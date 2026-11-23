//  Story 1095 (#1045): what the label on a selection says, for each thing the board can hold.

import ContextCore
import XCTest

final class BoardSelectionLabelTests: XCTestCase {
  private typealias Piece = BoardSelectionLabel.Piece

  private let texts = [BoardText(id: "hi", t: 100, text: "hi", font: .plain, size: 24, color: "#000000", glyphs: 2)]

  private func metas() throws -> BoardStrokeMeta {
    var metas = BoardStrokeMeta()
    metas.set(try XCTUnwrap(BoardMeta(["group": "box"])), for: "g1")
    metas.set(try XCTUnwrap(BoardMeta(["group": "box"])), for: "g2")
    metas.set(try XCTUnwrap(BoardMeta(["group": "c1-to"])), for: "w1")
    let arrow = BoardConnector(from: "hi", to: "c1-to", fromSide: .right, toSide: .left, by: "igor")
    metas.set(arrow.meta(over: nil), for: "c1")
    return metas
  }

  private let board = [
    Piece(names: ["i1"], t: 1), Piece(names: ["i2"], t: 2),
    Piece(names: ["h1"], t: 100), Piece(names: ["h2"], t: 100),
    Piece(names: ["g1"], t: 3), Piece(names: ["g2"], t: 4),
    Piece(names: ["w1"], t: 5), Piece(names: ["c1"], t: 6),
  ]

  private func label(_ names: [String], connectReady: Bool = false) throws -> String? {
    let picked = board.filter { $0.names.contains(where: names.contains) }
    return BoardSelectionLabel.label(
      picked: picked, board: board, texts: texts, metas: try metas(), connectReady: connectReady)?.text
  }

  func testNothingPickedHasNoLabel() throws {
    XCTAssertNil(try label([]))
  }

  func testPlainInkOffersToText() throws {
    XCTAssertEqual(try label(["i1", "i2"]), "Ink · To text")
  }

  func testAWholeKeptTextIsRewordedWithATapAndSaysAConnectorFollowsIt() throws {
    XCTAssertEqual(try label(["h1", "h2"]), "Text · tap to reword · a connector follows it")
  }

  func testPartOfATextSaysErasingItLeavesInk() throws {
    XCTAssertEqual(try label(["h1"]), "Part of a text · erasing it leaves ink")
  }

  func testATextErasedInPartIsInkOnceTheBoardForgetsIt() throws {
    let picked = [Piece(names: ["h1"], t: 100)]
    let left = BoardSelectionLabel.label(
      picked: picked, board: picked, texts: [], metas: try metas(), connectReady: false)
    XCTAssertEqual(left?.text, "Ink · To text")
  }

  func testAGroupMovesAsOneAndPartOfItSaysSo() throws {
    XCTAssertEqual(try label(["g1", "g2"]), "Group · moves as one")
    XCTAssertEqual(try label(["g1"]), "Part of a group · erasing it leaves ink")
  }

  func testAWordAConnectorEndsOnSaysTheConnectorFollowsIt() throws {
    XCTAssertEqual(try label(["w1"]), "Group · moves as one · a connector follows it")
  }

  func testAConnectorFollowsItsEnds() throws {
    XCTAssertEqual(try label(["c1"]), "Connector · follows its two ends")
  }

  func testADrawnArrowConnectCanJoinSaysConnect() throws {
    XCTAssertEqual(try label(["i1"], connectReady: true), "Arrow · Connect")
  }

  func testThingsTogetherAndInkWithThings() throws {
    XCTAssertEqual(try label(["h1", "h2", "g1", "g2"]), "2 things · move together")
    XCTAssertEqual(try label(["i1", "h1", "h2"]), "Ink and a text")
    XCTAssertEqual(try label(["i1", "g1", "c1"]), "Ink and 2 things")
  }

  /// Bead context-grabber-owy: a group of Larry's that holds kept texts (notes under each text's id, #937) is still
  /// one group, so all of it reads Group, not "2 things".
  private func groupedTexts() throws -> (board: [Piece], texts: [BoardText], metas: BoardStrokeMeta) {
    let texts = [
      BoardText(id: "lbl", t: 200, text: "box", font: .plain, size: 24, color: "#000000", glyphs: 2),
      BoardText(id: "a", t: 300, text: "a", font: .plain, size: 24, color: "#000000", glyphs: 1),
      BoardText(id: "b", t: 400, text: "b", font: .plain, size: 24, color: "#000000", glyphs: 1),
      BoardText(id: "solo", t: 500, text: "solo", font: .plain, size: 24, color: "#000000", glyphs: 1),
    ]
    var metas = BoardStrokeMeta()
    for name in ["b1", "b2", "lbl"] { metas.set(try XCTUnwrap(BoardMeta(["group": "card"])), for: name) }
    for name in ["a", "b"] { metas.set(try XCTUnwrap(BoardMeta(["group": "pair"])), for: name) }
    let board = [
      Piece(names: ["b1"], t: 10), Piece(names: ["b2"], t: 11),
      Piece(names: ["l1"], t: 200), Piece(names: ["l2"], t: 200),
      Piece(names: ["a1"], t: 300), Piece(names: ["b1g"], t: 400),
      Piece(names: ["s1"], t: 500), Piece(names: ["i9"], t: 20),
    ]
    return (board, texts, metas)
  }

  private func groupedLabel(_ names: [String], metas extra: BoardStrokeMeta? = nil) throws -> String? {
    let (board, texts, metas) = try groupedTexts()
    let picked = board.filter { $0.names.contains(where: names.contains) }
    return BoardSelectionLabel.label(
      picked: picked, board: board, texts: texts, metas: extra ?? metas, connectReady: false)?.text
  }

  func testAGroupOfABoxAndItsLabelReadsGroup() throws {
    XCTAssertEqual(try groupedLabel(["b1", "b2", "l1", "l2"]), "Group · moves as one")
  }

  func testAGroupOfTwoLabelsReadsGroup() throws {
    XCTAssertEqual(try groupedLabel(["a1", "b1g"]), "Group · moves as one")
  }

  func testATextAloneStillReadsTextAndPartOfAGroupedOneIsPartOfTheGroup() throws {
    XCTAssertEqual(try groupedLabel(["s1"]), "Text · tap to reword")
    XCTAssertEqual(try groupedLabel(["l1", "l2"]), "Part of a group · erasing it leaves ink")
    XCTAssertEqual(try groupedLabel(["i9", "a1", "b1g"]), "Ink and a group")
  }

  func testAConnectorOnATextInAGroupFollowsTheWholeGroup() throws {
    var metas = try groupedTexts().metas
    let arrow = BoardConnector(from: "lbl", to: "solo", fromSide: .right, toSide: .left, by: "igor")
    metas.set(arrow.meta(over: nil), for: "c9")
    let (board, texts, _) = try groupedTexts()
    let all = board + [Piece(names: ["c9"], t: 30)]
    let picked = all.filter { ["b1", "b2", "l1", "l2"].contains($0.names[0]) }
    let label = BoardSelectionLabel.label(picked: picked, board: all, texts: texts, metas: metas, connectReady: false)
    XCTAssertEqual(label?.text, "Group · moves as one · a connector follows it")
  }

  func testVoiceOverReadsItAsSelected() throws {
    let picked = [board[0]]
    let label = BoardSelectionLabel.label(
      picked: picked, board: board, texts: texts, metas: try metas(), connectReady: false)
    XCTAssertEqual(label?.spoken, "Selected: Ink, To text")
    XCTAssertEqual(label?.kind, .ink)
  }
}
