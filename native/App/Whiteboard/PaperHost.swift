//  PaperKit's host on any board: its lifecycle, the paper's colour and fit, the tool picker, the touch runs, and the
//  log's words. Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import PaperKit
import PencilKit
import UIKit

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
    /// The tool the picker shows selected (`pickerText`), which the board's own `drawingTool` may not follow (#1078).
    var picker: String = ""
    var facts = PaperProbe.TouchFacts()
    /// Every touch in it, so the Pencil is the Pencil whatever landed first (#825).
    var tally = PaperProbe.TouchTally()
    var selected = 0
    var frames = 0
    var maxGap: Double = 0
    var pageAdded = false
    /// Story 1143: the strokes selected as it went down, the view it began on, and PaperKit's handwriting tools showing.
    var heldAtStart: Set<String> = []
    var startView = ""
    var handwritingAtStart: [String] = []
    /// Story 1143: each change the board put on the ink while it was down, by name, and the turns logged as it began.
    var boardSets: [String] = []
    var turnsAtStart = 0
    /// Story 1284: why the pinch was held off in this run ("pencil" or "palm"), and how many pinches there were to hold.
    var pinchHeld: String?
    var pinchesHeld = 0
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
  /// Story 1091: the picker's tool when the latest touch went down, which every choice about that touch reads. Kept past
  /// the run, as PaperKit's word on the stroke comes after the lift.
  private(set) lazy var touchTool = decidingTool
  private var runEnding: Task<Void, Never>?
  private var touchStarts: [ObjectIdentifier: (at: CGPoint, began: Double, timestamp: Double, farthest: CGFloat)] = [:]
  /// Fingers on the glass now, and together since the last time there were none. A Pencil beside one doesn't count.
  private var fingersDown = 0
  private var fingersTogether = 0
  private(set) var lastTouchBoardPoint: CGPoint?
  /// Story 1284: each finger contact down now, at its widest, and why the pinch is held off until everything lifts.
  var fingerRadii: [ObjectIdentifier: CGFloat] = [:]
  var pinchHold: String?

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
    // Story 1098 (#1078): the picker opens on the tool picked last, on another board or in an earlier launch, and
    // PaperKit hears only a change, so the paper would draw with its own black pen under a selected eraser. It starts
    // on the picker's tool.
    if let tool = decidingTool.tool { paper.drawingTool = tool }
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
      touchTool = decidingTool
      if touchesDown == 0 {
        // A menu leaves nothing the first responder when it closes, and with that PaperKit drew no stroke and showed no tool
        // picker (3 of 3 on the simulator, iOS 27).
        if !paper.isFirstResponder { paper.becomeFirstResponder() }
        runEnding?.cancel()
        endRun()
        startRun(touch, at: at)
      }
      touchStarts[id] = (at, CACurrentMediaTime(), touch.timestamp, 0)
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
        fingerTapped(at: start.at, beganAt: Date().addingTimeInterval(start.timestamp - CACurrentMediaTime()))
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
    holdPinch(touch, phase, down: down)
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
      zoomAtStart: paper.scrollConfiguration.zoomScale, tool: toolName, ink: toolText(paper.drawingTool),
      picker: pickerText)
    run?.heldAtStart = Set(paper.selection.map(Self.key))
    run?.startView = touch.view.map { String(describing: type(of: $0)) } ?? ""
    run?.handwritingAtStart = handwritingTools()
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
  func fingerTapped(at spot: CGPoint, beganAt: Date) {}
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
    case let ink as PKInkingTool: return WhiteboardInk.name(ink.ink, at: "tool") ?? "unknown"
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
    let kind = WhiteboardInk.name(ink.ink, at: "tool") ?? "unknown"
    return "\(kind) \(WhiteboardStrokes.hex(red: red, green: green, blue: blue)) \(width)"
  }

  /// Story 1091: the one tool the board decides on, the picker's. Before that story it read the
  /// board's own tool (`paper.drawingTool`).
  var decidingTool: PickedTool { PickedTool(picker.selectedToolItem) }

  /// #1078 (story 1064): the tool the picker shows selected, as `toolText` says an ink; the eraser, the lasso, or the
  /// item's own identifier for anything else. Every iPad touch logged `drawingTool` as a black pen, even ones that
  /// erased or drew blue, so the log carries the picker's word beside it.
  var pickerText: String {
    let item = picker.selectedToolItem
    switch item {
    case let inking as PKToolPickerInkingItem: return toolText(inking.inkingTool)
    case is PKToolPickerEraserItem: return "eraser"
    case is PKToolPickerLassoItem: return "lasso"
    default: return item.identifier
    }
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

  func rect(_ r: CGRect) -> [Double] {
    r.isNull || r.isInfinite ? [] : [round(r.minX), round(r.minY), round(r.width), round(r.height)]
  }
}
