//  Larry is listening (spec 2026-11-12-whiteboard-conversation-design.md, *Larry is listening*, story 929; bead
//  context-grabber-4fww; Igor, 2026-11-22: "when Larry has seen a post but is waiting for more, no text reply; show a
//  tiny indicator"). The Cockpit marks Igor's newest message `waiting` while Larry holds for more; the board reads it
//  from the thread it already reads every few seconds, shows an ear, and takes a hold on the picture of the turn out as
//  his answer.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum WhiteboardLarryListening {
  /// Larry's words while he holds on Igor's newest message in `thread` (oldest first): nil unless that message carries
  /// the Cockpit's hold and no message of Larry's comes after it. A hold on an older message never counts.
  public static func label(in thread: [ChatMessage]) -> String? {
    guard let index = thread.lastIndex(where: \.fromIgor), let waiting = thread[index].waiting else { return nil }
    if thread[(index + 1)...].contains(where: { !$0.fromIgor && !$0.isSystem }) { return nil }
    return waiting.label
  }

  /// Larry holds on the picture of the turn out: the hold is on Igor's newest message and that message is the
  /// picture's (`picture`, its id, when the board handed it over itself), or, without one, a message of Igor's from
  /// since the picture went (`went`, with a second's grace for the Cockpit's whole-second timestamps). False with no
  /// turn out.
  public static func holdsTurn(
    _ turn: WhiteboardLarryTurn, thread: [ChatMessage], picture: String?, went: Date
  ) -> Bool {
    guard turn.looking, label(in: thread) != nil, let newest = thread.last(where: \.fromIgor) else { return false }
    if let picture { return newest.id == picture }
    return newest.at.map { $0 >= went - 1 } ?? false
  }

  /// The board's ear (story 929): Larry's words for his hold, shown only while no turn is out, since a turn's own
  /// clock speaks while it is.
  public static func shown(_ label: String?, turn: WhiteboardLarryTurn) -> String? {
    turn.looking ? nil : label
  }
}
