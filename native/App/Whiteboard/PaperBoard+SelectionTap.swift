//  A board on paper: a finger tap inside Igor's own selection is the selection's, whatever it lands on (story 1196,
//  context-grabber-nkh). A group, a thing of Larry's or a kept text under it neither replaces the selection nor opens.

import ContextCore
import PaperKit
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
    let kept = paper.selection
    if fingersDraw { ghostTap = TapDot(at: at, beganAt: beganAt, kept: kept) }
    log.event(
      "whiteboard",
      [
        "action": "selection_kept_tap", "board": model.board.id, "at": point(at), "landed_on": landed.kind,
        "selected": paper.selection.count, "selection_box": rect(box), "controls": model.overlays.list.count,
        "fingers_draw": fingersDraw,
      ])
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1.2))
      guard let self else { return }
      self.log.event(
        "whiteboard",
        [
          "action": "selection_kept_held", "board": self.model.board.id, "landed_on": landed.kind,
          "held": self.paper.selection == kept, "selected": self.paper.selection.count, "kept": kept.count,
        ])
    }
    return true
  }

  /// Story 1196: the selection a kept tap found, put back once PaperKit's dot for that tap is taken back, which on the
  /// simulator left nothing selected after a group tap (story 947).
  func putBackKeptSelection(_ kept: Set<MarkupOrderedSet.ElementID>) {
    let undo = paper.undoManager
    guard !kept.isEmpty, paper.selection != kept, undo?.isUndoing != true, undo?.isRedoing != true else { return }
    log.event(
      "whiteboard",
      ["action": "selection_kept_put_back", "board": model.board.id, "had": paper.selection.count, "to": kept.count])
    paper.selection = kept
    model.selectionChanged(Set(kept.map(Self.key)))
    showToText()
  }
}
