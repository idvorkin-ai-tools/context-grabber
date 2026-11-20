//  #965 (stories 1008, 1009; spec 2026-11-01-whiteboard-design.md, *Undo and Redo on the board's own bar*): what the
//  board's Undo and Redo buttons say and whether they can be pressed, from the undo stack's state.

import Foundation

public struct BoardUndoButtons: Equatable, Sendable {
  public struct Button: Equatable, Sendable {
    /// What VoiceOver reads: the action and, when the step has one, its name (*Undo Keep group*).
    public var label: String
    public var enabled: Bool

    public init(label: String, enabled: Bool) {
      self.label = label
      self.enabled = enabled
    }
  }

  /// The narrowest a button is, in points; its height is the bar's own.
  public static let side: Double = 44

  public var undo: Button
  public var redo: Button

  /// Nothing to undo or redo: a board just opened.
  public static let none = BoardUndoButtons(canUndo: false, canRedo: false, undoName: "", redoName: "")

  public init(canUndo: Bool, canRedo: Bool, undoName: String, redoName: String) {
    undo = Button(label: Self.label("Undo", canUndo ? undoName : ""), enabled: canUndo)
    redo = Button(label: Self.label("Redo", canRedo ? redoName : ""), enabled: canRedo)
  }

  /// PencilKit's own name for his stroke (seen on the iPad simulator, rung 2, 2026-11-20): his stroke is a step with no
  /// name, so it reads plain *Undo* (story 1009).
  static let unnamed: Set<String> = ["Add Strokes"]

  private static func label(_ action: String, _ name: String) -> String {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty || unnamed.contains(name) ? action : "\(action) \(name)"
  }
}
