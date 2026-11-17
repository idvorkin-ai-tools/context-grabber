//  Story 836 (#916): a board's name in its bar, as it is now, and on a board drawn on this device a menu on it with
//  *Rename* (spec 2026-11-01-whiteboard-design.md, *Rename*). The list's row offers the same box.

import ContextCore
import SwiftUI

struct BoardNameInBar: ViewModifier {
  let board: BoardEntry
  @ObservedObject var store: WhiteboardStore
  @State private var renaming = false
  @State private var newName = ""

  private var name: String { store.index.board(board.id)?.title ?? board.title }

  func body(content: Content) -> some View {
    if store.editable(board) {
      content
        .navigationTitle(name)
        .toolbarTitleMenu {
          Button {
            newName = name
            renaming = true
          } label: {
            Label("Rename", systemImage: "pencil")
          }
          .accessibilityIdentifier("whiteboard-rename")
        }
        .alert("Rename board", isPresented: $renaming) {
          TextField("Name", text: $newName)
          Button("Rename") { store.rename(board.id, to: newName) }.macDefaultAction()
          Button("Cancel", role: .cancel) {}
        }
    } else {
      content.navigationTitle(name)
    }
  }
}
