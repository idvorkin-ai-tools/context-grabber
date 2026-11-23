//  Bead context-grabber-dbku, stories 1206–1208, 1223, 1225, 1226: a jump between a board and its thread slides the other in over where
//  Igor is, goes back when it names where he came from, and brings forward a board already open elsewhere.

import XCTest

@testable import ContextCore

final class BoardChatJumpTests: XCTestCase {
  typealias Jump = BoardChatJump

  func testAJumpToSomewhereNewSlidesItIn() {
    XCTAssertEqual(Jump.how(.board("b1"), cameFrom: nil, openElsewhere: false), .slidIn)
    XCTAssertEqual(Jump.how(.thread("t1"), cameFrom: nil, openElsewhere: false), .slidIn)
    XCTAssertEqual(Jump.how(.board("b1"), cameFrom: .thread("t1"), openElsewhere: false), .slidIn)
    XCTAssertEqual(Jump.how(.thread("t1"), cameFrom: .board("b1"), openElsewhere: false), .slidIn)
  }

  /// Stories 1207, 1225: board, thread, board goes back; thread, board, thread too.
  func testAJumpToWhereHeCameFromGoesBack() {
    XCTAssertEqual(Jump.how(.board("b1"), cameFrom: .board("b1"), openElsewhere: false), .wentBack)
    XCTAssertEqual(Jump.how(.thread("t1"), cameFrom: .thread("t1"), openElsewhere: false), .wentBack)
  }

  /// Story 1207 before 1208: the board he came from is open underneath, and going back is still right.
  func testGoingBackWinsOverOpenElsewhere() {
    XCTAssertEqual(Jump.how(.board("b1"), cameFrom: .board("b1"), openElsewhere: true), .wentBack)
  }

  /// Story 1208: a board open in its own window or the whiteboard behind is brought forward, never opened twice.
  func testABoardOpenElsewhereIsBroughtForward() {
    XCTAssertEqual(Jump.how(.board("b2"), cameFrom: .board("b1"), openElsewhere: true), .broughtForward)
    XCTAssertEqual(Jump.how(.board("b2"), cameFrom: nil, openElsewhere: true), .broughtForward)
  }

  /// A thread is never "open elsewhere": several thread views are harmless.
  func testAThreadIsNeverBroughtForward() {
    XCTAssertEqual(Jump.how(.thread("t2"), cameFrom: .thread("t1"), openElsewhere: true), .slidIn)
  }

  /// Story 1226: the session log's words, pinned.
  func testTheLogSaysHowAndWhetherAListWasPassed() {
    XCTAssertEqual(Jump.How.slidIn.rawValue, "slid_in")
    XCTAssertEqual(Jump.How.wentBack.rawValue, "went_back")
    XCTAssertEqual(Jump.How.broughtForward.rawValue, "brought_forward")
    XCTAssertFalse(Jump.How.slidIn.throughList)
    XCTAssertFalse(Jump.How.wentBack.throughList)
    XCTAssertTrue(Jump.How.broughtForward.throughList)
    XCTAssertEqual(Jump.Target.board("b1").kind, "board")
    XCTAssertEqual(Jump.Target.thread("t1").id, "t1")
  }

  /// Story 1223: a board under its thread, T, with T2 pushed over T and popped, in either order the stack reports them.
  func testAPushOrPopOverTheThreadLeavesTheBoardCovered() {
    var cover = BoardCover()
    cover.appeared("T")
    cover.appeared("T2")
    XCTAssertFalse(cover.lastOver("T"), "T2 came first, then T left")
    cover = BoardCover()
    cover.appeared("T")
    XCTAssertTrue(cover.lastOver("T"), "T left first")
    cover.appeared("T2")
    XCTAssertFalse(cover.lastOver("T"), "by the time it is checked, T2 is over the board")
    cover.appeared("T")
    XCTAssertFalse(cover.lastOver("T2"), "popped back to T")
  }

  /// Story 1223: the whole stack taken down; the last screen over the board leaves and nothing comes back.
  func testTakingTheStackDownLeavesTheBoardUncovered() {
    var cover = BoardCover()
    cover.appeared("T")
    cover.appeared("B")
    cover.appeared("T3")
    XCTAssertTrue(cover.lastOver("T3"))
  }

  /// Story 1223: Back from the thread puts the board on screen, whichever is reported first.
  func testBackToTheBoardIsNotLeavingIt() {
    var cover = BoardCover()
    cover.appeared("T")
    cover.uncovered()
    XCTAssertFalse(cover.lastOver("T"))
  }
}
