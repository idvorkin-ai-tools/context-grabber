import XCTest

@testable import ContextCore

/// Links in a bubble are chips (story 743): a PR reads *PR*, the blog or its tailnet preview *Preview*, any other link
/// its strip chip's words; the words around them split so a chip can sit among them, punctuation kept against it.
final class ChatBubbleLinksTests: XCTestCase {
  private let pr734 = "https://github.com/idvorkin/context-grabber/pull/734"
  private let pr736 = "https://github.com/idvorkin/context-grabber/pull/736"
  private let preview = "http://c-5004.squeaker-teeth.ts.net:8445/ai-journal"

  /// Each paragraph as text: a chip as `[label]` with what touches it, words joined by a space.
  private func read(_ text: String) -> [String] {
    ChatBubbleLinks.paragraphs(in: text).map {
      switch $0 {
      case .plain(let words): return "plain: " + words
      case .flow(let tokens):
        return tokens.map { token -> String in
          switch token {
          case .word(let word): return word
          case .chip(let link, let leading, let trailing):
            return "\(leading)[\(link.label)]\(trailing)"
          }
        }
        .joined(separator: " ")
      }
    }
  }

  func testAPRAndAPreviewAreChipsAmongTheWords() {
    XCTAssertEqual(read("Opened \(pr734), preview at \(preview)."), ["Opened [PR], preview at [Preview]."])
  }

  func testEveryPRReadsPRWhateverItsNumber() {
    XCTAssertEqual(read("Merged \(pr734); \(pr736) is next"), ["Merged [PR]; [PR] is next"])
  }

  func testTheBlogAndItsPreviewsReadPreview() {
    for link in [
      "https://idvork.in/ai-journal", "https://www.idvork.in/eulogy", "https://idvorkin.github.io/ai-journal",
      "http://c-5004.squeaker-teeth.ts.net:8448/religion", "https://idvork.in",
    ] {
      XCTAssertEqual(read("See \(link)"), ["See [Preview]"], link)
    }
  }

  func testOtherLinksAreTheirStripChip() {
    let issue = "https://github.com/idvorkin/context-grabber/issues/736"
    let gist = "https://gist.github.com/idvorkin/3f2a9c1e8b7d"
    XCTAssertEqual(read("A gist \(gist) and \(issue)"), ["A gist [gist] and [github.com/issues/736]"])
  }

  func testWordsWrittenAgainstALinkStayWithItsChip() {
    XCTAssertEqual(read("(see \(pr734)) and **\(preview)**"), ["(see [PR]) and **[Preview]**"])
  }

  func testOnlyTheLinesWithALinkSplitIntoWords() {
    XCTAssertEqual(
      read("Done.\nThe PR: \(pr734)\n\nThanks"), ["plain: Done.", "The PR: [PR]", "plain: ", "plain: Thanks"])
    XCTAssertEqual(read("No links here,\njust words"), ["plain: No links here,\njust words"])
  }

  func testTheChipKeepsTheLinkAndItsPage() {
    guard case .flow(let tokens) = ChatBubbleLinks.paragraphs(in: "Opened \(pr734)/files.")[0],
      case .chip(let link, _, let trailing)? = tokens.last
    else { return XCTFail("no chip") }
    XCTAssertEqual(link.url.absoluteString, pr734 + "/files")
    XCTAssertEqual(link.id, "pr:idvorkin/context-grabber#734", "the strip's id, so its state applies")
    XCTAssertEqual(trailing, ".")
  }

  // Story 1127 (#1138): Lavish, on the Cockpit's host at 8444, is Larry's, not a blog preview.
  private let lavish = "https://c-5004.squeaker-teeth.ts.net:8444/session/7d7f837c3898ed37"

  func testLavishReadsLarryLavishInABubbleAndOnTheStrip() {
    XCTAssertEqual(read("plus AI multiplier: \(lavish)"), ["plus AI multiplier: [Larry: Lavish]"])
    XCTAssertEqual(ChatLinks.found(in: lavish).map(\.label), ["Larry: Lavish"])
    XCTAssertEqual(read("preview at \(preview)."), ["preview at [Preview]."], "the blog's preview still reads Preview")
  }

  func testTwoLavishPagesAreTwoChips() {
    let other = "https://c-5004.squeaker-teeth.ts.net:8444/session/6ca47370d1a1f30b"
    XCTAssertEqual(ChatLinks.found(in: "\(lavish) \(other)").map(\.id).count, 2)
    XCTAssertNotEqual(ChatLinks.found(in: lavish).first?.id, ChatLinks.found(in: other).first?.id)
  }

  /// The board's conversation (story 1127): the words as written, each link its bubble chip in its place.
  func testPiecesKeepTheWordsAndPutChipsWhereTheLinksWere() {
    let reply = "All three trees are there,\nplus AI multiplier: \(lavish) and \(pr734)."
    let pieces = ChatBubbleLinks.pieces(in: reply).map { piece -> String in
      switch piece {
      case .words(let words): return words
      case .chip(let link): return "[\(link.label)]"
      }
    }
    XCTAssertEqual(
      pieces, ["All three trees are there,\nplus AI multiplier: ", "[Larry: Lavish]", " and ", "[PR]", "."])
    guard case .chip(let first)? = ChatBubbleLinks.pieces(in: reply).dropFirst().first else {
      return XCTFail("the Lavish link is a chip")
    }
    XCTAssertEqual(first.url.absoluteString, lavish, "the chip opens the full address")
  }

  func testPiecesOfWordsWithNoLinkAreTheWords() {
    XCTAssertEqual(ChatBubbleLinks.pieces(in: "no links here"), [.words("no links here")])
    XCTAssertEqual(ChatBubbleLinks.pieces(in: ""), [])
  }
}
