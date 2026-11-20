//  A board on paper (whiteboard spec's "On paper: the default", stories 590–657, 658; #636): PaperKit's controller, which
//  can't be subclassed, held in `PaperHost` with the page lines, the tool picker and the touch log; and on it
//  `PaperBoardController`, which draws on a board through its model, so it saves and syncs, with its ghosts, Larry's
//  marks, the mic and paste. A look-only board (another device's, or one drawn on the old canvas) shows the same way with
//  drawing off and no tools. Ghosts lie on the sheet under the ink, in
//  PaperKit's content view, so they move with the board whatever it does.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass
import UniformTypeIdentifiers

extension PaperMarkup {
  /// The ink as a drawing, in today's file format. The strokes are remade: PKDrawing(strokes:) on what
  /// `subelements.strokes` gives throws an Objective-C exception, nil into PencilKit's set of UUIDs, seen on the simulator
  /// on iOS 27 with ink appended from a drawing.
  var inkDrawing: PKDrawing {
    PKDrawing(
      strokes: subelements.strokes.map {
        PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform, mask: $0.mask, randomSeed: $0.randomSeed)
      })
  }

  /// `subelements.strokes`, not the set itself: walking the set by element took 4.3 s at 1,000 strokes on the simulator
  /// and over 40 s at 5,000.
  var strokeFrames: [String: CGRect] {
    Dictionary(
      subelements.strokes.map { (PaperHost.key($0.elementID), $0.renderFrame) }, uniquingKeysWith: { _, new in new })
  }
}

/// PaperKit's controller and what goes with it on any board: a see-through canvas over the paper and its lines, the tool
/// picker, the pinch's floor at the page's width, and what each touch did.
@MainActor
class PaperHost: UIViewController {
  /// One touch, first down to last up, and what came of it.
  struct TouchRun {
    var type: String
    var began: Double
    var start: CGPoint
    var visibleAtStart: CGRect
    var zoomAtStart: CGFloat
    var tool: String
    /// The pen's colour and width with the kind (`toolText`): Igor's own ink, told from a mark he kept.
    var ink: String = ""
    var facts = PaperProbe.TouchFacts()
    /// Every touch in it, so the Pencil is the Pencil whatever landed first (#825).
    var tally = PaperProbe.TouchTally()
    var selected = 0
    var frames = 0
    var maxGap: Double = 0
    var pageAdded = false

    var kind: String { "\(type)_down" }
  }

  let paper: PaperMarkupViewController
  let lines: PaperLines
  /// Held here: the tool picker disappears when nothing keeps it.
  private let picker = PKToolPicker()
  private let watcher = PaperTouchWatcher()
  private(set) var boardPaper: BoardPaper
  var paperColor: UIColor { boardPaper.color }
  /// False on a look-only board: nothing draws, and there's no tool picker; a finger still pans and pinches.
  var drawsHere = true

  private(set) var touchesDown = 0
  private(set) var pencilDown = false
  var run: TouchRun?
  private var runEnding: Task<Void, Never>?
  private var touchStarts: [ObjectIdentifier: (at: CGPoint, began: Double, farthest: CGFloat)] = [:]
  /// Fingers on the glass now, and together since the last time there were none. A Pencil beside one doesn't count.
  private var fingersDown = 0
  private var fingersTogether = 0
  private(set) var lastTouchBoardPoint: CGPoint?

  private static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  init(boardPaper: BoardPaper) {
    self.boardPaper = boardPaper
    paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: Self.features)
    lines = PaperLines(paper: boardPaper.color)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = paperColor
    addChild(paper)
    paper.view.frame = view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // A see-through canvas, the paper and its lines beneath the ink.
    paper.view.backgroundColor = .clear
    paper.view.isOpaque = false
    view.addSubview(paper.view)
    paper.didMove(toParent: self)
    paper.contentView = lines
    paper.isEditable = drawsHere
    watcher.changed = { [weak self] touch, phase, down in self?.touched(touch, phase, down: down) }
    view.addGestureRecognizer(watcher)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard drawsHere else { return }
    picker.addObserver(paper)
    picker.addObserver(self)
    toolChanged()
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard drawsHere else { return }
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
    picker.removeObserver(self)
  }

  func setBoardPaper(_ new: BoardPaper) {
    guard new != boardPaper else { return }
    boardPaper = new
    let color = new.color
    view.backgroundColor = color
    lines.backgroundColor = color
  }

  /// What zoom means is read off the screen, then the pinch's floor is the page's width. The caller puts the view back.
  @discardableResult
  func fit(columnWidth: CGFloat) -> CGFloat {
    let config = paper.scrollConfiguration
    config.bounces = .vertical
    config.visibleScrollIndicators = .vertical
    paper.zoomRange = 0.05...4
    config.zoomScale = 1
    paper.view.layoutIfNeeded()
    let fit =
      BoardPages.fitZoom(visibleWidth: paper.contentVisibleFrame.width, atZoom: config.zoomScale, column: columnWidth)
      ?? 1
    paper.zoomRange = fit...max(3, fit)
    config.zoomScale = fit
    paper.view.layoutIfNeeded()
    return fit
  }

  // MARK: - Touches

  private func touched(_ touch: UITouch, _ phase: PaperTouchWatcher.Phase, down: Int) {
    let at = touch.location(in: view)
    let id = ObjectIdentifier(touch)
    switch phase {
    case .began:
      if touchesDown == 0 {
        // A menu leaves nothing the first responder when it closes, and with that PaperKit drew no stroke and showed no tool
        // picker (3 of 3 on the simulator, iOS 27).
        if !paper.isFirstResponder { paper.becomeFirstResponder() }
        runEnding?.cancel()
        endRun()
        startRun(touch, at: at)
      }
      touchStarts[id] = (at, CACurrentMediaTime(), 0)
      run?.tally.down(id.hashValue, Self.name(touch.type), radius: touch.majorRadius)
      if touch.type == .pencil { pencilDown = true }
      if touch.type == .direct {
        fingersDown += 1
        fingersTogether += 1
      }
      touchWentDown(touch)
    case .moved:
      touchMoved(touch)
      if let start = touchStarts[id] {
        let went = hypot(at.x - start.at.x, at.y - start.at.y)
        touchStarts[id]?.farthest = max(start.farthest, went)
        if let travel = run?.facts.travel { run?.facts.travel = max(travel, went) }
      }
    case .ended, .cancelled:
      // Short, still and alone, whatever a Pencil is doing beside it. The system calling a touch off, as it does a palm, is
      // no tap.
      if phase == .ended, touch.type == .direct, let start = touchStarts[id],
        PaperProbe.isFingerTap(
          travel: max(start.farthest, hypot(at.x - start.at.x, at.y - start.at.y)),
          seconds: CACurrentMediaTime() - start.began,
          fingers: fingersTogether)
      {
        fingerTapped(at: start.at)
      }
      if phase == .ended, touch.type == .direct, fingersTogether == 1, let start = touchStarts[id] {
        fingerLifted(from: start.at, to: at, seconds: CACurrentMediaTime() - start.began)
      }
      if let start = touchStarts[id] {
        touchEnded(
          touch, cancelled: phase == .cancelled, seconds: CACurrentMediaTime() - start.began,
          travel: max(start.farthest, hypot(at.x - start.at.x, at.y - start.at.y)))
      }
      touchStarts[id] = nil
      if touch.type == .pencil { pencilDown = false }
      if touch.type == .direct {
        fingersDown = max(fingersDown - 1, 0)
        if fingersDown == 0 { fingersTogether = 0 }
      }
    }
    touchesDown = down
    if let fingers = run?.facts.fingers { run?.facts.fingers = max(fingers, down) }
    if phase == .ended || phase == .cancelled { touchLifted(touch, down: down) }
    if phase == .ended || phase == .cancelled, down == 0 {
      if let began = run?.began { run?.facts.seconds = CACurrentMediaTime() - began }
      // A pan's coasting and a selection's arrival come after the lift.
      runEnding = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(0.6))
        guard !Task.isCancelled else { return }
        self?.endRun()
      }
    }
  }

  private func startRun(_ touch: UITouch, at: CGPoint) {
    let visible = paper.contentVisibleFrame
    let scale = visible.width / max(view.bounds.width, 1)
    lastTouchBoardPoint = CGPoint(x: visible.minX + at.x * scale, y: visible.minY + at.y * scale)
    run = TouchRun(
      type: Self.name(touch.type), began: CACurrentMediaTime(), start: at, visibleAtStart: visible,
      zoomAtStart: paper.scrollConfiguration.zoomScale, tool: toolName, ink: toolText(paper.drawingTool))
  }

  /// The view closing: a touch still being watched goes in the log now.
  func finishTouches() {
    runEnding?.cancel()
    endRun()
  }

  private func endRun() {
    guard var run else { return }
    self.run = nil
    let visible = paper.contentVisibleFrame
    let zoom = paper.scrollConfiguration.zoomScale
    let (dx, dy) = (visible.minX - run.visibleAtStart.minX, visible.minY - run.visibleAtStart.minY)
    run.facts.scrolled = hypot(dx, dy)
    run.facts.zoomChanged = abs(zoom - run.zoomAtStart) > 0.001
    touchEnded(run, visible: visible, zoom: zoom, dx: dx, dy: dy)
  }

  func touchWentDown(_ touch: UITouch) {}
  func touchMoved(_ touch: UITouch) {}
  func touchLifted(_ touch: UITouch, down: Int) {}
  /// One touch came up (or was called off): how long it was down, and the farthest it went, in this view's points.
  func touchEnded(_ touch: UITouch, cancelled: Bool, seconds: Double, travel: CGFloat) {}
  /// The tool picker's tool changed; `paper.drawingTool` has it on the next turn.
  func toolChanged() {}
  /// One finger, short and staying put, at this spot in `view`, Pencil or no Pencil. PaperKit may do its own thing with the
  /// same touch.
  func fingerTapped(at spot: CGPoint) {}
  /// A lone finger came up, from where it went down, in this view's points (story 849).
  func fingerLifted(from start: CGPoint, to end: CGPoint, seconds: Double) {}

  /// What a touch came to, for the log.
  func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {}

  /// #945: after a margin tap PaperKit showed a box, the watcher heard no touch again, and ink moved with nothing
  /// selected. For a change no touch was heard making: what the watcher holds, and what is on top at `spot` (this
  /// view's points), the board or something over it.
  func watchState(at spot: CGPoint?) -> [String: Any] {
    var state: [String: Any] = [
      "watcher_state": Self.name(watcher.state), "watcher_down": watcher.held, "watcher_on": watcher.isEnabled,
      "touches_down": touchesDown, "in_window": view.window != nil,
    ]
    guard let spot, let window = view.window else { return state }
    let top = window.hitTest(view.convert(spot, to: window), with: nil)
    var chain: [String] = []
    var at = top
    while let seen = at, chain.count < 4 {
      chain.append(String(describing: type(of: seen)))
      at = seen.superview
    }
    state["hit"] = chain
    state["hit_on_board"] = top?.isDescendant(of: view) ?? false
    return state
  }

  static func name(_ state: UIGestureRecognizer.State) -> String {
    switch state {
    case .possible: return "possible"
    case .began: return "began"
    case .changed: return "changed"
    case .ended: return "ended"
    case .cancelled: return "cancelled"
    case .failed: return "failed"
    @unknown default: return "other"
    }
  }

  // MARK: - The log's words

  var toolName: String {
    switch paper.drawingTool {
    case let ink as PKInkingTool: return ink.inkType.rawValue
    case is PKEraserTool: return "eraser"
    case is PKLassoTool: return "lasso"
    default: return String(describing: type(of: paper.drawingTool))
    }
  }

  /// The pen in hand as the log says it: its kind, `#rrggbb` as in light mode, and width (context-grabber-a3w).
  func toolText(_ tool: any PKTool) -> String {
    guard let ink = tool as? PKInkingTool else { return toolName }
    var (red, green, blue): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    ink.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(
      &red, green: &green, blue: &blue, alpha: nil)
    let width = (ink.width * 100).rounded() / 100
    return "\(ink.inkType.rawValue) \(WhiteboardStrokes.hex(red: red, green: green, blue: blue)) \(width)"
  }

  func name(_ mode: PaperMarkupViewController.TouchMode) -> String {
    mode == .selection ? "selection" : "drawing"
  }

  static func name(_ type: UITouch.TouchType) -> String {
    switch type {
    case .direct: return "finger"
    case .pencil: return "pencil"
    case .indirect: return "indirect"
    case .indirectPointer: return "pointer"
    @unknown default: return "other"
    }
  }

  nonisolated static func key(_ id: MarkupOrderedSet.ElementID) -> String {
    if case .stroke(let uuid) = id { return uuid.uuidString }
    return String(describing: id)
  }

  func round(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }
  func ms(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }
  func seconds(_ value: Double) -> Double { (value * 100).rounded() / 100 }
  func point(_ p: CGPoint) -> [Double] { [round(p.x), round(p.y)] }
  func insets(_ i: UIEdgeInsets) -> [Double] { [round(i.top), round(i.left), round(i.bottom), round(i.right)] }

  func rect(_ r: CGRect) -> [Double] {
    r.isNull || r.isInfinite ? [] : [round(r.minX), round(r.minY), round(r.width), round(r.height)]
  }
}

