//  Story 1103 (#1139): the end of the note's line while the board's mic is open: the microphone it hears, a tap away from
//  the others, and BugKit's live level bar beside it. Laid out from the dictation it is handed; a pick goes back
//  through the action it is handed.

import BugKit
import ContextCore
import SwiftUI

struct WhiteboardMicChip: View {
  /// The board's dictation: its microphones and the saved pick. Its level is handed straight to the bar, which alone
  /// redraws as the sound moves.
  @ObservedObject var dictation: NoteDictation
  /// What the open mic hears, by name (with Automatic, the system's pick).
  let hears: String?
  let pick: (String?) -> Void
  @ScaledMetric(relativeTo: .footnote) private var meterWidth: CGFloat = 56
  @ScaledMetric(relativeTo: .footnote) private var nameWidth: CGFloat = 180

  private var name: String { hears ?? dictation.selectedMicrophoneName }

  var body: some View {
    HStack(spacing: 6) {
      Menu {
        // Story 1113: the same rows as Talk's long press lists.
        WhiteboardMicRows(menu: dictation.boardMicMenu(micOpen: true, busy: false), pick: pick)
      } label: {
        HStack(spacing: 3) {
          Image(systemName: "mic.fill")
          Text(name).lineLimit(1).truncationMode(.middle)
          Image(systemName: "chevron.up.chevron.down").font(.caption2)
        }
        .frame(maxWidth: nameWidth)
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Microphone: \(name)")
      .accessibilityHint("Picks the microphone the board's mic hears")
      .accessibilityIdentifier("whiteboard-mic-picker")
      BugInputLevelMeter(level: dictation.level, accessibilityIdentifier: "whiteboard-mic-level")
        .frame(width: meterWidth)
    }
    .font(.footnote).foregroundStyle(Color(WhiteboardNoteInk.quiet))
    .padding(.trailing)
  }
}
