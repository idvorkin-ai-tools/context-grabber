//  Scratch out on paper (spec 2026-11-01-whiteboard-design.md, *Scratch out*; stories 890, 891): the markup's side.
//  `WhiteboardScratchOut` decides; this hands it the new stroke and the ink near it, and makes the markup without what
//  it named. The controller sets that markup with one undo step.

import ContextCore
import Foundation
import PaperKit
import PencilKit

extension PKStroke {
  /// Folded ink (story 847): still on the board, with no colour to see. Scratch out, Keep all and Tidy never touch it.
  var isFolded: Bool { ink.color.cgColor.alpha == 0 }
}

extension PaperMarkup {
  /// A scratch-out's verdict on a stroke just drawn, and the markup without it and the ink it took.
  struct Scratch {
    var outcome: WhiteboardScratchOut.Outcome
    /// The markup before the zigzag: what one undo goes back to.
    var before: PaperMarkup
    /// Without the zigzag and the ink it covered; nil when it isn't a scratch-out.
    var after: PaperMarkup?
    /// The zigzag, board points, and how long it took (ms; nil when not known): what a fold's erase reads (story 903).
    var points: [CGPoint] = []
    var ms: Double?
  }

  /// The verdict on the stroke `key`; nil for a stroke with too few turns to be one. Only the strokes whose frames come
  /// near the zigzag are read point by point, so a big board stays quick.
  func scratch(_ key: String) -> Scratch? {
    let strokes = subelements.strokes
    guard let zigzag = strokes.first(where: { PaperHost.key($0.elementID) == key }) else { return nil }
    let points = zigzag.path.map { $0.location.applying(zigzag.transform) }
    // Most strokes are writing: nothing more is read, or logged, for one with fewer turns than a scratch-out has.
    guard WhiteboardScratchOut.shape(points).reversals >= WhiteboardScratchOut.reversals else { return nil }
    // The Pencil's time along the stroke, in seconds from its start.
    let ms = zigzag.path.last.map { $0.timeOffset * 1000 }
    let near = zigzag.renderFrame.insetBy(dx: -12, dy: -12)
    let ink = strokes.filter {
      $0.elementID != zigzag.elementID && !$0.isFolded && $0.renderFrame.intersects(near)
    }.map { stroke in
      WhiteboardScratchOut.Ink(
        id: PaperHost.key(stroke.elementID), points: stroke.path.map { $0.location.applying(stroke.transform) },
        width: WhiteboardStrokes.width(sizes: stroke.path.map(\.size.width), transform: stroke.transform))
    }
    let outcome = WhiteboardScratchOut.check(points, ms: ms.flatMap { $0 > 0 ? $0 : nil }, over: ink)
    var before = self
    before.subelements.removeElement(for: zigzag.elementID)
    let drawn = ms.flatMap { $0 > 0 ? $0 : nil }
    guard outcome.ok else { return Scratch(outcome: outcome, before: before, after: nil, points: points, ms: drawn) }
    let gone = Set(outcome.gone)
    var after = before
    for stroke in strokes where gone.contains(PaperHost.key(stroke.elementID)) {
      after.subelements.removeElement(for: stroke.elementID)
    }
    return Scratch(outcome: outcome, before: before, after: after, points: points, ms: drawn)
  }
}
