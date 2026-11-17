//  Stories 902, 903: the eraser across a folded header's "▸ N lines folded", or across the folded header's own ink,
//  erases the whole section and closes up, one Undo named *Erase* (spec 2026-11-16-whiteboard-board-ops-design.md,
//  *Headers fold their sections*; the Cockpit's `erase` with `foldHits`). PaperKit's eraser takes the ink it touches as
//  ever; the fold goes when the touch lifts, worked out on the board as it was when the touch went down.

import ContextCore
import PencilKit
import UIKit

/// An eraser touch on a board with a fold: the outline when it went down, and its path in board points.
struct FoldErasing {
  var outline: BoardOutline
  var path: [CGPoint]
}

extension PaperBoardController {
  /// A touch that erases (the Pencil, or a finger while fingers draw) going down with the eraser on a folded board.
  func foldEraserDown(_ touch: UITouch) {
    foldErasing = nil
    guard paper.drawingTool is PKEraserTool, touch.type == .pencil || fingersDraw, model.editable,
      model.headers.contains(where: { $0.fold != nil }), let markup = paper.markup
    else { return }
    let outline = model.outline(of: model.opStrokes(markup.inkDrawing.strokes).strokes)
    guard !outline.markers.isEmpty else { return }
    foldErasing = FoldErasing(outline: outline, path: [lines.columnPoint(of: touch.location(in: lines))])
  }

  func foldEraserMoved(_ touch: UITouch) {
    guard foldErasing != nil else { return }
    foldErasing?.path.append(lines.columnPoint(of: touch.location(in: lines)))
  }

  func foldEraserLifted(_ touch: UITouch) {
    foldEraserMoved(touch)
    guard let erasing = foldErasing else { return }
    foldErasing = nil
    let hits = erasing.outline.foldHits(along: erasing.path, onHeader: true)
    guard !hits.isEmpty else { return }
    // A turn later: PaperKit's own erase of the header's ink is on the markup by then.
    Task { @MainActor [weak self] in self?.eraseFolds(hits, via: "eraser", path: erasing.path.count) }
  }

  /// Scratch-out's way in: a scratch over a fold's marker or its folded header line takes the whole fold. True when it
  /// took one; the scratch's other ink is erased as scratch-out erases it.
  /// ponytail: nothing calls this yet. Scratch-out is being built on its own branch (slot 1); once it merges, its
  /// recogniser calls `eraseFolds(crossing: zigzag, via: "scratch")` with the zigzag in board points before erasing what
  /// it covers, and skips its own erase of the header row when this returns true.
  @discardableResult
  func eraseFolds(crossing path: [CGPoint], via: String) -> Bool {
    guard model.editable, let markup = paper.markup else { return false }
    let outline = model.outline(of: model.opStrokes(markup.inkDrawing.strokes).strokes)
    let hits = outline.foldHits(along: path, reach: 4, onHeader: true)
    return !hits.isEmpty && eraseFolds(hits, via: via, path: path.count)
  }

  /// The folds erased on the markup as one Undo, the ink below closed up; the headers kept so the Undo brings them
  /// back folded.
  /// ponytail: across the header's own ink PaperKit's eraser has already taken those strokes in a step of its own, so
  /// that way back is two Undos (the marker's is one). One Undo there means erasing the header's ink ourselves before
  /// PaperKit's eraser reaches it, which PaperKit has no hook for.
  @discardableResult
  private func eraseFolds(_ hits: [BoardOutline.FoldHit], via: String, path: Int) -> Bool {
    let took = changeOutline("Erase") { $0.eraseFolds(hits) }
    log.event(
      "board_outline",
      [
        "action": "erase_fold", "board": model.board.id, "via": via, "folds": hits.count,
        "headers": hits.reduce(0) { $0 + $1.headers.count }, "strokes": hits.reduce(0) { $0 + $1.names.count },
        "path": path, "took": took, "can_undo": paper.undoManager?.canUndo ?? false,
        "undo_name": paper.undoManager?.undoActionName ?? "",
      ])
    return took
  }
}
