//  A pen touch's path in the session log (spec 2026-11-01-whiteboard-design.md, *A pen touch's path is in the log*;
//  story 1104, bead context-grabber-y544): each Pencil touch, and each finger touch while fingers draw, is one
//  `board_touch` line when it lifts, its points in board points with their times, so `just touch-fixture` can judge it
//  again on the Mac. The type is not a `whiteboard` one, so the paths never go to the Cockpit with the board's log: a
//  pen path is Igor's handwriting.

import ContextCore
import UIKit

/// The drawing touches down now, each with its path so far.
@MainActor
final class BoardTouchPaths {
  fileprivate struct Open {
    var began: TimeInterval
    var type: String
    var picker: String
    var samples: [BoardTouchPath.Sample]
  }

  fileprivate var open: [ObjectIdentifier: Open] = [:]
}

extension PaperBoardController {
  /// From the base's touch hooks, beside the snap's: `draws` when it is the Pencil, or a finger while fingers draw.
  func pathTouch(_ touch: UITouch, _ phase: SnapTouch, draws: Bool) {
    let id = ObjectIdentifier(touch)
    let point = lines.columnPoint(of: touch.location(in: lines))
    switch phase {
    case .down:
      guard model.editable, draws else { return }
      // A touch the view never heard lift is no part of the next.
      if paths.open.count > 8 { paths.open = [:] }
      paths.open[id] = BoardTouchPaths.Open(
        began: touch.timestamp, type: Self.name(touch.type), picker: pickerText,
        samples: [BoardTouchPath.Sample(point, ms: 0)])
    case .moved:
      guard let began = paths.open[id]?.began else { return }
      paths.open[id]?.samples.append(BoardTouchPath.Sample(point, ms: (touch.timestamp - began) * 1000))
      // Thinned as it grows, so a touch held down for minutes stays small.
      if let count = paths.open[id]?.samples.count, count > BoardTouchPath.most * 4 {
        paths.open[id]?.samples = BoardTouchPath.thinned(paths.open[id]?.samples ?? [])
      }
    case .lifted:
      guard var path = paths.open.removeValue(forKey: id) else { return }
      path.samples.append(BoardTouchPath.Sample(point, ms: (touch.timestamp - path.began) * 1000))
      log.event(
        "board_touch",
        [
          "action": "path", "board": model.board.id, "touch_type": path.type, "picker_tool": path.picker,
          "phase": touch.phase == .cancelled ? "cancelled" : "ended", "points": path.samples.count,
          "ms": Int(path.samples.last?.ms ?? 0), "path": BoardTouchPath.encode(path.samples),
        ])
    }
  }
}
