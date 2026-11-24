import Foundation
import XCTest

@testable import ContextCore

/// Keep beside any mark of a reply keeps the whole reply (story 1154; bead context-grabber-it0e; Igor, 2026-11-22 21:34,
/// option A). The oracle is the shapes spec's "Keep beside any mark of a reply keeps the whole reply": the chosen mark
/// and every other mark of its reply still showing are kept, as Keep all keeps that reply; other replies, his text from
/// a change and Claude's marks stay. Dismiss beside a reply of several takes the whole reply too (story 1286, #1383).
final class WhiteboardKeepReplyTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  /// Larry's smiley face from the iPad (reply 66618df4a0cc, 21:28): a label, an arrow, the face, the smile, two eyes and a
  /// label, seven marks of one reply. Another reply of two, his text from a change, and a mark of Claude's beside them.
  private let face = (0..<7).map { "66618df4a0cc#\($0)" }

  private func turns() -> WhiteboardGhostTurns<G> {
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    turns.land([G(id: "c0", who: .claude)], who: .claude, first: true, now: .now)
    turns.larrysMarks(face.map { G(id: $0, who: .larry) })
    turns.larrysMarks([G(id: "r2#0", who: .larry), G(id: "r2#1", who: .larry)])
    turns.larrysMarks([G(id: "op-text:t", who: .larry)])
    return turns
  }

  func testKeepBesideOneEyeKeepsAllSevenOfTheFace() throws {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "66618df4a0cc#4" })
    let kept = try XCTUnwrap(turns.keepChosenReply())
    XCTAssertEqual(kept.map(\.id), face, "all seven, in the order they came")
    XCTAssertEqual(turns.ghosts.map(\.id), ["c0", "r2#0", "r2#1", "op-text:t"], "the other reply, his text, Claude's")
    XCTAssertNil(turns.chosen, "Keep and Dismiss went with the marks")
    XCTAssertEqual(Set(WhiteboardMarks.keptGroups(kept.map(\.id)).values), ["66618df4a0cc"], "one group, the reply's")
  }

  /// Story 1286 (#1383): Dismiss beside a mark of a reply of several takes the whole reply; the other reply stays.
  func testDismissGroupTakesTheWholeReply() throws {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "66618df4a0cc#1" })
    let gone = try XCTUnwrap(turns.dismissChosen())
    XCTAssertEqual(gone.map(\.id), face, "all seven, in the order they came")
    XCTAssertEqual(turns.ghosts.map(\.id), ["c0", "r2#0", "r2#1", "op-text:t"], "the other reply, his text, Claude's")
    XCTAssertNil(turns.chosen, "Keep and Dismiss went with the marks")
  }

  /// Stories 1285, 1292 (#1383): a tap on any mark of a reply chooses the reply; another of its marks changes nothing.
  func testATapChoosesTheWholeReplyAndAnotherOfItsMarksChangesNothing() throws {
    var turns = turns()
    guard case .chose = turns.tap(hitting: { $0.id == "66618df4a0cc#2" }) else { return XCTFail("chose the reply") }
    XCTAssertEqual(turns.chosenMarks.map(\.id), face, "the whole reply is chosen")
    guard case .nothing = turns.tap(hitting: { $0.id == "66618df4a0cc#5" }) else {
      return XCTFail("another mark of the chosen reply changes nothing")
    }
    XCTAssertEqual(turns.chosen?.id, "66618df4a0cc#2", "still the first mark tapped")
    guard case .chose = turns.tap(hitting: { $0.id == "r2#1" }) else { return XCTFail("the other reply") }
    XCTAssertEqual(turns.chosenMarks.map(\.id), ["r2#0", "r2#1"])
  }

  /// Story 1285: the outlined replies are Larry's with two or more marks showing, hidden ones left out.
  func testTheOutlinedRepliesAreHisRepliesOfTwoOrMore() {
    var turns = turns()
    XCTAssertEqual(turns.groupedReplies.map(\.reply), ["66618df4a0cc", "r2"])
    XCTAssertEqual(turns.groupedReplies.first?.marks.count, 7)
    turns.hiddenMarks = ["r2#0"]
    XCTAssertEqual(turns.groupedReplies.map(\.reply), ["66618df4a0cc"], "one mark of r2 left showing: no outline")
  }

  func testALoneMarkHisTextAndClaudesAreKeptAlone() throws {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "op-text:t" })
    XCTAssertEqual(try XCTUnwrap(turns.keepChosenReply()).map(\.id), ["op-text:t"], "his text from a change, alone")
    _ = turns.tap(hitting: { $0.id == "c0" })
    XCTAssertEqual(try XCTUnwrap(turns.keepChosenReply()).map(\.id), ["c0"], "Claude's mark, alone")
    turns.hiddenMarks = ["r2#0"]
    _ = turns.tap(hitting: { $0.id == "r2#1" })
    XCTAssertEqual(turns.chosenMarks.map(\.id), ["r2#1"], "a reply's last mark showing is chosen alone")
    let last = try XCTUnwrap(turns.keepChosenReply())
    XCTAssertEqual(last.map(\.id), ["r2#1"], "a reply's last mark")
    XCTAssertEqual(WhiteboardMarks.keptGroups(last.map(\.id)), [:], "kept alone, in no group")
  }

  func testNothingChosenKeepsNothing() {
    var turns = turns()
    XCTAssertNil(turns.keepChosenReply())
    XCTAssertEqual(turns.ghosts.count, 11)
  }
}
