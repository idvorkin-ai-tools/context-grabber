import XCTest

enum WhiteboardWordsOnlyFixture {
  static func prepare(_ cockpit: String, for test: XCTestCase) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-ops")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"kind": "words_only"}"#.utf8)
    let done = test.expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    test.wait(for: [done], timeout: 5)
  }

  static func reply(in app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "this is where it goes")).firstMatch
  }
}
