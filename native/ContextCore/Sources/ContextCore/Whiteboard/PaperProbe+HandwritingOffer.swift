//  Stories 945, 946 (bead context-grabber-4nnh): the board never offers to convert handwriting to text, and a tapped group
//  stays selected. On the iPad a selection of handwriting brought up the system's handwriting popover a second later,
//  and the selection went with no callback: the drag that followed moved nothing. iPadOS has no switch for the offer.

import Foundation

extension PaperProbe {
  /// Story 945: a controller presented over the board is the system's handwriting offer when it is a popover pointed at
  /// the paper and either drawn by another process or one of the system's text-offer controllers (`_UICampo…` on the
  /// iPad, 2026-11-22). The board presents no popover of its own at the paper.
  public static func isHandwritingOffer(popover: Bool, pointsAtPaper: Bool, remote: Bool, kind: String) -> Bool {
    popover && pointsAtPaper && (remote || kind.contains("Campo"))
  }

  /// Story 946: what became of a tapped group's selection, looked at while the tap's window is open.
  public enum GroupTapLoss: String, Equatable, Sendable {
    /// Still the whole group.
    case held
    /// Gone, with no touch since: the board puts it back.
    case putBack = "put_back"
    /// Gone again after `groupTapPutBacks` tries: left as it is.
    case givenUp = "given_up"
    /// The window closed, an Undo is running, the group has no strokes, or something else is selected: not the board's.
    case notOurs = "not_ours"
  }

  /// Story 946: how many times one tap's selection is put back.
  public static let groupTapPutBacks = 3

  /// Story 946: `selected` strokes selected now, `wanted` in the group, `same` when the selection is the group's;
  /// `live` while the tap's window is open (no touch since, not timed out). Only an empty selection is put back: one
  /// Igor or PaperKit changed to something else is never fought here.
  public static func groupTapLoss(
    selected: Int, wanted: Int, same: Bool, live: Bool, undoing: Bool, putBacks: Int
  ) -> GroupTapLoss {
    guard live, !undoing, wanted > 0 else { return .notOurs }
    if same { return .held }
    guard selected == 0 else { return .notOurs }
    return putBacks < groupTapPutBacks ? .putBack : .givenUp
  }
}
