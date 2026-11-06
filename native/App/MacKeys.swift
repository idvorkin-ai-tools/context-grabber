//  #683, stories 677-678: on a Mac, Enter or Command+Enter does what a text field's button does. Shift+Enter passes
//  through, a new line in a growing field. A phone and an iPad keep their keyboard as it is.

import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

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

  /// #730, story 548: on a Mac, Command+V or Edit > Paste with a picture on the clipboard does what `action` does; meant
  /// for the paste the text field itself can't take, so words still paste as words. A phone and an iPad paste as they did.
  @ViewBuilder
  func macPastesImage(perform action: @escaping () -> Void) -> some View {
    #if targetEnvironment(macCatalyst)
      pasteDestination(for: ClipboardPicture.self) { _ in action() }
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

/// Any picture a paste offers, for `macPastesImage`; the action reads the clipboard itself, as the button does.
private struct ClipboardPicture: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { ClipboardPicture(data: $0) }
  }
}
