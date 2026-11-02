//  The boards (spec 2026-11-01-whiteboard-design.md, story 348): what the Whiteboard tile opens. A card per board,
//  newest change first, + New board, a long press to rename or delete this device's own; every device's boards come
//  down from iCloud when the list opens, comes forward, or is pulled.

import BugKit
import ContextCore
import SwiftUI

struct WhiteboardListView: View {
  @StateObject private var store: WhiteboardStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var path: [String] = []
  @State private var renaming: BoardEntry?
  @State private var newName = ""
  @State private var deleting: BoardEntry?
  /// A link named a board that isn't here (#603).
  @State private var linkProblem: BugProblem?
  private let app: AppModel
  private let onDone: () -> Void

  init(app: AppModel, onDone: @escaping () -> Void) {
    _store = StateObject(wrappedValue: WhiteboardStore(log: app.log, device: app.whiteboardDevice))
    self.app = app
    self.onDone = onDone
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if let problem = store.problem { BugProblemView(problem: problem, logger: app.bugLogger) }
          if let linkProblem { BugProblemView(problem: linkProblem, logger: app.bugLogger) }
          if let note = store.syncNote { Text(note).font(.footnote).foregroundStyle(.secondary) }
          if store.index.boards.isEmpty {
            ContentUnavailableView(
              "No boards yet", systemImage: "scribble.variable", description: Text("Tap + to start one."))
          } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 320), spacing: 16)], spacing: 16) {
              ForEach(store.index.sorted) { board in card(board) }
            }
          }
        }
        .padding()
      }
      .refreshable { await store.sync(reason: "pull") }
      .navigationTitle("Boards")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done", action: onDone).accessibilityIdentifier("whiteboard-done")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            path.append(store.create())
          } label: {
            Label("New board", systemImage: "plus")
          }
          .accessibilityIdentifier("whiteboard-new")
        }
      }
      .navigationDestination(for: String.self) { id in
        if let board = store.index.board(id) { WhiteboardView(board: board, store: store, app: app) }
      }
    }
    .accessibilityIdentifier("whiteboard-list")
    .task {
      if let linked = app.whiteboardLink {
        app.whiteboardLink = nil
        linkProblem = await store.find(linked, context: "WhiteboardListView.link")
        if linkProblem == nil, path.isEmpty { path = [linked] }
      } else {
        await store.sync(reason: "open")
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await store.sync(reason: "foreground") } }
    }
    .alert(
      "Rename board",
      isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
      presenting: renaming
    ) { board in
      TextField("Name", text: $newName)
      Button("Rename") { store.rename(board.id, to: newName) }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete this board from every device?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { board in
      Button("Delete \(board.title)", role: .destructive) { store.delete(board.id) }
    }
  }

  private func card(_ board: BoardEntry) -> some View {
    Button {
      path.append(board.id)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        BoardPicture(url: store.pictureURL(board.id), version: store.pictures)
        Text(board.title).font(.headline).lineLimit(1)
        Text(subtitle(board)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .buttonStyle(.plain)
    .contextMenu {
      if store.editable(board) {
        Button {
          newName = board.title
          renaming = board
        } label: {
          Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
          deleting = board
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
    .accessibilityIdentifier("whiteboard-card")
  }

  private func subtitle(_ board: BoardEntry) -> String {
    let when = RelativeDateTimeFormatter().localizedString(
      for: Date(timeIntervalSince1970: Double(board.updated) / 1000), relativeTo: Date())
    return store.editable(board) ? "Changed \(when)" : "Changed \(when) · Drawn on \(board.deviceName)"
  }
}

/// A board's picture on white, as the ink is dark on white whatever the mode; blank for an empty board.
private struct BoardPicture: View {
  let url: URL?
  /// Changes when a picture on disk does, so this one is read again.
  let version: Int

  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(Color.white)
      .overlay {
        if let url, let image = UIImage(contentsOfFile: url.path) {
          Image(uiImage: image).resizable().scaledToFit().padding(8)
        }
      }
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
      .aspectRatio(4 / 3, contentMode: .fit)
      .id(version)
  }
}
