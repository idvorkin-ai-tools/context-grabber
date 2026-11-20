import XCTest

@testable import ContextCore

/// Stories 726 and 730: off home, only the report stays live in the Go menu.
final class MacGoMenuTests: XCTestCase {
  func testOnHomeEveryDestinationIsLive() {
    for row in ["today", "inbox", "gym_timer", "report_problem"] {
      XCTAssertTrue(MacGoMenu.live(row, homeInFront: true), row)
    }
  }

  func testOffHomeOnlyTheReportIsLive() {
    XCTAssertTrue(MacGoMenu.live("report_problem", homeInFront: false), "it opens over chat, a timer or a call")
    for row in ["today", "inbox", "gym_timer", "breathe", "whiteboard"] {
      XCTAssertFalse(MacGoMenu.live(row, homeInFront: false), "\(row) would replace the screen in front")
    }
  }

  /// Stories 734-735 (#745): New Chat from home or chat, never over a timer or a call.
  func testNewChatIsLiveFromHomeOrChat() {
    XCTAssertTrue(MacGoMenu.newChatLive(homeInFront: true, chatInFront: false, chatHasWindow: false))
    XCTAssertTrue(MacGoMenu.newChatLive(homeInFront: false, chatInFront: true, chatHasWindow: false))
    XCTAssertTrue(
      MacGoMenu.newChatLive(homeInFront: false, chatInFront: false, chatHasWindow: true),
      "chat's own window comes forward and nothing in the home window closes")
  }

  func testNewChatWaitsWhileAnotherScreenCoversHome() {
    XCTAssertFalse(MacGoMenu.newChatLive(homeInFront: false, chatInFront: false, chatHasWindow: false))
  }
}
