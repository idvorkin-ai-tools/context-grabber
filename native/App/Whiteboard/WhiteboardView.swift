//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347): PencilKit's canvas and the system tool
//  picker on a board far bigger than the screen, saved a moment after each stroke, and sent to Larry as a new chat
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
  /// The last turn in a line: Larry's words, *Larry is looking…*, or ghosts not answering.
  @Published private(set) var turnNote: String?
  @Published private(set) var larryLooking = false
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
  /// What's on screen in board points, for a turn on an empty board; the canvas sets it.
  var visibleRect: (() -> CGRect)?
  /// Puts a kept ghost on the canvas (undoably); the canvas sets it.
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

  static let ghostsKey = "whiteboard_ghosts"
  /// How long the Pencil rests before Claude is asked.
  static let pause: Duration = .seconds(1)
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds =
    ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_GHOST_SECONDS"].flatMap(Double.init) ?? 30

  init(
    board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel, cockpit: String,
    callLive: @escaping @MainActor () -> Bool
  ) {
    self.callLive = callLive
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

  func larryTurn() {
    guard !larryLooking else { return }
    Task { await turn(.larry) }
  }

  static let ghostsAway = "Ghosts: the Cockpit isn't answering"
  private var threadKey: String { "whiteboard_thread_\(board.id)" }

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
    // ponytail: the board's thread in UserDefaults on this device; it moves to the board's index if boards ever
    // change hands.
    let thread = who == .larry ? UserDefaults.standard.string(forKey: threadKey) : nil
    if who == .larry {
      larryLooking = true
      turnNote = "Larry is looking…"
    }
    defer { if who == .larry { larryLooking = false } }
    let started = Date()
    let answer: WhiteboardTurn.Answer
    var read = ClaudesAnswer()
    do {
      let title = store.index.board(board.id)?.title ?? board.title
      let request =
        who == .claude
        ? try WhiteboardTurn.suggestRequest(
          title: WhiteboardSpeech.context(title: title, said: said), picture: png, width: image.cgImage?.width ?? 0,
          height: image.cgImage?.height ?? 0,
          cockpit: cockpit)
        : try WhiteboardTurn.request(
          who: who, board: board.id, title: title, picture: png, thread: thread, cockpit: cockpit)
      if who == .claude {
        read = await readClaude(request, started: started) { [weak self] shape, first in
          guard let self, self.pacer.generation == asked else { return }
          self.land([shape], who: .claude, rect: rect, scale: scale, first: first)
        }
        answer = read.answer
      } else {
        let (body, response) = try await URLSession.shared.data(for: request)
        answer = WhiteboardTurn.answer(status: (response as? HTTPURLResponse)?.statusCode, body: body, who: who)
      }
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
    case .shapes(let shapes, let say, let newThread):
      undelivered = nil
      event["ok"] = true
      event["shapes"] = shapes.count
      if !shapes.isEmpty { event["first_shape_ms"] = read.firstShapeMs ?? ms }
      turnFailing = false
      if who == .claude, turnNote == Self.ghostsAway { turnNote = nil }
      if who == .larry {
        if let newThread { UserDefaults.standard.set(newThread, forKey: threadKey) }
        turnNote = say.isEmpty ? (shapes.isEmpty ? "Larry has nothing to add" : nil) : "Larry: \(say)"
        if problem?.context == "WhiteboardView.larry" { problem = nil }
      }
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
          Task.isCancelled ? "no answer in \(Int(WhiteboardTurn.Who.claude.timeout)) s" : error.localizedDescription
      }
      return ClaudesAnswer(
        answer: reader.answer(error: failure), streamed: reader.streaming, firstShapeMs: firstShapeMs,
        broken: reader.broken(error: failure))
    }
    let deadline = Task {
      try? await Task.sleep(for: .seconds(WhiteboardTurn.Who.claude.timeout))
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
    saveTask?.cancel()
    if editable, dirty { save() }
  }

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
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

  /// Story 343: the whole drawing, dark ink on white whatever the iPad's mode, as a new thread with Larry, titled
  /// with the board's name.
  func send() {
    guard sent == nil, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    let ink = picture(rect: rect, scale: scale)
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    draft.text = store.index.board(board.id)?.title ?? board.title
    do {
      try inbox.add(&draft)
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
  private let callLive: AnyPublisher<Bool, Never>
  private let reportOpen: AnyPublisher<Bool, Never>

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit,
        callLive: { [weak app] in app?.call.snapshot.isActive ?? false }))
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
          .disabled(model.isEmpty || model.larryLooking)
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
    .onDisappear {
      model.stopMic(why: "closed")
      model.close()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        model.flush()
        model.stopMic(why: "background")
      }
    }
    .onReceive(callLive) { live in if live { model.stopMic(why: "call") } }
    .onReceive(reportOpen) { open in if open { model.stopMic(why: "report") } }
  }

  private var note: String? {
    let count = model.ghosts.count
    let parts = [
      model.turnNote,
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
      model.visibleRect = { [weak canvas] in
        guard let canvas else { return .null }
        let zoom = canvas.zoomScale
        return CGRect(
          x: canvas.contentOffset.x / zoom, y: canvas.contentOffset.y / zoom, width: canvas.bounds.width / zoom,
          height: canvas.bounds.height / zoom)
      }
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
