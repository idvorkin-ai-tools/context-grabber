//  Stories 1103 and 1113: the board's microphone rows and when *Find microphones* shows.

import ContextCore
import XCTest

final class BoardMicMenuTests: XCTestCase {
  private let pocket = BoardMicMenu.Microphone(id: "pocket", name: "Pocket Mic")
  private let ipad = BoardMicMenu.Microphone(id: "builtin", name: "iPad Microphone")

  func testAutomaticComesFirstAndThePickIsTicked() {
    let menu = BoardMicMenu(
      microphones: [ipad, pocket], picked: "pocket", savedName: "Saved microphone", micOpen: false, busy: false)
    XCTAssertEqual(menu.rows.map(\.name), ["Automatic", "iPad Microphone", "Pocket Mic"])
    XCTAssertEqual(menu.rows.filter(\.ticked).map(\.pick), ["pocket"])
  }

  func testAutomaticIsTickedWithNoPick() {
    let menu = BoardMicMenu(microphones: [pocket], picked: nil, savedName: "Automatic", micOpen: false, busy: false)
    XCTAssertEqual(menu.rows.filter(\.ticked).map(\.name), ["Automatic"])
    XCTAssertNil(menu.rows[0].pick)
  }

  /// Closed after a relaunch the board has read no microphones yet: the kept pick still shows, ticked, by its name.
  func testAPickNotReadSinceARelaunchStillShowsTicked() {
    let menu = BoardMicMenu(
      microphones: [], picked: "pocket", savedName: "Saved microphone", micOpen: false, busy: false)
    XCTAssertEqual(menu.rows.map(\.name), ["Automatic", "Saved microphone"])
    XCTAssertEqual(menu.rows.map(\.ticked), [false, true])
  }

  /// Story 1113: reading the microphones is for a closed mic with nothing on its way; an open one read them at opening.
  func testFindShowsOnlyWithTheMicClosedAndIdle() {
    func find(open: Bool, busy: Bool) -> Bool {
      BoardMicMenu(microphones: [pocket], picked: nil, savedName: "Automatic", micOpen: open, busy: busy).canFind
    }
    XCTAssertTrue(find(open: false, busy: false))
    XCTAssertFalse(find(open: true, busy: false))
    XCTAssertFalse(find(open: false, busy: true))
  }

  func testRowIdsAreDistinct() {
    let menu = BoardMicMenu(
      microphones: [ipad, pocket], picked: nil, savedName: "Automatic", micOpen: true, busy: false)
    XCTAssertEqual(Set(menu.rows.map(\.id)).count, menu.rows.count)
  }
}
