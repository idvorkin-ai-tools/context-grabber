//  The trial on paper (whiteboard spec's "Trial on paper", stories 435–439, 524–534; #635, #636). TEMPORARY: it goes when the
//  board moves to PaperKit. An in-memory copy of a board on PaperKit, to settle on the iPad
//  what PaperKit's interface can't: every touch and what came of it goes in the log as `paper_probe`, with `q` naming
//  the question it answers (docs/DEBUGGING.md).
//
//  Nothing here can reach a real board. The trial is handed a PKDrawing and a log, no store, model or inbox, so there is
//  nothing to save, sync or send through; the one read below leaves the file alone, even a file it can't read.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// The board as the trial gets it. A value: drawing on the trial never comes back through this.
struct PaperTrialCopy: Identifiable {
  let id: String
  let paper: BoardPaper
  let drawing: PKDrawing
}

extension WhiteboardStore {
  /// The board's ink, read and nothing else: unlike `drawing(_:)`, a file that can't be read stays where it is.
  /// `GRABBER_PAPER_TRIAL_INK=<n>` adds n strokes to the copy, for the simulator, where no board has old ink.
  func trialCopy(of board: BoardEntry) throws -> PaperTrialCopy {
    var drawing = PKDrawing()
    if let url = drawingURL(board.id), FileManager.default.fileExists(atPath: url.path) {
      drawing = try PKDrawing(data: Data(contentsOf: url))
    }
    if let extra = ProcessInfo.processInfo.environment["GRABBER_PAPER_TRIAL_INK"].flatMap(Int.init), extra > 0 {
      drawing.strokes += Self.oldBoardInk(extra)
    }
    return PaperTrialCopy(id: board.id, paper: board.paper, drawing: drawing)
  }

  /// Rows of short strokes where an old board's ink sits, the same on every run so their ids are too.
  private static func oldBoardInk(_ count: Int) -> [PKStroke] {
    (0..<count).map { (i: Int) -> PKStroke in
      let left: CGFloat = 10_060 + CGFloat(i % 20) * 34
      let top: CGFloat = 10_040 + CGFloat(i / 20) * 40
      let points: [PKStrokePoint] = (0..<8).map { (step: Int) -> PKStrokePoint in
        let wiggle: CGFloat = step % 2 == 0 ? 0 : 14
        let location = CGPoint(x: left + CGFloat(step) * 3, y: top + wiggle)
        return PKStrokePoint(
          location: location, timeOffset: Double(step) * 0.01, size: CGSize(width: 3, height: 3), opacity: 1, force: 1,
          azimuth: 0, altitude: CGFloat.pi / 2)
      }
      let made = Date(timeIntervalSince1970: 1_800_000_000 + Double(i))
      return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: made))
    }
  }
}

/// The screen: the trial under a title, one line of what to try, the page number, Close and the Trial menu.
@available(iOS 27, *)
struct PaperTrialView: View {
  @StateObject private var trial: PaperTrial
  private let onClose: () -> Void

  init(copy: PaperTrialCopy, log: SessionLog, onClose: @escaping () -> Void) {
    _trial = StateObject(wrappedValue: PaperTrial(copy: copy, log: log))
    self.onClose = onClose
  }

