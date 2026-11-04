//  A board on paper (whiteboard spec's "On paper: the default", stories 590–649; #636): PaperKit's controller, which
//  can't be subclassed, held in `PaperHost` with the page lines, the tool picker and the touch log, which the trial on
//  paper shares; and on it `PaperBoardController`, which draws on a real board through its model, so it saves and syncs
//  as any other board does, with its ghosts, Larry's marks, the mic and paste. Ghosts lie on the sheet under the ink, in
//  PaperKit's content view, so they move with the board whatever it does. Grids aren't here yet (S7).

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
      touchStarts[id] = (at, CACurrentMediaTime(), 0)
      if touch.type == .pencil { pencilDown = true }
      if touch.type == .direct {
        fingersDown += 1
        fingersTogether += 1
      }
      touchWentDown(touch)
    case .moved:
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

  func touchWentDown(_ touch: UITouch) {}
  func touchLifted(_ touch: UITouch, down: Int) {}
  /// One finger, short and staying put, at this spot in `view`, Pencil or no Pencil. PaperKit may do its own thing with the
  /// same touch.
  func fingerTapped(at spot: CGPoint) {}

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
  /// A Pencil or a drawing finger is down, as the pacer was told.
  private var toolDown = false
  /// What a finger does when no ghost shows; set while they do, as it taps and doesn't draw.
  private var fingerUsually: (mode: PaperMarkupViewController.TouchMode, autoDraws: Bool)?
  /// A tap's selection comes after the lift: until this time one is put straight back.
  private var noSelectionUntil: Double = 0
  /// How far a ghost's place on the sheet was from where the visible frame says, over this touch, and how many looks
  /// that took. For the iPad: the spec's "A ghost sits on the paper".
  private var seat = (worst: CGFloat(0), checks: 0)
  /// PaperKit's turn at a paste: this controller stands aside.
  private var handingOverPaste = false
  private var pressedForTests = false
  /// The undo stack a kept mark's steps went on. A closing view may no longer be able to say.
  private weak var stepsOn: UndoManager?

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
    model.visibleRect = { [weak self] in self?.paperOnScreen ?? .null }
    model.pasteReach = board.pasteReach
    model.zoom = { [weak self] in self?.screenScale ?? 1 }
    model.draw = { [weak self] _, added in self?.keep(added) }
  }

  /// The part of the column on screen: the visible frame runs past the paper where a phone's one page is shorter than the
  /// screen, and at a side.
  private var paperOnScreen: CGRect {
    let visible = paper.contentVisibleFrame
    let onPaper = visible.intersection(board.bounds(pages: pages))
    return onPaper.isNull || onPaper.isEmpty ? visible : onPaper
  }

  /// Screen points to a board point, whatever PaperKit's zoom scale means.
  private var screenScale: CGFloat {
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
    if change.added.count > 0 { pressSoonForTests() }
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
    if !controller.selection.isEmpty, CACurrentMediaTime() < noSelectionUntil { controller.selection = [] }
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
    // A finger drawing is only known from here. Late, it's a stroke already over, with no lift to come.
    if touchesDown > 0 { toolWentDown() }
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    showPageNumber()
    checkSeat()
    remembering?.cancel()
    remembering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled else { return }
      self?.rememberPlace()
    }
  }

  // MARK: - Ghosts

  /// The ghosts on the sheet, and a finger that taps while they show.
  func show(_ ghosts: [Ghost]) {
    guard lines.ghostLayers.show(ghosts) else { return }
    fingerTaps(!ghosts.isEmpty)
    let drawn = ghosts.flatMap(\.lines)
    log.event(
      "whiteboard",
      [
        "action": "paper_ghosts", "board": model.board.id, "count": ghosts.count,
        "past_side": board.reachesPastSide(drawn), "pages": pages, "visible": rect(paper.contentVisibleFrame),
        "sheet": rect(lines.bounds),
        "screen_scale": Double(screenScale),
      ])
    checkSeat()
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

  override func fingerTapped(at spot: CGPoint) {
    let count = model.ghosts.count
    guard count > 0 else { return }
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    noSelectionUntil = CACurrentMediaTime() + 0.8
    let selected = paper.selection.count
    if selected > 0 { paper.selection = [] }
    model.tap(at: at, zoom: screenScale)
    log.event(
      "whiteboard",
      [
        "action": "paper_tap", "board": model.board.id, "at": point(at), "ghosts_before": count,
        "ghosts_after": model.ghosts.count, "selected_at_tap": selected, "screen_scale": Double(screenScale),
      ])
  }

  // MARK: - Paste

  /// ⌘V, ahead of whatever PaperKit's own views would do with it.
  override var keyCommands: [UIKeyCommand]? {
    let key = UIKeyCommand(input: "v", modifierFlags: .command, action: #selector(pasteKeyPressed))
    key.wantsPriorityOverSystemBehavior = true
    return (super.keyCommands ?? []) + [key]
  }

  @objc private func pasteKeyPressed() { paste(from: "key") }

  /// *Paste* by any other road: a menu's, when nothing below this took it.
  override func paste(_ sender: Any?) { paste(from: "menu") }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)) { return !handingOverPaste && UIPasteboard.general.hasStrings }
    return super.canPerformAction(action, withSender: sender)
  }

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
    handingOverPaste = true
    let took = UIApplication.shared.sendAction(#selector(paste(_:)), to: nil, from: self, for: nil)
    handingOverPaste = false
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

  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste`: those, 2 s apart from a second after the first ink, for the simulator: it
  /// can't work the lasso, and keys reach only a run's first test. Copy selects all the ink and copies, as the lasso's does.
  private func pressSoonForTests() {
    guard !pressedForTests, let hook = ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_AFTER_INK"] else { return }
    pressedForTests = true
    Task { @MainActor [weak self] in
      for press in hook.split(separator: ",") {
        try? await Task.sleep(for: .seconds(1))
        if press == "paste" {
          self?.paste(from: "hook")
        } else {
          await self?.copyAllForTests()
        }
        try? await Task.sleep(for: .seconds(1))
      }
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

  /// A kept mark into the markup, and then any page it needs: one undo takes them both. PaperKit registers no
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
    let wanted = board.pages(after: pages, inkMaxY: model.drawing.bounds.maxY, redoWaiting: false)
    let made = PKDrawing(strokes: strokes)
    registerStepBack(to: markup)
    markup.append(contentsOf: made)
    quiet = true
    paper.markup = markup
    quiet = false
    let pagesBefore = pages
    showLines()
    showPageNumber()
    // The ink first and its pages on the next turn, from outside PaperKit's own change. The undo step above goes back past both.
    if wanted > pagesBefore { Task { @MainActor [weak self] in self?.grow(to: wanted) } }
    let held = paper.markup ?? markup
    inkFrames = held.strokeFrames
    let whole = held.inkDrawing
    model.settled(whole)
    // The names Larry knows them by, from the mark as made and as PaperKit gives it back: the spec's "Larry knows a kept
    // mark as one stroke".
    let back = PKDrawing(strokes: Array(whole.strokes.suffix(strokes.count)))
    let idsMade = WhiteboardModel.strokesForLarry(made).map(\.id)
    let idsBack = WhiteboardModel.strokesForLarry(back).map(\.id)
    log.event(
      "whiteboard",
      [
        "action": "paper_keep", "board": model.board.id, "strokes": strokes.count, "total": whole.strokes.count,
        "pages_before": pagesBefore, "pages": wanted, "same_ids": idsMade == idsBack, "ids_made": idsMade.count,
        "ids_back": idsBack.count, "ink": rect(made.bounds), "visible": rect(paper.contentVisibleFrame), "sheet": rect(lines.bounds), "markup": rect(held.bounds),
        "drift": round(hypot(made.bounds.minX - back.bounds.minX, made.bounds.minY - back.bounds.minY)),
        "could_undo": couldUndo, "could_redo": couldRedo, "can_undo": undo?.canUndo ?? false,
        "can_redo": undo?.canRedo ?? false, "undo_on_window": undo != nil && undo === view.window?.undoManager,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests()
  }

  /// Undo or redo of a kept mark: back to the markup as it was, and the way forward again the same way.
  private func registerStepBack(to markup: PaperMarkup) {
    guard let undo = paper.undoManager else { return }
    stepsOn = undo
    undo.registerUndo(withTarget: self) { controller in
      MainActor.assumeIsolated { controller.step(to: markup) }
    }
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

  private func step(to markup: PaperMarkup) {
    if let now = paper.markup { registerStepBack(to: now) }
    quiet = true
    paper.markup = markup
    quiet = false
    pages = board.pages(in: markup.bounds)
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      [
        "action": "paper_step", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "can_undo": paper.undoManager?.canUndo ?? false, "can_redo": paper.undoManager?.canRedo ?? false,
      ])
  }

  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...`: those presses after a keep, 3 s apart, for the simulator: a
  /// phone's tool picker has no Undo, and keys reach only a run's first test.
  private func undoSoonForTests() {
    guard let hook = ProcessInfo.processInfo.environment["GRABBER_WHITEBOARD_AFTER_KEEP"] else { return }
    let parts = hook.split(separator: ",")
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(Double(parts.first ?? "") ?? 3))
      for press in parts.dropFirst() {
        guard let self else { return }
        press == "undo" ? self.paper.undoManager?.undo() : self.paper.undoManager?.redo()
        self.log.event(
          "whiteboard",
          [
            "action": "paper_press_hook", "press": String(press), "board": self.model.board.id,
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
  }

  /// PaperKit says when drawing begins and not when it ends: this is the touch going. A palm left down doesn't hold it.
  override func touchLifted(_ touch: UITouch, down: Int) {
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
        "action": "paper_touch", "board": model.board.id, "touch_type": run.type,
        "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "travel": round(run.facts.travel), "fingers": run.facts.fingers, "seconds": seconds(run.facts.seconds),
        "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart), "zoom_to": Double(zoom),
        "selected": run.selected, "selection_changes": run.facts.selectionChanges, "ink_added": run.facts.inkAdded,
        "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved, "began_drawing": run.facts.beganDrawing,
        "page_added_during": run.pageAdded, "tool": run.tool, "touch_mode": name(paper.directTouchMode),
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
    PaperBoardHost(controller: controller, paper: model.paper, ghosts: model.ghosts)
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
  let ghosts: [Ghost]

  func makeUIViewController(context: Context) -> PaperBoardController { controller }

  func updateUIViewController(_ controller: PaperBoardController, context: Context) {
    controller.setPaperColor(paper.color)
    controller.show(ghosts)
  }

  static func dismantleUIViewController(_ controller: PaperBoardController, coordinator: ()) {
    controller.boardClosed()
  }
}

/// Paper under the ink: its colour, a faint line where each page ends, any small crosses asked for, and the ghosts. In
/// PaperKit's content view, so it moves with the board and is in nothing else.
final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  private var width: CGFloat = 0
  private var ends: [CGFloat] = []
  private var crosses: [CGPoint] = []
  let ghostLayers = GhostLayers()

  init(paper: UIColor) {
    super.init(frame: .zero)
    // See-through: the host's own colour is the paper. Opaque, the first ink pasted on a new board sometimes never showed, with
    // the same ink in the same place as when it did: 4 of 18 on the simulator, iOS 27, and 0 of 10 once this was clear. So
    // PaperKit seems to put a new board's ink under its content view now and then; that part is inferred, not seen.
    backgroundColor = .clear
    isUserInteractionEnabled = false
    shape.fillColor = nil
    shape.strokeColor = UIColor(white: 0.5, alpha: 0.45).cgColor
    shape.lineWidth = 1
    layer.addSublayer(shape)
    layer.addSublayer(ghostLayers.holder)
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

  /// This view's own point to the column's.
  func columnPoint(of spot: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: spot.x / scale, y: spot.y / scale)
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
    ghostLayers.holder.setAffineTransform(CGAffineTransform(scaleX: bounds.width / width, y: bounds.width / width))
    CATransaction.commit()
  }
}

/// Sees every touch and takes none: it never recognises anything, delays nothing and can't be stopped by what does.
final class PaperTouchWatcher: UIGestureRecognizer {
  enum Phase { case began, moved, ended, cancelled }

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
