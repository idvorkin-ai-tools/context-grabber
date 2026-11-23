//  A board on paper: a drag by hand that picks up part of a group brings the rest along (story 998, bead
//  context-grabber-1xdh). On the iPad the system's handwriting view picked up one paragraph of a kept reply of Larry's and
//  left the rest behind.

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Story 998: the rest of each group `moved` took only part of, by place on the canvas, and how far it goes: the
  /// drag's own offset. `strokes` and their markup keys `keys` are the board's after the move, in the same order. Nil with nothing to
  /// bring along.
  func groupCarry(
    _ moved: [PaperProbe.InkMove], strokes: [BoardOps.Stroke], keys: [String]
  ) -> (indices: Set<Int>, by: CGVector, groups: [String])? {
    let names = model.strokeMeta.groups
    guard !names.isEmpty, strokes.count == keys.count else { return nil }
    var groupOf: [String: String] = [:]
    var place: [String: Int] = [:]
    for index in strokes.indices {
      guard let group = strokes[index].ids.lazy.compactMap({ names[$0] }).first else { continue }
      let key = keys[index]
      groupOf[key] = group
      place[key] = index
    }
    guard let carry = PaperProbe.groupCarry(moved, groupOf: groupOf) else { return nil }
    return (Set(carry.carry.compactMap { place[$0] }), CGVector(dx: carry.dx, dy: carry.dy), carry.groups)
  }
}
