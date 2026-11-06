//  #681, stories 684 and 685: a Mac can't be shaken, so the menu bar carries Settings and a problem report. #722,
//  story 722: every shortcut is a menu item too: New Board, Go to the home destinations, Report a Problem. A phone and
//  an iPad show no new items and get none of the keys.

import SwiftUI

struct MacMenuCommands: Commands {
  @ObservedObject var model: AppModel

  var body: some Commands {
    #if targetEnvironment(macCatalyst)
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { model.openHomeSettings() }
          .keyboardShortcut(",")
          .disabled(!model.homeInFront)
      }
      // Command+N stays the Mac's New Window.
      CommandGroup(after: .newItem) {
        Button("New Board") { model.newBoard(from: "mac_menu") }
          .keyboardShortcut("n", modifiers: [.command, .shift])
          .disabled(!model.homeInFront && !model.showWhiteboard)
      }
      CommandMenu("Go") {
        ForEach(Array(destinations.enumerated()), id: \.element.id) { index, row in
          Button(row.title) {
            model.log.event("ui", ["action": "go", "row": row.id, "from": "mac_menu"])
            row.open(model)
          }
          .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)"))) : nil)
          .disabled(!model.homeInFront)
        }
      }
      CommandGroup(replacing: .help) {
        Button("Report a Problem…") { model.startBugReport(from: "mac_menu") }
          .keyboardShortcut("r", modifiers: [.command, .shift])
      }
    #else
      EmptyCommands()
    #endif
  }

  /// What home shows, in its order: the Today card when shown, then the tiles; the daily strip opens nothing.
  private var destinations: [HomeRow] {
    let arrangement = model.homeLayout.arrangement
    return ((arrangement.todayCard ? ["today"] : []) + arrangement.tiles).compactMap(HomeRow.row)
  }
}
