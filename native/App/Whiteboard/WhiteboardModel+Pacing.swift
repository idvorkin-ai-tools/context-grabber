//  Pen pacing: the pause after the pen lifts (the VAD) that cues Claude, and the hand hovering.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts.
  func beganDrawing() {
    penWent(down: true)
    vad.down(at: .now)
    // Story 894: writing again makes the picture of a turn still out stale.
    if turns.penCancelsTurn() {
      claudeReading?.cancel()
      log.event("whiteboard", ["action": "turn_cancelled", "board": board.id, "why": "pen_down"])
    }
    if turns.toolWentDown() {
      log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "away", "why": "drew"])
    }
    cancelPause()
  }

  /// A stroke landed (drawn or pasted): Claude's pause starts, or with Ghosts off the bar says no one is watching and the
  /// log says so once, at the first unwatched stroke (stories 1114, 1116).
  func strokeLanded() {
    let unwatchedBefore = turns.writingUnwatched
    if turns.stroked() {
      startPause()
    } else if !unwatchedBefore {
      log.event("whiteboard", ["action": "pause_skipped", "board": board.id, "why": "ghosts_off"])
    }
  }

  func endedDrawing() {
    penWent(down: false)
    vad.lifted(at: .now)
    if turns.toolLifted() { startPause() }
  }

  /// A pause still waiting is forgotten; `turns` has made an answer on its way stale.
  func cancelPause() {
    pauseTask?.cancel()
    pauseTask = nil
    awayTask?.cancel()
    vad.pauseOver()
  }

  /// Story 892: the pause waits as long as his rhythm says, from 1.5 to 5 s.
  func startPause() {
    let started = ContinuousClock.now
    let pause = vad.pauseStarted(at: started)
    log.event(
      "whiteboard", ["action": "vad", "board": board.id, "ms": pause.ms, "cue": pause.cue, "median": pause.median])
    waitPause(pause.duration, from: started)
    if vad.hoverSeen { lookForTheHand() }
  }

  private func waitPause(_ span: Duration, from started: ContinuousClock.Instant) {
    pauseTask?.cancel()
    pauseTask = Task { [weak self] in
      try? await Task.sleep(for: span)
      guard !Task.isCancelled, let self else { return }
      self.pauseTask = nil
      self.awayTask?.cancel()
      self.vad.pauseOver()
      // Story 661: how long the pause really waited, the timer's own lateness included.
      if self.turns.pauseEnded() { await self.turn(.claude, paused: started.duration(to: .now)) }
    }
  }

  /// Story 893: an end-of-thought cue cuts the pause to the floor, counted from the lift.
  private func cue(_ name: String, left: Duration) {
    guard pauseTask != nil else { return }
    log.event(
      "whiteboard", ["action": "vad", "board": board.id, "cue": name, "left_ms": WhiteboardTimings.ms(left) ?? 0])
    waitPause(left, from: .now - (WhiteboardWritingVad.floor - left))
  }

  /// The hovering Pencil, in board points: seen, and maybe back at the start of a new line (story 893).
  func hovered(at point: CGPoint) {
    if let left = vad.hovered(at: point, now: .now) { cue("new line", left: left) }
    if pauseTask != nil { lookForTheHand() }
  }

  /// A second with no Pencil near the paper, on an iPad whose hover shows it: his hand has left.
  private func lookForTheHand() {
    awayTask?.cancel()
    awayTask = Task { [weak self] in
      try? await Task.sleep(for: WhiteboardWritingVad.awayAfter)
      guard !Task.isCancelled, let self, let left = self.vad.lookedForTheHand(now: .now) else { return }
      self.cue("hand away", left: left)
    }
  }
}
