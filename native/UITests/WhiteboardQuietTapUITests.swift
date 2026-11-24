//  Story 1276 (#1385) on the simulator: a tap on the board brings up no system Paste · Select All menu. Before the fix,
//  a finger tap on the paper (PaperKit's selection gesture, the iPad's log: `board_cover` `edit_menu`, responder
//  PaperMarkupViewController) brought it up on every tap; paste lives in the board's own hold menu.
//  The simulator never brought the menu up, even before the fix: on the iPad it comes with Only Draw with Apple Pencil
//  on, which the simulator can't set. So this guards the taps; the iPad's log (`tap_menu_quiet`, and `board_cover`
//  with an empty `edit_menu` after a tap) is what shows the fix.
//  Run it on an iPad simulator: SIM="iPad Pro 11-inch (M5)".

import XCTest

final class WhiteboardQuietTapUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func systemMenu(_ app: XCUIApplication) -> XCUIElement? {
    // The system's edit menu, not the board's own Paste button on its bar (`whiteboard-paste`).
    let system = NSPredicate(
      format: "(label == 'Select All' OR label == 'Paste') AND NOT (identifier BEGINSWITH 'whiteboard')")
    for query in [app.menuItems, app.buttons, app.staticTexts] {
      let found = query.matching(system).firstMatch
      if found.exists { return found }
    }
    return nil
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  func testATapOnTheBoardBringsNoPasteOrSelectAll() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    // As on the iPad: the Pencil has touched a board, so a finger selects and never draws (story 1153).
    app.launchEnvironment["GRABBER_WHITEBOARD_PENCIL"] = "seen"
    app.launchEnvironment["GRABBER_WHITEBOARD_PASTE"] = "HI"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    // Ink on the board from the board's own Paste, so Select All has something to select, and text on the clipboard,
    // so a system Paste would have something to paste (the bar's Paste shows only with text on the clipboard).
    UIPasteboard.general.string = "a line to paste"
    let paste = app.buttons["whiteboard-paste"]
    XCTAssertTrue(paste.appears(within: 10), app.debugDescription)
    paste.tap()
    waitUntil(NSPredicate(format: "label BEGINSWITH 'Send to Larry, '"), app.buttons["whiteboard-send"], timeout: 10)
    sleep(1)

    // Finger taps on blank paper and near the ink: none brings up the system menu.
    for (index, spot) in [CGVector(dx: 0.5, dy: 0.7), CGVector(dx: 0.45, dy: 0.5), CGVector(dx: 0.4, dy: 0.3)]
      .enumerated()
    {
      app.coordinate(withNormalizedOffset: spot).tap()
      sleep(2)
      if let menu = systemMenu(app) {
        shot(app, "tap \(index)")
        XCTFail("tap \(index) at \(spot) brought up the system menu: \(menu.debugDescription)")
      }
    }
  }

}
