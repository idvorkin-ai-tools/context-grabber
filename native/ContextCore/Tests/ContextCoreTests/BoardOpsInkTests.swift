import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Step 2 of Larry's board ops (stories 840–844): his ink, erasing and replacing by name, his notes and groups, and what
/// Larry hears when Igor changes the ink.
final class BoardOpsInkTests: XCTestCase {
  private func batch(_ list: [Any]) -> BoardOps.Batch {
    BoardOps.batch(["board": "b1", "base_rev": 0, "label": "tidy", "list": list], key: "m1", source: "web")!
  }

  private func stroke(_ id: String, y: CGFloat, height: CGFloat = 20) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: 10, y: y, width: 100, height: height))
  }

  private let line: [Any] = [[10, 500], [200, 500]]

  // MARK: The wire

  func testAddStrokesWithTheirLooksAndNotes() throws {
    let b = batch([
      [
        "op": "add_strokes",
        "strokes": [
          [
            "id": "L1", "points": line, "width": 4, "color": "#ff0000",
            "meta": ["group": "g7", "kind": "text", "n": 2],
          ],
          ["id": "L2", "points": [[1, 2]]],
        ],
      ]
    ])
    XCTAssertNil(b.refusal)
    guard case .addStrokes(let strokes) = try XCTUnwrap(b.ops.first) else { return XCTFail("\(b.ops)") }
    XCTAssertEqual(strokes.map(\.id), ["L1", "L2"])
    XCTAssertEqual(strokes[0].points, [CGPoint(x: 10, y: 500), CGPoint(x: 200, y: 500)])
    XCTAssertEqual(strokes[0].width, 4)
    XCTAssertEqual(strokes[0].color, 0xFF0000)
    XCTAssertEqual(strokes[0].meta?.group, "g7")
    XCTAssertEqual(strokes[1].width, WhiteboardTurn.defaultPen, "no width: a kept mark's pen")
    XCTAssertNil(strokes[1].meta)
  }

  func testAPenTooThinOrTooWideDrawsWithinReach() throws {
    let b = batch([
      [
        "op": "add_strokes",
        "strokes": [["id": "a", "points": line, "width": 0.1], ["id": "b", "points": line, "width": 90]],
      ]
    ])
    guard case .addStrokes(let strokes) = try XCTUnwrap(b.ops.first) else { return XCTFail() }
    XCTAssertEqual(strokes.map(\.width), [WhiteboardTurn.thinnestPen, WhiteboardTurn.widestPen])
  }

  func testDeleteSetMetaAndReplace() {
    let b = batch([
      ["op": "delete", "ids": ["a", "b"]],
      ["op": "set_meta", "ids": ["c"], "meta": ["group": "g1"]],
      ["op": "replace", "ids": ["d"], "strokes": [["id": "D2", "points": line]]],
    ])
    XCTAssertNil(b.refusal)
    XCTAssertEqual(b.ops.count, 3)
    XCTAssertEqual(b.ops[0], .delete(["a", "b"]))
    XCTAssertEqual(b.ops[1], .setMeta(["c"], BoardMeta(["group": "g1"])!))
    guard case .replace(let ids, let new) = b.ops[2] else { return XCTFail() }
    XCTAssertEqual(ids, ["d"])
    XCTAssertEqual(new.map(\.id), ["D2"])
  }

  func testInkTheCockpitWouldRefuseIsRefusedHere() {
    let stroke = { (extra: [String: Any]) in
      self.batch([["op": "add_strokes", "strokes": [["id": "a", "points": self.line].merging(extra) { $1 }]]]).refusal
    }
    XCTAssertEqual(stroke(["id": "has space"]), BoardOps.Reason.badOp, "a name the strokes endpoint refuses")
    XCTAssertEqual(stroke(["id": String(repeating: "x", count: 65)]), BoardOps.Reason.badOp)
    XCTAssertEqual(stroke(["points": []]), BoardOps.Reason.badOp, "no points")
    XCTAssertEqual(stroke(["points": [[1]]]), BoardOps.Reason.badOp)
    XCTAssertEqual(stroke(["points": [[1, 1e12]]]), BoardOps.Reason.badOp, "off the board")
    XCTAssertEqual(stroke(["meta": "group"]), BoardOps.Reason.badOp, "notes are an object")
    XCTAssertEqual(
      stroke(["points": Array(repeating: [1, 1], count: WhiteboardStrokes.maxPoints + 1)]),
      BoardOps.Reason.tooManyPoints)
    let many = Array(repeating: ["id": "a", "points": line] as [String: Any], count: BoardOps.maxNewStrokes + 1)
    XCTAssertEqual(batch([["op": "add_strokes", "strokes": many]]).refusal, BoardOps.Reason.tooManyStrokes)
    XCTAssertEqual(batch([["op": "delete", "ids": "a"]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(batch([["op": "set_meta", "ids": ["a"]]]).refusal, BoardOps.Reason.badOp)
    XCTAssertEqual(
      batch([["op": "add_text", "id": "a b", "x": 1, "y": 1, "text": "x"]]).refusal, BoardOps.Reason.badOp,
      "a text's id goes back in the strokes too")
  }

  func testNotesAreKeptAsWritten() throws {
    let meta = try XCTUnwrap(BoardMeta(["kind": "text", "group": "g7", "nested": ["a": [1, 2]]]))
    XCTAssertEqual(meta.group, "g7")
    XCTAssertEqual(
      meta.object as? NSDictionary, ["kind": "text", "group": "g7", "nested": ["a": [1, 2]]] as NSDictionary)
    XCTAssertEqual(BoardMeta(["b": 1, "a": 2]), BoardMeta(["a": 2, "b": 1]), "the same notes compare equal")
    XCTAssertNil(BoardMeta(["group": ""])?.group)
    XCTAssertNil(BoardMeta([1, 2]))
  }

  // MARK: The plan (stories 840–842)

  func testLarrysInkJoinsTheBoardWhereLaterOpsLeaveIt() {
    let strokes = [stroke("a", y: 100), stroke("b", y: 600)]
    let new = BoardOps.NewStroke(id: "L1", points: [CGPoint(x: 0, y: 700), CGPoint(x: 50, y: 720)])
    let plan = BoardOps.plan(
      [.addStrokes([new]), .translateBelow(y: 650, dy: 30)], strokes: strokes, pages: 2)
    XCTAssertEqual(plan.added.map(\.id), ["L1"])
    XCTAssertEqual(plan.added.first?.points, [CGPoint(x: 0, y: 730), CGPoint(x: 50, y: 750)])
    XCTAssertEqual(plan.offsets, [:], "b's top is above the line")
    XCTAssertTrue(plan.changesBoard)
  }

  func testDeleteByNameAndReplace() {
    let strokes = [stroke("a", y: 100), stroke("b", y: 200), stroke("c", y: 300)]
    let clean = BoardOps.NewStroke(id: "C2", points: [CGPoint(x: 0, y: 300), CGPoint(x: 90, y: 300)])
    let plan = BoardOps.plan(
      [.delete(["a", "nope"]), .replace(["b", "c"], with: [clean]), .translateIDs(["C2"], dx: 0, dy: 10)],
      strokes: strokes, pages: 1)
    XCTAssertEqual(plan.erase, [0, 1, 2])
    XCTAssertEqual(plan.added.first?.points.first, CGPoint(x: 0, y: 310), "a later move moves what he drew")
    XCTAssertEqual(plan.missingIDs, ["nope"])
    XCTAssertEqual(plan.offsets, [:], "erased strokes don't move")
  }

  func testAStrokeDrawnAgainUnderItsNameReplacesIt() {
    let again = BoardOps.NewStroke(id: "a", points: [CGPoint(x: 1, y: 1)])
    let plan = BoardOps.plan([.addStrokes([again])], strokes: [stroke("a", y: 100)], pages: 1)
    XCTAssertEqual(plan.erase, [0], "the Cockpit takes a name once")
    XCTAssertEqual(plan.added.map(\.id), ["a"])
  }

  func testLarrysOwnInkCanBeErasedInTheSameBatch() {
    let new = BoardOps.NewStroke(id: "L1", points: [CGPoint(x: 1, y: 1)])
    let plan = BoardOps.plan([.addStrokes([new]), .delete(["L1"])], strokes: [], pages: 1)
    XCTAssertEqual(plan.added, [])
    XCTAssertFalse(plan.changesBoard)
  }

  func testAGroupMovesWholeAndAnswersToItsName() throws {
    let group = try XCTUnwrap(BoardMeta(["group": "g7", "kind": "label"]))
    var metas = BoardStrokeMeta()
    metas.set(group, for: "word")
    metas.set(group, for: "underline")
    let strokes = [stroke("word", y: 280), stroke("underline", y: 310), stroke("other", y: 600)]
    // The group's top is above the line: it stays whole, though its underline is below.
    let push = BoardOps.plan([.translateBelow(y: 300, dy: 50)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(push.offsets.keys.sorted(), [2])
    let byGroup = BoardOps.plan([.translateIDs(["g7"], dx: 5, dy: 0)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(byGroup.offsets.keys.sorted(), [0, 1])
    // A stroke of the group moves the group.
    let byStroke = BoardOps.plan([.translateIDs(["underline"], dx: 5, dy: 0)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(byStroke.offsets.keys.sorted(), [0, 1])
    // Erasing a stroke of it erases that stroke; erasing the group erases all of it.
    XCTAssertEqual(BoardOps.plan([.delete(["word"])], strokes: strokes, metas: metas, pages: 1).erase, [0])
    XCTAssertEqual(BoardOps.plan([.delete(["g7"])], strokes: strokes, metas: metas, pages: 1).erase, [0, 1])
    // His new stroke with the group's note joins it.
    let dot = BoardOps.NewStroke(id: "dot", points: [CGPoint(x: 0, y: 340)], meta: group)
    let joined = BoardOps.plan(
      [.addStrokes([dot]), .translateIDs(["g7"], dx: 0, dy: 10)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(joined.offsets.keys.sorted(), [0, 1])
    XCTAssertEqual(joined.added.first?.points, [CGPoint(x: 0, y: 350)])
  }

  func testNotesSetByNameAndForgottenWithTheirStrokes() throws {
    let note = try XCTUnwrap(BoardMeta(["kind": "arrow"]))
    let strokes = [BoardOps.Stroke(ids: ["s1", "s2"], t: nil, bounds: .zero), stroke("t", y: 9)]
    let plan = BoardOps.plan([.setMeta(["s1", "t", "zz"], note), .delete(["t"])], strokes: strokes, pages: 1)
    XCTAssertEqual(plan.metas["s1"], note)
    XCTAssertEqual(plan.metas["s2"], note, "a stroke rubbed into stretches gets it on each")
    XCTAssertNil(plan.metas["t"], "erased, its notes go")
    XCTAssertEqual(plan.missingIDs, ["zz"])
    XCTAssertTrue(plan.changesBoard)
    XCTAssertFalse(BoardOps.plan([.setMeta(["s1"], note)], strokes: strokes, pages: 2).changesBoard)
  }

  func testLarrysStrokesGoBackUnderHisNamesWithHisNotes() throws {
    let points = [CGPoint(x: 1, y: 1), CGPoint(x: 9, y: 9)]
    let hash = WhiteboardStrokes.id(points: points, color: "#ba39e6", t: 5)
    var ids = BoardStrokeIDs()
    ids.name(hash, as: "L1")
    var metas = BoardStrokeMeta()
    metas.set(try XCTUnwrap(BoardMeta(["group": "g7"])), for: "L1")
    let drawn = WhiteboardStrokes.Stroke(id: hash, t: 5, color: "#ba39e6", points: points)
    let wire = WhiteboardStrokes.wire(ids.named([drawn]), texts: [], metas: metas)
    XCTAssertEqual(wire.first?["id"] as? String, "L1")
    XCTAssertEqual(wire.first?["meta"] as? NSDictionary, ["group": "g7"] as NSDictionary)
  }

  func testTheNotesAreKeptPerBoard() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "BoardOpsInkTests-\(UUID().uuidString)"))
    let ledger = BoardOpLedger(defaults: defaults)
    var metas = BoardStrokeMeta()
    metas.set(try XCTUnwrap(BoardMeta(["group": "g"])), for: "a")
    ledger.setStrokeMeta(metas, board: "b1")
    XCTAssertEqual(ledger.strokeMeta(board: "b1")["a"]?.group, "g")
    XCTAssertTrue(ledger.strokeMeta(board: "b2").isEmpty)
  }

  // MARK: What Larry hears (stories 843, 844)

  func testIgorsInkChangeIsToldByName() {
    var ink = BoardInk(hashes: ["e1": ["h1"], "e2": ["h2"], "e3": ["h3"]])
    var ids = BoardStrokeIDs()
    ids.name("h2", as: "L2")
    // e4 drawn, e1 erased, e2 lasso-moved (one stretch, a new hash), e3 rubbed into two stretches.
    let change = ink.changed(
      updated: ["e4": ["h4"], "e2": ["h2-moved"], "e3": ["h3a", "h3b"]], removed: ["e1"], ids: &ids)
    XCTAssertEqual(change.added, ["h3a", "h3b", "h4"])
    XCTAssertEqual(change.erased, ["h3", "h1"])
    XCTAssertEqual(change.moved, ["L2"], "a moved stroke keeps its name")
    XCTAssertEqual(ids.stable("h2-moved"), "L2")
    XCTAssertEqual(ink.hashes["e2"], ["h2-moved"])
    XCTAssertNil(ink.hashes["e1"])
    // Told once: the same state again is no change.
    XCTAssertTrue(ink.changed(updated: ["e2": ["h2-moved"]], removed: [], ids: &ids).isEmpty)
  }

  func testInkEventsOnTheWire() {
    XCTAssertEqual(
      BoardEvent.strokesChanged(added: ["a"], erased: ["b"], moved: ["c"], rev: 4, t: 9).wire as NSDictionary,
      ["type": "strokes_changed", "added": ["a"], "erased": ["b"], "moved": ["c"], "rev": 4, "t": 9])
    XCTAssertEqual(
      BoardEvent.selection(ids: ["a", "b"], t: 3).wire as NSDictionary,
      ["type": "selection", "ids": ["a", "b"], "t": 3])
    var events = BoardEvents()
    events.record(.selection(ids: [], t: 1))
    XCTAssertEqual(events.take().events, [.selection(ids: [], t: 1)])
  }
}
