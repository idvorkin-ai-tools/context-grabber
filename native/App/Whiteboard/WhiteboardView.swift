//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347): PencilKit's canvas and the system tool
//  picker on a board far bigger than the screen, saved a moment after each stroke, and sent to Larry on the board's chat
//  thread holding its picture (the Inbox's image path, so it waits in the outbox when the network is away). A board
//  another device draws opens to look at only. Claude's ghosts after a pause and Larry's turn come back as shapes,
//  drawn faint until a tap keeps one (spec 2026-11-01-whiteboard-shapes-design.md, stories 344, 349).

import BugKit
import ContextCore
import PencilKit
import SwiftUI

@MainActor
final class WhiteboardModel: ObservableObject {
  @Published private(set) var isEmpty: Bool
  /// What the last Send did, shown in the bar until the next stroke.
  @Published private(set) var sent: String?
  @Published private(set) var problem: BugProblem?
  /// Shapes Claude or Larry offered, faint on the board until a tap keeps one (stories 344, 349).
  @Published private(set) var ghosts: [Ghost] = [] {
    didSet {
      if ghosts.count != oldValue.count {
        log.event(
          "whiteboard",
          [
            "action": "ghosts", "board": board.id, "count": ghosts.count,
            "larry": ghosts.filter { $0.who == .larry }.count,
          ])
      }
    }
  }
  /// Story 344's switch, remembered across boards.
  @Published private(set) var ghostsOn: Bool
  /// The last turn in a line: Larry's words, *Larry has the board*, or ghosts not answering.
  @Published private(set) var turnNote: String?
  /// The picture is on its way to Larry's thread.
  @Published private(set) var larrySending = false
  /// Looking at Larry's thread has failed for a while (story 383).
  @Published private(set) var larryAway = false
  let board: BoardEntry
  /// Drawn here, or only looked at (a board from another device, story 347).
  let editable: Bool
  @Published private(set) var drawing: PKDrawing
  private let store: WhiteboardStore
  private let log: SessionLog
  private let inbox: InboxModel
  private let cockpit: String
  /// Puts a kept ghost on the canvas (undoably); the canvas sets it.
  var draw: ((PKDrawing) -> Void)?
  private var pacer = WhiteboardPacer()
  private var pauseTask: Task<Void, Never>?
  private var fadeTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  private var dirty = false
  private var saveFailing = false
  private var turnFailing = false
  private var marks = WhiteboardMarks()
  /// The row his showing marks came from.
  private var shownRow: String?
  private var watchTask: Task<Void, Never>?
  /// Between the board appearing and it closing or the app leaving.
  private var watching = false
  private var lookFailures = 0

  static let ghostsKey = "whiteboard_ghosts"
  /// How long the Pencil rests before Claude is asked.
  static let pause: Duration = .seconds(1)
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds =
    ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_GHOST_SECONDS"].flatMap(Double.init) ?? 30
  /// How often an open board looks at its thread, and how many failed looks before the bar says so.
  static let lookEvery: Duration = .seconds(3)
  static let awayAfter = 3

  init(board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel, cockpit: String) {
    self.board = board
    self.store = store
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
    ghostsOn = UserDefaults.standard.object(forKey: Self.ghostsKey) as? Bool ?? true
    editable = store.editable(board)
    var loaded = PKDrawing()
    do {
      loaded = try store.drawing(board.id)
    } catch {
      log.event("error", ["where": "whiteboard_load", "message": "\(error)", "board": board.id])
      problem = .grabber(
        "This board could not be read: \(error.localizedDescription)", context: "WhiteboardView.load",
        extra: ["board": .string(board.id)])
    }
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    log.event(
      "whiteboard",
      ["action": "open", "board": board.id, "strokes": loaded.strokes.count, "editable": store.editable(board)])
  }

  func changed(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    let added = new.strokes.count > drawing.strokes.count
    drawing = new
    if added, ghostsOn {
      pacer.strokeAdded()
      startPause()
    }
    drawingMoved()
  }

