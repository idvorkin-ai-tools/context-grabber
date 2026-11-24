import XCTest

@testable import ContextCore

/// Story 1277 (#1384): the board's open conversation reads as Lines or as Bubbles.
final class WhiteboardPanelLookTests: XCTestCase {
  private func message(_ id: String, _ who: String, _ text: String, attachments: [String] = []) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: who, text: text, attachments: attachments)
  }

  func testAStoredChoiceReadsBackAndAnUnknownOneIsNone() {
    XCTAssertEqual(WhiteboardPanelLook(rawValue: "bubbles"), .bubbles)
    XCTAssertEqual(WhiteboardPanelLook(rawValue: "lines"), .lines)
    XCTAssertNil(WhiteboardPanelLook(rawValue: "nonsense"), "the panel then keeps its default, Lines")
  }

  func testTheSwitchNamesEachLook() {
    XCTAssertEqual(WhiteboardPanelLook.allCases.map(\.title), ["Lines", "Bubbles"])
  }

  func testBubblesShowTheSameMessagesAsLinesIgorOnTheRight() {
    let thread = [
      message("p", "igor", WhiteboardNote.boardTurnNote, attachments: ["board.png"]),
      message("a", "larry", "A circle."),
      message("b", "igor", "Make it bigger"),
      message("c", "larry", ""),
    ]
    let bubbles = WhiteboardPanelLook.bubbles(WhiteboardNote.recent(thread))
    XCTAssertEqual(bubbles.map(\.id), ["a", "b", "c"], "the word-less picture is left out, as in Lines")
    XCTAssertEqual(bubbles.map(\.mine), [false, true, false])
    XCTAssertEqual(bubbles.map(\.text), ["A circle.", "Make it bigger", "drew on the board"])
    XCTAssertEqual(bubbles.map(\.quiet), [false, false, true], "a reply of marks alone reads quietly")
  }

  func testLiveRowsAreNeverBubbles() {
    let live = WhiteboardNote.Row(id: "live-chip", kind: .live, who: "Your board", text: "Answered")
    XCTAssertEqual(WhiteboardPanelLook.bubbles([live]), [])
  }
}
