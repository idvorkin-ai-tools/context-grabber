//  A board on paper (whiteboard spec's "On paper: the default", stories 590–601; #636): PaperKit's controller, which
//  can't be subclassed, held in `PaperHost` with the page lines, the tool picker and the touch log, which the trial on
//  paper shares; and on it `PaperBoardController`, which draws on a real board through its model, so it saves and syncs
//  as any other board does. Ghosts, Larry's marks, paste and grids aren't here yet (S5–S7).

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

extension PaperMarkup {
  /// The ink as a drawing, in today's file format. The strokes are remade: PKDrawing(strokes:) on what
  /// `subelements.strokes` gives throws an Objective-C exception, nil into PencilKit's set of UUIDs, seen on the simulator
  /// on iOS 27 with ink appended from a drawing.
  var inkDrawing: PKDrawing {
    PKDrawing(
      strokes: subelements.strokes.map { PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform, mask: $0.mask) })
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
    var facts = PaperProbe.TouchFacts()
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
  private var paperColor: UIColor

  private(set) var touchesDown = 0
  private(set) var pencilDown = false
  var run: TouchRun?
  private var runEnding: Task<Void, Never>?
  private var touchStarts: [ObjectIdentifier: CGPoint] = [:]
  private(set) var lastTouchBoardPoint: CGPoint?

