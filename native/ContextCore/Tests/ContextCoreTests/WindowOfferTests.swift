import XCTest

@testable import ContextCore

/// Story 731: a new window offers the screens that can have a window, in home's order, and nothing else.
final class WindowOfferTests: XCTestCase {
  func testItFollowsHomesOrderWithTheTodayCardFirst() {
    let offered = WindowScreen.offered(
      todayCard: true,
      tiles: ["call", "inbox", "gym_timer", "whiteboard", "breathe", "cockpit", "places", "think_a_card"])
    XCTAssertEqual(offered, [.today, .chat, .whiteboard, .cockpit, .places, .card])
  }

  func testWhatHomeHidesIsNotOffered() {
    XCTAssertEqual(WindowScreen.offered(todayCard: false, tiles: ["places", "inbox"]), [.places, .chat])
  }

  func testTheAudioScreensAndTheRestOfHomeAreNot() {
    XCTAssertEqual(
      WindowScreen.offered(todayCard: false, tiles: ["call", "gym_timer", "breathe", "report_problem", "settings"]), [])
  }

  func testTodayOnceEvenIfItIsAlsoATile() {
    XCTAssertEqual(WindowScreen.offered(todayCard: true, tiles: ["today", "inbox"]), [.today, .chat])
  }
}
