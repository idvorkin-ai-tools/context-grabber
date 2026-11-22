//  Story 1020 (bead 8o93): a bare PaperKit paper over the app, for the touch contracts' UI tests
//  (`PaperKitTouchContractUITests`). The hosted contract tests (native/ContractTests) can't make a touch; a UI test can, and
//  this is what it touches: the board's feature set and inks, the tool picker shown, and the board's own touch watcher on
//  the view around the paper, with none of the board's handling of what PaperKit does. What it holds is one line of
//  text the test reads. Only `GRABBER_PAPER_STAGE` shows it.

import ContextCore
import PaperKit
import PencilKit
import UIKit

@MainActor
final class PaperTouchStage: NSObject, PaperMarkupViewController.Delegate {
  private static var shown: PaperTouchStage?

  /// The board's own (PaperBoard's): drawing only, its eight inks.
  private static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  private let hook: PaperStageHook
  private let paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: features)
  private let picker = PKToolPicker()
  private let watcher = PaperTouchWatcher()
  private let host = UIViewController()
  private let state = UILabel()
  private var window: UIWindow?
  private var ended = 0
  private var cancelled = 0
  private var liftPhase = "none"
  private var changes = 0
  private var calledOff = 0
  private var timer: Timer?

  private init(_ hook: PaperStageHook) { self.hook = hook }

  /// Over whatever the app shows, once its window scene is up.
  static func show(_ hook: PaperStageHook) {
    guard shown == nil else { return }
    let stage = PaperTouchStage(hook)
    shown = stage
    Task { @MainActor in
      for _ in 0..<100 {
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
          stage.open(on: scene)
          return
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func open(on scene: UIWindowScene) {
    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    self.window = window
    host.view.backgroundColor = .white
    // The state, and an Undo, above the paper: a tap on them never reaches it.
    state.accessibilityIdentifier = "paper-stage-state"
    state.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    state.numberOfLines = 2
    let undo = UIButton(type: .system)
    undo.setTitle("Undo", for: .normal)
    undo.accessibilityIdentifier = "paper-stage-undo"
    undo.addAction(UIAction { [weak self] _ in self?.paper.undoManager?.undo() }, for: .primaryActionTriggered)
    let bar = UIStackView(arrangedSubviews: [state, undo])
    bar.spacing = 12
    bar.translatesAutoresizingMaskIntoConstraints = false
    host.view.addSubview(bar)
    // The paper in a sheet that clips it: PaperKit draws, and takes touches, past its own view's bounds otherwise, over
    // the bar.
    let sheet = UIView()
    sheet.clipsToBounds = true
    sheet.translatesAutoresizingMaskIntoConstraints = false
    host.view.addSubview(sheet)
    host.addChild(paper)
    paper.view.frame = sheet.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sheet.addSubview(paper.view)
    paper.didMove(toParent: host)
    let guide = host.view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      bar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
      bar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
      bar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
      bar.heightAnchor.constraint(equalToConstant: 44),
      sheet.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
      sheet.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
      sheet.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
      sheet.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
    ])
    // A sheet to draw on: with no markup, PaperKit takes no ink.
    paper.markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 1024, height: 1400))
    paper.delegate = self
    paper.isEditable = true
    // As the board: a finger that selects rather than draws while marks show (PaperBoard's `fingerTaps`).
    if hook.finger == .select {
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .selection
    }
    watcher.changed = { [weak self] touch, phase, _ in self?.touched(touch, phase) }
    host.view.addGestureRecognizer(watcher)
    window.rootViewController = host
    window.makeKeyAndVisible()
    picker.addObserver(paper)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
    _ = paper.becomeFirstResponder()
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      MainActor.assumeIsolated { [weak self] in self?.render() }
    }
    changes = 0
    render()
  }

  func paperMarkupViewControllerDidChangeMarkup(_ paper: PaperMarkupViewController) {
    changes += 1
    render()
  }

  private func touched(_ touch: UITouch, _ phase: PaperTouchWatcher.Phase) {
    switch phase {
    case .began:
      guard hook.cancelsHeldTouch else { break }
      // Called off a beat after it went down, the touch still held: the stage's view, the watcher's, leaves the window
      // and comes back, and UIKit cancels every touch in it, as it does a palm's.
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(300))
        guard let self, let window = self.window, touch.phase != .ended, touch.phase != .cancelled else { return }
        self.calledOff += 1
        window.rootViewController = nil
        window.rootViewController = self.host
        self.render()
      }
    case .moved: break
    case .ended:
      ended += 1
      liftPhase = name(touch.phase)
    case .cancelled:
      cancelled += 1
      liftPhase = name(touch.phase)
    }
    render()
  }

  private func name(_ phase: UITouch.Phase) -> String {
    switch phase {
    case .began: return "began"
    case .moved: return "moved"
    case .stationary: return "stationary"
    case .ended: return "ended"
    case .cancelled: return "cancelled"
    default: return "other"
    }
  }

  private func render() {
    let undo = paper.undoManager
    let text = [
      "strokes=\(paper.markup?.subelements.strokes.count ?? 0)", "changes=\(changes)",
      "can_undo=\(undo?.canUndo == true ? 1 : 0)", "ended=\(ended)", "cancelled=\(cancelled)", "lift=\(liftPhase)",
      "called_off=\(calledOff)", "undo=\(undo?.undoActionName ?? "")",
    ].joined(separator: ";")
    guard state.text != text else { return }
    state.text = text
    state.accessibilityLabel = text
  }
}
