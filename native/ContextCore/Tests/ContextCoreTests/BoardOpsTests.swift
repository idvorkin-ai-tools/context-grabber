import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class BoardOpsTests: XCTestCase {
  private func batch(_ list: [Any], board: String = "b1", rev: Int = 0, label: String = "room", key: String = "m1")
    -> BoardOps.Batch
  {
    BoardOps.batch(["board": board, "base_rev": rev, "label": label, "list": list], key: key, source: "web")!
  }

  private func stroke(_ id: String, y: CGFloat, height: CGFloat = 20, t: Int64? = nil) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [id], t: t, bounds: CGRect(x: 10, y: y, width: 100, height: height))
  }

  // MARK: The wire (stories 814–817)

  func testATranslateBelowALine() {
    let b = batch([["op": "translate", "below_y": 300, "dy": 120]])
    XCTAssertNil(b.refusal)
    XCTAssertEqual(b.ops, [.translateBelow(y: 300, dy: 120)])
    XCTAssertEqual(b.board, "b1")
    XCTAssertEqual(b.baseRev, 0)
    XCTAssertEqual(b.label, "room")
  }

  func testATranslateOfNamedStrokes() {
    let b = batch([["op": "translate", "ids": ["a", "b"], "dx": 5, "dy": -10]])
    XCTAssertEqual(b.ops, [.translateIDs(["a", "b"], dx: 5, dy: -10)])
    let onlyDy = batch([["op": "translate", "ids": ["a"], "dy": 7]])
    XCTAssertEqual(onlyDy.ops, [.translateIDs(["a"], dx: 0, dy: 7)])
  }

  func testAddTextWithItsLooks() {
    let b = batch([
      [
        "op": "add_text", "id": "t1", "x": 40, "y": 60, "text": " Plan ", "font": "plain", "size": 22,
        "color": "#ff0000",
      ]
    ])
    XCTAssertEqual(
      b.ops, [.addText(.init(id: "t1", x: 40, y: 60, text: "Plan", font: .plain, size: 22, color: 0xFF0000))])
    let plain = batch([["op": "add_text", "id": "t2", "x": 1, "y": 2, "text": "hi"]])
    XCTAssertEqual(plain.ops, [.addText(.init(id: "t2", x: 1, y: 2, text: "hi", font: .plain, size: 18))])
  }

  func testPlainTextIsAPrintGhostAtItsTopLeft() {
    let text = BoardOps.Text(id: "t1", x: 40, y: 60, text: "Plan", font: .plain, size: 22, color: 0x00FF00)
    XCTAssertEqual(text.shape.kind, .text)
    XCTAssertEqual(text.shape.face, .print)
    XCTAssertEqual(text.shape.points, [CGPoint(x: 40, y: 60)])
    XCTAssertEqual(text.shape.size, 22)
    XCTAssertEqual(text.shape.color, 0x00FF00)
    XCTAssertEqual(BoardOps.Text(id: "t", x: 0, y: 0, text: "x", font: .hand).shape.face, .hand)
  }

  func testAnUnknownOpRefusesTheWholeBatch() {
    let b = batch([["op": "translate", "below_y": 1, "dy": 1], ["op": "fold", "y": 3]])
    XCTAssertEqual(b.refusal, BoardOps.Reason.unknownOp)
    XCTAssertEqual(b.ops, [])
  }

  func testMoreThanFiftyOpsAreRefused() {
    let op: [String: Any] = ["op": "translate", "below_y": 1, "dy": 1]
    XCTAssertNil(batch(Array(repeating: op, count: 50)).refusal)
    XCTAssertEqual(batch(Array(repeating: op, count: 51)).refusal, BoardOps.Reason.tooManyOps)
  }

  func testAPushPastFourThousandPointsIsRefused() {
    XCTAssertNil(batch([["op": "translate", "below_y": 1, "dy": -4000]]).refusal)
    XCTAssertEqual(batch([["op": "translate", "below_y": 1, "dy": 4001]]).refusal, BoardOps.Reason.dyOutOfRange)
    XCTAssertEqual(batch([["op": "translate", "ids": ["a"], "dy": -4001]]).refusal, BoardOps.Reason.dyOutOfRange)
    XCTAssertEqual(
      batch([["op": "translate", "ids": ["a"], "dx": 9000, "dy": 0]]).refusal, BoardOps.Reason.dxOutOfRange)
  }

  func testAnOpMissingWhatItNeedsIsRefused() {
    XCTAssertEqual(batch([["op": "translate", "dy": 3]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(batch([["op": "translate", "ids": ["a"]]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(batch([["op": "add_text", "id": "t", "x": 1, "y": 2, "text": "  "]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(batch(["nope"]).refusal, BoardOps.Reason.badOp)
  }

  func testABatchWithoutBoardRevOrListIsRefused() {
    XCTAssertEqual(
      BoardOps.batch(["base_rev": 1, "list": []], key: "k", source: "web")?.refusal, BoardOps.Reason.badBatch)
    XCTAssertEqual(
      BoardOps.batch(["board": "b", "list": []], key: "k", source: "web")?.refusal, BoardOps.Reason.badBatch)
    XCTAssertEqual(
      BoardOps.batch(["board": "b", "base_rev": 1], key: "k", source: "web")?.refusal, BoardOps.Reason.badBatch)
    XCTAssertNil(BoardOps.batch(nil, key: "k", source: "web"))
    XCTAssertNil(BoardOps.batch("ops", key: "k", source: "web"))
  }

  func testLarrysRowCarriesItsBatchKeyedByTheMessage() throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "ok": true,
      "messages": [
        ["who": "larry", "id": "r1", "text": "Room made"],
        [
          "who": "larry", "id": "r2", "text": "",
          "ops": [
            "board": "b1", "base_rev": 4, "label": "room", "list": [["op": "translate", "below_y": 10, "dy": 50]],
          ],
        ],
      ],
    ])
    let rows = try XCTUnwrap(WhiteboardMarks.rows(body))
    XCTAssertNil(rows[0].ops)
    XCTAssertEqual(rows[1].ops?.key, "r2")
    XCTAssertEqual(rows[1].ops?.baseRev, 4)
    XCTAssertEqual(rows[1].ops?.ops, [.translateBelow(y: 10, dy: 50)])
  }

  // MARK: The applier (stories 816, 819)

  func testABatchOnTheCurrentRevisionApplies() {
    var applier = BoardOpApplier(rev: 3)
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]], rev: 3)
    XCTAssertEqual(applier.receive(b, board: "b1", editable: true, ready: true), .apply(b))
    applier.changed()
    let result = applier.applied(b, plan: BoardOps.Plan(pagesBefore: 1, pagesAfter: 1))
    XCTAssertEqual(result, BoardOps.Result(label: "room", ok: true, rev: 4))
    XCTAssertEqual(applier.lastResult, result)
  }

  func testAStaleBatchAppliesNothingAndSaysSo() {
    var applier = BoardOpApplier(rev: 5)
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]], rev: 4)
    XCTAssertEqual(
      applier.receive(b, board: "b1", editable: true, ready: true),
      .refused(BoardOps.Result(label: "room", ok: false, rev: 5, reason: "stale")))
    XCTAssertEqual(applier.lastResult?.reason, "stale")
    XCTAssertEqual(applier.rev, 5)
    // His next answer, on the board as it is, applies.
    let fresh = batch([["op": "translate", "below_y": 1, "dy": 1]], rev: 5, key: "m2")
    XCTAssertEqual(applier.receive(fresh, board: "b1", editable: true, ready: true), .apply(fresh))
  }

  func testARefusedWireIsReportedWithItsReason() {
    var applier = BoardOpApplier()
    let b = batch([["op": "spin"]])
    XCTAssertEqual(
      applier.receive(b, board: "b1", editable: true, ready: true),
      .refused(BoardOps.Result(label: "room", ok: false, rev: 0, reason: "unknown_op")))
  }

  func testAnotherBoardsBatchIsIgnored() {
    var applier = BoardOpApplier()
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]], board: "other")
    XCTAssertEqual(applier.receive(b, board: "b1", editable: true, ready: true), .ignored(why: "other_board"))
    XCTAssertNil(applier.lastResult)
  }

  func testALookOnlyBoardRefuses() {
    var applier = BoardOpApplier()
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]])
    XCTAssertEqual(
      applier.receive(b, board: "b1", editable: false, ready: true),
      .refused(BoardOps.Result(label: "room", ok: false, rev: 0, reason: "look_only")))
  }

  func testTheSameBatchNeverAppliesTwice() {
    var applier = BoardOpApplier()
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]])
    XCTAssertEqual(applier.receive(b, board: "b1", editable: true, ready: true), .apply(b))
    XCTAssertEqual(applier.receive(b, board: "b1", editable: true, ready: true), .ignored(why: "handled"))
    // Nor after the board opens again with what the ledger kept.
    var reopened = BoardOpApplier(rev: applier.rev, handled: applier.handled)
    XCTAssertEqual(reopened.receive(b, board: "b1", editable: true, ready: true), .ignored(why: "handled"))
    // A refused one isn't retried either.
    let stale = batch([["op": "translate", "below_y": 1, "dy": 1]], rev: 9, key: "m3")
    _ = reopened.receive(stale, board: "b1", editable: true, ready: true)
    XCTAssertEqual(reopened.receive(stale, board: "b1", editable: true, ready: true), .ignored(why: "handled"))
  }

  func testTheHandledListKeepsItsNewest() {
    var applier = BoardOpApplier()
    for i in 0..<(BoardOpApplier.remembered + 5) {
      _ = applier.receive(batch([], key: "k\(i)"), board: "b1", editable: true, ready: true)
    }
    XCTAssertEqual(applier.handled.count, BoardOpApplier.remembered)
    XCTAssertEqual(applier.handled.last, "k\(BoardOpApplier.remembered + 4)")
  }

  func testWithThePencilDownTheBatchWaitsThenApplies() {
    var applier = BoardOpApplier(rev: 2)
    let b = batch([["op": "translate", "below_y": 1, "dy": 1]], rev: 2)
    XCTAssertEqual(applier.receive(b, board: "b1", editable: true, ready: false), .held(replaced: nil))
    XCTAssertNil(applier.release(ready: false))
    // The stroke just drawn bumps the revision; the batch held on arrival still applies.
    applier.changed()
    XCTAssertEqual(applier.release(ready: true), b)
    XCTAssertNil(applier.held)
    XCTAssertNil(applier.release(ready: true))
  }

  func testANewerHeldBatchReplacesTheOlder() {
    var applier = BoardOpApplier()
    let first = batch([["op": "translate", "below_y": 1, "dy": 1]], label: "one", key: "m1")
    let second = batch([["op": "translate", "below_y": 1, "dy": 2]], label: "two", key: "m2")
    _ = applier.receive(first, board: "b1", editable: true, ready: false)
    XCTAssertEqual(applier.receive(second, board: "b1", editable: true, ready: false), .held(replaced: "one"))
    XCTAssertEqual(applier.lastResult?.reason, "superseded")
    XCTAssertEqual(applier.release(ready: true), second)
  }

  func testAHeldBatchDroppedWhenTheBoardCloses() {
    var applier = BoardOpApplier()
    _ = applier.receive(batch([["op": "translate", "below_y": 1, "dy": 1]]), board: "b1", editable: true, ready: false)
    XCTAssertEqual(applier.dropHeld(reason: "closed")?.reason, "closed")
    XCTAssertNil(applier.held)
    XCTAssertNil(applier.dropHeld(reason: "closed"))
  }

  func testThePencilsHold() {
    let now = ContinuousClock.now
    XCTAssertEqual(BoardOps.readiness(penDown: true, liftedAt: nil, now: now), .onLift)
    XCTAssertEqual(BoardOps.readiness(penDown: false, liftedAt: nil, now: now), .now)
    XCTAssertEqual(
      BoardOps.readiness(penDown: false, liftedAt: now - .milliseconds(200), now: now), .after(.milliseconds(300)))
    XCTAssertEqual(BoardOps.readiness(penDown: false, liftedAt: now - .milliseconds(500), now: now), .now)
  }

  func testTheLedgerKeepsRevHandledAndTexts() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "BoardOpsTests-\(UUID().uuidString)"))
    let ledger = BoardOpLedger(defaults: defaults)
    XCTAssertEqual(ledger.applier(board: "b1"), BoardOpApplier())
    var applier = BoardOpApplier(rev: 7)
    _ = applier.receive(batch([], rev: 1), board: "b1", editable: true, ready: true)
    ledger.save(applier, board: "b1")
    let back = ledger.applier(board: "b1")
    XCTAssertEqual(back.rev, 7)
    XCTAssertEqual(back.handled, ["m1"])
    XCTAssertEqual(back.lastResult?.reason, "stale")
    XCTAssertEqual(ledger.applier(board: "b2").rev, 0)
    let text = BoardText(id: "t1", t: 99, text: "Plan", font: .plain, size: 18, color: "#ba39e6")
    ledger.setTexts([text], board: "b1")
    XCTAssertEqual(ledger.texts(board: "b1"), [text])
    XCTAssertEqual(ledger.texts(board: "b2"), [])
  }

  // MARK: What moves (stories 814, 815)

  func testAPushMovesOnlyWhatStartsAtOrBelowTheLine() {
    let items = BoardOps.items(strokes: [
      stroke("above", y: 100), stroke("across", y: 290), stroke("on", y: 300), stroke("below", y: 600),
    ])
    let plan = BoardOps.plan([.translateBelow(y: 300, dy: 120)], items: items, pages: 2)
    XCTAssertEqual(plan.offsets, [2: CGVector(dx: 0, dy: 120), 3: CGVector(dx: 0, dy: 120)])
    XCTAssertEqual(plan.moved, 2)
    XCTAssertEqual(plan.pagesAfter, 2)
    XCTAssertTrue(plan.changesBoard)
  }

  func testAPushThatNeedsAPageAddsOne() {
    let items = BoardOps.items(strokes: [stroke("a", y: 100), stroke("b", y: 900, height: 40)])
    let plan = BoardOps.plan([.translateBelow(y: 500, dy: 300)], items: items, pages: 2)
    // The ink now reaches 1240, onto page 2, and a blank page follows it.
    XCTAssertEqual(plan.pagesBefore, 2)
    XCTAssertEqual(plan.pagesAfter, 3)
  }

  func testAPushBelowTheLastInkMovesNothingAndAddsPaper() {
    let items = BoardOps.items(strokes: [stroke("a", y: 100)])
    let plan = BoardOps.plan([.translateBelow(y: 900, dy: 400)], items: items, pages: 2)
    XCTAssertEqual(plan.offsets, [:])
    XCTAssertEqual(plan.moved, 0)
    XCTAssertEqual(plan.pagesAfter, 3)
    XCTAssertTrue(plan.changesBoard)
  }

  func testNamedStrokesMoveAndOnlyThose() {
    let items = BoardOps.items(strokes: [stroke("a", y: 100), stroke("b", y: 200), stroke("c", y: 300)])
    let plan = BoardOps.plan([.translateIDs(["c", "a", "zzz"], dx: 10, dy: 5)], items: items, pages: 1)
    XCTAssertEqual(plan.offsets, [0: CGVector(dx: 10, dy: 5), 2: CGVector(dx: 10, dy: 5)])
    XCTAssertEqual(plan.missingIDs, ["zzz"])
  }

  func testOpsApplyInOrderOnTheBoardTheEarlierOnesLeft() {
    // The push moves b below 400; the second push then catches it again, and the named move adds to it.
    let items = BoardOps.items(strokes: [stroke("a", y: 100), stroke("b", y: 300)])
    let plan = BoardOps.plan(
      [.translateBelow(y: 250, dy: 200), .translateBelow(y: 450, dy: 50), .translateIDs(["b"], dx: 0, dy: 1)],
      items: items, pages: 1)
    XCTAssertEqual(plan.offsets, [1: CGVector(dx: 0, dy: 251)])
    XCTAssertEqual(plan.moved, 1)
  }

  func testAStrokeWithSeveralStretchesAnswersToEachId() {
    let items = BoardOps.items(strokes: [
      BoardOps.Stroke(ids: ["left", "right"], t: 1, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
    ])
    XCTAssertEqual(
      BoardOps.plan([.translateIDs(["right"], dx: 1, dy: 0)], items: items, pages: 1).offsets,
      [0: CGVector(dx: 1, dy: 0)])
  }

  func testAKeptTextMovesWholeByItsIdOrAPush() {
    let text = BoardText(id: "label", t: 500, text: "Tg", font: .plain, size: 18, color: "#000000")
    // Its glyphs' tops differ ("T" sits higher than "g"): a push between them still moves the whole text.
    let strokes = [
      stroke("ink", y: 100), stroke("T", y: 290, t: 500), stroke("g", y: 302, t: 500), stroke("later", y: 700),
    ]
    let items = BoardOps.items(strokes: strokes, texts: [text])
    XCTAssertEqual(items.count, 3)
    XCTAssertEqual(items[1].members, [1, 2])
    XCTAssertTrue(items[1].ids.contains("label"))
    let byID = BoardOps.plan([.translateIDs(["label"], dx: 0, dy: 40)], items: items, pages: 1)
    XCTAssertEqual(byID.offsets, [1: CGVector(dx: 0, dy: 40), 2: CGVector(dx: 0, dy: 40)])
    let push = BoardOps.plan([.translateBelow(y: 295, dy: 60)], items: items, pages: 1)
    XCTAssertEqual(push.offsets.keys.sorted(), [3])
    let pushAbove = BoardOps.plan([.translateBelow(y: 280, dy: 60)], items: items, pages: 1)
    XCTAssertEqual(pushAbove.offsets.keys.sorted(), [1, 2, 3])
  }

  func testTextAloneLeavesTheBoardAsItIs() {
    let text = BoardOps.Text(id: "t1", x: 1, y: 2, text: "hi")
    let plan = BoardOps.plan([.addText(text), .addText(text)], items: [], pages: 1)
    XCTAssertEqual(plan.texts, [text])
    XCTAssertFalse(plan.changesBoard)
  }

  // MARK: A kept text goes back to Larry as one text (story 817)

  func testAKeptTextGoesBackAsOneStrokeOfKindText() {
    let glyph = { (id: String, x: CGFloat) in
      WhiteboardStrokes.Stroke(
        id: id, t: 500, color: "#ba39e6", width: 2, tool: "pen",
        points: [CGPoint(x: x, y: 60), CGPoint(x: x + 8, y: 80)])
    }
    let ink = WhiteboardStrokes.Stroke(id: "ink", t: 1, points: [.zero, CGPoint(x: 1, y: 1)])
    let text = BoardText(id: "label", t: 500, text: "Hi", font: .plain, size: 18, color: "#ba39e6")
    let wire = WhiteboardStrokes.wire([ink, glyph("g1", 40), glyph("g2", 50)], texts: [text])
    XCTAssertEqual(wire.count, 2)
    XCTAssertEqual(wire[0]["id"] as? String, "ink")
    XCTAssertEqual(wire[1]["id"] as? String, "label")
    XCTAssertEqual(wire[1]["kind"] as? String, "text")
    XCTAssertEqual(wire[1]["text"] as? String, "Hi")
    XCTAssertEqual(wire[1]["font"] as? String, "plain")
    XCTAssertEqual(wire[1]["x"] as? Double, 40)
    XCTAssertEqual(wire[1]["y"] as? Double, 60)
    XCTAssertEqual(wire[1]["w"] as? Double, 18)
    XCTAssertEqual(wire[1]["h"] as? Double, 20)
    XCTAssertEqual(wire[1]["points"] as? [[Double]], [[40, 60], [58, 80]])
    // With no kept text, the strokes go as they always have.
    XCTAssertEqual(WhiteboardStrokes.wire([ink], texts: []).count, 1)
  }

  // MARK: What Larry hears (story 818)

  func testPenAndTapEventsAccumulateUntilTaken() {
    var events = BoardEvents()
    events.pen(down: true, t: 1000)
    events.pen(down: true, t: 1001)
    events.pen(down: false, t: 1600)
    events.tap(at: CGPoint(x: 12.34, y: 56.78), target: "r1#0", t: 2000)
    events.pen(down: true, t: 3600)
    let taken = events.take()
    XCTAssertEqual(
      taken.events,
      [
        .pen(down: true, idleMs: 0, t: 1000), .pen(down: false, idleMs: 600, t: 1600),
        .tap(x: 12.34, y: 56.78, target: "r1#0", t: 2000), .pen(down: true, idleMs: 2000, t: 3600),
      ])
    XCTAssertEqual(taken.dropped, 0)
    XCTAssertEqual(events.take().events, [])
    events.pen(down: false, t: 3700)
    XCTAssertEqual(events.take().events, [.pen(down: false, idleMs: 100, t: 3700)])
  }

  func testEventsKeepTheirNewestUnderTheCap() {
    var events = BoardEvents()
    for i in 0..<(BoardEvents.cap + 7) { events.tap(at: .zero, target: nil, t: Int64(i)) }
    let taken = events.take()
    XCTAssertEqual(taken.events.count, BoardEvents.cap)
    XCTAssertEqual(taken.dropped, 7)
    XCTAssertEqual(taken.events.first, .tap(x: 0, y: 0, target: nil, t: 7))
  }

  func testEventsOnTheWire() {
    XCTAssertEqual(
      BoardEvent.pen(down: false, idleMs: 30, t: 5).wire as NSDictionary,
      ["type": "pen", "state": "up", "idle_ms": 30, "t": 5])
    XCTAssertEqual(
      BoardEvent.tap(x: 1.26, y: 2, target: nil, t: 9).wire as NSDictionary,
      ["type": "tap", "x": 1.3, "y": 2.0, "target_id": NSNull(), "t": 9])
  }

  func testTheTurnMessageCarriesRevResultAndEventsButTheStrokesDont() throws {
    let report = BoardTurnReport(
      rev: 12, opResult: BoardOps.Result(label: "room", ok: false, rev: 11, reason: "stale"),
      events: [.pen(down: true, idleMs: 0, t: 1)], eventsDropped: 2)
    let picture = WhiteboardPicture(
      board: "b1", title: "Plan", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1, pictureID: "p1",
      report: report)
    let item = InboxItem(id: "p1", kind: .image, sharedAt: 1, note: "turn", thread: "t1", whiteboard: picture)
    let message = try ChatSend.messageRequest(item, attachment: "r", cockpit: "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(message.httpBody)) as? [String: Any])
    XCTAssertEqual(body["rev"] as? Int, 12)
    XCTAssertEqual(
      body["op_result"] as? NSDictionary, ["label": "room", "ok": false, "rev": 11, "reason": "stale"] as NSDictionary)
    XCTAssertEqual((body["events"] as? [[String: Any]])?.count, 1)
    XCTAssertEqual(body["events_dropped"] as? Int, 2)
    XCTAssertEqual(body["board"] as? String, "b1")

    let strokes = try WhiteboardStrokes.request(picture: picture, strokes: [], cockpit: "https://c.example")
    let strokesBody = try XCTUnwrap(
      JSONSerialization.jsonObject(with: XCTUnwrap(strokes.httpBody)) as? [String: Any])
    XCTAssertNil(strokesBody["rev"])
    XCTAssertNil(strokesBody["events"])

    // An outbox item keeps its report, and one written before reports still reads.
    let back = try JSONDecoder().decode(WhiteboardPicture.self, from: JSONEncoder().encode(picture))
    XCTAssertEqual(back.report, report)
    let old = try JSONDecoder().decode(
      WhiteboardPicture.self,
      from: Data(
        #"{"board":"b1","picture_id":"p","title":"T","frame":{"x":0,"y":0,"w":1,"h":1,"scale":1}}"#.utf8))
    XCTAssertNil(old.report)
  }

  // MARK: The source (story 819)

  func testTheWebSourceOffersTheNewestBatchFirstThenEachNewOne() {
    let ops = { (key: String) in self.batch([], key: key) }
    var source = WebBoardOpSource()
    XCTAssertEqual(source.name, "web")
    let first = [
      WhiteboardMarks.Row(id: "r1", ops: ops("r1")), WhiteboardMarks.Row(id: "r2", ops: ops("r2")),
      WhiteboardMarks.Row(id: "r3", text: "words"),
    ]
    XCTAssertEqual(source.batches(from: .rows(first)).map(\.key), ["r2"])
    XCTAssertEqual(source.batches(from: .rows(first)).map(\.key), [])
    let later =
      first + [
        WhiteboardMarks.Row(id: "r4", ops: ops("r4")), WhiteboardMarks.Row(id: "r5", ops: ops("r5")),
      ]
    XCTAssertEqual(source.batches(from: .rows(later)).map(\.key), ["r4", "r5"])
    XCTAssertEqual(source.batches(from: .event(.pen(down: true, idleMs: 0, t: 1))), [])
  }
}
