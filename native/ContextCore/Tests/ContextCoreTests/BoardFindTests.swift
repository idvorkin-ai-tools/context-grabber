import XCTest

@testable import ContextCore

/// #1137, story 1137: a jump to a board drawn here opens at once; another device's asks iCloud, once per jump.
final class BoardFindTests: XCTestCase {
  private func index(_ boards: BoardEntry...) -> BoardIndex {
    var index = BoardIndex()
    for board in boards { _ = index.merge(cloud: [board], device: "ipad") }
    return index
  }

  private func board(_ id: String, device: String, fetched: Int64?) -> BoardEntry {
    BoardEntry(
      id: id, title: id, created: 1, updated: 10, strokes: 1, device: device, deviceName: device, fetched: fetched)
  }

  func testThisDevicesBoardHereOpensWithoutAskingICloud() {
    var find = BoardFind()
    let here = index(board("mine", device: "ipad", fetched: 10))
    XCTAssertEqual(find.ask("mine", index: here, device: "ipad", now: 0), .ownHere)
  }

  func testAnotherDevicesBoardAsksICloudFirst() {
    var find = BoardFind()
    let here = index(board("theirs", device: "mac", fetched: 10))
    XCTAssertEqual(find.ask("theirs", index: here, device: "ipad", now: 0), .asked)
  }

  func testABoardNotHereAsksICloudFirst() {
    var find = BoardFind()
    XCTAssertEqual(find.ask("gone", index: BoardIndex(), device: "ipad", now: 0), .asked, "unknown here")
    var lost = BoardIndex()
    // A reinstall: iCloud lists this device's own board, whose drawing hasn't come down yet.
    _ = lost.merge(cloud: [board("mine", device: "ipad", fetched: nil)], device: "ipad")
    XCTAssertEqual(find.ask("mine", index: lost, device: "ipad", now: 0), .asked, "own, but its drawing isn't here")
  }

  func testAJumpAsksOnceNotAgainAsTheBoardsComeUp() {
    var find = BoardFind()
    let here = index(board("theirs", device: "mac", fetched: 10))
    XCTAssertEqual(find.ask("theirs", index: here, device: "ipad", now: 100), .asked)
    find.opens("theirs", now: 100.7)
    XCTAssertEqual(
      find.ask("theirs", index: here, device: "ipad", now: 102), .justAsked, "the boards following the link")
    XCTAssertEqual(find.ask("theirs", index: here, device: "ipad", now: 103), .asked, "the hand-off is taken once")
  }

  func testAHandOffIsForThatBoardAndOnlyForAMoment() {
    var find = BoardFind()
    let here = index(board("a", device: "mac", fetched: 10), board("b", device: "mac", fetched: 10))
    find.opens("a", now: 0)
    XCTAssertEqual(find.ask("b", index: here, device: "ipad", now: 1), .asked, "another board")
    XCTAssertEqual(find.ask("a", index: here, device: "ipad", now: 2), .asked, "the other board's find took it")
    find.opens("a", now: 0)
    XCTAssertEqual(find.ask("a", index: here, device: "ipad", now: 60), .asked, "a jump abandoned a minute ago")
  }
}
