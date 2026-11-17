//  Story 836 (#916): a board's name in its bar as it is now, so a rename shows there at once. Not a title menu with
//  *Rename*: on the iPad that made the Board menu open as a full-height list that stayed up after a pick (#848's
//  symptom; `WhiteboardPaperLinesUITests`, 2026-11-16). Renaming is the list's swipe and long press.

import Combine
import ContextCore
import SwiftUI

struct BoardNameInBar: ViewModifier {
  let board: BoardEntry
  let store: WhiteboardStore
  @State private var name: String?

  func body(content: Content) -> some View {
    content
      .navigationTitle(name ?? board.title)
      // Only the name: the board's screen doesn't redraw for the store's other changes (a sync, a picture).
      .onReceive(store.$index.map { $0.board(board.id)?.title }.removeDuplicates()) { name = $0 }
  }
}
