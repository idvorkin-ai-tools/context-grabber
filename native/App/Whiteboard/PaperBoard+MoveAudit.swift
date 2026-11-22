//  A board on paper: what a moving touch began on and held, what the board changed under it, and whose ink moved, for
//  the log (story 1143, bead context-grabber-eg7v). On the iPad one finger drag moved Larry's text and two of Igor's
//  strokes with nothing selected, beginning on PaperKit's handwriting reflow view; nothing here changes what a touch does.

import ContextCore
import PaperKit
import UIKit

extension PaperHost {
  /// PaperKit's handwriting tools over the paper: each view whose class names handwriting or reflow, with its size in
  /// points and `first` when it holds the keyboard focus (the reflow view is there, empty, on every board; on the iPad it
  /// held the focus while its popover showed), and `popover` for a popover pointed at the paper. Empty when none.
  func handwritingTools() -> [String] {
    var found: Set<String> = []
    var looks: [UIView] = [paper.view]
    var seen = 0
    while let here = looks.popLast(), seen < 3_000 {
      seen += 1
      guard !here.isHidden, here.alpha > 0 else { continue }
      let kind = String(describing: type(of: here))
      if kind.contains("Handwriting") || kind.contains("Reflow") {
        let size = "\(Int(here.bounds.width.rounded()))x\(Int(here.bounds.height.rounded()))"
        found.insert([kind, size, here.isFirstResponder ? "first" : ""].filter { !$0.isEmpty }.joined(separator: " "))
      }
      looks += here.subviews
    }
    var shown = view.window?.rootViewController?.presentedViewController
    while let top = shown {
      if let source = top.popoverPresentationController?.sourceView, source.isDescendant(of: paper.view) {
        found.insert("popover")
      }
      shown = top.presentedViewController
    }
    return found.sorted()
  }
}

extension PaperBoardController {
  /// Story 1143: a change that moved ink, against what the touch held as it went down and whose ink it is.
  func moveAudit(_ change: PaperProbe.InkChange, markup: PaperMarkup, frames: [String: CGRect]) -> [String: Any] {
    guard !change.moved.isEmpty else { return [:] }
    var fields = PaperProbe.moveAudit(
      change.moved, held: run?.heldAtStart ?? [], theirs: theirKeys(markup), frames: frames)
    fields["handwriting"] = handwritingTools()
    if let run { fields["start_view"] = run.startView }
    return fields
  }

  /// Story 1143: what the touch began on and held, and what the board and the turns changed while it was down.
  func touchAudit(_ run: TouchRun) -> [String: Any] {
    [
      "start_view": run.startView, "held_at_start": run.heldAtStart.count,
      "handwriting_at_start": run.handwritingAtStart, "handwriting_at_end": handwritingTools(),
      "board_sets": run.boardSets, "turns_during": model.turnsLogged - run.turnsAtStart,
    ]
  }

  /// The board's own change on the ink, said against the touch that is down, if one is.
  func noteBoardSet(_ name: String) {
    run?.boardSets.append(name)
  }

  /// The element keys of Larry's and Claude's strokes: every stroke made at a moment the ledger names as theirs.
  func theirKeys(_ markup: PaperMarkup) -> Set<String> {
    let moments = model.opLedger.theirs(board: model.board.id)
    guard !moments.isEmpty else { return [] }
    let strokes = opStrokes(markup).strokes
    let elements = markup.subelements.strokes
    guard strokes.count == elements.count else { return [] }
    return Set(
      elements.indices.filter { strokes[$0].t.map(moments.contains) ?? false }.map { Self.key(elements[$0].elementID) })
  }
}
