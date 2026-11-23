import ContextCore
import PencilKit
import UIKit

/// What the board's model asks of the canvas it is shown on: where the view is, and the changes only the canvas can make
/// to the ink, each one undoable. The canvas sets itself as the model's once it has loaded; until then there is none.
/// The writes say what came of them.
@MainActor
protocol BoardCanvas: AnyObject {
  /// What's on screen in board points, for a turn on an empty board or a paste.
  var visibleRect: CGRect { get }
  /// Screen points to a board point.
  var zoom: CGFloat { get }
  /// Puts a kept ghost or a paste on the canvas (undoably); `name` is the step's name for Undo and Redo (#966). False
  /// when there is no markup yet: the load takes the model's drawing, with these in it.
  func draw(_ strokes: [PKStroke], named name: String) -> Bool
  /// Plans a batch of Larry's changes on the canvas, applies it as one undo named for it and says what came of it (#1040).
  func apply(_ batch: BoardOps.Batch) -> BoardCanvasOutcome
  /// Story 852: a paste on paper lands clear of ink or opens room for itself, in one undo, and comes back as the whole
  /// drawing; false where it can't (no paper laid out), and the paste is added as it was placed.
  func landPaste(_ strokes: [PKStroke]) -> Bool
  /// #938 (story 992), #894 (stories 1004–1006): kept marks of Larry's and the room they open, one undo named *Keep*,
  /// logged as `why`. False when the canvas didn't take it, and the keep inks as ever.
  func keepMakingRoom(_ strokes: [PKStroke], push: BoardRoom.Push, why: String) -> Bool
  /// Stories 855–860: a change to the outline (a header made, folded, unfolded, the outline collapsed) as one undo named
  /// `label`, read once the change is made; false when nothing changed.
  func changeOutline(named label: @autoclosure () -> String, _ change: (inout BoardOutline) -> Bool) -> Bool
  /// Story 896: the strokes at these places in the drawing moved down so far, one undo. False when there is no markup
  /// yet.
  func moveStrokes(_ moves: [Int: CGFloat]) -> Bool
  /// Shows Larry's controls (story 845).
  func showOverlays(_ list: [BoardOverlay])
  /// Something was chosen in the Board menu, the colour already chosen too.
  func menuChose()
  /// #965 (stories 1008, 1009): the bar's Undo (false) or Redo (true) pressed.
  func pressedUndo(redo: Bool)
}
