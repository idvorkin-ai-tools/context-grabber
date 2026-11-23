import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Keep all (stories 895, 995, 998–1000, 1004; #942; bead context-grabber-yqau, which made Keep group and Keep all one
/// button): every mark of Larry's showing is kept, each reply of his as one group, with one room for what Igor wrote
/// after each reply's picture; and the buttons beside a chosen mark never sit under the board's top-right corner. The
/// oracle is the shapes spec's "Keep all keeps every mark of Larry's showing, each reply as one thing" and "Keep all
/// makes room once, for all of it".
final class WhiteboardKeepAllTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  private func turns() -> WhiteboardGhostTurns<G> {
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    turns.land([G(id: "c0", who: .claude)], who: .claude, first: true, now: .now)
    turns.larrysMarks([G(id: "r1#0", who: .larry), G(id: "r1#1", who: .larry), G(id: "r1#3", who: .larry)])
    turns.larrysMarks([G(id: "op-text:t", who: .larry)])
    return turns
  }

  func testAMarkBelongsToTheReplyItCameIn() {
    XCTAssertEqual(WhiteboardMarks.reply(of: WhiteboardMarks.mark(4, of: "12c6abcb46e7")), "12c6abcb46e7")
    XCTAssertNil(WhiteboardMarks.reply(of: "op-text:t"))
    XCTAssertNil(WhiteboardMarks.reply(of: "a#b"))
    XCTAssertEqual(WhiteboardMarks.group(reply: "12c6abcb46e7"), "reply-12c6abcb46e7")
  }

  func testKeepAllTakesEveryMarkOfLarrysAndLeavesClaudes() {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "r1#1" })
    XCTAssertEqual(
      turns.keepAll(.larry).map(\.id), ["r1#0", "r1#1", "r1#3", "op-text:t"], "every one of his, in the order they came"
    )
    XCTAssertEqual(turns.ghosts.map(\.id), ["c0"], "Claude's stay showing")
    XCTAssertNil(turns.chosen, "Keep and Dismiss went with the marks")
  }

  func testEachReplyIsAGroupOfItsOwn() {
    let groups = WhiteboardMarks.keptGroups(["r1#0", "r2#0", "r1#1", "r2#4", "r1#2"])
    XCTAssertEqual(groups, ["r1#0": "r1", "r1#1": "r1", "r1#2": "r1", "r2#0": "r2", "r2#4": "r2"])
  }

  func testALoneMarkAndHisTextFromAChangeAreKeptAlone() {
    let groups = WhiteboardMarks.keptGroups(["r1#0", "r1#1", "r3#2", "op-text:t", "op-text:u"])
    XCTAssertEqual(
      groups, ["r1#0": "r1", "r1#1": "r1"], "one mark left of r3, and texts that are no reply's, in no group")
    XCTAssertEqual(WhiteboardMarks.keptGroups(["r3#2"]), [:])
    XCTAssertEqual(WhiteboardMarks.keptGroups([]), [:])
  }

  func testTheGroupsNotesNameTheReply() {
    XCTAssertEqual(WhiteboardMarks.groupNote(reply: "r1")?.group, "reply-r1")
  }

  func testAGroupedConnectorKeepsItsEndsAndRoute() throws {
    let connector = BoardConnector(
      from: "left", to: "right", fromSide: .right, toSide: .left,
      route: [CGPoint(x: 10, y: 20), CGPoint(x: 40, y: 20)])
    let existing = connector.meta(over: BoardMeta(["label": "my note", "group": "old"]))
    let grouped = try XCTUnwrap(WhiteboardMarks.groupNote(reply: "r1", over: existing))
    XCTAssertEqual(grouped.group, "reply-r1")
    XCTAssertEqual(BoardConnector(grouped), connector)
    XCTAssertEqual((grouped.object as? [String: Any])?["label"] as? String, "my note")
  }

  // MARK: One room, each reply against its own picture

  /// When each picture was taken: the first reply answers `early`, the second `later`.
  private let early: Int64 = 1_795_000_000_000
  private var later: Int64 { early + 120_000 }

  private func writing(_ name: String, _ y: CGFloat, made t: Int64) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [name], t: t, bounds: CGRect(x: 80, y: y, width: 500, height: 24))
  }

  func testTwoRepliesMakeOneRoomUnderTheLowestMark() {
    // Igor wrote a line after both pictures, under the first reply's mark; the second reply sits lower on clear paper.
    let line = writing("new", 200, made: later + 60_000)
    let marks: [(box: CGRect, seen: Int64?)] = [
      (CGRect(x: 120, y: 190, width: 200, height: 40), early),
      (CGRect(x: 120, y: 300, width: 200, height: 40), later),
    ]
    let late = BoardRoom.late(marks, strokes: [line])
    let push = try? XCTUnwrap(late.push)
    XCTAssertEqual(late.covered, 1)
    XCTAssertEqual(push?.cut, 200)
    XCTAssertGreaterThanOrEqual(200 + (push?.dy ?? 0), 340 + BoardRoom.air, "under the lowest mark of both replies")
  }

  func testInkInAReplysOwnPictureNeverMakesRoomForItsMarks() {
    // Written between the two pictures: the later reply saw it, the earlier one didn't.
    let between = writing("between", 300, made: early + 60_000)
    let underLater: [(box: CGRect, seen: Int64?)] = [
      (CGRect(x: 120, y: 100, width: 200, height: 40), early),
      (CGRect(x: 120, y: 290, width: 200, height: 40), later),
    ]
    XCTAssertNil(BoardRoom.late(underLater, strokes: [between]).push, "only the later reply sits on it, and it saw it")
    let underEarlier: [(box: CGRect, seen: Int64?)] = [
      (CGRect(x: 120, y: 290, width: 200, height: 40), early),
      (CGRect(x: 120, y: 100, width: 200, height: 40), later),
    ]
    XCTAssertNotNil(BoardRoom.late(underEarlier, strokes: [between]).push, "the earlier reply didn't see it")
  }

  func testAMarkWithNoPictureTimeMakesNoRoomButTheRoomGoesUnderIt() {
    let line = writing("new", 200, made: later + 60_000)
    let unknown: [(box: CGRect, seen: Int64?)] = [(CGRect(x: 120, y: 190, width: 200, height: 40), nil)]
    XCTAssertNil(BoardRoom.late(unknown, strokes: [line]).push, "no time known, nothing moves")
    let both: [(box: CGRect, seen: Int64?)] = [
      (CGRect(x: 120, y: 190, width: 200, height: 40), early),
      (CGRect(x: 120, y: 400, width: 200, height: 40), nil),
    ]
    let push = BoardRoom.late(both, strokes: [line]).push
    XCTAssertGreaterThanOrEqual(200 + (push?.dy ?? 0), 440 + BoardRoom.air, "under the unknown one too")
  }

  func testHisTextFromAChangePushesWhatItLandsOnUnderItWhenItWasMade() {
    // A line Igor wrote before any picture: a reply's mark there moves nothing, his text from a change does (#938).
    let line = writing("old", 200, made: early - 60_000)
    let text = CGRect(x: 120, y: 190, width: 200, height: 40)
    XCTAssertNil(BoardRoom.late([(box: text, seen: Optional(early))], strokes: [line]).push)
    let late = BoardRoom.late([], landing: [text], strokes: [line])
    let push = try? XCTUnwrap(late.push)
    XCTAssertEqual(late.covered, 0)
    XCTAssertEqual(push?.cut, 200)
    XCTAssertGreaterThanOrEqual(200 + (push?.dy ?? 0), text.maxY + BoardRoom.air, "the line goes under the text")
  }

  func testHisTextInsideAFrameLeavesTheFrameWhereItIs() {
    let frame = BoardOps.Stroke(ids: ["box"], t: later + 60_000, bounds: CGRect(x: 80, y: 150, width: 400, height: 200))
    let text = CGRect(x: 120, y: 190, width: 200, height: 40)
    XCTAssertNil(BoardRoom.late([], landing: [text], strokes: [frame]).push, "a label in a box stays in it")
  }

  func testHisTextAndALateReplyMakeOneRoomUnderBoth() {
    let line = writing("new", 200, made: later + 60_000)
    let other = writing("other", 420, made: early - 60_000)
    let late = BoardRoom.late(
      [(box: CGRect(x: 120, y: 190, width: 200, height: 40), seen: Optional(early))],
      landing: [CGRect(x: 120, y: 410, width: 200, height: 40)], strokes: [line, other])
    XCTAssertEqual(late.covered, 1)
    XCTAssertEqual(late.push?.cut, 200)
    XCTAssertGreaterThanOrEqual(420 + (late.push?.dy ?? 0), 450 + BoardRoom.air, "one room, under his text too")
  }

  func testOnePictureTimePushesTheLineUnderTheMark() {
    let line = writing("new", 200, made: early + 60_000)
    let box = CGRect(x: 120, y: 190, width: 200, height: 40)
    for room in [
      BoardRoom.late([box], seen: early, strokes: [line]),
      BoardRoom.late([(box: box, seen: Optional(early))], strokes: [line]),
    ] {
      XCTAssertEqual(room.covered, 1)
      XCTAssertEqual(room.push?.cut, 200)
      XCTAssertEqual(room.push?.dy, 80)
    }
  }

  // MARK: Where the buttons go

  private let view = CGRect(x: 0, y: 0, width: 820, height: 1000)
  private let corner = CGRect(x: 560, y: 40, width: 240, height: 90)
  private let buttons = CGSize(width: 300, height: 44)

  func testButtonsUnderTheCornerMoveBelowIt() {
    let mark = CGRect(x: 600, y: 60, width: 150, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view, avoid: corner)
    XCTAssertFalse(placed.intersects(corner), "\(placed)")
    XCTAssertGreaterThanOrEqual(placed.minY, corner.maxY)
    XCTAssertTrue(view.contains(placed))
  }

  func testButtonsClearOfTheCornerStayBesideTheirMark() {
    let mark = CGRect(x: 100, y: 500, width: 150, height: 60)
    XCTAssertEqual(
      WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view, avoid: corner),
      WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view))
  }

  func testWithNoRoomBelowTheyGoLeftOfTheCorner() {
    let short = CGRect(x: 0, y: 0, width: 820, height: 170)
    let mark = CGRect(x: 600, y: 60, width: 150, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: short, avoid: corner)
    XCTAssertLessThanOrEqual(placed.maxX, corner.minX)
  }

  func testInAViewNarrowerThanTheButtonsTheyNarrowToStayOnScreen() {
    let narrow = CGRect(x: 0, y: 0, width: 320, height: 600)
    let mark = CGRect(x: 40, y: 200, width: 100, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: CGSize(width: 400, height: 48), in: narrow)
    XCTAssertTrue(narrow.contains(placed), "\(placed)")
    XCTAssertEqual(placed.height, 48)
  }
}
