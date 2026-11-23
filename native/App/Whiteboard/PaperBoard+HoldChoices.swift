//  A board on paper: the hold menu's rows for the thing under the finger, Select and Delete (stories 1186, 1187;
//  spec 2026-11-16-whiteboard-board-ops-design.md, *Press and hold*; context-grabber-y4y).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// A finger that draws leaves a dot where it held for the menu, a little after it lifts: taken back as a tap's is,
  /// so a hold on a word leaves nothing on it.
  func holdLifted(at: CGPoint) {
    guard holdMenu != nil, fingersDraw, let began = holdBegan else { return }
    ghostTap = TapDot(at: at, beganAt: began, within: PaperProbe.rewordDotSeconds)
    log.event("board_outline", ["action": "hold_lifted", "board": model.board.id, "at": point(at)])
  }

  /// Story 1186: the thing under the held finger selected, as a lasso round it would, its label and To text beside it.
  /// A beat later the log says whether the selection held.
  func holdSelect(_ names: [String]) {
    guard let markup = paper.markup, !names.isEmpty else { return }
    let wanted = Set(names)
    let ids = groupElements(wanted, in: markup)
    paper.selection = ids
    model.selectionChanged(Set(ids.map(Self.key)))
    showToText()
    log.event("board_outline", ["action": "hold_selected", "board": model.board.id, "strokes": ids.count])
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.6))
      guard let self, let markup = self.paper.markup else { return }
      let now = self.groupElements(wanted, in: markup)
      self.log.event(
        "board_outline",
        [
          "action": "hold_selected_held", "board": self.model.board.id,
          "held": !now.isEmpty && self.paper.selection == now, "selected": self.paper.selection.count,
        ])
    }
  }

  /// Story 1187: the thing under the held finger erased, one Undo named *Delete*; Larry hears it erased.
  func holdDelete(_ names: [String]) {
    guard let markup = paper.markup, !names.isEmpty else { return }
    let keys = Set(groupElements(Set(names), in: markup).map(Self.key))
    guard !keys.isEmpty else { return }
    paper.selection = []
    replaceInk(removing: keys, adding: [], named: "Delete")
    log.event("board_outline", ["action": "hold_deleted", "board": model.board.id, "strokes": keys.count])
  }
}
