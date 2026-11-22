//  A board on paper: ink dropped onto writing pushes it down (stories 973–975, 979, 969, 929). Moved from PaperBoard.swift
//  and widened by story 929 (bead context-grabber-9uj2): a drop by hand is one however it was picked up, a lasso, a tap on
//  a group, or a drag from PaperKit's handwriting view with nothing selected.

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Stories 973–975, 929: ink dragged onto ink pushes what is below down clear of it, as a paste's room does, and the
  /// drag and the push are one Undo named *Move*. Only a drag by hand: an Undo or Redo never pushes, nor does the system
  /// rearranging handwriting, nor a move the owners-apart rule puts right (`split`, story 1145).
  func pushesOnMove(_ change: PaperProbe.InkChange, markup: PaperMarkup, undo: UndoManager?, split: Bool) {
    guard drawsHere, !change.moved.isEmpty, change.added.isEmpty, change.removed.isEmpty,
      undo?.isUndoing != true, undo?.isRedoing != true
    else { return }
    let selected = Set(paper.selection.map(Self.key)).union(run?.heldAtStart ?? [])
    let pickup = PaperProbe.pickup(change.moved, selected: selected, inTouch: run != nil, split: split)
    let movedKeys = Set(change.moved.map(\.id))
    let frames = markup.strokeFrames
    let block = movedKeys.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    let back = Dictionary(uniqueKeysWithValues: change.moved.map { ($0.id, $0) })
    var event: [String: Any] = [
      "action": "paper_drop", "board": model.board.id, "strokes": movedKeys.count, "at": rect(block),
      "pickup": pickup.rawValue, "selected": paper.selection.count,
    ]
    let from = movedKeys.compactMap { key in
      frames[key].flatMap { box in back[key].map { box.offsetBy(dx: -$0.dx, dy: -$0.dy) } }
    }.reduce(CGRect.null) { $0.union($1) }
    event["from"] = rect(from)
    guard pickup.isDrop else {
      // Story 929: every move by hand says why it opened no room; a move with no touch down is the system's, unlogged.
      if pickup != .notInTouch {
        event["room"] = false
        log.event("whiteboard", event)
      }
      return
    }
    let (strokes, hashes) = opStrokes(markup)
    let elements = markup.subelements.strokes
    let dragged = Set(elements.indices.filter { movedKeys.contains(Self.key(elements[$0].elementID)) })
    let tags = model.outline(of: strokes).tags
    let others = strokes.indices.filter { !dragged.contains($0) }.map { strokes[$0] }
    let ink = BoardOps.shownBoxes(strokes: others, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    guard let push = BoardRoom.drop(block, from: from, among: ink) else {
      event["room"] = false
      log.event("whiteboard", event)
      return
    }
    var plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: tags, pages: pages, board: board)
    // What he dropped stays where he let go of it.
    for index in dragged { plan.offsets[index] = nil }
    // The board before the drag: the dragged strokes back where they were.
    var before = markup
    for element in elements {
      guard let move = back[Self.key(element.elementID)] else { continue }
      var stroke = element
      stroke.applyTransform(CGAffineTransform(translationX: -move.dx, y: -move.dy))
      _ = before.subelements.updateOrAppend(stroke)
    }
    event.merge(["room": true, "cut": Double(push.cut), "dy": Double(push.dy), "moved": plan.moved]) { $1 }
    // Not from inside PaperKit's own callback: its step for the drag is taken back, and one step for both goes on.
    Task { @MainActor [weak self] in
      guard let self else { return }
      let tookBack = self.quietly { self.takeBackPaperKitsStep(why: "drop") }
      let undidDrag = self.paper.markup.map { Self.close($0.strokeFrames, before.strokeFrames) } ?? false
      event["took_back"] = tookBack
      event["undid_drag"] = undidDrag
      // The step taken back wasn't the drag's: it goes back on, as the owners-apart rule does (story 1145).
      if tookBack, !undidDrag { self.quietly { self.paper.undoManager?.redo() } }
      let framesBefore = self.inkFrames
      self.registerStepBack(to: before, named: "Move")
      guard let (held, _, _) = self.put(plan, on: markup, hashes: hashes, named: "Move", stepBack: false) else {
        event["failed"] = true
        self.log.event("whiteboard", event)
        return
      }
      self.model.stepped(held.inkDrawing)
      self.noteInk(held, since: framesBefore, report: true)
      event["pages"] = self.pages
      event["undo_name"] = self.paper.undoManager?.undoActionName ?? ""
      self.log.event("whiteboard", event)
    }
  }
}
