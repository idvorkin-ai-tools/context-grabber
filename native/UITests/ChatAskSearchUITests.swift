//  Story 1132 (bead context-grabber-4dme) on the simulator, against the fake Cockpit's GET /asks/search
//  (scripts/native/test-chat-ui.sh starts it): the box on *Decisions* finds an ask by an option's words with the
//  matched-field line under it, says *No asks match.* and what the tick would show when only an answered ask matches,
//  shows it once *Answered too* is ticked, makes a failed search a copyable problem with its status, and a tap on an
//  open ask's row opens the chat where its card is. The answer's decoding, the count line, the highlights and a row's
//  tap rule are `ChatAskSearchTests` on the host. While the whiteboard work runs (Igor, 2026-11-22) it is run on the
//  iPad's simulator.

import XCTest

final class ChatAskSearchUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    if let cockpit { try? post(cockpit, "/fake/asks", ["open": false]) }
  }

  private var cockpit: String? {
    ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"].flatMap { $0.isEmpty ? nil : $0 }
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

  /// Empties the box and types the words, as Igor would.
  private func search(_ field: XCUIElement, _ words: String) {
    field.tap()
    if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
    }
    field.typeText(words)
  }

  private func label(_ element: XCUIElement, is text: String) {
    wait(for: [expectation(for: NSPredicate(format: "label == %@", text), evaluatedWith: element)], timeout: 10)
  }

  func testSearchFindsAsksByTheirWordsAndAnsweredOnesBehindTheTick() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh") }
    try post(cockpit, "/fake/asks", ["open": true])
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_DECISION_FOLDS"] = "reset"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()

    let decisions = app.buttons["chat-decisions"]
    XCTAssertTrue(decisions.appears(within: 20), app.debugDescription)
    decisions.tap()
    XCTAssertTrue(app.otherElements["decision-card-igor2-88g.881"].appears(within: 10), app.debugDescription)
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)

    // A word only in an option: the row, the option's line under it, the count.
    search(field, "RAMEN")
    let row = app.buttons["ask-search-row-igor2-88g.881"]
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    XCTAssertFalse(app.otherElements["decision-card-igor2-88g.881"].exists, "the search, not the cards")
    let line = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "ask-search-match", "Ramen")
    ).firstMatch
    XCTAssertTrue(line.appears(within: 5), "the option's line: \(app.debugDescription)")
    let count = app.staticTexts["ask-search-count"]
    label(count, is: "1 open · 0 answered")

    // Only an answered ask matches: none shown, the count says what the tick would show; ticked, it shows.
    search(field, "passport")
    XCTAssertTrue(app.staticTexts["ask-search-empty"].appears(within: 10), app.debugDescription)
    XCTAssertEqual(app.staticTexts["ask-search-empty"].label, "No asks match.")
    label(count, is: "0 open · 1 answered (tick to show)")
    // A Toggle drawn as a button: a switch or a button to XCUITest, depending on the OS.
    app.descendants(matching: .any).matching(identifier: "ask-search-all").firstMatch.tap()
    XCTAssertTrue(app.buttons["ask-search-row-igor2-88g.882"].appears(within: 10), app.debugDescription)
    label(count, is: "0 open · 1 answered")

    // bd failing at the Cockpit: a copyable problem with the status.
    search(field, "bdfail")
    let problem = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "HTTP 502"))
      .firstMatch
    XCTAssertTrue(problem.appears(within: 10), app.debugDescription)

    // A tap on an open ask's row opens the chat its card is in.
    search(field, "tacos")
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    row.tap()
    XCTAssertTrue(app.otherElements["decision-card-igor2-88g.881"].appears(within: 10), app.debugDescription)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Where should we eat"))
        .firstMatch.appears(within: 10), "the ask's chat: \(app.debugDescription)")
  }
}
