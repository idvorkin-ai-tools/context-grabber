//  #681, stories 684 and 685: a Mac can't be shaken, so the menu bar carries Settings and a problem report. #722,
//  stories 722-727: every shortcut is a menu item too: New Board, Go to the home destinations, Report a Problem. #745,
//  stories 725 and 734-735: Control+R reports, and Command+N is New Chat (Igor, 2026-11-20), so New Window (story 731)
//  moves to Option+Command+N. #1046, story 736: Command+T, the Mac's new-tab key, is New Thread, the same new chat. A
//  phone and an iPad show no new items and get none of the keys.

import BugKit
import ContextCore
import SwiftUI

struct MacMenuCommands: Commands {
  @ObservedObject var model: AppModel
  /// The report sheet covers home too; its state lives here, not on the model.
  @ObservedObject var reporter: BugReporter
  /// Story 729 (#781): chat's text size, which the chat views read.
  @AppStorage(ChatTextSize.defaultsKey) private var chatTextStep = ChatTextSize.standard

  var body: some Commands {
    #if targetEnvironment(macCatalyst)
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { model.openHomeSettings() }
          .keyboardShortcut(",")
          .disabled(!model.homeInFront)
        // Story 730 (#783): the report in the first menu he opens, over whatever screen is in front.
        Button("Report a Problem…") { model.startBugReport(from: "mac_menu") }
          .keyboardShortcut("r", modifiers: [.command, .shift])
      }
      // Replaces the system's New Window (Command+N), which comes back here on Option+Command+N.
      CommandGroup(replacing: .newItem) {
        Button("New Chat") { model.newChat(from: "mac_menu") }
          .keyboardShortcut("n")
          .disabled(!model.newChatLive)
        // Story 736 (#1046): a menu item holds one key, so Command+T is a second item doing what New Chat does.
        Button("New Thread") { model.newChat(from: "mac_menu_new_thread") }
          .keyboardShortcut("t")
          .disabled(!model.newChatLive)
        Button("New Window") { model.openNewWindow(from: "mac_menu") }
          .keyboardShortcut("n", modifiers: [.command, .option])
        Button("New Board") { model.newBoard(from: "mac_menu") }
          .keyboardShortcut("n", modifiers: [.command, .shift])
          .disabled(!model.homeInFront && !model.showWhiteboard)
      }
      // Story 729 (#781): chat's text size, from any screen; it shows wherever chat does.
      CommandGroup(after: .toolbar) {
        Button("Bigger Text") { setChatText(ChatTextSize.bigger(chatText), "bigger") }
          .keyboardShortcut("=")
          .disabled(!ChatTextSize.canGrow(chatText))
        Button("Smaller Text") { setChatText(ChatTextSize.smaller(chatText), "smaller") }
          .keyboardShortcut("-")
          .disabled(!ChatTextSize.canShrink(chatText))
        Button("Actual Size") { setChatText(ChatTextSize.standard, "actual") }
          .keyboardShortcut("0")
          .disabled(chatText == ChatTextSize.standard)
      }
      CommandMenu("Go") {
        ForEach(Array(destinations.enumerated()), id: \.element.id) { index, row in
          Button(row.title) {
            model.log.event("ui", ["action": "go", "row": row.id, "from": "mac_menu"])
            row.open(model)
          }
          .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)"))) : nil)
          .disabled(!MacGoMenu.live(row.id, homeInFront: model.homeInFront))
        }
      }
      CommandGroup(replacing: .help) {
        Button("Report a Problem…") { model.startBugReport(from: "mac_help_menu") }
          .keyboardShortcut("r", modifiers: .control)
      }
    #else
      EmptyCommands()
    #endif
  }

  private var chatText: Int { ChatTextSize.restored(chatTextStep) }

  private func setChatText(_ step: Int, _ how: String) {
    chatTextStep = step
    model.log.event("ui", ["action": "chat_text_size", "how": how, "step": step, "from": "mac_menu"])
  }

  /// What home shows, in its order: the Today card when shown, then the tiles; the daily strip opens nothing.
  private var destinations: [HomeRow] {
    let arrangement = model.homeLayout.arrangement
    return ((arrangement.todayCard ? ["today"] : []) + arrangement.tiles).compactMap(HomeRow.row)
  }
}
