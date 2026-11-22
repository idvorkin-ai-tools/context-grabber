//  Whether a finger draws on a board on paper while marks show (spec 2026-11-01-whiteboard-shapes-design.md, "Where a
//  finger draws"; stories 354, 1152, 1153; context-grabber-2eml). Pure: the board hands in what shows, the taps and the
//  Pencil, and sets PaperKit's touch from the verdict.

import Foundation

public struct WhiteboardFinger: Equatable, Sendable {
  /// Which rule decided, for the session log's `finger_draws`.
  public enum Why: String, Sendable {
    /// Marks (or his controls) showing: the finger taps and pans.
    case marks
    /// A tap off the marks gave a finger with no Pencil in use its pen back, the marks still showing.
    case tapOff = "tap_off"
    /// Nothing showing: the finger does what it usually does.
    case noMarks = "no_marks"
    /// The Pencil has touched a board this launch: a finger never draws.
    case pencil
  }

  public struct Verdict: Equatable, Sendable {
    /// True: the finger does what it does with nothing showing (it draws, unless the system's "Only Draw with Apple
    /// Pencil" is on). False: it selects, taps and pans, and never draws.
    public var usual: Bool
    public var why: Why

    public init(usual: Bool, why: Why) {
      self.usual = usual
      self.why = why
    }
  }

  public private(set) var marksShowing = false
  /// His marks, not his controls: only a tap with marks showing can give the finger its pen back.
  private var ghostsShowing = false
  public private(set) var tappedOff = false
  public private(set) var pencil: Bool

  public init(pencil: Bool = false) { self.pencil = pencil }

  public var verdict: Verdict {
    if pencil { return Verdict(usual: false, why: .pencil) }
    guard marksShowing else { return Verdict(usual: true, why: .noMarks) }
    return tappedOff ? Verdict(usual: true, why: .tapOff) : Verdict(usual: false, why: .marks)
  }

  /// Marks or his controls showing, or none. No mark left forgets a tap off, so his controls alone, or the next marks,
  /// put the finger back to tapping.
  public mutating func marks(_ showing: Bool, controls: Bool = false) {
    marksShowing = showing || controls
    ghostsShowing = showing
    if !showing { tappedOff = false }
  }

  /// A finger tap while marks show: one reaching no mark and outside his selection gives the finger its pen back. With
  /// only his controls showing a finger keeps tapping (story 846).
  public mutating func tapped(onMark: Bool, onSelection: Bool) {
    guard ghostsShowing, !onMark, !onSelection else { return }
    tappedOff = true
  }

  /// The Pencil touched a board: from now on a finger never draws.
  public mutating func pencilTouched() { pencil = true }
}
