//  Story 1277 (#1384) on an iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it):
//  the board's open conversation switches to chat bubbles, keeps the panel's size and scrolling, remembers the choice,
//  and switches back to lines. Which messages become bubbles, and on which side, is `WhiteboardPanelLookTests`, on the
//  host. The Pencil on the bubbles is the iPad's check.

import XCTest

final class WhiteboardBubblesUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  private func launch() throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launch()
    return app
  }

  /// A new board with one stroke, Larry's turn taken so the board has its thread, and the conversation open.
  private func openPanel(_ app: XCUIApplication) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    sleep(1)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    send.tap()
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 15), app.debugDescription)
    let switcher = app.segmentedControls["whiteboard-conversation-look"]
    if !switcher.exists { chevron.tap() }
    XCTAssertTrue(switcher.appears(within: 5), app.debugDescription)
  }

  /// Story 1277: Bubbles shows Larry's replies on the left, keeps the panel's size, follows the newest, outlives the
  /// board; Lines brings back the text.
  func testTheConversationReadsAsBubblesAndBack() throws {
    var app = try launch()
    openPanel(app)
    let switcher = app.segmentedControls["whiteboard-conversation-look"]
    addTeardownBlock {
      // Both choices outlive the launch: the next test starts in Lines, closed.
      let lines = app.segmentedControls["whiteboard-conversation-look"].buttons["Lines"]
      if lines.exists { lines.tap() }
      let chevron = app.buttons["whiteboard-note-chevron"]
      if app.segmentedControls["whiteboard-conversation-look"].exists, chevron.exists { chevron.tap() }
    }
    switcher.buttons["Bubbles"].tap()
    let bubbles = app.descendants(matching: .any)["whiteboard-conversation-bubbles"]
    XCTAssertTrue(bubbles.appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.textViews["whiteboard-conversation-text"].exists, "Bubbles replaces the lines")

    try post("/fake/larry-says", #"{"count": 12, "from": 1}"#)
    let newest = app.descendants(matching: .any).matching(identifier: "whiteboard-bubble-larry")
      .containing(NSPredicate(format: "label CONTAINS %@", "Reply 12:")).firstMatch
    XCTAssertTrue(newest.appears(within: 20), app.debugDescription)
    let window = app.windows.firstMatch.frame
    XCTAssertLessThanOrEqual(
      bubbles.frame.height, max(window.height / 5, 120) + 1, "the bubbles scroll, they don't grow")
    XCTAssertLessThan(newest.frame.midX, window.midX, "Larry's bubble is on the left")
    XCTAssertTrue(bubbles.frame.contains(CGPoint(x: newest.frame.midX, y: newest.frame.maxY - 2)), "newest in view")
    shot(app, "whiteboard-bubbles")

    // Another board opens in Bubbles.
    app.terminate()
    app = try launch()
    openPanel(app)
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard-conversation-bubbles"].appears(within: 5))

    app.segmentedControls["whiteboard-conversation-look"].buttons["Lines"].tap()
    XCTAssertTrue(app.textViews["whiteboard-conversation-text"].appears(within: 5), "Lines brings back the text")
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  private func post(_ path: String, _ body: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: try cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took \(path)")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }
}
