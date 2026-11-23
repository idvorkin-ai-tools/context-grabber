//  Story 1217 (bead context-grabber-0xrz): the PaperKit board, a scratch page with every pen and shape PaperKit has, so
//  Igor can feel them before the real board takes any. The real board (`PaperHost`) turns on drawing alone; this turns on
//  everything, with the fountain pen in hand. Nothing here is saved or sent: closing it throws the page away.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit

/// The scratch page, full screen from Settings' *About and diagnostics* on the iPad (story 1222).
struct PaperKitBoardView: View {
  let log: SessionLog

  var body: some View {
    PaperKitBoardPage(log: log)
      .ignoresSafeArea(edges: .bottom)
      .navigationTitle("PaperKit board")
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("paperkit-board")
  }
}

private struct PaperKitBoardPage: UIViewControllerRepresentable {
  let log: SessionLog

  func makeUIViewController(context: Context) -> PaperKitBoardController { PaperKitBoardController(log: log) }
  func updateUIViewController(_ controller: PaperKitBoardController, context: Context) {}
}

/// PaperKit's controller with every feature, shape, line end and ink on, and PaperKit's own insert menu behind the tool
/// picker's **+**.
@MainActor
final class PaperKitBoardController: UIViewController, PaperMarkupViewController.Delegate {
  /// Every pen this SDK has (PencilKit's `PKInkType.h`), the fountain pen first: the one in hand when the page opens.
  static let inks: [PKInkingTool.InkType] = [
    .fountainPen, .pen, .pencil, .marker, .monoline, .watercolor, .crayon, .reed,
  ]

  /// Everything PaperKit offers on this SDK.
  static let features: FeatureSet = {
    var set = FeatureSet.latest
    set.contentVersion = .latest
    for feature in FeatureSet.Feature.allCases { set.insert(feature) }
    set.shapes = Set(ShapeConfiguration.Shape.allCases)
    set.lineMarkerPositions = .all
    set.inks = Set(inks)
    return set
  }()

  private let log: SessionLog
  private let paper: PaperMarkupViewController
  /// Held here: the tool picker disappears when nothing keeps it.
  private let picker: PKToolPicker

  init(log: SessionLog) {
    self.log = log
    paper = PaperMarkupViewController(markup: PaperMarkup(bounds: .zero), supportedFeatureSet: Self.features)
    var items: [PKToolPickerItem] = Self.inks.map { PKToolPickerInkingItem(type: $0) }
    items.append(PKToolPickerEraserItem(type: .vector))
    items.append(PKToolPickerLassoItem())
    items.append(PKToolPickerRulerItem())
    picker = PKToolPicker(toolItems: items)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    addChild(paper)
    paper.view.frame = view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(paper.view)
    paper.didMove(toParent: self)
    paper.markup = PaperMarkup(bounds: view.bounds)
    let insert = UIBarButtonItem(
      image: UIImage(systemName: "plus"), primaryAction: UIAction { [weak self] _ in self?.showInsertMenu() })
    insert.accessibilityIdentifier = "paperkit-board-insert"
    insert.accessibilityLabel = "Insert"
    picker.accessoryItem = insert
    paper.delegate = self
    showElements()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Story 1222: PencilKit shows the tool picker only for its first responder; nothing else makes the paper one.
    if !paper.isFirstResponder { paper.becomeFirstResponder() }
    // Story 1222 (context-grabber-wvpv): what the page shows a second after it opens, so "nothing there" can be read.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.logPickerCheck() }
  }

  private func logPickerCheck() {
    let presenter = navigationController?.presentingViewController ?? presentingViewController
    log.event(
      "paperkit_board",
      [
        "action": "picker_check", "picker_visible": picker.isVisible, "first_responder": paper.isFirstResponder,
        "accessory": picker.accessoryItem != nil, "in_sheet": presenter != nil,
        "presentation": (navigationController ?? self).modalPresentationStyle.rawValue,
        "size_class": traitCollection.horizontalSizeClass == .compact ? "compact" : "regular",
        "touch_mode": paper.directTouchMode == .selection ? "selection" : "drawing",
        "auto_draws": paper.directTouchAutomaticallyDraws,
      ])
  }

  func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) { showElements() }

  /// For the UI test: how many elements the page holds, on the page's accessibility value.
  private func showElements() {
    view.accessibilityValue = "\(paper.markup?.subelements.count ?? 0) elements"
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if paper.markup?.bounds.isEmpty ?? true { paper.markup = PaperMarkup(bounds: view.bounds) }
    picker.addObserver(paper)
    if let fountain = picker.toolItems.first(where: {
      ($0 as? PKToolPickerInkingItem)?.inkingTool.inkType == .fountainPen
    }) {
      picker.selectedToolItem = fountain
    }
    paper.drawingTool = PKInkingTool(.fountainPen, color: .label)
    // Story 1222: a finger draws here too, so the shapes and pens can be tried without the Pencil.
    paper.directTouchMode = .drawing
    paper.directTouchAutomaticallyDraws = true
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
    log.event(
      "paperkit_board",
      [
        "action": "opened", "inks": Self.inks.map(\.rawValue),
        "shapes": Self.features.shapes.count, "features": Self.features.features.count,
        "tool": (paper.drawingTool as? PKInkingTool)?.inkType.rawValue ?? "other",
      ])
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
    log.event(
      "paperkit_board", ["action": "closed", "elements": paper.markup?.subelements.count ?? 0])
  }

  /// PaperKit's own menu of shapes, text boxes, lines and arrows, stickers and images; the paper inserts what's picked.
  private func showInsertMenu() {
    let menu = MarkupEditViewController(supportedFeatureSet: Self.features)
    menu.delegate = paper
    menu.modalPresentationStyle = .popover
    menu.popoverPresentationController?.sourceItem = picker.accessoryItem
    present(menu, animated: true)
  }
}
