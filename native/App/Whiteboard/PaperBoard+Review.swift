//  The board's strokes and folds as they are now, for the session's review record (spec
//  2026-11-23-board-interaction-review-design.md; bead context-grabber-8ao5.3): each stroke by its element key, whose it
//  is (Larry's and Claude's by the moments the ledger names as theirs), its box and whether a fold hides it; each
//  header's fold by the same keys. The recorder diffs these, so what a step changed is what the board really did.

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// Every stroke now; nil with no markup to read.
  func reviewInk() -> [String: BoardReviewRecorder.InkNow]? {
    guard let markup = paper.markup else { return nil }
    let elements = markup.subelements.strokes
    let strokes = markup.inkDrawing.strokes
    guard elements.count == strokes.count else { return nil }
    let theirs = model.opLedger.theirs(board: model.board.id)
    var out: [String: BoardReviewRecorder.InkNow] = [:]
    for (element, stroke) in zip(elements, strokes) {
      let t = Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
      let f = element.renderFrame
      out[Self.key(element.elementID)] = BoardReviewRecorder.InkNow(
        owner: theirs.contains(t) ? "larry" : "igor",
        box: .init(Double(f.minX), Double(f.minY), Double(f.width), Double(f.height)),
        hidden: stroke.ink.color.cgColor.alpha == 0)
    }
    return out
  }

  /// Every header's fold now, by the same keys: its first stroke, and the strokes its fold holds.
  func reviewFolds() -> [BoardReviewRecorder.FoldNow] {
    guard let markup = paper.markup else { return [] }
    let (strokes, _) = opStrokes(markup)
    let elements = markup.subelements.strokes
    guard strokes.count == elements.count else { return [] }
    var byName: [String: String] = [:]
    for (stroke, element) in zip(strokes, elements) {
      for name in stroke.ids { byName[name] = Self.key(element.elementID) }
    }
    let outline = model.outline(of: strokes)
    return outline.headers.compactMap { header in
      guard let key = header.ids.lazy.compactMap({ byName[$0] }).first else { return nil }
      let own = Set(header.ids.compactMap { byName[$0] })
      let held = Set((header.fold?.own ?? []).compactMap { byName[$0] }).subtracting(own)
      return BoardReviewRecorder.FoldNow(header: key, held: Array(held), folded: outline.isFolded(header))
    }
  }
}
