import XCTest

@testable import ContextCore

/// Site names come from the Cockpit (story 1135): a web chip reads the site's short name the Cockpit gives, the app's
/// own names until it has a list, and never on a PR, gist, Inbox, Install or Larry chip.
final class ChatSiteNamesTests: XCTestCase {
  override func tearDown() {
    ChatSiteNames.current = .shipped
    super.tearDown()
  }

  private func labels(_ text: String, _ names: ChatSiteNames) -> [String] {
    ChatSiteNames.current = names
    return ChatLinks.found(in: text).map(\.label)
  }

  func testTheShippedNamesShortenTheExplainerSite() {
    XCTAssertEqual(
      labels(
        "See https://idvorkin-ai-tools.github.io/p04.html and https://idvorkin-ai-tools.github.io/", .shipped),
      ["ai-tools/p04.html", "ai-tools"])
  }

  func testTheCockpitsListNamesItsSitesAndLeavesOthersAsThey() throws {
    let data = Data(#"{"sites": {"idvorkin-ai-tools.github.io": "ai-tools", "Example.org": "ex"}}"#.utf8)
    let names = try XCTUnwrap(ChatSiteNames.parse(data))
    XCTAssertEqual(
      labels(
        "https://idvorkin-ai-tools.github.io/p04.html https://example.org/a/b https://www.example.org/ https://idvork.in/ai-journal",
        names),
      ["ai-tools/p04.html", "ex/b", "ex", "idvork.in/ai-journal"])
  }

  func testAListWithoutASiteDropsTheShippedName() throws {
    let names = try XCTUnwrap(ChatSiteNames.parse(Data(#"{"sites": {}}"#.utf8)))
    XCTAssertEqual(
      labels("https://idvorkin-ai-tools.github.io/p04.html", names), ["idvorkin-ai-tools.github.io/p04.html"])
  }

  func testANameNeverChangesASpecialChip() throws {
    let data = Data(
      """
      {"sites": {"github.com": "gh", "gist.github.com": "g", "\(CockpitPage.host)": "cockpit"}}
      """.utf8)
    let names = try XCTUnwrap(ChatSiteNames.parse(data))
    let text = """
      https://github.com/idvorkin/context-grabber/pull/734 https://gist.github.com/idvorkin/3f2a \
      https://\(CockpitPage.host):8444/review https://\(CockpitPage.host)/ai-journal
      """
    XCTAssertEqual(labels(text, names), ["PR #734", "gist", "Larry: Lavish", "Larry: ai-journal"])
    XCTAssertEqual(labels("https://github.com/idvorkin/context-grabber/issues/736", names), ["gh/issues/736"])
  }

  func testAnUnreadableListIsNil() {
    XCTAssertNil(ChatSiteNames.parse(Data("not json".utf8)))
    XCTAssertNil(ChatSiteNames.parse(Data(#"{"other": 1}"#.utf8)))
    XCTAssertNil(ChatSiteNames.parse(Data(#"{"sites": ["a"]}"#.utf8)))
  }

  func testABlankNameIsLeftOut() throws {
    let names = try XCTUnwrap(ChatSiteNames.parse(Data(#"{"sites": {"example.org": "  ", "a.org": "A"}}"#.utf8)))
    XCTAssertEqual(names.names, ["a.org": "A"])
  }

  func testTheListIsKeptAndRestored() throws {
    let names = ChatSiteNames(names: ["example.org": "ex"])
    XCTAssertEqual(ChatSiteNames.parse(names.saved), names)
  }

  func testTheRequestAsksTheCockpitsLinkLabels() throws {
    let request = try ChatSiteNames.request(cockpit: "https://cockpit.example:8443/")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example:8443/link-labels")
    XCTAssertEqual(request.httpMethod ?? "GET", "GET")
  }
}
