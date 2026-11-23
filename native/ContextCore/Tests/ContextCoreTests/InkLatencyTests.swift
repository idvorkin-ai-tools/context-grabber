//  Story 1209 (bead context-grabber-vabk): Ink side by side's numbers, readout, log fields and web probe.

import XCTest

@testable import ContextCore

final class InkLatencyTests: XCTestCase {
  func testBeforeAnyStrokeTheCornerSaysDrawToMeasure() {
    let latency = InkLatency(side: .native)
    XCTAssertEqual(latency.readout, "Draw to measure")
    XCTAssertNil(latency.last)
    XCTAssertNil(latency.median)
    XCTAssertEqual(latency.count, 0)
  }

  func testEachStrokeUpdatesLastMedianAndCount() {
    var latency = InkLatency(side: .web)
    XCTAssertEqual(latency.add(18.4), .kept)
    XCTAssertEqual(latency.readout, "last 18 ms · median 18 ms · 1 stroke")
    latency.add(30)
    latency.add(21)
    XCTAssertEqual(latency.last, 21)
    XCTAssertEqual(latency.median, 21)
    XCTAssertEqual(latency.readout, "last 21 ms · median 21 ms · 3 strokes")
  }

  func testTheMedianOfAnEvenCountIsTheMeanOfTheMiddleTwo() {
    var latency = InkLatency(side: .native)
    for ms in [40.0, 10, 30, 20] { latency.add(ms) }
    XCTAssertEqual(latency.median, 25)
  }

  func testATimeBelowZeroOrOverASecondIsDroppedNotCounted() {
    var latency = InkLatency(side: .native)
    XCTAssertEqual(latency.add(-3), .dropped)
    XCTAssertEqual(latency.add(1500), .dropped)
    XCTAssertEqual(latency.add(.nan), .dropped)
    XCTAssertEqual(latency.add(1000), .kept)
    XCTAssertEqual(latency.count, 1)
    XCTAssertEqual(latency.dropped, 3)
    XCTAssertEqual(latency.readout, "last 1000 ms · median 1000 ms · 1 stroke")
  }

  func testTheLogNamesTheSideTheTimeTheMedianAndTheCount() {
    var latency = InkLatency(side: .web)
    latency.add(12.34)
    let outcome = latency.add(20.06)
    let fields = latency.logFields(ms: 20.06, outcome: outcome)
    XCTAssertEqual(fields["side"] as? String, "web")
    XCTAssertEqual(fields["ms"] as? Double, 20.1)
    XCTAssertEqual(fields["median"] as? Double, 16.2)
    XCTAssertEqual(fields["n"] as? Int, 2)
    XCTAssertEqual(fields["kept"] as? Bool, true)
    XCTAssertEqual(fields["dropped"] as? Int, 0)
  }

  func testADroppedSampleIsStillLoggedAsDropped() {
    var latency = InkLatency(side: .native)
    let outcome = latency.add(-1)
    let fields = latency.logFields(ms: -1, outcome: outcome)
    XCTAssertEqual(fields["kept"] as? Bool, false)
    XCTAssertEqual(fields["dropped"] as? Int, 1)
    XCTAssertNil(fields["median"])
  }

  func testTheWebBoardOpensOnItsScratchBoard() {
    XCTAssertEqual(
      InkLatency.webBoardURL(cockpit: "https://cockpit.example.net")?.absoluteString,
      "https://cockpit.example.net/ink?b=scratch")
    XCTAssertEqual(
      InkLatency.webBoardURL(cockpit: "https://cockpit.example.net/")?.absoluteString,
      "https://cockpit.example.net/ink?b=scratch")
  }

  func testTheProbeListensBeforeThePageAndPostsToItsHandler() {
    let script = InkLatency.webProbeScript
    XCTAssertTrue(script.contains("capture: true"), "it must run before the page can stop the event")
    XCTAssertTrue(script.contains("e.timeStamp"))
    XCTAssertTrue(script.contains("requestAnimationFrame"))
    XCTAssertTrue(script.contains("messageHandlers.\(InkLatency.messageHandler)"))
  }
}
