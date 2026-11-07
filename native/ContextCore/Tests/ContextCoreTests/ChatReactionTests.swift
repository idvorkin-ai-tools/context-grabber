import XCTest

@testable import ContextCore

/// What press and hold writes (#629, stories 519, 540-541).
final class ChatReactionTests: XCTestCase {
  private func larry(_ text: String) -> ChatMessage { ChatMessage(id: "m", ts: "", who: "larry", text: text) }

  func testAReactionToTheNewestIsTheBareWord() {
    XCTAssertEqual(ChatReaction.yes.text(answering: larry("Ship it?"), newest: true), "Yes")
    XCTAssertEqual(ChatReaction.no.text(answering: larry("Ship it?"), newest: true), "No")
  }

  func testAReactionToAnOlderMessageGoesUnderItsQuote() {
    XCTAssertEqual(ChatReaction.no.text(answering: larry("Ship it?"), newest: false), "> Ship it?\n\nNo")
  }

  func testAPictureAloneIsQuotedAsAPicture() {
    let picture = ChatMessage(id: "m", ts: "", who: "larry", text: "  ", attachments: ["a.png"])
    XCTAssertEqual(ChatReaction.yes.text(answering: picture, newest: false), "> A picture\n\nYes")
  }

  func testEveryLineIsMarkedAndABlankLineHoldsTogether() {
    XCTAssertEqual(ChatQuote.quoted(larry("one\n\ntwo\n")), "> one\n>\n> two")
  }

  func testEveryLineIsMarkedWhenTheLinesEndInCRLF() {
    XCTAssertEqual(ChatQuote.quoted(larry("one\r\n\r\ntwo")), "> one\n>\n> two")
  }

  func testALongMessageIsCutToTheLimit() {
    let exact = String(repeating: "a", count: ChatQuote.maxCharacters)
    XCTAssertEqual(ChatQuote.quoted(larry(exact)), "> " + exact)
    let quote = ChatQuote.quoted(larry(exact + "b"))
    XCTAssertEqual(quote, "> " + String(repeating: "a", count: ChatQuote.maxCharacters - 1) + "…")
  }

  func testAQuoteIntoAnEmptyBarLeavesRoomForTheReply() {
    XCTAssertEqual(ChatQuote.appended(larry("Ship it?"), to: " \n"), "> Ship it?\n\n")
  }

  func testAQuoteFollowsWhatTheBarHeld() {
    XCTAssertEqual(ChatQuote.appended(larry("Ship it?"), to: "half typed"), "half typed\n\n> Ship it?\n\n")
  }

  func testTwoQuotesKeepBoth() {
    let first = ChatQuote.appended(larry("one"), to: "")
    XCTAssertEqual(ChatQuote.appended(larry("two"), to: first), "> one\n\n> two\n\n")
  }

  // MARK: The hold menu (stories 518, 540-541)

  func testLarrysWordsOfferAllFourAndMineOnlyQuoteAndCopy() {
    XCTAssertEqual(ChatHold.choices(for: larry("Ship it?")), [.react(.yes), .react(.no), .quote, .copy])
    let mine = ChatMessage(id: "i", ts: "", who: "igor", text: "Yes")
    XCTAssertEqual(ChatHold.choices(for: mine), [.quote, .copy], "no answer to myself")
  }

  func testAPictureAloneHasNoWordsToQuoteOrCopy() {
    let picture = ChatMessage(id: "p", ts: "", who: "larry", text: " \n", attachments: ["2026-10-25/a.png"])
    XCTAssertEqual(ChatHold.choices(for: picture), [.react(.yes), .react(.no)])
    let myPicture = ChatMessage(id: "q", ts: "", who: "igor", text: "", attachments: ["2026-10-25/b.png"])
    XCTAssertEqual(ChatHold.choices(for: myPicture), [])
  }

  func testTheMenuSaysWhatEachChoiceDoes() {
    XCTAssertEqual(
      ChatHold.choices(for: larry("x")).map(\.label), ["Yes", "No", "Quote in reply", "Copy"])
    XCTAssertEqual(
      ChatHold.choices(for: larry("x")).map(\.systemImage),
      ["hand.thumbsup", "hand.thumbsdown", "text.quote", "doc.on.doc"])
  }

  /// GRABBER_CHAT_HOLD on the simulator: each word is one choice, and nothing else is.
  func testTheHoldHookNamesOneChoice() {
    XCTAssertEqual(ChatHold(hook: "yes"), .react(.yes))
    XCTAssertEqual(ChatHold(hook: "no"), .react(.no))
    XCTAssertEqual(ChatHold(hook: "quote"), .quote)
    XCTAssertEqual(ChatHold(hook: "copy"), .copy)
    XCTAssertNil(ChatHold(hook: "Yes"))
    XCTAssertNil(ChatHold(hook: ""))
  }
}