  var body: some View {
    NavigationStack {
      PaperTrialHost(trial: trial)
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .topTrailing) {
          Text(trial.pageText).font(.footnote.monospacedDigit())
            .padding(.vertical, 4).padding(.horizontal, 10)
            .background(.thinMaterial, in: Capsule())
            .padding(10)
            .allowsHitTesting(false)
            .accessibilityIdentifier("paper-trial-page")
        }
        .safeAreaInset(edge: .top, spacing: 0) {
          Text(
            "A copy: nothing here is saved. Drag and tap ink with a finger, write with the Pencil, then try the menu."
          )
          .font(.footnote).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.8)
          .padding(.vertical, 4).padding(.horizontal)
          .frame(maxWidth: .infinity)
          .background(.bar)
          .accessibilityIdentifier("paper-trial-note")
        }
        .navigationTitle("Trial on paper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Close") {
              trial.finish()
              onClose()
            }
            .accessibilityIdentifier("paper-trial-close")
          }
          ToolbarItem(placement: .topBarTrailing) { menu }
        }
    }
    .accessibilityIdentifier("paper-trial")
  }

  private var menu: some View {
    Menu {
      Section("Where the column sits") {
        Picker(
          "Column", selection: Binding(get: { trial.layout }, set: { trial.setLayout($0) })
        ) {
          Text("Ink moved to the top").tag(PaperProbe.Layout.moved)
          Text("Ink where it is").tag(PaperProbe.Layout.inkInPlace)
          Text("Tall column, cut short").tag(PaperProbe.Layout.tall)
        }
      }
      Section("What a finger does") {
        Picker("Finger", selection: Binding(get: { trial.finger }, set: { trial.setFinger($0) })) {
          Text("The system's choice").tag(PaperTrial.Finger.system)
          Text("Selects").tag(PaperTrial.Finger.selects)
          Text("Draws").tag(PaperTrial.Finger.draws)
        }
        Toggle("Lock the ink", isOn: Binding(get: { trial.locked }, set: { trial.setLocked($0) }))
      }
      Section("Pages") {
        Button("Add a page now") { trial.addPage(why: "menu") }
        Button("Add a page in 3 s") { trial.addPageSoon() }
        Button("Go to page 1") { trial.go(toPage: 1) }
        Button("Go to page 11") { trial.go(toPage: 11) }
        Button("Go to the end") { trial.goToEnd() }
      }
      Section("Undo") {
        Button("Count the undos") { trial.countUndos(why: "menu") }
      }
    } label: {
      Label("Trial", systemImage: "testtube.2")
    }
    // How much ink, for the UI test: the canvas isn't in the accessibility tree.
    .accessibilityLabel("Trial, \(trial.strokes) strokes")
    .accessibilityIdentifier("paper-trial-menu")
  }
}

@available(iOS 27, *)
private struct PaperTrialHost: UIViewControllerRepresentable {
  let trial: PaperTrial
  func makeUIViewController(context: Context) -> PaperTrial { trial }
  func updateUIViewController(_ controller: PaperTrial, context: Context) {}
}

/// PaperKit's controller can't be subclassed, so this holds it, with the ring and the probes beside it.
@available(iOS 27, *)
@MainActor
final class PaperTrial: UIViewController, ObservableObject, PaperMarkupViewController.Delegate {
  enum Finger: String { case system, selects, draws }

  @Published private(set) var pageText = "Page 1 of 1"
  @Published private(set) var strokes = 0
  @Published private(set) var layout = PaperProbe.Layout.moved
  @Published private(set) var finger = Finger.system
  @Published private(set) var locked = false

  private let copy: PaperTrialCopy
  private let log: SessionLog
  private let paper: PaperMarkupViewController
  /// Held here: the tool picker disappears when nothing keeps it.
  private let picker = PKToolPicker()
  private let lines: PaperLines
  private let watcher = PaperTouchWatcher()
  /// A sibling over the board, placed from the visible area alone (question 3). It needs its zPosition: without one
  /// the simulator drew it under PaperKit's view, though it's the later subview.
  private let ring = UIView()
  private var column = PaperProbe.column(ink: nil, layout: .moved)
  /// Where the column's corner is in the visible area's own numbers: its origin if PaperKit honours one, else zero.
  private var viewBase = CGPoint.zero
  private let opened = CACurrentMediaTime()
  private var laidWidth: CGFloat = 0
  private var loaded = false
  /// What the column's own changes shouldn't report as a person's.
  private var quiet = false
  private var inkFrames: [String: CGRect] = [:]
  private var inkAddedSinceLoad = 0
  private var systemTouchMode = PaperMarkupViewController.TouchMode.drawing
  private var systemAutoDraws = true
  /// The first stroke after a load says whether it landed under the Pencil (question 4).
  private var strokeLandingToCheck = true

  private var link: CADisplayLink?
  private var lastTick: Double = 0
  private var tickFrame = CGRect.null
  private var delegateFrame = CGRect.null
  private var glide: PaperProbe.Glide?
  private var glideFrom = CGRect.null
  private var glideStart: Double = 0
  private var glideLastMove: Double = 0
  /// A move the trial asked for rather than a person's: the delegate is documented only for a person's.
  private var asked: String?
  private var ringPage = 1

  private var touchesDown = 0
  private var pencilDown = false
  private var run: TouchRun?
  private var runEnding: Task<Void, Never>?

  private static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  init(copy: PaperTrialCopy, log: SessionLog) {
    self.copy = copy
    self.log = log
    paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: Self.features)
    lines = PaperLines(paper: copy.paper.color)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { nil }

  // MARK: - Opening

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = copy.paper.color
    addChild(paper)
    paper.view.frame = view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Question 5: a see-through canvas, the paper and its lines beneath the ink.
    paper.view.backgroundColor = .clear
    paper.view.isOpaque = false
    view.addSubview(paper.view)
    paper.didMove(toParent: self)
    paper.delegate = self
    paper.contentView = lines
    systemTouchMode = paper.directTouchMode
    systemAutoDraws = paper.directTouchAutomaticallyDraws