/// A real board on paper, drawn on this device. The drawing goes through the board's model, as the old canvas's does.
@MainActor
final class PaperBoardController: PaperHost, ObservableObject, PaperMarkupViewController.Delegate {
  @Published private(set) var pageText = BoardPages().pageText(visibleMidY: 0, pages: 1)
  /// The chosen mark's box in this view's points, where Keep and Dismiss sit beside it (story 825); nil with none.
  @Published private(set) var choiceFrame: CGRect?
  /// Where the board is on screen, for its question cards (stories 880–886).
  let place = WhiteboardBoardPlace()
  /// Story 852: the paste just landed, selected, in this view's points, where its Delete sits; nil once anything else
  /// is selected or the ink changes.
  @Published private(set) var pastedFrame: CGRect?
  /// The landed paste's elements, by key.
  private var pasted: Set<String> = []
  /// Story 910: the lassoed arrow Connect would join, in this view's points, and its elements by key; nil with none.
  @Published var connectFrame: CGRect?
  var connectKeys: Set<String> = []
  var following: Task<Void, Never>?
  var selectedNewestForTests = false
  private var marking: Task<Void, Never>?
  /// Stories 902, 903: an eraser touch on a board with a fold, from where it went down (PaperBoard+FoldErase.swift).
  var foldErasing: FoldErasing?
  /// Story 858: the menu a held finger brought up, in this view's points; nil with none.
  @Published private(set) var holdMenu: HoldMenu?
  /// A finger held in the margin: where it went down, board `y`, and in this view.
  private var grip: (y: CGFloat, spot: CGPoint)?
  /// Story 933: the touch that went down in the margin, for its log line when it lifts, and whether the finger's hold
  /// recogniser fired for it.
  private var marginTry: (touch: ObjectIdentifier, tool: BoardMarginHold.Tool, y: CGFloat, held: Bool)?
  /// What the last touch to go down was: a stroke the Pencil drew is the one the margin's Pencil hold judges.
  private var lastDown: UITouch.TouchType?
  private lazy var holding: UILongPressGestureRecognizer = {
    let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
    hold.minimumPressDuration = BoardMargin.holdAfter
    hold.allowableMovement = BoardMargin.dragAfter
    hold.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    hold.cancelsTouchesInView = false
    hold.delegate = self
    return hold
  }()

  let model: WhiteboardModel
  let log: SessionLog
  /// Stories 920–922: To text beside the lasso's ink (BoardToTextFlow.swift).
  let toText = BoardToTextState()
  /// Stories 923–925: a stroke held still at its end snaps to its shape (BoardShapeSnapping.swift).
  let snaps = BoardSnapWatch()
  /// Stories 940–942: a kept text's words open in place (BoardRewordFlow.swift).
  let reword = BoardRewordState()
  /// A page wide, or wider for an old-canvas board's wider ink (story 658).
  private(set) var board = BoardPages()
  private(set) var pages = 1
  private var laidWidth: CGFloat = 0
  /// What the column's own changes shouldn't report as a person's.
  private var quiet = false
  private(set) var inkFrames: [String: CGRect] = [:]
  private var saidNotInk = false
  private var remembering: Task<Void, Never>?
  private var redrawing: Task<Void, Never>?
  private var responding: Task<Void, Never>?
  private var rules = PaperRules.none
  private var rulesLaid: (rules: PaperRules, pages: Int, step: CGFloat, y: ClosedRange<CGFloat>)?
  /// The window this board made light, and how it was.
  private var lightWindow: (window: UIWindow, style: UIUserInterfaceStyle)?
  /// A Pencil or a drawing finger is down, as the pacer was told.
  private var toolDown = false
  /// What a finger does when no ghost shows; set while they do, as it taps and doesn't draw.
  private var fingerUsually: (mode: PaperMarkupViewController.TouchMode, autoDraws: Bool)?
  /// A tap's selection comes after the lift: until this time one is put straight back.
  private var noSelectionUntil: Double = 0
  /// The last finger tap while marks showed, in board points, and when: the dot PaperKit draws there is taken back.
  private var ghostTap: (at: CGPoint, time: Double, within: Double)?
  /// How far a ghost's place on the sheet was from where the visible frame says, over this touch, and how many looks
  /// that took. For the iPad: the spec's "A ghost sits on the paper".
  private var seat = (worst: CGFloat(0), checks: 0)
  private var pressedForTests = false
  private var movedForTests = false
  /// The undo stack a kept mark's steps went on. A closing view may no longer be able to say.
  private weak var stepsOn: UndoManager?

