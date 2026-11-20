import XCTest

@testable import ContextCore

/// The oracle is the shapes spec's *A reply of Larry's makes room for what Igor wrote after Larry looked* (#894, stories
/// 1004–1006), #912's *A late reply*: a kept reply of his that sits on ink made after his picture pushes that ink down
/// clear of it, his marks staying where he put them; ink he saw never makes room.
final class BoardRoomLateTests: XCTestCase {
  private let line = BoardRoom.line
  private let air = BoardRoom.air
  /// When his picture was taken.
  private let seen: Int64 = 1_795_000_000_000

  /// A line of writing across the page, y...y+24.
  private func writing(_ y: CGFloat, x: CGFloat = 80, width: CGFloat = 500) -> CGRect {
    CGRect(x: x, y: y, width: width, height: 24)
  }

  private func stroke(_ name: String, _ box: CGRect, after: Bool) -> BoardOps.Stroke {
    BoardOps.Stroke(ids: [name], t: after ? seen + 60_000 : seen - 60_000, bounds: box)
  }

  // MARK: Boxes

  func testAReplyOnWritingNewerThanItsPicturePushesThatWritingClearOfIt() {
    // His plan at 100; Larry's reply aimed at the blank paper under it, where Igor has since written two lines.
    let plan = writing(100)
    let newer = [writing(200), writing(240)]
    let marks = [CGRect(x: 120, y: 190, width: 200, height: 70)]
    let late = BoardRoom.late(marks, newer: newer, among: [plan] + newer)
    let push = try? XCTUnwrap(late.push)
    XCTAssertEqual(late.covered, 2)
    XCTAssertEqual(push?.cut, 200, "the clear line at the top of the newer writing")
    let dy = push?.dy ?? 0
    XCTAssertEqual(dy.truncatingRemainder(dividingBy: line), 0, "whole lines")
    XCTAssertGreaterThanOrEqual(200 + dy, marks[0].maxY + air, "the first newer line now sits under his lowest mark")
    XCTAssertLessThan(200 + dy - line, marks[0].maxY + air, "and no further than it needs")
    XCTAssertLessThan(plan.maxY, push?.cut ?? 0, "his plan above stays")
  }

  func testAReplyOnlyOnInkInHisPictureMovesNothing() {
    // A circle round a word he saw: he meant it.
    let word = writing(200, x: 120, width: 80)
    let marks = [CGRect(x: 110, y: 190, width: 100, height: 44)]
    let late = BoardRoom.late(marks, newer: [writing(400)], among: [word, writing(400)])
    XCTAssertNil(late.push)
    XCTAssertEqual(late.covered, 0)
  }

  func testAReplyBesideNewerInkWithoutTouchingItMovesNothing() {
    let newer = writing(200, x: 80, width: 100)
    let marks = [CGRect(x: 300, y: 195, width: 120, height: 30)]
    XCTAssertNil(BoardRoom.late(marks, newer: [newer], among: [newer]).push)
  }

  func testTouchingAnEdgeIsNotSittingOn() {
    let newer = writing(200)
    let marks = [CGRect(x: 120, y: 160, width: 200, height: 40)]
    XCTAssertNil(BoardRoom.late(marks, newer: [newer], among: [newer]).push)
  }

  func testNewerInkInALineThatStartedAboveTheReplyGoesWholeUnderIt() {
    // A tall line of his (a drawing, 120 points) whose top is above the reply's: the cut is that line's top, however
    // far, so none of it is left under his marks.
    let drawing = CGRect(x: 80, y: 200, width: 300, height: 120)
    let marks = [CGRect(x: 120, y: 300, width: 100, height: 40)]
    let push = BoardRoom.late(marks, newer: [drawing], among: [writing(100), drawing]).push
    XCTAssertEqual(push?.cut, 200)
    XCTAssertGreaterThanOrEqual(200 + (push?.dy ?? 0), marks[0].maxY + air)
  }

  func testEveryMarkCountsAndTheLowestSetsHowFar() {
    // A group: a label on clear paper high up, an arrow down onto his newer line.
    let newer = writing(300)
    let marks = [CGRect(x: 120, y: 100, width: 100, height: 30), CGRect(x: 150, y: 130, width: 4, height: 190)]
    let push = BoardRoom.late(marks, newer: [newer], among: [newer]).push
    XCTAssertEqual(push?.cut, 300)
    XCTAssertGreaterThanOrEqual(300 + (push?.dy ?? 0), 320 + air)
  }

  // MARK: Strokes

  func testOnlyStrokesMadeAfterThePictureMakeRoom() {
    let old = stroke("old", writing(200), after: false)
    let new = stroke("new", writing(400), after: true)
    let onOld = [CGRect(x: 120, y: 190, width: 100, height: 40)]
    let onNew = [CGRect(x: 120, y: 390, width: 100, height: 40)]
    XCTAssertNil(BoardRoom.late(onOld, seen: seen, strokes: [old, new]).push)
    let push = BoardRoom.late(onNew, seen: seen, strokes: [old, new]).push
    XCTAssertEqual(push?.cut, 400)
  }

