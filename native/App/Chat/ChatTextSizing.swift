//  Story 729 (#781): chat's text size on the Mac, set from the View menu (MacMenuCommands) and remembered on this Mac.
//  A phone and an iPad follow the system's text size, as before.

import ContextCore
import SwiftUI

extension View {
  /// Chat's own text size on the Mac. Put on the thread list and on a thread, so a pushed thread has it too.
  func chatTextSize() -> some View { modifier(ChatTextSizing()) }
}

private struct ChatTextSizing: ViewModifier {
  @AppStorage(ChatTextSize.defaultsKey) private var step = ChatTextSize.standard

  func body(content: Content) -> some View {
    #if targetEnvironment(macCatalyst)
      content.dynamicTypeSize(DynamicTypeSize.allCases[ChatTextSize.restored(step)])
    #else
      content
    #endif
  }
}
