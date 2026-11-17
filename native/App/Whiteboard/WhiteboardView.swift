//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347, 658): a column of pages on PaperKit with the
//  system tool picker, saved a moment after each stroke, and sent to Larry on the board's chat thread holding its picture
//  (the Inbox's image path, so it waits in the outbox when the network is away). A board another device draws, or one
//  drawn on the old canvas (gone 2026-11-07), opens to look at only. Claude's ghosts after a pause or spoken words and Larry's turn come back
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
  /// The ghosts and the rules of Claude's turn: what shows, whose, for how long, and when Claude is asked (stories 344,
  /// 349, 351, 357, 358, 359, 367, 370). The host tests are `WhiteboardGhostTurnsTests`.
  @Published private(set) var turns: WhiteboardGhostTurns<Ghost> {
    didSet {
      if turns.ghosts.count != oldValue.ghosts.count {
        log.event(
          "whiteboard",
          [
            "action": "ghosts", "board": board.id, "count": turns.ghosts.count,
            "larry": turns.ghosts.filter { $0.who == .larry }.count,
          ])
      }
    }
  }
  /// Shapes Claude or Larry offered, faint on the board until a tap keeps one (stories 344, 349).
  var ghosts: [Ghost] { turns.ghosts }
  /// Story 344's switch, remembered across boards.
  var ghostsOn: Bool { turns.on }
  /// Story 407's switch, remembered per board on this device. Lines on the board, never in the drawing or a picture.
  @Published private(set) var gridOn: Bool
  /// On paper only: a board has a grid, ruled lines or neither.
  @Published private(set) var ruledOn: Bool
  /// The board's colour (story 378).
  @Published private(set) var paper: BoardPaper
  /// Who answers a pause: Haiku, Sonnet or Larry, the board's knob on the Cockpit (story 659).
  @Published private(set) var responder = WhiteboardResponderKnob()
  /// Larry's turn, one at a time, latest wins (story 662): while one is out the bar says he is looking.
  @Published private(set) var larry = WhiteboardLarryTurn()
  /// Larry's changes to the board, whoever sends them (stories 814–819): the board's revision (bumped on every change
  /// of the ink: what a held pause remembers, what a picture to Larry was of, and what his `base_rev` is checked against),
  /// the batches handled and the one held for the Pencil. Kept per board on this device.
  private var ops: BoardOpApplier {
    didSet { if ops != oldValue { opLedger.save(ops, board: board.id) } }
  }
  private let opLedger = BoardOpLedger()
  /// Where his changes come from: today his board replies; later his own rules inside the app (story 819).
  private var opSources: [any BoardOpSource] = [WebBoardOpSource()]
  /// The Pencil and taps since the last turn, for Larry (story 818).
  private var events = BoardEvents()
  /// His texts Igor kept, known by their glyphs' time (story 817).
  private(set) var texts: [BoardText]
  /// The names Larry knows moved strokes by: a move never renames a stroke (stories 814, 815); his drawn strokes go by
  /// his names (story 840).
  private(set) var strokeIDs: BoardStrokeIDs
  /// Larry's notes on strokes, kept as he wrote them (story 842).
  private(set) var strokeMeta: BoardStrokeMeta
  /// Story 855: the board's headers and their folds, kept on this device by their strokes' names.
  private(set) var headers: [BoardHeader]
  /// Each element's ink hashes, to tell Larry what Igor added, erased and moved (story 843).
  private var ink = BoardInk()
  /// The lasso's selection as last told (story 844).
  private var selection: Set<String> = []
  /// Larry's controls on the board (story 845): live only while it is open.
  private(set) var overlays = BoardOverlays()
  /// Shows Larry's controls; the canvas sets it.
  var showOverlays: (([BoardOverlay]) -> Void)?
  /// The part of the board on screen as last told (story 850).
  private var lastViewport: (rect: CGRect, scale: CGFloat)?
  /// The Pencil (or a drawing finger) is down, and when it last lifted: a change of Larry's waits for it (story 816).
  private var penDown = false
  private var liftedAt: ContinuousClock.Instant?
  private var heldTask: Task<Void, Never>?
  /// The last turn in a line: Larry's words or ghosts not answering.
  var turnNote: String? { turns.note }
  /// The picture is on its way to Larry's thread.
  @Published private(set) var larrySending = false
  /// Twenty seconds into his turn, what the board offers: Retry and Dismiss for a picture the Cockpit hasn't taken,
  /// Interrupt for one he has (stories 775–777). Changed by the looks, every few seconds, and by the buttons.
  @Published private(set) var larryWait = WhiteboardLarryWait.none
  /// The picture out to Larry: what *Retry* sends again, and the furthest mark the Cockpit has put on its message.
  private var larryOut: LarryOut?
  /// Counts the hand-offs, so one that Retry, Dismiss or Interrupt has replaced never frees the turn or speaks for the
  /// board.
  private var larryHandOffs = WhiteboardLarryHandOffs()
  private var larryWaitHook = LaunchHooks.current.whiteboard.larryWait
  /// On paper: ink on the board, none of it on screen, so Send and Larry's turn have nothing to show him (story 522).
  @Published private(set) var nothingOnScreen = false
  /// Looking at Larry's thread has failed for a while (story 383).
  @Published private(set) var larryAway = false
  /// What the last paste left off or couldn't draw, shown until the board next changes (stories 392, 393).
  @Published private(set) var pasteNote: String?
  /// The board's mic (story 345): open, on its way up and finishing its last words.
  @Published private(set) var micOn = false
  @Published private(set) var micStarting = false
  @Published private(set) var micFinishing = false
  /// The newest thing said, by Larry or the mic: the middle of the note's line (story 766).
  @Published private(set) var lastSaid = WhiteboardSaid()
  /// The note's other messages and when they appeared: they take the line's middle for a few seconds, or for as long
  /// as the Cockpit isn't answering (story 766).
  @Published private(set) var notice: WhiteboardNote.Notice?
  /// The recent end of the board's thread, from the looks that bring Larry's marks: the open note's panel (story 768).
  @Published private(set) var thread: [ChatMessage] = []
  /// The note's panel is open, remembered for the next board (story 768).
  @Published private(set) var conversationOpen = UserDefaults.standard.bool(forKey: WhiteboardModel.conversationKey)
  let board: BoardEntry
  /// Drawn on here, or only looked at: a board from another device (story 347) or from the old canvas (story 658).
  let editable: Bool
  /// Drawn on the old canvas: its ink is moved onto pages to be shown, and it can't be sent (story 658).
  let oldCanvas: Bool
  /// Why it's only looked at, for the bar; nil on a board drawn on here.
  let lookOnlyNote: String?
  @Published private(set) var drawing: PKDrawing
  /// Larry's open asks as cards on the board (stories 880–886).
  let questions: WhiteboardQuestionsModel
  private let store: WhiteboardStore
  private let log: SessionLog
  private let inbox: InboxModel
  private let cockpit: String
  private let threads = WhiteboardThreads()
  /// What's on screen in board points, for a turn on an empty board or a paste, and the zoom; the canvas sets them.
  var visibleRect: (() -> CGRect)?
  var zoom: (() -> CGFloat)?
  /// Where a paste may land, in board points; a board on paper sets its own.
  var pasteReach = WhiteboardPaste.wholeBoard
  /// Puts a kept ghost or a paste on the canvas (undoably), given the whole drawing and what's new in it; the canvas sets
  /// it.
  var draw: ((PKDrawing, [PKStroke]) -> Void)?
  /// Plans a batch of Larry's changes on the canvas and applies it as one undo named for it; nil with no canvas yet.
  /// The canvas sets it.
  var applyOps: ((BoardOps.Batch) -> BoardOps.Plan?)?
  /// Story 852: a paste on paper lands clear of ink or opens room for itself, in one undo, and comes back as the whole
  /// drawing; nil where it can't (no paper laid out), and the paste is added as it was placed.
  var landPaste: (([PKStroke]) -> Bool)?
  /// Stories 855–860: a change to the outline (a header made, folded, unfolded, the outline collapsed) on the canvas
  /// as one undo named for it; false when nothing changed. The canvas sets it.
  var changeOutline: ((String, (inout BoardOutline) -> Bool) -> Bool)?
  /// Story 896: the strokes at these places in the drawing moved down so far, one undo.
  var move: (([Int: CGFloat]) -> Void)?
  /// Something was chosen in the Board menu, the colour already chosen too; a board on paper sets it.
  var menuChose: (() -> Void)?
  private let callLive: @MainActor () -> Bool
  private lazy var dictation = makeDictation()
  private var dictationWatches: Set<AnyCancellable> = []
  private var noticeWatch: AnyCancellable?
  private var speech = WhiteboardSpeech()
  private var silenceTask: Task<Void, Never>?
  private var pauseTask: Task<Void, Never>?
  /// Stories 892, 893: how long the pause waits, learned from his rhythm, and the look for his hand having left.
  private var vad = WhiteboardWritingVad()
  private var awayTask: Task<Void, Never>?
  /// Claude's answer being read, which the Pencil going down stops (story 894).
  private var claudeReading: Task<WhiteboardStream.Read, Never>?
  private var fadeTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  /// Ink not saved yet; a board on paper's page number says so (story 673: what a UI test waits on, not a fixed second).
  @Published private(set) var dirty = false
  private var saveFailing = false
  private var marks = WhiteboardMarks()
  /// On paper: each stroke's box, for what's on screen (story 433), and the frame the last Send showed.
  private var inkBoxes: [CGRect] = []
  private var sentFrame: CGRect?
  /// The part of the board in the picture Larry's turn last took: a tap with another part on screen sends (story 765).
  private var larryFrame: CGRect?
  /// The row his showing marks came from.
  private var shownRow: String?
  private var watchTask: Task<Void, Never>?
  private var lookFailures = 0

  static let ghostsKey = "whiteboard_ghosts"
  static let conversationKey = "whiteboard_conversation_open"
  /// A pasted letter's height on screen, in points, at 100% and zoomed out.
  static let pasteLetters: CGFloat = 24
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds = LaunchHooks.current.whiteboard.ghostSeconds ?? 30
  /// How long a turn of Larry's is out before the board stops waiting.
  static let larryTimeout: Duration =
    LaunchHooks.current.whiteboard.larryTimeout.map { .seconds($0.seconds) } ?? WhiteboardLarryTurn.timeout
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
    questions = WhiteboardQuestionsModel(board: board.id, log: log, inbox: inbox, cockpit: cockpit)
    turns = WhiteboardGhostTurns(
      on: UserDefaults.standard.object(forKey: Self.ghostsKey) as? Bool ?? true, ghostLife: .seconds(Self.ghostSeconds))
    let lines = BoardLines().choice(board.id)
    gridOn = lines == .grid
    ruledOn = lines == .ruled
    editable = store.drawable(board)
    oldCanvas = BoardIndex.drawnOnTheOldCanvas(board)
    lookOnlyNote = store.lookOnlyNote(board)
    ops = opLedger.applier(board: board.id)
    texts = opLedger.texts(board: board.id)
    strokeIDs = opLedger.strokeIDs(board: board.id)
    strokeMeta = opLedger.strokeMeta(board: board.id)
    headers = opLedger.headers(board: board.id)
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
    inkBoxes = loaded.strokes.map(\.renderBounds)
    log.event(
      "whiteboard",
      [
        "action": "open", "board": board.id, "strokes": loaded.strokes.count, "editable": editable,
        "old_canvas": oldCanvas, "look_only": lookOnlyNote as Any? ?? NSNull(),
      ])
    if LaunchHooks.current.whiteboard.grid { setGrid(true) }
    watchNotices()
  }

  /// Story 766: when the note's other messages change, so a new one takes the line's middle for its few seconds.
  private func watchNotices() {
    let lookOnly = lookOnlyNote
    noticeWatch = $pasteNote.combineLatest($sent, $turns.map(\.note), $larryAway.combineLatest($larry.map(\.looking)))
      .map { paste, sent, turnNote, away in
        WhiteboardNote.notice(
          paste: paste, sent: sent, turnNote: turnNote, marksAway: away.0, looking: away.1, lookOnly: lookOnly)
      }
      .removeDuplicates { $0?.text == $1?.text }
      .sink { [weak self] words in
        MainActor.assumeIsolated {
          self?.notice = words.map { WhiteboardNote.Notice(text: $0.text, held: $0.held, since: .now) }
        }
      }
  }

  /// Story 773: where the picture Larry is looking at is, from its mark on the thread the board last read (with the
  /// Cockpit not answering, the last it knew) and whether its sending was answered. The one reading the note's state
  /// and the 20-second controls share. A picture the board handed over itself is found by its id; a *Send to Larry*'s
  /// by Igor's newest message since it went.
  func larryMark(now: ContinuousClock.Instant) -> WhiteboardLarryWait.Mark {
    let out = larryOut.flatMap { $0.turn == larry.state ? $0 : nil }
    return WhiteboardLarryWait.mark(
      larry, thread: thread, now: now, wallNow: Date(), picture: out?.picture.pictureID,
      delivered: out?.delivered ?? false, earlier: out?.receipt ?? .sent)
  }

  /// The board has a thread with Larry on this device.
  var threadKey: String? { threads.thread(board: board.id) }

  /// Story 768: a tap on the note's line opens or closes the panel over the board, remembered for the next board; an
  /// iPhone has no panel, so it opens the board's thread in Chat.
  func tapNote(onPhone: Bool, openChat: (String) -> Void) {
    switch WhiteboardNote.tap(onPhone: onPhone, thread: threadKey) {
    case .toggle:
      conversationOpen.toggle()
      UserDefaults.standard.set(conversationOpen, forKey: Self.conversationKey)
      log.event(
        "whiteboard",
        ["action": "conversation", "board": board.id, "open": conversationOpen, "messages": thread.count])
    case .openChat(let key):
      log.event("whiteboard", ["action": "conversation_chat", "board": board.id, "thread": key])
      openChat(key)
    case .nothing:
      log.event("whiteboard", ["action": "conversation_chat", "board": board.id, "thread": ""])
    }
  }

  func changed(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    let added = new.strokes.count > drawing.strokes.count
    logStrokesMoved(to: new)
    drawing = new
    if added, let last = new.strokes.last { vad.stroke(last.renderBounds) }
    if added, turns.stroked() { startPause() }
    drawingMoved()
  }

  /// Kept ink as the canvas reads it back. Nothing to ask about or save that the keep hasn't already started.
  func settled(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    inkMoved()
  }

  /// A kept mark undone or redone on paper: saved like any change, and not a stroke for Claude to answer.
  func stepped(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
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

  private func drawingMoved() {
    ops.changed()
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    sentFrame = nil
    inkMoved()
    pasteNote = nil
    dirty = true
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  /// The ink changed: what's on screen may have too.
  private func inkMoved() {
    inkBoxes = drawing.strokes.map(\.renderBounds)
    screenMoved()
  }

  /// On paper, the view moved or the ink changed (story 433): what Send and Larry's turn would show. A Send already made is
  /// of the pages it showed, so another page on screen can be sent too.
  func screenMoved() {
    let frame = pictureFrame()?.rect
    let nothing = !drawing.strokes.isEmpty && frame == nil
    if nothing != nothingOnScreen { nothingOnScreen = nothing }
    if let sentFrame, sentFrame != frame {
      self.sentFrame = nil
      sent = nil
    }
  }

  /// Larry's picture, for Send and his turn: the pages on screen (story 433). Claude's own turns frame theirs as they
  /// always have.
  private func pictureFrame() -> (rect: CGRect, scale: CGFloat)? {
    BoardPages().picture(visible: visibleRect?() ?? .null, ink: inkBoxes)
  }

  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts.
  func beganDrawing() {
    penWent(down: true)
    vad.down(at: .now)
    // Story 894: writing again makes the picture of a turn still out stale.
    if turns.penCancelsTurn() {
      claudeReading?.cancel()
      log.event("whiteboard", ["action": "turn_cancelled", "board": board.id, "why": "pen_down"])
    }
    if turns.toolWentDown() {
      log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "away", "why": "drew"])
    }
    cancelPause()
  }

  func endedDrawing() {
    penWent(down: false)
    vad.lifted(at: .now)
    if turns.toolLifted() { startPause() }
  }

  /// A pause still waiting is forgotten; `turns` has made an answer on its way stale.
  private func cancelPause() {
    pauseTask?.cancel()
    pauseTask = nil
    awayTask?.cancel()
    vad.pauseOver()
  }

  /// Story 892: the pause waits as long as his rhythm says, from 1.5 to 5 s.
  private func startPause() {
    let started = ContinuousClock.now
    let pause = vad.pauseStarted(at: started)
    log.event(
      "whiteboard", ["action": "vad", "board": board.id, "ms": pause.ms, "cue": pause.cue, "median": pause.median])
    waitPause(pause.duration, from: started)
    if vad.hoverSeen { lookForTheHand() }
  }

  private func waitPause(_ span: Duration, from started: ContinuousClock.Instant) {
    pauseTask?.cancel()
    pauseTask = Task { [weak self] in
      try? await Task.sleep(for: span)
      guard !Task.isCancelled, let self else { return }
      self.pauseTask = nil
      self.awayTask?.cancel()
      self.vad.pauseOver()
      // Story 661: how long the pause really waited, the timer's own lateness included.
      if self.turns.pauseEnded() { await self.turn(.claude, paused: started.duration(to: .now)) }
    }
  }

  /// Story 893: an end-of-thought cue cuts the pause to the floor, counted from the lift.
  private func cue(_ name: String, left: Duration) {
    guard pauseTask != nil else { return }
    log.event(
      "whiteboard", ["action": "vad", "board": board.id, "cue": name, "left_ms": WhiteboardTimings.ms(left) ?? 0])
    waitPause(left, from: .now - (WhiteboardWritingVad.floor - left))
  }

  /// The hovering Pencil, in board points: seen, and maybe back at the start of a new line (story 893).
  func hovered(at point: CGPoint) {
    if let left = vad.hovered(at: point, now: .now) { cue("new line", left: left) }
    if pauseTask != nil { lookForTheHand() }
  }

  /// A second with no Pencil near the paper, on an iPad whose hover shows it: his hand has left.
  private func lookForTheHand() {
    awayTask?.cancel()
    awayTask = Task { [weak self] in
      try? await Task.sleep(for: WhiteboardWritingVad.awayAfter)
      guard !Task.isCancelled, let self, let left = self.vad.lookedForTheHand(now: .now) else { return }
      self.cue("hand away", left: left)
    }
  }

  func setGhosts(_ on: Bool) {
    UserDefaults.standard.set(on, forKey: Self.ghostsKey)
    log.event("whiteboard", ["action": on ? "ghosts_on" : "ghosts_off", "board": board.id])
    turns.setOn(on)
    if !on {
      cancelPause()
      larry.dropped()
      if micOn || micStarting {
        turns.micClosedByGhostsOff()
        stopMic(why: "ghosts_off")
      }
    }
  }

  func setRuled(_ on: Bool) {
    ruledOn = on
    log.event("whiteboard", ["action": on ? "ruled_on" : "ruled_off", "board": board.id])
    if on, gridOn { setGrid(false) }
    saveLines()
  }

  func setGrid(_ on: Bool) {
    gridOn = on
    log.event("whiteboard", ["action": on ? "grid_on" : "grid_off", "board": board.id])
    if on, ruledOn { setRuled(false) }
    saveLines()
  }

  private func saveLines() {
    BoardLines().set(gridOn ? .grid : ruledOn ? .ruled : .none, board: board.id)
  }

  func setPaper(_ new: BoardPaper) {
    guard editable, new != paper else { return }
    paper = new
    store.setPaper(new, board: board.id)
    log.event("whiteboard", ["action": "paper", "board": board.id, "paper": new.rawValue])
  }

  /// Story 380: the picture goes to the board's thread and Igor keeps drawing; Larry's marks come when they come. It
  /// goes now, whatever a Larry board was holding for his answer, and takes the words that waited (story 662), unless
  /// he is already looking at this very board (story 765).
  func larryTurn() {
    guard !larrySending else { return }
    let moved = pictureFrame().map { $0.rect != larryFrame } ?? false
    guard case .send(let words) = larry.tapped(version: ops.rev, moved: moved, now: .now) else {
      return alreadyHas(from: "button")
    }
    let turn = larry.state
    Task { await handToLarry(turn, said: words) }
    checkLarryWait()
  }

  /// Story 765: a tap that sent nothing, because Larry is looking at this part of the board as it is and no words wait.
  /// The note says *Larry already has this* for two seconds (`WhiteboardLarryClock`).
  private func alreadyHas(from: String) {
    var event: [String: Any] = ["action": "larry_already_has", "board": board.id, "from": from]
    if case .awaiting(let since, _) = larry.state {
      event["looking_s"] = Int((ContinuousClock.now - since).components.seconds)
    }
    log.event("whiteboard", event)
  }

  /// The turn `larry` has already counted as out: `said`, words spoken to a Larry board, go as the picture's message
  /// (story 659). `from`: the button, a pause on a Larry board, or the picture that follows his answer or a timeout
  /// (story 662). One that doesn't reach him frees the turn and keeps its words for the next.
  /// `again`: *Retry* (story 775), the very picture that went before, under the same message id.
  private func handToLarry(
    _ turn: WhiteboardLarryTurn.State, said: String?, from: String = "button", again: LarryOut? = nil
  ) async {
    guard editable, let out = again ?? larryPicture(said: said) else {
      larry.failed(turn, words: said)
      return
    }
    let attempt = larryHandOffs.begin()
    larryOut = out
    larryOut?.turn = turn
    larryOut?.attempt = attempt
    larrySending = true
    defer { if larryHandOffs.isLatest(attempt) { larrySending = false } }
    let (jpeg, strokes, picture, rect, scale) = (out.jpeg, out.strokes, out.picture, out.rect, out.scale)
    let folds = out.folds
    let thread = threads.thread(board: board.id)
    let started = Date()
    var event: [String: Any] = [
      "who": "larry", "board": board.id, "bytes": jpeg.count, "picture": picture.pictureID, "new_thread": thread == nil,
      "pixels": "\(Int(rect.width * scale))x\(Int(rect.height * scale))", "from": from, "said_chars": said?.count ?? 0,
      "rev": picture.report?.rev ?? -1, "events": picture.report?.events.count ?? 0,
      "op_result": picture.report?.opResult?.label ?? "",
    ]
    defer {
      event["ms"] = Int(Date().timeIntervalSince(started) * 1000)
      log.event("whiteboard_turn", event)
    }
    // Story 419: the strokes first, under this picture's id; the picture goes whatever they answered.
    event.merge(WhiteboardStrokes.logFields(await sendStrokes(strokes, folds: folds, picture: picture))) { $1 }
    if !folds.isEmpty { event["folds"] = folds.count }
    let outcome = await deliver(jpeg, picture: picture, thread: thread, note: said ?? "Your turn on the board")
    shipLog(why: "larry_turn")
    switch outcome {
    case .sent(let key, _):
      event["ok"] = true
      event["thread"] = key
      threads.set(key, board: board.id)
      // The Cockpit has the picture (story 775): it isn't stuck. Kept apart from the marks the thread shows, so a
      // Cockpit that marks nothing never reads *Sent* (story 773).
      if larryOut?.picture.pictureID == picture.pictureID { larryOut?.delivered = true }
      turns.larryReached()
      if problem?.context == "WhiteboardView.larry" { problem = nil }
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      // A thread the Cockpit no longer has: the next turn starts a new one.
      if status == 404, let thread { threads.forget(thread, board: board.id) }
      // Retry, Dismiss or Interrupt took this one over (stories 775–777): its words went with the retry or back in the
      // queue.
      guard larryHandOffs.speaks(attempt) else {
        event["superseded"] = true
        return
      }
      larry.failed(turn, words: said)
      failed(
        .larry, "The Cockpit refused the turn (\(status)): \(reason)", status: status,
        first: turns.failed(.larry, stale: false))
    case .retry(let reason):
      event["ok"] = false
      event["reason"] = reason
      // Retry, Dismiss or Interrupt took over while this one hung (stories 775–777): its failure is no longer the board's. One a
      // newer picture replaced still keeps its words, and its turn is freed only if it is still the one out.
      guard larryHandOffs.speaks(attempt) else {
        event["superseded"] = true
        return
      }
      larry.failed(turn, words: said)
      failed(.larry, "Larry couldn't be reached: \(reason)", status: nil, first: turns.failed(.larry, stale: false))
    }
  }

  /// #883: the whiteboard's log lines since the last the archive took, to the Cockpit's archive (`whiteboard.log`), each
  /// time a picture goes to Larry, so he reads what the board did without Igor pulling the log. One try; lines not
  /// taken go with the next picture. Nothing goes from a simulator or a Mac without GRABBER_ARCHIVE_URL.
  private func shipLog(why: String) {
    let lines = log.whiteboardUnsent()
    guard let last = lines.last else { return }
    var event: [String: Any] = ["why": why, "board": board.id, "records": lines.count, "launch": log.launch]
    guard let archive = ArchiveModel.destination(ProcessInfo.processInfo.environment) else {
      event["ok"] = false
      event["reason"] = "no archive URL"
      log.event("whiteboard_log", event)
      return
    }
    let device = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? "unknown-device"
    let batch = ArchiveBatch(
      stream: WhiteboardLogArchive.stream, deviceId: device,
      records: WhiteboardLogArchive.records(
        lines, launch: log.launch,
        build: [
          "app": BuildInfo.version, "sha": BuildInfo.sha, "branch": BuildInfo.branch,
          "system": UIDevice.current.systemVersion, "device": UIDevice.current.model,
        ]))
    let log = log
    Task { [event] in
      var event = event
      let outcome: ArchiveSend.Outcome
      do {
        let (body, response) = try await URLSession.shared.data(for: try ArchiveSend.request(batch, cockpit: archive))
        outcome = ArchiveSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: body)
      } catch {
        outcome = .retry(reason: error.localizedDescription)
      }
      switch outcome {
      case .taken(let inserted, let duplicate):
        log.whiteboardSent(through: last.seq)
        event["ok"] = true
        event["inserted"] = inserted
        event["duplicate"] = duplicate
      case .refused(let status, let reason):
        event["ok"] = false
        event["status"] = status
        event["reason"] = reason
      case .retry(let reason):
        event["ok"] = false
        event["reason"] = reason
      }
      log.event("whiteboard_log", event)
    }
  }

  /// Story 419: the board's strokes to the Cockpit under the picture's id. Never a reason not to send the picture.
  private func sendStrokes(_ strokes: [[String: Any]], folds: [[String: Any]] = [], picture: WhiteboardPicture) async
    -> WhiteboardStrokes.Answer
  {
    do {
      let request = try WhiteboardStrokes.request(picture: picture, strokes: strokes, folds: folds, cockpit: cockpit)
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
  /// By the names Larry knows them: a stroke Larry's changes moved keeps the one it had.
  /// Story 857: what is folded goes under its header in `folds`, never as strokes, so it is neither erased nor new.
  private func strokesForLarry() -> [WhiteboardStrokes.Stroke] {
    let all = strokeIDs.named(Self.strokesForLarry(drawing))
    guard headers.contains(where: { $0.fold != nil }) else { return all }
    let folded = outline().foldedNames
    return all.filter { !folded.contains($0.id) }
  }

  /// The folds as Larry gets them with the strokes.
  private func foldsForLarry() -> [[String: Any]] {
    headers.contains { $0.fold != nil } ? outline().wire : []
  }

  static func strokesForLarry(_ drawing: PKDrawing) -> [WhiteboardStrokes.Stroke] {
    drawing.strokes.flatMap { stroke -> [WhiteboardStrokes.Stroke] in
      let color = lightHex(stroke.ink.color)
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
        // Story 847: Larry's fold leaves the ink on the board with no colour to see.
        return WhiteboardStrokes.Stroke(
          id: WhiteboardStrokes.id(points: points, color: color, t: t), t: t, color: color, width: width, tool: tool,
          points: points, hidden: stroke.ink.color.cgColor.alpha == 0)
      }
    }
  }

  /// The picture uploaded, then the message that names it.
  private func deliver(
    _ jpeg: Data, picture: WhiteboardPicture, thread: String?, note: String
  ) async -> ChatSend.Outcome {
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try ChatSend.uploadRequest(image: jpeg, cockpit: cockpit))
      switch ChatSend.upload(status: (response as? HTTPURLResponse)?.statusCode, body: body) {
      case .refused(let status, let reason): return .refused(status: status, reason: reason)
      case .retry(let reason): return .retry(reason: "image upload: \(reason)")
      case .ref(let ref):
        // The message's id is the picture's, so *Retry* sending it again is the same message to the Cockpit (story 775).
        let item = InboxItem(
          id: picture.pictureID, kind: .image, sharedAt: Int64(Date().timeIntervalSince1970 * 1000), note: note,
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
    Task { [questions] in await questions.sync(reason: "open") }
    watchTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.lookAtThread()
        self?.larryTimedOut()
        self?.checkLarryWait()
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
        let messages = ChatWire.messages(body) ?? []
        if let out = larryOut, let mark = WhiteboardLarryWait.receipt(of: out.picture.pictureID, in: messages) {
          larryOut?.receipt = out.receipt.atLeast(mark)
        }
        let recent = Array(messages.suffix(WhiteboardNote.panelMessages))
        if recent != self.thread { self.thread = recent }
        lookWorked(rows)
        questions.looked(body)
        larryClosed(messages)
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
    self.thread = []
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
    turns.larrySaid(update.say, marks: update.marks != nil)
    lastSaid.larrySaid(update.say, marks: update.marks != nil)
    // Story 762: his silence is said until he next answers.
    if update.replied, problem?.context == WhiteboardLarryClock.DidntAnswer.context { problem = nil }
    // A row landing while a picture is still going up answers an earlier one: the turn on its way stays out.
    if update.replied, !larrySending { larryFollowUp(larry.replied(version: ops.rev, now: .now), why: "reply") }
    // After the follow-up is decided (his own change to the board is never Igor moving on) and after the row's marks
    // show (his text joins them rather than being replaced by them).
    defer { takeOps(.rows(rows)) }
    guard let row = update.marks, let frame = row.frame else { return }
    // Each author's new marks replace only their own, placed by the row's own frame: where that picture was.
    shownRow = row.id
    let settled = Set(UserDefaults.standard.stringArray(forKey: settledMarksKey) ?? [])
    turns.larrysMarks(
      row.shapes.enumerated().map { index, shape in
        Ghost(shape, who: .larry, frame: frame, scale: row.scale, id: WhiteboardMarks.mark(index, of: row.id))
      }.filter { !settled.contains($0.id) })
    log.event(
      "whiteboard_marks",
      [
        "action": "shown", "board": board.id, "row": row.id, "shapes": row.shapes.count,
        "picture": row.pictureID ?? "",
      ])
  }

  /// #913 (story 662): Larry marked the picture he is looking at done and wrote nothing after it. The turn ends as an
  /// answer with no shapes would. Runs after the look's rows, so a reply landing in the same look has already ended the
  /// turn and this finds no turn out.
  private func larryClosed(_ messages: [ChatMessage]) {
    guard case .awaiting(let since, _) = larry.state, let out = larryOut, out.turn == larry.state,
      WhiteboardLarryWait.doneWithoutReply(out.picture.pictureID, in: messages)
    else { return }
    let looking = Int((ContinuousClock.now - since).components.seconds)
    larryFollowUp(
      larry.closed(version: ops.rev, now: .now), why: "done_no_reply",
      facts: ["picture": out.picture.pictureID, "looking_s": looking])
    checkLarryWait()
  }

  /// Story 662: his turn has been out too long; the board stops waiting, as if he had answered. Story 669: and says so,
  /// as a copyable problem that stays until he next answers or Igor dismisses it, whatever picture goes next.
  private func larryTimedOut() {
    let now = ContinuousClock.now
    let waiting = larry
    let mark = larryMark(now: now)
    guard let next = larry.tick(version: ops.rev, now: now, timeout: Self.larryTimeout) else { return }
    var facts: [String: Any] = [:]
    if let silence = WhiteboardLarryClock.didntAnswer(
      waiting, now: now, wallNow: Date(), cockpitAnswering: !larryAway, mark: mark)
    {
      let sentAt = silence.sentAt.formatted(.iso8601)
      facts = [
        "problem": silence.context, "sent_at": sentAt, "waited_s": silence.waitedSeconds,
        "ink_waiting": silence.inkWaiting, "words_waiting": silence.wordsWaiting,
        "cockpit_answering": silence.cockpitAnswering, "mark": silence.mark.rawValue,
      ]
      problem = .grabber(
        silence.message, context: silence.context,
        extra: [
          "board": .string(board.id), "cockpit": .string(cockpit), "sent_at": .string(sentAt),
          "waited_s": .int(silence.waitedSeconds), "ink_waiting": .bool(silence.inkWaiting),
          "words_waiting": .bool(silence.wordsWaiting), "cockpit_answering": .bool(silence.cockpitAnswering),
          "mark": .string(silence.mark.rawValue),
        ])
    }
    larryFollowUp(next, why: "timeout", facts: facts)
    dismissSoonForTests()
  }

  /// `GRABBER_WHITEBOARD_LARRY_TIMEOUT=<seconds>,dismiss`: *Larry didn't answer* goes 3 s after it shows, as a tap on
  /// *Dismiss* would take it, for the simulator.
  private func dismissSoonForTests() {
    guard LaunchHooks.current.whiteboard.larryTimeout?.dismiss == true else { return }
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard let self, self.problem?.context == WhiteboardLarryClock.DidntAnswer.context else { return }
      self.dismissProblem()
    }
  }

  /// Igor dismissed *Larry didn't answer* (story 761).
  func dismissProblem() {
    log.event("whiteboard", ["action": "problem_dismissed", "board": board.id, "context": problem?.context ?? ""])
    problem = nil
  }

  /// Stories 775–777: twenty seconds into his turn, what where the picture is says to offer (the same reading as the
  /// note's state, story 773). Logged, and the stuck picture's problem shown or taken away, only when it changes: the
  /// problem slot holds one, the newest wins, and this takes away only its own.
  private func checkLarryWait() {
    let now = ContinuousClock.now
    let out = larryOut.flatMap { $0.turn == larry.state ? $0 : nil }
    let mark = larryMark(now: now)
    let wait = out == nil ? .none : WhiteboardLarryWait.of(larry, mark: mark, now: now)
    guard wait != larryWait else { return }
    var event: [String: Any] = [
      "action": "larry_wait", "board": board.id, "wait": wait.rawValue, "was": larryWait.rawValue,
      "mark": mark.rawValue, "picture": out?.picture.pictureID ?? "", "sending": larrySending,
      "cockpit_answering": !larryAway,
    ]
    if case .awaiting(let since, _) = larry.state { event["looking_s"] = Int((now - since).components.seconds) }
    log.event("whiteboard", event)
    larryWait = wait
    if wait == .stuck, case .awaiting(let since, _) = larry.state {
      let waited = Int((now - since).components.seconds)
      problem = .grabber(
        WhiteboardLarryWait.stuckMessage, context: WhiteboardLarryWait.stuckContext,
        extra: [
          "board": .string(board.id), "cockpit": .string(cockpit),
          "picture": .string(out?.picture.pictureID ?? ""),
          "sent_at": .string((Date() - TimeInterval(waited)).formatted(.iso8601)), "waited_s": .int(waited),
          "sending": .bool(larrySending), "cockpit_answering": .bool(!larryAway), "mark": .string(mark.rawValue),
        ])
    } else if problem?.context == WhiteboardLarryWait.stuckContext {
      problem = nil
    }
    pressSoonForTests()
  }

  /// `GRABBER_WHITEBOARD_LARRY_WAIT=retry` / `dismiss` / `interrupt`: that control taps itself, once, 3 s after the board
  /// first offers it, for the simulator.
  private func pressSoonForTests() {
    guard let press = larryWaitHook, larryWait == (press == .interrupt ? .working : .stuck) else { return }
    larryWaitHook = nil
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      switch press {
      case .retry: self?.retryLarry()
      case .dismiss: self?.dismissStuck()
      case .interrupt: self?.interruptLarry()
      }
    }
  }

  /// *Retry* (story 775): the same picture again, under the same message id, so a first one that did land is kept once;
  /// the clock and the twenty seconds start again. A hand-off still hanging is left to end on its own, and replaced.
  func retryLarry() {
    checkLarryWait()
    guard larryWait == .stuck, let out = larryOut, larry.resent(now: .now) else { return }
    log.event(
      "whiteboard",
      [
        "action": "larry_retry", "board": board.id, "picture": out.picture.pictureID, "sending": larrySending,
        "receipt": out.receipt.rawValue,
      ])
    larryHandOffs.replace(out.attempt)
    let turn = larry.state
    larryOut?.turn = turn
    Task { await handToLarry(turn, said: out.said, from: "retry", again: out) }
    checkLarryWait()
  }

  /// *Dismiss* on a stuck picture (story 776): the board stops waiting. The turn is free, the words that went with it
  /// wait for the next picture, and a hand-off still hanging no longer speaks for the board.
  func dismissStuck() {
    checkLarryWait()
    guard larryWait == .stuck else { return }
    log.event(
      "whiteboard",
      [
        "action": "larry_dismiss", "board": board.id, "picture": larryOut?.picture.pictureID ?? "",
        "sending": larrySending,
      ])
    if let out = larryOut { larryHandOffs.replace(out.attempt) }
    larrySending = false
    larry.failed(larry.state, words: larryOut?.said)
    larryOut = nil
    checkLarryWait()
  }

  /// *Interrupt* (story 777): Larry has the picture and the board stops waiting for his answer, so the next pause or tap
  /// is a fresh ask. What he draws or says later still lands. A picture whose sending hasn't been answered is let go of
  /// as *Dismiss* lets go: its hand-off no longer speaks for the board, and its words wait for the next picture unless
  /// the Cockpit's mark says it has them.
  func interruptLarry() {
    checkLarryWait()
    guard larryWait == .working else { return }
    var event: [String: Any] = [
      "action": "larry_interrupt", "board": board.id, "picture": larryOut?.picture.pictureID ?? "",
      "mark": larryMark(now: .now).rawValue, "sending": larrySending,
    ]
    if case .awaiting(let since, _) = larry.state {
      event["looking_s"] = Int((ContinuousClock.now - since).components.seconds)
    }
    guard larry.interrupted() else { return }
    log.event("whiteboard", event)
    if let out = larryOut {
      larryHandOffs.replace(out.attempt)
      larrySending = false
      if !out.delivered, out.receipt == .sent { larry.failed(larry.state, words: out.said) }
    }
    larryOut = nil
    checkLarryWait()
  }

  /// The picture of the board on screen for Larry, its strokes and its id; nil with nothing on screen to show him.
  private func larryPicture(said: String?) -> LarryOut? {
    guard let (rect, scale) = pictureFrame() else { return nil }
    larryFrame = rect
    // ponytail: rendered and encoded on the main thread, as the ghost turn is.
    let jpeg = picture(rect: rect, scale: scale).jpegData(compressionQuality: 0.85) ?? Data()
    let picture = WhiteboardPicture(
      board: board.id, title: store.index.board(board.id)?.title ?? board.title, rect: rect, scale: scale,
      report: turnReport())
    return LarryOut(
      jpeg: jpeg, strokes: WhiteboardStrokes.wire(strokesForLarry(), texts: texts, metas: strokeMeta),
      folds: foldsForLarry(), picture: picture, rect: rect,
      scale: scale, said: said)
  }

  /// A picture handed to Larry, kept while his turn on it is out: *Retry* sends exactly this again (story 775).
  struct LarryOut {
    let jpeg: Data
    let strokes: [[String: Any]]
    /// The folded sections, beside the strokes (story 857).
    var folds: [[String: Any]] = []
    let picture: WhiteboardPicture
    let rect: CGRect
    let scale: CGFloat
    /// The words that went with it, back in the queue if it is dismissed, or interrupted before the Cockpit has it.
    let said: String?
    /// The furthest the Cockpit's mark on its message has got, on the thread.
    var receipt = ChatMessage.Receipt.sent
    /// Its sending was answered: the Cockpit has it.
    var delivered = false
    /// The hand-off it last went under (`WhiteboardLarryHandOffs`).
    var attempt = 0
    /// The turn it went out under: its mark speaks only for that turn, never for a later one (a *Send to Larry* goes
    /// through the Inbox's outbox, which retries on its own, so that turn is offered nothing).
    var turn = WhiteboardLarryTurn.State.idle
  }

  /// His answer came, or the wait ran out: one fresh picture if the board moved on or words waited, else nothing.
  /// `facts`: the state a timeout's problem carries, in the log too.
  private func larryFollowUp(_ next: WhiteboardLarryTurn.Next, why: String, facts: [String: Any] = [:]) {
    var event: [String: Any] = ["action": "larry_turn_over", "board": board.id, "why": why]
    event.merge(facts) { $1 }
    switch next {
    case .send(let words):
      event["next"] = "send"
      event["said_chars"] = words?.count ?? 0
      log.event("whiteboard", event)
      let turn = larry.state
      Task { await handToLarry(turn, said: words, from: why) }
    case .held, .done:
      event["next"] = "none"
      log.event("whiteboard", event)
    }
  }

  /// Igor kept or dismissed one of Larry's marks: it doesn't come back when the board opens again, and once none of his
  /// row is left, nor does the row.
  private func settleLarrys(_ ghost: Ghost) {
    guard ghost.who == .larry, ghost.text == nil, let shownRow else { return }
    let settled = UserDefaults.standard.stringArray(forKey: settledMarksKey) ?? []
    UserDefaults.standard.set(WhiteboardMarks.settling(ghost.id, of: shownRow, after: settled), forKey: settledMarksKey)
    if !turns.ghosts.contains(where: { $0.who == .larry }) { UserDefaults.standard.set(shownRow, forKey: settledKey) }
  }

  private var settledKey: String { "whiteboard_marks_settled_\(board.id)" }
  private var settledMarksKey: String { "whiteboard_marks_settled_marks_\(board.id)" }

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
    // #824: with Ghosts off the words would reach no one, so the mic (and its hook) doesn't take them.
    if !micOn, !turns.micMayOpen() {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "ghosts_off"])
      return
    }
    if let words = LaunchHooks.current.whiteboard.say {
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
    lastSaid.micOpened()
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
    lastSaid.heard(text)
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
    let went = turns.spoke(words)
    log.event("whiteboard", ["action": "spoke", "board": board.id, "chars": words.count, "went": went.rawValue])
    guard went == .now else { return }
    // This turn's picture has the strokes a waiting pause would ask about.
    cancelPause()
    Task { await turn(.claude) }
  }

  /// One turn: the board's picture to the Cockpit, shapes back as ghosts, or, on a board whose responder is Larry, the
  /// picture on to his thread (story 659). `paused`: how long the pause that asked it waited; nil for spoken words.
  func turn(_ who: WhiteboardTurn.Who, paused: Duration? = nil) async {
    let said = turns.said(who)
    // An empty board has no drawing to frame: a spoken turn sees the part on screen, and any other isn't asked.
    let framed =
      WhiteboardGhostTurns<Ghost>.framesScreen(said: said, boardEmpty: drawing.strokes.isEmpty)
      ? visibleRect?() ?? .null : drawing.bounds
    guard editable, let (rect, scale) = WhiteboardFrame.export(framed) else { return }
    let asked = turns.asked(who)
    defer { if turns.turnOver(who) { startPause() } }
    // ponytail: rendered and encoded on the main thread; if a big board hitches the next stroke (the turn event's
    // `bytes`), this moves to a background task.
    // Story 661: the iPad's half of the turn, measured around the picture and its send.
    var timings = WhiteboardTimings(pause: paused)
    let rendering = ContinuousClock.now
    let image = picture(rect: rect, scale: scale)
    let encoding = ContinuousClock.now
    timings.render = rendering.duration(to: encoding)
    let png = image.pngData() ?? Data()
    timings.encode = encoding.duration(to: .now)
    let started = Date()
    let answer: WhiteboardTurn.Answer
    var read = WhiteboardStream.Read()
    let knobAsked = responder.generation
    let upload = UploadClock()
    do {
      let title = store.index.board(board.id)?.title ?? board.title
      let request = try WhiteboardTurn.suggestRequest(
        title: WhiteboardSpeech.context(title: title, said: said), picture: png, width: image.cgImage?.width ?? 0,
        height: image.cgImage?.height ?? 0,
        cockpit: cockpit, board: board.id, timings: timings.wire)
      read = await readClaude(request, started: started, upload: upload) { [weak self] shape, first in
        guard let self, self.turns.current(asked) else { return }
        self.land([shape], who: .claude, rect: rect, scale: scale, first: first)
      }
      answer = read.answer
    } catch {
      answer = WhiteboardTurn.answer(status: nil, body: nil, error: error.localizedDescription)
    }
    timings.upload = upload.span
    let landing = turns.answered(answer, who: who, asked: asked, streamed: read.streamed, said: said)
    let ms = Int(Date().timeIntervalSince(started) * 1000)
    var event: [String: Any] = [
      "who": who.rawValue, "board": board.id, "ms": ms, "stale": landing.stale, "bytes": png.count,
      "streamed": read.streamed, "said_chars": said?.count ?? 0,
    ]
    event.merge(timings.logFields) { $1 }
    if let answered = read.responder {
      event["responder"] = answered.rawValue
      responder.heard(answered, asked: knobAsked)
    }
    if let broken = read.broken { event["broken"] = broken }
    if landing.cancelled { event["cancelled"] = "pen_down" }
    switch answer {
    case .shapes(let shapes):
      event["ok"] = true
      event["shapes"] = shapes.count
      if !shapes.isEmpty { event["first_shape_ms"] = read.firstShapeMs ?? ms }
    case .tooSoon:
      event["ok"] = false
      event["reason"] = "too_soon"
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
    case .away(let reason):
      event["ok"] = false
      event["reason"] = reason
    }
    // Streamed marks are on the board already; a stream with none clears Claude's, as an empty answer does.
    if let shapes = landing.land { land(shapes, who: who, rect: rect, scale: scale, first: true) }
    if let failure = landing.failure {
      failed(who, failure, status: landing.status, first: landing.firstFailure)
    }
    let handOff = WhiteboardResponder.handOff(
      answered: read.responder, answer: answer, stale: landing.stale,
      firstSendWaiting: firstSendWaiting(in: inbox.items))
    // Story 662: one turn of Larry's out at a time. While one is, the pause is held for his answer, with its words.
    var toLarry: String??
    switch handOff {
    case .nothing: break
    case .skipped(let why): event["larry"] = why
    case .hand:
      switch larry.paused(version: ops.rev, words: said, now: .now) {
      case .send(let words):
        event["larry"] = "hand"
        toLarry = .some(words)
      case .held, .done:
        event["larry"] = "held"
      }
    }
    log.event("whiteboard_turn", event)
    // The turn holds the next pause until the picture has gone.
    if case .some(let words) = toLarry { await handToLarry(larry.state, said: words, from: "responder") }
  }

  /// Reads Claude's answer as it comes, telling `landed` each mark and whether it is the answer's first. The 10 s are
  /// for the whole answer: URLRequest's own timeout starts over with every byte.
  private func readClaude(
    _ request: URLRequest, started: Date, upload: UploadClock, landed: @escaping (WhiteboardTurn.Shape, Bool) -> Void
  ) async -> WhiteboardStream.Read {
    let reading = Task { () -> WhiteboardStream.Read in
      var reading = WhiteboardStream.Reading()
      let elapsedMs = { Int(Date().timeIntervalSince(started) * 1000) }
      var failure: String?
      do {
        upload.start()
        let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: upload)
        reading.opened(status: (response as? HTTPURLResponse)?.statusCode, contentType: response.mimeType)
        for try await byte in bytes {
          if let mark = reading.take(byte, elapsedMs: elapsedMs) { landed(mark.shape, mark.first) }
          if reading.done { break }
        }
        if let mark = reading.finish(elapsedMs: elapsedMs) { landed(mark.shape, mark.first) }
      } catch {
        failure = WhiteboardStream.Reading.failure(error, cancelled: Task.isCancelled)
      }
      return reading.read(failure: failure)
    }
    claudeReading = reading
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
    turns.land(
      shapes.map { Ghost($0, who: who, frame: rect, scale: scale) }, who: who, first: first, now: .now)
    if who == .claude { fadeClaudesGhosts() }
  }

  private func fadeClaudesGhosts() {
    guard let at = turns.fadeAt else { return }
    fadeTask?.cancel()
    fadeTask = Task { [weak self] in
      try? await Task.sleep(until: at, clock: .continuous)
      guard !Task.isCancelled, let self else { return }
      self.turns.fade(now: .now)
    }
  }

  /// `turns` has already said so in the note; logged once a run, and Larry's as a copyable problem.
  private func failed(_ who: WhiteboardTurn.Who, _ message: String, status: Int?, first: Bool) {
    if first {
      log.event("error", ["where": "whiteboard_turn", "who": who.rawValue, "message": message, "board": board.id])
    }
    guard who == .larry else { return }
    var extra: [String: JSONValue] = ["board": .string(board.id), "cockpit": .string(cockpit)]
    if let status { extra["status"] = .int(status) }
    problem = .grabber(message, context: "WhiteboardView.larry", extra: extra)
  }

  /// The mark whose Keep and Dismiss show (story 825).
  var chosen: Ghost? { turns.chosen }

  /// A tap at `point` (board points) on a mark shows its Keep and Dismiss; anywhere else only puts them away (stories
  /// 825, 810, #883): a stray tap never keeps or dismisses a mark.
  func tap(at point: CGPoint, zoom: CGFloat) {
    switch turns.tap(hitting: { WhiteboardTurn.hit($0.lines, at: point, tolerance: 22 / zoom) }) {
    case .nothing: return
    case .chose(let ghost):
      log.event(
        "whiteboard",
        ["action": "mark_chosen", "board": board.id, "who": ghost.who.rawValue, "kind": ghost.kind.rawValue])
    case .putAway:
      log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "away", "why": "tap_off"])
    }
  }

  // MARK: Keep all and Tidy overlaps (stories 895, 896)

  /// Larry's marks showing, for Keep all in the note's line.
  var larrysMarks: Int { turns.ghosts.filter { $0.who == .larry }.count }

  /// Story 895: every mark of Larry's kept at once, top to bottom, a label on ink moved under it and the marks after it
  /// with it. One keep, so one undo.
  func keepLarrysMarks() {
    let marks = turns.keepAll(.larry)
    guard editable, !marks.isEmpty else { return }
    let moves = WhiteboardTidy.keepAll(
      marks.map { .init(id: $0.id, lines: $0.lines, label: $0.kind == .text) }, over: Self.inkPoints(drawing))
    let started = Date()
    var strokes: [PKStroke] = []
    for (i, ghost) in marks.enumerated() {
      let dy = moves[ghost.id] ?? 0
      // A moment of its own for each, a few milliseconds apart, so each label is known as one (and story 817's text).
      let made = BoardText.time(started.addingTimeInterval(Double(i) * 0.005))
      let lines = ghost.lines.map { line in line.map { CGPoint(x: $0.x, y: $0.y + dy) } }
      let mine = Self.strokes(lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
      strokes += mine
      if ghost.kind == .text { rememberLabel(made.date) }
      if let text = ghost.text {
        texts.append(
          BoardText(
            id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
            color: Self.lightHex(ghost.color), glyphs: mine.count))
      }
      settleLarrys(ghost)
    }
    if marks.contains(where: { $0.text != nil }) { opLedger.setTexts(texts, board: board.id) }
    log.event(
      "whiteboard",
      [
        "action": "keep_all", "board": board.id, "marks": marks.count, "strokes": strokes.count,
        "moved": moves.values.filter { $0 > 0 }.count,
      ])
    add(strokes)
  }

  /// Story 896: kept labels and pastes that sit on other ink laid out again, top to bottom; his ink stays. One undo.
  func tidyOverlaps() {
    guard editable else { return }
    let known = Set(UserDefaults.standard.array(forKey: labelsKey) as? [Int64] ?? [])
    var labels: [String: [[CGPoint]]] = [:]
    var members: [String: [Int]] = [:]
    var ink: [[CGPoint]] = []
    for (i, stroke) in drawing.strokes.enumerated() where !stroke.isFolded {
      let points = Self.points(stroke)
      let made = Self.moment(stroke)
      if known.contains(made) {
        labels["\(made)", default: []].append(points)
        members["\(made)", default: []].append(i)
      } else {
        ink.append(points)
      }
    }
    let moves = WhiteboardTidy.tidy(labels, among: ink)
    log.event("whiteboard", ["action": "tidy", "board": board.id, "labels": labels.count, "moved": moves.count])
    guard !moves.isEmpty else {
      pasteNote = "Nothing overlaps"
      return
    }
    var strokes: [Int: CGFloat] = [:]
    for (label, dy) in moves { for i in members[label] ?? [] { strokes[i] = dy } }
    move?(strokes)
  }

  private var labelsKey: String { "whiteboard_labels_\(board.id)" }

  /// A label's moment, kept on this device. ponytail: not synced, so another device's labels never tidy; the moments go
  /// with the board's file if that is ever wanted.
  private func rememberLabel(_ made: Date) {
    var known = UserDefaults.standard.array(forKey: labelsKey) as? [Int64] ?? []
    known.append(Int64(made.timeIntervalSince1970 * 1000))
    UserDefaults.standard.set(Array(known.suffix(2000)), forKey: labelsKey)
  }

  private static func moment(_ stroke: PKStroke) -> Int64 {
    Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
  }

  private static func points(_ stroke: PKStroke) -> [CGPoint] {
    stroke.path.interpolatedPoints(by: .distance(4)).map { $0.location.applying(stroke.transform) }
  }

  private static func inkPoints(_ drawing: PKDrawing) -> [[CGPoint]] {
    drawing.strokes.filter { !$0.isFolded }.map(points)
  }

  /// Keep beside the chosen mark: the old tap's keep, one undo.
  func keepChosen() {
    guard let kept = turns.keepChosen() else { return }
    log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "keep", "who": kept.who.rawValue])
    settleLarrys(kept)
    ink(kept)
  }

  /// Dismiss beside the chosen mark: that mark goes, and doesn't come back when the board opens again.
  func dismissChosen() {
    guard let gone = turns.dismissChosen() else { return }
    log.event(
      "whiteboard",
      [
        "action": "mark_choice", "board": board.id, "choice": "dismiss", "who": gone.who.rawValue,
        "kind": gone.kind.rawValue, "left": turns.ghosts.count,
      ])
    settleLarrys(gone)
  }

  /// The ghost as ink in its colour. Its point spacing is what makes PencilKit's spline follow the shape.
  private func ink(_ ghost: Ghost) {
    // Story 817: a text of Larry's is one thing on the board, known by its glyphs' one creation time.
    let made = BoardText.time(Date())
    let strokes = Self.strokes(ghost.lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
    if ghost.kind == .text { rememberLabel(made.date) }
    if let text = ghost.text {
      texts.append(
        BoardText(
          id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
          color: Self.lightHex(ghost.color), glyphs: strokes.count))
      opLedger.setTexts(texts, board: board.id)
    }
    // #883: what a kept mark that doesn't show needs said: its pen, letters and colour, the zoom, and whether the ink
    // landed on screen. `paper_keep` and `paper_ink_look` follow with where it went and whether the view drew it.
    let ink = PKDrawing(strokes: strokes).bounds
    var event: [String: Any] = [
      "action": "keep", "board": board.id, "who": ghost.who.rawValue, "strokes": strokes.count,
      "kind": ghost.kind.rawValue, "width": Double(ghost.width),
      "color": Self.lightHex(ghost.color), "zoom": Double(zoom?() ?? 1),
    ]
    if let letters = ghost.letters { event["letters"] = Double(letters) }
    if let text = ghost.text { event["text_id"] = text.id }
    if let visible = visibleRect?(), !visible.isNull, !ink.isNull { event["in_view"] = visible.intersects(ink) }
    log.event("whiteboard", event)
    add(strokes)
  }

  /// A colour as `#rrggbb`, as it looks in light mode: the colour the Cockpit's strokes carry.
  static func lightHex(_ color: UIColor) -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if !color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(
      &red, green: &green, blue: &blue, alpha: &alpha)
    {
      (red, green, blue) = (0, 0, 0)
    }
    return WhiteboardStrokes.hex(red: red, green: green, blue: blue)
  }

  /// `made`: one moment for every stroke of one mark or paste, which is how a kept label is known again (story 896).
  static func strokes(
    _ lines: [[CGPoint]], color: UIColor, width: CGFloat, spacing: CGFloat, made: Date = Date()
  ) -> [PKStroke] {
    let ink = PKInk(.pen, color: color)
    return lines.map { line in
      PKStroke(
        ink: ink,
        path: PKStrokePath(
          controlPoints: WhiteboardTurn.inkPoints(line, spacing: spacing).enumerated().map { i, p in
            PKStrokePoint(
              location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: width, height: width), opacity: 1,
              force: 1, azimuth: 0, altitude: .pi / 2)
          }, creationDate: made))
    }
  }

  private func add(_ strokes: [PKStroke]) {
    var kept = drawing
    kept.strokes += strokes
    drawing = kept
    drawingMoved()
    draw?(kept, strokes)
  }

  /// Stories 390, 391: the text as ink in the middle of the view, one undo, and a change like a drawn stroke. Black ink
  /// shows light in dark mode, as the Pencil's does, and dark in the picture. The pen's width is in proportion to the
  /// letters: a ghost's 3.7 fills a 24-point letter in, and PencilKit draws nothing under about 2 (seen on the
  /// simulator, on the canvas and in the picture alike), which is why zooming in never shrinks them on the board.
  func paste(_ text: String) {
    guard editable, let visible = visibleRect?(), !visible.isNull, let zoom = zoom?() else { return }
    let height = Self.pasteLetters / min(zoom, 1)
    let layout = WhiteboardPaste.layout(text, visible: visible, height: height, board: pasteReach)
    let made = Date()
    let strokes = Self.strokes(layout.lines, color: .black, width: height * 0.11, spacing: height / 8, made: made)
    if !strokes.isEmpty { rememberLabel(made) }
    log.event(
      "whiteboard",
      [
        "action": "paste", "board": board.id, "characters": layout.kept, "of": layout.total, "strokes": strokes.count,
      ])
    guard !strokes.isEmpty else {
      pasteNote = layout.note
      return
    }
    land(strokes)
    if turns.stroked() { startPause() }
    if let note = layout.note { pasteNote = note }
  }

  private func land(_ strokes: [PKStroke]) {
    if landPaste?(strokes) != true { add(strokes) }
  }

  /// Copied strokes the canvas didn't place itself: one undo, and a change like a drawn stroke, as a paste of text is.
  func paste(strokes: [PKStroke]) {
    guard editable, !strokes.isEmpty else { return }
    log.event("whiteboard", ["action": "paste_strokes", "board": board.id, "strokes": strokes.count])
    land(strokes)
    if turns.stroked() { startPause() }
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
      drawFoldMarkers(in: rect)
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
    guard editable else { return }
    store.opened(board.id)
    Task { await readResponder() }
  }

  /// Story 659: which responder the board has, asked as it opens. Until the Cockpit answers, or when it can't, Sonnet
  /// stays ticked: the log says so, the bar doesn't.
  private func readResponder() async {
    let asked = responder.generation
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.readRequest(board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    var event: [String: Any] = ["action": "responder_read", "board": board.id]
    switch reply {
    case .responder(let answered):
      responder.heard(answered, asked: asked)
      event["ok"] = true
      event["responder"] = answered.rawValue
    case .failed(let reason, let status):
      event["ok"] = false
      event["reason"] = reason
      if let status { event["status"] = status }
    }
    event["ticked"] = responder.shown.rawValue
    log.event("whiteboard", event)
  }

  /// Story 659: Igor picked who answers the board's pauses. It shows at once and goes to the Cockpit; a write that
  /// fails takes the tick back and says why.
  func setResponder(_ new: WhiteboardResponder) {
    guard editable, let choice = responder.chose(new) else { return }
    log.event("whiteboard", ["action": "responder", "board": board.id, "responder": new.rawValue])
    Task { await writeResponder(new, choice: choice) }
  }

  private func writeResponder(_ new: WhiteboardResponder, choice: Int) async {
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.writeRequest(new, board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    switch reply {
    case .responder(let answered):
      responder.wrote(answered, choice: choice)
      if problem?.context == "WhiteboardView.responder" { problem = nil }
    case .failed(let reason, let status):
      responder.wrote(nil, choice: choice)
      log.event(
        "error",
        ["where": "whiteboard_responder", "board": board.id, "responder": new.rawValue, "message": reason])
      var extra: [String: JSONValue] = [
        "board": .string(board.id), "responder": .string(new.rawValue), "ticked": .string(responder.shown.rawValue),
        "cockpit": .string(cockpit),
      ]
      if let status { extra["status"] = .int(status) }
      problem = .grabber(
        "The board couldn't be given to \(new.name): \(reason)", context: "WhiteboardView.responder", extra: extra)
    }
  }

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
    stopWatchingLarry()
    saveTask?.cancel()
    heldTask?.cancel()
    if let dropped = ops.dropHeld(reason: "board_closed") {
      log.event(
        "board_ops", ["action": "refused", "board": board.id, "label": dropped.label, "reason": "board_closed"])
    }
    guard editable else { return }
    if dirty {
      save()
      log.event(
        "whiteboard", ["action": "close", "board": board.id, "strokes": drawing.strokes.count, "saved": !dirty])
      if dirty, let problem { store.closedUnsaved(problem, board: board.id) }
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
      if problem?.context == "WhiteboardView.save" { problem = nil }
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

  /// Story 343: the whole drawing (on paper, the pages on screen: story 433), dark ink on white whatever the iPad's mode,
  /// on the board's thread with Larry, titled with the board's name; the first one starts it (story 381).
  func send() {
    guard sent == nil, !larrySending, let (rect, scale) = pictureFrame() else { return }
    // Story 662: a Send is Larry's turn too, out now whatever was held; words that waited go with it. Story 765: not
    // while he is looking at the board as it is.
    guard case .send(let words) = larry.tapped(version: ops.rev, moved: rect != larryFrame, now: .now) else {
      return alreadyHas(from: "send")
    }
    larryFrame = rect
    let turn = larry.state
    checkLarryWait()
    let ink = picture(rect: rect, scale: scale)
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    let title = store.index.board(board.id)?.title ?? board.title
    draft.text = words.map { "\(title): \($0)" } ?? title
    draft.whiteboard = WhiteboardPicture(board: board.id, title: title, rect: rect, scale: scale, report: turnReport())
    // Story 424: the strokes wait beside the picture and go first when it goes.
    draft.strokes = try? JSONSerialization.data(
      withJSONObject: WhiteboardStrokes.wire(strokesForLarry(), texts: texts, metas: strokeMeta))
    do {
      try inbox.add(&draft, thread: threads.thread(board: board.id))
      if problem?.context == "WhiteboardView.send" { problem = nil }
      sent = "Sent to Larry: his reply shows in Chat"
      sentFrame = rect
      shipLog(why: "send")
      log.event(
        "whiteboard",
        [
          "action": "send", "board": board.id, "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
          "frame": [Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)],
        ])
    } catch {
      larry.failed(turn, words: words)
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}

// MARK: - Larry's changes to the board (stories 814–819)

extension WhiteboardModel {
  /// Unix ms, the time the wire carries.
  private static var nowMs: Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }

  /// The Pencil went down or up: Larry hears it on his next turn, and a change of his waits for the lift.
  fileprivate func penWent(down: Bool) {
    guard down != penDown else { return }
    penDown = down
    if !down { liftedAt = .now }
    let before = events.list.count
    events.pen(down: down, t: Self.nowMs)
    if events.list.count != before, let event = events.list.last { takeOps(.event(event)) }
    if down {
      heldTask?.cancel()
      heldTask = nil
    } else {
      releaseHeldSoon()
    }
  }

  /// A finger tap on the board, in board points: Larry hears where, and which of his marks it hit (a ghost, or a text
  /// he wrote and Igor kept), if any.
  func tapped(at point: CGPoint, zoom: CGFloat) {
    let tolerance = 22 / zoom
    // Story 846: a tap on one of his controls goes to him at once.
    if let overlay = overlays.hit(point, tolerance: 4 / zoom) {
      events.record(.overlayTap(id: overlay.id, event: overlay.tapEvent, t: Self.nowMs))
      log.event("board_events", ["action": "overlay_tap", "board": board.id, "overlay": overlay.id])
      sendEventsNow(why: "overlay_tap")
      return
    }
    // A finger in the margin is the margin's (story 849).
    guard point.x >= BoardMargin.width else { return }
    let ghost = ghosts.first { WhiteboardTurn.hit($0.lines, at: point, tolerance: tolerance) }
    let target = ghost.map { $0.text?.id ?? $0.id } ?? keptText(at: point, tolerance: tolerance)
    events.tap(at: point, target: target, t: Self.nowMs)
    if let event = events.list.last { takeOps(.event(event)) }
  }

  /// Story 849: a lone finger lifted after starting in the margin, in board points.
  func fingerLifted(from start: CGPoint, to end: CGPoint, seconds: Double) {
    guard let (gesture, y, dy) = BoardMargin.gesture(from: start, to: end, seconds: seconds) else { return }
    record(.margin(gesture: gesture, y: y, dy: dy, t: Self.nowMs))
    if gesture == .tap { marginTapped(at: y) }
  }

  /// Story 855, as the web board's margin tap: beside a header it folds or unfolds it; beside a line of ink it makes it
  /// a header; beside blank paper nothing.
  func marginTapped(at y: CGFloat) {
    guard editable else { return }
    var what = "nothing"
    let changed =
      changeOutline?("Fold") { outline in
        if let header = outline.header(at: y) {
          what = outline.isFolded(header) ? "unfold" : "fold"
          return outline.toggle(header.id)
        }
        what = "header"
        return outline.markHeader(at: y, id: Self.newHeaderID())
      } ?? false
    log.event(
      "board_outline", ["action": "margin_tap", "board": board.id, "y": Double(y), "did": what, "changed": changed])
  }

  /// A header's id, as the Cockpit takes a stroke's.
  static func newHeaderID() -> String { "h-" + UUID().uuidString.prefix(8).lowercased() }

  /// The outline over `strokes` (the canvas's, by default the drawing's), with the board's headers.
  func outline(of strokes: [BoardOps.Stroke]? = nil) -> BoardOutline {
    BoardOutline(
      strokes: strokes ?? opStrokes(drawing.strokes).strokes, headers: headers, texts: texts, groups: strokeMeta.groups)
  }

  /// The canvas applied an outline change.
  func outlineChanged(_ outline: BoardOutline) {
    // Stories 902–904: a header whose ink is gone stays, so the Undo that brings the ink back brings it back folded.
    let kept = BoardOutline.keeping(outline.headers, previous: headers, live: outline.liveNames)
    guard kept != headers else { return }
    headers = kept
    opLedger.setHeaders(headers, board: board.id)
  }

  /// Story 850: the view came to rest showing `rect` (board points) at `scale`.
  func viewRested(_ rect: CGRect, scale: CGFloat) {
    guard !rect.isNull, !rect.isEmpty else { return }
    if let last = lastViewport, abs(last.rect.minY - rect.minY) < 1, abs(last.rect.height - rect.height) < 1,
      abs(last.scale - scale) < 0.001
    {
      return
    }
    lastViewport = (rect, scale)
    record(.viewport(y: rect.minY, h: rect.height, scale: scale, t: Self.nowMs))
  }

  /// Story 851: Igor undid a batch of Larry's.
  func undid(_ label: String) {
    record(.undo(label: label, t: Self.nowMs))
    log.event("board_ops", ["action": "undone", "board": board.id, "label": label])
  }

  private func record(_ event: BoardEvent) {
    events.record(event)
    takeOps(.event(event))
  }

  /// Story 846: the events so far go to the Cockpit now, not with the next turn. Taken, they're gone; not taken (no
  /// route yet, or no answer), they wait for the next turn, and the log says which.
  private func sendEventsNow(why: String) {
    let taken = events.take()
    let report = BoardTurnReport(
      rev: ops.rev, opResult: ops.lastResult, events: taken.events, eventsDropped: taken.dropped)
    let request: URLRequest
    do {
      request = try BoardEventsSend.request(board: board.id, report: report, cockpit: cockpit)
    } catch {
      events.restore(taken)
      log.event("board_events", ["action": "held", "board": board.id, "why": why, "reason": "\(error)"])
      return
    }
    let started = Date()
    Task { [weak self] in
      let answer: BoardEventsSend.Answer
      do {
        let (_, response) = try await URLSession.shared.data(for: request)
        answer = BoardEventsSend.answer(status: (response as? HTTPURLResponse)?.statusCode)
      } catch {
        answer = BoardEventsSend.answer(status: nil, error: error.localizedDescription)
      }
      guard let self else { return }
      var event: [String: Any] = [
        "board": self.board.id, "why": why, "events": taken.events.count,
        "ms": Int(Date().timeIntervalSince(started) * 1000),
      ]
      switch answer {
      case .taken:
        event["action"] = "sent"
      case .notThere:
        // ponytail: the Cockpit's POST /whiteboard/events is Larry's to build; until it answers, a tap waits for the
        // next turn. Drop this branch's log once every Cockpit has it.
        self.events.restore(taken)
        event["action"] = "held"
        event["reason"] = "no events route"
      case .away(let reason):
        self.events.restore(taken)
        event["action"] = "held"
        event["reason"] = reason
      }
      self.log.event("board_events", event)
    }
  }

  /// The kept text of Larry's under `point`, by its glyphs' box.
  private func keptText(at point: CGPoint, tolerance: CGFloat) -> String? {
    guard !texts.isEmpty else { return nil }
    let byTime = BoardText.byTime(texts)
    var boxes: [String: CGRect] = [:]
    for stroke in drawing.strokes {
      let t = Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
      guard let text = BoardText.owning(t, in: byTime) else { continue }
      boxes[text.id] = (boxes[text.id] ?? .null).union(stroke.renderBounds)
    }
    return boxes.first { $0.value.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }?.key
  }

  /// The board's half of Larry's next turn: the events since the last are taken.
  fileprivate func turnReport() -> BoardTurnReport {
    let taken = events.take()
    return BoardTurnReport(rev: ops.rev, opResult: ops.lastResult, events: taken.events, eventsDropped: taken.dropped)
  }

  /// Whatever a source hears goes to every source; each batch they make goes to the one applier.
  fileprivate func takeOps(_ input: BoardOpInput) {
    for i in opSources.indices {
      let name = opSources[i].name
      for batch in opSources[i].batches(from: input) { receive(batch, from: name) }
    }
  }

  private var opsReady: BoardOps.Readiness {
    BoardOps.readiness(penDown: penDown, liftedAt: liftedAt, now: .now)
  }

  private func receive(_ batch: BoardOps.Batch, from source: String) {
    var event = BoardOps.logFields(batch)
    event["board"] = board.id
    event["source"] = source
    event["rev"] = ops.rev
    switch ops.receive(batch, board: board.id, editable: editable, ready: opsReady == .now) {
    case .ignored(let why):
      event["action"] = "ignored"
      event["why"] = why
      event["for_board"] = batch.board ?? ""
      log.event("board_ops", event)
    case .refused(let result):
      event["action"] = "refused"
      event["reason"] = result.reason ?? ""
      log.event("board_ops", event)
    case .held(let replaced):
      event["action"] = "held"
      event["pen_down"] = penDown
      if let replaced { event["replaced"] = replaced }
      log.event("board_ops", event)
      releaseHeldSoon()
    case .apply(let batch):
      apply(batch, held: false)
    }
  }

  /// A batch held for the Pencil goes once it is up and the board's pause has passed; a touch down in the meantime waits
  /// for the next lift.
  private func releaseHeldSoon() {
    guard ops.held != nil else { return }
    switch opsReady {
    case .onLift:
      return
    case .now:
      if let batch = ops.release(ready: true) { apply(batch, held: true) }
    case .after(let wait):
      heldTask?.cancel()
      heldTask = Task { [weak self] in
        try? await Task.sleep(for: wait)
        guard !Task.isCancelled else { return }
        self?.releaseHeldSoon()
      }
    }
  }

  private func apply(_ batch: BoardOps.Batch, held: Bool) {
    let started = ContinuousClock.now
    var event = BoardOps.logFields(batch)
    event["board"] = board.id
    event["held"] = held
    guard let plan = applyOps?(batch) else {
      // No canvas laid out yet, or PaperKit didn't take the move (`paper_ops_failed`).
      let result = ops.refusal(batch, "not_applied")
      event["action"] = "refused"
      event["reason"] = result.reason ?? ""
      log.event("board_ops", event)
      return
    }
    if !plan.overlays.isEmpty {
      overlays.apply(plan.overlays)
      showOverlays?(overlays.list)
    }
    if !plan.metas.isEmpty || !plan.forgetMetas.isEmpty {
      plan.forgetMetas.forEach { strokeMeta.remove($0) }
      strokeMeta.merge(plan.metas)
      opLedger.setStrokeMeta(strokeMeta, board: board.id)
    }
    if !plan.texts.isEmpty {
      turns.larrysText(
        plan.texts.map {
          Ghost($0.shape, who: .larry, frame: .zero, scale: 1, id: "op-text:\($0.id)", text: $0)
        })
    }
    let result = ops.applied(batch, plan: plan)
    var moves = plan.offsets.values.map(\.dy)
    moves.sort()
    let hiding = plan.hidden.values.filter { $0 }.count
    let moving: [String: Any] = [
      "action": "applied", "rev": result.rev, "moved": plan.moved, "strokes_moved": plan.offsets.count,
      "dy_min": Double(moves.first ?? 0), "dy_max": Double(moves.last ?? 0),
      "pages_before": plan.pagesBefore, "pages": plan.pagesAfter,
    ]
    let editing: [String: Any] = [
      "erased": plan.erase.count, "drawn": plan.added.count, "metas": plan.metas.count, "hidden": hiding,
      "shown": plan.hidden.count - hiding, "selected": plan.select.count, "overlays": overlays.list.count,
      "texts": plan.texts.count, "missing_ids": plan.missingIDs.count, "changed": plan.changesBoard,
      "ms": Int(started.duration(to: .now) / .milliseconds(1)),
    ]
    event.merge(moving) { $1 }
    event.merge(editing) { $1 }
    log.event("board_ops", event)
  }

  /// Story 843: elements came or changed (`updated`, their hashes now) or went. `report`: Igor did it, so Larry hears
  /// it; else the board only takes it in.
  func inkElements(updated: [String: [String]], removed: [String], report: Bool) {
    let before = strokeIDs
    let change = ink.changed(updated: updated, removed: removed, ids: &strokeIDs)
    if strokeIDs != before { opLedger.setStrokeIDs(strokeIDs, board: board.id) }
    guard report, !change.isEmpty else { return }
    let dissolved = dissolve(erased: change.erased)
    let event = BoardEvent.strokesChanged(
      added: change.added, erased: change.erased, moved: change.moved, rev: ops.rev, t: Self.nowMs,
      dissolved: dissolved.isEmpty ? nil : dissolved)
    events.record(event)
    takeOps(.event(event))
  }

  /// Story 854: a group or kept text Igor erased part of is plain ink from now on. The ids that dissolved.
  private func dissolve(erased: [String]) -> [String] {
    guard !erased.isEmpty, !strokeMeta.isEmpty || !texts.isEmpty else { return [] }
    var metas = strokeMeta
    var kept = texts
    let gone = BoardDissolve.dissolve(
      erased: erased, live: opStrokes(drawing.strokes).strokes, metas: &metas, texts: &kept)
    guard !gone.isEmpty else { return [] }
    if metas != strokeMeta {
      strokeMeta = metas
      opLedger.setStrokeMeta(metas, board: board.id)
    }
    if kept != texts {
      texts = kept
      opLedger.setTexts(kept, board: board.id)
    }
    log.event("board_ops", ["action": "dissolved", "board": board.id, "ids": gone, "erased": erased.count])
    return gone
  }

  /// The strokes as a plan of the board sees them, by the names Larry knows them (one moved before keeps its first
  /// name), with each one's hashes now. Ink with no colour to see is hidden.
  func opStrokes(_ ink: [PKStroke]) -> (strokes: [BoardOps.Stroke], hashes: [[String]]) {
    let sent = ink.map { Self.strokesForLarry(PKDrawing(strokes: [$0])) }
    let hashes = sent.map { $0.map(\.id) }
    let strokes = zip(ink, sent).map { stroke, stretches in
      BoardOps.Stroke(
        ids: stretches.map { strokeIDs.stable($0.id) },
        t: Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000), bounds: stroke.renderBounds,
        hidden: stroke.ink.color.cgColor.alpha == 0, points: stretches.flatMap(\.points),
        pen: CGFloat(stretches.first?.width ?? 0))
    }
    return (strokes, hashes)
  }

  /// The ink as it is, Larry told nothing: on opening, and after a change of his own.
  func inkReset(_ hashes: [String: [String]]) { ink.reset(hashes) }

  /// Story 848: the element keys of the strokes Larry names.
  func elementKeys(named names: [String]) -> Set<String> {
    let wanted = Set(names)
    return Set(ink.hashes.filter { $0.value.contains { wanted.contains(strokeIDs.stable($0)) } }.keys)
  }

  /// Story 844: the lasso's selection, by element key; Larry hears it by name when it changes.
  func selectionChanged(_ keys: Set<String>) {
    guard keys != selection else { return }
    selection = keys
    let names = keys.sorted().flatMap { ink.hashes[$0] ?? [] }.map(strokeIDs.stable)
    let event = BoardEvent.selection(ids: names, t: Self.nowMs)
    events.record(event)
    takeOps(.event(event))
  }

  // Stories 920–922 (BoardToTextFlow.swift): what To text needs of the board.
  var cockpitURL: String { cockpit }
  var sessionLog: SessionLog { log }
  func show(problem new: BugProblem?) { problem = new }
  func say(_ note: String) { pasteNote = note }
  func keep(text: BoardText) {
    texts.append(text)
    opLedger.setTexts(texts, board: board.id)
  }

  /// Stories 910–916: what a plan put on the canvas besides its ink, whoever made it: its notes (a connector's route, a
  /// word grouped as one end, a connector turned plain ink) and the names of the strokes it drew.
  func planPut(_ plan: BoardOps.Plan, drawn: [(hash: [String], name: String)]) {
    guard editable else { return }
    if !plan.metas.isEmpty || !plan.forgetMetas.isEmpty {
      plan.forgetMetas.forEach { strokeMeta.remove($0) }
      strokeMeta.merge(plan.metas)
      opLedger.setStrokeMeta(strokeMeta, board: board.id)
    }
    guard !drawn.isEmpty else { return }
    for stroke in drawn { stroke.hash.forEach { strokeIDs.name($0, as: stroke.name) } }
    opLedger.setStrokeIDs(strokeIDs, board: board.id)
  }

  /// The canvas applied a batch of Larry's: saved and a new revision like any change, and no stroke for Claude to answer.
  /// `renamed`: for each moved stroke, the hashes of its stretches before and after, so it keeps its names.
  /// `drawn`: each stroke Larry drew, its hashes and his name for it.
  func opsApplied(
    _ new: PKDrawing, renamed: [(from: [String], to: [String])], drawn: [(hash: [String], name: String)] = []
  ) {
    guard editable else { return }
    for pair in renamed { strokeIDs.moved(from: pair.from, to: pair.to) }
    for stroke in drawn { stroke.hash.forEach { strokeIDs.name($0, as: stroke.name) } }
    if !renamed.isEmpty || !drawn.isEmpty { opLedger.setStrokeIDs(strokeIDs, board: board.id) }
    drawing = new
    drawingMoved()
  }
}

/// A shape Claude or Larry offered, in board points, not yet kept.
struct Ghost: Identifiable, WhiteboardGhost {
  let id: String
  let who: WhiteboardTurn.Who
  let lines: [[CGPoint]]
  /// The colour and pen it asked for, or its author's colour and the default pen (#698).
  let color: UIColor
  let width: CGFloat
  /// What it is and, for a label, its letters' height in board points: for the keep's log line (#883).
  let kind: WhiteboardTurn.Shape.Kind
  let letters: CGFloat?
  /// A text of Larry's from a batch of his changes (story 817): kept, it becomes one text under its id.
  let text: BoardOps.Text?

  init(
    _ shape: WhiteboardTurn.Shape, who: WhiteboardTurn.Who, frame: CGRect, scale: CGFloat,
    id: String = UUID().uuidString, text: BoardOps.Text? = nil
  ) {
    self.id = id
    self.text = text
    self.who = who
    lines = WhiteboardTurn.lines(shape, frame: frame, scale: scale)
    color = shape.color.map { UIColor(rgb: $0) } ?? who.color
    width = WhiteboardTurn.width(shape, scale: scale)
    kind = shape.kind
    letters = WhiteboardTurn.letters(shape, scale: scale)
  }
}

/// How long a ghost turn's request took to go up (story 661): from the send to its body's last byte, the connection's
/// setup included. URLSession tells a task's own delegate as the body goes; the last word is the last byte.
final class UploadClock: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var started: ContinuousClock.Instant?
  private var sent: ContinuousClock.Instant?

  func start() {
    lock.withLock {
      started = .now
      sent = nil
    }
  }

  /// Nil until the body has gone, or when URLSession never said.
  var span: Duration? {
    lock.withLock {
      guard let started, let sent else { return nil }
      return started.duration(to: sent)
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    lock.withLock { sent = .now }
  }
}

/// The ghosts on screen, in board points: one shape layer a ghost, the ink it would become, faint, in its colour. Whoever
/// holds `holder` scales it to sit on the drawing. Never part of the drawing, and in no picture.
@MainActor
final class GhostLayers {
  let holder = CALayer()
  private var shown: [String: CAShapeLayer] = [:]

  init() {
    holder.anchorPoint = .zero
    holder.frame = .zero
  }

  /// True when the ghosts on show changed.
  @discardableResult
  func show(_ ghosts: [Ghost]) -> Bool {
    guard Set(ghosts.map(\.id)) != Set(shown.keys) else { return false }
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
      shape.strokeColor = ghost.color.withAlphaComponent(0.5).cgColor
      shape.lineWidth = ghost.width
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
      holder.addSublayer(shape)
      shown[ghost.id] = shape
    }
    return true
  }
}