  func testAStrokeWhoseMakingIsNotKnownIsTakenAsSeen() {
    let unknown = BoardOps.Stroke(ids: ["u"], t: nil, bounds: writing(200))
    XCTAssertNil(BoardRoom.late([CGRect(x: 120, y: 190, width: 100, height: 40)], seen: seen, strokes: [unknown]).push)
  }

  func testAGroupWithAStrokeMadeAfterThePictureIsNewerAndMovesWhole() {
    // Two strokes of one group: one old, one added after; the group is one thing, and the cut never splits it.
    let a = stroke("a", CGRect(x: 80, y: 200, width: 100, height: 24), after: false)
    let b = stroke("b", CGRect(x: 80, y: 230, width: 100, height: 24), after: true)
    let late = BoardRoom.late(
      [CGRect(x: 90, y: 235, width: 60, height: 30)], seen: seen, strokes: [a, b], groups: ["a": "g", "b": "g"])
    XCTAssertEqual(late.covered, 1)
    XCTAssertEqual(late.push?.cut, 200, "the group's top, not between its strokes")
  }

  func testAMarkOfLarrysKeptAfterThePictureNeverMakesRoom() {
    // His box, kept a moment before the arrow that ends on it: made after the picture, but his.
    let box = stroke("box", writing(200, width: 100), after: true)
    let arrow = [CGRect(x: 120, y: 150, width: 4, height: 70)]
    let theirs: Set<Int64> = [seen + 60_000]
    let late = BoardRoom.late(arrow, seen: seen, strokes: [box], theirs: theirs)
    XCTAssertNil(late.push)
    XCTAssertEqual(late.covered, 0)
  }

  func testAMarkOfLarrysReadBackAMillisecondOffIsStillHis() {
    // A saved drawing reads a stroke's time back truncated: his box kept at t+1 shows as t.
    let box = stroke("box", writing(200, width: 100), after: true)
    let arrow = [CGRect(x: 120, y: 150, width: 4, height: 70)]
    let late = BoardRoom.late(arrow, seen: seen, strokes: [box], theirs: [seen + 60_001])
    XCTAssertNil(late.push)
    XCTAssertEqual(late.covered, 0)
  }

  func testIgorsNewerInkBesideAKeptMarkOfLarrysStillMakesRoom() {
    let box = stroke("box", writing(200, width: 100), after: true)
    let igor = BoardOps.Stroke(ids: ["igor"], t: seen + 90_000, bounds: writing(200, x: 300, width: 100))
    let marks = [CGRect(x: 120, y: 150, width: 300, height: 70)]
    let late = BoardRoom.late(marks, seen: seen, strokes: [box, igor], theirs: [seen + 60_000])
    XCTAssertEqual(late.covered, 1, "Igor's line, not Larry's box")
    XCTAssertEqual(late.push?.cut, 200)
  }

  func testHiddenInkNeverMakesRoom() {
    var folded = stroke("f", writing(200), after: true)
    folded.hidden = true
    XCTAssertNil(BoardRoom.late([CGRect(x: 120, y: 190, width: 100, height: 40)], seen: seen, strokes: [folded]).push)
  }

  // MARK: When each picture was taken (story 1006)

  private func times() throws -> WhiteboardPictureTimes {
    let suite = "whiteboard-picture-times-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
    return WhiteboardPictureTimes(defaults: defaults)
  }

  func testAPictureIsRememberedForItsBoardOnly() throws {
    let times = try times()
    times.record("p1", at: 1000, board: "b1")
    XCTAssertEqual(times.taken("p1", board: "b1"), 1000)
    XCTAssertNil(times.taken("p1", board: "b2"))
    XCTAssertNil(times.taken("p2", board: "b1"))
    XCTAssertNil(times.taken(nil, board: "b1"))
  }

  func testAPictureIDThatPrefixesAnotherIsNotTakenForIt() throws {
    let times = try times()
    times.record("p10", at: 1000, board: "b1")
    XCTAssertNil(times.taken("p1", board: "b1"))
  }

  func testTheNewest200AreKept() throws {
    let times = try times()
    for i in 0..<(WhiteboardPictureTimes.kept + 5) { times.record("p\(i)", at: Int64(i), board: "b1") }
    XCTAssertNil(times.taken("p0", board: "b1"))
    XCTAssertNil(times.taken("p4", board: "b1"))
    XCTAssertEqual(times.taken("p5", board: "b1"), 5)
    XCTAssertEqual(times.taken("p204", board: "b1"), 204)
  }

  func testRecordingAgainKeepsTheNewerTime() throws {
    let times = try times()
    times.record("p1", at: 1000, board: "b1")
    times.record("p1", at: 2000, board: "b1")
    XCTAssertEqual(times.taken("p1", board: "b1"), 2000)
  }
}
