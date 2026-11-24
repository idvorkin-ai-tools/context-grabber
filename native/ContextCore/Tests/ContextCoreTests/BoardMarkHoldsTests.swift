import XCTest

@testable import ContextCore

/// Stories 1180, 1181, 1269–1271 (bead context-grabber-p2an): Larry's unkept marks hold to the ink they answer, fold
/// with it, fade when Igor writes over them, and go on the next post.
final class BoardMarkHoldsTests: XCTestCase {
  /// A letter-sized stroke, as BoardOutlineTests draws them.
  private func letter(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 24) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + h), CGPoint(x: x + w / 2, y: y), CGPoint(x: x + w, y: y + h)]
    return BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: w, height: h), points: points, pen: 3)
  }

  /// A word of three letters: `<id>0`, `<id>1`, `<id>2`.
  private func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  /// A stroke along `points`, its box theirs.
  private func path(_ id: String, _ points: [CGPoint], pen: CGFloat = 2) -> BoardOps.Stroke {
    let box = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
    return BoardOps.Stroke(ids: [id], t: nil, bounds: box, points: points, pen: pen)
  }

  /// A line from `a` to `b` sampled every 2 points, as the Pencil reports one.
  private func line(_ id: String, from a: CGPoint, to b: CGPoint, pen: CGFloat = 2) -> BoardOps.Stroke {
    let n = max(Int(hypot(b.x - a.x, b.y - a.y) / 2), 1)
    return path(
      id,
      (0...n).map {
        CGPoint(x: a.x + (b.x - a.x) * CGFloat($0) / CGFloat(n), y: a.y + (b.y - a.y) * CGFloat($0) / CGFloat(n))
      },
      pen: pen)
  }

  /// A zigzag across `x` between `y`'s ends, 8 teeth, sampled as a Pencil reports one.
  private func zigzag(_ id: String, x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) -> BoardOps.Stroke {
    let corners = (0...16).map { i in
      CGPoint(
        x: x.lowerBound + (x.upperBound - x.lowerBound) * CGFloat(i) / 16, y: i % 2 == 0 ? y.lowerBound : y.upperBound)
    }
    let points = zip(corners, corners.dropFirst()).flatMap { a, b in line("", from: a, to: b).points.dropLast() }
    return path(id, points + [corners.last!])
  }

  /// A label of Larry's: a row of glyph lines filling `box`.
  private func label(_ id: String, _ box: CGRect) -> BoardMark {
    let glyphs = stride(from: box.minX, to: box.maxX, by: 12).map { x in
      [CGPoint(x: x, y: box.maxY), CGPoint(x: x + 5, y: box.minY), CGPoint(x: x + 10, y: box.maxY)]
    }
    return BoardMark(id: id, lines: glyphs, pen: 1.6, label: true)
  }

  /// A check of Larry's: two strokes of a tick.
  private func check(_ id: String, at p: CGPoint) -> BoardMark {
    BoardMark(
      id: id, lines: [[p, CGPoint(x: p.x + 10, y: p.y + 12), CGPoint(x: p.x + 30, y: p.y - 16)]], pen: 2.5, label: false
    )
  }

  private func moved(_ strokes: [BoardOps.Stroke], _ ids: Set<String>, dy: CGFloat, dx: CGFloat = 0) -> [BoardOps
    .Stroke]
  {
    strokes.map { s in
      guard ids.contains(s.ids[0]) else { return s }
      var s = s
      s.bounds = s.bounds.offsetBy(dx: dx, dy: dy)
      s.points = s.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
      return s
    }
  }

  // MARK: The anchor

  func testAMarkHoldsToTheUnitItOverlapsMostElseTheNearestAboveOrBesideElseNothing() {
    let ink = BoardMarkHolds.Ink(strokes: word("a", x: 100, y: 100) + word("b", x: 100, y: 200))
    let onB = BoardMarkHolds.anchor(check("c", at: CGPoint(x: 120, y: 210)), on: ink)
    XCTAssertEqual(onB.strokes.first?.name, "b1", "a check on a word holds to the stroke it lies on most")
    XCTAssertEqual(onB.gap, 0)

    let under = BoardMarkHolds.anchor(label("l", CGRect(x: 100, y: 140, width: 80, height: 18)), on: ink)
    XCTAssertEqual(under.strokes.first.map { $0.name.prefix(1) }, "a", "a label under a line holds to the line above")
    XCTAssertEqual(under.gap, 16, accuracy: 0.01)

    let beside = BoardMarkHolds.anchor(check("c", at: CGPoint(x: 400, y: 214)), on: ink)
    XCTAssertEqual(beside.strokes.first?.name, "b2", "a check beside a line, its top above the check's middle")

    let top = BoardMarkHolds.anchor(label("l", CGRect(x: 100, y: 20, width: 80, height: 18)), on: ink)
    XCTAssertTrue(top.strokes.isEmpty, "above every line: nothing holds it")
    XCTAssertTrue(
      BoardMarkHolds.anchor(label("l", CGRect(x: 0, y: 0, width: 9, height: 9)), on: .init(strokes: [])).strokes.isEmpty
    )
  }

  func testAGroupIsOneUnitAndFoldedInkIsNoAnchor() {
    var strokes = word("a", x: 100, y: 100) + word("b", x: 100, y: 300)
    strokes[1].hidden = true
    let groups = ["b0": "g", "b1": "g", "b2": "g"]
    let ink = BoardMarkHolds.Ink(strokes: strokes, groups: groups)
    let anchor = BoardMarkHolds.anchor(label("l", CGRect(x: 100, y: 330, width: 120, height: 18)), on: ink)
    XCTAssertEqual(Set(anchor.strokes.map(\.name)), ["b0", "b1", "b2"], "the whole group, nearest first")
    let a = BoardMarkHolds.anchor(check("c", at: CGPoint(x: 120, y: 110)), on: ink)
    XCTAssertFalse(a.strokes.contains { $0.name == "a1" }, "a hidden stroke is never held: \(a.strokes)")
  }

  // MARK: Where it goes

  func testItMovesWithItsUnitThroughMovesRoomAndUndoAndRoomBetweenLeavesItBeside() {
    let strokes = word("a", x: 100, y: 100) + word("b", x: 100, y: 200)
    let mark = label("l", CGRect(x: 100, y: 140, width: 80, height: 18))
    let anchor = BoardMarkHolds.anchor(mark, on: .init(strokes: strokes))
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: strokes), .init())

    let dragged = moved(strokes, ["a0", "a1", "a2"], dy: 40, dx: 30)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: dragged), .init(dx: 30, dy: 40), "a drag")
    let room = moved(strokes, ["a0", "a1", "a2", "b0", "b1", "b2"], dy: 80)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: room), .init(dy: 80), "room above both pushes both")
    let between = moved(strokes, ["b0", "b1", "b2"], dy: 80)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: between), .init(), "room between: it stays beside its line")
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: strokes), .init(), "undo puts it back with the line")
  }

  func testAFoldHidesItAndUnfoldBringsItBackWhereverItsInkIs() throws {
    let ink =
      word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("b", x: 140, y: 180)
      + word("c", x: 100, y: 220)
    let onA = check("onA", at: CGPoint(x: 160, y: 150))
    let onC = label("onC", CGRect(x: 100, y: 248, width: 70, height: 16))
    let anchors = [onA, onC].map { BoardMarkHolds.anchor($0, on: .init(strokes: ink)) }
    XCTAssertEqual(anchors[0].strokes.first?.name.prefix(1), "a")
    XCTAssertEqual(anchors[1].strokes.first?.name.prefix(1), "c")

    var outline = BoardOutline(strokes: ink, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    XCTAssertTrue(outline.fold("h"))
    XCTAssertEqual(BoardMarkHolds.place(anchors[0], on: outline.strokes).hidden, .folded, "folds with its section")
    XCTAssertEqual(
      BoardMarkHolds.place(anchors[1], on: outline.strokes), .init(dy: -40), "closes up with the line below")
    XCTAssertTrue(outline.unfold("h"))
    XCTAssertEqual(BoardMarkHolds.place(anchors[0], on: outline.strokes), .init(), "unfold: back beside its ink")
    XCTAssertEqual(BoardMarkHolds.place(anchors[1], on: outline.strokes), .init())
  }

  func testErasingItsInkHidesItErasingPartHandsItOnAndUndoBringsItBack() {
    let strokes = word("a", x: 100, y: 100)
    let anchor = BoardMarkHolds.anchor(check("c", at: CGPoint(x: 104, y: 108)), on: .init(strokes: strokes))
    XCTAssertEqual(anchor.strokes.first?.name, "a0")
    let part = moved(Array(strokes.dropFirst()), ["a1", "a2"], dy: 40)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: part), .init(dy: 40), "the next stroke of the word holds it")
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: []).hidden, .erased)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: []).drops, .inkErased)
    XCTAssertEqual(BoardMarkHolds.place(anchor, on: strokes), .init(), "undo of the erase: back")
  }

  // MARK: Written over

  func testWritingOnALabelOrScribblingOnACheckFadesItAndAnUnderlineCircleOrCrossingDoesNot() {
    let lbl = label("l", CGRect(x: 100, y: 140, width: 120, height: 18))
    let written = word("w", x: 110, y: 138)
    XCTAssertGreaterThanOrEqual(BoardMarkHolds.share(of: written[0], on: lbl), 0.9, "a word written on the label")
    let strike = line("s", from: CGPoint(x: 96, y: 149), to: CGPoint(x: 226, y: 149))
    XCTAssertTrue(BoardMarkHolds.writesOver(strike, lbl), "struck through")
    let underline = line("u", from: CGPoint(x: 100, y: 164), to: CGPoint(x: 220, y: 164))
    XCTAssertFalse(BoardMarkHolds.writesOver(underline, lbl), "underlined")
    let ring = path(
      "r",
      (0...36).map { i in
        let a = CGFloat(i) / 36 * 2 * .pi
        return CGPoint(x: 160 + 80 * cos(a), y: 149 + 24 * sin(a))
      })
    XCTAssertFalse(BoardMarkHolds.writesOver(ring, lbl), "a circle round it")

    let tick = check("c", at: CGPoint(x: 300, y: 300))
    let crossing = line("x", from: CGPoint(x: 260, y: 306), to: CGPoint(x: 380, y: 306))
    XCTAssertFalse(BoardMarkHolds.writesOver(crossing, tick), "a line across it")
    let scribble = path("z", (0..<12).map { CGPoint(x: 300 + CGFloat($0) * 2.5, y: $0 % 2 == 0 ? 300 : 312) })
    XCTAssertTrue(BoardMarkHolds.writesOver(scribble, tick), "a scribble along it")
  }

  func testAFadeRemembersItsStrokeUndoUnfadesItAndThePostDropsWhatFadedOrLostItsInk() {
    let a = word("a", x: 100, y: 100)
    let lbl = label("l", CGRect(x: 100, y: 140, width: 120, height: 18))
    let tick = check("c", at: CGPoint(x: 400, y: 104))
    var anchors = [
      "l": BoardMarkHolds.anchor(lbl, on: .init(strokes: a)), "c": BoardMarkHolds.anchor(tick, on: .init(strokes: a)),
    ]
    let over = word("w", x: 110, y: 138)
    let board = a + over
    var wrote: [(id: String, share: Double)] = []
    for stroke in over { wrote += BoardMarkHolds.wrote(stroke, marks: [lbl, tick], anchors: &anchors, strokes: board) }
    XCTAssertEqual(Set(wrote.map(\.id)), ["l"])
    XCTAssertEqual(anchors["l"]?.writtenBy, ["w0", "w1", "w2"])
    XCTAssertTrue(BoardMarkHolds.place(anchors["l"]!, on: board).faded)
    XCTAssertFalse(BoardMarkHolds.place(anchors["l"]!, on: a).faded, "undo of the writing: full strength again")
    XCTAssertEqual(
      BoardMarkHolds.drops([lbl, tick], anchors: anchors, strokes: board), [.init(id: "l", why: .writtenOver)])
    XCTAssertEqual(BoardMarkHolds.drops([lbl, tick], anchors: anchors, strokes: a), [])
    XCTAssertEqual(
      BoardMarkHolds.drops([lbl, tick], anchors: anchors, strokes: over),
      [.init(id: "l", why: .inkErased), .init(id: "c", why: .inkErased)], "its ink erased: both go")
  }

  func testAMovedMarkIsWrittenOverWhereItShowsNotWhereItLanded() {
    let a = word("a", x: 100, y: 100)
    let lbl = label("l", CGRect(x: 100, y: 140, width: 120, height: 18))
    var anchors = ["l": BoardMarkHolds.anchor(lbl, on: .init(strokes: a))]
    let pushed = moved(a, ["a0", "a1", "a2"], dy: 200)
    let whereItLanded = word("w", x: 110, y: 138)
    XCTAssertTrue(
      BoardMarkHolds.wrote(whereItLanded[0], marks: [lbl], anchors: &anchors, strokes: pushed + whereItLanded).isEmpty)
    let whereItShows = word("v", x: 110, y: 338)
    XCTAssertEqual(
      BoardMarkHolds.wrote(whereItShows[0], marks: [lbl], anchors: &anchors, strokes: pushed + whereItShows).map(\.id),
      ["l"])
  }

  /// Board 5c232430, 2026-11-23 (iPad log grabber-20261123-163635, Larry's row ac41e16c681f): his label *got all 33
  /// strokes ✓* and check landed with one fold open, then Igor drew a scratch-out zigzag and a line of writing below.
  /// Boxes as the log gives them, ink as plain strokes filling them.
  func testBoard5c232430TheLabelHoldsToTheWritingAboveAndTheZigzagBelowDoesNotFadeIt() {
    let fill = { (id: String, box: CGRect) -> BoardOps.Stroke in
      self.path(id, [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY)])
    }
    // His writing above the label: the header his margin taps folded at y 50 to 75 (its width assumed), and the line
    // he wrote at 202 to 204 s, as logged.
    let writing = [
      fill("hdr", CGRect(x: 70, y: 48, width: 220, height: 28)),
      fill("w96", CGRect(x: 514, y: 190, width: 55, height: 26)),
      fill("w97", CGRect(x: 586, y: 191, width: 33, height: 10)),
      fill("w98", CGRect(x: 632, y: 187, width: 18, height: 11)),
      fill("w99", CGRect(x: 651, y: 187, width: 34, height: 10)),
    ]
    // Where the label showed: Keep and Dismiss framed it at [130.7, 105.1, 180.5, 21.3] in the view, at 1.05.
    let lbl = label("ac41e16c681f#0", CGRect(x: 124.5, y: 100, width: 172, height: 20))
    let anchor = BoardMarkHolds.anchor(lbl, on: .init(strokes: writing))
    XCTAssertEqual(anchor.strokes.first?.name, "hdr", "the line above it, not the writing far to the right")
    // The zigzag at 987.9 s, [54, 239, 653, 120], drawn as a zigzag across that box.
    let zag = zigzag("zz", x: 54...707, y: 239...359)
    XCTAssertEqual(BoardMarkHolds.share(of: zag, on: lbl), 0, "below the label: it shares nothing with it")
  }

  /// Story 1270: the post that takes marks away says which and why, beside the events, however full the turn.
  func testThePostsReportNamesTheMarksItTookAwayHoweverManyEventsWent() throws {
    var events = BoardEvents()
    for i in 0..<(BoardEvents.cap + 50) { events.record(.undo(label: "u", t: Int64(i))) }
    var report = BoardTurnReport(rev: 3, taken: events.take())
    XCTAssertNil(report.wire["marks_dropped"], "none taken away: no field")
    report.marksDropped = [.init(id: "row#0", why: .writtenOver), .init(id: "row#1", why: .inkErased)]
    let wire = try XCTUnwrap(report.wire["marks_dropped"] as? [[String: String]])
    XCTAssertEqual(wire, [["id": "row#0", "why": "written_over"], ["id": "row#1", "why": "ink_erased"]])
  }

  private struct Mark: WhiteboardGhost {
    let id: String
    let who: WhiteboardTurn.Who
    var y: CGFloat = 0
  }

  /// Stories 1181, 1271: a hidden mark takes no tap and no keep; it moves in place; the post drops what it names.
  func testAHiddenMarkIsNeitherTappedNorKeptAndThePostDropsMarks() {
    var turns = WhiteboardGhostTurns<Mark>(on: true, ghostLife: .seconds(30))
    turns.larrysMarks([Mark(id: "r#0", who: .larry), Mark(id: "r#1", who: .larry), Mark(id: "s#0", who: .larry)])
    turns.hiddenMarks = ["r#1"]
    guard case .chose(let chosen) = turns.tapNearest(reach: { ["r#1": 0, "r#0": 1][$0.id] ?? 5 }) else {
      return XCTFail("the tap reaches a shown mark")
    }
    XCTAssertNotEqual(chosen.id, "r#1", "the hidden one takes no tap")
    XCTAssertEqual(turns.keepChosenReply()?.map(\.id), ["r#0"], "its reply's hidden mark stays")
    turns.change("s#0") { $0.y = 40 }
    XCTAssertEqual(turns.ghosts.first { $0.id == "s#0" }?.y, 40)
    XCTAssertEqual(turns.keepAll(.larry).map(\.id), ["s#0"], "Keep all leaves the hidden one")
    XCTAssertEqual(turns.drop(["r#1"]).map(\.id), ["r#1"])
    XCTAssertTrue(turns.ghosts.isEmpty)
    XCTAssertTrue(turns.hiddenMarks.isEmpty)
  }
}
