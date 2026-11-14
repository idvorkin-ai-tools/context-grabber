//  Twenty seconds into Larry's turn on a board (spec 2026-11-12-whiteboard-conversation-design.md, *After 20 seconds*,
//  stories 775–777; Igor on his board, 2026-11-14: "I think Larry got stuck. I need interrupt/retry button after 20s!").
//  The Cockpit's mark on the picture's message (#630, #879) says where the picture is: none is a picture the Cockpit
//  hasn't taken, stuck, with Retry and Dismiss; received or seen without done is Larry's to answer, with a quiet
//  Interrupt. The board's model hands in the turn, the furthest mark it has seen and the clock.

public enum WhiteboardLarryWait: String, Equatable, Sendable {
  /// No turn out, or Larry marked the picture done.
  case none
  /// A turn is out and twenty seconds haven't passed.
  case waiting
  /// Twenty seconds and the Cockpit hasn't taken the picture: Retry or Dismiss.
  case stuck
  /// Twenty seconds and the Cockpit has it, received or seen, not done: Interrupt.
  case working

  /// How long a picture goes unanswered before the board offers anything.
  public static let after: Duration = .seconds(20)

  public static func of(
    _ turn: WhiteboardLarryTurn, receipt: ChatMessage.Receipt, now: ContinuousClock.Instant, after: Duration = after
  ) -> Self {
    guard case .awaiting(let since, _) = turn.state, receipt != .done else { return .none }
    if now - since < after { return .waiting }
    return receipt == .sent ? .stuck : .working
  }

  /// What the board offers in this state.
  public enum Control: String, Equatable, Sendable { case retry, dismiss, interrupt }

  public var controls: [Control] {
    switch self {
    case .stuck: return [.retry, .dismiss]
    case .working: return [.interrupt]
    case .none, .waiting: return []
    }
  }

  /// The stuck picture's copyable problem: the message and its context. Its state (when it went, how long it waited,
  /// whether it is still going up, whether the Cockpit is answering) is the board's to add.
  public static let stuckMessage = "Larry hasn't got the picture"
  public static let stuckContext = "WhiteboardView.larryStuck"

  /// The mark of the message `id` in a thread's messages, nil when the thread doesn't hold it.
  public static func receipt(of id: String, in messages: [ChatMessage]) -> ChatMessage.Receipt? {
    messages.last { $0.id == id }?.receipt
  }
}

extension ChatMessage.Receipt {
  private var rank: Int {
    switch self {
    case .sent: return 0
    case .received: return 1
    case .seen: return 2
    case .done: return 3
    }
  }

  /// The further along of the two: the Cockpit's ladder only moves forward, so a look that brings back less is ignored.
  public func atLeast(_ other: Self) -> Self { other.rank > rank ? other : self }
}
