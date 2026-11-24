import XCTest

@testable import ContextCore

/// Story 569 (#1354): a board link naming a board of the Cockpit's web ink page opens that page, not the app's boards.
final class WebInkBoardTests: XCTestCase {
  func testAnInkIdIsAWebBoardByItsName() {
    XCTAssertEqual(WebInkBoard(board: "ink-wasn-t")?.name, "wasn-t")
    XCTAssertEqual(WebInkBoard(board: "ink-board-jan-1")?.name, "board-jan-1")
  }

  func testTheAppsOwnBoardsAreNot() {
    XCTAssertNil(WebInkBoard(board: "3f2c9a1e-8b7d-4c2a-9f10-2b6e5d4c3a21"), "an app board's id is a UUID")
    XCTAssertNil(WebInkBoard(board: "ink-"), "no name, no board")
    XCTAssertNil(WebInkBoard(board: "INK-x"))
    XCTAssertNil(WebInkBoard(board: "inkwell"))
  }

  func testItsPageIsTheInkPageOnTheCockpit() {
    let board = WebInkBoard(board: "ink-wasn-t")
    XCTAssertEqual(
      board?.url(cockpit: "https://c-5004.squeaker-teeth.ts.net")?.absoluteString,
      "https://c-5004.squeaker-teeth.ts.net/ink?b=wasn-t")
    XCTAssertEqual(
      board?.url(cockpit: "http://127.0.0.1:8123/")?.absoluteString, "http://127.0.0.1:8123/ink?b=wasn-t",
      "a fake Cockpit's address, with its trailing slash")
  }

  func testANameIsEscapedNotTrusted() {
    XCTAssertEqual(
      WebInkBoard(board: "ink-a b&c")?.url(cockpit: "https://cockpit.test")?.absoluteString,
      "https://cockpit.test/ink?b=a%20b%26c")
  }
}
