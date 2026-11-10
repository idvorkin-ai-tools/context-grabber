import XCTest

@testable import ContextCore

/// #809: the outbox's counts for the log (`chat` outbox_thread and outbox), which settle whether a sent message its
/// thread never returns stays pending on the phone.
final class ChatOutboxLookTests: XCTestCase {
  private let hour: Int64 = 3_600_000

  private func item(_ id: String, thread: String? = nil, landed: String? = nil, sentAt: Int64? = nil) -> InboxItem {
    var item = InboxItem(id: id, kind: .text, sharedAt: 1, text: "secret words", thread: thread)
    item.sentAt = sentAt
    item.chatThread = landed
    return item
  }

  private func message(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "igor", text: "") }

  func testAThreadCountsItsItemsSentOnesAndTheSentOnesItDoesNotHold() {
    let now = 100 * hour
    let items = [
      item("waiting", thread: "k"),
      item("delivered", thread: "k", landed: "k", sentAt: now - hour),
      item("stuck-old", thread: "k", landed: "k", sentAt: now - 50 * hour),
      item("stuck-new", landed: "k", sentAt: now - 2 * hour),
      item("elsewhere", thread: "j", landed: "j", sentAt: now - 90 * hour),
      item("earlier-share", sentAt: now - 99 * hour),
    ]
    let look = ChatOutboxLook.thread("k", items: items, messages: [message("delivered")], now: now)
    XCTAssertEqual(
      look, .init(items: 4, sent: 3, pending: 3, sentPending: 2, oldestSentPendingHours: 50))
    XCTAssertEqual(look.pending, ChatWire.pending(in: "k", items: items, messages: [message("delivered")]).count)
  }

  func testAThreadWithNothingStuckCarriesNoAge() {
    let items = [item("waiting", thread: "k"), item("delivered", landed: "k", sentAt: 5)]
    let look = ChatOutboxLook.thread("k", items: items, messages: [message("delivered")], now: 10 * hour)
    XCTAssertEqual(look, .init(items: 2, sent: 1, pending: 1, sentPending: 0, oldestSentPendingHours: nil))
    XCTAssertNil(look.logFields(thread: "k")["oldest_sent_pending_hours"])
    XCTAssertEqual(ChatOutboxLook.thread("k", items: [], messages: nil, now: 1), .init())
  }

  func testAThreadNotReadYetCountsEverySentItemAsPending() {
    let look = ChatOutboxLook.thread("k", items: [item("a", landed: "k", sentAt: 0)], messages: nil, now: hour / 2)
    XCTAssertEqual(look, .init(items: 1, sent: 1, pending: 1, sentPending: 1, oldestSentPendingHours: 0.5))
  }

  func testAgesAreTenthsOfAnHourAndNeverNegative() {
    let items = [item("a", landed: "k", sentAt: 10 * hour)]
    XCTAssertEqual(
      ChatOutboxLook.thread("k", items: items, messages: nil, now: 10 * hour + 15 * 60_000).oldestSentPendingHours,
      0.3, "15 minutes, rounded")
    XCTAssertEqual(ChatOutboxLook.thread("k", items: items, messages: nil, now: 0).oldestSentPendingHours, 0)
  }

  func testAnOpenThreadLogsItsFirstReadAChangeAndOnceWhenASentItemSticks() {
    func look(_ sentPending: Int, hours: Double? = nil) -> ChatOutboxLook.Thread {
      .init(
        items: sentPending, sent: sentPending, pending: sentPending, sentPending: sentPending,
        oldestSentPendingHours: hours)
    }
    var log = ChatOutboxLook.ThreadLog()
    XCTAssertTrue(log.logs(look(0)), "the first read")
    XCTAssertFalse(log.logs(look(0)), "a poll with nothing new")
    XCTAssertTrue(log.logs(look(1, hours: 0)), "a send the thread does not hold yet")
    XCTAssertFalse(log.logs(look(1, hours: 0)))
    XCTAssertTrue(log.logs(look(1, hours: 0.1)), "still not held minutes later: stuck, said once")
    XCTAssertFalse(log.logs(look(1, hours: 0.2)))
    XCTAssertTrue(log.logs(look(0)), "the thread returned it")
    XCTAssertTrue(log.logs(look(1, hours: 0)))
    XCTAssertTrue(log.logs(look(1, hours: 0.3)), "each sticking is said")

    var old = ChatOutboxLook.ThreadLog()
    XCTAssertTrue(old.logs(look(2, hours: 50)), "already stuck at the open: the first read says so")
    XCTAssertFalse(old.logs(look(2, hours: 50.1)), "and no second line for it")
  }

  func testTheWholeOutboxCountsSentItemsAndTellsEarlierSharesFromChats() {
    let now = 200 * hour
    let items = [
      item("waiting", thread: "k"), item("new-chat"),
      item("in-chat", landed: "k", sentAt: now - 30 * hour),
      item("in-chat-2", landed: "j", sentAt: now - 3 * hour),
      item("earlier-share", sentAt: now - 150 * hour),
    ]
    XCTAssertEqual(
      ChatOutboxLook.whole(items, now: now),
      .init(items: 5, sent: 3, sentInChats: 2, oldestSentHours: 150, oldestSentInChatsHours: 30))
    XCTAssertEqual(ChatOutboxLook.whole([], now: now), .init())
  }

  func testTheLogLinesCarryCountsAndNeverTheWords() throws {
    let now = 10 * hour
    let items = [item("a", thread: "k", landed: "k", sentAt: now - 4 * hour)]
    let thread = ChatOutboxLook.thread("k", items: items, messages: [], now: now).logFields(thread: "k")
    XCTAssertEqual(
      thread.keys.sorted(),
      ["action", "items", "oldest_sent_pending_hours", "pending", "sent", "sent_pending", "thread"])
    XCTAssertEqual(thread["action"] as? String, "outbox_thread")
    XCTAssertEqual(thread["thread"] as? String, "k")
    XCTAssertEqual(thread["sent_pending"] as? Int, 1)
    XCTAssertEqual(thread["oldest_sent_pending_hours"] as? Double, 4)
    let whole = ChatOutboxLook.whole(items, now: now).logFields(why: "foreground")
    XCTAssertEqual(
      whole.keys.sorted(),
      ["action", "items", "oldest_sent_hours", "oldest_sent_in_chats_hours", "sent", "sent_in_chats", "why"])
    XCTAssertEqual(whole["action"] as? String, "outbox")
    XCTAssertEqual(whole["why"] as? String, "foreground")
    for fields in [thread, whole] {
      let line = String(decoding: SessionLogLine.encode(type: "chat", t: 1, fields: fields), as: UTF8.self)
      XCTAssertFalse(line.contains("secret"), line)
    }
  }
}
