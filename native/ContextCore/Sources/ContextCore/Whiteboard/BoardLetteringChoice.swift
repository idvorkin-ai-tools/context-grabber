//  A board's lettering on this device (spec 2026-11-01-whiteboard-shapes-design.md, *A real font, still drawn as ink*;
//  stories 1042–1044, #950): single strokes or the real font, remembered per board as its lines are. A board with
//  nothing saved, every board from before included, letters in single strokes.

import Foundation

public struct BoardLetteringChoice: @unchecked Sendable {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public static func key(_ board: String) -> String { "whiteboard_lettering_\(board)" }

  /// What the board letters new text in; a value from a newer build reads as single strokes.
  public func choice(_ board: String) -> WhiteboardTurn.LetterStyle {
    WhiteboardTurn.LetterStyle.named(defaults.string(forKey: Self.key(board))) ?? .single
  }

  public func set(_ lettering: WhiteboardTurn.LetterStyle, board: String) {
    defaults.set(lettering.rawValue, forKey: Self.key(board))
  }

  /// A board deleted or dropped here: its choice goes with it.
  public func forget(_ board: String) {
    defaults.removeObject(forKey: Self.key(board))
  }
}
