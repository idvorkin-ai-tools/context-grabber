//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347): PencilKit's canvas and the system tool
//  picker on a board far bigger than the screen, saved a moment after each stroke, and sent to Larry on the board's chat
//  thread holding its picture (the Inbox's image path, so it waits in the outbox when the network is away). A board
//  another device draws opens to look at only. Claude's ghosts after a pause or spoken words and Larry's turn come back
//  as shapes, drawn faint until a tap keeps one (spec 2026-11-01-whiteboard-shapes-design.md, stories 344, 345, 349).

import BugKit
import Combine
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
  /// Story 407's switch, remembered per board on this device. Lines over the board, never in the drawing or a picture.
  @Published private(set) var gridOn: Bool
  /// The board's colour (story 378).
  @Published private(set) var paper: BoardPaper
  /// The last turn in a line: Larry's words, *Larry has the board*, or ghosts not answering.
  @Published private(set) var turnNote: String?
  /// The picture is on its way to Larry's thread.
  @Published private(set) var larrySending = false
  /// Looking at Larry's thread has failed for a while (story 383).
  @Published private(set) var larryAway = false
  /// What the last paste left off or couldn't draw, shown until the board next changes (stories 392, 393).
  @Published private(set) var pasteNote: String?
  /// The board's mic (story 345): open, on its way up, finishing its last words, and the last words it heard.
  @Published private(set) var micOn = false
  @Published private(set) var micStarting = false
  @Published private(set) var micFinishing = false
  @Published private(set) var heardNote: String?
  let board: BoardEntry
  /// Drawn here, or only looked at (a board from another device, story 347).
  let editable: Bool
  @Published private(set) var drawing: PKDrawing
  private let store: WhiteboardStore
  private let log: SessionLog
  private let inbox: InboxModel
  private let cockpit: String
  private let threads = WhiteboardThreads()
  /// What's on screen in board points, for a turn on an empty board or a paste, and the zoom; the canvas sets them.
  var visibleRect: (() -> CGRect)?
  var zoom: (() -> CGFloat)?
  /// Puts a kept ghost or a paste on the canvas (undoably); the canvas sets it.
  var draw: ((PKDrawing) -> Void)?
  private var pacer = WhiteboardPacer()
  private let callLive: @MainActor () -> Bool
  private lazy var dictation = makeDictation()
  private var dictationWatches: Set<AnyCancellable> = []
  private var speech = WhiteboardSpeech()
  /// Spoken and not yet in a turn that got through.
  private var unsaid: String?
  private var silenceTask: Task<Void, Never>?
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
  private var lookFailures = 0

  static let ghostsKey = "whiteboard_ghosts"
  /// How long the Pencil rests before Claude is asked.
  static let pause: Duration = .seconds(1)
  /// A pasted letter's height on screen, in points, at 100% and zoomed out.
  static let pasteLetters: CGFloat = 24
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds =
    ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_GHOST_SECONDS"].flatMap(Double.init) ?? 30
  /// How often an open board looks at its thread, how long one look waits, and how many failed looks before the bar
  /// says so.
  static let lookEvery: Duration = .seconds(3)
  static let lookTimeout: TimeInterval = 3
  static let awayAfter = 3

  init(
    board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel, cockpit: String,
    callLive: @escaping @MainActor () -> Bool
  ) {
    self.callLive = callLive
    self.board = board
    paper = board.paper
    self.store = store
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
    ghostsOn = UserDefaults.standard.object(forKey: Self.ghostsKey) as? Bool ?? true
    gridOn = UserDefaults.standard.bool(forKey: "whiteboard_grid_\(board.id)")
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
    if ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_GRID"] == "on" { setGrid(true) }
  }

  func changed(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    let added = new.strokes.count > drawing.strokes.count
    logStrokesMoved(to: new)
    drawing = new
    if added, ghostsOn {
      pacer.strokeAdded()
      startPause()
    }
    drawingMoved()
  }

  /// #624: a board's ink below a line moved on its own, splitting a kept label. Names the next one.
  private func logStrokesMoved(to new: PKDrawing) {
    guard
      let moved = WhiteboardFrame.strokesMoved(
        before: drawing.strokes.map(\.renderBounds), after: new.strokes.map(\.renderBounds))
    else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_moved", "board": board.id, "strokes": new.strokes.count, "moved": moved.count,
        "dx": Double(moved.dx), "dy": Double(moved.dy), "top_moved_y": Double(moved.topY), "zoom": Double(zoom?() ?? 1),
      ])
  }

  /// #624: which commands the canvas's menu offers, once each per board.
  func canvasAsked(_ selector: String, allowed: Bool) {
    log.event("whiteboard", ["action": "can_perform", "board": board.id, "selector": selector, "allowed": allowed])
  }

  private func drawingMoved() {
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    pasteNote = nil
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
      unsaid = nil
      ghosts.removeAll { $0.who == .claude }
      if turnNote == Self.ghostsAway { turnNote = nil }
    }
  }

  func setGrid(_ on: Bool) {
    gridOn = on
    UserDefaults.standard.set(on, forKey: "whiteboard_grid_\(board.id)")
    log.event("whiteboard", ["action": on ? "grid_on" : "grid_off", "board": board.id])
  }

  func setPaper(_ new: BoardPaper) {
    guard editable, new != paper else { return }
    paper = new
    store.setPaper(new, board: board.id)
    log.event("whiteboard", ["action": "paper", "board": board.id, "paper": new.rawValue])
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
    turnNote = "Larry has the board"
    // ponytail: rendered and encoded on the main thread, as the ghost turn is.
    let jpeg = picture(rect: rect, scale: scale).jpegData(compressionQuality: 0.85) ?? Data()
    let strokes = WhiteboardStrokes.wire(strokesForLarry())
    let thread = threads.thread(board: board.id)
    let picture = WhiteboardPicture(
      board: board.id, title: store.index.board(board.id)?.title ?? board.title, rect: rect, scale: scale)
    let started = Date()
    var event: [String: Any] = [
      "who": "larry", "board": board.id, "bytes": jpeg.count, "picture": picture.pictureID, "new_thread": thread == nil,
      "pixels": "\(Int(rect.width * scale))x\(Int(rect.height * scale))",
    ]
    defer {
      event["ms"] = Int(Date().timeIntervalSince(started) * 1000)
      log.event("whiteboard_turn", event)
    }
    // Story 419: the strokes first, under this picture's id; the picture goes whatever they answered.
    event.merge(WhiteboardStrokes.logFields(await sendStrokes(strokes, picture: picture))) { $1 }
    let outcome = await deliver(jpeg, picture: picture, thread: thread)
    switch outcome {
    case .sent(let key, _):
      event["ok"] = true
      event["thread"] = key
      threads.set(key, board: board.id)
      turnFailing = false
      if problem?.context == "WhiteboardView.larry" { problem = nil }
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      // A thread the Cockpit no longer has: the next turn starts a new one.
      if status == 404, let thread { threads.forget(thread, board: board.id) }
      failed(.larry, "The Cockpit refused the turn (\(status)): \(reason)", status: status, stale: false)
    case .retry(let reason):
      event["ok"] = false
      event["reason"] = reason
      failed(.larry, "Larry couldn't be reached: \(reason)", status: nil, stale: false)
    }
  }

  /// Story 419: the board's strokes to the Cockpit under the picture's id. Never a reason not to send the picture.
  private func sendStrokes(_ strokes: [[String: Any]], picture: WhiteboardPicture) async -> WhiteboardStrokes.Answer {
    do {
      let request = try WhiteboardStrokes.request(picture: picture, strokes: strokes, cockpit: cockpit)
      let (body, response) = try await URLSession.shared.data(for: request)
      return WhiteboardStrokes.answer(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      return WhiteboardStrokes.answer(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  /// Story 419: the drawing as the Cockpit's strokes, in board points: each PencilKit spline sampled every few points
  /// (the stroke's transform applied), the ink's colour as it looks in light mode (black, not white), the width as
  /// the mean of the stroke's own point sizes (the transform's scale applied), and an id that is the same for the same
  /// ink on every send. Story 423: only the ink still visible goes, one stroke per visible stretch, so a pixel eraser's rub changes the ids.
  private func strokesForLarry() -> [WhiteboardStrokes.Stroke] {
    let light = UITraitCollection(userInterfaceStyle: .light)
    return drawing.strokes.prefix(WhiteboardStrokes.maxStrokes).flatMap { stroke -> [WhiteboardStrokes.Stroke] in
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      if !stroke.ink.color.resolvedColor(with: light).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        (red, green, blue) = (0, 0, 0)
      }
      let color = WhiteboardStrokes.hex(red: red, green: green, blue: blue)
      let width = WhiteboardStrokes.width(sizes: stroke.path.map(\.size.width), transform: stroke.transform)
      let t = Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
      let tool = WhiteboardStrokes.tool(rawValue: stroke.ink.inkType.rawValue)
      return stroke.maskedPathRanges.map { range in
        var points = stroke.path.interpolatedPoints(in: range, by: .distance(WhiteboardStrokes.spacing)).map {
          $0.location.applying(stroke.transform)
        }
        if points.isEmpty {
          points = [stroke.path.interpolatedPoint(at: range.lowerBound).location.applying(stroke.transform)]
        }
        return WhiteboardStrokes.Stroke(
          id: WhiteboardStrokes.id(points: points, color: color, t: t), t: t, color: color, width: width, tool: tool,
          points: points)
      }
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

  /// The board appearing or the app coming back: looks at its thread, once it has one, until `stopWatchingLarry`.
  /// Story 382.
  func startWatchingLarry() {
    guard editable, watchTask == nil else { return }
    watchTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.lookAtThread()
        try? await Task.sleep(for: Self.lookEvery)
      }
    }
  }

  private func stopWatchingLarry() {
    watchTask?.cancel()
    watchTask = nil
  }

  private func lookAtThread() async {
    guard let thread = threads.thread(board: board.id) else { return }
    let reason: String
    do {
      var request = try ChatWire.threadRequest(thread, cockpit: cockpit)
      request.timeoutInterval = Self.lookTimeout
      let (body, response) = try await URLSession.shared.data(for: request)
      if Task.isCancelled { return }
      let status = (response as? HTTPURLResponse)?.statusCode
      if status == 200, let rows = WhiteboardMarks.rows(body) {
        lookWorked(rows)
        return
      }
      if status == 404 {
        threadGone(thread)
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

  /// The Cockpit answered and no longer has the thread: the next picture starts a new one.
  private func threadGone(_ thread: String) {
    threads.forget(thread, board: board.id)
    lookFailures = 0
    larryAway = false
    log.event("whiteboard_marks", ["action": "thread_gone", "board": board.id, "thread": thread])
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
  private var settledKey: String { "whiteboard_marks_settled_\(board.id)" }

  private func makeDictation() -> NoteDictation {
    let dictation = NoteDictation(
      logger: log.bugLogger, hostMicrophoneBusy: { [weak self] in self?.callLive() ?? false })
    dictation.$listening.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micOn = on }
    }
    .store(in: &dictationWatches)
    dictation.$starting.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micStarting = on }
    }
    .store(in: &dictationWatches)
    dictation.$processing.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micFinishing = on }
    }
    .store(in: &dictationWatches)
    dictation.$problem.combineLatest(dictation.$problemState).sink { [weak self] message, state in
      MainActor.assumeIsolated {
        guard let self, let message else { return }
        self.micProblem(message, state)
      }
    }
    .store(in: &dictationWatches)
    return dictation
  }

  private func micProblem(_ message: String, _ state: [String: JSONValue]) {
    let extra = state.merging(["board": .string(board.id), "call_live": .bool(callLive())]) { _, new in new }
    problem = .grabber(message, context: "WhiteboardView.mic", extra: extra)
  }

  /// Opens the board's mic, or closes it and sends what's still unsent.
  func tapMic() {
    if let words = ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_SAY"] {
      speech.heard(words)
      spoke()
      return
    }
    if micOn {
      stopMic(why: "tap")
      return
    }
    guard !dictation.busy else { return }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live"])
      micProblem("A call with Larry is using the microphone. End it to talk to the board.", [:])
      return
    }
    if problem?.context == "WhiteboardView.mic" { problem = nil }
    speech = WhiteboardSpeech()
    heardNote = nil
    log.event("whiteboard", ["action": "mic_on", "board": board.id])
    dictation.toggle(note: "") { [weak self] text in self?.heard(text) }
  }

  /// A call taking the microphone, the board closing or the app leaving: the mic stops, and its last words still go.
  func stopMic(why: String) {
    guard micOn || micStarting else { return }
    silenceTask?.cancel()
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": why])
    Task {
      await dictation.finish(why: why)
      spoke()
    }
  }

  private func heard(_ text: String) {
    speech.heard(text)
    heardNote = String(text.suffix(80))
    silenceTask?.cancel()
    silenceTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.spoke()
    }
  }

  /// He stopped talking: the new words go now, or with the next turn if one is on its way. With Ghosts off nothing is
  /// asked, and they aren't kept for later.
  private func spoke() {
    guard let words = speech.takeNew() else { return }
    guard ghostsOn else {
      log.event("whiteboard", ["action": "spoke", "board": board.id, "chars": words.count, "went": "ghosts_off"])
      return
    }
    unsaid = unsaid.map { "\($0) \(words)" } ?? words
    let now = pacer.pauseEnded()
    log.event("whiteboard", ["action": "spoke", "board": board.id, "chars": words.count, "went": now ? "now" : "held"])
    guard now else { return }
    // This turn's picture has the strokes a waiting pause would ask about.
    pauseTask?.cancel()
    pauseTask = nil
    Task { await turn(.claude) }
  }

  /// One turn: the board's picture to the Cockpit, shapes back as ghosts.
  func turn(_ who: WhiteboardTurn.Who) async {
    let said = who == .claude ? unsaid : nil
    // An empty board has no drawing to frame: a spoken turn sees the part on screen, and any other isn't asked.
    let framed = said != nil && drawing.strokes.isEmpty ? visibleRect?() ?? .null : drawing.bounds
    guard editable, let (rect, scale) = WhiteboardFrame.export(framed) else { return }
    if who == .claude { unsaid = nil }
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
        title: WhiteboardSpeech.context(title: title, said: said), picture: png, width: image.cgImage?.width ?? 0,
        height: image.cgImage?.height ?? 0,
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
      "said_chars": said?.count ?? 0,
    ]
    var undelivered = said
    if let broken = read.broken { event["broken"] = broken }
    switch answer {
    case .shapes(let shapes):
      undelivered = nil
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
    if ghostsOn, let undelivered { unsaid = unsaid.map { "\(undelivered) \($0)" } ?? undelivered }
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
    let strokes = Self.strokes(ghost.lines, color: ghost.who.color, width: 3.7, spacing: 4)
    ghosts.removeAll { $0.id == ghost.id }
    if ghost.who == .larry { settleLarrysRow() }
    log.event("whiteboard", ["action": "keep", "board": board.id, "who": ghost.who.rawValue, "strokes": strokes.count])
    add(strokes)
  }

  private static func strokes(_ lines: [[CGPoint]], color: UIColor, width: CGFloat, spacing: CGFloat) -> [PKStroke] {
    let ink = PKInk(.pen, color: color)
    return lines.map { line in
      PKStroke(
        ink: ink,
        path: PKStrokePath(
          controlPoints: WhiteboardTurn.inkPoints(line, spacing: spacing).enumerated().map { i, p in
            PKStrokePoint(
              location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: width, height: width), opacity: 1,
              force: 1, azimuth: 0, altitude: .pi / 2)
          }, creationDate: Date()))
    }
  }

  private func add(_ strokes: [PKStroke]) {
    var kept = drawing
    kept.strokes += strokes
    drawing = kept
    drawingMoved()
    draw?(kept)
  }

  /// Stories 390, 391: the text as ink in the middle of the view, one undo, and a change like a drawn stroke. Black ink
  /// shows light in dark mode, as the Pencil's does, and dark in the picture. The pen's width is in proportion to the
  /// letters: a ghost's 3.7 fills a 24-point letter in, and PencilKit draws nothing under about 2 (seen on the
  /// simulator, on the canvas and in the picture alike), which is why zooming in never shrinks them on the board.
  func paste(_ text: String) {
    guard editable, let visible = visibleRect?(), !visible.isNull, let zoom = zoom?() else { return }
    let height = Self.pasteLetters / min(zoom, 1)
    let layout = WhiteboardPaste.layout(text, visible: visible, height: height)
    let strokes = Self.strokes(layout.lines, color: .black, width: height * 0.11, spacing: height / 8)
    log.event(
      "whiteboard",
      [
        "action": "paste", "board": board.id, "characters": layout.kept, "of": layout.total, "strokes": strokes.count,
      ])
    guard !strokes.isEmpty else {
      pasteNote = "Nothing in that text can be drawn"
      return
    }
    add(strokes)
    if ghostsOn {
      pacer.strokeAdded()
      startPause()
    }
    if layout.cut {
      pasteNote = "Pasted the first \(layout.kept) of \(layout.total.formatted()) characters"
    }
  }

  /// Dark ink on white whatever the iPad's mode and the board's colour: what Larry and Claude see.
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

  /// On screen: a delete from another device waits for `close`, which comes after the last save.
  func opened() {
    if editable { store.opened(board.id) }
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

  /// The board's first Send is still in the outbox: a turn now would start a second thread.
  func firstSendWaiting(in items: [InboxItem]) -> Bool {
    threads.firstSendWaiting(board: board.id, in: items)
  }

  /// Story 343: the whole drawing, dark ink on white whatever the iPad's mode, on the board's thread with Larry, titled
  /// with the board's name; the first one starts it (story 381).
  func send() {
    guard sent == nil, !larrySending, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    let ink = picture(rect: rect, scale: scale)
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    draft.text = store.index.board(board.id)?.title ?? board.title
    draft.whiteboard = WhiteboardPicture(board: board.id, title: draft.text, rect: rect, scale: scale)
    // Story 424: the strokes wait beside the picture and go first when it goes.
    draft.strokes = try? JSONSerialization.data(withJSONObject: WhiteboardStrokes.wire(strokesForLarry()))
    do {
      try inbox.add(&draft, thread: threads.thread(board: board.id))
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

extension UIColor {
  convenience init(rgb: UInt32) {
    self.init(
      red: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1)
  }
}

extension BoardPaper {
  /// Follows the view's mode, as the ink does. Plain is the system's own, as every board was before colours.
  var color: UIColor {
    guard self != .plain else { return .systemBackground }
    let light = UIColor(rgb: light)
    let dark = UIColor(rgb: dark)
    return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
  }
}

/// One board, pushed from the list: drawn on here, or looked at when another device draws it.
struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  @ObservedObject private var inbox: InboxModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let logger: BugLogger
  private let callLive: AnyPublisher<Bool, Never>
  private let reportOpen: AnyPublisher<Bool, Never>

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit,
        callLive: { [weak app] in app?.call.snapshot.isActive ?? false }))
    inbox = app.inbox
    callLive = app.call.$snapshot.map(\.isActive).removeDuplicates().eraseToAnyPublisher()
    reportOpen = app.reporter.$flow.map(\.isPresented).removeDuplicates().eraseToAnyPublisher()
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
        // The board's own settings, in one menu. Six items in an iPhone's top bar push Larry's turn and Send under *More*,
        // so at that width this one goes to the bottom (story 402).
        ToolbarItem(placement: horizontalSizeClass == .compact ? .bottomBar : .topBarTrailing) {
          Menu {
            Section("Colour") {
              Picker("Colour", selection: Binding(get: { model.paper }, set: { model.setPaper($0) })) {
                ForEach(BoardPaper.allCases, id: \.self) { paper in
                  Text(paper.name).tag(paper)
                }
              }
            }
            Section("Grid") {
              Toggle("Grid lines", isOn: Binding(get: { model.gridOn }, set: { model.setGrid($0) }))
            }
          } label: {
            Label("Board", systemImage: "paintpalette")
          }
          // Its colour and grid, for VoiceOver and the UI test, in the label for the reason below.
          .accessibilityLabel("Board, \(model.paper.name)\(model.gridOn ? ", grid on" : "")")
          .accessibilityIdentifier("whiteboard-board")
        }
        ToolbarItem(placement: .topBarTrailing) {
          // The system's button: no *Allow Paste?* prompt, and iOS dims it when the clipboard holds no text.
          PasteButton(payloadType: String.self) { texts in
            Task { @MainActor in model.paste(texts.joined(separator: "\n")) }
          }
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("whiteboard-paste")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.tapMic()
          } label: {
            Label(model.micOn ? "Stop listening" : "Talk to Claude", systemImage: model.micOn ? "mic.fill" : "mic")
          }
          .disabled(model.micStarting || model.micFinishing)
          .tint(model.micOn ? .red : nil)
          .accessibilityIdentifier("whiteboard-mic")
        }
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
          .disabled(model.isEmpty || model.larrySending || model.firstSendWaiting(in: inbox.items))
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
        .disabled(model.isEmpty || model.sent != nil || model.larrySending)
        .accessibilityIdentifier("whiteboard-send")
      }
    }
    .accessibilityIdentifier("whiteboard")
    .task {
      // XCUITest's taps never reach the system's paste button: the UI test pastes through this.
      guard let text = ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_PASTE"] else { return }
      try? await Task.sleep(for: .seconds(1))
      model.paste(text)
    }
    .onAppear {
      model.opened()
      model.startWatchingLarry()
    }
    .onDisappear {
      model.stopMic(why: "closed")
      model.close()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        model.flush()
        model.stopMic(why: "background")
      }
      if phase == .active { model.startWatchingLarry() }
    }
    .onReceive(callLive) { live in if live { model.stopMic(why: "call") } }
    .onReceive(reportOpen) { open in if open { model.stopMic(why: "report") } }
  }

  private var note: String? {
    let count = model.ghosts.count
    let parts = [
      model.turnNote,
      model.pasteNote,
      model.larryAway ? "Larry's marks: the Cockpit isn't answering" : nil,
      model.micOn ? model.heardNote.map { "Heard: \($0)" } ?? "Listening…" : nil,
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
    canvas.backgroundColor = model.paper.color
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
      canvas.pasted = { [weak model] text in model?.paste(text) }
      canvas.asked = { [weak model] selector, allowed in model?.canvasAsked(selector, allowed: allowed) }
      model.visibleRect = { [weak canvas] in
        guard let canvas else { return .null }
        let zoom = canvas.zoomScale
        return CGRect(
          x: canvas.contentOffset.x / zoom, y: canvas.contentOffset.y / zoom, width: canvas.bounds.width / zoom,
          height: canvas.bounds.height / zoom)
      }
      model.zoom = { [weak canvas] in canvas?.zoomScale ?? 1 }
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
    canvas.backgroundColor = model.paper.color
    canvas.show(model.ghosts)
    canvas.showGrid(model.gridOn)
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
  /// ⌘V on a board that can be drawn on (stories 390, 394).
  fileprivate var pasted: ((String) -> Void)?
  /// #624: each command the system asks about, the first time it asks.
  fileprivate var asked: ((String, Bool) -> Void)?
  private var askedAlready: Set<String> = []
  private var opened = false
  /// Holds the ghosts in board points; scaled with the zoom so they sit on the drawing.
  private let ghostLayer = CALayer()
  private var shown: [String: CAShapeLayer] = [:]
  /// Story 407: one thin solid line, repeated each way by the GPU. Nothing is rasterised, and nothing changes between
  /// crossings of a line, so the grid costs next to nothing while drawing and panning. Made the first time it's asked for.
  private var grid: (holder: CALayer, across: CAReplicatorLayer, down: CAReplicatorLayer)?
  private var gridLaid: WhiteboardFrame.Grid?

  /// The first layout knows the screen's size: the view opens centred on the drawing.
  override func layoutSubviews() {
    super.layoutSubviews()
    layGrid()
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
    layGrid()
  }

  fileprivate func showGrid(_ on: Bool) {
    guard on != !(grid?.holder.isHidden ?? true) else { return }
    if grid == nil { grid = Self.makeGrid(in: layer) }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    grid?.holder.isHidden = !on
    CATransaction.commit()
    layGrid()
  }

  /// A grey that reads on a light or a dark background, whichever is behind it.
  private static func makeGrid(in parent: CALayer) -> (CALayer, CAReplicatorLayer, CAReplicatorLayer) {
    let holder = CALayer()
    let across = CAReplicatorLayer()
    let down = CAReplicatorLayer()
    for replicator in [across, down] {
      let line = CALayer()
      line.backgroundColor = UIColor(white: 0.5, alpha: 0.3).cgColor
      replicator.addSublayer(line)
      holder.addSublayer(replicator)
    }
    // Above the ink and under the ghosts: a layer behind the ink doesn't show through PencilKit's canvas (0 pixels on
    // the simulator, opaque or not), and a see-through canvas would blend the whole screen on every frame. A hair this
    // faint barely tints a stroke it crosses.
    holder.zPosition = 5
    parent.addSublayer(holder)
    return (holder, across, down)
  }

  private func layGrid() {
    guard let grid, !grid.holder.isHidden, bounds.width > 0 else { return }
    let wanted = WhiteboardFrame.grid(offset: contentOffset, viewport: bounds.size, zoom: zoomScale)
    guard wanted != gridLaid else { return }
    gridLaid = wanted
    let hair = 1 / traitCollection.displayScale
    let width = CGFloat(wanted.across) * wanted.gap
    let height = CGFloat(wanted.down) * wanted.gap
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    grid.holder.frame = CGRect(origin: wanted.origin, size: .zero)
    grid.across.instanceCount = wanted.across
    grid.across.instanceTransform = CATransform3DMakeTranslation(wanted.gap, 0, 0)
    grid.across.sublayers?.first?.frame = CGRect(x: 0, y: 0, width: hair, height: height)
    grid.down.instanceCount = wanted.down
    grid.down.instanceTransform = CATransform3DMakeTranslation(0, wanted.gap, 0)
    grid.down.sublayers?.first?.frame = CGRect(x: 0, y: 0, width: width, height: hair)
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

  // hasStrings asks without reading, so it shows no paste prompt.
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    let allowed = canPerform(action, sender)
    if askedAlready.insert(NSStringFromSelector(action)).inserted { asked?(NSStringFromSelector(action), allowed) }
    return allowed
  }

  private func canPerform(_ action: Selector, _ sender: Any?) -> Bool {
    if action == #selector(paste(_:)) {
      guard pasted != nil else { return false }
      return UIPasteboard.general.hasStrings || super.canPerformAction(action, withSender: sender)
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override func paste(_ sender: Any?) {
    guard let pasted else { return }
    if let text = UIPasteboard.general.string { pasted(text) } else { super.paste(sender) }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let toolPicker else { return }
    toolPicker.addObserver(self)
    toolPicker.setVisible(true, forFirstResponder: self)
    becomeFirstResponder()
  }
}
