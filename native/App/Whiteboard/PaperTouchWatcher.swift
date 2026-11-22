//  The recogniser that sees every touch on a board and takes none. Moved from PaperBoard.swift as it was
//  (context-grabber-fz4x).

import UIKit
import UIKit.UIGestureRecognizerSubclass

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
