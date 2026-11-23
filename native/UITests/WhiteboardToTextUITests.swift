//  Stories 920, 921 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): To text
//  beside the selected ink, its picture read by the fake's `POST /ink/to-text`, and the words in the ink's place, or a
//  copyable problem with the ink left alone. The simulator can't work the lasso, so `GRABBER_WHITEBOARD_AFTER_INK=select`
//  selects the ink as one would. A real lasso and the real Cockpit's reading are the iPad's.

import XCTest

final class WhiteboardToTextUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// What the fake's `POST /ink/to-text` answers from now on: `{}` is its "hello".
  private func arm(_ cockpit: String, _ answer: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/to-text")))
    request.httpMethod = "POST"
    request.httpBody = Data(answer.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// A new board on paper with Ghosts off, so a finger draws, and the first ink selected a second after it lands.
  private func openBoard(_ cockpit: String) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_WHITEBOARD_AFTER_INK"] = "select"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    return app
  }

  /// Story 920: the selected ink becomes the fake's "hello", typed: its glyphs in place of the one stroke.
  func testToTextPutsTheWordsInTheInksPlace() throws {
    let cockpit = try cockpit()
    try arm(cockpit, "{}")
    let app = try openBoard(cockpit)
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertTrue(toText.appears(within: 10), "To text beside the selection: \(app.debugDescription)")
    // Story 1095: the label above the selection names it as ink, with what applies.
    let named = app.descendants(matching: .any)["whiteboard-selection-label"]
    XCTAssertTrue(named.appears(within: 5), "the selection's label: \(app.debugDescription)")
    XCTAssertEqual(named.label, "Selected: Ink, To text")
    toText.tap()
    waitUntil(
      NSPredicate(format: "label BEGINSWITH 'Send to Larry, ' AND label != 'Send to Larry, 1 strokes'"),
      app.buttons["whiteboard-send"], timeout: 15)
    XCTAssertFalse(app.buttons["copy-error"].exists, "no problem")
    XCTAssertNotNil(PaperScreen(app).ink, "the typed words show")
  }

  /// Story 921: the Cockpit failing leaves the ink as it was and says why, copyably.
  func testAFailureLeavesTheInkWithACopyableProblem() throws {
    let cockpit = try cockpit()
    try arm(cockpit, #"{"status": 502, "error": "the model failed"}"#)
    defer { try? arm(cockpit, "{}") }
    let app = try openBoard(cockpit)
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertTrue(toText.appears(within: 10), app.debugDescription)
    toText.tap()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 15), "copyable: \(app.debugDescription)")
    let said = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "To text failed: the model failed")
    ).firstMatch
    XCTAssertTrue(said.exists, app.debugDescription)
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 1 strokes", "the ink stays")
  }
}
