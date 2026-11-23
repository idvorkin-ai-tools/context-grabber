//  Stories 775-777, 802, 805 and 806 (bead context-grabber-stl) on the simulator, against the fake Cockpit
//  (scripts/native/test-whiteboard-ui.sh starts it): twenty seconds into a board turn Larry hasn't answered, the board
//  offers Interrupt when he has the picture, and Retry when the Cockpit never took it. What each reading offers is
//  `WhiteboardLarryWaitTests`, on the host; these hold the controls themselves, on an iPad.

import XCTest

final class WhiteboardLarryWaitUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// Stories 777, 805, 806: a slow Larry on a Cockpit that marks nothing gets a quiet Interrupt past twenty seconds; a
  /// tap frees the board, so the next tap is a fresh ask with a new clock.
  func testInterruptShowsPastTwentySecondsAndFreesTheBoard() throws {
    let (app, cockpit) = try launch()
    stroke(app, at: 0.5)
    try post(cockpit + "/fake/larry-ops", #"{"kind": "slow", "seconds": 45}"#)
    app.buttons["whiteboard-larry"].tap()
    let state = app.descendants(matching: .any)["whiteboard-note-state"]
    XCTAssertTrue(state.appears(within: 10), app.debugDescription)
    let interrupt = app.buttons["whiteboard-larry-interrupt"]
    XCTAssertFalse(interrupt.exists, "nothing is offered before twenty seconds")
    XCTAssertTrue(interrupt.appears(within: 35), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-larry-retry"].exists, "a Cockpit that marks nothing is never stuck")
    shot(app, "Interrupt past twenty seconds")
    interrupt.tap()
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: interrupt)
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: state)
    waitForExpectations(timeout: 10)
    // The next tap sends at once, never *Larry already has this*: a fresh clock.
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(state.appears(within: 10), app.debugDescription)
    XCTAssertFalse(interrupt.exists, "the fresh turn's twenty seconds start again")
  }

  /// Stories 775, 802, 804: on a Cockpit that marks, a picture it hasn't taken in twenty seconds is stuck, with Retry
  /// and Dismiss; Retry sends the same picture again, the problem goes, and his answer ends the turn.
  func testAStuckPictureOffersRetryAndARetryLands() throws {
    let (app, cockpit) = try launch()
    addTeardownBlock { try? self.post(cockpit + "/fake/board-stuck", #"{"seconds": 0}"#) }
    stroke(app, at: 0.4)
    app.buttons["whiteboard-larry"].tap()
    let state = app.descendants(matching: .any)["whiteboard-note-state"]
    XCTAssertTrue(state.appears(within: 10), app.debugDescription)
    // The first turn lands and is answered, so the thread is one whose pictures carry marks.
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: state)
    waitForExpectations(timeout: 20)
    try post(cockpit + "/fake/board-stuck", #"{"seconds": 28}"#)
    stroke(app, at: 0.6)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(state.appears(within: 10), app.debugDescription)
    let retry = app.buttons["whiteboard-larry-retry"]
    XCTAssertTrue(retry.appears(within: 26), app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-larry-dismiss"].exists)
    XCTAssertFalse(app.buttons["whiteboard-larry-interrupt"].exists, "stuck offers Retry, not Interrupt")
    shot(app, "Larry hasn't got the picture, with Retry and Dismiss")
    retry.tap()
    // The resend lands at once and Larry answers it: the problem and the clock go.
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: retry)
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: state)
    waitForExpectations(timeout: 15)
  }

  private func launch() throws -> (XCUIApplication, String) {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    sleep(1)
    return (app, cockpit)
  }

  private func stroke(_ app: XCUIApplication, at y: CGFloat) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: y))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: y)))
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  private func post(_ url: String, _ body: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }
}
