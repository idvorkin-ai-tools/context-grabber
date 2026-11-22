import Foundation
import XCTest

@testable import ContextCore

/// #1044: a board's save timed stage by stage for the session log, on a clock the test moves: what each stage took, what
/// set the save off, how many strokes and which revision, and never the drawing itself.
final class BoardSaveTimingTests: XCTestCase {
  /// A clock that moves only when told, in seconds.
  private final class Clock {
    var now = 100.0
  }

  private struct Full: Error {}

  func testEachStageIsTimedInMillisecondsWithTheTriggerStrokesAndRevision() throws {
    let clock = Clock()
    var timing = BoardSaveTiming(board: "b1", trigger: .debounce, strokes: 1_000) { clock.now }
    let data = timing.time("encode") { () -> Data in
      clock.now += 0.0123
      return Data("ink".utf8)
    }
    XCTAssertEqual(data, Data("ink".utf8), "the stage's own result comes back")
    timing.time("write") { clock.now += 0.004 }
    timing.time("picture") { clock.now += 0.25 }
    timing.time("index") { clock.now += 0.001 }
    timing.revision = 1_800_000_000_123
    let fields = timing.fields
    XCTAssertEqual(fields["action"] as? String, "save_timing")
    XCTAssertEqual(fields["board"] as? String, "b1")
    XCTAssertEqual(fields["trigger"] as? String, "debounce")
    XCTAssertEqual(fields["strokes"] as? Int, 1_000)
    XCTAssertEqual(fields["revision"] as? Int64, 1_800_000_000_123)
    XCTAssertEqual(fields["encode_ms"] as? Double, 12.3)
    XCTAssertEqual(fields["write_ms"] as? Double, 4.0)
    XCTAssertEqual(fields["picture_ms"] as? Double, 250.0)
    XCTAssertEqual(fields["index_ms"] as? Double, 1.0)
    XCTAssertEqual(fields["total_ms"] as? Double, 267.3)
    XCTAssertNil(fields["failed"])
    XCTAssertEqual(
      Set(fields.keys),
      [
        "action", "board", "trigger", "strokes", "revision", "encode_ms", "write_ms", "picture_ms", "index_ms",
        "total_ms",
      ],
      "nothing of the drawing itself")
  }

  func testAStageThatFailsIsTimedAndNamedAndTheErrorGoesUp() {
    let clock = Clock()
    var timing = BoardSaveTiming(board: "b1", trigger: .close, strokes: 5) { clock.now }
    timing.time("encode") { clock.now += 0.002 }
    XCTAssertThrowsError(
      try timing.time("write") {
        clock.now += 0.5
        throw Full()
      })
    let fields = timing.fields
    XCTAssertEqual(fields["trigger"] as? String, "close")
    XCTAssertEqual(fields["failed"] as? String, "write")
    XCTAssertEqual(fields["write_ms"] as? Double, 500.0)
    XCTAssertEqual(fields["total_ms"] as? Double, 502.0)
    XCTAssertNil(fields["revision"], "the list wasn't told, so there's no new revision")
    XCTAssertNil(fields["picture_ms"], "a stage never reached isn't in it")
  }

  func testTheTriggersAreTheWaysABoardSaves() {
    XCTAssertEqual(
      BoardSaveTiming.Trigger.allCases.map(\.rawValue), ["debounce", "close", "background", "fixture"])
  }
}
