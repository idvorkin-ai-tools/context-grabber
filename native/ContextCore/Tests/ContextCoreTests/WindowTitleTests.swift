import XCTest

@testable import ContextCore

/// Story 233: a window's name says what's open in it, in the Cockpit's words (its story 211, `pageTitle` and
/// `titleDetail` in cockpit_core.js, whose cases in test_core.cjs these mirror).
final class WindowTitleTests: XCTestCase {
  func testAWindowWithNothingOpenInItIsItsTilesName() {
    XCTAssertEqual(WindowTitle.name(tile: "Chat"), "Chat")
    XCTAssertEqual(WindowTitle.name(tile: "Chat", detail: ""), "Chat")
    XCTAssertEqual(WindowTitle.name(tile: "Chat", detail: "  \n "), "Chat")
  }

  func testWhatIsOpenFollowsThePlaceAfterADot() {
    XCTAssertEqual(WindowTitle.name(tile: "Chat", detail: "Plan the week"), "Chat · Plan the week")
    XCTAssertEqual(WindowTitle.name(tile: "Whiteboard", detail: "Board, Nov 22"), "Whiteboard · Board, Nov 22")
  }

  func testTheCockpitsOwnNameForItsViewIsTheWindowsName() {
    XCTAssertEqual(WindowTitle.name(tile: "Cockpit", pageTitle: "Cockpit · Machines"), "Cockpit · Machines")
    XCTAssertEqual(WindowTitle.name(tile: "Cockpit", pageTitle: "Cockpit · Inbox (3)"), "Cockpit · Inbox (3)")
    XCTAssertEqual(
      WindowTitle.name(tile: "Cockpit", pageTitle: "Cockpit · Ink · Board, Nov 22"), "Cockpit · Ink · Board, Nov 22")
  }

  func testACockpitThatHasntNamedItselfIsPlainCockpit() {
    XCTAssertEqual(WindowTitle.name(tile: "Cockpit", pageTitle: nil), "Cockpit")
    XCTAssertEqual(WindowTitle.name(tile: "Cockpit", pageTitle: ""), "Cockpit")
    XCTAssertEqual(WindowTitle.name(tile: "Cockpit", pageTitle: "   "), "Cockpit")
  }

  func testTheDetailIsPlainWords() {
    // test_core.cjs: "Fix the **title** of [this](https://x.y/1)" -> "Fix the title of this"
    XCTAssertEqual(WindowTitle.detail("Fix the **title** of [this](https://x.y/1)"), "Fix the title of this")
    XCTAssertEqual(WindowTitle.detail("# A `code` _word_ > quoted"), "A code word quoted")
    XCTAssertEqual(WindowTitle.detail("two\n  lines\tjoined"), "two lines joined")
  }

  func testALongDetailIsCutToFortyWithAnEllipsis() {
    // test_core.cjs: "a long thread title is cut short for the tab strip"
    let long = "A thread title that goes on for a good deal longer than any browser tab can show"
    let cut = WindowTitle.detail(long)
    XCTAssertTrue(cut.hasSuffix("…"), cut)
    XCTAssertLessThanOrEqual(cut.count, WindowTitle.detailMax, cut)
    XCTAssertEqual(cut, "A thread title that goes on for a good…")
    let name = WindowTitle.name(tile: "Chat", detail: long)
    XCTAssertLessThanOrEqual(name.count, "Chat · ".count + WindowTitle.detailMax, name)
  }

  func testOnlyACockpitPageNamesTheCockpitsWindow() {
    let start = URL(string: "https://cockpit.example.ts.net/?client=grabber")
    let state = CockpitPage.State(address: "https://cockpit.example.ts.net/", start: start, now: Date())
    XCTAssertTrue(state.isCockpit(URL(string: "https://cockpit.example.ts.net/#machines")!))
    XCTAssertTrue(state.isCockpit(URL(string: "https://cockpit.example.ts.net/ink/board-1")!))
    XCTAssertFalse(state.isCockpit(URL(string: "https://github.com/idvorkin/context-grabber")!))
    let bundled = CockpitPage.State(address: "bridge-test.html", start: nil, now: Date())
    XCTAssertFalse(bundled.isCockpit(URL(string: "https://cockpit.example.ts.net/")!))
  }

  func testADetailOfExactlyFortyIsKept() {
    let forty = String(repeating: "x", count: 40)
    XCTAssertEqual(WindowTitle.detail(forty), forty)
  }
}