  private static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  init(paperColor: UIColor) {
    self.paperColor = paperColor
    paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: Self.features)
    lines = PaperLines(paper: paperColor)
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
    watcher.changed = { [weak self] touch, phase, down in self?.touched(touch, phase, down: down) }
    view.addGestureRecognizer(watcher)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    picker.addObserver(paper)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
  }

  func setPaperColor(_ color: UIColor) {
    guard color != paperColor else { return }
    paperColor = color
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
        runEnding?.cancel()
        endRun()
        startRun(touch, at: at)
      }
      touchStarts[id] = at
      if touch.type == .pencil { pencilDown = true }
    case .moved:
      if let start = touchStarts[id] {
        if let travel = run?.facts.travel { run?.facts.travel = max(travel, hypot(at.x - start.x, at.y - start.y)) }
      }
    case .ended:
      touchStarts[id] = nil
      if touch.type == .pencil { pencilDown = false }
    }
    touchesDown = down
    if let fingers = run?.facts.fingers { run?.facts.fingers = max(fingers, down) }
    if phase == .ended, down == 0 {
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
      zoomAtStart: paper.scrollConfiguration.zoomScale, tool: toolName)
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

  /// What a touch came to, for the log.
  func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {}

  // MARK: - The log's words

  var toolName: String {
    switch paper.drawingTool {
    case let ink as PKInkingTool: return ink.inkType.rawValue
    case is PKEraserTool: return "eraser"
    case is PKLassoTool: return "lasso"
    default: return String(describing: type(of: paper.drawingTool))
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
  func insets(_ i: UIEdgeInsets) -> [Double] { [round(i.top), round(i.left), round(i.bottom), round(i.right)] }

  func rect(_ r: CGRect) -> [Double] {
    r.isNull || r.isInfinite ? [] : [round(r.minX), round(r.minY), round(r.width), round(r.height)]
  }
}

/// A real board on paper, drawn on this device. The drawing goes through the board's model, as the old canvas's does.
@MainActor
final class PaperBoardController: PaperHost, ObservableObject, PaperMarkupViewController.Delegate {
  @Published private(set) var pageText = BoardPages().pageText(visibleMidY: 0, pages: 1)

  private let model: WhiteboardModel
  private let log: SessionLog
  private let board = BoardPages()
  private var pages = 1
  private var laidWidth: CGFloat = 0
  /// What the column's own changes shouldn't report as a person's.
  private var quiet = false
  private var inkFrames: [String: CGRect] = [:]
  private var saidNotInk = false
  private var remembering: Task<Void, Never>?
  /// The window this board made light, and how it was.
  private var lightWindow: (window: UIWindow, style: UIUserInterfaceStyle)?

  private var placeKey: String { "whiteboard_paper_y_\(model.board.id)" }

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    self.log = log
    super.init(paperColor: model.paper.color)
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    paper.delegate = self
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
    let drawing = model.drawing
    pages = board.pagesNeeded(inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY)
    var markup = PaperMarkup(bounds: board.bounds(pages: pages))
    markup.append(contentsOf: drawing)
    quiet = true
    paper.markup = markup
    quiet = false
    inkFrames = paper.markup?.strokeFrames ?? [:]
    showLines()
    log.event(
      "whiteboard",
      [
        "action": "paper_open", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "ms": ms(CACurrentMediaTime() - started),
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
  }

  private func showLines() {
    lines.show(width: board.width, ends: board.pageEnds(pages: pages))
  }

  private func showPageNumber() {
    let text = board.pageText(visibleMidY: paper.contentVisibleFrame.midY, pages: pages)
    if text != pageText { pageText = text }
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
    let change = PaperProbe.inkChange(before: inkFrames, after: frames)
    inkFrames = frames
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
    // An undo can take back a page added earlier: the count follows what the markup holds.
    pages = board.pages(in: markup.bounds)
    let wanted = board.pages(
      after: pages, inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY,
      redoWaiting: controller.undoManager?.canRedo ?? false)
    log.event(
      "whiteboard",
      [
        "action": "paper_ink", "board": model.board.id, "strokes": frames.count, "pages": pages, "wanted": wanted,
        "added": change.added.count, "moved": change.moved.count, "removed": change.removed.count,
        "can_undo": controller.undoManager?.canUndo ?? false, "can_redo": controller.undoManager?.canRedo ?? false,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    showLines()
    showPageNumber()
    // Not from inside PaperKit's own callback.
    if wanted > pages { Task { @MainActor [weak self] in self?.grow(to: wanted) } }
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
  }

  func paperMarkupViewControllerDidChangeSelection(_ controller: PaperMarkupViewController) {
    run?.facts.selectionChanges += 1
    run?.selected = controller.selection.count
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    showPageNumber()
    remembering?.cancel()
    remembering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled else { return }
      self?.rememberPlace()
    }
  }

  // MARK: - The log

  /// What a finger does on paper isn't settled (the spec's "On paper"): this line says which it was, Pencil or finger,
  /// and what came of it, so the iPad's next log can settle it. `touch_type`, as `type` is the event's own.
  override func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {
    log.event(
      "whiteboard",
      [
        "action": "paper_touch", "board": model.board.id, "touch_type": run.type,
        "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "travel": round(run.facts.travel), "fingers": run.facts.fingers, "seconds": seconds(run.facts.seconds),
        "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart), "zoom_to": Double(zoom),
        "selected": run.selected, "selection_changes": run.facts.selectionChanges, "ink_added": run.facts.inkAdded,
        "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved, "began_drawing": run.facts.beganDrawing,
        "page_added_during": run.pageAdded, "tool": run.tool, "touch_mode": name(paper.directTouchMode),
        "auto_draws": paper.directTouchAutomaticallyDraws, "pages": pages,
        "page": board.page(at: CGPoint(x: 0, y: visible.midY)),
      ])
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
    PaperBoardHost(controller: controller, paper: model.paper)
      .overlay(alignment: .topTrailing) {
        Text(controller.pageText).font(.footnote.monospacedDigit())
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

  func makeUIViewController(context: Context) -> PaperBoardController { controller }

  func updateUIViewController(_ controller: PaperBoardController, context: Context) {
    controller.setPaperColor(paper.color)
  }
}

/// Paper under the ink: its colour, a faint line where each page ends, and any small crosses asked for. In PaperKit's
/// content view, so it moves with the board and is in nothing else.
final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  private var width: CGFloat = 0
  private var ends: [CGFloat] = []
  private var crosses: [CGPoint] = []

  init(paper: UIColor) {
    super.init(frame: .zero)
    backgroundColor = paper
    isUserInteractionEnabled = false
    shape.fillColor = nil
    shape.strokeColor = UIColor(white: 0.5, alpha: 0.45).cgColor
    shape.lineWidth = 1
    layer.addSublayer(shape)
  }

  required init?(coder: NSCoder) { nil }

  /// In board points. The crosses are the trial's, to test with; a real board has none.
  func show(width: CGFloat, ends: [CGFloat], crosses: [CGPoint] = []) {
    self.width = width
    self.ends = ends
    self.crosses = crosses
    setNeedsLayout()
  }

  /// Column points to this view's own: PaperKit sizes it.
  func spot(of point: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard width > 0, bounds.width > 0 else { return }
    let path = CGMutablePath()
    for end in ends {
      let edge = spot(of: CGPoint(x: 0, y: end))
      path.move(to: edge)
      path.addLine(to: CGPoint(x: bounds.width, y: edge.y))
    }
    for mark in crosses {
      let cross = spot(of: mark)
      path.move(to: CGPoint(x: cross.x - 8, y: cross.y))
      path.addLine(to: CGPoint(x: cross.x + 8, y: cross.y))
      path.move(to: CGPoint(x: cross.x, y: cross.y - 8))
      path.addLine(to: CGPoint(x: cross.x, y: cross.y + 8))
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shape.frame = bounds
    shape.path = path
    CATransaction.commit()
  }
}

/// Sees every touch and takes none: it never recognises anything, delays nothing and can't be stopped by what does.
final class PaperTouchWatcher: UIGestureRecognizer {
  enum Phase { case began, moved, ended }

  var changed: ((UITouch, Phase, Int) -> Void)?
  private var down: Set<UITouch> = []

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

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches) }

  private func lift(_ touches: Set<UITouch>) {
    for touch in touches {
      down.remove(touch)
      changed?(touch, .ended, down.count)
    }
    if down.isEmpty { state = .failed }
  }

  override func reset() { down = [] }
}
