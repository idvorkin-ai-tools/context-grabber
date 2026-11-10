//  Story 059 (#798): a Places failure is a copyable problem under the map, not a line of grey text.
//  Needs no fixture: the import hook is pointed at a file that is not a database, so the import is refused.

import XCTest

final class PlacesProblemUITests: XCTestCase {
  func testARefusedImportCanBeCopied() throws {
    let app = XCUIApplication()
    // An absolute path the simulator can read (the Mac's own file); on a device it is missing, refused all the same.
    app.launchEnvironment["GRABBER_IMPORT_DB"] = "/etc/hosts"
    app.launchEnvironment["GRABBER_PLACES"] = "open"
    app.launch()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 30), app.debugDescription)
    let refused = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Import refused'")).firstMatch
    XCTAssertTrue(refused.exists, app.debugDescription)
  }
}
