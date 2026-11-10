import Foundation

/// #809: what the outbox holds, for the log, to settle whether a sent message its thread never returns stays a
/// pending bubble on the phone. Counts and ages only: never a message's text or a link.
public enum ChatOutboxLook {
  /// One thread's share of the outbox against the messages the Cockpit returned for it.
  public struct Thread: Equatable, Sendable {
    /// Every outbox item for the thread, by where it is going or where it landed.
    public var items = 0
    /// Of those, the ones the Cockpit took.
    public var sent = 0
    /// What `ChatWire.pending` shows as bubbles: the ones whose id the thread does not hold.
    public var pending = 0
    /// Sent, and still pending: the Cockpit took it and its thread does not list it.
    public var sentPending = 0
    /// Hours since the oldest of those was sent; nil with none.
    public var oldestSentPendingHours: Double?

    public func logFields(thread: String) -> [String: Any] {
      var fields: [String: Any] = [
        "action": "outbox_thread", "thread": thread, "items": items, "sent": sent, "pending": pending,
        "sent_pending": sentPending,
      ]
      if let oldestSentPendingHours { fields["oldest_sent_pending_hours"] = oldestSentPendingHours }
      return fields
    }
  }

  /// Which of an open thread's reads log a line: the first, any where `sentPending` changed, and once more when
  /// what is sent and pending has stayed so long enough to be no race between a send and a poll.
  public struct ThreadLog: Equatable, Sendable {
    /// The age, as logged, from which a sent and pending item is stuck and not just landing: 0.1 h is three minutes
    /// or more, an age being rounded to a tenth.
    public static let stuckHours = 0.1
    private var sentPending: Int?
    private var saidStuck = false

    public init() {}

    public mutating func logs(_ look: Thread) -> Bool {
      let stuck = (look.oldestSentPendingHours ?? 0) >= Self.stuckHours
      if sentPending != look.sentPending {
        sentPending = look.sentPending
        saidStuck = stuck
        return true
      }
      guard stuck, !saidStuck else { return false }
      saidStuck = true
      return true
    }
  }

  /// The whole outbox.
  public struct Whole: Equatable, Sendable {
    public var items = 0
    public var sent = 0
    /// Sent to a chat thread: the ones a thread's read should drop once it holds them. The rest of `sent` are
    /// *Earlier shares*, kept on purpose.
    public var sentInChats = 0
    /// Hours since the oldest sent item, and the oldest sent to a chat thread, went; nil with none.
    public var oldestSentHours: Double?
    public var oldestSentInChatsHours: Double?

    public func logFields(why: String) -> [String: Any] {
      var fields: [String: Any] = [
        "action": "outbox", "why": why, "items": items, "sent": sent, "sent_in_chats": sentInChats,
      ]
      if let oldestSentHours { fields["oldest_sent_hours"] = oldestSentHours }
      if let oldestSentInChatsHours { fields["oldest_sent_in_chats_hours"] = oldestSentInChatsHours }
      return fields
    }
  }

  /// `now`: Unix ms, as `sentAt`.
  public static func thread(_ key: String, items: [InboxItem], messages: [ChatMessage]?, now: Int64) -> Thread {
    let mine = items.filter { $0.thread == key || $0.chatThread == key }
    let pending = ChatWire.pending(in: key, items: mine, messages: messages)
    let sentPending = pending.filter { $0.status == .sent }
    return Thread(
      items: mine.count, sent: mine.count { $0.status == .sent }, pending: pending.count,
      sentPending: sentPending.count, oldestSentPendingHours: oldestHours(sentPending, now: now))
  }

  public static func whole(_ items: [InboxItem], now: Int64) -> Whole {
    let sent = items.filter { $0.status == .sent }
    let inChats = sent.filter { $0.chatThread != nil }
    return Whole(
      items: items.count, sent: sent.count, sentInChats: inChats.count,
      oldestSentHours: oldestHours(sent, now: now), oldestSentInChatsHours: oldestHours(inChats, now: now))
  }

  /// To a tenth of an hour; a clock set back reads 0, not a negative age.
  private static func oldestHours(_ sent: [InboxItem], now: Int64) -> Double? {
    guard let oldest = sent.compactMap(\.sentAt).min() else { return nil }
    return (Double(max(0, now - oldest)) / 360_000).rounded() / 10
  }
}
