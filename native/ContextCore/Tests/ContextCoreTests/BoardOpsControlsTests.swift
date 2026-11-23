import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Step 3 of Larry's board ops (stories 845–851): his controls, hiding and selecting, and what Larry hears of the
/// margin, the view and Undo.
final class BoardOpsControlsTests: XCTestCase {
  private func batch(_ list: [Any]) -> BoardOps.Batch {
    BoardOps.batch(["board": "b1", "base_rev": 0, "label": "fold", "list": list], key: "m1", source: "web")!
  }

  private func stroke(_ id: String, y: CGFloat) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: 10, y: y, width: 100, height: 20))
  }

  // MARK: The wire

  func testAnOverlayWithItsLooksAndItsEvent() throws {
    let b = batch([
      [
        "op": "overlay", "id": "band1", "kind": "band", "rect": ["x": 0, "y": 400, "w": 820, "h": 40],
        "label": "room opens here", "style": ["fill": "#ffeeaa"], "tap_event": ["type": "make_room", "y": 400],
      ],
      ["op": "remove_overlay", "id": "old"],
    ])
    XCTAssertNil(b.refusal)
    guard case .overlay(let overlay) = try XCTUnwrap(b.ops.first) else { return XCTFail("\(b.ops)") }
    XCTAssertEqual(overlay.id, "band1")
    XCTAssertEqual(overlay.kind, .band)
    XCTAssertEqual(overlay.rect, CGRect(x: 0, y: 400, width: 820, height: 40))
    XCTAssertEqual(overlay.label, "room opens here")
    XCTAssertEqual(overlay.styleColor("fill"), 0xFFEEAA)
    XCTAssertNil(overlay.styleColor("color"))
    XCTAssertEqual(overlay.tapEvent, BoardMeta(["type": "make_room", "y": 400]))
    XCTAssertEqual(b.ops[1], .removeOverlay("old"))
  }

  func testAnOverlayThatCantShowIsRefused() {
    let base: [String: Any] = ["op": "overlay", "id": "o", "kind": "chip", "rect": ["x": 0, "y": 0, "w": 10, "h": 10]]
    XCTAssertNil(batch([base]).refusal)
    for (change, why) in [
      (["kind": "popup"], "a kind it doesn't know"), (["rect": ["x": 0, "y": 0, "w": 0, "h": 10]], "no width"),
      (["rect": ["x": 0, "y": 0]], "no size"), (["id": ""], "no id"),
      (["label": String(repeating: "x", count: 201)], "a label too long"),
      (["tap_event": "go"], "an event not an object"),
    ] as [([String: Any], String)] {
      XCTAssertEqual(batch([base.merging(change) { $1 }]).refusal, BoardOps.Reason.badOp, why)
    }
  }

  func testHideAndSelect() {
    let b = batch([["op": "set_hidden", "ids": ["a"], "hidden": true], ["op": "select", "ids": ["b", "c"]]])
    XCTAssertEqual(b.ops, [.setHidden(["a"], true), .select(["b", "c"])])
    XCTAssertEqual(batch([["op": "set_hidden", "ids": ["a"]]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(batch([["op": "select"]]).refusal, BoardOps.Reason.badOp)
  }

  // MARK: The plan (stories 845, 847, 848)

  func testHiddenInkMovesWithAPushAndHidingIsAChange() {
    let strokes = [stroke("a", y: 100), stroke("b", y: 500)]
    let plan = BoardOps.plan(
      [.setHidden(["b"], true), .translateBelow(y: 300, dy: 40)], strokes: strokes, pages: 2)
    XCTAssertEqual(plan.hidden, [1: true])
    XCTAssertEqual(plan.offsets, [1: CGVector(dx: 0, dy: 40)], "hidden, it still moves")
    XCTAssertTrue(plan.changesBoard)
    let shown = BoardOps.plan([.setHidden(["b", "nope"], false)], strokes: strokes, pages: 2)
    XCTAssertEqual(shown.hidden, [1: false])
    XCTAssertEqual(shown.missingIDs, ["nope"])
  }

  func testInkHeDrawsHiddenIsDrawnHidden() {
    let new = BoardOps.NewStroke(id: "L1", points: [CGPoint(x: 1, y: 1)])
    let plan = BoardOps.plan([.addStrokes([new]), .setHidden(["L1"], true)], strokes: [], pages: 1)
    XCTAssertEqual(plan.added.first?.hidden, true)
  }

  func testSelectingAndControlsLeaveTheInkAsItIs() throws {
    let band = BoardOverlay(id: "b", kind: .band, rect: CGRect(x: 0, y: 0, width: 10, height: 10))
    let plan = BoardOps.plan(
      [.select(["a", "nope"]), .overlay(band), .removeOverlay("b")], strokes: [stroke("a", y: 10)], pages: 2)
    XCTAssertEqual(plan.select, ["a"])
    XCTAssertEqual(plan.missingIDs, ["nope"])
    XCTAssertEqual(plan.overlays, [.set(band), .remove("b")])
    XCTAssertFalse(plan.changesBoard)
  }

  func testControlsAreLaidReplacedTakenAwayAndHit() {
    var overlays = BoardOverlays()
    let low = BoardOverlay(id: "band", kind: .band, rect: CGRect(x: 0, y: 100, width: 800, height: 40), label: "a")
    let top = BoardOverlay(id: "button", kind: .button, rect: CGRect(x: 10, y: 110, width: 60, height: 20))
    overlays.apply([.set(low), .set(top)])
    XCTAssertEqual(overlays.hit(CGPoint(x: 20, y: 115))?.id, "button", "the last laid is on top")
    XCTAssertEqual(overlays.hit(CGPoint(x: 400, y: 120))?.id, "band")
    XCTAssertNil(overlays.hit(CGPoint(x: 400, y: 200)))
    XCTAssertEqual(overlays.hit(CGPoint(x: 400, y: 145), tolerance: 6)?.id, "band")
    var relabelled = low
    relabelled.label = "b"
    overlays.apply([.set(relabelled), .remove("button")])
    XCTAssertEqual(overlays.list, [relabelled], "one per id, and one taken away")
  }

  func testAHiddenStrokeIsSaidToBe() {
    let wire = WhiteboardStrokes.wire([
      WhiteboardStrokes.Stroke(id: "a", points: [.zero], hidden: true),
      WhiteboardStrokes.Stroke(id: "b", points: [.zero]),
    ])
    XCTAssertEqual(wire[0]["hidden"] as? Bool, true)
    XCTAssertNil(wire[1]["hidden"])
  }

  // MARK: What Larry hears (stories 846, 849–851)

  func testTheMarginsGestures() throws {
    let tap = try XCTUnwrap(BoardMargin.gesture(from: CGPoint(x: 20, y: 300), to: CGPoint(x: 22, y: 303), seconds: 0.1))
    XCTAssertEqual(tap.0, .tap)
    XCTAssertEqual(tap.y, 300)
    XCTAssertEqual(tap.dy, 0)
    XCTAssertEqual(
      BoardMargin.gesture(from: CGPoint(x: 20, y: 300), to: CGPoint(x: 20, y: 300), seconds: 0.8)?.0, .hold)
    let drag = try XCTUnwrap(
      BoardMargin.gesture(from: CGPoint(x: 30, y: 300), to: CGPoint(x: 90, y: 460), seconds: 0.6))
    XCTAssertEqual(drag.0, .dragEnd)
    XCTAssertEqual(drag.dy, 160)
    XCTAssertNil(BoardMargin.gesture(from: CGPoint(x: 64, y: 300), to: CGPoint(x: 64, y: 300), seconds: 0.1))
    XCTAssertNil(BoardMargin.gesture(from: CGPoint(x: -5, y: 300), to: CGPoint(x: -5, y: 300), seconds: 0.1))
  }

  func testControlsAndViewEventsOnTheWire() {
    XCTAssertEqual(
      BoardEvent.margin(gesture: .dragEnd, y: 300.04, dy: 160, t: 1).wire as NSDictionary,
      ["type": "margin", "gesture": "drag_end", "y": 300.0, "dy": 160.0, "t": 1])
    XCTAssertEqual(
      BoardEvent.viewport(y: 1200, h: 900.26, scale: 1.23456, t: 2).wire as NSDictionary,
      ["type": "viewport", "y": 1200.0, "h": 900.3, "scale": 1.235, "t": 2])
    XCTAssertEqual(
      BoardEvent.undo(label: "make room", t: 3).wire as NSDictionary, ["type": "undo", "label": "make room", "t": 3])
    XCTAssertEqual(
      BoardEvent.overlayTap(id: "band1", event: BoardMeta(["type": "make_room", "y": 400]), t: 4).wire as NSDictionary,
      [
        "type": "overlay_tap", "target_id": "band1", "overlay_id": "band1", "t": 4,
        "event": ["type": "make_room", "y": 400],
      ], "a tap the Cockpit wakes him for, naming which, with his event as written")
    XCTAssertEqual(
      BoardEvent.overlayTap(id: "chip", event: nil, t: 5).wire as NSDictionary,
      ["type": "overlay_tap", "target_id": "chip", "overlay_id": "chip", "t": 5])
  }

  func testAReportKeepsToTheCockpitsCaps() {
    let huge = BoardEvent.undo(label: String(repeating: "x", count: BoardTurnReport.maxEventBytes), t: 1)
    let small = BoardEvent.undo(label: "a", t: 2)
    var wire = BoardTurnReport(rev: 1, events: [small, huge, small], eventsDropped: 2).wire
    XCTAssertEqual((wire["events"] as? [Any])?.count, 2, "an event over 8 KB is dropped")
    XCTAssertEqual(wire["events_dropped"] as? Int, 3, "and counted with those dropped before")

    let many = (0..<250).map { BoardEvent.undo(label: "u", t: Int64($0)) }
    wire = BoardTurnReport(rev: 1, events: many).wire
    let kept = wire["events"] as? [[String: Any]]
    XCTAssertEqual(kept?.count, BoardTurnReport.maxEvents, "at most 200 to a post")
    XCTAssertEqual(kept?.first?["t"] as? Int64, 50, "the newest kept")
    XCTAssertEqual(wire["events_dropped"] as? Int, 50)

    let big = BoardEvent.undo(label: String(repeating: "y", count: 7000), t: 1)
    wire = BoardTurnReport(rev: 1, events: Array(repeating: big, count: 60)).wire
    let body = (try? JSONSerialization.data(withJSONObject: wire))?.count ?? .max
    XCTAssertLessThan(body, BoardTurnReport.maxBodyBytes, "the body stays under 256 KB")
    XCTAssertGreaterThan(wire["events_dropped"] as? Int ?? 0, 0)
  }

  // Its request: WhiteboardRequestsTests (ContextCore holds the board's HTTP requests).
  func testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt() {
    XCTAssertEqual(BoardEventsSend.answer(status: 200), .taken)
    XCTAssertEqual(BoardEventsSend.answer(status: 404), .notThere)
    XCTAssertEqual(BoardEventsSend.answer(status: 500), .away(reason: "HTTP 500"))
    XCTAssertEqual(BoardEventsSend.answer(status: nil, error: "offline"), .away(reason: "offline"))

    // Not taken: back in front of any since, for the next turn.
    var events = BoardEvents()
    events.record(.undo(label: "a", t: 1))
    let taken = events.take()
    events.record(.undo(label: "b", t: 2))
    events.restore(taken)
    XCTAssertEqual(events.take().events, [.undo(label: "a", t: 1), .undo(label: "b", t: 2)])
  }
}
