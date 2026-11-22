//  The board's Talk button (story 1055: a long press names it; bead context-grabber-h5c0, story 1113: and picks the
//  microphone, open or closed). A plain tap opens and closes the mic.

import BugKit
import ContextCore
import SwiftUI

struct WhiteboardMicButton: View {
  @ObservedObject var model: WhiteboardModel
  /// Observed for its microphones and the kept pick, which the menu lists.
  @ObservedObject var dictation: NoteDictation

  private var does: String { model.micOn ? "Stop listening" : "Talk to Claude" }

  var body: some View {
    let menu = model.micMenu
    Menu {
      Section("Talk") { Button(does) { model.tapMic() } }
      Section("Microphone") {
        WhiteboardMicRows(menu: menu) { model.pickMicrophone($0) }
        if menu.canFind {
          Button("Find microphones", systemImage: "arrow.clockwise") { model.findMicrophones() }
            .accessibilityIdentifier("whiteboard-mic-find")
        }
      }
    } label: {
      Label(does, systemImage: model.micOn ? "mic.fill" : "mic")
    } primaryAction: {
      model.tapMic()
    }
    .disabled(model.micStarting || model.micFinishing)
    .tint(model.micOn ? .red : nil)
    .accessibilityLabel(does)
    .accessibilityIdentifier("whiteboard-mic")
  }
}

/// Stories 1103, 1113: *Automatic* and each microphone the board knows, the pick ticked; shared by the note's line and
/// Talk's long press.
struct WhiteboardMicRows: View {
  let menu: BoardMicMenu
  let pick: (String?) -> Void

  var body: some View {
    ForEach(menu.rows) { row in
      Button {
        pick(row.pick)
      } label: {
        if row.ticked { Label(row.name, systemImage: "checkmark") } else { Text(row.name) }
      }
    }
  }
}
