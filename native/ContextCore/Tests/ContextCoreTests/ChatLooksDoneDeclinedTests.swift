import XCTest

@testable import ContextCore

/// #1098, stories 314, 1100, 1101: turning Larry's *Looks done* proposals down on this device.
final class ChatLooksDoneDeclinedTests: XCTestCase {
  private func row(
    _ key: String, done: Bool = false, archived: Bool = false, looksDone: Bool = false, pinned: Bool = false
  ) -> ChatSummary {
    ChatSummary(
      key: key, title: "T\(key)", lastTs: "", lastWho: "larry", lastText: "", done: done || archived,
      archived: archived, looksDone: looksDone, pinned: pinned)
  }

  func testATurnedDownProposalLeavesTheRowTheLineAndReview() {
    let threads = [row("a"), row("b", looksDone: true), row("c", looksDone: true)]
    var declined = ChatLooksDoneDeclined()
    XCTAssertEqual(declined.decline(["b"]), ["b"])
    XCTAssertEqual(declined.decline(["b"]), [], "already turned down: nothing new to log")
    let shown = declined.masked(threads)
    XCTAssertFalse(shown[1].showsLooksDone, "the row's mark is gone")
    XCTAssertTrue(shown[2].showsLooksDone)
    XCTAssertEqual(shown.map(\.key), ["a", "b", "c"], "the thread stays live where it was")
    XCTAssertFalse(shown[1].done)
    var selection = ChatListSelection()
    XCTAssertEqual(selection.reviewLine(shown), "1 chat looks done")
    XCTAssertEqual(selection.review(shown), 1)
    XCTAssertFalse(selection.ticked("b"), "Review doesn't offer it again")
    XCTAssertEqual(selection.rows(shown).map(\.key), ["c"], "not under Recommendations")
  }

  func testTheLastProposalTurnedDownLeavesNoLineAndNothingUnderRecommendations() {
    var declined = ChatLooksDoneDeclined()
    declined.decline(["b"])
    let shown = declined.masked([row("a"), row("b", looksDone: true)])
    var selection = ChatListSelection()
    XCTAssertNil(selection.reviewLine(shown), "the screenshot's state: nothing left to review")
    selection.toggle()
    selection.show(.recommendations)
    XCTAssertEqual(selection.emptyLine(shown), "Nothing looks done")
  }

  func testTheSwipeIsOfferedOnlyOnALiveRowThatLooksDone() {
    XCTAssertTrue(ChatLooksDoneSwipe.offers(row("b", looksDone: true)))
    XCTAssertFalse(ChatLooksDoneSwipe.offers(row("a")))
    XCTAssertFalse(ChatLooksDoneSwipe.offers(row("d", done: true, looksDone: true)), "a Done thread has no mark")
    XCTAssertFalse(ChatLooksDoneSwipe.offers(row("b", looksDone: true).declined()), "already turned down")
  }

  func testAReviewTurnsDownWhatWasLeftUnticked() {
    let threads = [row("a"), row("b", looksDone: true), row("c", looksDone: true), row("d", looksDone: true)]
    var selection = ChatListSelection()
    selection.review(threads)
    selection.tick("c")
    selection.show(.all)
    selection.tick("a")
    XCTAssertEqual(selection.declined(threads), ["c"], "the unticked proposal, even after switching to All")
    XCTAssertEqual(Set(selection.archivePicked(threads)), ["a", "b", "d"])
    XCTAssertEqual(selection.declined(threads), [], "Archive ends the Review")
  }

  func testSelectAndCancelTurnNothingDown() {
    let threads = [row("a"), row("b", looksDone: true)]
    var selection = ChatListSelection()
    selection.toggle()
    XCTAssertEqual(selection.declined(threads), [], "Select from the toolbar never turns anything down")
    selection.toggle()
    selection.review(threads)
    selection.tick("b")
    selection.toggle()
    XCTAssertEqual(selection.declined(threads), [], "Cancel leaves the list as it was")
    selection.review(threads)
    selection.toggle()
    selection.toggle()
    XCTAssertEqual(selection.declined(threads), [], "Select after a cancelled Review is not a Review")
  }

  func testTheSameProposalStaysTurnedDownAndANewOneShowsOnceTheCockpitDroppedIt() {
    var declined = ChatLooksDoneDeclined()
    declined.decline(["b", "c", "d", "e"])
    let still = declined.fresh([row("b", looksDone: true), row("c"), row("d", archived: true, looksDone: true)])
    XCTAssertFalse(still[0].showsLooksDone, "the Cockpit still carries the same proposal: still turned down")
    XCTAssertEqual(declined.keys, ["b"], "cleared by a message, archived, or gone: forgotten")
    declined.decline(["b"])
    _ = declined.fresh([row("b")])
    XCTAssertEqual(declined.keys, [])
    let again = declined.fresh([row("b", looksDone: true)])
    XCTAssertTrue(again[0].showsLooksDone, "Larry proposed it again after it was cleared: the mark shows")
  }

  func testItIsRememberedAcrossLaunches() {
    var declined = ChatLooksDoneDeclined()
    declined.decline(["b", "a"])
    XCTAssertEqual(declined.saved, #"["a","b"]"#)
    XCTAssertEqual(ChatLooksDoneDeclined.restored(declined.saved), declined)
    XCTAssertEqual(ChatLooksDoneDeclined.restored(nil).keys, [])
    XCTAssertEqual(ChatLooksDoneDeclined.restored("not json").keys, [])
    XCTAssertEqual(ChatLooksDoneDeclined.settingKey, "chat_looks_done_declined")
  }
}
