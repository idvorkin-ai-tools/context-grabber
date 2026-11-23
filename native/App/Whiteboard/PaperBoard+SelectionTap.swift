//  A board on paper: a finger tap inside Igor's own selection is the selection's, whatever it lands on (story 1196,
//  context-grabber-nkh). A group, a thing of Larry's or a kept text under it neither replaces the selection nor opens.

import ContextCore
import UIKit

extension PaperBoardController {
  /// The selected ink's box, in board points; null with nothing selected.
  var selectionBox: CGRect {
    paper.selection.map(Self.key).compactMap { inkFrames[$0] }.reduce(CGRect.null) { $0.union($1) }
  }

  /// Story 1196: true when the tap at `at` (board points) landed inside his selection on a group, a thing of Larry's
  /// or a kept text that isn't the whole selection. The selection keeps it, so PaperKit's menu shows; a drawing finger's
  /// dot is taken back. False (and nothing done) otherwise, for the tap to go on as before.
  func selectionKeptTap(at: CGPoint, beganAt: Date) -> Bool {
    guard !paper.selection.isEmpty else { return false }
    let box = selectionBox
    let reach = WhiteboardTurn.tapReach / max(screenScale, 0.01)
    guard WhiteboardMarkChoice.onSelection(box, at: at, reach: reach, onMark: false) else { return false }
    let landed: (kind: String, whole: Bool)
    if let group = tappedGroup(at: at) ?? tappedTheirs(at: at) {
      landed = (group.kind, group.selected)
    } else if let keys = keptTextKeys(at: at) {
      landed = ("text", keys == Set(paper.selection.map(Self.key)))
    } else {
      return false
    }
    guard
      WhiteboardMarkChoice.selectionKeeps(
        box, at: at, reach: reach, onMark: false, tappedIsWholeSelection: landed.whole)
    else { return false }
    if fingersDraw { ghostTap = TapDot(at: at, beganAt: beganAt) }
    log.event(
      "whiteboard",
      [
        "action": "selection_kept_tap", "board": model.board.id, "at": point(at), "landed_on": landed.kind,
        "selected": paper.selection.count, "selection_box": rect(box), "controls": model.overlays.list.count,
      ])
    return true
  }
}