  private var placeKey: String { "whiteboard_paper_y_\(model.board.id)" }

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    self.log = log
    super.init(boardPaper: model.paper)
    drawsHere = model.editable
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    paper.delegate = self
    model.visibleRect = { [weak self] in self?.paperOnScreen ?? .null }
    model.questions.visibleRect = { [weak self] in self?.paperOnScreen ?? .null }
    model.pasteReach = board.pasteReach
    model.zoom = { [weak self] in self?.screenScale ?? 1 }
    model.draw = { [weak self] _, added in self?.keep(added) }
    model.applyOps = { [weak self] batch in self?.applyOps(batch) }
    model.landPaste = { [weak self] strokes in self?.land(paste: strokes) ?? false }
    model.keepMakingRoom = { [weak self] strokes, push in self?.keep(strokes, making: push) ?? false }
    model.changeOutline = { [weak self] label, change in self?.changeOutline(label, change) ?? false }
    model.showOverlays = { [weak self] list in
      guard let self else { return }
      self.lines.showOverlays(list)
      // Story 846: with his controls showing, a finger taps them, as it taps ghosts, rather than drawing.
      self.fingerTaps(!self.model.ghosts.isEmpty || !list.isEmpty)
    }
    model.move = { [weak self] moves in self?.move(moves) }
    model.menuChose = { [weak self] in self?.takeTheResponderBack() }
    if model.editable { view.addGestureRecognizer(holding) }
    if drawsHere { view.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hovering(_:)))) }
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardShown(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
  }

  /// Stories 892, 893: the Pencil hovering over the paper, in board points. A pointer's hover has no height above the
  /// glass and isn't the Pencil.
  @objc private func hovering(_ hover: UIHoverGestureRecognizer) {
    guard hover.state == .began || hover.state == .changed, hover.zOffset > 0 else { return }
    model.hovered(at: lines.columnPoint(of: hover.location(in: lines)))
  }

  /// #850: whether a board raises the on-screen keyboard. On the iPad simulator one rose over an open Board menu and its
  /// tap didn't take; this says whether a real iPad does it too.
  @objc private func keyboardShown(_ note: Notification) {
    let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
    log.event(
      "whiteboard",
      [
        "action": "keyboard_shown", "height": Int(frame.height), "paper_has_it": paper.isFirstResponder,
        "taking_back": responding != nil,
      ])
  }

  /// The part of the column on screen: the visible frame runs past the paper where a phone's one page is shorter than the
  /// screen, and at a side.
  private var paperOnScreen: CGRect {
    let visible = paper.contentVisibleFrame
    let onPaper = visible.intersection(board.bounds(pages: pages))
    return onPaper.isNull || onPaper.isEmpty ? visible : onPaper
  }

  /// Screen points to a board point, whatever PaperKit's zoom scale means.
  var screenScale: CGFloat {
    view.bounds.width / max(paper.contentVisibleFrame.width, 1)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = view.bounds.width
    guard width > 0, width != laidWidth else { return }
    let first = laidWidth == 0
    laidWidth = width
    // On the next turn: PaperKit lays itself out first, and this publishes, which SwiftUI's update may not.
    Task { @MainActor [weak self] in
      guard let self else { return }
      if first { self.load() }
      self.fitToPage(first: first)
      self.placeCards()
      // #845: whether an opened board's ink is drawn, on every device's geometry.
      if first, let ink = self.paper.markup?.inkDrawing, !ink.strokes.isEmpty {
        self.lookForInk(ink.bounds, why: "open")
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    paper.becomeFirstResponder()
  }

  /// The whole window in light mode while a board on paper is up, whatever the device's. In dark mode PaperKit draws new
  /// ink so it can't be seen: black on Plain's black; and with only this controller's views set light, white on white on
  /// a new board, as PaperKit's canvas doesn't reliably take the override (the simulator, iOS 27, 2026-11-03). Saved ink
  /// is the same either way. ponytail: light only; a board in dark mode needs PaperKit's ink to follow the mode as
  /// PencilKit's canvas does, and a look on the iPad.
  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    guard lightWindow == nil, let window = view.window else { return }
    lightWindow = (window, window.overrideUserInterfaceStyle)
    window.overrideUserInterfaceStyle = .light
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    finishTouches()
    rememberPlace()
    lightWindow?.window.overrideUserInterfaceStyle = lightWindow?.style ?? .unspecified
    lightWindow = nil
  }

  private func load() {
    let started = CACurrentMediaTime()
    var drawing = model.drawing
    if model.oldCanvas {
      // Story 658: the old canvas put ink about 10,000 points from its corner. Moved, never scaled, to the first page's
      // corner for showing only: a look-only board saves nothing, so its file keeps the ink where it was.
      let placed = BoardPages.placing(ink: drawing.strokes.isEmpty ? nil : drawing.bounds)
      board = placed.board
      drawing = drawing.transformed(using: placed.transform)
    }
    pages = board.pagesNeeded(inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY)
    var markup = PaperMarkup(bounds: board.bounds(pages: pages))
    markup.append(contentsOf: drawing)
    quiet = true
    paper.markup = markup
    quiet = false
    inkFrames = paper.markup?.strokeFrames ?? [:]
    model.inkReset(paper.markup.map(Self.allHashes) ?? [:])
    showMarks()
    showLines()
    log.event(
      "whiteboard",
      [
        "action": "paper_open", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "width": Double(board.width), "ink": rect(drawing.strokes.isEmpty ? .zero : drawing.bounds),
        "editable": drawsHere, "ms": ms(CACurrentMediaTime() - started),
      ])
  }

  /// The page fits the screen's width, at the place he left it or, when only the width changed, the place it's at.
  private func fitToPage(first: Bool) {
    let y =
      first
      ? board.openingY(remembered: UserDefaults.standard.object(forKey: placeKey) as? Double, pages: pages)
      : paper.contentVisibleFrame.minY
    fit(columnWidth: board.width)
    let size = paper.contentVisibleFrame.size
    paper.contentVisibleFrame = CGRect(origin: CGPoint(x: 0, y: y), size: size)
    showPageNumber()
    layRules()
  }

  private func showLines() {
    lines.show(width: board.width, ends: board.pageEnds(pages: pages))
    layRules()
  }

  func setRules(_ wanted: PaperRules) {
    guard wanted != rules else { return }
    rules = wanted
    layRules()
    lookAfterChange()
  }

  override func setBoardPaper(_ new: BoardPaper) {
    guard new != boardPaper else { return }
    super.setBoardPaper(new)
    lookAfterChange()
  }

  /// A choice in the menu, which leaves nothing the first responder as it closes: PaperKit then draws no stroke, and shows no
  /// tool picker (3 of 3 on the simulator, iOS 27), and giving it back as the touch lands is too late for that touch (5 of 5).
  /// So it goes back as the menu goes, for as long as that takes.
  private func takeTheResponderBack() {
    responding?.cancel()
    responding = Task { @MainActor [weak self] in
      var lost = 0
      for _ in 0..<30 {
        try? await Task.sleep(for: .seconds(0.1))
        guard let self, !Task.isCancelled else { return }
        if !self.paper.isFirstResponder {
          lost += 1
          self.paper.becomeFirstResponder()
        }
      }
      self?.log.event(
        "whiteboard",
        ["action": "paper_responder", "times_lost": lost, "has_it": self?.paper.isFirstResponder ?? false])
      self?.responding = nil
    }
  }

  /// The sheet changed under the ink, which must not lose it: `paper_ink_look` says if it did.
  private func lookAfterChange() {
    guard let ink = paper.markup?.inkDrawing, !ink.strokes.isEmpty else { return }
    lookForInk(ink.bounds, why: "sheet")
  }

  /// The grid or ruled lines for a screen above and below the view, so they're laid again only now and then in a scroll, and
  /// when the zoom thins them or a page is added.
  private func layRules() {
    let zoom = screenScale
    let visible = paper.contentVisibleFrame
    let step = WhiteboardFrame.lineStep(zoom: zoom)
    lines.hair = 1 / (traitCollection.displayScale * max(zoom, 0.01))
    if let laid = rulesLaid, laid.rules == rules, laid.pages == pages, laid.step == step,
      laid.y.contains(visible.minY), laid.y.contains(visible.maxY)
    {
      return
    }
    let y = (visible.minY - visible.height)...(visible.maxY + visible.height)
    rulesLaid = (rules, pages, step, y)
    switch rules {
    case .none:
      lines.showRules(across: [], span: 0...0, down: [])
    case .ruled:
      lines.showRules(across: [], span: 0...0, down: board.ruledLines(visible: y, pages: pages, zoom: zoom))
    case .grid:
      let area = CGRect(x: 0, y: y.lowerBound, width: board.width, height: y.upperBound - y.lowerBound)
      let grid = board.gridLines(visible: area, pages: pages, zoom: zoom)
      let column = board.bounds(pages: pages)
      let span = min(max(y.lowerBound, 0), column.maxY)...max(min(y.upperBound, column.maxY), 0)
      lines.showRules(across: grid.across, span: span, down: grid.down)
    }
  }

  private func showPageNumber() {
    let text = board.pageText(visibleMidY: paper.contentVisibleFrame.midY, pages: pages)
    if text != pageText { pageText = text }
    model.screenMoved()
  }

  private func rememberPlace() {
    remembering?.cancel()
    UserDefaults.standard.set(Double(paper.contentVisibleFrame.minY), forKey: placeKey)
  }

  // MARK: - PaperKit's delegate

  func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
    guard !quiet, let markup = controller.markup else { return }
    let started = CACurrentMediaTime()
    let frames = markup.strokeFrames
    let previous = inkFrames
    let change = PaperProbe.inkChange(before: inkFrames, after: frames)
    inkFrames = frames
    let consumed =
      takesBackTapDot(change, frames: frames) || marginHeld(change, markup: markup)
      || pickedUp(change, markup: markup, before: previous) || scratchesOut(change, markup)
    snapNoticed(change, consumed: consumed)
    if consumed { return }
    if !change.isEmpty {
      forgetPaste()
      showMarksSoon()
      followSoon()
    }
    defer {
      // Story 843: after the model's revision has moved on.
      if !change.isEmpty {
        model.inkElements(
          updated: Self.hashes(of: Set(change.added + change.moved.map(\.id)), in: markup), removed: change.removed,
          report: true)
      }
    }
    run?.facts.inkAdded += change.added.count
    run?.facts.inkMoved += change.moved.count
    run?.facts.inkRemoved += change.removed.count
    if !saidNotInk, markup.subelements.count != frames.count {
      // Only strokes are saved, and the tools offered only make strokes: this says if that ever stops being true.
      saidNotInk = true
      log.event(
        "whiteboard",
        [
          "action": "paper_not_ink", "board": model.board.id, "elements": markup.subelements.count,
          "strokes": frames.count,
        ])
    }
    let drawing = markup.inkDrawing
    model.changed(drawing)
    if change.added.count > 0 {
      pressSoonForTests()
      goToPageSoonForTests()
    }
    // An undo can take back a page added earlier: the count follows what the markup holds.
    pages = board.pages(in: markup.bounds)
    let wanted = board.pages(
      after: pages, inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY,
      redoWaiting: controller.undoManager?.canRedo ?? false)
    var event: [String: Any] = [
      "action": "paper_ink", "board": model.board.id, "strokes": frames.count, "pages": pages, "wanted": wanted,
      "added": change.added.count, "moved": change.moved.count, "removed": change.removed.count,
      "added_box": rect(change.added.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }),
      "can_undo": controller.undoManager?.canUndo ?? false, "can_redo": controller.undoManager?.canRedo ?? false,
      "ms": ms(CACurrentMediaTime() - started),
    ]
    event.merge(unheard(change, frames: frames, undo: controller.undoManager)) { $1 }
    log.event("whiteboard", event)
    showLines()
    showPageNumber()
    showToText()
    // Not from inside PaperKit's own callback.
    if wanted > pages { Task { @MainActor [weak self] in self?.grow(to: wanted) } }
    pushesOnMove(change, markup: markup, undo: controller.undoManager)
  }

  /// Stories 973–975: a lasso selection dragged onto ink pushes what is below down clear of it, as a paste's room
  /// does, and the drag and the push are one Undo named *Move*. Only a drag by hand: an Undo or Redo never pushes.
  private func pushesOnMove(_ change: PaperProbe.InkChange, markup: PaperMarkup, undo: UndoManager?) {
    guard drawsHere, !change.moved.isEmpty, change.added.isEmpty, change.removed.isEmpty,
      undo?.isUndoing != true, undo?.isRedoing != true
    else { return }
    let selected = Set(paper.selection.map(Self.key))
    let movedKeys = Set(change.moved.map(\.id))
    guard movedKeys.isSubset(of: selected) else { return }
    let frames = markup.strokeFrames
    let block = movedKeys.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    let back = Dictionary(uniqueKeysWithValues: change.moved.map { ($0.id, $0) })
    let (strokes, hashes) = opStrokes(markup)
    let elements = markup.subelements.strokes
    let dragged = Set(elements.indices.filter { movedKeys.contains(Self.key(elements[$0].elementID)) })
    let tags = model.outline(of: strokes).tags
    let others = strokes.indices.filter { !dragged.contains($0) }.map { strokes[$0] }
    let ink = BoardOps.shownBoxes(strokes: others, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    var event: [String: Any] = [
      "action": "paper_drop", "board": model.board.id, "strokes": movedKeys.count, "at": rect(block),
    ]
    let from = movedKeys.compactMap { key in
      frames[key].flatMap { box in back[key].map { box.offsetBy(dx: -$0.dx, dy: -$0.dy) } }
    }.reduce(CGRect.null) { $0.union($1) }
    event["from"] = rect(from)
    guard let push = BoardRoom.drop(block, from: from, among: ink) else {
      event["room"] = false
      log.event("whiteboard", event)
      return
    }
    var plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: tags, pages: pages, board: board)
    // What he dropped stays where he let go of it.
    for index in dragged { plan.offsets[index] = nil }
    // The board before the drag: the dragged strokes back where they were.
    var before = markup
    for element in elements {
      guard let move = back[Self.key(element.elementID)] else { continue }
      var stroke = element
      stroke.applyTransform(CGAffineTransform(translationX: -move.dx, y: -move.dy))
      _ = before.subelements.updateOrAppend(stroke)
    }
    event.merge(["room": true, "cut": Double(push.cut), "dy": Double(push.dy), "moved": plan.moved]) { $1 }
    // Not from inside PaperKit's own callback: its step for the drag is taken back, and one step for both goes on.
    Task { @MainActor [weak self] in
      guard let self else { return }
      let undo = self.paper.undoManager
      self.quiet = true
      if undo?.canUndo ?? false { undo?.undo() }
      self.quiet = false
      event["undid_drag"] = self.paper.markup.map { Self.close($0.strokeFrames, before.strokeFrames) } ?? false
      let framesBefore = self.inkFrames
      self.registerStepBack(to: before, named: "Move")
      guard let (held, _, _) = self.put(plan, on: markup, hashes: hashes, named: "Move", stepBack: false) else {
        event["failed"] = true
        self.log.event("whiteboard", event)
        return
      }
      self.model.stepped(held.inkDrawing)
      self.noteInk(held, since: framesBefore, report: true)
      event["pages"] = self.pages
      self.log.event("whiteboard", event)
    }
  }

  /// Every stroke where it was, to half a point.
  private static func close(_ a: [String: CGRect], _ b: [String: CGRect]) -> Bool {
    a.count == b.count
      && a.allSatisfy { key, box in b[key].map { abs($0.minX - box.minX) + abs($0.minY - box.minY) < 0.5 } ?? false }
  }

  /// The markup's bounds are the only way PaperKit's interface has to change the column. On Igor's iPad, 2026-11-03, a
  /// page added like this kept a stroke under way under the Pencil, and the view where it was.
  private func grow(to wanted: Int) {
    guard wanted > pages, var markup = paper.markup else { return }
    markup.bounds = board.bounds(pages: wanted)
    quiet = true
    paper.markup = markup
    quiet = false
    pages = wanted
    run?.pageAdded = true
    showLines()
    showPageNumber()
    redrawSoon()
  }

  func paperMarkupViewControllerDidChangeSelection(_ controller: PaperMarkupViewController) {
    run?.facts.selectionChanges += 1
    run?.selected = controller.selection.count
    let putBack = !controller.selection.isEmpty && CACurrentMediaTime() < noSelectionUntil
    logSelection(controller.selection, putBack: putBack)
    if putBack { controller.selection = [] }
    // Story 844: what the lasso holds, for Larry.
    let keys = Set(controller.selection.map(Self.key))
    if !pasted.isEmpty, keys != pasted { forgetPaste() }
    model.selectionChanged(keys)
    showToText()
    offerConnect(keys)
  }

  /// #945: every selection PaperKit reports, with what it holds and whether a touch was heard making it.
  private func logSelection(_ selection: Set<MarkupOrderedSet.ElementID>, putBack: Bool) {
    let keys = selection.map(Self.key)
    let box = keys.compactMap { inkFrames[$0] }.reduce(CGRect.null) { $0.union($1) }
    var event: [String: Any] = [
      "action": "paper_selection", "board": model.board.id, "selected": selection.count,
      "strokes": keys.filter { inkFrames[$0] != nil }.count, "box": rect(box), "put_back": putBack,
      "in_touch": run != nil, "touch_mode": name(paper.directTouchMode),
    ]
    if run == nil { event.merge(watchState(at: box.isNull ? nil : viewSpot(box))) { $1 } }
    log.event("whiteboard", event)
  }

  /// #945: the ink's change, said with whether a touch was heard making it and what was selected; with none heard (and
  /// no Undo or Redo), what the watcher holds and what is on top where the ink changed.
  private func unheard(_ change: PaperProbe.InkChange, frames: [String: CGRect], undo: UndoManager?) -> [String: Any] {
    let undoing = undo?.isUndoing == true || undo?.isRedoing == true
    var fields: [String: Any] = ["in_touch": run != nil, "selected": paper.selection.count, "undoing": undoing]
    guard run == nil, !undoing, !change.isEmpty else { return fields }
    let box = (change.added + change.moved.map(\.id)).compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    fields.merge(watchState(at: box.isNull ? nil : viewSpot(box))) { $1 }
    return fields
  }

  /// A box on the board, its centre in this view's points.
  private func viewSpot(_ box: CGRect) -> CGPoint {
    lines.convert(lines.spot(of: CGPoint(x: box.midX, y: box.midY)), to: view)
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
    // A finger drawing is only known from here. Late, it's a stroke already over, with no lift to come.
    if touchesDown > 0 { toolWentDown() }
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    showPageNumber()
    showChoice()
    placeCards()
    showPasted()
    showToText()
    showConnect()
    layRules()
    checkSeat()
    remembering?.cancel()
    remembering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled, let self else { return }
      self.rememberPlace()
      // Story 850: where the view came to rest, for Larry.
      self.model.viewRested(self.paper.contentVisibleFrame, scale: self.screenScale)
    }
  }

  // MARK: - Ghosts

  /// The ghosts on the sheet, and a finger that taps while they show.
  func show(_ ghosts: [Ghost]) {
    Task { @MainActor [weak self] in self?.showChoice() }
    guard lines.ghostLayers.show(ghosts) else { return }
    fingerTaps(!ghosts.isEmpty || !model.overlays.list.isEmpty)
    let drawn = ghosts.flatMap(\.lines)
    log.event(
      "whiteboard",
      [
        "action": "paper_ghosts", "board": model.board.id, "count": ghosts.count,
        // #941: how many of each kind show, so a mark that never drew is told from one that can't be tapped.
        "kinds": Dictionary(ghosts.map { ($0.kind.rawValue, 1) }, uniquingKeysWith: +),
        "past_side": board.reachesPastSide(drawn), "pages": pages, "visible": rect(paper.contentVisibleFrame),
        "sheet": rect(lines.bounds),
        "screen_scale": Double(screenScale),
      ])
    checkSeat()
  }

  /// Where the chosen mark is on screen now, for its Keep and Dismiss. The board's points map to the view's by a scale and
  /// a shift, so two corners place the whole box.
  func showChoice() {
    var frame: CGRect?
    if let ghost = model.chosen {
      let box = WhiteboardMarkChoice.bounds(ghost.lines)
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    guard frame != choiceFrame else { return }
    choiceFrame = frame
    log.event(
      "whiteboard",
      [
        "action": "mark_buttons", "board": model.board.id, "chosen": model.chosen != nil,
        "frame": frame.map { rect($0) } ?? [], "view": rect(view.bounds),
      ])
  }

  /// As the old canvas's `.pencilOnly`, which PaperKit doesn't have: a finger selects rather than draws, and a tap's
  /// selection is put straight back, so a tap leaves nothing.
  private func fingerTaps(_ taps: Bool) {
    if taps, fingerUsually == nil {
      fingerUsually = (paper.directTouchMode, paper.directTouchAutomaticallyDraws)
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .selection
    } else if !taps, let usual = fingerUsually {
      fingerUsually = nil
      paper.directTouchMode = usual.mode
      paper.directTouchAutomaticallyDraws = usual.autoDraws
    }
  }

  /// Where the sheet has a ghost against where the visible frame says it should be, in screen points.
  private func checkSeat() {
    guard let point = model.ghosts.first?.lines.first?.first else { return }
    let visible = paper.contentVisibleFrame
    let onSheet = lines.convert(lines.spot(of: point), to: view)
    let scale = screenScale
    let framed = CGPoint(x: (point.x - visible.minX) * scale, y: (point.y - visible.minY) * scale)
    seat.worst = max(seat.worst, hypot(onSheet.x - framed.x, onSheet.y - framed.y))
    seat.checks += 1
  }

  override func fingerLifted(from start: CGPoint, to end: CGPoint, seconds: Double) {
    let column = { (spot: CGPoint) in self.lines.columnPoint(of: self.view.convert(spot, to: self.lines)) }
    model.fingerLifted(from: column(start), to: column(end), seconds: seconds)
  }

  override func fingerTapped(at spot: CGPoint) {
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    // Story 818: Larry hears every tap, marks showing or not.
    model.tapped(at: at, zoom: screenScale)
    let count = model.ghosts.count
    // Story 855: a margin tap is the outline's; a dot a drawing finger leaves there is taken back.
    if at.x < BoardMargin.width {
      ghostTap = (at, CACurrentMediaTime(), PaperProbe.tapDotSeconds)
      noSelectionUntil = CACurrentMediaTime() + 0.8
      return
    }
    // Story 940: with no marks to choose, a tap on a kept text opens its words (or, with them open, is done).
    if count == 0, rewordTapped(at: at) {
      noSelectionUntil = CACurrentMediaTime() + 0.8
      ghostTap = (at, CACurrentMediaTime(), PaperProbe.rewordDotSeconds)
      return
    }
    // With his controls showing a finger taps too (story 846): no dot, no selection.
    guard count > 0 || !model.overlays.list.isEmpty else { return }
    noSelectionUntil = CACurrentMediaTime() + 0.8
    ghostTap = (at, CACurrentMediaTime(), PaperProbe.tapDotSeconds)
    let selected = paper.selection.count
    if selected > 0 { paper.selection = [] }
    guard count > 0 else { return }
    model.tap(at: at, zoom: screenScale)
    log.event(
      "whiteboard",
      [
        "action": "paper_tap", "board": model.board.id, "at": point(at), "ghosts_before": count,
        "ghosts_after": model.ghosts.count, "chosen": model.chosen != nil, "selected_at_tap": selected,
        "touch_mode": name(paper.directTouchMode), "auto_draws": paper.directTouchAutomaticallyDraws,
        "screen_scale": Double(screenScale),
      ])
  }

  /// Stories 616, 825 (#883): a finger tap while marks show draws no dot. PaperKit draws one at the tap all the same, a
  /// few tenths of a second after the lift, with a finger set not to draw; its own undo takes it back, so the stack holds
  /// no step for it, and the board never sees it: no stroke for Claude to answer, whose new marks would put the chosen
  /// one's Keep and Dismiss away.
  /// ponytail: the dot is undone once it has landed, which leaves it as Redo until the next step; stopping PaperKit
  /// drawing it is the upgrade, should a setting ever do that.
  private func takesBackTapDot(_ change: PaperProbe.InkChange, frames: [String: CGRect]) -> Bool {
    guard let tap = ghostTap, change.removed.isEmpty, change.moved.isEmpty else { return false }
    let since = CACurrentMediaTime() - tap.time
    let added = change.added.compactMap { frames[$0] }
    guard PaperProbe.isTapDot(added: added, tap: tap.at, secondsSince: since, zoom: screenScale, within: tap.within)
    else { return false }
    ghostTap = nil
    let dot = change.added
    Task { @MainActor [weak self] in
      guard let self else { return }
      let undo = self.paper.undoManager
      let could = undo?.canUndo ?? false
      let before = self.paper.markup?.strokeFrames ?? [:]
      if could { undo?.undo() }
      let wanted = before.filter { !dot.contains($0.key) }
      let gone = could && PaperProbe.inkChange(before: wanted, after: self.paper.markup?.strokeFrames ?? [:]).isEmpty
      if !gone {
        if could { undo?.redo() }
        if let markup = self.paper.markup { self.model.changed(markup.inkDrawing) }
      }
      self.log.event(
        "whiteboard",
        [
          "action": "paper_tap_dot", "board": self.model.board.id, "at": self.point(tap.at),
          "dot": self.rect(added.first ?? .null), "ms": self.ms(since), "could_undo": could, "gone": gone,
          "strokes": self.inkFrames.count,
        ])
    }
    return true
  }

  /// Stories 890, 891: a fast zigzag over ink takes it and itself away, one undo bringing the ink back. PaperKit's own
  /// step for the zigzag is undone first, as for the tap's dot, so the stack holds only the scratch-out's.
  private func scratchesOut(_ change: PaperProbe.InkChange, _ markup: PaperMarkup) -> Bool {
    guard drawsHere, change.added.count == 1, change.removed.isEmpty, change.moved.isEmpty,
      let key = change.added.first, let scratch = markup.scratch(key)
    else { return false }
    let outcome = scratch.outcome
    var event: [String: Any] = [
      "action": "scratch", "board": model.board.id, "fired": outcome.ok, "reversals": outcome.reversals,
      "strokes": outcome.gone.count,
    ]
    if let speed = outcome.speed { event["speed"] = speed }
    if let why = outcome.why { event["why"] = why }
    // Story 905: over a fold's marker or its folded header line, the whole section goes with what else it covered.
    if scratchTakesFolds(scratch, zigzag: key) { return true }
    guard let after = scratch.after else {
      log.event("whiteboard", event)
      return false
    }
    Task { @MainActor [weak self] in
      guard let self else { return }
      let undo = self.paper.undoManager
      if undo?.canUndo ?? false { undo?.undo() }
      // The zigzag's own step may not have been the one undone: the markup before it is set either way.
      event["undid_zigzag"] = self.paper.markup?.strokeFrames[key] == nil
      self.registerStepBack(to: scratch.before)
      self.quiet = true
      self.paper.markup = after
      self.quiet = false
      let framesBefore = self.inkFrames
      self.inkFrames = after.strokeFrames
      self.model.stepped(after.inkDrawing)
      self.noteInk(after, since: framesBefore, report: true)
      self.log.event("whiteboard", event)
      self.redrawSoon()
    }
    return true
  }

  // MARK: - Paste

  /// ⌘V, ahead of whatever PaperKit's own views would do with it.
  override var keyCommands: [UIKeyCommand]? {
    let key = UIKeyCommand(input: "v", modifierFlags: .command, action: #selector(pasteKeyPressed))
    key.wantsPriorityOverSystemBehavior = true
    return (super.keyCommands ?? []) + [key]
  }

  @objc private func pasteKeyPressed() { paste(from: "key") }

  /// Text is ink, in the middle of the view. Copied strokes are PaperKit's to place if it will, and landed here if not: nothing
  /// on the simulator takes them, and whether the iPad's PaperKit does is what this line will say. Only a picture is refused: only
  /// strokes are saved, so one on the sheet would go when he left. Strokes first, as a copy may hold a picture of them too. hasStrings
  /// asks without reading, so no prompt shows for nothing. (The spec's "Paste on paper".)
  private func paste(from how: String) {
    let clipboard = UIPasteboard.general
    var event: [String: Any] = [
      "action": "paper_paste", "board": model.board.id, "how": how, "has_text": clipboard.hasStrings,
      "has_image": clipboard.hasImages, "types": Array(clipboard.types.prefix(8)),
      "strokes_before": model.drawing.strokes.count,
    ]
    defer { log.event("whiteboard", event) }
    if clipboard.hasStrings, let text = clipboard.string {
      event["went"] = "ink"
      model.paste(text)
      return
    }
    let copied = copiedStrokes(clipboard)
    if copied == nil, clipboard.hasImages {
      event["went"] = "refused_picture"
      return
    }
    let paste = #selector(UIResponderStandardEditActions.paste(_:))
    let took = UIApplication.shared.sendAction(paste, to: nil, from: self, for: nil)
    if took {
      event["went"] = "paperkit"
    } else if let copied {
      event["went"] = "landed_here"
      event["strokes"] = copied.count
      model.paste(strokes: moved(copied))
    } else {
      event["went"] = "nobody"
    }
  }

  /// Story 852, as the web board's paste: in the clear patch of the view nearest its middle; else room opens at the
  /// clear line nearest the middle, the ink below pushed down whole lines, and the paste lands in it. The push and the
  /// paste are one undo. It lands selected, with Delete beside it.
  private func land(paste strokes: [PKStroke]) -> Bool {
    guard let markup = paper.markup, !strokes.isEmpty else { return false }
    let started = CACurrentMediaTime()
    let (ink, hashes) = opStrokes(markup)
    let block = PKDrawing(strokes: strokes).bounds
    let view = paperOnScreen
    let tags = model.outline(of: ink).tags
    let landing = BoardRoom.place(
      block.size, view: view,
      ink: BoardOps.shownBoxes(strokes: ink, texts: model.texts, groups: model.strokeMeta.groups, folds: tags),
      pageWidth: board.width)
    let by = CGAffineTransform(translationX: landing.origin.x - block.minX, y: landing.origin.y - block.minY)
    let placed = strokes.map {
      PKStroke(
        ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(by), mask: $0.mask,
        randomSeed: $0.randomSeed)
    }
    let ops = landing.push.map { [BoardOps.Op.translateBelow(y: $0.cut, dy: $0.dy)] } ?? []
    var plan = BoardOps.plan(
      ops, strokes: ink, texts: model.texts, metas: model.strokeMeta, folds: tags, pages: pages, board: board)
    let landedBox = PKDrawing(strokes: placed).bounds
    plan.pagesAfter = board.pages(after: plan.pagesAfter, inkMaxY: landedBox.maxY, redoWaiting: false)
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, adding: placed, named: "Paste") else { return false }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    let ids = Array(held.subelements.strokes.map(\.elementID).suffix(placed.count))
    pasted = Set(ids.map(Self.key))
    paper.selection = Set(ids)
    showPasted()
    log.event(
      "whiteboard",
      [
        "action": "paper_paste_landed", "board": model.board.id, "strokes": placed.count, "at": rect(landedBox),
        "view": rect(view), "clear": landing.push == nil, "cut": landing.push.map { Double($0.cut) } ?? NSNull(),
        "dy": Double(landing.push?.dy ?? 0), "moved": plan.moved, "pages_before": plan.pagesBefore, "pages": pages,
        "selected": paper.selection.count, "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterKeep)
    lookForInk(landedBox, why: "pasted")
    return true
  }

  /// #938 (story 992): a ghost of Larry's text kept where Igor's ink has come under it. The room opens and the text
  /// lands in one change, one undo named *Keep*, as a paste and its room are one.
  private func keep(_ strokes: [PKStroke], making push: BoardRoom.Push) -> Bool {
    guard let markup = paper.markup, !strokes.isEmpty else { return false }
    let (ink, hashes) = opStrokes(markup)
    var plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: ink, texts: model.texts, metas: model.strokeMeta,
      folds: model.outline(of: ink).tags, pages: pages, board: board)
    plan.pagesAfter = board.pages(
      after: plan.pagesAfter, inkMaxY: PKDrawing(strokes: strokes).bounds.maxY, redoWaiting: false)
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, adding: strokes, named: "Keep") else { return false }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event(
      "board_room",
      [
        "action": "keep_text", "board": model.board.id, "cut": Double(push.cut), "dy": Double(push.dy),
        "moved": plan.moved, "pages_before": plan.pagesBefore, "pages": pages,
      ])
    return true
  }

  /// Stories 855–860: an outline change on the markup, one undo named `label`: what folds hides, what is below slides,
  /// and the headers are kept. A header made or unmade alone changes only the marks.
  /// `base` is the markup the change starts from (the board's own by default) and `undoTo` where its Undo goes back to
  /// (`base`, by default): a scratch-out's fold erase starts without the zigzag's other ink and undoes to before it.
  func changeOutline(
    _ label: String, on base: PaperMarkup? = nil, undoTo: PaperMarkup? = nil, _ change: (inout BoardOutline) -> Bool
  ) -> Bool {
    guard let markup = base ?? paper.markup else { return false }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    var outline = model.outline(of: strokes)
    guard change(&outline) else { return false }
    var plan = outline.plan(from: strokes, pages: pages, board: board)
    // Stories 911, 915: a fold moves ink, and the connectors follow it.
    BoardConnectors.follow(
      &plan, strokes: strokes, texts: model.texts, metas: model.strokeMeta, folds: outline.tags)
    if plan.changesBoard {
      guard let (held, renamed, _) = put(plan, on: markup, hashes: hashes, named: label, undoTo: undoTo) else {
        return false
      }
      model.opsApplied(held.inkDrawing, renamed: renamed)
      model.inkReset(Self.allHashes(held))
    }
    model.outlineChanged(outline)
    showMarks()
    log.event(
      "board_outline",
      [
        "action": "changed", "board": model.board.id, "label": label, "moved": plan.offsets.count,
        "hidden": plan.hidden.values.filter { $0 }.count, "shown": plan.hidden.values.filter { !$0 }.count,
        "headers": outline.headers.count, "folded": outline.headers.filter(outline.isFolded).count,
        "pages": pages, "ms": ms(CACurrentMediaTime() - started),
      ])
    return true
  }

  /// The margin's marks: ▾ beside a header, ▸ and its lines beside a folded one, a faint H beside a line that looks
  /// like one (stories 855, 861). Soon after a change, not on every stroke's every point.
  private func showMarksSoon() {
    marking?.cancel()
    marking = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.4))
      guard !Task.isCancelled else { return }
      self?.showMarks()
    }
  }

  private func showMarks() {
    guard let markup = paper.markup else { return }
    // ponytail: the whole board's outline on each change, ~ms per hundred strokes; incremental by changed line if
    // a long board feels it.
    let outline = model.outline(of: opStrokes(markup).strokes)
    var marks: [PaperLines.Mark] = []
    for header in outline.headers where outline.shows(header) {
      guard let box = outline.box(header) else { continue }
      let folded = outline.isFolded(header)
      marks.append(
        PaperLines.Mark(
          id: "header-\(header.id)", y: box.midY, text: folded ? "▸ \(header.fold?.lines ?? 0)" : "▾", faint: false))
    }
    // Story 901: "▸ N lines folded" beside a folded header, where the eraser takes the fold.
    for marker in outline.markers {
      marks.append(
        PaperLines.Mark(
          id: "fold-\(marker.header)", y: marker.box.midY, text: marker.text, faint: false, x: marker.origin.x))
    }
    for (n, candidate) in outline.candidates().enumerated() {
      marks.append(PaperLines.Mark(id: "candidate-\(n)", y: candidate.y, text: "H", faint: true))
    }
    lines.showMarks(marks)
  }

  // MARK: - Press and hold (#918)

  /// Story 858, as the web board: a finger held in the margin is the room handle, and the drag opens or closes room
  /// when it lifts; held still there, or anywhere on the page, it brings up the menu.
  @objc private func held(_ hold: UILongPressGestureRecognizer) {
    let spot = hold.location(in: view)
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    switch hold.state {
    case .began:
      holdMenu = nil
      if marginTry?.tool == .finger { marginTry?.held = true }
      if at.x < BoardMargin.width,
        model.outline(of: paper.markup.map { opStrokes($0).strokes } ?? []).header(at: at.y) == nil
      {
        grip = (at.y, spot)
        scrolls(false)
      } else {
        showHoldMenu(at: at, spot: spot)
      }
    case .ended, .cancelled, .failed:
      guard let grip else { return }
      self.grip = nil
      scrolls(true)
      let dy = (spot.y - grip.spot.y) / max(screenScale, 0.01)
      if hold.state == .ended, abs(dy) >= BoardRoom.line / 2 {
        room(at: grip.y, dy: dy, why: "margin_drag")
      } else if hold.state == .ended {
        showHoldMenu(at: CGPoint(x: 0, y: grip.y), spot: grip.spot)
      }
    default:
      break
    }
  }

  /// PaperKit's own scrolling, off while a finger holds the margin's handle so the drag is the handle's.
  /// ponytail: found by walking PaperKit's views for its scroll view; a PaperKit setting is the upgrade if one comes.
  private func scrolls(_ on: Bool) {
    func scrollViews(_ view: UIView) -> [UIScrollView] {
      ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrollViews)
    }
    for scroll in scrollViews(paper.view) { scroll.panGestureRecognizer.isEnabled = on }
  }

  private func showHoldMenu(at point: CGPoint, spot: CGPoint) {
    let outline = model.outline(of: paper.markup.map { opStrokes($0).strokes } ?? [])
    var items: [HoldMenu.Item] = []
    if point.x < BoardMargin.width, outline.header(at: point.y) != nil {
      items = [.foldAll, .level(1), .level(2), .level(3), .unfoldAll]
    } else {
      items = [.makeRoom, .paste]
      if let row = outline.row(at: point.y) {
        if let header = row.header {
          items.append(.notHeader(header))
        } else if !row.names.isEmpty {
          items.append(.makeHeader)
        }
      }
    }
    holdMenu = HoldMenu(spot: spot, y: point.y, items: items)
    log.event(
      "board_outline",
      ["action": "hold_menu", "board": model.board.id, "y": Double(point.y), "items": items.map(\.id)])
  }

  /// A choice from the hold menu.
  func chose(_ item: HoldMenu.Item) {
    guard let menu = holdMenu else { return }
    holdMenu = nil
    log.event("board_outline", ["action": "hold_chose", "board": model.board.id, "item": item.id])
    switch item {
    case .makeRoom: room(at: menu.y, dy: 3 * BoardRoom.line, why: "menu")
    case .paste: paste(from: "hold")
    case .makeHeader:
      _ = changeOutline("Make header") { $0.markHeader(at: menu.y, id: WhiteboardModel.newHeaderID()) }
    case .notHeader(let id):
      _ = changeOutline("Not a header") { outline in
        outline.unmark(id)
        return true
      }
    case .foldAll:
      _ = changeOutline("Fold all") { outline in
        outline.foldAll()
        return true
      }
    case .unfoldAll:
      _ = changeOutline("Unfold all") { outline in
        outline.unfoldAll()
        return true
      }
    case .level(let n):
      _ = changeOutline("Collapse to \(n)") { outline in
        outline.collapse(to: n)
        return true
      }
    }
  }

  func dismissHoldMenu() { holdMenu = nil }

  /// Room by Igor's hand (stories 858): the push at the clear line nearest `y`, `dy` in whole lines, one undo named
  /// *Make room*. Larry hears the ink that moved.
  private func room(at y: CGFloat, dy: CGFloat, why: String) {
    guard let markup = paper.markup else { return }
    let (strokes, hashes) = opStrokes(markup)
    let tags = model.outline(of: strokes).tags
    let boxes = BoardOps.shownBoxes(strokes: strokes, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    guard let push = BoardRoom.byHand(boxes, at: y, dy: dy) else {
      log.event("board_room", ["action": "nothing", "board": model.board.id, "why": why, "y": Double(y)])
      return
    }
    let plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: tags, pages: pages, board: board)
    guard !plan.offsets.isEmpty else {
      log.event("board_room", ["action": "nothing_below", "board": model.board.id, "why": why, "y": Double(y)])
      return
    }
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, named: push.dy > 0 ? "Make room" : "Close room")
    else { return }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event(
      "board_room",
      [
        "action": "room", "board": model.board.id, "why": why, "y": Double(y), "cut": Double(push.cut),
        "dy": Double(push.dy), "moved": plan.moved, "pages": pages,
      ])
  }

  /// Stories 930–932: a Pencil stroke that went down in the margin and held still for half a second is the hold, not
  /// ink: dragged, it opens or closes room when it lifts; lifted in place, the menu. Its own stroke goes. A Pencil that
  /// moved or lifted sooner draws. Each verdict is in the log (story 933). True when it was a hold.
  private func marginHeld(_ change: PaperProbe.InkChange, markup: PaperMarkup) -> Bool {
    guard model.editable, lastDown == .pencil, change.added.count == 1, change.removed.isEmpty,
      change.moved.isEmpty, paper.drawingTool is PKInkingTool,
      let element = markup.subelements.strokes.first(where: { Self.key($0.elementID) == change.added[0] }),
      let drawn = markup.subelements[element.elementID] as? PKStroke
    else { return false }
    let path = drawn.path.map { (point: $0.location.applying(drawn.transform), time: $0.timeOffset) }
    let verdict = BoardMarginHold.pencil(path)
    guard verdict != .notInMargin, let start = path.first?.point else { return false }
    var event: [String: Any] = [
      "action": "hold_stroke", "board": model.board.id, "tool": "pencil", "verdict": verdict.reason,
      "y": Double(start.y), "ms": Int(((path.last?.time ?? 0) - (path.first?.time ?? 0)) * 1000),
      "points": path.count,
    ]
    switch verdict {
    case .moved(let after, let by):
      event["moved_after_ms"] = Int(after * 1000)
      event["moved_by"] = Double(by.rounded())
    case .hold(let dy): event["dy"] = Double(dy.rounded())
    case .tooShort, .notInMargin: break
    }
    log.event("board_margin", event)
    guard case .hold(let dy) = verdict else { return false }
    // ponytail: PaperKit's own undo step for the stroke stays beneath, with nothing to take back, as the pick-up's does.
    var without = markup
    _ = without.subelements.removeElement(for: element.elementID)
    quiet = true
    paper.markup = without
    quiet = false
    inkFrames = without.strokeFrames
    if verdict.opensRoom, model.outline(of: opStrokes(without).strokes).header(at: start.y) == nil {
      room(at: start.y, dy: dy, why: "pencil_margin_drag")
    } else {
      showHoldMenu(at: CGPoint(x: 0, y: start.y), spot: lines.convert(lines.spot(of: start), to: view))
    }
    return true
  }

  /// Story 859, as the web board: the Pencil held still on ink for 400 ms picks up the word, and the same stroke drags
  /// it. On paper the word lands when the Pencil lifts, and the Pencil's own stroke goes. True when it did.
  private func pickedUp(_ change: PaperProbe.InkChange, markup: PaperMarkup, before: [String: CGRect]) -> Bool {
    guard change.added.count == 1, change.removed.isEmpty, change.moved.isEmpty, paper.drawingTool is PKInkingTool,
      let element = markup.subelements.strokes.first(where: { Self.key($0.elementID) == change.added[0] }),
      let drawn = markup.subelements[element.elementID] as? PKStroke
    else { return false }
    let path = drawn.path.map { (point: $0.location.applying(drawn.transform), time: $0.timeOffset) }
    guard BoardOutline.isHold(path), BoardMarginHold.pencil(path) == .notInMargin else { return false }
    var without = markup
    _ = without.subelements.removeElement(for: element.elementID)
    let (strokes, hashes) = opStrokes(without)
    let outline = model.outline(of: strokes)
    guard let picked = outline.pickUp(path) else { return false }
    let names = Set(picked.names)
    let still = hypot(picked.by.dx, picked.by.dy) <= BoardOutline.holdStill
    let elements = without.subelements.strokes
    let framesBefore = before
    if still {
      // Held and lifted: the word is left selected; the Pencil's dot goes.
      quiet = true
      paper.markup = without
      quiet = false
      inkFrames = without.strokeFrames
      let chosen = strokes.indices.filter { strokes[$0].ids.contains(where: names.contains) }
      paper.selection = Set(chosen.compactMap { elements.indices.contains($0) ? elements[$0].elementID : nil })
    } else {
      let plan = BoardOps.plan(
        [.translateIDs(picked.names, dx: picked.by.dx, dy: picked.by.dy)], strokes: strokes, texts: model.texts,
        metas: model.strokeMeta, folds: outline.tags, pages: pages, board: board)
      // ponytail: the step goes back to the board without the Pencil's stroke; PaperKit's own step for that stroke
      // stays beneath it and finds nothing to take back.
      guard let (held, _, _) = put(plan, on: without, hashes: hashes, named: "Move") else { return false }
      model.stepped(held.inkDrawing)
      noteInk(held, since: framesBefore, report: true)
    }
    log.event(
      "board_word",
      [
        "action": still ? "picked_up" : "moved", "board": model.board.id, "strokes": picked.names.count,
        "dx": Double(picked.by.dx), "dy": Double(picked.by.dy), "path_points": path.count,
        "held_ms": Int(((path.last?.time ?? 0) - (path.first?.time ?? 0)) * 1000),
      ])
    return true
  }

  /// Where the landed paste is on screen now, for its Delete.
  private func showPasted() {
    var frame: CGRect?
    if !pasted.isEmpty, let markup = paper.markup {
      let box = markup.subelements.strokes.filter { pasted.contains(Self.key($0.elementID)) }
        .compactMap { markup.subelements[$0.elementID] as? PKStroke }.reduce(CGRect.null) { $0.union($1.renderBounds) }
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    if frame != pastedFrame { pastedFrame = frame }
  }

  private func forgetPaste() {
    guard !pasted.isEmpty else { return }
    pasted = []
    pastedFrame = nil
  }

  /// Story 852: the landed paste's Delete: its strokes go, one undo; the room it opened stays, as on the web board.
  func deletePasted() {
    guard var markup = paper.markup, !pasted.isEmpty else { return }
    let before = markup
    let gone = markup.subelements.strokes.map(\.elementID).filter { pasted.contains(Self.key($0)) }
    for id in gone { _ = markup.subelements.removeElement(for: id) }
    forgetPaste()
    registerStepBack(to: before, named: "Delete")
    quiet = true
    paper.markup = markup
    quiet = false
    let framesBefore = inkFrames
    let held = paper.markup ?? markup
    inkFrames = held.strokeFrames
    model.changed(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event("whiteboard", ["action": "paper_paste_deleted", "board": model.board.id, "strokes": gone.count])
  }

  /// The strokes with these element keys swapped for `strokes`, as one undo named `name` (stories 920, 923, 940): saved,
  /// and told to Larry as ink added and erased (naming the texts it `reworded`), never a stroke for Claude to answer. Nil
  /// before the markup is laid out.
  @discardableResult
  func replaceInk(
    removing keys: Set<String>, adding strokes: [PKStroke], named name: String, reworded: [String]? = nil
  ) -> PaperMarkup? {
    guard var markup = paper.markup else { return nil }
    let before = markup
    for id in markup.subelements.strokes.map(\.elementID) where keys.contains(Self.key(id)) {
      _ = markup.subelements.removeElement(for: id)
    }
    if !strokes.isEmpty { markup.append(contentsOf: PKDrawing(strokes: strokes)) }
    forgetPaste()
    registerStepBack(to: before, named: name)
    quiet = true
    paper.markup = markup
    quiet = false
    let framesBefore = inkFrames
    let held = paper.markup ?? markup
    inkFrames = held.strokeFrames
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true, reworded: reworded)
    showLines()
    redrawSoon()
    showMarksSoon()
    return held
  }

  private func copiedStrokes(_ clipboard: UIPasteboard) -> [PKStroke]? {
    if let data = clipboard.data(forPasteboardType: UTType.paperkit.identifier),
      let markup = try? PaperMarkup(dataRepresentation: data), !markup.subelements.strokes.isEmpty
    {
      return markup.inkDrawing.strokes
    }
    if let data = clipboard.data(forPasteboardType: PKAppleDrawingTypeIdentifier as String),
      let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty
    {
      return drawing.strokes
    }
    return nil
  }

  private func moved(_ strokes: [PKStroke]) -> [PKStroke] {
    let shift = board.pasteShift(ink: PKDrawing(strokes: strokes).bounds, visible: paperOnScreen)
    let by = CGAffineTransform(translationX: shift.dx, y: shift.dy)
    return strokes.map {
      PKStroke(
        ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(by), mask: $0.mask,
        randomSeed: $0.randomSeed)
    }
  }

  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste` (or `select`, story 920): those, 2 s apart from a second after the first
  /// ink, for the simulator: it can't work the lasso, and keys reach only a run's first test. Copy selects all the ink and copies, as the lasso's does.
  private func pressSoonForTests() {
    guard !pressedForTests, let presses = LaunchHooks.current.whiteboard.afterInk else { return }
    pressedForTests = true
    Task { @MainActor [weak self] in
      for press in presses {
        try? await Task.sleep(for: .seconds(1))
        if press == "paste" {
          self?.paste(from: "hook")
        } else if press == "select" {
          self?.selectAllForTests()
        } else {
          await self?.copyAllForTests()
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  /// `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>`: a second after the first ink, the view goes to that page's top (as far as
  /// the column lets it), for the simulator: a finger draws there and XCUITest has no two-finger drag (stories 433, 522).
  private func goToPageSoonForTests() {
    guard !movedForTests, let page = LaunchHooks.current.whiteboard.pageAfterInk else { return }
    movedForTests = true
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self else { return }
      let size = self.paper.contentVisibleFrame.size
      self.paper.contentVisibleFrame = CGRect(origin: CGPoint(x: 0, y: self.board.frame(ofPage: page).minY), size: size)
      self.showPageNumber()
      self.layRules()
      self.log.event(
        "whiteboard",
        [
          "action": "paper_page_hook", "board": self.model.board.id, "page": page, "pages": self.pages,
          "visible": self.rect(self.paper.contentVisibleFrame),
        ])
    }
  }

  /// What the system's Copy took here: nothing does, on the simulator, with the selection set. So after asking, the selected
  /// ink goes on the clipboard in PaperKit's own format.
  private func copyAllForTests() async {
    guard let markup = paper.markup else { return }
    UIPasteboard.general.items = []
    paper.selection = Set(markup.subelements.strokes.map(\.elementID))
    try? await Task.sleep(for: .seconds(0.5))
    let copy = #selector(UIResponderStandardEditActions.copy(_:))
    let took = UIApplication.shared.sendAction(copy, to: nil, from: nil, for: nil)
    if !took, let data = try? await paper.selectedMarkup.dataRepresentation() {
      UIPasteboard.general.setData(data, forPasteboardType: UTType.paperkit.identifier)
    }
    log.event(
      "whiteboard",
      [
        "action": "paper_copy_hook", "board": model.board.id, "took": took, "selected": paper.selection.count,
        "types": Array(UIPasteboard.general.types.prefix(8)),
      ])
    paper.selection = []
  }

  /// A kept mark into the markup, and any page it needs in the same change: one undo takes them both. PaperKit registers no
  /// undo for a markup that's set: left to itself, the next undo took back the stroke before the kept mark, and the mark
  /// stayed (the simulator, iOS 27, 2026-11-03). Its own steps go on working after this, as the elements keep their ids.
  private func keep(_ strokes: [PKStroke]) {
    let started = CACurrentMediaTime()
    guard var markup = paper.markup else {
      // Not laid out yet: the load takes the model's drawing, with this in it.
      log.event("whiteboard", ["action": "paper_keep", "board": model.board.id, "no_markup": true])
      return
    }
    let undo = paper.undoManager
    let (couldUndo, couldRedo) = (undo?.canUndo ?? false, undo?.canRedo ?? false)
    // context-grabber-a3w: a keep leaves the pen in hand as it was; if setting the markup ever changed it, it goes back.
    let tool = paper.drawingTool
    let toolBefore = toolText(tool)
    let wanted = board.pages(after: pages, inkMaxY: model.drawing.bounds.maxY, redoWaiting: false)
    let made = PKDrawing(strokes: strokes)
    registerStepBack(to: markup)
    if wanted > pages { markup.bounds = board.bounds(pages: wanted) }
    markup.append(contentsOf: made)
    quiet = true
    paper.markup = markup
    quiet = false
    let toolAfter = toolText(paper.drawingTool)
    if toolAfter != toolBefore { paper.drawingTool = tool }
    let pagesBefore = pages
    pages = wanted
    run?.pageAdded = wanted > pagesBefore
    showLines()
    showPageNumber()
    redrawSoon()
    let held = paper.markup ?? markup
    let framesBefore = inkFrames
    inkFrames = held.strokeFrames
    let whole = held.inkDrawing
    model.settled(whole)
    noteInk(held, since: framesBefore, report: true)
    // The names Larry knows them by, from the mark as made and as PaperKit gives it back: the spec's "Larry knows a kept
    // mark as one stroke".
    let back = PKDrawing(strokes: Array(whole.strokes.suffix(strokes.count)))
    let idsMade = WhiteboardModel.strokesForLarry(made).map(\.id)
    let idsBack = WhiteboardModel.strokesForLarry(back).map(\.id)
    // #883: the pen PaperKit holds the kept mark at, beside the keep's own `width`.
    let widthBack: Double =
      back.strokes.first.map {
        Double(WhiteboardStrokes.width(sizes: $0.path.map(\.size.width), transform: $0.transform))
      } ?? 0
    log.event(
      "whiteboard",
      [
        "action": "paper_keep", "board": model.board.id, "strokes": strokes.count, "total": whole.strokes.count,
        "pages_before": pagesBefore, "pages": wanted, "same_ids": idsMade == idsBack, "ids_made": idsMade.count,
        "ids_back": idsBack.count, "ink": rect(made.bounds), "visible": rect(paper.contentVisibleFrame),
        "in_view": paper.contentVisibleFrame.intersects(made.bounds), "screen_scale": Double(screenScale),
        "width_back": widthBack,
        "tool_before": toolBefore, "tool_after": toolAfter, "tool_restored": toolAfter != toolBefore,
        "sheet": rect(lines.bounds), "markup": rect(held.bounds),
        "drift": round(hypot(made.bounds.minX - back.bounds.minX, made.bounds.minY - back.bounds.minY)),
        "could_undo": couldUndo, "could_redo": couldRedo, "can_undo": undo?.canUndo ?? false,
        "can_redo": undo?.canRedo ?? false, "undo_on_window": undo != nil && undo === view.window?.undoManager,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterKeep)
    lookForInk(made.bounds, why: "kept")
  }

  /// Stories 814–816, 840–842: a batch of Larry's changes on the markup. Every stroke it moves moves whole, by a transform
  /// on its own element (its id kept, so PaperKit's own steps go on working); strokes it erases go, the ink he draws is
  /// added, the column grows to the pages it needs, and the lot is one undo named for the batch, the page count
  /// included. Text and notes alone leave the markup as it is. Nil before the markup is laid out.
  private func applyOps(_ batch: BoardOps.Batch) -> BoardOps.Plan? {
    guard let markup = paper.markup else { return nil }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    let plan = BoardOps.plan(
      batch.ops, strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: model.outline(of: strokes).tags, ghosts: model.textGhosts, pages: pages, board: board)
    guard plan.changesBoard else {
      select(plan.select)
      return plan
    }
    // #937: his texts with notes are ink in the same undo.
    let lettered = model.letter(plan.inked)
    guard
      let (held, renamed, drawn) = put(plan, on: markup, hashes: hashes, adding: lettered.strokes, named: batch.label)
    else { return nil }
    model.keep(lettered: lettered.texts)
    model.opsApplied(held.inkDrawing, renamed: renamed, drawn: drawn)
    model.inkReset(Self.allHashes(held))
    log.event(
      "whiteboard",
      [
        "action": "paper_ops", "board": model.board.id, "label": batch.label, "moved": plan.offsets.count,
        "erased": plan.erase.count, "drawn": plan.added.count, "elements": held.subelements.count,
        "pages_before": plan.pagesBefore, "pages": pages, "can_undo": paper.undoManager?.canUndo ?? false,
        "undo_name": paper.undoManager?.undoActionName ?? "", "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterOps)
    select(plan.select)
    return plan
  }

  func opStrokes(_ markup: PaperMarkup) -> (strokes: [BoardOps.Stroke], hashes: [[String]]) {
    model.opStrokes(markup.inkDrawing.strokes)
  }

  /// A plan on the markup, with `extra` ink added in the same change, as one undo named `name`: moves, hides, erases,
  /// Larry's ink, the pages. Nil when PaperKit didn't take the moves as moves (the log says so); nothing is set then.
  func put(
    _ plan: BoardOps.Plan, on start: PaperMarkup, hashes: [[String]], adding extra: [PKStroke] = [], named name: String,
    stepBack: Bool = true, undoTo: PaperMarkup? = nil
  ) -> (held: PaperMarkup, renamed: [(from: [String], to: [String])], drawn: [(hash: [String], name: String)])? {
    var markup = start
    let elements = markup.subelements.strokes
    let before = markup
    let countBefore = markup.subelements.count
    var renamed: [(from: [String], to: [String])] = []
    for (index, shift) in plan.offsets where elements.indices.contains(index) {
      var moved = elements[index]
      moved.applyTransform(CGAffineTransform(translationX: shift.dx, y: shift.dy))
      _ = markup.subelements.updateOrAppend(moved)
      renamed.append((hashes[index], Self.hashes(moved)))
    }
    // Story 847: hidden ink stays where it is with no colour to see; its names don't change, as the hash ignores alpha.
    for (index, hidden) in plan.hidden where elements.indices.contains(index) {
      guard var stroke = markup.subelements[elements[index].elementID] as? PKStroke else { continue }
      // ponytail: shown again at full strength, whatever alpha the ink had; the Pencil's inks draw opaque colours.
      stroke.ink = PKInk(stroke.ink.inkType, color: stroke.ink.color.withAlphaComponent(hidden ? 0 : 1))
      _ = markup.subelements.updateOrAppend(stroke)
    }
    // A moved stroke that came back as a new element would leave its old self behind: nothing is set, and the log says so.
    guard markup.subelements.count == countBefore else {
      log.event(
        "whiteboard",
        [
          "action": "paper_ops_failed", "board": model.board.id, "label": name, "elements_before": countBefore,
          "elements": markup.subelements.count,
        ])
      return nil
    }
    for index in plan.erase where elements.indices.contains(index) {
      _ = markup.subelements.removeElement(for: elements[index].elementID)
    }
    // His ink, in his colour unless he names one, under his names.
    var drawn: [(hash: [String], name: String)] = []
    for stroke in plan.added {
      let shown = stroke.color.map { UIColor(rgb: $0) } ?? WhiteboardTurn.Who.larry.color
      let color = stroke.hidden ? shown.withAlphaComponent(0) : shown
      let made = WhiteboardModel.strokes([stroke.points], color: color, width: stroke.width, spacing: 4)
      for one in made {
        markup.append(contentsOf: PKDrawing(strokes: [one]))
        drawn.append((Self.hashes(one), stroke.id))
      }
    }
    if !extra.isEmpty { markup.append(contentsOf: PKDrawing(strokes: extra)) }
    if stepBack { registerStepBack(to: undoTo ?? before, named: name) }
    if plan.pagesAfter != pages { markup.bounds = board.bounds(pages: plan.pagesAfter) }
    quiet = true
    paper.markup = markup
    quiet = false
    pages = plan.pagesAfter
    let held = paper.markup ?? markup
    inkFrames = held.strokeFrames
    showLines()
    showPageNumber()
    redrawSoon()
    showMarksSoon()
    model.planPut(plan, drawn: drawn)
    return (held, renamed, drawn)
  }

  /// Story 848: the strokes Larry names, selected as a lasso would leave them; nothing when he names none.
  private func select(_ names: [String]) {
    guard !names.isEmpty, let markup = paper.markup else { return }
    let keys = model.elementKeys(named: names)
    paper.selection = Set(markup.subelements.strokes.map(\.elementID).filter { keys.contains(Self.key($0)) })
  }

  /// A stroke's names as the board sends them, one per visible stretch: remade as `inkDrawing` remakes strokes, since
  /// PencilKit throws on the markup's own.
  static func hashes(_ stroke: PKStroke) -> [String] {
    let remade = PKStroke(
      ink: stroke.ink, path: stroke.path, transform: stroke.transform, mask: stroke.mask, randomSeed: stroke.randomSeed)
    return WhiteboardModel.strokesForLarry(PKDrawing(strokes: [remade])).map(\.id)
  }

  /// Each of `keys`' strokes' names, by element key (story 843): every stroke's with `keys` nil.
  static func hashes(of keys: Set<String>?, in markup: PaperMarkup) -> [String: [String]] {
    if let keys, keys.isEmpty { return [:] }
    var out: [String: [String]] = [:]
    for stroke in markup.subelements.strokes {
      let key = PaperHost.key(stroke.elementID)
      if let keys, !keys.contains(key) { continue }
      out[key] = hashes(stroke)
    }
    return out
  }

  static func allHashes(_ markup: PaperMarkup) -> [String: [String]] { hashes(of: nil, in: markup) }

  /// Story 843: what changed in the ink since `frames`, told to Larry as added, erased and moved (`report`), or only
  /// taken in.
  func noteInk(
    _ markup: PaperMarkup, since frames: [String: CGRect], report: Bool, reworded: [String]? = nil
  ) {
    let change = PaperProbe.inkChange(before: frames, after: markup.strokeFrames)
    guard !change.isEmpty else { return }
    let updated = Self.hashes(of: Set(change.added + change.moved.map(\.id)), in: markup)
    model.inkElements(updated: updated, removed: change.removed, report: report, reworded: reworded)
  }

  /// Story 896: kept labels moved down off ink, by their places in the markup's strokes, with any pages that needs, in
  /// one undo step. Moved in place, so every stroke keeps its id.
  private func move(_ moves: [Int: CGFloat]) {
    guard var markup = paper.markup else { return }
    let strokes = markup.subelements.strokes
    registerStepBack(to: markup)
    for (i, dy) in moves where strokes.indices.contains(i) {
      var stroke = strokes[i]
      stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: 0, y: dy))
      markup.subelements.updateOrAppend(stroke)
    }
    let wanted = board.pages(after: pages, inkMaxY: markup.inkDrawing.bounds.maxY, redoWaiting: false)
    if wanted > pages { markup.bounds = board.bounds(pages: wanted) }
    quiet = true
    paper.markup = markup
    quiet = false
    pages = wanted
    let framesBefore = inkFrames
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    noteInk(markup, since: framesBefore, report: true)
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      ["action": "paper_move", "board": model.board.id, "strokes": moves.count, "pages": pages])
    redrawSoon()
  }

  /// PaperKit sometimes never draws a markup that's set: the ink is held and counted, and the tile it falls on stays empty,
  /// whatever is set or scrolled after. A change of zoom draws it. On the simulator, iOS 27: 15 of 180 pastes without this, 0 of
  /// 60 with it, and a zoom brought back each of the 7 in the run that tried one. A set that opens a board is followed by a
  /// zoom anyway, the fit. So the zoom moves too little to see and back, with the touches done and the view at rest.
  /// ponytail: works around a miss inside PaperKit, unseen on a real device so far; drop it if `paper_ink_look` shows the iOS
  /// it's built for no longer misses without it.
  /// `step`: how far a centred page moves and back, in points; a heal after a measured miss moves further (#906).
  private func redrawSoon(step: CGFloat = 1) {
    redrawing?.cancel()
    redrawing = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.2))
      var seen: CGRect?
      while !Task.isCancelled, let self, self.touchesDown > 0 || self.paper.contentVisibleFrame != seen {
        seen = self.paper.contentVisibleFrame
        try? await Task.sleep(for: .seconds(0.1))
      }
      guard let self, !Task.isCancelled else { return }
      let config = self.paper.scrollConfiguration
      let (zoom, place) = (config.zoomScale, self.paper.contentVisibleFrame)
      let range = self.paper.zoomRange
      let nudged = zoom * (zoom < range.upperBound ? 1.002 : 0.998)
      // #829: with the page narrower than the screen PaperKit centres it (the view starts left of the page), and a zoom
      // set there recursed inside PaperKit until the stack ran out: zoom 1.017 at the bottom of 1.017...3, asked 1.019, on
      // an iPad simulator. Centred, the zoom is left alone and the view moves instead (#833).
      let centred = place.minX < 0
      self.log.event(
        "whiteboard",
        [
          "action": "paper_redraw_nudge", "board": self.model.board.id, "zoom": zoom, "to": nudged,
          "range_lo": range.lowerBound, "range_hi": range.upperBound, "visible": self.rect(place),
          "how": centred ? "frame" : "zoom", "step": Double(step),
        ])
      if centred {
        // #833: centred, a point down and back instead, which draws the missed tile without setting the zoom.
        self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: step)
        try? await Task.sleep(for: .seconds(0.05))
        if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
        return
      }
      config.zoomScale = nudged
      try? await Task.sleep(for: .seconds(0.05))
      config.zoomScale = zoom
      if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
    }
  }

  /// A second after ink is kept or pasted or the sheet changes under it, whether the view's own picture has it. 0 with the
  /// ink in view is the ink missing, and the view redraws and looks again, twice at most, each try moving the view further
  /// (#906: a paste on a centred iPad page went unseen about 1 in 6 on the simulator, and a missed tile the first redraw
  /// leaves empty was never drawn after). `paper_ink_heal` says a try was made; the look after it, whether it drew.
  private func lookForInk(_ ink: CGRect, why: String, attempt: Int = 0) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, let markup = self.paper.markup else { return }
      let corner = self.lines.convert(self.lines.spot(of: ink.origin), to: self.view)
      let scale = self.screenScale
      let spot = CGRect(x: corner.x, y: corner.y, width: ink.width * scale, height: ink.height * scale)
      let inView = self.view.bounds.contains(spot)
      let shown = self.shownPixels(in: spot)
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_look", "why": why, "board": self.model.board.id, "ink": self.rect(ink),
          "spot": self.rect(spot), "in_view": inView, "strokes": markup.subelements.strokes.count,
          "visible": self.rect(self.paper.contentVisibleFrame), "shown_px": shown, "attempt": attempt,
        ])
      guard inView, shown == 0, !ink.isEmpty, attempt < 2, self.touchesDown == 0 else { return }
      let step: CGFloat = attempt == 0 ? 8 : 32
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_heal", "why": why, "board": self.model.board.id, "attempt": attempt + 1,
          "step": Double(step),
        ])
      self.redrawSoon(step: step)
      self.lookForInk(ink, why: why, attempt: attempt + 1)
    }
  }

  /// Pixels unlike the paper in this view's own picture of itself, in a part of it.
  private func shownPixels(in spot: CGRect) -> Int {
    let box = spot.intersection(view.bounds)
    guard !box.isNull, !box.isEmpty else { return -1 }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let picture = UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
      let whole = CGRect(origin: CGPoint(x: -box.minX, y: -box.minY), size: view.bounds.size)
      view.drawHierarchy(in: whole, afterScreenUpdates: false)
    }
    guard let cg = picture.cgImage else { return -1 }
    var (r, g, b): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    paperColor.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: nil)
    let paper = [Int(r * 255), Int(g * 255), Int(b * 255)]
    let (w, h) = (cg.width, cg.height)
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    guard drawn else { return -1 }
    return stride(from: 0, to: bytes.count, by: 4).filter { i in
      (0..<3).contains { abs(Int(bytes[i + $0]) - paper[$0]) > 40 }
    }.count
  }

  /// Undo or redo of a kept mark or a batch of Larry's changes: back to the markup as it was, and the way forward again
  /// the same way. `named`: what Undo and Redo say (a batch's label).
  private func registerStepBack(to markup: PaperMarkup, named name: String? = nil) {
    guard let undo = paper.undoManager else { return }
    stepsOn = undo
    undo.registerUndo(withTarget: self) { controller in
      MainActor.assumeIsolated { controller.step(to: markup, named: name) }
    }
    if let name, !name.isEmpty { undo.setActionName(name) }
  }

  /// The board really closed, which a cancelled swipe back isn't: the stack can be the window's, and the next board's Undo
  /// mustn't reach this one's steps.
  func boardClosed() {
    guard let stepsOn else { return }
    stepsOn.removeAllActions(withTarget: self)
    log.event(
      "whiteboard",
      [
        "action": "paper_undo_closed", "board": model.board.id, "can_undo": stepsOn.canUndo,
        "can_redo": stepsOn.canRedo,
      ])
  }

  private func step(to markup: PaperMarkup, named name: String? = nil) {
    // Story 851: an undo of one of Larry's batches, by its label.
    if let name, !name.isEmpty, paper.undoManager?.isUndoing == true { model.undid(name) }
    if let now = paper.markup { registerStepBack(to: now, named: name) }
    quiet = true
    paper.markup = markup
    quiet = false
    pages = board.pages(in: markup.bounds)
    let framesBefore = inkFrames
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    noteInk(markup, since: framesBefore, report: true)
    // An undo can open a fold or close it again: the marks follow the ink.
    showMarks()
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      [
        "action": "paper_step", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "can_undo": paper.undoManager?.canUndo ?? false, "can_redo": paper.undoManager?.canRedo ?? false,
      ])
    redrawSoon()
  }

  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...` (after a keep) and `GRABBER_WHITEBOARD_AFTER_OPS=...` (after
  /// a batch of Larry's moved the board, story 814): those presses, 3 s apart, for the simulator: a phone's tool picker
  /// has no Undo, and keys reach only a run's first test.
  private func undoSoonForTests(_ hook: WhiteboardHooks.AfterKeep?) {
    guard let hook else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(hook.delay))
      for press in hook.presses {
        guard let self else { return }
        press == "undo" ? self.paper.undoManager?.undo() : self.paper.undoManager?.redo()
        self.log.event(
          "whiteboard",
          [
            "action": "paper_press_hook", "press": press, "board": self.model.board.id,
            "strokes": self.model.drawing.strokes.count, "pages": self.pages,
            "can_undo": self.paper.undoManager?.canUndo ?? false, "can_redo": self.paper.undoManager?.canRedo ?? false,
          ])
        try? await Task.sleep(for: .seconds(3))
      }
    }
  }

  /// The word to the pacer: the Pencil touching down, or a finger once it's seen to be drawing.
  private func toolWentDown() {
    guard !toolDown else { return }
    toolDown = true
    model.beganDrawing()
  }

  override func touchWentDown(_ touch: UITouch) {
    if touch.type == .pencil { toolWentDown() }
    lastDown = pencilDown ? .pencil : touch.type
    snapTouch(touch, .down, draws: touch.type == .pencil || fingersDraw)
    foldEraserDown(touch)
    // Story 858: any touch but the hold's own puts the menu away.
    if holdMenu != nil, grip == nil { holdMenu = nil }
    // Story 933: every try at a hold in the margin is in the log, from here to its verdict.
    let at = lines.columnPoint(of: touch.location(in: lines))
    guard model.editable, marginTry == nil || touchesDown == 0, at.x >= 0, at.x < BoardMargin.width,
      touch.type == .pencil || touch.type == .direct
    else {
      return
    }
    let tool: BoardMarginHold.Tool = touch.type == .pencil ? .pencil : .finger
    marginTry = (ObjectIdentifier(touch), tool, at.y, false)
    log.event(
      "board_margin",
      [
        "action": "hold_began", "board": model.board.id, "tool": tool.rawValue, "x": Double(at.x), "y": Double(at.y),
        "drawing_tool": toolName,
      ])
  }

  override func touchEnded(_ touch: UITouch, cancelled: Bool, seconds: Double, travel: CGFloat) {
    guard let attempt = marginTry, attempt.touch == ObjectIdentifier(touch) else { return }
    marginTry = nil
    var event: [String: Any] = [
      "action": "hold_ended", "board": model.board.id, "tool": attempt.tool.rawValue, "y": Double(attempt.y),
      "ms": Int(seconds * 1000), "travel": Double(travel.rounded()), "cancelled": cancelled,
    ]
    switch attempt.tool {
    case .finger:
      event["verdict"] = BoardMarginHold.finger(seconds: seconds, travel: travel, recognized: attempt.held)
    case .pencil:
      // The Pencil's verdict comes from its stroke, as `hold_stroke`; none means PaperKit drew nothing for it.
      event["verdict"] = "stroke"
    }
    log.event("board_margin", event)
  }

  /// Story 886: the eraser over an answered question card takes it, from a touch that would erase ink: the Pencil, or a
  /// finger only while fingers draw. A finger that pans the board takes nothing.
  override func touchMoved(_ touch: UITouch) {
    snapTouch(touch, .moved, draws: touch.type == .pencil || fingersDraw)
    foldEraserMoved(touch)
    guard place.erasing, touch.type == .pencil || fingersDraw,
      model.questions.board.cards.contains(where: { $0.answered != nil })
    else { return }
    model.questions.erase(crossing: [lines.columnPoint(of: touch.location(in: lines))])
  }

  var fingersDraw: Bool {
    paper.directTouchAutomaticallyDraws
      ? !UIPencilInteraction.prefersPencilOnlyDrawing : paper.directTouchMode == .drawing
  }

  override func toolChanged() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      let erasing = self.paper.drawingTool is PKEraserTool
      if self.place.erasing != erasing { self.place.erasing = erasing }
      // #949: the pen Igor holds is the width Larry's labels take; the eraser or lasso leaves the last pen's.
      if let ink = self.paper.drawingTool as? PKInkingTool { self.model.penInHand = ink.width }
    }
  }

  /// PaperKit says when drawing begins and not when it ends: this is the touch going. A palm left down doesn't hold it.
  override func touchLifted(_ touch: UITouch, down: Int) {
    snapTouch(touch, .lifted, draws: touch.type == .pencil || fingersDraw)
    foldEraserLifted(touch)
    guard toolDown, touch.type == .pencil || down == 0 else { return }
    toolDown = false
    model.endedDrawing()
  }

  // MARK: - The log

  /// What a finger does on paper isn't settled (the spec's "On paper"): this line says which it was, Pencil or finger,
  /// and what came of it, so the iPad's next log can settle it. `touch_type`, as `type` is the event's own.
  override func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {
    log.event(
      "whiteboard",
      [
        "action": "paper_touch", "board": model.board.id, "touch_type": run.tally.type ?? run.type,
        "touch_types": run.tally.types, "finger_radius": round(run.tally.fingerRadius),
        "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "travel": round(run.facts.travel), "fingers": run.facts.fingers, "seconds": seconds(run.facts.seconds),
        "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart), "zoom_to": Double(zoom),
        "selected": run.selected, "selection_changes": run.facts.selectionChanges, "ink_added": run.facts.inkAdded,
        "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved, "began_drawing": run.facts.beganDrawing,
        "page_added_during": run.pageAdded, "tool": run.tool, "tool_ink": run.ink,
        "touch_mode": name(paper.directTouchMode),
        "auto_draws": paper.directTouchAutomaticallyDraws, "pages": pages,
        "page": board.page(at: CGPoint(x: 0, y: visible.midY)), "ghosts": model.ghosts.count,
        "ghost_slip": round(seat.worst), "ghost_checks": seat.checks,
      ])
    seat = (0, 0)
  }
}

