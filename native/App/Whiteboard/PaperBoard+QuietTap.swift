//  Story 1276 (#1385): each edit menu the board built for a tap, and what it took out of it, in the session log, so the
//  iPad can show a tap stayed quiet.

import UIKit

extension PaperBoardController {
  override func quietMenuBuilt(dropped: [String]) {
    log.event(
      "whiteboard",
      [
        "action": "tap_menu_quiet", "board": model.board.id, "dropped": dropped,
        "selected": paper.selection.count,
      ])
  }
}
