import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Bead context-grabber-27sv (story 818): a long stretch of drawing between turns never costs Larry what changed. A
/// turn holds as many events as the Cockpit takes, less one for the picture's `post`, and past that a replaced view and
/// the Pencil's downs and ups go before anything else.
final class BoardEventsCapTests: XCTestCase {
  private func ink(_ i: Int) -> BoardEvent {
    .strokesChanged(added: ["s\(i)"], erased: [], moved: [], rev: i, t: Int64(i))
  }

  func testATurnHoldsAsManyAsTheCockpitTakesLessThePost() {
    XCTAssertEqual(BoardEvents.cap, BoardTurnReport.maxEvents - 1)
    var events = BoardEvents()
    for i in 0..<BoardEvents.cap { events.record(.undo(label: "u", t: Int64(i))) }
    var taken = events.take()
    XCTAssertEqual(taken.dropped, 0)
    taken.events.append(
      .post(BoardPostTiming(t: 9, build: "abc main", from: "button", renderMs: 1, encodeMs: 1, strokesMs: 1, bytes: 9)))
    let wire = BoardTurnReport(rev: 1, taken: taken).wire
    XCTAssertEqual((wire["events"] as? [Any])?.count, BoardTurnReport.maxEvents, "the post fits beside a full turn")
    XCTAssertNil(wire["events_dropped"])
  }

  func testThePencilsDownsAndUpsGoBeforeTheInkChanges() {
    // Igor's 2026-11-22 board: about 30 strokes, each a down, an up and an ink change, plus a kept reply and its
    // selection, more than a turn holds.
    var events = BoardEvents()
    events.tap(at: CGPoint(x: 1, y: 2), target: "ghost", t: 0)
    events.record(.selection(ids: ["k1", "k2"], t: 1))
    for i in 0..<80 {
      events.pen(down: true, t: Int64(10 * i + 2))
      events.pen(down: false, t: Int64(10 * i + 5))
      events.record(ink(i))
    }
    let taken = events.take()
    XCTAssertEqual(taken.events.count, BoardEvents.cap)
    XCTAssertEqual(taken.dropped, 2 + 240 - BoardEvents.cap)
    XCTAssertEqual(taken.droppedKinds, ["pen": taken.dropped])
    XCTAssertEqual(taken.events.first, .tap(x: 1, y: 2, target: "ghost", t: 0), "the tap on his mark stays")
    XCTAssertEqual(taken.events[1], .selection(ids: ["k1", "k2"], t: 1))
    XCTAssertEqual(taken.events.filter { $0.kind == "strokes_changed" }.count, 80, "every ink change stays")
    XCTAssertEqual(taken.events.last, ink(79))
    XCTAssertEqual(
      taken.events.filter { $0.kind == "pen" }.first, .pen(down: false, idleMs: 3, t: 215), "the newest pens stay")
  }

  func testAViewALaterOneReplacedGoesFirst() {
    var events = BoardEvents()
    events.record(.viewport(y: 0, h: 800, scale: 1, t: 0))
    events.pen(down: true, t: 1)
    for i in 0..<(BoardEvents.cap - 3) { events.record(ink(i)) }
    events.record(.viewport(y: 400, h: 800, scale: 1, t: 2))
    events.record(ink(999))
    let taken = events.take()
    XCTAssertEqual(taken.droppedKinds, ["viewport": 1])
    XCTAssertEqual(taken.events.first, .pen(down: true, idleMs: 0, t: 1))
    XCTAssertTrue(taken.events.contains(.viewport(y: 400, h: 800, scale: 1, t: 2)), "the view as it is now stays")
  }

  func testWithNothingElseToSpareTheOldestGo() {
    var events = BoardEvents()
    events.record(.viewport(y: 0, h: 800, scale: 1, t: 0))
    for i in 0..<BoardEvents.cap { events.record(ink(i)) }
    let taken = events.take()
    XCTAssertEqual(taken.droppedKinds, ["viewport": 1], "a lone view is still the oldest")
    events.record(.viewport(y: 0, h: 800, scale: 1, t: 0))
    for i in 0..<(BoardEvents.cap - 1) { events.record(ink(i)) }
    events.record(ink(500))
    XCTAssertEqual(events.take().droppedKinds, ["viewport": 1])
    for i in 0...BoardEvents.cap { events.record(ink(i)) }
    let inks = events.take()
    XCTAssertEqual(inks.droppedKinds, ["strokes_changed": 1])
    XCTAssertEqual(inks.events.first, ink(1))
  }

  func testRestoredEventsKeepTheirCountsAndTheSameOrder() {
    var events = BoardEvents()
    for i in 0...BoardEvents.cap { events.pen(down: i % 2 == 0, t: Int64(i)) }
    let taken = events.take()
    XCTAssertEqual(taken.droppedKinds, ["pen": 1])
    events.record(ink(1))
    events.restore(taken)
    let again = events.take()
    XCTAssertEqual(again.dropped, 2)
    XCTAssertEqual(again.droppedKinds, ["pen": 2])
    XCTAssertEqual(again.events.last, ink(1))
  }

  func testTheWireTrimsPensFirstToo() {
    let events =
      [BoardEvent.undo(label: "a", t: 0)]
      + (1...BoardTurnReport.maxEvents).map {
        BoardEvent.pen(down: $0 % 2 == 0, idleMs: 0, t: Int64($0))
      }
    let wire = BoardTurnReport(rev: 1, events: events).wire
    let kept = wire["events"] as? [[String: Any]]
    XCTAssertEqual(kept?.count, BoardTurnReport.maxEvents)
    XCTAssertEqual(kept?.first?["type"] as? String, "undo", "the undo outlasts the pens")
    XCTAssertEqual(wire["events_dropped"] as? Int, 1)
  }

  func testTheReportKeepsItsCountsByKindOffTheWire() throws {
    let report = BoardTurnReport(
      rev: 2, taken: BoardEvents.Taken(events: [], dropped: 3, droppedKinds: ["pen": 3]))
    XCTAssertEqual(report.droppedKinds, ["pen": 3])
    XCTAssertNil(report.wire["dropped_kinds"])
    XCTAssertEqual(report.wire["events_dropped"] as? Int, 3)
    let back = try JSONDecoder().decode(BoardTurnReport.self, from: JSONEncoder().encode(report))
    XCTAssertEqual(back, report)
    XCTAssertNil(BoardTurnReport(rev: 2, taken: BoardEvents.Taken(events: [])).droppedKinds)
  }
}
