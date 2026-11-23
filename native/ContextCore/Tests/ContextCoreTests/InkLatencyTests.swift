//  Story 1209 (bead context-grabber-vabk): Ink side by side's numbers, readout, log fields and web probe.

import XCTest

@testable import ContextCore

#if canImport(JavaScriptCore)
  import JavaScriptCore
#endif

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

  #if canImport(JavaScriptCore)
    /// The spec's span, run in a real JavaScript engine: a pen-down at 100 ms on the page's clock and the next frame
    /// at 116 ms is one 16 ms sample, posted at the frame and not before; a tap on the page's own button is none.
    func testTheProbeTimesAPenDownToTheNextFrameAndSkipsThePagesButtons() throws {
      let js = try XCTUnwrap(JSContext())
      var thrown: [String] = []
      js.exceptionHandler = { _, error in thrown.append(error?.toString() ?? "?") }
      js.evaluateScript(
        """
        var window = this;
        var listeners = [];
        function addEventListener(type, fn, opts) { listeners.push({ type: type, fn: fn, opts: opts }); }
        var frames = [];
        function requestAnimationFrame(fn) { frames.push(fn); }
        var clock = 0;
        var performance = { now: function () { return clock; } };
        var posts = [];
        window.webkit = { messageHandlers: { "\(InkLatency.messageHandler)": { postMessage: function (m) { posts.push(m); } } } };
        function el(tag, parent) {
          return { tag: tag, parent: parent, closest: function (sel) {
            var tags = sel.split(",").map(function (s) { return s.trim(); });
            for (var n = this; n; n = n.parent) { if (tags.indexOf(n.tag) >= 0) return n; }
            return null;
          } };
        }
        function down(target, stamp) {
          listeners.forEach(function (l) { l.fn({ target: target, timeStamp: stamp, pointerType: "pen" }); });
        }
        function frame(at) { clock = at; var due = frames; frames = []; due.forEach(function (f) { f(at); }); }
        function sent() { return JSON.stringify(posts.map(function (p) { return p.ms; })); }
        """)
      js.evaluateScript(InkLatency.webProbeScript)
      js.evaluateScript(InkLatency.webProbeScript)
      XCTAssertEqual(js.evaluateScript("listeners.length")?.toInt32(), 1, "a second injection adds no second listener")
      XCTAssertEqual(js.evaluateScript("listeners[0].type")?.toString(), "pointerdown")
      XCTAssertEqual(
        js.evaluateScript("listeners[0].opts.capture === true")?.toBool(), true,
        "it must run before the page can stop the event")

      js.evaluateScript("down(el('canvas', el('div')), 100); clock = 105")
      XCTAssertEqual(js.evaluateScript("sent()")?.toString(), "[]", "nothing until the next frame")
      js.evaluateScript("frame(116)")
      XCTAssertEqual(js.evaluateScript("sent()")?.toString(), "[16]")

      js.evaluateScript("down(el('svg', el('button', el('div'))), 200); frame(216)")
      XCTAssertEqual(js.evaluateScript("sent()")?.toString(), "[16]", "a tap on the page's own button is not a stroke")
      XCTAssertEqual(thrown, [])
    }
  #endif
}
