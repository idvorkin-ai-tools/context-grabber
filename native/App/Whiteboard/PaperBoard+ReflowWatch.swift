//  A board on paper: PaperKit's handwriting reflow, for the log (story 1188; #1256, #1255). On the iPad its reflow
//  animation gave a word picture a position that is not a number, a moment after a touch began on the reflow, and the
//  system stopped the app. This says what the reflow showed, where, and what had just touched it, before anything is
//  changed.

import ContextCore
import UIKit

/// What the reflow watch remembers: the last look written and the last touch's start.
@MainActor
final class BoardReflowWatch {
  var last: [PaperProbe.ReflowView] = []
  var touchAt: Double?
  var touchOn = ""
}

extension PaperBoardController {
  /// Twice a second while the board's controller lives, a look at PaperKit's reflow; a line only on a change.
  func watchReflow() {
    Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(0.5))
        guard let self else { return }
        self.lookAtReflow(why: "look")
      }
    }
  }

  /// A touch went down: remembered for the next line, and a touch on the reflow itself is a line at once (the iPad's
  /// crash came about 20 ms after one).
  func reflowTouched(_ touch: UITouch) {
    let kind = touch.view.map { String(describing: type(of: $0)) } ?? ""
    reflowWatch.touchAt = CACurrentMediaTime()
    reflowWatch.touchOn = kind
    guard PaperProbe.isReflowKind(kind) else { return }
    lookAtReflow(why: "touch", always: true)
  }

  private func lookAtReflow(why: String, always: Bool = false) {
    let all = reflowViews()
    let shown = PaperProbe.reflowShown(all)
    guard always || shown != reflowWatch.last else { return }
    reflowWatch.last = shown
    let watch = reflowWatch
    log.event(
      "whiteboard",
      [
        "action": "paper_reflow", "board": model.board.id, "why": why, "views": (always ? all : shown).map(\.fields),
        "selected": paper.selection.count, "popover": popoverAtPaper(),
        "touch_ms_ago": watch.touchAt.map { Int((CACurrentMediaTime() - $0) * 1_000) } ?? -1, "touch_on": watch.touchOn,
      ])
  }

  /// Every view of PaperKit's reflow over the paper, with its pictures and flawed frames.
  private func reflowViews() -> [PaperProbe.ReflowView] {
    var found: [PaperProbe.ReflowView] = []
    var looks: [UIView] = [paper.view]
    var seen = 0
    while let here = looks.popLast(), seen < 3_000 {
      seen += 1
      looks += here.subviews
      let kind = String(describing: type(of: here))
      guard !here.isHidden, PaperProbe.isReflowKind(kind) else { continue }
      let box = here.convert(here.bounds, to: paper.view)
      var pictures = 0
      var flawed: [String: Int] = [:]
      var layers: [CALayer] = [here.layer]
      var layersSeen = 0
      while let layer = layers.popLast(), layersSeen < 400 {
        layersSeen += 1
        layers += layer.sublayers ?? []
        if layer !== here.layer, layer.contents != nil { pictures += 1 }
        let frame = layer.frame
        if let flaw = PaperProbe.reflowFlaw(
          x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height),
          flaw != .empty || layer.contents != nil
        {
          flawed[flaw.rawValue, default: 0] += 1
        }
      }
      found.append(
        PaperProbe.ReflowView(
          kind: kind,
          frame: PaperProbe.reflowRect(x: box.origin.x, y: box.origin.y, width: box.width, height: box.height),
          within: here.superview.map { String(describing: type(of: $0)) } ?? "", pictures: pictures, flawed: flawed))
    }
    return found
  }

  /// Whether a popover pointed at the paper (the system's handwriting offer) is up.
  private func popoverAtPaper() -> Bool {
    var shown = view.window?.rootViewController?.presentedViewController
    while let top = shown {
      if let source = top.popoverPresentationController?.sourceView, source.isDescendant(of: paper.view) { return true }
      shown = top.presentedViewController
    }
    return false
  }
}
