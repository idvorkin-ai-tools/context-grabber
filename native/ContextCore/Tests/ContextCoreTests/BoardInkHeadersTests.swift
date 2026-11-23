import XCTest

@testable import ContextCore

/// Stories 1030–1036 (#967): an underline under a line, or a # at its start, makes it a header; writing more on a
/// header's line joins its row; a rule ends the sections above it; the mark's Undo takes the header and its Redo
/// brings it back; Larry's picture labels each open header (#1001). No board in the fixtures has an underline or a # drawn on
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

  /// A hand's #, top left at (`x`, `y`), 26 points wide and `h` tall, its upright bars slanted as a hand's are.
  private func hash(_ id: String, x: CGFloat, y: CGFloat, h: CGFloat = 26) -> [BoardOps.Stroke] {
    [
      line("\(id)u1", from: CGPoint(x: x + 10, y: y), to: CGPoint(x: x + 6, y: y + h)),
      line("\(id)u2", from: CGPoint(x: x + 20, y: y), to: CGPoint(x: x + 16, y: y + h)),
      line("\(id)l1", from: CGPoint(x: x, y: y + h * 8 / 26), to: CGPoint(x: x + 26, y: y + h * 7 / 26)),
      line("\(id)l2", from: CGPoint(x: x - 1, y: y + h * 17 / 26), to: CGPoint(x: x + 25, y: y + h * 18 / 26)),
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

  func testARuleTouchingTheLastLineLeavesThatLineInTheSection() throws {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("m", x: 140, y: 178)
    strokes.append(line("rule", from: CGPoint(x: 90, y: 200), to: CGPoint(x: 600, y: 201)))
    strokes += word("c", x: 140, y: 280)
    var o = BoardOutline(strokes: strokes, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    XCTAssertEqual(o.rules(), [place(o, "rule")])
    XCTAssertTrue(o.candidates().isEmpty, "a rule offers no faint H beside the line it touches")
    XCTAssertTrue(o.fold("h"))
    XCTAssertTrue(o.strokes[place(o, "m0")].hidden, "the line the rule touches is the section's")
    XCTAssertFalse(o.strokes[place(o, "rule")].hidden)
    XCTAssertFalse(o.strokes[place(o, "c0")].hidden)
  }

  func testOneUndoOfAHashsLastBarTakesTheHeader() throws {
    var o = BoardOutline(strokes: hash("#", x: 100, y: 100) + word("w", x: 140, y: 101), headers: [])
    XCTAssertEqual(o.inkHeader(newest: place(o, "#l2"), id: "x")?.kind, "hash")
    let undone = BoardOutline(strokes: o.strokes.filter { $0.ids != ["#l2"] }, headers: o.headers)
    XCTAssertTrue(undone.headers.isEmpty, "three bars left are no #")
    XCTAssertEqual(BoardOutline(strokes: o.strokes, headers: o.headers).headers.map(\.id), ["x"], "Redo")
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
    XCTAssertTrue(undone.headerLabels.isEmpty)
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

  /// Stories 1170, 955 (context-grabber-bov): a fold is taken by its header's words or its marker, never by the
  /// underline or # that made the header, through the eraser's own path: the strokes it crossed, then what PaperKit took.
  func testTheEraserAcrossAFoldedHeadersUnderlineLeavesTheFold() throws {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("c", x: 100, y: 180)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    o.inkHeader(newest: place(o, "under"), id: "x")
    XCTAssertTrue(o.fold("x"))
    XCTAssertEqual(try XCTUnwrap(o.header("x")).words, ["h0", "h1", "h2"])
    // Along the underline, a few points under the words: near them, but PaperKit takes only the underline.
    let along = [CGPoint(x: 96, y: 129), CGPoint(x: 172, y: 130)]
    let hits = o.foldHits(along: along, onHeader: true)
    XCTAssertEqual(hits.map(\.header), ["x"], "the path along the underline comes near the words")
    let live = o.liveNames.subtracting(["under"])
    XCTAssertTrue(o.foldsTaken(hits, by: .lifted, live: live).isEmpty, "the underline is no part of its words")
    XCTAssertTrue(o.foldsTaken(hits, by: .rubbed, live: live).isEmpty)
    var after = o
    XCTAssertFalse(after.eraseFolds(o.foldsTaken(hits, by: .lifted, live: live)))
    // The board PaperKit leaves: the header's words, its fold and its folded lines, with the ink below where it was.
    let left = BoardOutline(strokes: o.strokes.filter { $0.ids != ["under"] }, headers: o.headers)
    let header = try XCTUnwrap(left.header("x"))
    XCTAssertTrue(left.isFolded(header))
    XCTAssertEqual(header.words, ["h0", "h1", "h2"])
    XCTAssertEqual(left.markers.map(\.header), ["x"])
    XCTAssertEqual(Set(header.fold?.ids ?? []), ["a0", "a1", "a2"])
    XCTAssertEqual(left.liveNames, o.liveNames.subtracting(["under"]))
    // Across the words it takes the section, and by the marker as ever.
    let across = [CGPoint(x: 100, y: 112), CGPoint(x: 170, y: 112)]
    let words = o.foldsTaken(
      o.foldHits(along: across, onHeader: true), by: .lifted, live: o.liveNames.subtracting(["h0", "h1", "h2"]))
    XCTAssertEqual(words.map(\.header), ["x"])
    XCTAssertTrue(after.eraseFolds(words))
    XCTAssertTrue(after.headers.isEmpty)
    XCTAssertFalse(after.liveNames.contains("a0"), "its folded lines go with it")
    let marker = try XCTUnwrap(o.markers.first).box
    let byMarker = o.foldHits(along: [CGPoint(x: marker.midX, y: marker.midY)], onHeader: true)
    XCTAssertEqual(o.foldsTaken(byMarker, by: .lifted, live: o.liveNames).map(\.header), ["x"])
    XCTAssertEqual(o.foldsTaken(byMarker, by: .rubbed, live: o.liveNames).map(\.header), ["x"])
  }

  func testTheEraserAcrossAFoldedHeadersHashLeavesTheFold() throws {
    var o = BoardOutline(strokes: hash("#", x: 20, y: 100), headers: [])
    XCTAssertNotNil(o.inkHeader(newest: place(o, "#l2"), id: "x"))
    for s in word("w", x: 60, y: 101) {
      o.strokes.append(s)
      o.inkHeader(newest: o.strokes.count - 1, id: "n")
    }
    o.strokes += word("a", x: 100, y: 140)
    XCTAssertTrue(o.fold("x"))
    XCTAssertEqual(try XCTUnwrap(o.header("x")).words, ["w0", "w1", "w2"])
    // Down the #'s upright bar: PaperKit takes that stroke and nothing of the words.
    let hits = o.foldHits(along: [CGPoint(x: 30, y: 98), CGPoint(x: 26, y: 128)], onHeader: true)
    XCTAssertTrue(hits.isEmpty, "the # is no part of its words, and the bar is far from them")
    XCTAssertTrue(o.foldsTaken(hits, by: .lifted, live: o.liveNames.subtracting(["#u1"])).isEmpty)
    let left = BoardOutline(strokes: o.strokes.filter { $0.ids != ["#u1"] }, headers: o.headers)
    XCTAssertTrue(left.isFolded(try XCTUnwrap(left.header("x"))), "the fold stays with a bar of its # gone")
  }

  /// Story 955: the pixel eraser takes a fold by its words only once it has rubbed through every stroke of them (a
  /// rubbed stroke comes back under new names); a rub on one letter leaves the section folded.
  func testThePixelEraserTakesAFoldOnlyWhenItRubsThroughTheWords() {
    var strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140)
    strokes.append(line("under", from: CGPoint(x: 96, y: 128), to: CGPoint(x: 172, y: 129)))
    var o = BoardOutline(strokes: strokes, headers: [])
    o.inkHeader(newest: place(o, "under"), id: "x")
    XCTAssertTrue(o.fold("x"))
    let corner = o.foldHits(along: [CGPoint(x: 102, y: 122)], onHeader: true)
    XCTAssertEqual(corner.map(\.header), ["x"], "the rub crossed the header's first letter")
    let rubbed = o.liveNames.subtracting(["h0"]).union(["h0-rubbed"])
    XCTAssertTrue(o.foldsTaken(corner, by: .rubbed, live: rubbed).isEmpty, "a corner of one letter: the fold stays")
    XCTAssertEqual(o.foldsTaken(corner, by: .lifted, live: rubbed).map(\.header), ["x"], "the eraser took a letter")
    let through = o.liveNames.subtracting(["h0", "h1", "h2"])
    XCTAssertEqual(o.foldsTaken(corner, by: .rubbed, live: through).map(\.header), ["x"])
    XCTAssertTrue(o.foldsTaken(corner, by: .rubbed, live: nil).isEmpty, "no board to read: nothing by its words")
  }

  func testOldHeadersDecodeWithNoMark() throws {
    let old = Data(#"[{"id":"h","ids":["a"]}]"#.utf8)
    let headers = try JSONDecoder().decode([BoardHeader].self, from: old)
    XCTAssertNil(headers.first?.mark)
  }

  func testLarrysPictureLabelsEachOpenHeaderInWords() {
    let strokes = word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("g", x: 100, y: 300)
    var o = BoardOutline(
      strokes: strokes, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"]), BoardHeader(id: "g", ids: ["g0"])])
    XCTAssertEqual(o.headerLabels.map(\.header), ["h", "g"])
    XCTAssertEqual(o.headerLabels.map(\.text), ["▾ header", "▾ header"])
    // The h row ends at 169.5 (the pen pads its box) and its middle is 112: the label starts 14 past it, where a fold's
    // marker would.
    XCTAssertEqual(o.headerLabels.first?.origin, CGPoint(x: 183.5, y: 117))
    o.fold("h")
    XCTAssertEqual(o.headerLabels.map(\.header), ["g"], "a folded one has its own marker")
  }

  /// #1001: a ▾ at the margin's middle sat on the very # it marked, and for a line written further in fell outside
  /// Larry's picture, so he saw plain strokes. The label sits past the line, clear of its ink, and the picture's frame
  /// takes it in.
  func testTheLabelIsClearOfTheInkAndInsideThePicture() throws {
    // A # in the margin, as Igor writes one, then the words; and an underlined line written further in.
    var o = BoardOutline(strokes: hash("#", x: 20, y: 380), headers: [])
    XCTAssertNotNil(o.inkHeader(newest: place(o, "#l2"), id: "x"))
    for s in word("w", x: 60, y: 381) {
      o.strokes.append(s)
      XCTAssertEqual(o.inkHeader(newest: o.strokes.count - 1, id: "n")?.kind, "grew")
    }
    o.strokes += word("u", x: 300, y: 600)
    o.strokes.append(line("under", from: CGPoint(x: 296, y: 628), to: CGPoint(x: 372, y: 629)))
    XCTAssertEqual(o.inkHeader(newest: place(o, "under"), id: "y")?.kind, "underline")
    XCTAssertEqual(o.headerLabels.map(\.header), ["x", "y"])
    for label in o.headerLabels {
      let row = o.strokes.filter { s in o.header(label.header)?.ids.contains(where: s.ids.contains) ?? false }
      XCTAssertFalse(row.isEmpty)
      for s in row { XCTAssertFalse(label.box.intersects(s.bounds), "\(label.header)'s label is on its ink") }
      XCTAssertGreaterThan(label.origin.x, row.map(\.bounds.maxX).max() ?? 0, "past the line")
    }
    // Larry's picture of the page: the ink alone stops 40 points past it, short of the labels; with them it holds both.
    let ink = o.strokes.map(\.bounds)
    let visible = CGRect(x: 0, y: 0, width: 820, height: 1_000)
    let bare = try XCTUnwrap(BoardPages().picture(visible: visible, ink: ink)).rect
    XCTAssertFalse(o.headerLabels.allSatisfy { bare.contains($0.box) }, "the old frame cut a label off")
    let framed = try XCTUnwrap(BoardPages().picture(visible: visible, ink: ink + o.headerLabels.map(\.box))).rect
    for label in o.headerLabels { XCTAssertTrue(framed.contains(label.box), "\(label.header)'s label is cut off") }
  }

  // MARK: - ## and ### (#1034, stories 1065–1068)

  /// Each stroke drawn in turn, read as Igor's Pencil lifts: what the last one made.
  @discardableResult
  private func draw(_ o: inout BoardOutline, _ strokes: [BoardOps.Stroke], id: String) -> BoardOutline.InkHeader? {
    var made: BoardOutline.InkHeader?
    for s in strokes {
      o.strokes.append(s)
      made = o.inkHeader(newest: o.strokes.count - 1, id: id)
    }
    return made
  }

  /// A line `#`, `##` or `###` then a word, at `y`: its #s 34 points apart from `x`, the word after them.
  private func headerLine(
    _ o: inout BoardOutline, _ id: String, level: Int, x: CGFloat = 100, y: CGFloat
  ) {
    for n in 0..<level { draw(&o, hash("\(id)#\(n)", x: x + CGFloat(n) * 34, y: y), id: id) }
    draw(&o, word("\(id)w", x: x + CGFloat(level) * 34 + 10, y: y + 1), id: id)
  }

  func testASecondAndThirdHashBesideAHeadersHashTakeItDeeper() throws {
    var o = BoardOutline(strokes: [], headers: [])
    XCTAssertEqual(draw(&o, hash("a", x: 100, y: 100), id: "x")?.kind, "hash")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 1)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾"], "a level-1 header's mark is the ▾ alone")
    let second = try XCTUnwrap(draw(&o, hash("b", x: 134, y: 101), id: "unused"))
    guard case .deeper(let header, let level, _, let mark) = second else { return XCTFail("\(second)") }
    XCTAssertEqual(header, "x")
    XCTAssertEqual(level, 2)
    XCTAssertEqual(Set(mark), ["bu1", "bu2", "bl1", "bl2"])
    XCTAssertEqual(o.headers.count, 1, "the same header, a level deeper")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 2)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ##"])
    XCTAssertEqual(draw(&o, hash("c", x: 166, y: 99), id: "unused")?.kind, "deeper")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 3)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ###"])
    XCTAssertEqual(o.headerLabels.map(\.text), ["▾ ### header"])
    // A fourth is plain ink on the header's line.
    XCTAssertEqual(draw(&o, hash("d", x: 200, y: 100), id: "unused")?.kind, "grew")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 3)
    // Folded, the mark keeps its #s after the lines.
    o.strokes += word("body", x: 140, y: 150)
    XCTAssertTrue(o.fold("x"))
    XCTAssertEqual(o.headerMarks.map(\.text), ["▸ 1 ###"])
  }

  func testAHashAfterTheHeadersWordsOrBesideAnUnderlineIsPlainInk() throws {
    var o = BoardOutline(strokes: [], headers: [])
    draw(&o, hash("a", x: 100, y: 100), id: "x")
    draw(&o, word("w", x: 140, y: 101), id: "x")
    XCTAssertEqual(draw(&o, hash("b", x: 220, y: 100), id: "unused")?.kind, "grew", "a # after the words")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 1)
    // An underlined header: a # drawn just left of its words is its row's ink.
    var u = BoardOutline(strokes: word("h", x: 140, y: 300), headers: [])
    draw(&u, [line("under", from: CGPoint(x: 136, y: 328), to: CGPoint(x: 212, y: 329))], id: "y")
    XCTAssertEqual(draw(&u, hash("c", x: 106, y: 300), id: "unused")?.kind, "grew")
    XCTAssertEqual(u.level(try XCTUnwrap(u.header("y"))), 1)
  }

  func testOneUndoOfTheLastHashTakesOneLevel() throws {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "x", level: 3, y: 100)
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 3)
    // Undo the third #'s last bar: back to ##, still a header.
    let undone = BoardOutline(strokes: o.strokes.filter { $0.ids != ["x#2l2"] }, headers: o.headers)
    XCTAssertEqual(undone.headers.map(\.id), ["x"])
    XCTAssertEqual(undone.level(undone.headers[0]), 2)
    XCTAssertEqual(undone.headerMarks.map(\.text), ["▾ ##"])
    // Redo: ### again.
    let redone = BoardOutline(strokes: o.strokes, headers: undone.headers)
    XCTAssertEqual(redone.level(redone.headers[0]), 3)
    // The first # gone takes the header, as ever.
    XCTAssertTrue(BoardOutline(strokes: o.strokes.filter { $0.ids != ["x#0l2"] }, headers: o.headers).headers.isEmpty)
  }

  func testRedrawingAnUndoneHashsLastBarTakesTheHeaderDeeperAgain() throws {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "x", level: 2, y: 100)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ##"])
    // Undo the second #'s last bar: ▾ alone.
    o.strokes.removeAll { $0.ids == ["x#1l2"] }
    o = BoardOutline(strokes: o.strokes, headers: o.headers)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾"])
    // Draw it again: the three bars left and the new one are a # again, ▾ ## again.
    let again = line("again", from: CGPoint(x: 133, y: 117), to: CGPoint(x: 159, y: 118))
    XCTAssertEqual(draw(&o, [again], id: "unused")?.kind, "deeper")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 2)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ##"])
  }

  func testRedrawingAnErasedBarOfTheMiddleHashBringsBackEveryHash() throws {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "x", level: 3, y: 100)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ###"])
    // Erase one bar of the second # (the eraser, not Undo): the third # no longer counts, back to ▾.
    o.strokes.removeAll { $0.ids == ["x#1l2"] }
    o = BoardOutline(strokes: o.strokes, headers: o.headers)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾"])
    // Redraw it: all three #s are on the board again, so ▾ ### again, not ▾ ##.
    let again = line("again", from: CGPoint(x: 133, y: 117), to: CGPoint(x: 159, y: 118))
    XCTAssertEqual(draw(&o, [again], id: "unused")?.kind, "deeper")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 3)
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ###"])
    XCTAssertEqual(o.hashes(try XCTUnwrap(o.header("x"))).count, 12, "the third #'s bars are #s again, not row ink")
  }

  func testATightlyWrittenHashHashWhoseBarsOverlapIsStillAHashHash() throws {
    var o = BoardOutline(strokes: [], headers: [])
    draw(&o, hash("a", x: 100, y: 100), id: "x")
    // The second #'s level bars start 5 points inside the first's right end.
    XCTAssertEqual(draw(&o, hash("b", x: 121, y: 101), id: "unused")?.kind, "deeper")
    XCTAssertEqual(o.headerMarks.map(\.text), ["▾ ##"])
  }

  func testAHashUnderATallHashHeaderIsNotItsSecondHash() throws {
    var o = BoardOutline(strokes: [], headers: [])
    XCTAssertEqual(draw(&o, hash("a", x: 100, y: 100, h: 56), id: "x")?.kind, "hash")
    draw(&o, word("w", x: 140, y: 120), id: "x")
    // The next line's #, right under the tall one, its middle still beside it.
    let under = draw(&o, hash("b", x: 100, y: 144), id: "y")
    XCTAssertNotEqual(under?.kind, "deeper")
    XCTAssertEqual(o.level(try XCTUnwrap(o.header("x"))), 1)
    XCTAssertEqual(o.headerMarks.first?.text, "▾", "the header above stays a #")
  }

  /// # Top, a line, ## A and its line, ## B and its line, # Next: all at one indent.
  private func outline() -> BoardOutline {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "top", level: 1, y: 100)
    o.strokes += word("t", x: 100, y: 150)
    headerLine(&o, "a", level: 2, y: 200)
    o.strokes += word("p", x: 100, y: 250)
    headerLine(&o, "b", level: 2, y: 300)
    o.strokes += word("q", x: 100, y: 350)
    headerLine(&o, "next", level: 1, y: 400)
    o.strokes += word("n", x: 100, y: 450)
    return o
  }

  func testASubsectionEndsAtTheNextHeaderOfItsLevelOrShallower() throws {
    var o = outline()
    XCTAssertEqual(o.headers.map(\.id), ["top", "a", "b", "next"])
    XCTAssertEqual(o.headers.map { o.level($0) }, [1, 2, 2, 1])
    XCTAssertTrue(o.fold("a"))
    XCTAssertTrue(o.strokes[place(o, "p0")].hidden, "##a's own line")
    XCTAssertFalse(o.strokes[place(o, "b#0l1")].hidden, "the next ## ends it")
    XCTAssertFalse(o.strokes[place(o, "q0")].hidden)
    XCTAssertTrue(o.fold("b"))
    XCTAssertTrue(o.strokes[place(o, "q0")].hidden)
    XCTAssertFalse(o.strokes[place(o, "nextw0")].hidden, "the # ends the ##")
  }

  func testFoldingTheHashFoldsItsSubsectionsAndUnfoldingKeepsTheirFolds() throws {
    var o = outline()
    XCTAssertTrue(o.fold("b"))
    XCTAssertTrue(o.fold("top"))
    for name in ["t0", "aw0", "p0", "bw0", "q0"] { XCTAssertTrue(o.strokes[place(o, name)].hidden, name) }
    XCTAssertFalse(o.strokes[place(o, "nextw0")].hidden, "the next # is not the section's")
    XCTAssertTrue(o.unfold("top"))
    XCTAssertFalse(o.strokes[place(o, "aw0")].hidden)
    XCTAssertTrue(o.isFolded(try XCTUnwrap(o.header("b"))), "the ## folded inside it stays folded")
    XCTAssertTrue(o.strokes[place(o, "q0")].hidden)
  }

  func testTheOutlinesLevelsFollowTheHashes() {
    let o = outline()
    XCTAssertEqual(o.levels(), ["top": 1, "a": 2, "b": 2, "next": 1])
    var c = o
    c.collapse(to: 1)
    XCTAssertTrue(c.isFolded(c.header("top")!))
    XCTAssertTrue(c.isFolded(c.header("next")!))
    XCTAssertTrue(c.strokes[place(c, "aw0")].hidden, "the ## tucked under the #")
  }

  func testAnIndentedBodyThenAnUnindentedSubheaderStaysInTheSection() throws {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "top", level: 1, y: 100)
    o.strokes += word("t", x: 160, y: 150)
    headerLine(&o, "a", level: 2, y: 200)
    o.strokes += word("p", x: 100, y: 250)
    headerLine(&o, "next", level: 1, y: 300)
    XCTAssertTrue(o.fold("top"))
    for name in ["t0", "aw0", "p0"] { XCTAssertTrue(o.strokes[place(o, name)].hidden, name) }
    XCTAssertFalse(o.strokes[place(o, "nextw0")].hidden)
  }

  func testAShallowerHeaderEndsASubsectionWhateverItsIndent() throws {
    var o = BoardOutline(strokes: [], headers: [])
    headerLine(&o, "a", level: 2, y: 100)
    o.strokes += word("p", x: 140, y: 150)
    headerLine(&o, "next", level: 1, x: 180, y: 200)
    o.strokes += word("n", x: 220, y: 250)
    XCTAssertTrue(o.fold("a"))
    XCTAssertTrue(o.strokes[place(o, "p0")].hidden)
    XCTAssertFalse(o.strokes[place(o, "nextw0")].hidden, "an indented # still ends a ##")
  }

  func testLarrysPictureLabelsADeeperHeaderWithItsLevel() {
    let o = outline()
    XCTAssertEqual(o.headerLabels.map(\.text), ["▾ header", "▾ ## header", "▾ ## header", "▾ header"])
  }

  func testOldHeadersDecodeAtLevelOne() throws {
    let old = Data(#"[{"id":"h","ids":["a"],"mark":["a"]}]"#.utf8)
    let headers = try JSONDecoder().decode([BoardHeader].self, from: old)
    XCTAssertNil(headers.first?.deeper)
    let o = BoardOutline(strokes: [letter("a", x: 100, y: 100)], headers: headers)
    XCTAssertEqual(o.headers.map { o.level($0) }, [1])
  }
}