/// The board on paper with its page number, which floats over it and isn't in any picture.
struct PaperBoardCanvas: View {
  @ObservedObject var model: WhiteboardModel
  @StateObject private var controller: PaperBoardController

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    _controller = StateObject(wrappedValue: PaperBoardController(model: model, log: log))
  }

  var body: some View {
    PaperBoardHost(
      controller: controller, paper: model.paper, ghosts: model.ghosts, chosen: model.chosen?.id,
      rules: model.gridOn ? .grid : model.ruledOn ? .ruled : .none
    )
    .overlay {
      if model.editable { WhiteboardQuestionCards(questions: model.questions, place: controller.place) }
    }
    .overlay { MarkChoiceButtons(model: model, mark: controller.choiceFrame) }
    .overlay { PastedButtons(controller: controller, pasted: controller.pastedFrame) }
    .overlay { ToTextButton(controller: controller, state: controller.toText) }
    .overlay { ConnectButton(controller: controller, arrow: controller.connectFrame, toText: controller.toText) }
    .overlay { RewordField(controller: controller, state: controller.reword) }
    .overlay { HoldMenuButtons(controller: controller, menu: controller.holdMenu) }
    .overlay(alignment: .topTrailing) {
      Text(controller.pageText).font(.footnote.monospacedDigit())
        // Story 673. On this text, not Send: a toolbar button drops its accessibility value (iOS 27 simulator).
        .accessibilityValue(model.dirty ? "unsaved" : "saved")
        // The board's own name for a UI test, here rather than over the whole view: there it named every element on the
        // board, Keep and Dismiss too, which their tests then never found (the iPad simulator, 2026-11-14).
        .accessibilityIdentifier("whiteboard")
        .padding(.vertical, 4).padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
    }
  }
}

