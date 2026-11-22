//  Stories 902–905: the eraser across a folded header's "▸ N lines folded", or across the folded header's own ink,
//  erases the whole section and closes up, one Undo named *Erase* (spec 2026-11-16-whiteboard-board-ops-design.md,
//  *Headers fold their sections*; the Cockpit's `erase` with `foldHits`). PaperKit's eraser takes the ink it touches as
//  ever; the fold goes when the touch lifts, worked out on the board as it was when the touch went down. A scratch-out
//  over the marker or the folded header line takes the fold the same way, one Undo.

import ContextCore
import PaperKit
import PencilKit
import UIKit

/// An eraser touch on a board with a fold: which touch, the outline when it went down, and its path in board points.
struct FoldErasing {
  var touch: ObjectIdentifier
  var outline: BoardOutline
  var path: [CGPoint]
}

extension PaperBoardController {
  /// A touch that erases (the Pencil, or a finger while fingers draw) going down with the eraser on a folded board.
  func foldEraserDown(_ touch: UITouch) {
    guard paper.drawingTool is PKEraserTool, touch.type == .pencil || fingersDraw else { return }
    foldErasing = nil
    guard model.editable, model.headers.contains(where: { $0.fold != nil }), let markup = paper.markup else { return }
    let outline = model.outline(of: model.opStrokes(markup.inkDrawing.strokes).strokes)
    guard !outline.markers.isEmpty else { return }
    foldErasing = FoldErasing(
      touch: ObjectIdentifier(touch), outline: outline, path: [lines.columnPoint(of: touch.location(in: lines))])
  }

  func foldEraserMoved(_ touch: UITouch) {
    guard foldErasing?.touch == ObjectIdentifier(touch) else { return }
    foldErasing?.path.append(lines.columnPoint(of: touch.location(in: lines)))
  }

  /// The eraser touch coming up, or called off (context-grabber-0m2d): a called-off stroke takes a fold only where
  /// PaperKit's eraser took the header's ink anyway.
  func foldEraserLifted(_ touch: UITouch) {
    let cancelled = touch.phase == .cancelled
    if !cancelled { foldEraserMoved(touch) }
    guard let erasing = foldErasing, erasing.touch == ObjectIdentifier(touch) else { return }
    foldErasing = nil
    let hits = erasing.outline.foldHits(along: erasing.path, onHeader: true)
    guard !hits.isEmpty else { return }
    // A turn later: PaperKit's own erase of the header's ink is on the markup by then.
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard cancelled else {
        self.eraseFolds(hits, via: "eraser", path: erasing.path.count)
        return
      }
      let live = self.paper.markup.map { self.model.outline(of: self.model.opStrokes($0.inkDrawing.strokes).strokes) }
      // No markup to read: the header's ink can't be seen gone, so nothing is taken.
      let taken = live.map { erasing.outline.foldsTaken(hits, cancelled: true, live: $0.liveNames) } ?? []
      // What a called-off eraser stroke did to the header's ink, so the iPad's log says whether PaperKit keeps it.
      self.log.event(
        "board_outline",
        [
          "action": "erase_fold_cancelled", "board": self.model.board.id, "folds": hits.count, "taken": taken.count,
          "path": erasing.path.count, "markup": live != nil,
        ])
      if !taken.isEmpty { self.eraseFolds(taken, via: "eraser_cancelled", path: erasing.path.count) }
    }
  }

  /// Story 905: a scratch-out over a fold's marker or its folded header line takes the whole fold, and the other ink it
  /// covered goes with it, one Undo back to before the zigzag (the web board's `scratchOut` with `foldHits`). False,
  /// and scratch-out goes on as ever, when the zigzag crosses no fold.
  func scratchTakesFolds(_ scratch: PaperMarkup.Scratch, zigzag key: String) -> Bool {
    guard model.editable, model.headers.contains(where: { $0.fold != nil }),
      WhiteboardScratchOut.isZigzag(scratch.points, ms: scratch.ms)
    else { return false }
    let outline = model.outline(of: model.opStrokes(scratch.before.inkDrawing.strokes).strokes)
    let hits = outline.foldHits(along: scratch.points, reach: 4, onHeader: true)
    guard !hits.isEmpty else { return false }
    // The zigzag's other ink, as scratch-out takes it; the header's own goes with its fold either way.
    let gone = Set(scratch.outcome.ok ? scratch.outcome.gone : [])
    Task { @MainActor [weak self] in
      guard let self else { return }
      // PaperKit's own step for the zigzag goes first, as for an ordinary scratch-out, so one Undo is the lot.
      let taken = self.takeBackZigzag(key, before: scratch.before, why: "scratch_fold")
      let took = self.eraseFolds(
        hits, via: "scratch", path: scratch.points.count, on: taken.base.without(gone), undoTo: taken.base,
        extra: ["undid_zigzag": taken.undid, "strokes_too": gone.count])
      // #1015: what PaperKit holds once the fold's markup is set, and a beat later, as for an ordinary scratch-out (#999).
      guard took else { return }
      let went = Set(scratch.before.strokeFrames.keys).union([key]).subtracting(self.putKeys)
      self.scratched = went
      var event: [String: Any] = [
        "action": "scratch_fold", "board": self.model.board.id, "base": taken.how, "wanted": self.putKeys.count,
      ]
      event.merge(self.heldAfterScratch(went)) { $1 }
      self.log.event("whiteboard", event)
      try? await Task.sleep(for: .seconds(1))
      var later: [String: Any] = ["action": "scratch_held", "board": self.model.board.id, "fold": true]
      later.merge(self.heldAfterScratch(went)) { $1 }
      self.log.event("whiteboard", later)
    }
    return true
  }

  /// The folds erased on the markup as one Undo, the ink below closed up; the headers kept so the Undo brings them
  /// back folded.
  /// ponytail: across the header's own ink PaperKit's eraser has already taken those strokes in a step of its own, so
  /// that way back is two Undos (the marker's, and a scratch-out's, is one). One Undo there means erasing the header's
  /// ink ourselves before PaperKit's eraser reaches it, which PaperKit has no hook for.
  @discardableResult
  private func eraseFolds(
    _ hits: [BoardOutline.FoldHit], via: String, path: Int, on base: PaperMarkup? = nil, undoTo: PaperMarkup? = nil,
    extra: [String: Any] = [:]
  ) -> Bool {
    let took = changeOutline(via == "scratch" ? "Scratch out" : "Erase", on: base, undoTo: undoTo) {
      $0.eraseFolds(hits)
    }
    var event: [String: Any] = [
      "action": "erase_fold", "board": model.board.id, "via": via, "folds": hits.count,
      "headers": hits.reduce(0) { $0 + $1.headers.count }, "strokes": hits.reduce(0) { $0 + $1.names.count },
      "path": path, "took": took, "can_undo": paper.undoManager?.canUndo ?? false,
      "undo_name": paper.undoManager?.undoActionName ?? "",
    ]
    event.merge(extra) { $1 }
    log.event("board_outline", event)
    return took
  }
}
