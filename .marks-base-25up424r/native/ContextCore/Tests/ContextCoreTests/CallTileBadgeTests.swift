//  The home Call tile's badge: short whatever the call, so the tile never outgrows its neighbours (Codex on #295).

import ContextCore
import XCTest

final class CallTileBadgeTests: XCTestCase {
  func testNoBadgeWithoutACallRunning() {
    var s = CallSnapshot()
    XCTAssertNil(s.tileBadge(nowMs: 0))
    s.state = .ended
    s.endedReason = "Generating the LLM response took too long."
    XCTAssertNil(s.tileBadge(nowMs: 0))
  }

  func testCallingThenTheRunningTime() {
    var s = CallSnapshot()
    s.state = .connecting
    XCTAssertEqual(s.tileBadge(nowMs: 5_000), "calling\u{2026}")
    s.state = .live
    s.startedAt = 10_000
    XCTAssertEqual(s.tileBadge(nowMs: 10_000), "0:00")
    XCTAssertEqual(s.tileBadge(nowMs: 135_400), "2:05")
    XCTAssertEqual(s.tileBadge(nowMs: 3_610_000), "60:00")
  }

  func testTheBadgeIsOneShortLineWhateverTheBackendAndVoice() {
    var s = CallSnapshot()
    s.state = .live
    s.backend = .eleven
    s.voice = .igor
    s.startedAt = 0
    let badge = s.tileBadge(nowMs: 59 * 60_000 + 59_000)
    XCTAssertEqual(badge, "59:59")
    XCTAssertFalse(badge?.contains("\n") ?? true)
  }
}