  private func drawingMoved() {
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    dirty = true
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts.
  func beganDrawing() {
    pacer.toolWentDown()
    pauseTask?.cancel()
    pauseTask = nil
  }

  func endedDrawing() {
    if pacer.toolLifted() { startPause() }
  }

  private func clearGhosts() {
    dropClaudesTurn()
    if ghosts.contains(where: { $0.who == .larry }) { settleLarrysRow() }
    if !ghosts.isEmpty { ghosts = [] }
  }

  /// A pause still waiting is forgotten, and an answer on its way is stale when it lands.
  private func dropClaudesTurn() {
    pacer.dropped()
    pauseTask?.cancel()
    pauseTask = nil
  }

  private func startPause() {
    pauseTask?.cancel()
    pauseTask = Task { [weak self] in
      try? await Task.sleep(for: Self.pause)
      guard !Task.isCancelled, let self else { return }
      self.pauseTask = nil
      if self.pacer.pauseEnded() { await self.turn(.claude) }
    }
  }

  func setGhosts(_ on: Bool) {
    ghostsOn = on
    UserDefaults.standard.set(on, forKey: Self.ghostsKey)
    log.event("whiteboard", ["action": on ? "ghosts_on" : "ghosts_off", "board": board.id])
    if !on {
      dropClaudesTurn()
      ghosts.removeAll { $0.who == .claude }
      if turnNote == Self.ghostsAway { turnNote = nil }
    }
  }

  /// Story 380: the picture goes to the board's thread and Igor keeps drawing; Larry's marks come when they come.
  func larryTurn() {
    guard !larrySending else { return }
    Task { await handToLarry() }
  }

  private func handToLarry() async {
    guard editable, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    larrySending = true
    defer { larrySending = false }
    turnNote = "Sending the board to Larry"
    // ponytail: rendered and encoded on the main thread, as the ghost turn is.
    let jpeg = picture(rect: rect, scale: scale).jpegData(compressionQuality: 0.85) ?? Data()
    let thread = UserDefaults.standard.string(forKey: threadKey)
    let picture = WhiteboardPicture(
      board: board.id, title: store.index.board(board.id)?.title ?? board.title, rect: rect, scale: scale)
    let started = Date()
    var event: [String: Any] = [
      "who": "larry", "board": board.id, "bytes": jpeg.count, "picture": picture.pictureID, "new_thread": thread == nil,
    ]
    defer {
      event["ms"] = Int(Date().timeIntervalSince(started) * 1000)
      log.event("whiteboard_turn", event)
    }
    let outcome = await deliver(jpeg, picture: picture, thread: thread)
    switch outcome {
    case .sent(let key, _):
      event["ok"] = true
      event["thread"] = key
      UserDefaults.standard.set(key, forKey: threadKey)
      turnFailing = false
      turnNote = "Larry has the board"
      if problem?.context == "WhiteboardView.larry" { problem = nil }
      watchLarry()
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      // A thread the Cockpit no longer has: the next turn starts a new one.
      if status == 404 { UserDefaults.standard.removeObject(forKey: threadKey) }
      failed(.larry, "The Cockpit refused the turn (\(status)): \(reason)", status: status, stale: false)
    case .retry(let reason):
      event["ok"] = false
      event["reason"] = reason
      failed(.larry, "Larry couldn't be reached: \(reason)", status: nil, stale: false)
    }
  }

  /// The picture uploaded, then the message that names it.
  private func deliver(_ jpeg: Data, picture: WhiteboardPicture, thread: String?) async -> ChatSend.Outcome {
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try ChatSend.uploadRequest(image: jpeg, cockpit: cockpit))
      switch ChatSend.upload(status: (response as? HTTPURLResponse)?.statusCode, body: body) {
      case .refused(let status, let reason): return .refused(status: status, reason: reason)
      case .retry(let reason): return .retry(reason: "image upload: \(reason)")
      case .ref(let ref):
        let item = InboxItem(
          kind: .image, sharedAt: Int64(Date().timeIntervalSince1970 * 1000), note: "Your turn on the board",
          thread: thread, whiteboard: picture)
        let (body, response) = try await URLSession.shared.data(
          for: try ChatSend.messageRequest(item, attachment: ref, cockpit: cockpit))
        return ChatSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: body)
      }
    } catch {
      return .retry(reason: error.localizedDescription)
    }
  }

  /// The board appearing or the app coming back: looks at the thread until `stopWatchingLarry`, if there is one to
  /// look at. Story 382.
  func startWatchingLarry() {
    watching = true
    watchLarry()
  }

  private func watchLarry() {
    guard editable, watching, watchTask == nil, hasThreadToWatch else { return }
    watchTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.lookAtThread()
        try? await Task.sleep(for: Self.lookEvery)
      }
    }
  }

  private func stopWatchingLarry() {
    watching = false
    watchTask?.cancel()
    watchTask = nil
  }

  private var hasThreadToWatch: Bool {
    UserDefaults.standard.string(forKey: threadKey) != nil || UserDefaults.standard.string(forKey: sendKey) != nil
  }

  /// A Send to Larry that started the thread: once it lands, that thread is the board's.
  private func adoptSentThread() {
    guard let id = UserDefaults.standard.string(forKey: sendKey) else { return }
    let item = inbox.items.first { $0.id == id }
    if let thread = item?.chatThread, UserDefaults.standard.string(forKey: threadKey) == nil {
      UserDefaults.standard.set(thread, forKey: threadKey)
    }
    if item == nil || item?.status != .waiting { UserDefaults.standard.removeObject(forKey: sendKey) }
  }

  private func lookAtThread() async {
    adoptSentThread()
    guard let thread = UserDefaults.standard.string(forKey: threadKey) else { return }
    let reason: String
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try ChatWire.threadRequest(thread, cockpit: cockpit))
      if Task.isCancelled { return }
      let status = (response as? HTTPURLResponse)?.statusCode
      if status == 200, let rows = WhiteboardMarks.rows(body) {
        lookWorked(rows)
        return
      }
      reason = "HTTP \(status ?? 0)"
    } catch {
      if Task.isCancelled { return }
      reason = error.localizedDescription
    }
    // Once in the log, and quietly in the bar: never a loop of errors.
    if lookFailures == 0 {
      log.event("error", ["where": "whiteboard_marks", "board": board.id, "thread": thread, "message": reason])
    }
    lookFailures += 1
    if lookFailures >= Self.awayAfter { larryAway = true }
  }

  private func lookWorked(_ rows: [WhiteboardMarks.Row]) {
    if lookFailures > 0 { log.event("whiteboard_marks", ["action": "back", "board": board.id, "after": lookFailures]) }
    lookFailures = 0
    larryAway = false
    let update = marks.take(rows, settled: UserDefaults.standard.string(forKey: settledKey))
    for row in update.unplaced {
      log.event("whiteboard_marks", ["action": "unplaced", "board": board.id, "row": row])
    }
    if let say = update.say {
      turnNote = "Larry: \(say)"
    } else if update.marks != nil {
      turnNote = nil
    }
    guard let row = update.marks, let frame = row.frame else { return }
    // Each author's new marks replace only their own, placed by the row's own frame: where that picture was.
    shownRow = row.id
    ghosts =
      ghosts.filter { $0.who != .larry }
      + row.shapes.map { shape in
        Ghost(id: UUID().uuidString, who: .larry, lines: WhiteboardTurn.lines(shape, frame: frame, scale: row.scale))
      }
    log.event(
      "whiteboard_marks",
      [
        "action": "shown", "board": board.id, "row": row.id, "shapes": row.shapes.count,
        "picture": row.pictureID ?? "",
      ])
  }

  /// Igor kept or dismissed from his row: it doesn't come back when the board opens again.
  private func settleLarrysRow() {
    if let shownRow { UserDefaults.standard.set(shownRow, forKey: settledKey) }
  }

  static let ghostsAway = "Ghosts: the Cockpit isn't answering"
  // ponytail: the board's thread in UserDefaults on this device; it moves to the board's index if boards ever change
  // hands.
  private var threadKey: String { "whiteboard_thread_\(board.id)" }
  /// A Send to Larry starting the thread, by its Inbox id, until it lands.
  private var sendKey: String { "whiteboard_send_\(board.id)" }
  private var settledKey: String { "whiteboard_marks_settled_\(board.id)" }

  /// One turn: the board's picture to the Cockpit, shapes back as ghosts.
  func turn(_ who: WhiteboardTurn.Who) async {
    guard editable, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    let asked = pacer.generation
    if who == .claude { pacer.turnStarted() }
    defer { if who == .claude, pacer.turnLanded() { startPause() } }
    // ponytail: rendered and encoded on the main thread; if a big board hitches the next stroke (the turn event's
    // `bytes`), this moves to a background task.
    let image = picture(rect: rect, scale: scale)
    let png = image.pngData() ?? Data()
    let started = Date()
    let answer: WhiteboardTurn.Answer
    var read = ClaudesAnswer()
    do {
      let title = store.index.board(board.id)?.title ?? board.title
      let request = try WhiteboardTurn.suggestRequest(
        title: title, picture: png, width: image.cgImage?.width ?? 0, height: image.cgImage?.height ?? 0,
        cockpit: cockpit)
      read = await readClaude(request, started: started) { [weak self] shape, first in
        guard let self, self.pacer.generation == asked else { return }
        self.land([shape], who: .claude, rect: rect, scale: scale, first: first)
      }
      answer = read.answer
    } catch {
      answer = WhiteboardTurn.answer(status: nil, body: nil, error: error.localizedDescription)
    }
    let stale = who == .claude && pacer.generation != asked
    let ms = Int(Date().timeIntervalSince(started) * 1000)
    var event: [String: Any] = [
      "who": who.rawValue, "board": board.id, "ms": ms, "stale": stale, "bytes": png.count, "streamed": read.streamed,
    ]
    if let broken = read.broken { event["broken"] = broken }
    switch answer {
    case .shapes(let shapes):
      event["ok"] = true
      event["shapes"] = shapes.count
      if !shapes.isEmpty { event["first_shape_ms"] = read.firstShapeMs ?? ms }
      turnFailing = false
      if turnNote == Self.ghostsAway { turnNote = nil }
      // Streamed marks are on the board already; a stream with none clears Claude's, as an empty answer does.
      if !stale, !read.streamed || shapes.isEmpty { land(shapes, who: who, rect: rect, scale: scale, first: true) }
    case .tooSoon:
      event["ok"] = false
      event["reason"] = "too_soon"
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      failed(who, "The Cockpit refused the turn (\(status)): \(reason)", status: status, stale: stale)
    case .away(let reason):
      event["ok"] = false
      event["reason"] = reason
      failed(who, "Larry couldn't be reached: \(reason)", status: nil, stale: stale)
    }
    log.event("whiteboard_turn", event)
  }

  /// How Claude's answer was read, for `whiteboard_turn`.
  private struct ClaudesAnswer {
    var answer = WhiteboardTurn.Answer.away(reason: "no answer")
    var streamed = false
    var firstShapeMs: Int?
    /// What cut the reading short; marks that had already arrived stay.
    var broken: String?
  }

  /// Reads Claude's answer as it comes, telling `landed` each mark and whether it is the answer's first. The 10 s are
  /// for the whole answer: URLRequest's own timeout starts over with every byte.
  private func readClaude(
    _ request: URLRequest, started: Date, landed: @escaping (WhiteboardTurn.Shape, Bool) -> Void
  ) async -> ClaudesAnswer {
    let reading = Task { () -> ClaudesAnswer in
      var reader = WhiteboardStream(status: nil, contentType: nil)
      var firstShapeMs: Int?
      let land = { (shape: WhiteboardTurn.Shape, reader: WhiteboardStream) in
        let first = reader.shapes.count == 1
        if first { firstShapeMs = Int(Date().timeIntervalSince(started) * 1000) }
        landed(shape, first)
      }
      var failure: String?
      do {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        reader = WhiteboardStream(status: (response as? HTTPURLResponse)?.statusCode, contentType: response.mimeType)
        for try await byte in bytes {
          if let shape = reader.take(byte) { land(shape, reader) }
          if reader.done { break }
        }
        if let shape = reader.finish() { land(shape, reader) }
      } catch {
        failure =
          Task.isCancelled ? "no answer in \(Int(WhiteboardTurn.suggestTimeout)) s" : error.localizedDescription
      }
      return ClaudesAnswer(
        answer: reader.answer(error: failure), streamed: reader.streaming, firstShapeMs: firstShapeMs,
        broken: reader.broken(error: failure))
    }
    let deadline = Task {
      try? await Task.sleep(for: .seconds(WhiteboardTurn.suggestTimeout))
      if !Task.isCancelled { reading.cancel() }
    }
    defer { deadline.cancel() }
    return await reading.value
  }

  /// Marks landing on the board: an answer's first replaces its author's earlier ones, and only those.
  private func land(
    _ shapes: [WhiteboardTurn.Shape], who: WhiteboardTurn.Who, rect: CGRect, scale: CGFloat, first: Bool
  ) {
    if who == .claude, turnNote == Self.ghostsAway, !shapes.isEmpty { turnNote = nil }
    ghosts =
      (first ? ghosts.filter { $0.who != who } : ghosts)
      + shapes.map { shape in
        Ghost(id: UUID().uuidString, who: who, lines: WhiteboardTurn.lines(shape, frame: rect, scale: scale))
      }
    if who == .claude { fadeClaudesGhosts() }
    if first, ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_KEEP"] == "first", let ghost = ghosts.first {
      keep(ghost)
    }
  }

  private func fadeClaudesGhosts() {
    fadeTask?.cancel()
    fadeTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(Self.ghostSeconds))
      guard !Task.isCancelled, let self else { return }
      self.ghosts.removeAll { $0.who == .claude }
    }
  }

  private func failed(_ who: WhiteboardTurn.Who, _ message: String, status: Int?, stale: Bool) {
    if !turnFailing {
      log.event("error", ["where": "whiteboard_turn", "who": who.rawValue, "message": message, "board": board.id])
    }
    turnFailing = true
    guard who == .larry else {
      if !stale, turnNote == nil { turnNote = Self.ghostsAway }
      return
    }
    turnNote = nil
    var extra: [String: JSONValue] = ["board": .string(board.id), "cockpit": .string(cockpit)]
    if let status { extra["status"] = .int(status) }
    problem = .grabber(message, context: "WhiteboardView.larry", extra: extra)
  }

  /// A tap at `point` (board points) keeps the ghost under it; a tap anywhere else dismisses the ghosts.
  func tap(at point: CGPoint, zoom: CGFloat) {
    guard !ghosts.isEmpty else { return }
    if let ghost = ghosts.first(where: { WhiteboardTurn.hit($0.lines, at: point, tolerance: 22 / zoom) }) {
      keep(ghost)
    } else {
      log.event("whiteboard", ["action": "ghosts_dismissed", "board": board.id, "count": ghosts.count])
      clearGhosts()
    }
  }

  /// The ghost as ink in its colour. Its point spacing is what makes PencilKit's spline follow the shape.
  private func keep(_ ghost: Ghost) {
    let ink = PKInk(.pen, color: ghost.who.color)
    let strokes = ghost.lines.map { line in
      PKStroke(
        ink: ink,
        path: PKStrokePath(
          controlPoints: WhiteboardTurn.inkPoints(line).enumerated().map { i, p in
            PKStrokePoint(
              location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: 3.7, height: 3.7), opacity: 1, force: 1,
              azimuth: 0, altitude: .pi / 2)
          }, creationDate: Date()))
    }
    var kept = drawing
    kept.strokes += strokes
    drawing = kept
    ghosts.removeAll { $0.id == ghost.id }
    if ghost.who == .larry { settleLarrysRow() }
    log.event("whiteboard", ["action": "keep", "board": board.id, "who": ghost.who.rawValue, "strokes": strokes.count])
    drawingMoved()
    draw?(kept)
  }

  /// Dark ink on white whatever the iPad's mode: what Larry and Claude see.
  private func picture(rect: CGRect, scale: CGFloat) -> UIImage {
    var ink = UIImage()
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { ink = drawing.image(from: rect, scale: scale) }
    let format = UIGraphicsImageRendererFormat()
    format.scale = ink.scale
    format.opaque = true
    return UIGraphicsImageRenderer(size: ink.size, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: ink.size))
      ink.draw(at: .zero)
    }
  }

  /// The app going to the background: what is drawn is written now. The board stays open, so an empty new one is
  /// kept.
  func flush() {
    stopWatchingLarry()
    saveTask?.cancel()
    if editable, dirty { save() }
  }

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
    stopWatchingLarry()
    saveTask?.cancel()
    guard editable else { return }
    if dirty {
      save()
      log.event("whiteboard", ["action": "close", "board": board.id, "strokes": drawing.strokes.count])
    }
    store.closed(board.id, empty: drawing.strokes.isEmpty)
  }

  // ponytail: serialised on the main thread; a board big enough to stutter here moves it to a background task.
  private func save() {
    guard dirty else { return }
    do {
      try store.save(drawing, board: board.id)
      dirty = false
      saveFailing = false
    } catch {
      if !saveFailing {
        log.event("error", ["where": "whiteboard_save", "message": "\(error)", "strokes": drawing.strokes.count])
      }
      saveFailing = true
      problem = .grabber(
        "The board could not be saved: \(error.localizedDescription)", context: "WhiteboardView.save",
        extra: ["strokes": .int(drawing.strokes.count)])
    }
  }

  /// Story 343: the whole drawing, dark ink on white whatever the iPad's mode, on the board's thread with Larry, titled
  /// with the board's name; the first one starts it (story 381).
  func send() {
    guard sent == nil, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    let ink = picture(rect: rect, scale: scale)
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    draft.text = store.index.board(board.id)?.title ?? board.title
    draft.whiteboard = WhiteboardPicture(board: board.id, title: draft.text, rect: rect, scale: scale)
    let thread = UserDefaults.standard.string(forKey: threadKey)
    let id = UUID().uuidString.lowercased()
    do {
      try inbox.add(&draft, id: id, thread: thread)
      if thread == nil {
        UserDefaults.standard.set(id, forKey: sendKey)
        watchLarry()
      }
      if problem?.context == "WhiteboardView.send" { problem = nil }
      sent = "Sent to Larry: his reply shows in Chat"
      log.event(
        "whiteboard",
        [
          "action": "send", "board": board.id, "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
        ])
    } catch {
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}

/// A shape Claude or Larry offered, in board points, not yet kept.
struct Ghost: Identifiable {
  let id: String
  let who: WhiteboardTurn.Who
  let lines: [[CGPoint]]
}

extension WhiteboardTurn.Who {
  /// Claude orange, Larry blue (spec 2026-11-01-whiteboard-shapes-design.md).
  var color: UIColor { self == .claude ? .systemOrange : .systemBlue }
}

/// One board, pushed from the list: drawn on here, or looked at when another device draws it.
struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  @Environment(\.scenePhase) private var scenePhase
  private let logger: BugLogger

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit))
    logger = app.bugLogger
  }

  var body: some View {
    VStack(spacing: 0) {
      if let note {
        Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.8)
          .padding(.vertical, 4).padding(.horizontal)
      }
      if let problem = model.problem {
        BugProblemView(problem: problem, logger: logger).padding(.horizontal)
      }
      BoardCanvas(model: model).ignoresSafeArea(edges: .bottom)
    }
    .navigationTitle(model.board.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if model.editable {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.setGhosts(!model.ghostsOn)
          } label: {
            Label(model.ghostsOn ? "Ghosts on" : "Ghosts off", systemImage: model.ghostsOn ? "sparkles" : "eye.slash")
          }
          // How many show, for VoiceOver and the UI test (the board's own content is not in the accessibility tree,
          // and a toolbar button's accessibility value never reaches it).
          .accessibilityLabel(
            (model.ghostsOn ? "Ghosts on" : "Ghosts off")
              + (model.ghosts.isEmpty ? "" : ", \(model.ghosts.count) showing")
          )
          .accessibilityIdentifier("whiteboard-ghosts")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.larryTurn()
          } label: {
            Label("Larry's turn", systemImage: "hand.draw")
          }
          .disabled(model.isEmpty || model.larrySending)
          .accessibilityIdentifier("whiteboard-larry")
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          model.send()
        } label: {
          Label("Send to Larry", systemImage: "paperplane")
        }
        // How much is drawn, for VoiceOver and the UI test, in the label for the reason above.
        .accessibilityLabel("Send to Larry, \(model.drawing.strokes.count) strokes")
        .disabled(model.isEmpty || model.sent != nil)
        .accessibilityIdentifier("whiteboard-send")
      }
    }
    .accessibilityIdentifier("whiteboard")
    .onAppear { model.startWatchingLarry() }
    .onDisappear { model.close() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { model.flush() }
      if phase == .active { model.startWatchingLarry() }
    }
  }

  private var note: String? {
    let count = model.ghosts.count
    let parts = [
      model.turnNote,
      model.larryAway ? "Larry's marks: the Cockpit isn't answering" : nil,
      count == 0 ? nil : "\(count) suggestion\(count == 1 ? "" : "s"): tap one to keep it",
      model.sent ?? (model.editable ? nil : "Drawn on \(model.board.deviceName): look only"),
    ].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}

