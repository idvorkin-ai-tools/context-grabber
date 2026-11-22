//  The board's PaperKit set up as the board sets it up, on its own window inside the app, for the contract tests: the
//  same feature set and inks, the tool picker shown with the paper as its observer, and a delegate that counts and can
//  act inside PaperKit's change callback.

import PaperKit
import PencilKit
import UIKit
import XCTest

@MainActor
final class PaperStage {
  /// The delegate: how many changes PaperKit told, and what to do inside the next one.
  final class Delegate: NSObject, PaperMarkupViewController.Delegate, PKToolPickerObserver {
    var changes = 0
    var toolPicks = 0
    var duringNextChange: ((PaperMarkupViewController) -> Void)?

    func paperMarkupViewControllerDidChangeMarkup(_ paper: PaperMarkupViewController) {
      changes += 1
      let act = duringNextChange
      duringNextChange = nil
      act?(paper)
    }

    func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) { toolPicks += 1 }
  }

  /// The board's own (PaperHost's): drawing only, its eight inks.
  static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  static let inks: [PKInk.InkType] = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]

  let paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: features)
  let picker = PKToolPicker()
  let delegate = Delegate()
  private let window: UIWindow

  init() throws {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "the app has a window scene")
    window = UIWindow(windowScene: scene)
    let host = UIViewController()
    host.addChild(paper)
    paper.view.frame = host.view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.view.addSubview(paper.view)
    paper.didMove(toParent: host)
    paper.delegate = delegate
    window.rootViewController = host
    window.makeKeyAndVisible()
    picker.addObserver(paper)
    picker.addObserver(delegate)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
    _ = paper.becomeFirstResponder()
    Self.wait(0.5)
  }

  func close() {
    if let pen = picker.toolItems.first(where: { ($0 as? PKToolPickerInkingItem)?.inkingTool.inkType == .pen }) {
      picker.selectedToolItem = pen
    }
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    window.isHidden = true
  }

  /// The run loop turned for `seconds`: PaperKit's next turns, and anything it does a beat later.
  static func wait(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

  /// The strokes PaperKit holds now.
  var held: Int { paper.markup?.subelements.strokes.count ?? -1 }

  /// A ten-point stroke across at `y`.
  static func stroke(at y: CGFloat, ink: PKInk = PKInk(.pen, color: .black)) -> PKStroke {
    let points = (0..<10).map { i in
      PKStrokePoint(
        location: CGPoint(x: 40 + CGFloat(i) * 10, y: y), timeOffset: Double(i) * 0.01,
        size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()))
  }

  /// A page of strokes, one at each `y`.
  static func markup(_ ys: [CGFloat]) -> PaperMarkup {
    var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
    markup.append(contentsOf: PKDrawing(strokes: ys.map { stroke(at: $0) }))
    return markup
  }

  /// `markup` with one more stroke, at `y`.
  static func adding(_ markup: PaperMarkup, at y: CGFloat) -> PaperMarkup {
    var more = markup
    more.append(contentsOf: PKDrawing(strokes: [stroke(at: y)]))
    return more
  }

  /// The ink's kind as the Objective-C ink spells it, never through the Swift getter that traps (#1083).
  static func kind(_ ink: PKInk) -> String? { (ink as PKInkReference).value(forKey: "inkType") as? String }
}
