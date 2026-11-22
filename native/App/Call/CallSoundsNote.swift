//  Story 1071 (context-grabber-2r55): the call keeps the mic, so the Gym Timer and box breathing run silently while a
//  call is connecting or live. This one line says so on their screens, for as long as the call lasts.

import SwiftUI

struct CallSoundsNote: View {
  @ObservedObject var call: CallModel

  var body: some View {
    if call.snapshot.isActive {
      Label("Sounds are off during the call", systemImage: "speaker.slash")
        .font(.system(size: 13)).foregroundStyle(Color(white: 0.6))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Color(white: 0.12)))
        .accessibilityIdentifier("call-sounds-off")
    }
  }
}