/// PencilKit's canvas on a board far bigger than the screen, with the ghosts on a layer that pans and zooms with it.
private struct BoardCanvas: UIViewRepresentable {
  @ObservedObject var model: WhiteboardModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> BoardCanvasView {
    let canvas = BoardCanvasView()
    canvas.drawing = model.drawing
    canvas.delegate = context.coordinator
    // The system's own choice: with a Pencil paired, only it draws (palm rejection, a finger moves the board);
    // without one (an iPhone, the simulator), a finger draws.
    canvas.drawingPolicy = .default
    canvas.backgroundColor = .systemBackground
    canvas.isOpaque = true
    canvas.contentSize = CGSize(width: WhiteboardFrame.side, height: WhiteboardFrame.side)
    canvas.minimumZoomScale = 0.1
    canvas.maximumZoomScale = 3
    if model.editable {
      canvas.toolPicker = context.coordinator.picker
      // Stories 344, 354: a finger tap keeps a ghost (the Pencil draws, and they stay while it does).
      let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
      tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
      tap.cancelsTouchesInView = false
      canvas.addGestureRecognizer(tap)
      model.draw = { [weak canvas] drawing in
        guard let canvas else { return }
        let before = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: canvas) { $0.drawing = before }
        canvas.drawing = drawing
      }
    } else {
      // Story 347: pan and pinch only.
      canvas.drawingGestureRecognizer.isEnabled = false
    }
    return canvas
  }

  func updateUIView(_ canvas: BoardCanvasView, context: Context) {
    canvas.show(model.ghosts)
  }

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    let model: WhiteboardModel
    /// Held here: the tool picker disappears when nothing keeps it.
    let picker = PKToolPicker()

    init(model: WhiteboardModel) { self.model = model }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      let drawing = canvasView.drawing
      MainActor.assumeIsolated { model.changed(drawing) }
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
      MainActor.assumeIsolated { model.endedDrawing() }
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
      MainActor.assumeIsolated { model.beganDrawing() }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      MainActor.assumeIsolated { (scrollView as? BoardCanvasView)?.followZoom() }
    }

    @objc func tapped(_ tap: UITapGestureRecognizer) {
      guard let canvas = tap.view as? BoardCanvasView else { return }
      let zoom = canvas.zoomScale
      let at = tap.location(in: canvas)
      MainActor.assumeIsolated {
        model.tap(at: CGPoint(x: at.x / zoom, y: at.y / zoom), zoom: zoom)
      }
    }
  }
}

