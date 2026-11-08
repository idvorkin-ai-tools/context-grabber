//  #634, stories 460-462, 470-473: what each window draws.

import BugKit
import ContextCore
import SwiftUI
import UIKit

/// Says which scene a window is, once it has one: what the ledger knows it by.
private struct SceneReader: UIViewRepresentable {
  let found: (String) -> Void

  final class Reader: UIView {
    var found: ((String) -> Void)?
    override func didMoveToWindow() {
      super.didMoveToWindow()
      if let id = window?.windowScene?.session.persistentIdentifier { found?(id) }
    }
  }

  func makeUIView(context: Context) -> Reader {
    let reader = Reader()
    reader.isUserInteractionEnabled = false
    reader.found = found
    return reader
  }

  func updateUIView(_ reader: Reader, context: Context) {}
}

/// Hands the model this scene's window actions, and reports the window's scene.
private struct WindowSeat: ViewModifier {
  let model: AppModel
  let seated: (String) -> Void
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  func body(content: Content) -> some View {
    content
      .background {
        SceneReader { id in
          model.openWindowAction = openWindow
          model.dismissWindowAction = dismissWindow
          seated(id)
        }
        .frame(width: 0, height: 0)
      }
  }
}

/// A window with no screen of its own: the home screen, or, when a home window is already up, a choice of the screens
/// that can have a window (story 731, #782). A phone has the one window, so it goes straight to the home screen.
struct HomeWindow: View {
  @ObservedObject var model: AppModel
  @State private var home: Bool?
  @State private var scene: String?

  var body: some View {
    Group {
      if !model.windowsAvailable || home == true {
        DiagnosticsView(model: model)
      } else if home == false {
        WindowChoice(model: model, scene: scene)
      } else {
        Color.clear
      }
    }
    .modifier(
      WindowSeat(model: model) {
        scene = $0
        home = model.homeWindowAppeared($0)
      }
    )
    .bugReporting(model.reporter)
    .onOpenURL { model.open(url: $0) }
    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
  }
}

/// Story 731 (#782): a new window while home is up starts as a short home: the screens that can have a window, as home's
/// tiles, in home's order. Choosing one makes it that screen's window (or brings forward the one that has it).
private struct WindowChoice: View {
  @ObservedObject var model: AppModel
  let scene: String?

  private var offered: [WindowScreen] {
    let arrangement = model.homeLayout.arrangement
    return WindowScreen.offered(todayCard: arrangement.todayCard, tiles: arrangement.tiles)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(offered, id: \.self) { screen in
            if let row = HomeRow.row(screen.tile) {
              Button {
                model.chooseForNewWindow(screen, closing: scene)
              } label: {
                Label {
                  Text(row.title).foregroundStyle(.primary)
                } icon: {
                  Image(systemName: row.icon).foregroundStyle(.white).frame(width: 30, height: 30)
                    .background(row.color, in: RoundedRectangle(cornerRadius: 7))
                }
              }
              .accessibilityIdentifier("window-choice-\(screen.rawValue)")
            }
          }
        } footer: {
          Text("Home is open in another window. Timers, breathing and calls stay there.")
        }
      }
      .navigationTitle("New Window")
    }
    .accessibilityIdentifier("window-choice")
    .onAppear { model.chooseForHook(closing: scene) }
  }
}

/// Stories 460, 461: one screen, whose Done closes the window. It uses the same views and models as the home window;
/// `AppModel.bringForward` keeps the two from showing one screen at once.
struct ScreenWindow: View {
  @ObservedObject var model: AppModel
  let screen: WindowScreen

  var body: some View {
    content
      .modifier(WindowSeat(model: model) { model.screenWindowAppeared(screen, window: $0) })
      .bugReporting(model.reporter)
      .handlesExternalEvents(preferring: [], allowing: [])
  }

  private func close() { model.closeWindow(screen) }

  @ViewBuilder private var content: some View {
    switch screen {
    case .chat:
      NavigationStack {
        ChatListView(chat: model.chat, voice: model.chatVoice, logger: model.bugLogger).toolbar { done }
      }
    case .today:
      NavigationStack { TodayView(app: model, mirror: model.mirror).toolbar { done } }
    case .cockpit: CockpitView(model: model.cockpit, onDone: close)
    case .places: PlacesView(app: model, places: model.places, tracker: model.tracker, onExit: close)
    case .whiteboard: WhiteboardListView(app: model, onDone: close)
    case .card: CardView(app: model, think: false, onDone: close)
    }
  }

  private var done: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button("Done", action: close).accessibilityIdentifier("window-done")
    }
  }
}
