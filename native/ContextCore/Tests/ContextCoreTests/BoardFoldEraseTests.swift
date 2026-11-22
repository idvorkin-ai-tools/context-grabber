import XCTest

@testable import ContextCore

/// Stories 902, 903: the eraser across a fold's marker (or across the header's ink) erasing the whole fold, as the web
/// board's `foldHits` and `eraseFold`, and an Undo bringing it back folded.
final class BoardFoldEraseTests: XCTestCase {
  private typealias F = BoardFoldFixture
  private var start: [BoardOps.Stroke] { F.start }
  private var nested: BoardOutline { F.nested }
  private func folded() -> BoardOutline { F.folded() }
  private func header(_ id: String) -> BoardHeader { F.header(id) }
  private func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] { F.word(id, x: x, y: y) }

  private func top(_ o: BoardOutline, _ id: String) -> CGFloat? {
    o.strokes.enumerated().first { !o.erased.contains($0.offset) && $0.element.ids.contains(id) }?.element.bounds.minY
  }

  func testTheEraserAcrossTheMarkerErasesTheWholeFoldAndClosesUp() throws {
    var o = folded()
    let before = o.strokes
    let hits = o.foldHits(along: [CGPoint(x: 200, y: 110), CGPoint(x: 260, y: 112)], onHeader: false)
    XCTAssertEqual(hits.map(\.headers), [["h"]])
    XCTAssertEqual(hits.first?.top, 100)
    XCTAssertTrue(o.eraseFolds(hits))
    XCTAssertTrue(o.headers.isEmpty)
    XCTAssertEqual(o.liveNames, ["c0", "c1", "c2"], "the header and its folded lines go")
    XCTAssertEqual(top(o, "c0"), 100, "the line below closes up to where the header was, whole lines")
    let plan = o.plan(from: before, pages: 1)
    XCTAssertEqual(plan.erase.count, 9)
    XCTAssertEqual(Set(plan.offsets.values.map(\.dy)), [-80])
    XCTAssertTrue(plan.hidden.isEmpty, "nothing erased is shown again first")
  }

  func testAnUndoBringsTheFoldBackStillFolded() throws {
    let was = folded()
    var o = was
    o.eraseFolds(o.foldHits(along: [CGPoint(x: 250, y: 110)], onHeader: false))
    // The board keeps the erased header while its ink is gone, so the Undo's ink finds it again.
    let kept = BoardOutline.keeping(o.headers, previous: was.headers, live: o.liveNames)
    XCTAssertEqual(kept.map(\.id), ["h"])
    let back = BoardOutline(strokes: was.strokes, headers: kept)
    XCTAssertTrue(back.isFolded(try XCTUnwrap(back.header("h"))), "the Undo's ink, folded as it was")
    XCTAssertEqual(back.markers.map(\.text), ["▸ 2 lines folded"])
    // Unmarking a header whose ink is still there drops it.
    var open = BoardOutline(strokes: start, headers: [header("h")])
    open.unmark("h")
    XCTAssertTrue(BoardOutline.keeping(open.headers, previous: [header("h")], live: open.liveNames).isEmpty)
  }

  /// context-grabber-0m2d: an eraser stroke the system calls off takes no fold by its marker, and by the header's ink
  /// only where PaperKit's eraser took that ink anyway.
  func testACalledOffEraserTakesAFoldOnlyWhereTheHeadersInkWent() {
    let o = folded()
    let marker = o.foldHits(along: [CGPoint(x: 200, y: 110), CGPoint(x: 260, y: 112)], onHeader: true)
    XCTAssertEqual(marker.map(\.header), ["h"])
    XCTAssertTrue(o.foldsTakenByCancelledStroke(marker, live: o.liveNames).isEmpty, "called off, the fold stays")
    let ink = o.foldHits(along: [CGPoint(x: 105, y: 112), CGPoint(x: 165, y: 112)], onHeader: true)
    XCTAssertTrue(o.foldsTakenByCancelledStroke(ink, live: o.liveNames).isEmpty, "its ink stayed, so does it")
    let partly = o.liveNames.subtracting(["h0", "h1"])
    XCTAssertTrue(o.foldsTakenByCancelledStroke(ink, live: partly).isEmpty, "some of the header is left to unfold by")
    let gone = o.liveNames.subtracting(["h0", "h1", "h2"])
    XCTAssertEqual(o.foldsTakenByCancelledStroke(ink, live: gone), ink, "its ink went anyway: the section goes with it")
  }

  func testTheHeadersInkTakesTheFoldOnlyWhenAsked() {
    let o = folded()
    let across = [CGPoint(x: 105, y: 112), CGPoint(x: 165, y: 112)]
    XCTAssertTrue(o.foldHits(along: across, onHeader: false).isEmpty, "the header's ink is not its marker")
    XCTAssertEqual(o.foldHits(along: across, onHeader: true).map(\.headers), [["h"]])
    XCTAssertTrue(o.foldHits(along: [CGPoint(x: 400, y: 112)], onHeader: true).isEmpty, "blank paper beside it")
    XCTAssertTrue(o.foldHits(along: [CGPoint(x: 120, y: 190)], onHeader: true).isEmpty, "the line slid up")
    let open = BoardOutline(strokes: start, headers: [header("h")])
    XCTAssertTrue(open.foldHits(along: across, onHeader: true).isEmpty, "an open header is erased as ink")
  }

  func testErasingAFoldTakesTheFoldsFoldedInsideIt() throws {
    var o = nested
    o.fold("i")
    o.fold("o")
    XCTAssertEqual(top(o, "p0"), 180)
    let marker = try XCTUnwrap(o.markers.first)
    let hits = o.foldHits(along: [CGPoint(x: marker.box.midX, y: marker.box.midY)], onHeader: false)
    XCTAssertEqual(hits.first?.headers, ["o", "i"])
    o.eraseFolds(hits)
    XCTAssertEqual(o.headers.map(\.id), ["p"])
    XCTAssertEqual(o.liveNames, ["p0", "p1", "p2", "q0", "q1", "q2"])
    XCTAssertEqual(top(o, "p0"), 100)
    XCTAssertEqual(top(o, "q0"), 140)
  }

  func testTwoFoldsInOneStrokeEachCloseUp() {
    let strokes = start + word("g", x: 100, y: 300) + word("k", x: 140, y: 340) + word("z", x: 100, y: 380)
    var o = BoardOutline(strokes: strokes, headers: [header("h"), header("g")])
    o.fold("g")
    o.fold("h")
    let markers = o.markers
    XCTAssertEqual(markers.count, 2)
    let path = markers.sorted { $0.box.minY < $1.box.minY }.map { CGPoint(x: $0.box.midX, y: $0.box.midY) }
    let hits = o.foldHits(along: path, onHeader: false)
    XCTAssertEqual(Set(hits.flatMap(\.headers)), ["h", "g"])
    o.eraseFolds(hits)
    XCTAssertTrue(o.headers.isEmpty)
    XCTAssertEqual(top(o, "c0"), 100)
    XCTAssertEqual(top(o, "z0"), 180, "the lower fold closed up too, and the upper one's close-up took it along")
  }

  /// Story 903: a fast zigzag over the marker, where there is no ink, is still a scratch-out, and it takes the fold.
  func testAScratchOutOverTheMarkerTakesTheFold() {
    let o = folded()
    // Back and forth along the marker, five sweeps.
    let zigzag = (0..<10).map { CGPoint(x: $0 % 2 == 0 ? 190 : 300, y: 104 + CGFloat($0)) }
    XCTAssertTrue(WhiteboardScratchOut.isZigzag(zigzag, ms: 200))
    XCTAssertFalse(WhiteboardScratchOut.isZigzag(zigzag, ms: 100_000), "slow is writing")
    XCTAssertFalse(WhiteboardScratchOut.isZigzag(Array(zigzag.prefix(3)), ms: 50), "a line is no zigzag")
    XCTAssertEqual(o.foldHits(along: zigzag, reach: 4, onHeader: true).map(\.headers), [["h"]])
    let overHeader = (0..<10).map { CGPoint(x: $0 % 2 == 0 ? 100 : 168, y: 106 + CGFloat($0)) }
    XCTAssertEqual(
      o.foldHits(along: overHeader, reach: 4, onHeader: true).map(\.headers), [["h"]], "or its header line")
  }
}
