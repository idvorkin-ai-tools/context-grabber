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
}
