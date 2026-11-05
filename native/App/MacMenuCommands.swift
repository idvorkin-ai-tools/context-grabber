//  #681, story 684: a Mac can't be shaken, so the menu bar carries Settings and a problem report. A phone and an iPad
//  show no new items.

import SwiftUI

struct MacMenuCommands: Commands {
  let model: AppModel

  var body: some Commands {
    #if targetEnvironment(macCatalyst)
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { model.openHomeSettings() }
          .keyboardShortcut(",")
      }
      CommandGroup(replacing: .help) {
        Button("Report a Problem…") { model.startBugReport(from: "mac_menu") }
      }
    #else
      EmptyCommands()
    #endif
  }
}
