//  Story 1284 (context-grabber-hxzv): writing never zooms the board. While the Pencil or a palm is on the glass, PaperKit's
//  pinch is off; once everything lifts it is back, and the next two fingertips pinch as before.

import ContextCore
import UIKit

extension PaperHost {
  /// Called with every touch the watcher hears, after the counts are updated.
  func holdPinch(_ touch: UITouch, _ phase: PaperTouchWatcher.Phase, down: Int) {
    let id = ObjectIdentifier(touch)
    if touch.type == .direct {
      switch phase {
      case .began, .moved: fingerRadii[id] = max(fingerRadii[id] ?? 0, touch.majorRadius)
      case .ended, .cancelled: fingerRadii[id] = nil
      }
    }
    if down == 0 {
      fingerRadii = [:]
      if pinchHold != nil {
        pinchHold = nil
        for pinch in heldPinches { pinch.isEnabled = true }
        heldPinches = []
      }
      return
    }
    guard pinchHold == nil,
      let why = PaperProbe.pinchHeld(pencilDown: pencilDown, largestFingerRadius: fingerRadii.values.max() ?? 0)
    else { return }
    pinchHold = why
    // Turning a pinch off mid-gesture cancels it, so a zoom a palm had begun stops where it is.
    heldPinches = pinches().filter(\.isEnabled)
    for pinch in heldPinches { pinch.isEnabled = false }
    run?.pinchHeld = why
    run?.pinchesHeld = heldPinches.count
  }

  /// PaperKit's pinches: its scroll views' own, and any other pinch in its views.
  /// ponytail: found by walking PaperKit's views, as the margin handle finds its scroll view; a PaperKit setting is the
  /// upgrade if one comes.
  private func pinches() -> [UIPinchGestureRecognizer] {
    func walk(_ view: UIView) -> [UIPinchGestureRecognizer] {
      let own = (view.gestureRecognizers ?? []).compactMap { $0 as? UIPinchGestureRecognizer }
      let scroll = (view as? UIScrollView)?.pinchGestureRecognizer.map { [$0] } ?? []
      return own + scroll + view.subviews.flatMap(walk)
    }
    var seen = Set<ObjectIdentifier>()
    return walk(paper.view).filter { seen.insert(ObjectIdentifier($0)).inserted }
  }
}
