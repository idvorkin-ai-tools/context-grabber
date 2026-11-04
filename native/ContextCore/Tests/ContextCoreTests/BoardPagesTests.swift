//  Stories 535–539: the column of pages.

import ContextCore
import CoreGraphics
import XCTest

final class BoardPagesTests: XCTestCase {
  private let pages = BoardPages()

  private func page(_ y: CGFloat) -> Int { pages.page(at: CGPoint(x: 100, y: y)) }

  // MARK: Story 535: a blank page below the last ink

  func testANewBoardIsOneBlankPage() {
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: nil), 1)
    XCTAssertEqual(BoardPages.placing(ink: nil).pages, 1)
    XCTAssertEqual(BoardPages.placing(ink: .null).pages, 1)
  }

  func testInkOnAPageNeedsThatPageAndABlankOne() {
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: 10), 2)
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: 1_060), 2, "ink stopping at the page's end leaves page 2 blank")
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: 1_060.5), 3)
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: 5 * 1_060), 6)
  }

  func testThereIsAlwaysExactlyOneBlankPageBelowTheInk() {
    for inkMaxY in stride(from: CGFloat(1), to: 12_000, by: 137) {
      let needed = pages.pagesNeeded(inkMaxY: inkMaxY)
      XCTAssertGreaterThanOrEqual(pages.frame(ofPage: needed).minY, inkMaxY, "the last page is blank")
      XCTAssertLessThan(pages.frame(ofPage: needed - 1).minY, inkMaxY, "the one above it has ink")
    }
  }

  func testInkAboveTheColumnIsStillInk() {
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: -5), 2)
  }

  func testNumbersThatCantBeRealNeverCrash() {
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: .infinity), 1)
    XCTAssertEqual(pages.pagesNeeded(inkMaxY: .nan), 1)
    XCTAssertGreaterThan(pages.pagesNeeded(inkMaxY: 1e300), 1)
    XCTAssertEqual(page(.nan), 1)
    XCTAssertEqual(page(.infinity), 1)
    XCTAssertGreaterThan(page(1e300), 1)
    XCTAssertEqual(BoardPages.placing(ink: .infinite).pages, 1)
  }

  // MARK: Story 536: which page a mark is on

  func testAPointIsOnThePageThatHoldsIt() {
    XCTAssertEqual(page(0), 1)
    XCTAssertEqual(page(1_059.9), 1)
    XCTAssertEqual(page(1_060), 2, "on the line is the page below")
    XCTAssertEqual(page(2_500), 3)
    XCTAssertEqual(page(-500), 1, "above the column is page 1")
  }

  func testAPointPastTheSideIsStillOnThatPage() {
    XCTAssertEqual(pages.page(at: CGPoint(x: 50_000, y: 1_100)), 2)
  }

  func testThePageMostlyOnScreenIsTheOneAtItsMiddle() {
    let screen = CGRect(x: 0, y: 900, width: 820, height: 1_180)
    XCTAssertEqual(pages.page(at: CGPoint(x: screen.midX, y: screen.midY)), 2)
    let higher = CGRect(x: 0, y: 300, width: 820, height: 1_180)
    XCTAssertEqual(pages.page(at: CGPoint(x: higher.midX, y: higher.midY)), 1)
  }

  // MARK: Story 537: a page's edges and the line where it ends

  func testPagesStackTouchingAndArePaperShaped() {
    XCTAssertEqual(pages.frame(ofPage: 1), CGRect(x: 0, y: 0, width: 820, height: 1_060))
    XCTAssertEqual(pages.frame(ofPage: 3), CGRect(x: 0, y: 2_120, width: 820, height: 1_060))
    XCTAssertEqual(pages.frame(ofPage: 2).minY, pages.frame(ofPage: 1).maxY)
    XCTAssertEqual(pages.bounds(pages: 3), CGRect(x: 0, y: 0, width: 820, height: 3_180))
  }

  func testAWideBoardsPagesAreWideAndNoTaller() {
    let wide = BoardPages(width: 2_000)
    XCTAssertEqual(wide.frame(ofPage: 2), CGRect(x: 0, y: 1_060, width: 2_000, height: 1_060))
  }

  func testAPageEndLineMarksTheBottomOfEachPage() {
    XCTAssertEqual(pages.pageEnds(pages: 3), [1_060, 2_120, 3_180])
    XCTAssertEqual(pages.pageEnds(pages: 0), [])
  }

  // MARK: Story 538: ruled lines

  func testEveryPageIsRuledTheSameAndNoLineLandsOnItsEnd() {
    let lines = pages.ruledLines(visible: 0...3_180, pages: 3, zoom: 1)
    let onPage = { (n: Int) -> [CGFloat] in
      let top = self.pages.frame(ofPage: n).minY
      return lines.filter { $0 >= top && $0 < top + 1_060 }.map { $0 - top }
    }
    XCTAssertEqual(onPage(1).first, 40, "one line down from the top")
    XCTAssertEqual(onPage(1).last, 1_040)
    XCTAssertEqual(onPage(1).count, 26)
    XCTAssertEqual(onPage(2), onPage(1))
    XCTAssertEqual(onPage(3), onPage(1))
    XCTAssertTrue(Set(lines).isDisjoint(with: pages.pageEnds(pages: 3)))
    XCTAssertFalse(lines.contains(0))
  }

  func testRuledLinesStayInViewAndOnThePages() {
    XCTAssertEqual(pages.ruledLines(visible: 95...205, pages: 3, zoom: 1), [120, 160, 200])
    XCTAssertEqual(pages.ruledLines(visible: 1_030...1_110, pages: 3, zoom: 1), [1_040, 1_100], "across a page's end")
    XCTAssertEqual(pages.ruledLines(visible: 1_100...1_200, pages: 1, zoom: 1), [], "past the last page")
    XCTAssertEqual(pages.ruledLines(visible: -300 ... -100, pages: 1, zoom: 1), [], "above the first")
    XCTAssertEqual(pages.ruledLines(visible: 0...100, pages: 0, zoom: 1), [])
    XCTAssertEqual(pages.ruledLines(visible: 0...100, pages: 1, zoom: 0), [])
  }

  func testPinchingOutOnlyRemovesLinesAndNeverCrowdsThem() {
    var previous = Set(pages.ruledLines(visible: 0...1_060, pages: 2, zoom: 1))
    XCTAssertFalse(previous.isEmpty)
    for zoom: CGFloat in [0.5, 0.25, 0.1, 0.05] {
      let lines = pages.ruledLines(visible: 0...1_060, pages: 2, zoom: zoom)
      XCTAssertFalse(lines.isEmpty, "zoom \(zoom)")
      XCTAssertTrue(Set(lines).isSubset(of: previous), "zoom \(zoom)")
      XCTAssertLessThan(lines.count, previous.count, "zoom \(zoom)")
      for (a, b) in zip(lines, lines.dropFirst()) {
        XCTAssertGreaterThanOrEqual((b - a) * zoom, WhiteboardFrame.gridMinGap, "zoom \(zoom)")
      }
      previous = Set(lines)
    }
    XCTAssertEqual(
      pages.ruledLines(visible: 0...300, pages: 1, zoom: 3), [40, 80, 120, 160, 200, 240, 280], "pinching in adds none")
  }

  // MARK: Story 539: a stroke never scales

  private let oldInk = CGRect(x: 10_100, y: 9_900, width: 300, height: 500)

  func testMovingOntoPagesIsATranslationAndNothingElse() {
    let boards = [
      oldInk, CGRect(x: 9_000, y: 9_000, width: 2_000, height: 40),
      CGRect(x: 10_000, y: 2_000, width: 500, height: 15_000),
    ]
    for ink in boards {
      let transform = BoardPages.placing(ink: ink).transform
      XCTAssertEqual(transform.a, 1)
      XCTAssertEqual(transform.b, 0)
      XCTAssertEqual(transform.c, 0)
      XCTAssertEqual(transform.d, 1)
      XCTAssertEqual(ink.applying(transform).size, ink.size)
    }
  }

  func testStrokesKeepTheirWidthAndPlacesRelativeToEachOther() {
    let transform = BoardPages.placing(ink: oldInk).transform
    XCTAssertEqual(WhiteboardStrokes.width(sizes: [3, 5], transform: transform), 4, "the pen's width")
    let movedA = CGPoint(x: 10_100, y: 9_900).applying(transform)
    let movedB = CGPoint(x: 10_400, y: 10_400).applying(transform)
    XCTAssertEqual(movedB.x - movedA.x, 300)
    XCTAssertEqual(movedB.y - movedA.y, 500)
  }

  func testInkLandsInsideTheFirstPagesCorner() {
    let placed = BoardPages.placing(ink: oldInk)
    let moved = oldInk.applying(placed.transform)
    XCTAssertEqual(moved.origin, CGPoint(x: 40, y: 40))
    XCTAssertEqual(placed.board, BoardPages())
    XCTAssertEqual(placed.pages, 2)
    XCTAssertTrue(placed.board.bounds(pages: placed.pages).contains(moved))
  }

  func testInkWiderThanAPageWidensTheBoardInsteadOfShrinking() {
    let wide = CGRect(x: 9_000, y: 9_000, width: 2_000, height: 40)
    let placed = BoardPages.placing(ink: wide)
    XCTAssertEqual(placed.board.width, 2_080)
    XCTAssertEqual(placed.board.frame(ofPage: 1).height, 1_060)
    XCTAssertTrue(placed.board.bounds(pages: placed.pages).contains(wide.applying(placed.transform)))
  }

  func testTallInkTakesThePagesItNeedsPlusABlankOne() {
    XCTAssertEqual(
      BoardPages.placing(ink: CGRect(x: 0, y: 0, width: 10, height: 1_020)).pages, 2, "ends at page 1's end")
    XCTAssertEqual(BoardPages.placing(ink: CGRect(x: 0, y: 0, width: 10, height: 1_021)).pages, 3)
    let tall = BoardPages.placing(ink: CGRect(x: 0, y: 0, width: 10, height: 15_000))
    XCTAssertEqual(tall.pages, 16)
    XCTAssertGreaterThanOrEqual(tall.board.frame(ofPage: tall.pages).minY, 15_040)
  }

  func testNoInkDoesNotMove() {
    let placed = BoardPages.placing(ink: nil)
    XCTAssertEqual(placed.shift, .zero)
    XCTAssertEqual(placed.board, BoardPages())
  }

  // MARK: Stories 591, 596, 603, 608: a real board's pages and place

  func testPagesAddedAsInkReachesThemAndNeverTakenBack() {
    XCTAssertEqual(pages.pages(after: 1, inkMaxY: nil, redoWaiting: false), 1)
    XCTAssertEqual(pages.pages(after: 1, inkMaxY: 100, redoWaiting: false), 2)
    XCTAssertEqual(pages.pages(after: 2, inkMaxY: 1_100, redoWaiting: false), 3)
    XCTAssertEqual(pages.pages(after: 5, inkMaxY: 100, redoWaiting: false), 5, "erasing leaves the room")
    XCTAssertEqual(pages.pages(after: 5, inkMaxY: nil, redoWaiting: false), 5, "erasing it all too")
  }

  func testNoPageIsAddedWhileRedoHasStepsWaiting() {
    XCTAssertEqual(pages.pages(after: 1, inkMaxY: 100, redoWaiting: true), 1)
    XCTAssertEqual(pages.pages(after: 2, inkMaxY: 5_000, redoWaiting: true), 2)
  }

  func testAColumnsHeightSaysItsPages() {
    XCTAssertEqual(pages.pages(in: pages.bounds(pages: 1)), 1)
    XCTAssertEqual(pages.pages(in: pages.bounds(pages: 7)), 7)
    XCTAssertEqual(pages.pages(in: .zero), 1)
    XCTAssertEqual(pages.pages(in: .null), 1, "a null rectangle can't crash it")
    XCTAssertGreaterThan(pages.pages(in: .infinite), 0, "nor an endless one")
  }

  func testThePageNumberReadsAtTheCorner() {
    XCTAssertEqual(pages.pageText(visibleMidY: 500, pages: 1), "Page 1 of 1")
    XCTAssertEqual(pages.pageText(visibleMidY: 1_060, pages: 3), "Page 2 of 3")
    XCTAssertEqual(pages.pageText(visibleMidY: 9_000, pages: 3), "Page 3 of 3", "a phone's view runs past the column")
    XCTAssertEqual(pages.pageText(visibleMidY: -50, pages: 3), "Page 1 of 3")
  }

  func testABoardOpensWhereItWasLeft() {
    XCTAssertEqual(pages.openingY(remembered: nil, pages: 3), 0, "new to this device: the first page")
    XCTAssertEqual(pages.openingY(remembered: 1_500, pages: 3), 1_500)
    XCTAssertEqual(pages.openingY(remembered: 9_000, pages: 3), 2_120, "ink erased since: the last page's top")
    XCTAssertEqual(pages.openingY(remembered: -40, pages: 3), 0)
    XCTAssertEqual(pages.openingY(remembered: .nan, pages: 3), 0)
  }

  // MARK: A mark past the page's side (the spec's "Ghosts and Larry on paper")

  func testAMarkPastTheColumnIsTold() {
    let inside = [[CGPoint(x: 0, y: 0), CGPoint(x: 820, y: 1_060)]]
    XCTAssertFalse(pages.reachesPastSide(inside))
    XCTAssertTrue(pages.reachesPastSide([[CGPoint(x: 821, y: 10)]]), "past the right")
    XCTAssertTrue(pages.reachesPastSide([[CGPoint(x: -1, y: 10)]]), "past the left")
    XCTAssertTrue(pages.reachesPastSide([[CGPoint(x: 10, y: -1)]]), "above the first page")
    XCTAssertFalse(pages.reachesPastSide([[CGPoint(x: 10, y: 5_000)]]), "far down isn't past a side")
    XCTAssertTrue(BoardPages(width: 1_000).reachesPastSide([[CGPoint(x: 1_001, y: 0)]]))
    XCTAssertFalse(BoardPages(width: 1_000).reachesPastSide([[CGPoint(x: 1_000, y: 0)]]), "a wider board holds more")
    XCTAssertFalse(pages.reachesPastSide([]))
  }

  // MARK: Story 641: copied strokes

  func testCopiedInkLandsInTheMiddleOfTheView() {
    let view = CGRect(x: 0, y: 2_000, width: 820, height: 1_000)
    let ink = CGRect(x: 10, y: 20, width: 100, height: 50)
    let shift = pages.pasteShift(ink: ink, visible: view)
    let moved = ink.offsetBy(dx: shift.dx, dy: shift.dy)
    XCTAssertEqual(moved.midX, view.midX, accuracy: 0.01)
    XCTAssertEqual(moved.midY, view.midY, accuracy: 0.01)
  }

  func testCopiedInkStaysOnTheColumn() {
    let right = CGRect(x: 780, y: 0, width: 40, height: 100)
    let ink = CGRect(x: 0, y: 0, width: 200, height: 300)
    var shift = pages.pasteShift(ink: ink, visible: right)
    var moved = ink.offsetBy(dx: shift.dx, dy: shift.dy)
    XCTAssertEqual(moved.maxX, 820, accuracy: 0.01, "against the right side")
    XCTAssertEqual(moved.minY, 0, accuracy: 0.01, "and not above the first page")
    let wide = CGRect(x: 50, y: 0, width: 2_000, height: 10)
    shift = pages.pasteShift(ink: wide, visible: right)
    moved = wide.offsetBy(dx: shift.dx, dy: shift.dy)
    XCTAssertEqual(moved.minX, 0, accuracy: 0.01, "too wide starts at the left")
  }

  func testTheFitZoomIsWhatFitsTheColumn() {
    XCTAssertEqual(BoardPages.fitZoom(visibleWidth: 820, atZoom: 1, column: 820), 1)
    XCTAssertEqual(BoardPages.fitZoom(visibleWidth: 402, atZoom: 1, column: 820), 402.0 / 820)
    // A person at zoom 2 sees 410 points: 820 at 1, so a page wide at 1. Nothing assumes what zoom 1 means.
    XCTAssertEqual(BoardPages.fitZoom(visibleWidth: 410, atZoom: 2, column: 820), 1)
    XCTAssertEqual(BoardPages.fitZoom(visibleWidth: 1_180, atZoom: 1, column: 820) ?? 0, 1_180 / 820, accuracy: 0.001)
    XCTAssertNil(BoardPages.fitZoom(visibleWidth: 0, atZoom: 1, column: 820), "no width seen yet")
  }
}
