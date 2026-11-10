import XCTest

@testable import ContextCore

/// A Cockpit thread link in a bubble (story 744): which thread it names, and whether a tap opens it in the app.
final class ChatCockpitLinkTests: XCTestCase {
  private func url(_ s: String) -> URL { URL(string: s)! }

  func testACockpitThreadLinkNamesItsThread() {
    XCTAssertEqual(
      ChatCockpitLink.threadKey(url("https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1411.2")),
      "igor2-88g.1411.2")
    XCTAssertEqual(
      ChatCockpitLink.threadKey(url("https://c-5004.squeaker-teeth.ts.net#thread/igor2-88g.1413")), "igor2-88g.1413")
    XCTAssertEqual(ChatCockpitLink.threadKey(url("HTTPS://C-5004.squeaker-teeth.ts.net/#thread/a%2Db")), "a-b")
  }

  func testOtherLinksNameNoThread() {
    for s in [
      "https://c-5004.squeaker-teeth.ts.net/#inbox",
      "https://c-5004.squeaker-teeth.ts.net/#thread/",
      "https://c-5004.squeaker-teeth.ts.net/#thread/a/b",
      "https://c-5004.squeaker-teeth.ts.net/decisions#thread/igor2-88g.1413",
      "http://c-5004.squeaker-teeth.ts.net:8445/#thread/igor2-88g.1413",
      "https://example.com/#thread/igor2-88g.1413",
      "https://github.com/idvorkin/context-grabber/pull/734",
    ] {
      XCTAssertNil(ChatCockpitLink.threadKey(url(s)), s)
    }
  }

  func testATapOpensAKnownThreadAndLeavesTheRestAsToday() {
    let link = url("https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1411.2")
    let known: Set = ["igor2-88g.1411.2", "igor2-88g.1413"]
    XCTAssertEqual(ChatCockpitLink.jump(link, from: "igor2-88g.1413", known: known), .thread("igor2-88g.1411.2"))
    XCTAssertEqual(ChatCockpitLink.jump(link, from: "igor2-88g.1411.2", known: known), .here)
    XCTAssertNil(ChatCockpitLink.jump(link, from: "igor2-88g.1413", known: ["igor2-88g.1413"]), "unknown: as today")
    XCTAssertNil(ChatCockpitLink.jump(url("https://idvork.in/ai-journal"), from: nil, known: known))
  }
}
