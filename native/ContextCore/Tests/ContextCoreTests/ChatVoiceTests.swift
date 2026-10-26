import XCTest

@testable import ContextCore

/// Speaking a message in Chat (#448, story 303): the mic's five-minute limit and its clock.
final class ChatVoiceTests: XCTestCase {
  func testTheClock() {
    XCTAssertEqual(ChatVoice.elapsed(0), "0:00")
    XCTAssertEqual(ChatVoice.elapsed(7.9), "0:07")
    XCTAssertEqual(ChatVoice.elapsed(72), "1:12")
    XCTAssertEqual(ChatVoice.elapsed(-3), "0:00")
  }

  func testARecordingIsCappedAtFiveMinutes() {
    XCTAssertEqual(ChatVoice.limit, 300)
    XCTAssertEqual(ChatVoice.elapsed(ChatVoice.limit), "5:00")
    XCTAssertEqual(ChatVoice.cappedLine, "Stopped at 5 minutes.")
  }
}