    ring.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
    ring.layer.cornerRadius = 22
    ring.layer.borderWidth = 2
    ring.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.6).cgColor
    ring.isUserInteractionEnabled = false
    ring.layer.zPosition = 1000
    view.addSubview(ring)

    watcher.changed = { [weak self] touch, phase, down in self?.touched(touch, phase, down: down) }
    view.addGestureRecognizer(watcher)

    picker.addObserver(paper)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible

    probe(
      "open", q: "other",
      [
        "board": copy.id, "strokes": copy.drawing.strokes.count, "ink": rect(copy.drawing.bounds),
        "idiom": UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone",
        "system": UIDevice.current.systemVersion, "layout": layout.rawValue,
        "pencil_only": UIPencilInteraction.prefersPencilOnlyDrawing,
        "touch_mode": name(paper.directTouchMode), "auto_draws": paper.directTouchAutomaticallyDraws,
        "indirect_mode": name(paper.indirectPointerTouchMode),
        "zoom_range": [Double(paper.zoomRange.lowerBound), Double(paper.zoomRange.upperBound)],
        "zoom": Double(paper.scrollConfiguration.zoomScale),
      ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = view.bounds.width
    guard width > 0, width != laidWidth else { return }
    let first = laidWidth == 0
    laidWidth = width
    // On the next turn: PaperKit lays itself out first.
    Task { @MainActor [weak self] in
      guard let self else { return }
      // Here rather than in viewDidLoad, which runs inside SwiftUI's update, where this may not publish.
      if first { self.load(self.layout) }
      self.fit(probing: first)
      if first { self.afterFirstLayout() }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let became = paper.becomeFirstResponder()
    probe("appeared", q: "other", ["became_first_responder": became, "is_first_responder": paper.isFirstResponder])
    if link == nil {
      let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
      link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
      link.add(to: .main, forMode: .common)
      self.link = link
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    link?.invalidate()
    link = nil
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
  }

  /// Close: what's in the copy goes with it.
  func finish() {
    runEnding?.cancel()
    endRun()
    endGlide()
    probe(
      "close", q: "other",
      [
        "strokes": strokes, "added_since_load": inkAddedSinceLoad, "seconds": seconds(CACurrentMediaTime() - opened),
        "saved": false,
      ])
  }

  // MARK: - The column

  private func load(_ layout: PaperProbe.Layout) {
    let started = CACurrentMediaTime()
    let ink = copy.drawing.strokes.isEmpty ? nil : copy.drawing.bounds
    column = PaperProbe.column(ink: ink, layout: layout)
    var markup = PaperMarkup(bounds: column.bounds)
    markup.append(contentsOf: copy.drawing)
    let appended = CACurrentMediaTime()
    if column.shift != .zero {
      markup.transformContent(CGAffineTransform(translationX: column.shift.dx, y: column.shift.dy))
    }
    let built = CACurrentMediaTime()
    // Before the set, so a board that takes too long still says how far it got.
    probe(
      "markup_built", q: "other",
      [
        "strokes": copy.drawing.strokes.count, "append_ms": ms(appended - started),
        "transform_ms": ms(built - appended),
      ])
    quiet = true
    paper.markup = markup
    quiet = false
    let set = CACurrentMediaTime()
    let back = paper.markup
    let read = CACurrentMediaTime()
    inkFrames = back.map(Self.frames) ?? [:]
    let framed = CACurrentMediaTime()
    inkAddedSinceLoad = 0
    strokes = inkFrames.count
    strokeLandingToCheck = true
    lines.show(column)
    probe(
      "markup_load", q: "other",
      [
        "layout": layout.rawValue, "strokes": strokes, "build_ms": ms(built - started), "set_ms": ms(set - built),
        "read_ms": ms(read - set), "frames_ms": ms(framed - read),
        "feature_set_fits": back?.featureSet.isSubset(of: paper.supportedFeatureSet) ?? false,
      ])
    probe(
      "origin", q: "origin",
      [
        "layout": layout.rawValue, "asked": rect(column.bounds), "bounds_back": back.map { rect($0.bounds) } ?? [],
        "bounds_kept": back?.bounds == column.bounds, "render_frame": back.map { rect($0.contentsRenderFrame) } ?? [],
      ])
  }

  /// What zoom means is read off the screen, then the pinch's floor is the page's width.
  private func fit(probing: Bool) {
    let config = paper.scrollConfiguration
    config.bounces = .vertical
    config.visibleScrollIndicators = .vertical
    paper.zoomRange = 0.05...4
    if probing {
      let samples: [[String: Any]] = [1, 0.5, 2].map { (asked: CGFloat) in
        config.zoomScale = asked
        paper.view.layoutIfNeeded()
        let visible = paper.contentVisibleFrame
        return [
          "asked": Double(asked), "zoom": Double(config.zoomScale), "visible_width": Double(visible.width),
          "visible_height": Double(visible.height),
        ]
      }
      probe(
        "zoom_meaning", q: "other",
        ["view_width": Double(view.bounds.width), "column_width": Double(column.width), "samples": samples])
    }
    config.zoomScale = 1
    paper.view.layoutIfNeeded()
    let fit =
      PaperProbe.fitZoom(visibleWidth: paper.contentVisibleFrame.width, atZoom: config.zoomScale, column: column.width)
      ?? 1
    paper.zoomRange = fit...max(3, fit)
    config.zoomScale = fit
    paper.view.layoutIfNeeded()
    applyTrim()
    let size = paper.contentVisibleFrame.size
    expectMove("fit")
    paper.contentVisibleFrame = CGRect(origin: column.origin, size: size)
    let reached = paper.contentVisibleFrame
    // Question 4: the simulator says the visible area counts from the column's corner, whatever the bounds' origin,
    // while the ink keeps its own numbers: ink at (10058, 10038) in a column at (10018, 9998) shows at (40, 40).
    let reachable = abs(reached.minX - column.origin.x) < 2 && abs(reached.minY - column.origin.y) < 2
    viewBase = reachable ? column.origin : .zero
    if !reachable { paper.contentVisibleFrame = CGRect(origin: .zero, size: size) }
    let visible = paper.contentVisibleFrame
    placeRing(visible)
    probe(
      "origin_reached", q: "origin",
      [
        "layout": layout.rawValue, "asked": point(column.origin), "reached": rect(reached),
        "visible_reaches_it": reachable,
      ])
    probe(
      "fit", q: "other",
      [
        "first": probing, "fit_zoom": Double(fit), "zoom": Double(config.zoomScale),
        "view_width": Double(view.bounds.width),
        "visible": rect(visible), "inset": insets(config.adjustedContentInset),
      ])
  }

  /// Whether the ink's numbers fall in the visible area's, as they are or counted from the column's corner. Which of
  /// them shows the ink on screen is for a look, or for where a new stroke lands.
  private func reportOrigin() {
    let visible = paper.contentVisibleFrame
    let placed = (paper.markup?.contentsRenderFrame) ?? .null
    let there = !placed.isNull && !placed.isEmpty
    probe(
      "origin_on_screen", q: "origin",
      [
        "layout": layout.rawValue, "visible": rect(visible), "render_frame": rect(placed), "view_base": point(viewBase),
        "ink_in_visible_numbers": there && visible.intersects(placed),
        "ink_in_visible_from_corner": there
          && visible.offsetBy(dx: column.origin.x, dy: column.origin.y).intersects(placed),
        "content_view_frame": rect(lines.frame), "content_view_bounds": rect(lines.bounds),
      ])
  }

  private func afterFirstLayout() {
    let visible = paper.contentVisibleFrame
    reportOrigin()
    probe(
      "overlay_at_rest", q: "overlay", ["slip": Double(slip()), "ring": point(ring.center), "visible": rect(visible)])
    roundTrip()
    probe(
      "loaded", q: "other",
      ["strokes": strokes, "ms": ms(CACurrentMediaTime() - opened), "first_responder": paper.isFirstResponder])
    loaded = true
  }

  /// Whether the ink's wire ids survive PaperKit: through a markup and back, and then through a drawing's data. The ids
  /// are the Cockpit's, so a change here is a change Larry would see. In memory, and never shown. The strokes are remade
  /// on the way out: PKDrawing(strokes:) on what `subelements.strokes` gives throws an Objective-C exception, nil into
  /// PencilKit's set of UUIDs, seen on the simulator on iOS 27 with ink appended from a drawing.
  private func roundTrip() {
    let started = CACurrentMediaTime()
    let ids = WhiteboardModel.strokesForLarry(copy.drawing).map(\.id)
    var markup = PaperMarkup(bounds: column.bounds)
    markup.append(contentsOf: copy.drawing)
    let back = markup.subelements.strokes
    let through = PKDrawing(
      strokes: back.map { PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform, mask: $0.mask) })
    let result = PaperProbe.roundTrip(ids, WhiteboardModel.strokesForLarry(through).map(\.id))
    let again = (try? PKDrawing(data: through.dataRepresentation())) ?? PKDrawing()
    let data = PaperProbe.roundTrip(ids, WhiteboardModel.strokesForLarry(again).map(\.id))
    probe(
      "round_trip", q: "other",
      [
        "strokes": copy.drawing.strokes.count, "strokes_back": back.count, "wire_ids": result.count,
        "back": result.countBack, "same_order": result.sameOrder, "missing": result.missing, "extra": result.extra,
        "first_missing": result.firstMissing, "through_data_missing": data.missing,
        "through_data_same_order": data.sameOrder, "drawing_equal": through == copy.drawing,
        "ms": ms(CACurrentMediaTime() - started),
      ])
  }

  // MARK: - The menu

  func setLayout(_ new: PaperProbe.Layout) {
    guard new != layout else { return }
    layout = new
    load(new)
    fit(probing: false)
    afterLayoutChange()
  }

  private func afterLayoutChange() {
    locked = false
    reportOrigin()
  }

  func setFinger(_ new: Finger) {
    finger = new
    switch new {
    case .system:
      paper.directTouchMode = systemTouchMode
      paper.directTouchAutomaticallyDraws = systemAutoDraws
    case .selects:
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .selection
    case .draws:
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .drawing
    }
    probe(
      "finger_mode", q: "finger",
      [
        "finger": new.rawValue, "touch_mode": name(paper.directTouchMode),
        "auto_draws": paper.directTouchAutomaticallyDraws,
      ])
  }

  /// What's on the board now stops being selectable: ink drawn afterwards isn't locked.
  func setLocked(_ on: Bool) {
    guard var markup = paper.markup else { return }
    locked = on
    for id in markup.subelements.ids {
      guard var element = markup.subelements[id] else { continue }
      element.allowedInteractions = on ? .readOnly : .all
      markup.subelements[id] = element
    }
    quiet = true
    paper.markup = markup
    quiet = false
    probe("ink_lock", q: "finger", ["locked": on, "strokes": strokes])
  }

  func addPageSoon() {
    probe("page_soon", q: "growth", ["pages": column.pages])
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(3))
      self?.addPage(why: "menu_soon")
    }
  }

  /// Question 2. In the tall layout growth is only the view's cut moving; otherwise it's a new markup, the only way
  /// PaperKit's interface has to change the bounds.
  func addPage(why: String, upTo target: Int? = nil) {
    let visible = paper.contentVisibleFrame
    let config = paper.scrollConfiguration
    let zoom = config.zoomScale
    let undo = paper.undoManager
    let (undoBefore, redoBefore) = (undo?.canUndo ?? false, undo?.canRedo ?? false)
    let pagesBefore = column.pages
    column.pages = max(target ?? pagesBefore + 1, pagesBefore)
    let started = CACurrentMediaTime()
    var method = "inset"
    if column.pages > column.heldPages || layout != .tall {
      method = "markup"
      column.heldPages = max(column.pages, column.heldPages)
      guard var markup = paper.markup else {
        probe("growth", q: "growth", ["why": why, "failed": "no_markup"])
        return
      }
      markup.bounds = column.bounds
      quiet = true
      paper.markup = markup
      quiet = false
    }
    let took = CACurrentMediaTime() - started
    lines.show(column)
    applyTrim()
    run?.pageAdded = true
    let after = paper.contentVisibleFrame
    placeRing(after)
    probe(
      "growth", q: "growth",
      [
        "why": why, "method": method, "layout": layout.rawValue, "pages_before": pagesBefore, "pages": column.pages,
        "ms": ms(took), "touches_down": touchesDown, "pencil_down": pencilDown, "visible_before": rect(visible),
        "visible_after": rect(after), "view_moved": visible != after, "zoom_before": Double(zoom),
        "zoom_after": Double(config.zoomScale), "can_undo_before": undoBefore, "can_redo_before": redoBefore,
        "can_undo_after": undo?.canUndo ?? false, "can_redo_after": undo?.canRedo ?? false, "strokes": strokes,
        "added_since_load": inkAddedSinceLoad, "bounds": rect(paper.markup?.bounds ?? .null),
      ])
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.6))
      guard let self else { return }
      self.probe(
        "growth_settled", q: "growth",
        [
          "visible": self.rect(self.paper.contentVisibleFrame), "view_moved": visible != self.paper.contentVisibleFrame,
          "zoom": Double(self.paper.scrollConfiguration.zoomScale), "strokes": self.strokes,
          "touches_down": self.touchesDown,
        ])
      if self.touchesDown == 0 { self.countUndos(why: "after_growth") }
    }
  }

  private func applyTrim() {
    let config = paper.scrollConfiguration
    config.contentInset.bottom = -column.trim * config.zoomScale
  }

  func go(toPage page: Int) {
    if column.pages < page { addPage(why: "go_to_page", upTo: page) }
    move(to: viewBase.y + CGFloat(page - 1) * PaperProbe.pageHeight, why: "page_\(page)")
  }

  func goToEnd() {
    move(to: viewBase.y + CGFloat(column.heldPages) * PaperProbe.pageHeight, why: "end")
  }

  private func move(to y: CGFloat, why: String) {
    var target = paper.contentVisibleFrame
    target.origin.y = y
    expectMove(why)
    paper.setContentVisibleFrame(target, animated: true)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.9))
      guard let self else { return }
      let visible = self.paper.contentVisibleFrame
      let reachable = self.viewBase.y + CGFloat(self.column.pages) * PaperProbe.pageHeight
      self.probe(
        "went", q: "feel",
        [
          "why": why, "asked_y": Double(y), "visible": self.rect(visible), "layout": self.layout.rawValue,
          "points_down": Double(visible.minY - self.viewBase.y), "page": self.page(of: visible),
          "stayed_within_pages": visible.maxY <= reachable + 2,
        ])
    }
  }

  private func expectMove(_ why: String) {
    asked = why
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.9))
      guard let self, self.glide == nil, self.asked == why else { return }
      self.asked = nil
    }
  }

  /// How many undos there are: all the way back and all the way forward again. A copy, so it can't hurt.
  func countUndos(why: String) {
    guard let undo = paper.undoManager else {
      probe("undos", q: "growth", ["why": why, "failed": "no_undo_manager"])
      return
    }
    guard touchesDown == 0 else { return }
    quiet = true
    var depth = 0
    while undo.canUndo, depth < 2_000 {
      undo.undo()
      depth += 1
    }
    let bottom = paper.markup?.subelements.count ?? -1
    var again = 0
    while undo.canRedo, again < depth {
      undo.redo()
      again += 1
    }
    quiet = false
    let restored = paper.markup.map(Self.frames) ?? [:]
    inkFrames = restored
    strokes = restored.count
    probe(
      "undos", q: "growth",
      [
        "why": why, "depth": depth, "strokes_at_bottom": bottom, "redone": again, "strokes_restored": restored.count,
        "added_since_load": inkAddedSinceLoad, "visible": rect(paper.contentVisibleFrame),
      ])
  }

  // MARK: - PaperKit's delegate

  func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
    guard !quiet, let markup = controller.markup else { return }
    let started = CACurrentMediaTime()
    let frames = Self.frames(markup)
    let change = PaperProbe.inkChange(before: inkFrames, after: frames)
    inkFrames = frames
    strokes = frames.count
    inkAddedSinceLoad += change.added.count
    run?.facts.inkAdded += change.added.count
    run?.facts.inkMoved += change.moved.count
    run?.facts.inkRemoved += change.removed.count
    guard !change.isEmpty else {
      probe(
        "ink", q: "finger", ["changed": false, "touch_down": touchesDown, "ms": ms(CACurrentMediaTime() - started)])
      return
    }
    probe(
      "ink", q: "finger",
      [
        "added": Array(change.added.prefix(20)), "removed": Array(change.removed.prefix(20)),
        "moved_count": change.moved.count,
        "moved": change.moved.prefix(20).map { move -> [String: Any] in
          [
            "id": move.id, "dx": round(move.dx), "dy": round(move.dy), "resized": move.resized,
            "frame": frames[move.id].map { rect($0) } ?? [],
          ]
        },
        "strokes": frames.count, "touch_down": touchesDown, "touch": run?.kind ?? "none",
        "ms": ms(CACurrentMediaTime() - started),
      ])
    checkLanding(change, frames: frames)
    let lowest = frames.values.map(\.maxY).max() ?? column.origin.y
    if column.needsPage(inkMaxY: lowest) {
      Task { @MainActor [weak self] in self?.addPage(why: "ink_reached_last_page") }
    }
  }

  /// Question 4: a stroke at a non-zero origin should land under the touch that drew it, in board points.
  private func checkLanding(_ change: PaperProbe.InkChange, frames: [String: CGRect]) {
    guard strokeLandingToCheck, let id = change.added.first, let frame = frames[id], let start = lastTouchBoardPoint
    else { return }
    strokeLandingToCheck = false
    probe(
      "stroke_landing", q: "origin",
      [
        "layout": layout.rawValue, "touch_at": point(start), "stroke_frame": rect(frame),
        "under_the_touch": frame.insetBy(dx: -30, dy: -30).contains(start),
        "under_the_touch_from_corner": frame.insetBy(dx: -30, dy: -30)
          .contains(CGPoint(x: start.x + column.origin.x, y: start.y + column.origin.y)),
        "column_origin": point(column.origin),
      ])
  }

  func paperMarkupViewControllerDidChangeSelection(_ controller: PaperMarkupViewController) {
    let selected = controller.selection.map(Self.key).sorted()
    run?.facts.selectionChanges += 1
    run?.selected = selected.count
    probe(
      "selection", q: "finger",
      [
        "count": selected.count, "ids": Array(selected.prefix(20)), "touch_down": touchesDown,
        "touch": run?.kind ?? "none", "finger": finger.rawValue, "locked": locked,
      ])
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
    probe(
      "began_drawing", q: "finger",
      ["touch": run?.kind ?? "none", "tool": toolName, "finger": finger.rawValue, "page": ringPage])
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    let now = CACurrentMediaTime()
    let visible = controller.contentVisibleFrame
    if glide == nil { beginGlide(from: delegateFrame, at: now) }
    glide?.delegateCalled(at: now)
    delegateFrame = visible
    glideLastMove = now
    placeRing(visible)
    applyTrim()
  }

  private static func frames(_ markup: PaperMarkup) -> [String: CGRect] {
    // `subelements.strokes`, not the set itself: walking the set by element took 4.3 s at 1,000 strokes on the simulator
    // and over 40 s at 5,000, which would have made every stroke here feel slow for a reason of the probe's own.
    Dictionary(
      markup.subelements.strokes.map { (key($0.elementID), $0.renderFrame) }, uniquingKeysWith: { _, new in new })
  }

  private static func key(_ id: MarkupOrderedSet.ElementID) -> String {
    if case .stroke(let uuid) = id { return uuid.uuidString }
    return String(describing: id)
  }

  // MARK: - The ring and the visible area

  private func placeRing(_ visible: CGRect) {
    guard visible.width > 0 else { return }
    let scale = view.bounds.width / visible.width
    ringPage = page(of: visible)
    let cross = column.cross(page: ringPage)
    ring.center = CGPoint(
      x: (viewBase.x + cross.x - visible.minX) * scale, y: (viewBase.y + cross.y - visible.minY) * scale)
    let text = "Page \(ringPage) of \(column.pages)"
    if text != pageText { pageText = text }
  }

  private func page(of visible: CGRect) -> Int {
    column.page(at: visible.midY - viewBase.y + column.origin.y)
  }

  /// How far the ring sits from the cross under it, in screen points.
  private func slip() -> CGFloat {
    let spot = lines.spot(of: column.cross(page: ringPage))
    var mark = lines.convert(spot, to: view)
    if let shown = lines.layer.presentation(), let top = view.layer.presentation() {
      mark = shown.convert(spot, to: top)
    }
    return hypot(mark.x - ring.center.x, mark.y - ring.center.y)
  }

  @objc private func tick(_ link: CADisplayLink) {
    let now = link.timestamp
    if lastTick > 0, run != nil, touchesDown > 0 {
      run?.frames += 1
      if let gap = run?.maxGap { run?.maxGap = max(gap, now - lastTick) }
    }
    lastTick = now
    guard loaded, !pencilDown else { return }
    let visible = paper.contentVisibleFrame
    let moved = visible != tickFrame && !tickFrame.isNull
    if moved, glide == nil { beginGlide(from: tickFrame, at: now) }
    tickFrame = visible
    guard glide != nil else { return }
    if moved { glideLastMove = max(glideLastMove, now) }
    glide?.tick(moved: moved, stale: visible != delegateFrame, slip: slip())
    if now - glideLastMove > 0.35 { endGlide() }
  }

  private func beginGlide(from: CGRect, at now: Double) {
    glide = PaperProbe.Glide()
    glideFrom = from
    glideStart = now
    glideLastMove = now
  }

  private func endGlide() {
    guard let glide else { return }
    self.glide = nil
    let visible = paper.contentVisibleFrame
    probe(
      "glide", q: "overlay",
      [
        "from": rect(glideFrom), "to": rect(visible), "why": asked ?? (glideFrom == visible ? "no_move" : "person"),
        "touch": run?.kind ?? "none",
        "delegate_calls": glide.delegateCalls, "max_gap_ms": ms(glide.maxGap), "frames": glide.ticks,
        "moved_frames": glide.movedTicks, "stale_frames": glide.staleTicks, "max_slip": round(glide.maxSlip),
        "ms": ms(glideLastMove - glideStart), "zoom": Double(paper.scrollConfiguration.zoomScale),
        "page": ringPage,
      ])
    asked = nil
  }

  // MARK: - Touches

  /// One touch, first down to last up, and what came of it.
  private struct TouchRun {
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

  private var lastTouchBoardPoint: CGPoint?
  private var touchStarts: [ObjectIdentifier: CGPoint] = [:]

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

  private func endRun() {
    guard var run else { return }
    self.run = nil
    let visible = paper.contentVisibleFrame
    let zoom = paper.scrollConfiguration.zoomScale
    let (dx, dy) = (visible.minX - run.visibleAtStart.minX, visible.minY - run.visibleAtStart.minY)
    run.facts.scrolled = hypot(dx, dy)
    run.facts.zoomChanged = abs(zoom - run.zoomAtStart) > 0.001
    probe(
      "touch", q: run.type == "pencil" ? "feel" : "finger",
      [
        "type": run.type, "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "seconds": seconds(run.facts.seconds), "travel": round(run.facts.travel), "fingers": run.facts.fingers,
        "at": point(run.start), "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart),
        "zoom_to": Double(zoom), "selection_changes": run.facts.selectionChanges, "selected": run.selected,
        "ink_added": run.facts.inkAdded, "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved,
        "began_drawing": run.facts.beganDrawing, "page_added_during": run.pageAdded, "frames": run.frames,
        "max_gap_ms": ms(run.maxGap), "points_down": Double(visible.minY - viewBase.y), "page": ringPage,
        "tool": run.tool, "finger": finger.rawValue, "locked": locked, "layout": layout.rawValue,
        "touch_mode": name(paper.directTouchMode), "auto_draws": paper.directTouchAutomaticallyDraws,
      ])
  }

  // MARK: - The log

  private func probe(_ kind: String, q: String, _ fields: [String: Any]) {
    var line = fields
    line["kind"] = kind
    line["q"] = q
    log.event("paper_probe", line)
  }

  private var toolName: String {
    switch paper.drawingTool {
    case let ink as PKInkingTool: return ink.inkType.rawValue
    case is PKEraserTool: return "eraser"
    case is PKLassoTool: return "lasso"
    default: return String(describing: type(of: paper.drawingTool))
    }
  }

  private func name(_ mode: PaperMarkupViewController.TouchMode) -> String {
    mode == .selection ? "selection" : "drawing"
  }

  private static func name(_ type: UITouch.TouchType) -> String {
    switch type {
    case .direct: return "finger"
    case .pencil: return "pencil"
    case .indirect: return "indirect"
    case .indirectPointer: return "pointer"
    @unknown default: return "other"
    }
  }

  private func round(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }
  private func ms(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }
  private func seconds(_ value: Double) -> Double { (value * 100).rounded() / 100 }
  private func point(_ p: CGPoint) -> [Double] { [round(p.x), round(p.y)] }
  private func insets(_ i: UIEdgeInsets) -> [Double] { [round(i.top), round(i.left), round(i.bottom), round(i.right)] }

  private func rect(_ r: CGRect) -> [Double] {
    r.isNull || r.isInfinite ? [] : [round(r.minX), round(r.minY), round(r.width), round(r.height)]
  }
}

/// Paper under the ink: its colour, a faint line where each page ends, and a small cross for the ring to sit on. In
/// PaperKit's content view, so it moves with the board and is in nothing else.
private final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  private var column: PaperProbe.Column?

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

  func show(_ column: PaperProbe.Column) {
    self.column = column
    setNeedsLayout()
  }

  /// Column points to this view's own: PaperKit sizes it.
  func spot(of point: CGPoint) -> CGPoint {
    let scale = column.map { bounds.width / $0.width } ?? 1
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let column, bounds.width > 0 else { return }
    let path = CGMutablePath()
    for page in 1...max(column.heldPages, 1) {
      let edge = spot(of: CGPoint(x: 0, y: CGFloat(page) * PaperProbe.pageHeight))
      path.move(to: edge)
      path.addLine(to: CGPoint(x: bounds.width, y: edge.y))
      let cross = spot(of: column.cross(page: page))
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
private final class PaperTouchWatcher: UIGestureRecognizer {
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