final class BoardCanvasView: PKCanvasView {
  fileprivate var toolPicker: PKToolPicker?
  private var opened = false
  /// Holds the ghosts in board points; scaled with the zoom so they sit on the drawing.
  private let ghostLayer = CALayer()
  private var shown: [String: CAShapeLayer] = [:]

  /// The first layout knows the screen's size: the view opens centred on the drawing.
  override func layoutSubviews() {
    super.layoutSubviews()
    if ghostLayer.superlayer == nil {
      ghostLayer.anchorPoint = .zero
      ghostLayer.frame = .zero
      layer.addSublayer(ghostLayer)
      followZoom()
    }
    guard !opened, bounds.width > 0, bounds.height > 0 else { return }
    opened = true
    let drawn = drawing.strokes.isEmpty ? nil : drawing.bounds
    contentOffset = WhiteboardFrame.openingOffset(drawing: drawn, viewport: bounds.size)
  }

  func followZoom() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    ghostLayer.setAffineTransform(CGAffineTransform(scaleX: zoomScale, y: zoomScale))
    ghostLayer.zPosition = 10
    CATransaction.commit()
  }

  /// One shape layer a ghost: the ink it would become, faint, in its colour.
  fileprivate func show(_ ghosts: [Ghost]) {
    guard Set(ghosts.map(\.id)) != Set(shown.keys) else { return }
    // Where a finger draws, it taps and pans while ghosts show (story 354).
    drawingPolicy = ghosts.isEmpty ? .default : .pencilOnly
    let live = Set(ghosts.map(\.id))
    for (id, gone) in shown where !live.contains(id) {
      shown[id] = nil
      CATransaction.begin()
      CATransaction.setCompletionBlock { gone.removeFromSuperlayer() }
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = gone.presentation()?.opacity ?? 1
      fade.toValue = 0
      fade.duration = 0.3
      gone.opacity = 0
      gone.add(fade, forKey: "fade")
      CATransaction.commit()
    }
    let arriving = ghosts.filter { shown[$0.id] == nil }
    for (i, ghost) in arriving.enumerated() {
      let path = CGMutablePath()
      for line in ghost.lines { path.addLines(between: line) }
      let shape = CAShapeLayer()
      shape.path = path
      shape.fillColor = nil
      shape.strokeColor = ghost.who.color.withAlphaComponent(0.5).cgColor
      shape.lineWidth = 3.7
      shape.lineCap = .round
      shape.lineJoin = .round
      // Drawn in one after another, like someone sketching beside him.
      let drawIn = CABasicAnimation(keyPath: "strokeEnd")
      drawIn.fromValue = 0
      drawIn.toValue = 1
      drawIn.duration = 0.25
      drawIn.beginTime = CACurrentMediaTime() + 0.25 * Double(i)
      drawIn.fillMode = .backwards
      shape.add(drawIn, forKey: "drawIn")
      ghostLayer.addSublayer(shape)
      shown[ghost.id] = shape
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let toolPicker else { return }
    toolPicker.addObserver(self)
    toolPicker.setVisible(true, forFirstResponder: self)
    becomeFirstResponder()
  }
}
