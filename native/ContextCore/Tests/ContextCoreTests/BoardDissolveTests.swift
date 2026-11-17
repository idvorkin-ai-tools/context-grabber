import XCTest

@testable import ContextCore

/// Story 854: erasing part of a group or a kept text leaves plain ink.
final class BoardDissolveTests: XCTestCase {
  private func stroke(_ id: String, t: Int64? = nil) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [id], t: t, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
  }

  func testPartOfAGroupErasedLeavesPlainInkWithItsOtherNotes() throws {
    var metas = BoardStrokeMeta()
    metas.set(try XCTUnwrap(BoardMeta(["group": "box", "role": "edge"])), for: "a")
    metas.set(try XCTUnwrap(BoardMeta(["group": "box"])), for: "b")
    metas.set(try XCTUnwrap(BoardMeta(["group": "box"])), for: "c")
    metas.set(try XCTUnwrap(BoardMeta(["group": "other"])), for: "d")
    var texts: [BoardText] = []
    let gone = BoardDissolve.dissolve(
      erased: ["c"], live: [stroke("a"), stroke("b"), stroke("d")], metas: &metas, texts: &texts)
    XCTAssertEqual(gone, ["box"])
    XCTAssertNil(metas.groups["a"])
    XCTAssertNil(metas.groups["b"])
    XCTAssertEqual(metas.groups["d"], "other", "another group is left alone")
    XCTAssertEqual(metas["a"]?.object as? NSDictionary, ["role": "edge"], "his other notes stay")
    XCTAssertNil(metas["b"], "a note that was only the group goes")
    XCTAssertEqual(BoardOps.items(strokes: [stroke("a"), stroke("b")], groups: metas.groups).count, 2, "one by one")
  }

  func testAWholeGroupErasedIsAnOrdinaryErase() throws {
    var metas = BoardStrokeMeta()
    metas.set(try XCTUnwrap(BoardMeta(["group": "box"])), for: "a")
    var texts: [BoardText] = []
    XCTAssertEqual(BoardDissolve.dissolve(erased: ["a"], live: [stroke("z")], metas: &metas, texts: &texts), [])
    XCTAssertEqual(BoardDissolve.dissolve(erased: [], live: [], metas: &metas, texts: &texts), [])
  }

  func testAKeptTextMissingALetterIsForgotten() {
    var metas = BoardStrokeMeta()
    var texts = [
      BoardText(id: "hi", t: 100, text: "hi", font: .plain, size: 24, color: "#000000", glyphs: 3),
      BoardText(id: "ok", t: 200, text: "ok", font: .plain, size: 24, color: "#000000", glyphs: 2),
      BoardText(id: "old", t: 300, text: "old", font: .plain, size: 24, color: "#000000"),
    ]
    let live = [
      stroke("h1", t: 100), stroke("h2", t: 101), stroke("o1", t: 200), stroke("o2", t: 200), stroke("x", t: 300),
    ]
    let gone = BoardDissolve.dissolve(erased: ["h3"], live: live, metas: &metas, texts: &texts)
    XCTAssertEqual(gone, ["hi"])
    XCTAssertEqual(texts.map(\.id), ["ok", "old"], "whole texts stay, and one kept before the board counted")
    XCTAssertEqual(
      BoardEvent.strokesChanged(added: [], erased: ["h3"], moved: [], rev: 2, t: 1, dissolved: gone).wire["dissolved"]
        as? [String], ["hi"])
    XCTAssertNil(BoardEvent.strokesChanged(added: [], erased: [], moved: [], rev: 2, t: 1).wire["dissolved"])
  }
}
