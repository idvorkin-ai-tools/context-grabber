//  A board on paper: whether a finger draws (spec 2026-11-01-whiteboard-shapes-design.md, "Where a finger draws";
//  stories 354, 1152, 1153; context-grabber-2eml). The rule is ContextCore's `WhiteboardFinger`; this sets PaperKit's
//  touch from its verdict and logs each change with the rule that decided it.

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Story 1153: the Pencil has touched a board since the app launched, so a finger never draws on any board.
  static var pencilThisLaunch = LaunchHooks.current.whiteboard.pencilSeen

  /// As the old canvas's `.pencilOnly`, which PaperKit doesn't have: while marks or his controls show, a finger selects
  /// rather than draws, and a tap's selection is put straight back, so a tap leaves nothing.
  func fingerTaps(_ taps: Bool) {
    finger.marks(taps)
    settleFinger()
  }

  /// Story 1152: a finger tap while marks show, on a mark or his selection or neither.
  func fingerTappedWithMarks(onMark: Bool, onSelection: Bool) {
    finger.tapped(onMark: onMark, onSelection: onSelection)
    settleFinger()
  }

  /// Story 1153: the Pencil touching down.
  func pencilTouched() {
    Self.pencilThisLaunch = true
    guard !finger.pencil else { return }
    finger.pencilTouched()
    settleFinger()
  }

  /// PaperKit's touch as the rule has it; a change is logged as `finger_draws`, with which rule decided.
  func settleFinger() {
    if Self.pencilThisLaunch, !finger.pencil { finger.pencilTouched() }
    let usual = fingerUsually ?? (paper.directTouchMode, paper.directTouchAutomaticallyDraws)
    fingerUsually = usual
    let verdict = finger.verdict
    let mode = verdict.usual ? usual.mode : .selection
    let autoDraws = verdict.usual ? usual.autoDraws : false
    showFingerForTests(verdict)
    guard mode != paper.directTouchMode || autoDraws != paper.directTouchAutomaticallyDraws else { return }
    paper.directTouchAutomaticallyDraws = autoDraws
    paper.directTouchMode = mode
    log.event(
      "whiteboard",
      [
        "action": "finger_draws", "board": model.board.id, "on": fingersDraw, "why": verdict.why.rawValue,
        "touch_mode": name(mode), "auto_draws": autoDraws, "pencil_only": UIPencilInteraction.prefersPencilOnlyDrawing,
      ])
  }

  /// `GRABBER_WHITEBOARD_FINGER_LABEL=1`: the verdict as an element a UI test reads (`whiteboard-finger`: *draws* or
  /// *taps*, the rule as its value). XCUITest's finger draws on the simulator whatever PaperKit's touch is set to, so the
  /// ink alone can't show it.
  private func showFingerForTests(_ verdict: WhiteboardFinger.Verdict) {
    guard LaunchHooks.current.whiteboard.fingerLabel, isViewLoaded else { return }
    let id = "whiteboard-finger"
    let label =
      view.subviews.first { $0.accessibilityIdentifier == id } as? UILabel
      ?? {
        let made = UILabel(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        made.accessibilityIdentifier = id
        made.isAccessibilityElement = true
        made.alpha = 0.02
        view.addSubview(made)
        return made
      }()
    label.accessibilityLabel = verdict.usual ? "draws" : "taps"
    label.accessibilityValue = verdict.why.rawValue
  }
}
