//  #966 (story 1007; spec 2026-11-01-whiteboard-design.md, *Every keep is a step of Undo of its own, and keeps it*): the
//  board takes back some of PaperKit's own steps (a tap's dot, a zigzag, a dragged selection) by pressing Undo for it.
//  When PaperKit's step wasn't yet on top, that Undo took the board's own step under it instead, a keep, which then was
//  gone from the stack: Undo could never take the keep back. This presses Undo only for a step that isn't the board's: one
//  of the board's own, reached instead, is put straight back with Redo.

import Foundation

/// The undo stack, as the probe needs it: an app's `UndoManager`, or a test's.
public protocol BoardUndoStack: AnyObject {
  var canUndo: Bool { get }
  func undo()
  func redo()
}

public final class BoardUndoProbe {
  public enum Outcome: Equatable, Sendable {
    /// Nothing to undo.
    case nothing
    /// The step on top wasn't the board's, and it went.
    case tookBack
    /// The step on top was the board's own, named so, and it stays.
    case leftOurs(String)
  }

  /// True while the probe presses Undo or Redo: a step of the board's that runs then is the probe's to report.
  public private(set) var probing = false
  private var reached: String?

  public init() {}

  /// Called by each of the board's own steps as it runs. True while probing: the step then only makes its change and
  /// registers its way back, saying nothing to anyone, as Redo is about to undo it.
  public func reached(_ name: String) -> Bool {
    guard probing else { return false }
    reached = name
    return true
  }

  /// Undo once, for a step that isn't the board's; one of the board's own on top is left on the stack as it was.
  public func takeBackOthers(on stack: BoardUndoStack) -> Outcome {
    guard stack.canUndo else { return .nothing }
    probing = true
    reached = nil
    defer {
      probing = false
      reached = nil
    }
    stack.undo()
    guard let ours = reached else { return .tookBack }
    stack.redo()
    return .leftOurs(ours)
  }
}

#if canImport(ObjectiveC)
  extension UndoManager: BoardUndoStack {}
#endif