private struct PaperBoardHost: UIViewControllerRepresentable {
  let controller: PaperBoardController
  let paper: BoardPaper
  let ghosts: [Ghost]
  /// The chosen mark: a change places its Keep and Dismiss.
  let chosen: String?
  let rules: PaperRules

  func makeUIViewController(context: Context) -> PaperBoardController { controller }

  func updateUIViewController(_ controller: PaperBoardController, context: Context) {
    controller.setBoardPaper(paper)
    controller.setRules(rules)
    controller.show(ghosts)
  }

  static func dismantleUIViewController(_ controller: PaperBoardController, coordinator: ()) {
    controller.boardClosed()
  }
}

/// Story 825 (#883): Keep and Dismiss beside the chosen mark, wholly on screen. Over the board, not in it, so a tap on
/// them never reaches the board as a tap off the marks. Stories 995 and 1000 (#942): Keep group between them when more of the
/// mark's reply of Larry's shows; each button at least 36 points each way, the capsule taking every tap within it, and
/// never under the board's top-right corner.
private struct MarkChoiceButtons: View {
  @ObservedObject var model: WhiteboardModel
  let mark: CGRect?
  private static let height: CGFloat = 48

  var body: some View {
    GeometryReader { geometry in
      if let mark {
        let group = model.chosenReplyCount
        let size = CGSize(width: group > 1 ? 400 : 210, height: Self.height)
        let origin = geometry.frame(in: .global).origin
        let place = WhiteboardMarkChoice.place(
          mark: mark, buttons: size, in: CGRect(origin: .zero, size: geometry.size),
          avoid: model.cornerFrame.offsetBy(dx: -origin.x, dy: -origin.y))
        HStack(spacing: 4) {
          Button(action: model.keepChosen) { Self.label("Keep", "checkmark") }
            .accessibilityIdentifier("whiteboard-mark-keep")
          if group > 1 {
            Button(action: model.keepChosenReply) { Self.label("Keep group · \(group)", "square.on.square") }
              .accessibilityHint("Keeps all \(group) marks of this reply of Larry's as one group that moves together")
              .accessibilityIdentifier("whiteboard-mark-keep-group")
          }
          Button(action: model.dismissChosen) { Self.label("Dismiss", "xmark") }
            .accessibilityIdentifier("whiteboard-mark-dismiss")
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .lineLimit(1)
        .frame(width: place.width, height: place.height)
        .background(.regularMaterial, in: Capsule())
        // A tap between the buttons lands on the capsule, never on the paper under it.
        .contentShape(Capsule())
        .onTapGesture {}
        .position(x: place.midX, y: place.midY)
      }
    }
  }

  /// A button's whole face, at least 36 points each way, takes its tap (#933: a bare glyph let taps through).
  private static func label(_ title: String, _ image: String) -> some View {
    Label(title, systemImage: image).frame(minWidth: 36, minHeight: 36).contentShape(Rectangle())
  }
}

extension PaperBoardController: UIGestureRecognizerDelegate {
  /// The hold watches beside PaperKit's own gestures, never instead of them.
  nonisolated func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool { true }
}

/// Story 858: what a held finger offers.
struct HoldMenu: Equatable {
  enum Item: Equatable {
    case makeRoom, paste, makeHeader, foldAll, unfoldAll
    case notHeader(String)
    case level(Int)

