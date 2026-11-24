//  Story 1276 (#1385): a tap on the board brings up no system Paste · Select All menu. The iPad's log (`board_cover`
//  `edit_menu`, responder PaperMarkupViewController) showed PaperKit's selection gesture bringing up the system edit
//  menu on a plain finger tap. Paste lives in the board's own hold menu; a selection's menu keeps Copy, Delete and the
//  rest. The edit menu is built up the responder chain, and the host sits above the paper on it.

import UIKit

extension PaperHost {
  /// The edit actions a tap's menu never offers on a board.
  static let quietActions: Set<Selector> = [
    #selector(UIResponderStandardEditActions.paste(_:)),
    #selector(UIResponderStandardEditActions.pasteAndMatchStyle(_:)),
    #selector(UIResponderStandardEditActions.pasteAndGo(_:)),
    #selector(UIResponderStandardEditActions.pasteAndSearch(_:)),
    #selector(UIResponderStandardEditActions.selectAll(_:)),
  ]

  override func buildMenu(with builder: any UIMenuBuilder) {
    super.buildMenu(with: builder)
    guard builder.system == .context else { return }
    var dropped: [String] = []
    for menu in [UIMenu.Identifier.standardEdit, .edit] where builder.menu(for: menu) != nil {
      builder.replaceChildren(ofMenu: menu) { children in
        children.filter { element in
          guard let command = element as? UICommand, Self.quietActions.contains(command.action) else { return true }
          dropped.append(NSStringFromSelector(command.action))
          return false
        }
      }
    }
    quietMenuBuilt(dropped: dropped)
  }

  /// Each menu the board built for a tap, and what it took out of it, in the session log.
  @objc dynamic func quietMenuBuilt(dropped: [String]) {}
}
