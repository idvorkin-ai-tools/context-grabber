//  Stories 830-832 (#878) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): the
//  card in the chat whose bead is an open ask, its row's *Decision waiting*, *Decisions (N)*, an answer the fake records,
//  and a refused one that leaves the card with a copyable problem. What each answer means, the order, the marks and the
//  lines are `ChatDecisionsTests` on the host. The fake Cockpit has no asks until a test asks for them, and each test
//  takes them away again: an extra row moves the list under the other chat classes.

import XCTest

final class ChatDecisionUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    if let cockpit { try? post(cockpit, "/fake/asks", ["open": false]) }
  }

  private var cockpit: String? {
    ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"].flatMap { $0.isEmpty ? nil : $0 }
  }

  private func fakeCockpit() throws -> String {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh") }
    try post(cockpit, "/fake/asks", ["open": true])
    return cockpit
  }

  private func post(_ cockpit: String, _ path: String, _ body: [String: Any]) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let done = expectation(description: "the fake Cockpit took \(path)")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// What the fake Cockpit was posted to /act, /close and /snooze.
  private func answers(_ cockpit: String) throws -> [[String: Any]] {
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: try XCTUnwrap(URL(string: cockpit + "/fake/answers"))) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["answers"] as? [[String: Any]])
  }

  private func launch(_ cockpit: String, _ environment: [String: String]) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    for (key, value) in environment { app.launchEnvironment[key] = value }
    app.launch()
    return app
  }

  /// Stories 830-832: the row says so, Decisions counts them all, the card answers, the fake records it, the mark goes.
  func testTheCardInItsChatAnswersAndTheRowsMarkGoes() throws {
    let cockpit = try fakeCockpit()
    let app = launch(cockpit, ["GRABBER_INBOX": "open"])

    let row = app.buttons["chat-thread-igor2-88g.878"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    let marked = NSPredicate(format: "label CONTAINS %@", "Decision waiting")
    wait(for: [expectation(for: marked, evaluatedWith: row)], timeout: 10)
    let decisions = app.buttons["chat-decisions"]
    XCTAssertTrue(decisions.appears(within: 5), app.debugDescription)
    XCTAssertTrue(decisions.label.contains("Decisions (3)"), decisions.label)
    let larrys = app.buttons["chat-thread-igor2-88g.1268"]
    XCTAssertLessThan(larrys.frame.minY, decisions.frame.minY, "under Larry's")
    XCTAssertFalse(app.buttons["chat-thread-igor2-88g.900"].label.contains("Decision waiting"), "only the ask's chat")

    row.tap()
    XCTAssertTrue(app.otherElements["decision-card-igor2-88g.878"].appears(within: 10), app.debugDescription)
    XCTAssertTrue(app.staticTexts["Lunch on Friday: where?"].exists)
    XCTAssertTrue(app.staticTexts["Default"].exists, "the default is marked")
    app.buttons["decision-option-ramen"].tap()
    let decided = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "You decided: Ramen")
    ).firstMatch
    XCTAssertTrue(decided.appears(within: 10), app.debugDescription)
    XCTAssertFalse(app.otherElements["decision-card-igor2-88g.878"].exists, "the card gave way")

    let posted = try answers(cockpit).filter { $0["path"] as? String == "/act" }
    XCTAssertEqual(posted.count, 1, "\(posted)")
    XCTAssertEqual(posted.first?["id"] as? String, "igor2-88g.878")
    XCTAssertEqual(posted.first?["response"] as? String, "DECISION: Ramen")
    XCTAssertEqual(posted.first?["action"] as? String, "respond")

    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    let unmarked = NSPredicate(format: "NOT (label CONTAINS %@)", "Decision waiting")
    wait(for: [expectation(for: unmarked, evaluatedWith: row)], timeout: 10)
    let two = NSPredicate(format: "label CONTAINS %@", "Decisions (2)")
    wait(for: [expectation(for: two, evaluatedWith: decisions)], timeout: 10)
  }

  /// Story 830: a refused answer leaves the card, buttons live, with a copyable problem.
  func testARefusedAnswerLeavesTheCardWithACopyableProblem() throws {
    let cockpit = try fakeCockpit()
    let app = launch(cockpit, ["GRABBER_LINK": "grabbernative://chat?thread=igor2-88g.880"])

    let card = app.otherElements["decision-card-igor2-88g.880"]
    XCTAssertTrue(card.appears(within: 20), app.debugDescription)
    XCTAssertTrue(app.staticTexts["decision-expiry"].label.hasPrefix("Expired"), "expired, and still answerable")
    let move = app.buttons["decision-option-move"]
    move.tap()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 10), "copyable: \(app.debugDescription)")
    let said = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Could not answer this decision: bd: database is locked")
    ).firstMatch
    XCTAssertTrue(said.exists, app.debugDescription)
    XCTAssertTrue(card.exists, "the card stays")
    XCTAssertTrue(move.isEnabled, "and its buttons work again")
  }
}
