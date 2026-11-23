import Foundation
import XCTest

@testable import ContextCore

/// Keep beside any mark of a reply keeps the whole reply (story 1154; bead context-grabber-it0e; Igor, 2026-11-22 21:34,
/// option A). The oracle is the shapes spec's "Keep beside any mark of a reply keeps the whole reply": the chosen mark
/// and every other mark of its reply still showing are kept, as Keep all keeps that reply; other replies, his text from
/// a change and Claude's marks stay; Dismiss still takes only the chosen mark.
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

  func testDismissTakesOneAndKeepThenTakesTheRestAsOneGroup() throws {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "66618df4a0cc#1" })
    XCTAssertEqual(turns.dismissChosen()?.id, "66618df4a0cc#1", "Dismiss takes the arrow alone")
    XCTAssertEqual(turns.ghosts.filter { $0.id.hasPrefix("66618df4a0cc") }.count, 6)
    _ = turns.tap(hitting: { $0.id == "66618df4a0cc#5" })
    let kept = try XCTUnwrap(turns.keepChosenReply())
    XCTAssertEqual(kept.map(\.id), face.filter { $0 != "66618df4a0cc#1" }, "the other six")
    XCTAssertEqual(WhiteboardMarks.keptGroups(kept.map(\.id)).count, 6, "all six in the reply's group")
  }

  func testALoneMarkHisTextAndClaudesAreKeptAlone() throws {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "op-text:t" })
    XCTAssertEqual(try XCTUnwrap(turns.keepChosenReply()).map(\.id), ["op-text:t"], "his text from a change, alone")
    _ = turns.tap(hitting: { $0.id == "c0" })
    XCTAssertEqual(try XCTUnwrap(turns.keepChosenReply()).map(\.id), ["c0"], "Claude's mark, alone")
    _ = turns.tap(hitting: { $0.id == "r2#0" })
    _ = turns.dismissChosen()
    _ = turns.tap(hitting: { $0.id == "r2#1" })
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
