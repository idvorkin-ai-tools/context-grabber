import XCTest

@testable import ContextCore

/// Short links in a bubble (story 743): a lone PR reads *PR*, a blog link or its tailnet preview *Preview*; several
/// keep words that tell them apart, and every other link shows as written.
final class ChatBubbleLinksTests: XCTestCase {
  private let pr734 = "https://github.com/idvorkin/context-grabber/pull/734"
  private let pr736 = "https://github.com/idvorkin/context-grabber/pull/736"
  private let preview = "http://c-5004.squeaker-teeth.ts.net:8445/ai-journal"

  func testALonePRAndALonePreviewReadShort() {
    let text = "Opened \(pr734), preview at \(preview)."
    XCTAssertEqual(ChatBubbleLinks.labels(in: text), [pr734: "PR", preview: "Preview"])
  }

  func testOnePRWrittenTwiceOrToTwoOfItsPagesIsStillOne() {
    let files = pr734 + "/files"
    let labels = ChatBubbleLinks.labels(in: "\(pr734) and its diff \(files), again \(pr734)")
    XCTAssertEqual(labels, [pr734: "PR", files: "PR"])
  }

  func testSeveralPRsKeepTheirNumbers() {
    let labels = ChatBubbleLinks.labels(in: "Merged \(pr734); \(pr736) is next")
    XCTAssertEqual(labels, [pr734: "PR #734", pr736: "PR #736"])
  }

  func testTwoPRsWithOneNumberNameTheirRepositories() {
    let other = "https://github.com/idvorkin/chop-conventions/pull/734"
    let labels = ChatBubbleLinks.labels(in: "\(pr734) and \(other)")
    XCTAssertEqual(labels, [pr734: "context-grabber PR #734", other: "chop-conventions PR #734"])
  }

  func testTheBlogAndItsPreviewsReadPreview() {
    for link in [
      "https://idvork.in/ai-journal", "https://www.idvork.in/eulogy", "https://idvorkin.github.io/ai-journal",
      "http://c-5004.squeaker-teeth.ts.net:8448/religion", "https://idvork.in",
    ] {
      XCTAssertEqual(ChatBubbleLinks.labels(in: "See \(link)"), [link: "Preview"], link)
    }
  }

  func testSeveralPreviewsKeepTheLastPartOfTheirPath() {
    let journal = "https://idvork.in/ai-journal"
    let eulogy = "http://c-5004.squeaker-teeth.ts.net:8445/eulogy"
    let labels = ChatBubbleLinks.labels(in: "\(journal) and \(eulogy)")
    XCTAssertEqual(labels, [journal: "Preview: ai-journal", eulogy: "Preview: eulogy"])
  }

  func testOtherLinksShowAsWritten() {
    let text = """
      The Cockpit https://c-5004.squeaker-teeth.ts.net/#inbox, a gist https://gist.github.com/idvorkin/3f2a9c1e8b7d, \
      an issue https://github.com/idvorkin/context-grabber/issues/736 and https://example.com/idvork.in
      """
    XCTAssertEqual(ChatBubbleLinks.labels(in: text), [:])
  }

  func testACockpitThreadLinkReadsInbox() {
    let ask = "https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1411.2"
    let other = "https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1413"
    XCTAssertEqual(ChatBubbleLinks.labels(in: "It's in the Inbox: \(ask). Also \(pr734)"), [ask: "Inbox", pr734: "PR"])
    XCTAssertEqual(
      ChatBubbleLinks.labels(in: "\(ask), \(other) and \(ask) again"), [ask: "Inbox 1", other: "Inbox 2"])
  }

  func testAPRBesideAPreviewIsStillTheOnlyPR() {
    let text = "\(pr734) **\(preview)**"
    XCTAssertEqual(ChatBubbleLinks.labels(in: text), [pr734: "PR", preview: "Preview"])
  }
}