extension WhiteboardTurn.Who {
  /// Claude orange, Larry purple: a colour the picker doesn't offer (spec 2026-11-01-whiteboard-shapes-design.md,
  /// context-grabber-a3w).
  var color: UIColor { self == .claude ? .systemOrange : UIColor(rgb: WhiteboardTurn.larryColor) }
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
  /// Story 766: the note's one line, kept whether it says anything or not, so the paper never moves for it.
  @ScaledMetric(relativeTo: .footnote) private var noteHeight: CGFloat = 28
  private let logger: BugLogger
  private let log: SessionLog
  private let callLive: AnyPublisher<Bool, Never>
  private let reportOpen: AnyPublisher<Bool, Never>
  /// Stories 952, 953: Feedback opens BugKit's report; its status after each save.
  private let report: () -> Void
  private let reportSaved: AnyPublisher<String, Never>
  /// Story 769: an iPhone has no conversation panel; a tap on the note opens the board's thread in Chat.
  private let onPhone: Bool
  private let openChat: (String) -> Void
  private let decisions: ChatDecisionsModel

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit,
        callLive: { [weak app] in app?.call.snapshot.isActive ?? false }))
    inbox = app.inbox
    callLive = app.call.$snapshot.map(\.isActive).removeDuplicates().eraseToAnyPublisher()
    reportOpen = app.reporter.$flow.map(\.isPresented).removeDuplicates().eraseToAnyPublisher()
    report = { [weak app] in app?.startBugReport(from: "whiteboard") }
    reportSaved = app.reporter.$lastStatus.dropFirst().compactMap { $0 }.receive(on: RunLoop.main).eraseToAnyPublisher()
    logger = app.bugLogger
    log = app.log
    onPhone = store.onPhone
    openChat = { [weak app] key in app?.open(route: .chat(thread: key), from: "whiteboard") }
    decisions = app.chat.decisions
  }

  var body: some View {
    VStack(spacing: 0) {
      // Story 667: while Larry is looking the note begins with his clock, so it ticks once a second, as it does while a
      // message holds the middle (story 766); else it's still.
      if WhiteboardNote.ticks(larry: model.larry, notice: model.notice) {
        TimelineView(.periodic(from: .now, by: 1)) { _ in noteLine(now: .now) }
      } else {
        noteLine(now: .now)
      }
      if let problem = model.problem {
        HStack(alignment: .firstTextBaseline) {
          BugProblemView(problem: problem, logger: logger)
          // Stories 761, 762: his silence stays until he next answers or this.
          if problem.context == WhiteboardLarryClock.DidntAnswer.context {
            Spacer()
            Button("Dismiss") { model.dismissProblem() }.font(.footnote).buttonStyle(.borderless)
              .accessibilityIdentifier("whiteboard-dismiss-problem")
          }
          // Stories 775, 776: a picture the Cockpit hasn't taken in twenty seconds.
          if problem.context == WhiteboardLarryWait.stuckContext {
            Spacer()
            Button("Retry") { model.retryLarry() }.font(.footnote).buttonStyle(.borderless)
              .accessibilityIdentifier("whiteboard-larry-retry")
            Button("Dismiss") { model.dismissStuck() }.font(.footnote).buttonStyle(.borderless)
              .accessibilityIdentifier("whiteboard-larry-dismiss")
          }
        }
        .padding(.horizontal)
      }
      Group {
        PaperBoardCanvas(model: model, log: log)
      }
      // Story 768: the conversation lies over the top of the board and never moves or resizes the paper.
      .overlay(alignment: .top) {
        if model.conversationOpen, !onPhone {
          // Story 837 (#917): a fifth of the board at most; past that it scrolls rather than grows.
          GeometryReader { space in
            conversation.frame(
              maxHeight: CGFloat(WhiteboardNote.panelHeight(board: Double(space.size.height))), alignment: .top)
          }
        }
      }
      .ignoresSafeArea(edges: .bottom)
    }
    // Stories 950–953: ? and Feedback at the board's lower right, as on /ink; off the top bar (#848).
    .overlay(alignment: .bottomTrailing) {
      BoardHelpButtons(
        editable: model.editable, log: log, board: model.board.id, report: report, saved: reportSaved)
    }
    .modifier(WhiteboardQuestionSheet(questions: model.questions, decisions: decisions, logger: logger))
    .navigationTitle(model.board.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if model.editable {
        // The board's own settings, in one menu. Six items in an iPhone's top bar push Larry's turn and Send under *More*,
        // so at that width this one goes to the bottom (story 402).
        ToolbarItem(placement: horizontalSizeClass == .compact ? .bottomBar : .topBarTrailing) {
          Menu {
            Section("Colour") {
              ForEach(BoardPaper.allCases, id: \.self) { paper in
                Toggle(
                  paper.name,
                  isOn: Binding(
                    get: { model.paper == paper },
                    set: { _ in
                      model.setPaper(paper)
                      model.menuChose?()
                    }))
              }
            }
            Section("Lines") {
              Toggle(
                "Grid lines",
                isOn: Binding(
                  get: { model.gridOn },
                  set: {
                    model.setGrid($0)
                    model.menuChose?()
                  }))
              Toggle(
                "Ruled lines",
                isOn: Binding(
                  get: { model.ruledOn },
                  set: {
                    model.setRuled($0)
                    model.menuChose?()
                  }))
            }
            // Story 896: kept labels moved off ink. One row, as the Board menu has room for no more (#848); Keep all is in
            // the note's line, beside the count of marks to keep (story 895).
            Button("Tidy overlaps") {
              model.tidyOverlaps()
              model.menuChose?()
            }
            .accessibilityIdentifier("whiteboard-tidy")
            // Story 659: who answers a pause, the board's own on the Cockpit. A submenu, not a section: three more rows
            // make the iPad show the menu as a full-height list that stays up after a pick (#848).
            Menu {
              ForEach(WhiteboardResponder.allCases, id: \.self) { responder in
                Toggle(
                  responder.name,
                  isOn: Binding(
                    get: { model.responder.shown == responder },
                    set: { _ in
                      model.setResponder(responder)
                      model.menuChose?()
                    }))
              }
            } label: {
              Label("Responder: \(model.responder.shown.name)", systemImage: "person.wave.2")
            }
          } label: {
            Label("Board", systemImage: "paintpalette")
          }
          // Its colour and lines, for VoiceOver and the UI test, in the label for the reason below.
          .accessibilityLabel(
            "Board, \(model.paper.name)\(model.gridOn ? ", grid on" : model.ruledOn ? ", ruled lines on" : "")"
          )
          .accessibilityIdentifier("whiteboard-board")
        }
      }
      if model.editable {
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
          .disabled(
            model.isEmpty || model.nothingOnScreen || model.larrySending || model.firstSendWaiting(in: inbox.items)
          )
          .accessibilityIdentifier("whiteboard-larry")
        }
      }
      // An old-canvas board's ink sits where the column put it, not where it's saved: nothing to frame for Larry (story 658).
      if !model.oldCanvas {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.send()
          } label: {
            Label("Send to Larry", systemImage: "paperplane")
          }
          // How much is drawn, for VoiceOver and the UI test, in the label for the reason above.
          .accessibilityLabel("Send to Larry, \(model.drawing.strokes.count) strokes")
          .disabled(model.isEmpty || model.nothingOnScreen || model.sent != nil || model.larrySending)
          .accessibilityIdentifier("whiteboard-send")
        }
      }
    }
    .task {
      // XCUITest's taps never reach the system's paste button: the UI test pastes through this.
      guard let text = LaunchHooks.current.whiteboard.paste else { return }
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

  /// The bar's note, one line (story 766): Larry's state first so it is never what gets cut off (story 667), the newest
  /// thing said, how many suggestions show, and a chevron. A finger tap opens the conversation over the board. VoiceOver
  /// reads his state in words when it reaches the note, not on every tick.
  @ViewBuilder private func noteLine(now: ContinuousClock.Instant) -> some View {
    if let line = WhiteboardNote.line(
      larry: model.larry, now: now, cockpitAnswering: !model.larryAway, mark: model.larryMark(now: now),
      said: model.lastSaid, micOn: model.micOn,
      notice: model.notice, ghosts: model.ghosts.count)
    {
      let tap = WhiteboardNote.tap(onPhone: onPhone, thread: model.threadKey)
      HStack(spacing: 6) {
        if let state = line.state {
          Text(state).lineLimit(1).layoutPriority(1)
            .accessibilityLabel(line.spokenState ?? state)
            .accessibilityIdentifier("whiteboard-note-state")
          if line.middle != nil { Text("·") }
        }
        if let middle = line.middle {
          Text(middle).lineLimit(1).truncationMode(line.keepsEnd ? .head : .tail)
            .accessibilityIdentifier("whiteboard-note-said")
        }
        Spacer(minLength: 0)
        if let keep = line.keep { Text(keep).lineLimit(1).fixedSize() }
        // Story 895: every mark of Larry's kept at once, in order, as the web board's Keep all.
        if model.editable, model.larrysMarks > 0 {
          Button("Keep all") { model.keepLarrysMarks() }.buttonStyle(.borderless).fixedSize()
            .accessibilityHint("Keeps every mark of Larry's, top to bottom, clear of your writing")
            .accessibilityIdentifier("whiteboard-keep-all")
        }
        // Story 777: Larry has the picture and twenty seconds have passed: a quiet way to stop waiting for him.
        if model.larryWait == .working {
          Button("Interrupt") { model.interruptLarry() }.buttonStyle(.borderless).fixedSize()
            .accessibilityHint("Stops waiting for Larry's answer, so the next picture is a fresh ask")
            .accessibilityIdentifier("whiteboard-larry-interrupt")
        }
        if tap != .nothing {
          Button {
            model.tapNote(onPhone: onPhone, openChat: openChat)
          } label: {
            Image(systemName: onPhone ? "chevron.right" : model.conversationOpen ? "chevron.up" : "chevron.down")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(
            onPhone ? "Open in Chat" : model.conversationOpen ? "Hide the conversation" : "Show the conversation"
          )
          .accessibilityIdentifier("whiteboard-note-chevron")
        }
      }
      .font(.footnote).foregroundStyle(.secondary)
      .padding(.vertical, 4).padding(.horizontal)
      .frame(minHeight: noteHeight)
      .contentShape(Rectangle())
      .onTapGesture { model.tapNote(onPhone: onPhone, openChat: openChat) }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("whiteboard-note")
    } else {
      // Nothing to say yet: the line's room stays, so the paper doesn't jump when it first speaks.
      Color.clear.frame(height: noteHeight).accessibilityHidden(true)
    }
  }

  /// Story 768: the open note, over the top of the board: the recent end of the board's thread, selectable, then what is
  /// live, and *Open in Chat*. The Pencil never acts on it: the thread's text takes finger touches only, and the rest
  /// holds nothing to scroll or draw on.
  private var conversation: some View {
    let tick = WhiteboardNote.ticks(larry: model.larry, notice: nil)
    return VStack(alignment: .leading, spacing: 4) {
      WhiteboardConversationText(rows: WhiteboardNote.recent(model.thread))
      if tick {
        TimelineView(.periodic(from: .now, by: 1)) { _ in liveRows(now: .now) }
      } else {
        liveRows(now: .now)
      }
      if let key = model.threadKey {
        Button("Open in Chat") { openChat(key) }
          .font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-conversation-chat")
      }
    }
    .padding(.horizontal).padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .contentShape(Rectangle())
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-conversation")
  }

  /// What is live under the thread: the turn that's out, what waits to go next, what the mic is hearing.
  private func liveRows(now: ContinuousClock.Instant) -> some View {
    let live = WhiteboardNote.live(
      larry: model.larry, now: now, cockpitAnswering: !model.larryAway, mark: model.larryMark(now: now),
      said: model.lastSaid, micOn: model.micOn)
    // One column of its own: a TimelineView lays several children over each other (#882).
    return VStack(alignment: .leading, spacing: 4) {
      ForEach(live) { row in
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text("\(row.who):").bold()
          Text(row.text)
        }
        .font(.footnote).foregroundStyle(.secondary)
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("whiteboard-conversation-\(row.id)")
      }
    }
  }
}

