//  A board on paper: ink dropped onto writing pushes it down (stories 973–975, 979, 969, 1172). Moved from PaperBoard.swift
//  and widened by story 1172 (bead context-grabber-9uj2): a drop by hand is one however it was picked up, a lasso, a tap on
//  a group, or a drag from PaperKit's handwriting view with nothing selected.

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Stories 973–975, 1172: ink dragged onto ink pushes what is below down clear of it, as a paste's room does, and the
  /// drag and the push are one Undo named *Move*. Only a drag by hand: an Undo or Redo never pushes, nor does the system
  /// rearranging handwriting, nor a move the owners-apart rule puts right (`split`, story 1145).
  func pushesOnMove(_ change: PaperProbe.InkChange, markup: PaperMarkup, undo: UndoManager?, split: Bool) {
    guard drawsHere, !change.moved.isEmpty, change.added.isEmpty, change.removed.isEmpty,
      undo?.isUndoing != true, undo?.isRedoing != true
    else { return }
    // Story 1201: a drag inside a small selection that PaperKit's handle took as a stretch is moved on the lift instead.
    if resizeAsMove(change, undo: undo) { return }
    let selected = Set(paper.selection.map(Self.key)).union(run?.heldAtStart ?? [])
    let pickup = PaperProbe.pickup(change.moved, selected: selected, inTouch: run != nil, split: split)
    let movedKeys = Set(change.moved.map(\.id))
    let frames = markup.strokeFrames
    var block = movedKeys.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    let back = Dictionary(uniqueKeysWithValues: change.moved.map { ($0.id, $0) })
    var event: [String: Any] = [
      "action": "paper_drop", "board": model.board.id, "strokes": movedKeys.count, "at": rect(block),
      "pickup": pickup.rawValue, "selected": paper.selection.count,
    ]
    var from = movedKeys.compactMap { key in
      frames[key].flatMap { box in back[key].map { box.offsetBy(dx: -$0.dx, dy: -$0.dy) } }
    }.reduce(CGRect.null) { $0.union($1) }
    event["from"] = rect(from)
    guard pickup.isDrop else {
      // Story 1172: every move by hand says why it opened no room; a move with no touch down is the system's, unlogged.
      if pickup != .notInTouch {
        event["room"] = false
        log.event("whiteboard", event)
      }
      return
    }
    let (strokes, hashes) = opStrokes(markup)
    let elements = markup.subelements.strokes
    let dragged = Set(elements.indices.filter { movedKeys.contains(Self.key(elements[$0].elementID)) })
    // Story 998: a drag with nothing selected that took part of a group brings the rest along, by the drag's offset.
    let carry =
      pickup == .dragged
      ? groupCarry(change.moved, strokes: strokes, keys: elements.map { Self.key($0.elementID) }) : nil
    let carried = carry?.indices ?? []
    if let carry {
      let boxes = carried.compactMap { frames[Self.key(elements[$0].elementID)] }
      block = boxes.reduce(block) { $0.union($1.offsetBy(dx: carry.by.dx, dy: carry.by.dy)) }
      from = boxes.reduce(from) { $0.union($1) }
      event.merge(["carried": carried.count, "carried_groups": carry.groups, "at": rect(block), "from": rect(from)]) {
        $1
      }
    }
    let whole = dragged.union(carried)
    let tags = model.outline(of: strokes).tags
    let others = strokes.indices.filter { !whole.contains($0) }.map { strokes[$0] }
    let ink = BoardOps.shownBoxes(strokes: others, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    let push = BoardRoom.drop(block, from: from, among: ink)
    guard push != nil || !carried.isEmpty else {
      event["room"] = false
      log.event("whiteboard", event)
      return
    }
    var plan =
      push.map {
        BoardOps.plan(
          [.translateBelow(y: $0.cut, dy: $0.dy)], strokes: strokes, texts: model.texts, metas: model.strokeMeta,
          folds: tags, pages: pages, board: board)
      } ?? BoardOps.Plan(pagesBefore: pages, pagesAfter: pages)
    // What he dropped stays where he let go of it, and the rest of its group goes as far.
    for index in dragged { plan.offsets[index] = nil }
    for index in carried { plan.offsets[index] = carry?.by }
    let pushedKeys = plan.offsets.keys.filter { elements.indices.contains($0) && !carried.contains($0) }
      .map { Self.key(elements[$0].elementID) }
    event.merge(["room": push != nil, "moved": plan.moved]) { $1 }
    if let push { event.merge(["cut": Double(push.cut), "dy": Double(push.dy)]) { $1 } }
    // Not from inside PaperKit's own callback: its step for the drag is taken back, and one step for both goes on.
    Task { @MainActor [weak self] in
      guard let self else { return }
      // PaperKit's drag is still going while the finger is down: the push waits for the lift, up to 3 s.
      var waited = 0
      while self.run != nil, waited < 60 {
        try? await Task.sleep(for: .milliseconds(50))
        waited += 1
      }
      event["waited_ms"] = waited * 50
      let now = self.paper.markup ?? markup
      let nowIsDrop = Self.close(now.strokeFrames, markup.strokeFrames)
      event["now_is_drop"] = nowIsDrop
      let keys = elements.map { Self.key($0.elementID) }
      guard nowIsDrop, now.subelements.strokes.map({ Self.key($0.elementID) }) == keys else {
        event["room"] = false
        event["stale"] = true
        self.log.event("whiteboard", event)
        return
      }
      // The board before the drag, as it is after the lift: the dragged strokes back where they were.
      var before = now
      for element in now.subelements.strokes {
        guard let move = back[Self.key(element.elementID)] else { continue }
        var stroke = element
        stroke.applyTransform(CGAffineTransform(translationX: -move.dx, y: -move.dy))
        _ = before.subelements.updateOrAppend(stroke)
      }
      let tookBack = self.quietly { self.takeBackPaperKitsStep(why: "drop") }
      let undidDrag = self.paper.markup.map { Self.close($0.strokeFrames, before.strokeFrames) } ?? false
      event["took_back"] = tookBack
      event["undid_drag"] = undidDrag
      // The step taken back wasn't the drag's: it goes back on, as the owners-apart rule does (story 1145).
      if tookBack, !undidDrag { self.quietly { self.paper.undoManager?.redo() } }
      let framesBefore = self.inkFrames
      self.registerStepBack(to: before, named: "Move")
      // The change goes on the strokes PaperKit holds after taking its step back, not on its copies from before: a set
      // of those dropped the push (the simulator, 2026-11-22: the line stayed, the dragged strokes landed). The drag is
      // done again by its own offsets, and the push with it.
      var start = now
      var onLive = plan
      event["on_live"] = false
      if undidDrag, let live = self.paper.markup,
        live.subelements.strokes.map({ Self.key($0.elementID) }) == keys
      {
        start = live
        event["on_live"] = true
        for index in dragged {
          guard let move = back[Self.key(live.subelements.strokes[index].elementID)] else { continue }
          onLive.offsets[index] = CGVector(dx: move.dx, dy: move.dy)
        }
      }
      guard let (held, _, _) = self.put(onLive, on: start, hashes: hashes, named: "Move", stepBack: false) else {
        event["failed"] = true
        self.log.event("whiteboard", event)
        return
      }
      self.model.stepped(held.inkDrawing)
      self.noteInk(held, since: framesBefore, report: true)
      event["pages"] = self.pages
      event["undo_name"] = self.paper.undoManager?.undoActionName ?? ""
      event["pushed"] = pushedKeys.count
      guard let push else {
        self.log.event("whiteboard", event)
        return
      }
      event["pushed_now"] = self.pushedStill(pushedKeys, from: markup, dy: push.dy)
      self.log.event("whiteboard", event)
      // Whether the push is still there once the touch is over: PaperKit's drag ends after this runs.
      try? await Task.sleep(for: .seconds(1))
      self.log.event(
        "whiteboard",
        [
          "action": "paper_drop_after", "board": self.model.board.id, "pushed": pushedKeys.count,
          "pushed_now": self.pushedStill(pushedKeys, from: markup, dy: push.dy), "in_touch": self.run != nil,
          "undo_name": self.paper.undoManager?.undoActionName ?? "",
        ])
    }
  }

  /// How many of `keys` sit `dy` below where they were in `before`, on the paper now.
  private func pushedStill(_ keys: [String], from before: PaperMarkup, dy: CGFloat) -> Int {
    let was = before.strokeFrames
    let now = paper.markup?.strokeFrames ?? [:]
    return keys.filter { key in
      guard let a = was[key], let b = now[key] else { return false }
      return abs(b.minY - a.minY - dy) < 1
    }.count
  }
}
