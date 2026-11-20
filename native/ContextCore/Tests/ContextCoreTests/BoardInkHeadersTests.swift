import XCTest

@testable import ContextCore

/// Stories 1010–1016 (#967): an underline under a line, or a # at its start, makes it a header; writing more on a
/// header's line joins its row; a rule ends the sections above it; the mark's Undo takes the header and its Redo
/// brings it back; Larry's picture marks each open header. No board in the fixtures has an underline or a # drawn on
/// it, so the strokes here are hand-like: a Pencil's wobble on every line.
final class BoardInkHeadersTests: XCTestCase {
  /// A stroke through `points`, a Pencil's 3-point pen, its box padded by the pen as PencilKit's render bounds are.
  private func stroke(_ id: String, _ points: [CGPoint]) -> BoardOps.Stroke {
    let box = points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }.insetBy(dx: -1.5, dy: -1.5)
    return BoardOps.Stroke(ids: [id], t: nil, bounds: box, points: points, pen: 3)
  }

  /// A letter-sized caret.
  private func letter(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 24) -> BoardOps.Stroke {
    stroke(id, [CGPoint(x: x, y: y + h), CGPoint(x: x + w / 2, y: y), CGPoint(x: x + w, y: y + h)])
  }

  /// A word of `n` letters, 4 points apart.
  private func word(_ id: String, x: CGFloat, y: CGFloat, n: Int = 3) -> [BoardOps.Stroke] {
    (0..<n).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  /// A hand's straight line from `a` to `b`: sampled every 6 points with a point or so of wobble across it.
  private func line(_ id: String, from a: CGPoint, to b: CGPoint) -> BoardOps.Stroke {
    let d = hypot(b.x - a.x, b.y - a.y)
    let n = max(2, Int(d / 6))
    let (nx, ny) = (-(b.y - a.y) / d, (b.x - a.x) / d)
    let wobble: [CGFloat] = [0, 0.8, -0.6, 1.1, -0.9, 0.4, -1.2, 0.7]
    let points = (0...n).map { i -> CGPoint in
      let t = CGFloat(i) / CGFloat(n)
      let w = i == 0 || i == n ? 0 : wobble[i % wobble.count]
      return CGPoint(x: a.x + (b.x - a.x) * t + nx * w, y: a.y + (b.y - a.y) * t + ny * w)
    }
    return stroke(id, points)
  }

  /// A hand's #, top left at (`x`, `y`), 26 points each way, its upright bars slanted as a hand's are.
  private func hash(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    [
      line("\(id)u1", from: CGPoint(x: x + 10, y: y), to: CGPoint(x: x + 6, y: y + 26)),
      line("\(id)u2", from: CGPoint(x: x + 20, y: y), to: CGPoint(x: x + 16, y: y + 26)),
      line("\(id)l1", from: CGPoint(x: x, y: y + 8), to: CGPoint(x: x + 26, y: y + 7)),
      line("\(id)l2", from: CGPoint(x: x - 1, y: y + 17), to: CGPoint(x: x + 25, y: y + 18)),
    ]
  }

  private func place(_ o: BoardOutline, _ id: String) -> Int { o.strokes.firstIndex { $0.ids.contains(id) }! }

  func testAnUnderlineUnderALineMakesItAHeaderThatFolds() throws {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("c", x: 100, y: 180)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    let made = try XCTUnwrap(o.inkHeader(newest: place(o, "under"), id: "x"))
    XCTAssertEqual(made.kind, "underline")
    let header = try XCTUnwrap(o.header("x"))
    XCTAssertEqual(Set(header.ids), ["h0", "h1", "h2", "under"], "the underline is the header's own")
    XCTAssertEqual(header.mark, ["under"])
    XCTAssertTrue(o.fold("x"))
    XCTAssertTrue(o.strokes[place(o, "a0")].hidden, "its indented line folds")
    XCTAssertFalse(o.strokes[place(o, "under")].hidden, "the underline stays with its header")
  }

  func testAnUnderlineUnderNothingOrRunningFarPastMakesNoHeader() {
    var strokes = word("h", x: 100, y: 100)
    strokes.append(line("far", from: CGPoint(x: 100, y: 300), to: CGPoint(x: 200, y: 300)))
    strokes.append(line("long", from: CGPoint(x: 96, y: 129), to: CGPoint(x: 500, y: 130)))
    var o = BoardOutline(strokes: strokes, headers: [])
    XCTAssertNil(o.inkHeader(newest: place(o, "far"), id: "x"), "under blank paper")
    XCTAssertNil(o.inkHeader(newest: place(o, "long"), id: "y"), "a rule, not an underline")
    XCTAssertTrue(o.headers.isEmpty)
  }

  func testOldUnderlinesAreNotReadAndALettersStrokeIsNoMark() {
    var strokes = word("h", x: 100, y: 100)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    XCTAssertNil(
      o.inkHeader(newest: place(o, "h2"), id: "x"), "only the newest stroke is read, and a letter is no mark")
    XCTAssertEqual(o.candidates().map(\.why), [.underline], "the old underline is still only offered")
  }

  func testAHashAtALinesStartMakesItAHeaderAndTheWordsAfterJoinIt() throws {
    let strokes = hash("#", x: 100, y: 100) + word("a", x: 140, y: 140)
    var o = BoardOutline(strokes: strokes, headers: [])
    // The # finished by its last bar, whichever it is.
    XCTAssertNil(BoardOutline(strokes: Array(strokes.prefix(3)), headers: []).hash(finishedBy: 2), "three bars")
    let made = try XCTUnwrap(o.inkHeader(newest: place(o, "#l2"), id: "x"))
    XCTAssertEqual(made.kind, "hash")
    XCTAssertEqual(Set(o.header("x")?.mark ?? []), ["#u1", "#u2", "#l1", "#l2"])
    // Then the words after it.
    for s in word("w", x: 140, y: 101) {
      o.strokes.append(s)
      XCTAssertEqual(o.inkHeader(newest: o.strokes.count - 1, id: "n")?.kind, "grew")
    }
    XCTAssertTrue(Set(o.header("x")?.ids ?? []).isSuperset(of: ["w0", "w1", "w2"]))
    XCTAssertEqual(o.headers.count, 1, "one header, not two")
    let marker = try XCTUnwrap(
      { () -> BoardOutline.Marker? in
        var f = o
        f.fold("x")
        return f.markers.first
      }())
    XCTAssertGreaterThan(marker.origin.x, 140 + 3 * 24, "the fold's words land past the header's words")
  }

  func testAHashThatIsNotAtTheLinesStartOrNotAHashIsNoHeader() {
    var o = BoardOutline(strokes: word("w", x: 100, y: 100) + hash("#", x: 200, y: 100), headers: [])
    XCTAssertNil(o.inkHeader(newest: place(o, "#l2"), id: "x"), "ink left of it on its line")
    // Four bars that don't cross: two equals signs' worth.
    let bars = [
      line("l1", from: CGPoint(x: 100, y: 300), to: CGPoint(x: 126, y: 300)),
      line("l2", from: CGPoint(x: 100, y: 310), to: CGPoint(x: 126, y: 310)),
      line("u1", from: CGPoint(x: 140, y: 290), to: CGPoint(x: 140, y: 316)),
      line("u2", from: CGPoint(x: 150, y: 290), to: CGPoint(x: 150, y: 316)),
    ]
    var p = BoardOutline(strokes: bars, headers: [])
    XCTAssertNil(p.inkHeader(newest: 3, id: "y"))
  }

  func testARuleEndsTheSectionsAboveIt() throws {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("b", x: 140, y: 180)
    strokes.append(line("rule", from: CGPoint(x: 90, y: 240), to: CGPoint(x: 600, y: 242)))
    strokes += word("c", x: 140, y: 280)
    var o = BoardOutline(strokes: strokes, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    XCTAssertEqual(o.rules(), [place(o, "rule")])
    XCTAssertTrue(o.fold("h"))
    XCTAssertTrue(o.strokes[place(o, "b0")].hidden)
    XCTAssertFalse(o.strokes[place(o, "c0")].hidden, "below the rule is not the section's")
    XCTAssertFalse(o.strokes[place(o, "rule")].hidden)
    XCTAssertEqual(o.headers.first?.fold?.lines, 2)
    XCTAssertLessThan(o.strokes[place(o, "rule")].bounds.minY, 240, "the rule slides up under the header")
    // Without the rule the indented line below it is the section's.
    var without = BoardOutline(
      strokes: strokes.filter { $0.ids != ["rule"] },
      headers: o.headers.map {
        BoardHeader(id: $0.id, ids: $0.ids)
      })
    XCTAssertTrue(without.fold("h"))
    XCTAssertTrue(without.strokes[place(without, "c0")].hidden)
  }

  func testTheMarksUndoTakesTheHeaderAndItsRedoBringsItBack() throws {
    var strokes = word("h", x: 100, y: 100)
    let under = line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129))
    strokes.append(under)
    var o = BoardOutline(strokes: strokes, headers: [])
    o.inkHeader(newest: place(o, "under"), id: "x")
    let saved = o.headers
    // Undo: the underline is gone.
    let undone = BoardOutline(strokes: Array(strokes.dropLast()), headers: saved)
    XCTAssertTrue(undone.headers.isEmpty, "no header while its underline is away")
    XCTAssertTrue(undone.openHeaderMarks.isEmpty)
    let kept = BoardOutline.keeping(undone.headers, previous: saved, live: undone.liveNames)
    XCTAssertEqual(kept.map(\.id), ["x"], "kept, so the Redo brings it back")
    XCTAssertEqual(BoardOutline(strokes: strokes, headers: kept).headers.map(\.id), ["x"])
    // A margin tap made the row a header meanwhile: the old one is not brought back beside it.
    var tapped = undone
    XCTAssertTrue(tapped.markHeader(at: 112, id: "tap"))
    XCTAssertEqual(
      BoardOutline.keeping(tapped.headers, previous: saved, live: tapped.liveNames).map(\.id), ["tap"])
  }

  func testNotAHeaderKeepsTheUnderlineAndNothingBringsItBack() {
    var strokes = word("h", x: 100, y: 100)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    o.inkHeader(newest: place(o, "under"), id: "x")
    let before = o.headers
    o.unmark("x")
    XCTAssertTrue(BoardOutline.keeping(o.headers, previous: before, live: o.liveNames).isEmpty)
    o.strokes += word("z", x: 100, y: 300)
    XCTAssertNil(o.inkHeader(newest: o.strokes.count - 1, id: "y"))
    XCTAssertTrue(o.headers.isEmpty)
  }

  func testAFoldedHeaderKeepsItsFoldWhenItsUnderlineGoes() {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    o.inkHeader(newest: place(o, "under"), id: "x")
    XCTAssertTrue(o.fold("x"))
    let gone = BoardOutline(strokes: o.strokes.filter { $0.ids != ["under"] }, headers: o.headers)
    XCTAssertEqual(gone.headers.map(\.id), ["x"])
    XCTAssertTrue(gone.isFolded(gone.headers[0]))
  }

  func testOldHeadersDecodeWithNoMark() throws {
    let old = Data(#"[{"id":"h","ids":["a"]}]"#.utf8)
    let headers = try JSONDecoder().decode([BoardHeader].self, from: old)
    XCTAssertNil(headers.first?.mark)
  }

  func testLarrysPictureMarksEachOpenHeader() {
    let strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("g", x: 100, y: 300)
    var o = BoardOutline(
      strokes: strokes, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"]), BoardHeader(id: "g", ids: ["g0"])])
    XCTAssertEqual(o.openHeaderMarks.map(\.header), ["h", "g"])
    XCTAssertEqual(o.openHeaderMarks.first?.y ?? 0, 112, accuracy: 2)
    o.fold("h")
    XCTAssertEqual(o.openHeaderMarks.map(\.header), ["g"], "a folded one has its own marker")
  }
}
