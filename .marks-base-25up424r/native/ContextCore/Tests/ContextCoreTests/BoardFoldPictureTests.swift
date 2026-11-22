import XCTest

@testable import ContextCore

/// #1013, stories 900 and 1046: Larry's picture draws a folded section whole and shaded, and his marks on it land on
/// the folded board where he drew them.
final class BoardFoldPictureTests: XCTestCase {
  private typealias F = BoardFoldFixture

  func testNothingFoldedPicturesTheBoardAsItIs() {
    XCTAssertNil(BoardOutline(strokes: F.start, headers: [F.header("h")]).foldPicture())
    XCTAssertNil(BoardOutline(strokes: F.start, headers: []).foldPicture())
  }

  func testAFoldedSectionShowsWholeUnderItsHeaderWithTheRestAfterIt() throws {
    let folded = F.folded()
    let picture = try XCTUnwrap(folded.foldPicture())
    // The header's row ends at 124; folded, the last line sat at 180, a line below where it was.
    XCTAssertEqual(picture.map.steps, [BoardFoldMap.Step(header: "h", top: 124, slide: 40)])
    // The two folded lines (strokes 3–8) show again, where they were; the line after goes back down to 220.
    XCTAssertEqual(picture.shown, Set(3...8))
    XCTAssertEqual(Set(picture.offsets.keys), Set(9...11))
    XCTAssertTrue(picture.offsets.values.allSatisfy { $0 == CGVector(dx: 0, dy: 40) })
    XCTAssertTrue(picture.open.strokes.allSatisfy { !$0.hidden })
    XCTAssertEqual(picture.open.strokes[9].bounds.minY, 220)
    // The shading runs from the header's row to the bottom of its lines.
    XCTAssertEqual(picture.bands, [.init(header: "h", top: 124, bottom: 204)])
    XCTAssertEqual(picture.foldedMarks.map(\.header), ["h"])
    XCTAssertEqual(picture.foldedMarks.first?.y, 112)
    XCTAssertTrue(picture.openLabels.isEmpty)
  }

  func testAMarkBelowTheSectionLandsUnderTheSameInkOnTheFoldedBoard() throws {
    let map = try XCTUnwrap(F.folded().foldPicture()).map
    // The line after the section: 220 in the picture, 180 on the folded board.
    XCTAssertEqual(map.toBoard(220), 180)
    XCTAssertEqual(map.toBoard(CGPoint(x: 130, y: 250)), CGPoint(x: 130, y: 210))
    XCTAssertEqual(map.toPicture(180), 220)
    // On the folded lines: just under the header.
    XCTAssertEqual(map.toBoard(150), 124)
    XCTAssertEqual(map.toBoard(163.9), 124)
    // Above the section nothing moves.
    XCTAssertEqual(map.toBoard(110), 110)
    XCTAssertEqual(map.toPicture(110), 110)
    // The screen's rect grows by the section opened inside it.
    XCTAssertEqual(
      map.toPicture(CGRect(x: 0, y: 60, width: 500, height: 200)), CGRect(x: 0, y: 60, width: 500, height: 240))
  }

  func testAFoldInsideAFoldOpensWholeInsideTheOuterShading() throws {
    var o = F.nested
    o.fold("i")
    o.fold("o")
    let picture = try XCTUnwrap(o.foldPicture())
    XCTAssertEqual(picture.map.steps.map(\.header), ["o", "i"], "the outer opens first, then the one inside it")
    XCTAssertTrue(picture.open.strokes.allSatisfy { !$0.hidden })
    let outer = try XCTUnwrap(picture.bands.first { $0.header == "o" })
    let inner = try XCTUnwrap(picture.bands.first { $0.header == "i" })
    XCTAssertLessThanOrEqual(outer.top, inner.top)
    XCTAssertGreaterThanOrEqual(outer.bottom, inner.bottom)
    XCTAssertEqual(Set(picture.foldedMarks.map(\.header)), ["o", "i"])
    XCTAssertEqual(picture.openLabels.map(\.header), ["p"], "the header left open keeps its label")
    // #1001: past its line in the opened picture, not in the margin on its ink.
    let p = try XCTUnwrap(picture.open.header("p").flatMap { picture.open.box($0) })
    XCTAssertGreaterThan(picture.openLabels.first?.box.minX ?? 0, p.maxX)
    XCTAssertEqual(picture.openLabels.first?.origin.y ?? 0, p.midY + 5, accuracy: 0.001)
    // The board opened is the board Unfold all makes.
    var all = o
    all.unfoldAll()
    XCTAssertEqual(picture.open.strokes.map(\.bounds), all.strokes.map(\.bounds))
  }

