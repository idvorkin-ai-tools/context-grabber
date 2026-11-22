//  Stories 830-832 (#878) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): the
//  card in the chat an open ask continues (filed from it: the ask's `thread` names that chat, not its own bead), its
//  row's *Decision waiting*, *Decisions (N)*, an answer the fake records and writes into the chat as Igor's message, and
//  a refused one that leaves the card with a copyable problem. What each answer means, the order, the marks and the
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

  private func fakeCockpit(other: Bool = false) throws -> String {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh") }
    try post(cockpit, "/fake/asks", ["open": true, "other": other])
    return cockpit
  }

  /// The own-words field, a text view or a text field depending on how SwiftUI draws a vertical one.
  private func otherWords(_ app: XCUIApplication) -> XCUIElement {
    app.textViews["decision-other-words"].exists
      ? app.textViews["decision-other-words"] : app.textFields["decision-other-words"]
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

  /// Stories 830-832: the row says so, Decisions counts them all, the card answers, the fake records it, the answer is
  /// Igor's message in the thread, the mark goes.
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
    XCTAssertTrue(app.otherElements["decision-card-igor2-88g.881"].appears(within: 10), app.debugDescription)
    XCTAssertTrue(app.staticTexts["Lunch on Friday: where?"].exists)
    XCTAssertTrue(app.staticTexts["Default"].exists, "the default is marked")
    app.buttons["decision-option-ramen"].tap()
    let mine = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "chat-mine", "Decided: Ramen")
    ).firstMatch
    XCTAssertTrue(mine.appears(within: 10), "Igor's answer is his message: \(app.debugDescription)")
    XCTAssertFalse(app.otherElements["decision-card-igor2-88g.881"].exists, "the card gave way")
    let line = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "You decided"))
    XCTAssertEqual(line.count, 0, "the message, not the line: \(app.debugDescription)")

    let posted = try answers(cockpit).filter { $0["path"] as? String == "/act" }
    XCTAssertEqual(posted.count, 1, "\(posted)")
    XCTAssertEqual(posted.first?["id"] as? String, "igor2-88g.881")
    XCTAssertEqual(posted.first?["response"] as? String, "DECISION: Ramen")
    XCTAssertEqual(posted.first?["action"] as? String, "respond")
    XCTAssertEqual(posted.first?["post_to_chat"] as? Bool, true)
    XCTAssertEqual(posted.first?["source"] as? String, "app")

    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    let unmarked = NSPredicate(format: "NOT (label CONTAINS %@)", "Decision waiting")
    wait(for: [expectation(for: unmarked, evaluatedWith: row)], timeout: 10)
    let two = NSPredicate(format: "label CONTAINS %@", "Decisions (2)")
    wait(for: [expectation(for: two, evaluatedWith: decisions)], timeout: 10)
  }

  /// Story 832, #1072: the last card answered on *Decisions* leaves its line there. With the row's link gone under it the
  /// screen froze on the answered card, and a further tap only answered it again.
  func testTheLastDecisionFinishedOnDecisionsLeavesItsLine() throws {
    let cockpit = try fakeCockpit()
    let app = launch(cockpit, ["GRABBER_INBOX": "open"])

    let decisions = app.buttons["chat-decisions"]
    XCTAssertTrue(decisions.appears(within: 20), app.debugDescription)
    let three = NSPredicate(format: "label CONTAINS %@", "Decisions (3)")
    wait(for: [expectation(for: three, evaluatedWith: decisions)], timeout: 10)
    decisions.tap()

    let lines = app.staticTexts.matching(identifier: "decision-line")
    for (ask, option) in [("igor2-88g.881", "tacos"), ("igor2-88g.879", "yes")] {
      let card = app.otherElements["decision-card-\(ask)"]
      XCTAssertTrue(card.appears(within: 10), app.debugDescription)
      app.buttons["decision-option-\(option)"].tap()
      XCTAssertTrue(card.waitForNonExistence(timeout: 10), "\(ask) gave way: \(app.debugDescription)")
    }
    XCTAssertEqual(lines.count, 2, app.debugDescription)

    // The last one, finished from its menu as #1072's was.
    let last = app.otherElements["decision-card-igor2-88g.880"]
    XCTAssertTrue(last.appears(within: 10), app.debugDescription)
    app.buttons["decision-menu"].tap()
    XCTAssertTrue(app.buttons["Abandon"].appears(within: 5), app.debugDescription)
    app.buttons["Abandon"].tap()
    XCTAssertTrue(app.buttons["Stale"].appears(within: 5), app.debugDescription)
    app.buttons["Stale"].tap()
    XCTAssertTrue(last.waitForNonExistence(timeout: 10), "the last card gave way: \(app.debugDescription)")
    let abandoned = lines.matching(NSPredicate(format: "label CONTAINS %@", "Abandoned")).firstMatch
    XCTAssertTrue(abandoned.appears(within: 5), "its line is on Decisions: \(app.debugDescription)")
    XCTAssertEqual(lines.count, 3, app.debugDescription)
    XCTAssertTrue(app.navigationBars["Decisions"].exists, "still on Decisions: \(app.debugDescription)")
    let closed = try answers(cockpit).filter { $0["path"] as? String == "/close" }
    XCTAssertEqual(closed.count, 1, "abandoned once: \(closed)")
  }

  /// Story 1128: *Other…* in the card's chat opens a field with the mic beside Send; Igor's words answer the ask as the
  /// Inbox's free-text answer and become his message in the chat.
  func testOtherAnswersInIgorsOwnWords() throws {
    let cockpit = try fakeCockpit()
    let app = launch(cockpit, ["GRABBER_LINK": "grabbernative://chat?thread=igor2-88g.878"])

    let card = app.otherElements["decision-card-igor2-88g.881"]
    XCTAssertTrue(card.appears(within: 20), app.debugDescription)
    let other = app.buttons["decision-other"]
    XCTAssertTrue(other.exists, "every card has Other: \(app.debugDescription)")
    XCTAssertFalse(app.buttons["decision-other-send"].exists, "the field opens only on a tap")
    other.tap()
    let send = app.buttons["decision-other-send"]
    let mic = app.buttons["decision-other-mic"]
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    XCTAssertTrue(mic.exists, "dictation beside Send")
    XCTAssertLessThanOrEqual(mic.frame.maxX, send.frame.minX, "the mic comes before Send")
    XCTAssertFalse(send.isEnabled, "no words, no Send")
    let field = otherWords(app)
    field.tap()
    field.typeText("Pho on Thursday")
    XCTAssertTrue(send.isEnabled)
    send.tap()

    let mine = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "chat-mine", "Decided: Pho on Thursday")
    ).firstMatch
    XCTAssertTrue(mine.appears(within: 10), "Igor's words are his message: \(app.debugDescription)")
    XCTAssertFalse(card.exists, "the card gave way")
    let posted = try answers(cockpit).filter { $0["path"] as? String == "/act" }
    XCTAssertEqual(posted.count, 1, "\(posted)")
    XCTAssertEqual(posted.first?["id"] as? String, "igor2-88g.881")
    XCTAssertEqual(posted.first?["response"] as? String, "DECISION: Pho on Thursday")
    XCTAssertEqual(posted.first?["post_to_chat"] as? Bool, true)
  }

  /// Story 1129: an ask that already offers Larry's own-answer option (keyed other, labelled *Something else*, as on
  /// 2026-11-22) shows no second *Other*, and his opens the field: the Cockpit gets Igor's words, never the bare label
  /// and never an empty answer.
  func testLarrysOwnOtherOpensTheFieldAndNeverSendsTheBareWord() throws {
    let cockpit = try fakeCockpit(other: true)
    let app = launch(cockpit, ["GRABBER_INBOX": "open"])

    let decisions = app.buttons["chat-decisions"]
    XCTAssertTrue(decisions.appears(within: 20), app.debugDescription)
    decisions.tap()
    let card = app.otherElements["decision-card-igor2-88g.879"]
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    XCTAssertFalse(card.buttons["decision-other"].exists, "no second Other: \(app.debugDescription)")
    let larrys = card.buttons["decision-option-other"]
    XCTAssertTrue(larrys.exists, app.debugDescription)
    XCTAssertTrue(larrys.label.contains("Something else"), larrys.label)
    larrys.tap()
    let send = app.buttons["decision-other-send"]
    XCTAssertTrue(send.appears(within: 5), "Larry's Other opened the field: \(app.debugDescription)")
    XCTAssertFalse(send.isEnabled, "Send is off until there are words")
    XCTAssertTrue(card.exists, "nothing answered yet")
    XCTAssertTrue(try answers(cockpit).isEmpty, "a tap on Something else sends nothing")
    let field = otherWords(app)
    field.tap()
    field.typeText("Month to month")
    send.tap()
    XCTAssertTrue(card.waitForNonExistence(timeout: 10), "the card gave way: \(app.debugDescription)")
    let posted = try answers(cockpit).filter { $0["path"] as? String == "/act" }
    XCTAssertEqual(posted.map { $0["response"] as? String }, ["DECISION: Month to month"], "\(posted)")
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
