//  Stories 837 and 887 (bead context-grabber-97s) on an iPad simulator, against the fake Cockpit
//  (scripts/native/test-whiteboard-ui.sh starts it): the board's open conversation keeps its size with more of Larry's
//  replies than it holds, and follows the newest only while Igor is at the bottom. Where the panel stops and when it
//  follows are `WhiteboardNoteTests`, on the host. Story 1184's bound on what the mic hears has no simulator hook that
//  keeps the mic on.

import XCTest

final class WhiteboardPanelScrollUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  /// A new board with one stroke, Larry's turn taken so the board has its thread, and the conversation open.
  private func openPanel() throws -> (XCUIApplication, XCUIElement) {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launch()
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
    let panel = app.textViews["whiteboard-conversation-text"]
    if !panel.exists { chevron.tap() }
    // Open or closed outlives the launch: the next test starts with it closed.
    addTeardownBlock {
      if panel.exists { chevron.tap() }
    }
    XCTAssertTrue(panel.appears(within: 5), app.debugDescription)
    return (app, panel)
  }

  /// Stories 837, 887: twelve long replies, more than the panel holds; the panel and the paper under it stay put, and
  /// a reply while Igor reads an older one leaves him there.
  func testALongConversationScrollsInsideAndAReplyNeverPullsAReaderDown() throws {
    let (app, panel) = try openPanel()
    let help = app.buttons["whiteboard-help"]
    XCTAssertTrue(help.appears(within: 5), app.debugDescription)
    try post("/fake/larry-says", #"{"count": 12, "from": 1}"#)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Reply 12:"), panel, timeout: 20)
    let window = app.windows.firstMatch.frame.height
    let paperTop = help.frame.minY
    XCTAssertLessThanOrEqual(panel.frame.height, max(window / 5, 120) + 1, "the messages scroll, they don't grow")
    XCTAssertLessThanOrEqual(paperTop - panel.frame.minY, window / 5 + 120, "the whole panel stays small")
    waitUntil(NSPredicate(format: "label CONTAINS %@", "newest"), panel, timeout: 5)
    shot(app, "whiteboard-panel-full")

    try post("/fake/larry-says", #"{"count": 1, "from": 13}"#)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Reply 13:"), panel, timeout: 20)
    XCTAssertEqual(help.frame.minY, paperTop, accuracy: 1, "another reply doesn't move the paper")
    XCTAssertTrue(panel.label.contains("newest"), "at the bottom, it follows the reply: \(panel.label)")

    // A finger scrolls up to an older reply; the next one leaves it there.
    for _ in 0..<4 { panel.swipeDown() }
    waitUntil(NSPredicate(format: "label CONTAINS %@", "older"), panel, timeout: 5)
    try post("/fake/larry-says", #"{"count": 1, "from": 14}"#)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Reply 14:"), panel, timeout: 20)
    sleep(1)
    XCTAssertTrue(panel.label.contains("older"), "still where Igor was reading: \(panel.label)")
    XCTAssertEqual(help.frame.minY, paperTop, accuracy: 1)

    // Back at the bottom, it follows again.
    for _ in 0..<6 { panel.swipeUp() }
    waitUntil(NSPredicate(format: "label CONTAINS %@", "newest"), panel, timeout: 5)
    try post("/fake/larry-says", #"{"count": 1, "from": 15}"#)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Reply 15:"), panel, timeout: 20)
    sleep(1)
    XCTAssertTrue(panel.label.contains("newest"), "following the newest again: \(panel.label)")
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
