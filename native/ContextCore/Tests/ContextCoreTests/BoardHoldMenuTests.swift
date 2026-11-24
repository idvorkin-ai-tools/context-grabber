import XCTest

@testable import ContextCore

/// Stories 874, 1186, 1187, 1309 (context-grabber-y4y, #1386): a held finger's menu is about what it is on.
final class BoardHoldMenuTests: XCTestCase {
  private func letter(_ id: String, x: CGFloat, y: CGFloat) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + 24), CGPoint(x: x + 10, y: y), CGPoint(x: x + 20, y: y + 24)]
    return BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: 20, height: 24), points: points, pen: 3)
  }

  /// Three letters 4 points apart: `<id>0`, `<id>1`, `<id>2`.
  private func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  func testOnInkTheMenuSelectsOrDeletesTheWordUnderTheFinger() {
    let o = BoardOutline(strokes: word("a", x: 100, y: 100) + word("b", x: 212, y: 100), headers: [])
    let menu = o.holdMenu(at: CGPoint(x: 110, y: 112), inMargin: false, slop: 22)
    XCTAssertEqual(menu.choices, [.select, .toText, .delete, .makeRoom, .paste, .makeHeader])
    XCTAssertEqual(menu.names.sorted(), ["a0", "a1", "a2"], "the word under the finger, not the line")
    XCTAssertEqual(menu.on, "ink")
  }

  func testBesideALineButOffInkTheMenuIsTheLinesAsBefore() {
    let o = BoardOutline(strokes: word("a", x: 100, y: 100), headers: [])
    let menu = o.holdMenu(at: CGPoint(x: 500, y: 112), inMargin: false, slop: 22)
    XCTAssertEqual(menu.choices, [.makeRoom, .paste, .makeHeader])
    XCTAssertEqual(menu.names, [])
    XCTAssertEqual(menu.on, "paper")
    XCTAssertEqual(
      o.holdMenu(at: CGPoint(x: 500, y: 400), inMargin: false, slop: 22).choices, [.makeRoom, .paste], "blank paper")
  }

  func testOnAHeadersRowThereIsNoDelete() {
    let o = BoardOutline(strokes: word("h", x: 100, y: 100), headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    let menu = o.holdMenu(at: CGPoint(x: 110, y: 112), inMargin: false, slop: 22)
    XCTAssertEqual(menu.choices, [.select, .toText, .makeRoom, .paste, .notHeader("h")])
    XCTAssertEqual(menu.on, "header")
  }

  func testOnAGroupOfLarrysTheMenuTakesTheWholeGroup() {
    let larry = word("g", x: 100, y: 200) + word("k", x: 300, y: 200)
    var groups: [String: String] = [:]
    for s in larry { for id in s.ids { groups[id] = "reply-1" } }
    let o = BoardOutline(strokes: larry, headers: [], groups: groups)
    let menu = o.holdMenu(at: CGPoint(x: 105, y: 212), inMargin: false, slop: 22)
    XCTAssertEqual(Array(menu.choices.prefix(3)), [.select, .toText, .delete])
    XCTAssertEqual(menu.names.sorted(), ["g0", "g1", "g2", "k0", "k1", "k2"])
    XCTAssertEqual(menu.on, "group")
  }

  func testInTheMarginTheMenuIsTheLinesOrTheOutline() {
    let o = BoardOutline(strokes: word("h", x: 100, y: 100), headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    XCTAssertEqual(
      o.holdMenu(at: CGPoint(x: 20, y: 112), inMargin: true, slop: 22).choices,
      [.foldAll, .level(1), .level(2), .level(3), .unfoldAll])
    let plain = BoardOutline(strokes: word("a", x: 100, y: 100), headers: [])
    let margin = plain.holdMenu(at: CGPoint(x: 20, y: 112), inMargin: true, slop: 22)
    XCTAssertEqual(margin.choices, [.makeRoom, .paste, .makeHeader], "the margin is never on ink")
    XCTAssertEqual(margin.names, [])
  }

  func testEachChoiceHasItsIdentifier() {
    XCTAssertEqual(
      [BoardHoldChoice.select, .toText, .delete, .makeRoom, .paste, .makeHeader, .notHeader("x"), .level(2)].map(\.id),
      ["select", "to-text", "delete", "make-room", "paste", "make-header", "not-header", "level-2"])
    XCTAssertEqual(BoardHoldChoice.toText.title, "To text", "as the web board's and the old button's word")
  }

  /// Story 1309 (#1386): a kept text is text already, so held on one the menu has no To text; a word of his beside it does.
  func testOnAKeptTextThereIsNoToText() {
    var glyphs = word("t", x: 100, y: 200)
    for i in glyphs.indices { glyphs[i].t = 1000 }
    let texts = [BoardText(id: "text-1", t: 1000, text: "hi", font: .plain, size: 24, color: "#000000", glyphs: 3)]
    let o = BoardOutline(strokes: glyphs + word("m", x: 100, y: 400), headers: [], texts: texts)
    let onText = o.holdMenu(at: CGPoint(x: 110, y: 212), inMargin: false, slop: 22)
    XCTAssertEqual(onText.names.sorted(), ["t0", "t1", "t2"], "the whole text")
    XCTAssertEqual(Array(onText.choices.prefix(2)), [.select, .delete])
    XCTAssertFalse(onText.choices.contains(.toText), "no To text on a kept text: \(onText.choices)")
    let onMine = o.holdMenu(at: CGPoint(x: 110, y: 412), inMargin: false, slop: 22)
    XCTAssertEqual(Array(onMine.choices.prefix(3)), [.select, .toText, .delete], "his own word")
  }

  /// Story 1310 (#1386): a lasso round two lines, then a finger held on one of their words: the menu is about the whole
  /// selection, To text and Delete taking all of it, and no Select, which it already is. Off the selection, as before.
  func testHeldOnTheSelectionTheMenuTakesAllOfIt() {
    let o = BoardOutline(
      strokes: word("a", x: 100, y: 100) + word("b", x: 100, y: 200) + word("c", x: 100, y: 300), headers: [])
    let lasso = ["a0", "a1", "a2", "b0", "b1", "b2"]
    let on = o.holdMenu(at: CGPoint(x: 110, y: 212), inMargin: false, slop: 22, selected: lasso)
    XCTAssertEqual(on.choices, [.toText, .delete, .makeRoom, .paste, .makeHeader])
    XCTAssertEqual(on.names.sorted(), lasso, "both lines, not the word under the finger")
    XCTAssertEqual(on.on, "selection")
    let off = o.holdMenu(at: CGPoint(x: 110, y: 312), inMargin: false, slop: 22, selected: lasso)
    XCTAssertEqual(off, o.holdMenu(at: CGPoint(x: 110, y: 312), inMargin: false, slop: 22), "the word under the finger")
    XCTAssertEqual(off.names.sorted(), ["c0", "c1", "c2"])
    let paper = o.holdMenu(at: CGPoint(x: 500, y: 600), inMargin: false, slop: 22, selected: lasso)
    XCTAssertEqual(paper.on, "paper", "blank paper is never the selection")
  }
}
