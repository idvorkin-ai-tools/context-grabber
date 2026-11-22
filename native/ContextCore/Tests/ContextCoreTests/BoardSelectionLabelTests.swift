//  Story 1108 (#1045): what the label on a selection says, for each thing the board can hold.

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

  func testVoiceOverReadsItAsSelected() throws {
    let picked = [board[0]]
    let label = BoardSelectionLabel.label(
      picked: picked, board: board, texts: texts, metas: try metas(), connectReady: false)
    XCTAssertEqual(label?.spoken, "Selected: Ink, To text")
    XCTAssertEqual(label?.kind, .ink)
  }
}