    var id: String {
      switch self {
      case .makeRoom: "make-room"
      case .paste: "paste"
      case .makeHeader: "make-header"
      case .notHeader: "not-header"
      case .foldAll: "fold-all"
      case .unfoldAll: "unfold-all"
      case .level(let n): "level-\(n)"
      }
    }

    var title: String {
      switch self {
      case .makeRoom: "Make room here"
      case .paste: "Paste"
      case .makeHeader: "Make header"
      case .notHeader: "Not a header"
      case .foldAll: "Fold all"
      case .unfoldAll: "Unfold all"
      case .level(let n): "\(n)"
      }
    }
  }

  /// Where the finger was, in the board view's points, and board `y`.
  var spot: CGPoint
  var y: CGFloat
  var items: [Item]
}

private struct HoldMenuButtons: View {
  let controller: PaperBoardController
  let menu: HoldMenu?

  var body: some View {
    GeometryReader { geometry in
      if let menu {
        let width: CGFloat = menu.items.count > 4 ? 300 : 340
        HStack(spacing: 4) {
          ForEach(menu.items, id: \.id) { item in
            Button(item.title) { controller.chose(item) }
              .accessibilityIdentifier("whiteboard-hold-\(item.id)")
          }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .fixedSize()
        .position(
          x: min(max(menu.spot.x, width / 2), geometry.size.width - width / 2),
          y: max(menu.spot.y - 44, 30))
      }
    }
  }
}

/// Story 852: Delete beside a paste that just landed, selected.
private struct PastedButtons: View {
  let controller: PaperBoardController
  let pasted: CGRect?
  private static let size = CGSize(width: 104, height: 44)