/// Story 768: the board's thread in the open note, one text that can be selected and copied across rows and scrolls
/// inside the panel, newest at the bottom. A UITextView rather than SwiftUI text: its gestures can be told to take
/// fingers only, so the Pencil neither scrolls nor selects it, and a ticking clock beside it doesn't reset a selection.
private struct WhiteboardConversationText: UIViewRepresentable {
  let rows: [WhiteboardNote.Row]

  func makeUIView(context: Context) -> NewestInView {
    let view = NewestInView()
    view.isEditable = false
    view.isSelectable = true
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityIdentifier = "whiteboard-conversation-text"
    return view
  }

  func updateUIView(_ view: NewestInView, context: Context) {
    let text = Self.text(rows)
    fingersOnly(view)
    guard view.attributedText != text else { return }
    view.attributedText = text
    view.showNewest()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: NewestInView, context: Context) -> CGSize? {
    let width = proposal.width ?? 320
    let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: min(fit.height, proposal.height ?? fit.height))
  }

  /// ponytail: every gesture the text view has now, set again on each update since UIKit adds some lazily; a Pencil
  /// touch on it then does nothing at all. If one ever slips through, subclass UITextView and filter in its
  /// `gestureRecognizerShouldBegin`.
  private func fingersOnly(_ view: UITextView) {
    let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    for gesture in view.gestureRecognizers ?? [] where gesture.allowedTouchTypes != fingers {
      gesture.allowedTouchTypes = fingers
    }
  }

  private static func text(_ rows: [WhiteboardNote.Row]) -> NSAttributedString {
    let body = UIFont.preferredFont(forTextStyle: .footnote)
    let bold = UIFont(
      descriptor: body.fontDescriptor.withSymbolicTraits(.traitBold) ?? body.fontDescriptor, size: body.pointSize)
    let text = NSMutableAttributedString()
    for (index, row) in rows.enumerated() {
      if index > 0 { text.append(NSAttributedString(string: "\n")) }
      let color: UIColor = row.kind == .larry ? .label : .secondaryLabel
      text.append(NSAttributedString(string: "\(row.who): ", attributes: [.font: bold, .foregroundColor: color]))
      text.append(NSAttributedString(string: row.text, attributes: [.font: body, .foregroundColor: color]))
      if let mark = row.mark {
        text.append(
          NSAttributedString(string: " · \(mark)", attributes: [.font: body, .foregroundColor: UIColor.tertiaryLabel]))
      }
    }
    return text
  }
}
