import XCTest

@testable import ContextCore

/// Links in a thread (#736, stories 549-553): found in real message words, labelled, one per page, newest first.
final class ChatLinksTests: XCTestCase {
  private func message(_ id: String, _ text: String, who: String = "larry", isError: Bool = false) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: who, text: text, isError: isError)
  }

  #if canImport(Darwin)
    private func labels(_ text: String) -> [String] { ChatLinks.found(in: text).map(\.label) }

    func testAPullRequestReadsItsNumberFromAnyOfItsPages() {
      let text = """
        Opened https://github.com/idvorkin/context-grabber/pull/734 for the shortcuts; the diff is at \
        https://github.com/idvorkin/context-grabber/pull/735/files and my note https://github.com/idvorkin/chop-conventions/pull/12#issuecomment-99.
        """
      XCTAssertEqual(labels(text), ["PR #734", "PR #735", "PR #12"])
      XCTAssertEqual(
        ChatLinks.found(in: text).first?.kind, .pullRequest(repo: "idvorkin/context-grabber", number: 734))
    }

    func testAGistReadsGist() {
      let links = ChatLinks.found(in: "Log uploaded: https://gist.github.com/idvorkin/3f2a9c1e8b7d")
      XCTAssertEqual(links.map(\.label), ["gist"])
      XCTAssertEqual(links.first?.kind, .gist)
    }
  #endif

  #if canImport(Darwin)
    func testABlogLinkReadsItsSiteAndLastPart() {
      XCTAssertEqual(labels("Worth rereading https://idvork.in/ai-journal before the call"), ["idvork.in/ai-journal"])
      XCTAssertEqual(labels("See https://www.idvork.in/posts/eulogy/"), ["idvork.in/eulogy"])
      XCTAssertEqual(labels("Home: https://idvork.in"), ["idvork.in"])
    }

    func testAnIssueKeepsThePartBeforeItsNumber() {
      XCTAssertEqual(
        labels("Filed https://github.com/idvorkin/context-grabber/issues/736"), ["github.com/issues/736"])
    }

    func testALongPathIsCutShort() {
      let label = labels("https://idvork.in/a-very-long-post-name-about-many-many-things")[0]
      XCTAssertEqual(label, "idvork.in/a-very-long-post-name-a…")
    }
  #endif

  #if canImport(Darwin)
    func testTheSentencesPunctuationIsNotPartOfTheLink() {
      let text = """
        Merged https://github.com/idvorkin/context-grabber/pull/734. (see https://idvork.in/ai-journal) \
        `https://idvork.in/code` **https://idvork.in/bold** "https://idvork.in/quoted", https://idvork.in/why?
        """
      let urls = ChatLinks.found(in: text).map(\.url.absoluteString)
      XCTAssertEqual(
        urls,
        [
          "https://github.com/idvorkin/context-grabber/pull/734", "https://idvork.in/ai-journal",
          "https://idvork.in/code", "https://idvork.in/bold", "https://idvork.in/quoted", "https://idvork.in/why",
        ])
    }

    func testABalancedBracketStaysInTheLink() {
      XCTAssertEqual(
        ChatLinks.found(in: "https://en.wikipedia.org/wiki/Foo_(bar).").map(\.url.absoluteString),
        ["https://en.wikipedia.org/wiki/Foo_(bar)"])
    }
  #endif

  #if canImport(Darwin)
    func testOnlyLinksWrittenWithTheirSchemeCount() {
      XCTAssertEqual(labels("Read AGENTS.md and idvork.in/foo, mail igor@example.com, or mailto:igor@example.com"), [])
    }
  #endif

  #if canImport(Darwin)
    func testAThreadsLinksAreNewestFirstAndOncePerPage() {
      let messages = [
        message("1", "Draft: https://idvork.in/ai-journal and https://github.com/idvorkin/context-grabber/pull/700"),
        message(
          "2", "Here https://github.com/idvorkin/context-grabber/pull/734 then https://gist.github.com/i/abc",
          who: "igor"
        ),
        message(
          "3",
          "Again https://www.idvork.in/ai-journal/#top and https://github.com/idvorkin/context-grabber/pull/700/files"),
      ]
      let links = ChatLinks.inThread(messages)
      XCTAssertEqual(links.map(\.label), ["idvork.in/ai-journal", "PR #700", "PR #734", "gist"])
      // The newest one written is the one a chip opens.
      XCTAssertEqual(links[0].url.absoluteString, "https://www.idvork.in/ai-journal/#top")
      XCTAssertEqual(links[1].url.absoluteString, "https://github.com/idvorkin/context-grabber/pull/700/files")
    }

    func testTheSameNumberInAnotherRepoIsAnotherChip() {
      let links = ChatLinks.inThread([
        message("1", "https://github.com/idvorkin/context-grabber/pull/12 https://github.com/idvorkin/bug-kit/pull/12")
      ])
      XCTAssertEqual(links.map(\.label), ["PR #12", "PR #12"])
    }

    func testADifferentQueryIsAnotherPage() {
      let links = ChatLinks.inThread([message("1", "https://example.com/s?q=a https://example.com/s?q=b")])
      XCTAssertEqual(links.count, 2)
    }

    func testAFailureIsNotAMessageWithLinks() {
      XCTAssertEqual(ChatLinks.inThread([message("1", "Could not reach https://idvork.in/x", isError: true)]), [])
    }

    func testAThreadWithoutLinksHasNone() {
      XCTAssertEqual(ChatLinks.inThread([message("1", "Ship it?"), message("2", "Yes", who: "igor")]), [])
    }

    func testTheStripShowsTenAndCountsTheRest() {
      let messages = (1...13).map { message("\($0)", "https://idvork.in/post-\($0)") }
      let (shown, more) = ChatLinks.strip(ChatLinks.inThread(messages))
      XCTAssertEqual(shown.count, 10)
      XCTAssertEqual(shown.first?.label, "idvork.in/post-13")
      XCTAssertEqual(more, 3)
      XCTAssertEqual(ChatLinks.strip(Array(ChatLinks.inThread(messages).prefix(4))).more, 0)
    }

    func testAPullRequestCarriesNoStateYet() {
      XCTAssertNil(ChatLinks.found(in: "https://github.com/a/b/pull/1").first?.state)
    }
  #endif
}
