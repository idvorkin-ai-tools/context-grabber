//  A board on paper: the ghosts on the sheet, where the chosen mark sits, a finger that taps while they show, the dot
//  PaperKit draws for that tap taken back, and the scratch-out's hookup. Moved from PaperBoard.swift as it was
//  (context-grabber-fz4x).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// The ghosts on the sheet, and a finger that taps while they show.
  func show(_ ghosts: [Ghost]) {
    Task { @MainActor [weak self] in self?.showChoice() }
    guard lines.ghostLayers.show(ghosts) else { return }
    fingerTaps(!ghosts.isEmpty || !model.overlays.list.isEmpty)
    let drawn = ghosts.flatMap(\.lines)
    log.event(
      "whiteboard",
      [
        "action": "paper_ghosts", "board": model.board.id, "count": ghosts.count,
        // #941: how many of each kind show, so a mark that never drew is told from one that can't be tapped.
        "kinds": Dictionary(ghosts.map { ($0.kind.rawValue, 1) }, uniquingKeysWith: +),
        "past_side": board.reachesPastSide(drawn), "pages": pages, "visible": rect(paper.contentVisibleFrame),
        "sheet": rect(lines.bounds),
        "screen_scale": Double(screenScale),
      ])
    checkSeat()
  }

  /// Where the chosen mark is on screen now, for its Keep and Dismiss. The board's points map to the view's by a scale and
  /// a shift, so two corners place the whole box.
  func showChoice() {
    var frame: CGRect?
    if let ghost = model.chosen {
      let box = WhiteboardMarkChoice.bounds(ghost.lines)
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    guard frame != choiceFrame else { return }
    choiceFrame = frame
    log.event(
      "whiteboard",
      [
        "action": "mark_buttons", "board": model.board.id, "chosen": model.chosen != nil,
        "frame": frame.map { rect($0) } ?? [], "view": rect(view.bounds),
      ])
  }

  /// As the old canvas's `.pencilOnly`, which PaperKit doesn't have: a finger selects rather than draws, and a tap's
  /// selection is put straight back, so a tap leaves nothing.
  func fingerTaps(_ taps: Bool) {
    if taps, fingerUsually == nil {
      fingerUsually = (paper.directTouchMode, paper.directTouchAutomaticallyDraws)
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .selection
    } else if !taps, let usual = fingerUsually {
      fingerUsually = nil
      paper.directTouchMode = usual.mode
      paper.directTouchAutomaticallyDraws = usual.autoDraws
    }
  }

  /// Where the sheet has a ghost against where the visible frame says it should be, in screen points.
  func checkSeat() {
    guard let point = model.ghosts.first?.lines.first?.first else { return }
    let visible = paper.contentVisibleFrame
    let onSheet = lines.convert(lines.spot(of: point), to: view)
    let scale = screenScale
    let framed = CGPoint(x: (point.x - visible.minX) * scale, y: (point.y - visible.minY) * scale)
    seat.worst = max(seat.worst, hypot(onSheet.x - framed.x, onSheet.y - framed.y))
    seat.checks += 1
  }

  /// Stories 616, 825 (#883): a finger tap while marks show draws no dot. PaperKit draws one at the tap all the same, a
  /// few tenths of a second after the lift, with a finger set not to draw; its own undo takes it back, so the stack holds
  /// no step for it, and the board never sees it: no stroke for Claude to answer, whose new marks would put the chosen
  /// one's Keep and Dismiss away.
  /// ponytail: the dot is undone once it has landed, which leaves it as Redo until the next step; stopping PaperKit
  /// drawing it is the upgrade, should a setting ever do that.
  func takesBackTapDot(_ change: PaperProbe.InkChange, frames: [String: CGRect]) -> Bool {
    guard let tap = ghostTap, change.removed.isEmpty, change.moved.isEmpty else { return false }
    let since = CACurrentMediaTime() - tap.time
    let added = change.added.compactMap { frames[$0] }
    guard PaperProbe.isTapDot(added: added, tap: tap.at, secondsSince: since, zoom: screenScale, within: tap.within)
    else { return false }
    ghostTap = nil
    let dot = change.added
    Task { @MainActor [weak self] in
      guard let self else { return }
      let undo = self.paper.undoManager
      let before = self.paper.markup?.strokeFrames ?? [:]
      let could = self.takeBackPaperKitsStep(why: "tap_dot")
      let wanted = before.filter { !dot.contains($0.key) }
      let gone = could && PaperProbe.inkChange(before: wanted, after: self.paper.markup?.strokeFrames ?? [:]).isEmpty
      if !gone {
        if could { undo?.redo() }
        if let markup = self.paper.markup { self.model.changed(markup.inkDrawing) }
      }
      self.log.event(
        "whiteboard",
        [
          "action": "paper_tap_dot", "board": self.model.board.id, "at": self.point(tap.at),
          "dot": self.rect(added.first ?? .null), "ms": self.ms(since), "could_undo": could, "gone": gone,
          "strokes": self.inkFrames.count,
        ])
    }
    return true
  }

  /// Stories 890, 891: a fast zigzag over ink takes it and itself away, one undo bringing the ink back. PaperKit's own
  /// step for the zigzag is undone first, as for the tap's dot, so the stack holds only the scratch-out's.
  func scratchesOut(_ change: PaperProbe.InkChange, _ markup: PaperMarkup) -> Bool {
    // An Undo or Redo that brings a stroke back is never a new zigzag: Redo brings back one that found nothing (#1000).
    let undo = paper.undoManager
    guard drawsHere, undo?.isUndoing != true, undo?.isRedoing != true, change.added.count == 1, change.removed.isEmpty,
      change.moved.isEmpty, let key = change.added.first,
      let scratch = markup.scratch(key, asZigzag: LaunchHooks.current.whiteboard.zigzagAt == inkFrames.count)
    else { return false }
    let outcome = scratch.outcome
    var event: [String: Any] = [
      "action": "scratch", "board": model.board.id, "fired": outcome.ok, "reversals": outcome.reversals,
      "strokes": outcome.gone.count, "path": BoardTouchPath.encode(scratch.samples),
    ]
    if let speed = outcome.speed { event["speed"] = speed }
    if let why = outcome.why { event["why"] = why }
    // Story 905: over a fold's marker or its folded header line, the whole section goes with what else it covered.
    if scratchTakesFolds(scratch, zigzag: key) {
      flashScratched(Set(outcome.gone + [key]), from: markup)
      return true
    }
    guard scratch.after != nil else {
      // Stories 1051, 1052 (#1000): a zigzag over nothing goes, with a word; writing that only looks like one stays ink.
      if outcome.findsNothing, let frame = markup.strokeFrames[key] {
        scratchFoundNothing(key, frame: frame, event: event)
        return true
      }
      log.event("whiteboard", event)
      return false
    }
    // Story 1050 (#1000): the struck ink flashes and fades where it was, read before it goes.
    flashScratched(Set(outcome.gone + [key]), from: markup)
    Task { @MainActor [weak self] in
      guard let self else { return }
      let taken = self.takeBackZigzag(key, before: scratch.before, why: "scratch")
      event["undid_zigzag"] = taken.undid
      event["base"] = taken.how
      let gone = Set(scratch.outcome.gone + [key])
      let before = taken.base
      let after = before.without(gone)
      self.setMarkup(after, stepBack: before)
      let framesBefore = self.inkFrames
      self.inkFrames = after.strokeFrames
      self.model.stepped(after.inkDrawing)
      self.noteInk(after, since: framesBefore, report: true)
      // #999: what PaperKit holds once the markup is set, and a beat later: on the iPad the scratched ink came back.
      self.scratched = gone
      event["wanted"] = after.strokeFrames.count
      event.merge(self.heldAfterScratch(gone)) { $1 }
      self.log.event("whiteboard", event)
      self.redrawSoon()
      try? await Task.sleep(for: .seconds(1))
      var later: [String: Any] = ["action": "scratch_held", "board": self.model.board.id]
      later.merge(self.heldAfterScratch(gone)) { $1 }
      self.log.event("whiteboard", later)
    }
    return true
  }

  /// PaperKit's own step for a zigzag taken back, and the markup a scratch-out builds on, without the zigzag. The step
  /// undone may not have been the zigzag's (#966): one that took other ink is put back, and the zigzag's stays beneath,
  /// as the margin hold's does. #999, #1015: the base is the markup PaperKit holds after that, never one made before it
  /// from the markup the zigzag's change handed over, which PaperKit refused whole, keeping the scratched ink.
  func takeBackZigzag(
    _ key: String, before: PaperMarkup, why: String
  ) -> (base: PaperMarkup, undid: Bool, how: String) {
    let could = takeBackPaperKitsStep(why: why)
    let undid = paper.markup?.strokeFrames[key] == nil
    let held = Set((paper.markup?.strokeFrames ?? [:]).keys).subtracting([key])
    let redone = WhiteboardScratchOut.redoTakeBack(
      could: could, zigzagHeld: !undid, held: held, before: Set(before.strokeFrames.keys))
    if redone { paper.undoManager?.redo() }
    return ((paper.markup ?? before).without([key]), undid, redone ? "redone" : could ? "taken_back" : "untouched")
  }

  /// #999: how many strokes PaperKit's markup holds, and how many of a scratch-out's (`gone`, the zigzag's too) are among
  /// them: none, once it has worked.
  func heldAfterScratch(_ gone: Set<String>) -> [String: Any] {
    let held = paper.markup?.strokeFrames ?? [:]
    return ["held": held.count, "held_gone": held.keys.filter(gone.contains).count, "board_strokes": inkFrames.count]
  }
}