  /// context-grabber-e91y: an open sub-header inside a folded section is labelled in the opened picture, so the
  /// picture's frame takes its label in, as it does every open header's: written as the rightmost line, its "▾ header"
  /// was cut off.
  func testTheFrameTakesInAnOpenSubheadersLabelInsideAFold() throws {
    let wide = F.word("i", x: 140, y: 140) + [F.letter("i3", x: 212, y: 140), F.letter("i4", x: 236, y: 140)]
    let strokes =
      F.word("o", x: 100, y: 100) + wide + F.word("d", x: 180, y: 180) + F.word("e", x: 140, y: 220)
      + F.word("p", x: 100, y: 260)
    let inner = BoardHeader(id: "i", ids: (0..<5).map { "i\($0)" })
    var o = BoardOutline(strokes: strokes, headers: [F.header("o"), inner, F.header("p")])
    XCTAssertTrue(o.fold("o"))
    XCTAssertEqual(o.headerLabels.map(\.header), ["p"], "the sub-header doesn't show on the folded board")
    let picture = try XCTUnwrap(o.foldPicture())
    let label = try XCTUnwrap(picture.openLabels.first { $0.header == "i" }, "the opened picture labels it")
    let visible = CGRect(x: 0, y: 0, width: 820, height: 1_000)
    let ink = o.strokes.map(\.bounds)
    let bare = try XCTUnwrap(BoardPages().picture(visible: visible, ink: ink + o.headerLabels.map(\.box))).rect
    XCTAssertFalse(picture.map.toPicture(bare).contains(label.box), "the old frame cut the label off")
    XCTAssertEqual(o.pictureLabelBoxes.count, 2, "the sub-header's label and p's")
    let framed = try XCTUnwrap(BoardPages().picture(visible: visible, ink: ink + o.pictureLabelBoxes)).rect
    for label in picture.openLabels {
      XCTAssertTrue(picture.map.toPicture(framed).contains(label.box), "\(label.header)'s label is cut off")
    }
    // With no fold showing, the boxes are the board's own labels.
    o.unfoldAll()
    XCTAssertEqual(o.pictureLabelBoxes, o.headerLabels.map(\.box))
  }

  func testEveryInkThatShowsMapsBothWays() throws {
    var o = F.nested
    o.fold("i")
    o.fold("o")
    o.fold("p")
    let picture = try XCTUnwrap(o.foldPicture())
    for (i, stroke) in o.strokes.enumerated() where !stroke.hidden {
      let there = picture.open.strokes[i].bounds.minY
      XCTAssertEqual(picture.map.toPicture(stroke.bounds.minY), there, "stroke \(i) into the picture")
      XCTAssertEqual(picture.map.toBoard(there), stroke.bounds.minY, "stroke \(i) back onto the board")
    }
  }

  func testTheMapGoesWithThePictureAndBackAsJSON() throws {
    let map = BoardFoldMap(steps: [.init(header: "h", top: 124, slide: 40)])
    XCTAssertEqual(map.wire.first?["y"] as? Double, 124)
    XCTAssertEqual(map.wire.first?["h"] as? Double, 40)
    XCTAssertEqual(try JSONDecoder().decode(BoardFoldMap.self, from: JSONEncoder().encode(map)), map)
  }

  func testATallerPictureStaysWithinThePixelBudget() {
    XCTAssertEqual(WhiteboardFrame.scale(for: CGRect(x: 0, y: 0, width: 100, height: 100), atMost: 2), 2)
    let tall = CGRect(x: 0, y: 0, width: 1000, height: 6000)
    let scale = WhiteboardFrame.scale(for: tall, atMost: 2)
    XCTAssertLessThanOrEqual(tall.width * tall.height * scale * scale, 2048 * 2048 + 1)
  }
}

/// Story 1046: a reply's picture's map, remembered by its id across launches.
final class WhiteboardPictureFoldsTests: XCTestCase {
  func testAPicturesMapIsKeptByItsIdAndAPictureWithNoFoldsIsNot() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "WhiteboardPictureFoldsTests"))
    defaults.removePersistentDomain(forName: "WhiteboardPictureFoldsTests")
    let folds = WhiteboardPictureFolds(defaults: defaults)
    let map = BoardFoldMap(steps: [.init(header: "h", top: 124, slide: 40)])
    folds.record("p1", map: map, board: "b")
    folds.record("p2", map: BoardFoldMap(steps: []), board: "b")
    folds.record("p3", map: nil, board: "b")
    XCTAssertEqual(WhiteboardPictureFolds(defaults: defaults).map("p1", board: "b"), map)
    XCTAssertNil(folds.map("p2", board: "b"))
    XCTAssertNil(folds.map("p1", board: "other"))
    XCTAssertNil(folds.map(nil, board: "b"))
  }

  func testTheFoldsGoWithThePictureBesideItsFrame() {
    var picture = WhiteboardPicture(board: "b", title: "t", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
    XCTAssertNil(picture.wire["picture_folds"])
    picture.folds = BoardFoldMap(steps: [.init(header: "h", top: 124, slide: 40)])
    XCTAssertEqual((picture.wire["picture_folds"] as? [[String: Any]])?.count, 1)
  }
}
