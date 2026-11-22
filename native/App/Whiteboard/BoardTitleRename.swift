//  Story 946 (context-grabber-5chm): the board's name in its top bar, as it is now, and on a board that draws here a tap
//  on it opens the list's rename box (spec 2026-11-01-whiteboard-design.md, *Rename from the board's own bar*). A plain
//  button, never a title menu: on the iPad a menu on the name kept the Board menu up as a full-height list after a pick
//  (d33c7d0d, 2026-11-16). A look-only board's name is plain text.

import Combine
import ContextCore
import SwiftUI

struct BoardTitleRename: ViewModifier {
  let board: BoardEntry
  let store: WhiteboardStore
  /// The board draws here (`WhiteboardModel.editable`): another device's, an old-canvas one, one that couldn't be read
  /// and every board on an iPhone are only looked at, and their name doesn't rename.
  let editable: Bool
  @State private var name: String?
  @State private var renaming = false
  @State private var newName = ""

  private var shown: String { name ?? board.title }

  func body(content: Content) -> some View {
    content
      .navigationTitle(shown)
      .toolbar {
        if editable {
          ToolbarItem(placement: .principal) {
            Button {
              newName = shown
              renaming = true
            } label: {
              Text(shown).font(.headline).lineLimit(1).truncationMode(.tail)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shown)
            .accessibilityHint("Rename the board")
            .accessibilityIdentifier("whiteboard-title")
          }
          .sharedBackgroundVisibility(.hidden)
        }
      }
      .alert("Rename board", isPresented: $renaming) {
        TextField("Name", text: $newName)
        Button("Rename") { store.rename(board.id, to: newName, from: "title") }.macDefaultAction()
        Button("Cancel", role: .cancel) {}
      }
      // Only the name: the board's screen doesn't redraw for the store's other changes (a sync, a picture).
      .onReceive(store.$index.map { $0.board(board.id)?.title }.removeDuplicates()) { name = $0 }
  }
}