  var body: some View {
    GeometryReader { geometry in
      if let pasted {
        let place = WhiteboardMarkChoice.place(
          mark: pasted, buttons: Self.size, in: CGRect(origin: .zero, size: geometry.size))
        Button("Delete", systemImage: "trash", role: .destructive) { controller.deletePasted() }
          .accessibilityIdentifier("whiteboard-paste-delete")
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.bordered)
          .controlSize(.small)
          .frame(width: Self.size.width, height: Self.size.height)
          .background(.regularMaterial, in: Capsule())
          .position(x: place.midX, y: place.midY)
      }
    }
  }
}

/// What a board's paper is ruled with. A board has one or none.
enum PaperRules { case none, grid, ruled }

/// Paper under the ink: its colour, its grid or ruled lines, a faint line where each page ends, and the ghosts. In PaperKit's content view, so it moves with the board and is in nothing else.
final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  /// The grid or ruled lines, under the page lines and the ghosts, as ink lies over all of this.
  private let rules = CAShapeLayer()
  /// A hair on screen, in board points: the lines stay that wide at any zoom.
  var hair: CGFloat = 1 {
    didSet {
      guard hair != oldValue else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      rules.lineWidth = hair
      CATransaction.commit()
    }
  }
  private var rulesAcross: [CGFloat] = []
  private var rulesSpan: ClosedRange<CGFloat> = 0...0
  private var rulesDown: [CGFloat] = []
  private var width: CGFloat = 0
  private var ends: [CGFloat] = []
  let ghostLayers = GhostLayers()
  /// Larry's controls (story 845), over the lines and under the ink, at their places on the board.
  private var overlays: [BoardOverlay] = []
  private var overlayViews: [String: UILabel] = [:]
  /// The margin's marks (stories 855, 861): the board's own, never Larry's, in no picture.
  struct Mark: Equatable {
    var id: String
    /// The row's middle, board points.
    var y: CGFloat
    var text: String
    var faint: Bool
    /// Where the words start, board points, for a mark beside the ink rather than in the margin (story 901).
    var x: CGFloat?
  }
  private var marks: [Mark] = []
  private var markViews: [String: UILabel] = [:]

