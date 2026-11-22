//  Story 1122 (#633) on the simulator: a PDF delivered to a thread, against the fake Cockpit
//  (scripts/native/test-chat-ui.sh starts it), shows as a file row with its name and opens in the system preview.
//  The name and the fetch's problems are `ChatTests`' (host).

import XCTest

final class ChatFileUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testADeliveredPDFIsARowThatOpensIt() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/file-thread")))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data("{}".utf8)
    let done = expectation(description: "the fake Cockpit adds the thread")
    URLSession.shared.dataTask(with: request) { _, _, _ in done.fulfill() }.resume()
    wait(for: [done], timeout: 10)

    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.633"
    app.launch()
    let row = app.buttons["chat-file"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    XCTAssertTrue(row.label.contains("Lease.pdf") && row.label.contains("PDF"), row.label)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "The PDF's row in its thread"
    shot.lifetime = .keepAlways
    add(shot)

    row.tap()
    // The system preview names the file in its own bar; the thread's title is the chat's, so this is the preview.
    let preview = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Lease'")).firstMatch
    let titled = app.staticTexts.matching(NSPredicate(format: "label == 'Lease.pdf'"))
    let deadline = Date().addingTimeInterval(15)
    while !preview.exists && titled.count < 2 && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
    let opened = XCTAttachment(screenshot: app.screenshot())
    opened.name = "The PDF open in the preview"
    opened.lifetime = .keepAlways
    add(opened)
    XCTAssertTrue(preview.exists || titled.count >= 2, "the preview opened: \(app.debugDescription)")
  }
}
