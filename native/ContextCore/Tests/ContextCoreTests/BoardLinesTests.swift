//  Story 410 (#915): a new board opens with the grid on; a saved choice, or none saved (story 888), is kept.

import ContextCore
import XCTest

final class BoardLinesTests: XCTestCase {
  private func fresh() -> (BoardLines, UserDefaults) {
    let suite = "board-lines-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (BoardLines(defaults: defaults), defaults)
  }

  func testANewBoardOpensWithTheGrid() {
    let (lines, _) = fresh()
    lines.set(.none, board: "other")
    lines.startNew("new")
    XCTAssertEqual(lines.choice("new"), .grid)
    XCTAssertEqual(lines.choice("other"), .none, "another board's choice is its own")
  }

  func testABoardMadeBeforeWithNothingSavedHasNoGrid() {
    let (lines, _) = fresh()
    XCTAssertEqual(lines.choice("old"), .none)
  }

  func testASavedChoiceIsKept() {
    let (lines, defaults) = fresh()
    lines.startNew("b")
    lines.set(.none, board: "b")
    XCTAssertEqual(BoardLines(defaults: defaults).choice("b"), .none, "turned off stays off")
    lines.set(.ruled, board: "b")
    XCTAssertEqual(BoardLines(defaults: defaults).choice("b"), .ruled, "ruled lines take the grid's place")
  }

  func testTheKeysBoardsAlreadyHaveAreRead() {
    let (lines, defaults) = fresh()
    defaults.set(true, forKey: "whiteboard_grid_old")
    defaults.set(true, forKey: "whiteboard_ruled_lined")
    XCTAssertEqual(lines.choice("old"), .grid)
    XCTAssertEqual(lines.choice("lined"), .ruled)
  }

  func testTheUITestsHookStartsABoardBare() {
    let (lines, _) = fresh()
    lines.startNew("bare", bare: true)
    XCTAssertEqual(lines.choice("bare"), .none)
  }

  func testAForgottenBoardLeavesNothingSaved() {
    let (lines, defaults) = fresh()
    lines.startNew("gone")
    lines.startNew("kept")
    lines.forget("gone")
    XCTAssertNil(defaults.object(forKey: BoardLines.gridKey("gone")))
    XCTAssertNil(defaults.object(forKey: BoardLines.ruledKey("gone")))
    XCTAssertEqual(lines.choice("kept"), .grid, "only that board's choice goes")
  }
}