  init(paper: UIColor) {
    super.init(frame: .zero)
    backgroundColor = paper
    isUserInteractionEnabled = false
    shape.fillColor = nil
    shape.strokeColor = UIColor(white: 0.5, alpha: 0.45).cgColor
    shape.lineWidth = 1
    rules.fillColor = nil
    rules.strokeColor = UIColor(white: 0.5, alpha: 0.3).cgColor
    layer.addSublayer(rules)
    layer.addSublayer(shape)
    layer.addSublayer(ghostLayers.holder)
  }

  required init?(coder: NSCoder) { nil }

  /// In board points.
  func show(width: CGFloat, ends: [CGFloat]) {
    self.width = width
    self.ends = ends
    setNeedsLayout()
  }

  /// In board points: lines over `span` at each of `across`, and side to side at each of `down`.
  func showRules(across: [CGFloat], span: ClosedRange<CGFloat>, down: [CGFloat]) {
    (rulesAcross, rulesSpan, rulesDown) = (across, span, down)
    setNeedsLayout()
  }

  /// Story 845: Larry's controls as they are now.
  func showMarks(_ list: [Mark]) {
    guard list != marks else { return }
    marks = list
    let ids = Set(list.map(\.id))
    for (id, view) in markViews where !ids.contains(id) {
      view.removeFromSuperview()
      markViews[id] = nil
    }
    for mark in list where markViews[mark.id] == nil {
      let label = UILabel()
      label.textAlignment = .center
      label.isAccessibilityElement = true
      label.accessibilityIdentifier = "whiteboard-margin-\(mark.id)"
      addSubview(label)
      markViews[mark.id] = label
    }
    for mark in list { if let label = markViews[mark.id] { lay(mark, label) } }
  }

  private func lay(_ mark: Mark, _ label: UILabel) {
    let scale = spot(of: CGPoint(x: 1, y: 0)).x - spot(of: .zero).x
    if let x = mark.x {
      // Story 901: the web board's grey 14-point words beside the folded header, read as the picture has them.
      let origin = spot(of: CGPoint(x: x, y: mark.y - 12))
      label.font = .systemFont(ofSize: BoardOutline.markerPoints * scale)
      label.textColor = UIColor(rgb: 0x999999)
      label.textAlignment = .left
      label.text = mark.text
      label.sizeToFit()
      label.frame.origin = origin
      label.frame.size.height = 24 * scale
      label.accessibilityLabel = "Lines folded"
      label.accessibilityValue = mark.text
      return
    }
    let size = CGSize(width: 44 * scale, height: 28 * scale)
    let center = spot(of: CGPoint(x: BoardMargin.width / 2, y: mark.y))
    label.frame = CGRect(
      x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    label.font = .systemFont(ofSize: 17 * scale, weight: mark.faint ? .regular : .semibold)
    label.textColor = mark.faint ? .tertiaryLabel : .secondaryLabel
    label.text = mark.text
    label.accessibilityLabel =
      mark.faint ? "Looks like a header" : mark.text.hasPrefix("▸") ? "Folded header" : "Header"
    label.accessibilityValue = mark.text
  }

  func showOverlays(_ list: [BoardOverlay]) {
    overlays = list
    let ids = Set(list.map(\.id))
    for (id, view) in overlayViews where !ids.contains(id) {
      view.removeFromSuperview()
      overlayViews[id] = nil
    }
    for overlay in list where overlayViews[overlay.id] == nil {
      let label = UILabel()
      label.textAlignment = .center
      label.numberOfLines = 1
      label.clipsToBounds = true
      label.accessibilityIdentifier = "whiteboard-overlay-\(overlay.id)"
      addSubview(label)
      overlayViews[overlay.id] = label
    }
    setNeedsLayout()
  }

  /// A control's look: Larry's `fill` and `color` when he names them, else its kind's.
  private func lay(_ overlay: BoardOverlay, _ label: UILabel) {
    let origin = spot(of: overlay.rect.origin)
    let far = spot(of: CGPoint(x: overlay.rect.maxX, y: overlay.rect.maxY))
    label.frame = CGRect(x: origin.x, y: origin.y, width: far.x - origin.x, height: far.y - origin.y)
    let scale = width > 0 ? bounds.width / width : 1
    let larry = UIColor(rgb: WhiteboardTurn.larryColor)
    let (fill, text): (UIColor, UIColor) =
      switch overlay.kind {
      case .band: (larry.withAlphaComponent(0.12), larry)
      case .chip: (larry.withAlphaComponent(0.2), larry)
      case .button: (larry, .white)
      case .hint: (.clear, .secondaryLabel)
      }
    label.backgroundColor = overlay.styleColor("fill").map { UIColor(rgb: $0) } ?? fill
    label.textColor = overlay.styleColor("color").map { UIColor(rgb: $0) } ?? text
    label.font = .systemFont(ofSize: 15 * scale, weight: overlay.kind == .button ? .semibold : .regular)
    label.layer.cornerRadius = overlay.kind == .band ? 0 : min(label.frame.height / 2, 10 * scale)
    label.text = overlay.label
    label.accessibilityLabel = overlay.label
  }

  /// Column points to this view's own: PaperKit sizes it.
  func spot(of point: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }

  /// This view's own point to the column's.
  func columnPoint(of spot: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: spot.x / scale, y: spot.y / scale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard width > 0, bounds.width > 0 else { return }
    for overlay in overlays { if let label = overlayViews[overlay.id] { lay(overlay, label) } }
    for mark in marks { if let label = markViews[mark.id] { lay(mark, label) } }
    let path = CGMutablePath()
    for end in ends {
      let edge = spot(of: CGPoint(x: 0, y: end))
      path.move(to: edge)
      path.addLine(to: CGPoint(x: bounds.width, y: edge.y))
    }
    let ruled = CGMutablePath()
    for x in rulesAcross {
      ruled.move(to: spot(of: CGPoint(x: x, y: rulesSpan.lowerBound)))
      ruled.addLine(to: spot(of: CGPoint(x: x, y: rulesSpan.upperBound)))
    }
    for y in rulesDown {
      ruled.move(to: spot(of: CGPoint(x: 0, y: y)))
      ruled.addLine(to: spot(of: CGPoint(x: width, y: y)))
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shape.frame = bounds
    shape.path = path
    rules.frame = bounds
    rules.path = ruled
    ghostLayers.holder.setAffineTransform(CGAffineTransform(scaleX: bounds.width / width, y: bounds.width / width))
    CATransaction.commit()
  }
}

/// Sees every touch and takes none: it never recognises anything, delays nothing and can't be stopped by what does.
final class PaperTouchWatcher: UIGestureRecognizer {
  enum Phase { case began, moved, ended, cancelled }

  var changed: ((UITouch, Phase, Int) -> Void)?
  private var down: Set<UITouch> = []
  /// The touches it thinks are still down (#945's log).
  var held: Int { down.count }

  init() {
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
    requiresExclusiveTouchType = false
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    for touch in touches {
      down.insert(touch)
      changed?(touch, .began, down.count)
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    for touch in touches { changed?(touch, .moved, down.count) }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, .ended) }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, .cancelled) }

  private func lift(_ touches: Set<UITouch>, _ phase: Phase) {
    for touch in touches {
      down.remove(touch)
      changed?(touch, phase, down.count)
    }
    if down.isEmpty { state = .failed }
  }

  override func reset() { down = [] }
}
