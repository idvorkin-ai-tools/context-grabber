//  #683, stories 677-678: on a Mac, Enter or Command+Enter does what a text field's button does. Shift+Enter passes
//  through, a new line in a growing field. A phone and an iPad keep their keyboard as it is.

import SwiftUI

extension View {
  /// `action` guards itself as its button does, by being disabled or by refusing.
  @ViewBuilder
  func macEnterConfirms(perform action: @escaping () -> Void) -> some View {
    #if targetEnvironment(macCatalyst)
      onKeyPress(.return, phases: .down) { press in
        if press.modifiers.contains(.shift) { return .ignored }
        action()
        return .handled
      }
    #else
      self
    #endif
  }

  /// A button in an alert, whose field takes no key handler of its own.
  @ViewBuilder
  func macDefaultAction() -> some View {
    #if targetEnvironment(macCatalyst)
      keyboardShortcut(.defaultAction)
    #else
      self
    #endif
  }
}
