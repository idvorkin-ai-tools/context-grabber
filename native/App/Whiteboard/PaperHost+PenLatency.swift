//  Story 1311 (context-grabber-7xv6): how fast the board answers the Pencil. One Pencil moment in four is stamped with
//  its touch's own timestamp, and the next frame's presentation time (the display link's `targetTimestamp`, the same
//  clock) ends it: input to frame presentation, the span the web board measures. The display link runs only while a
//  stamp waits, so the board does nothing extra between strokes.

import ContextCore
import UIKit

extension PaperHost {
  /// A Pencil touch heard going down or moving.
  func penMoment(_ touch: UITouch) {
    guard touch.type == .pencil, penMeter.measuresNext() else { return }
    penWaiting.append(touch.timestamp)
    if penLink == nil {
      let link = CADisplayLink(target: self, selector: #selector(penFrame(_:)))
      link.add(to: .main, forMode: .common)
      penLink = link
    }
    penLink?.isPaused = false
  }

  /// The Pencil lifted: a line when enough moments wait.
  func penLifted() {
    guard let line = penMeter.lifted() else { return }
    penLatencyLine(line, hz: penHz)
  }

  /// The view going away: the display link holds its target, so it stops here.
  func stopPenClock() {
    penLink?.invalidate()
    penLink = nil
    penWaiting = []
  }

  @objc private func penFrame(_ link: CADisplayLink) {
    let frame = link.targetTimestamp - link.timestamp
    if frame > 0 { penHz = Int((1 / frame).rounded()) }
    let waiting = penWaiting
    penWaiting = []
    link.isPaused = true
    for stamp in waiting {
      if let line = penMeter.add(milliseconds: (link.targetTimestamp - stamp) * 1000) {
        penLatencyLine(line, hz: penHz)
      }
    }
  }
}
