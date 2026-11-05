//  Stories 433, 522 (#636): on paper, Larry's picture shows the pages on screen, and nothing on screen is nothing to send.

import ContextCore
import CoreGraphics
import XCTest

final class BoardPicturePagesTests: XCTestCase {
  private let pages = BoardPages()
  private let height = BoardPages.pageHeight

  /// A line of writing across page `page`, `down` points below its top.
  private func writing(page: Int, down: CGFloat = 300) -> CGRect {
    CGRect(x: 100, y: CGFloat(page - 1) * height + down, width: 500, height: 60)
  }

  /// An iPad's screen at a page's width: about 1,000 board points tall, its top `top` points down the column.
  private func iPad(top: CGFloat) -> CGRect { CGRect(x: 0, y: top, width: 820, height: 1_000) }

  /// A phone's: the page fits its width, so the screen is about 1,500 board points tall.
  private func phone(top: CGFloat) -> CGRect { CGRect(x: 0, y: top, width: 820, height: 1_530) }

  // MARK: Story 433: Larry reads the pages I'm looking at

  func testTheMiddlePageOnScreenIsThePicture() throws {
    let ink = [writing(page: 1), writing(page: 2), writing(page: 3)]
    XCTAssertEqual(pages.pagesShown(visible: iPad(top: height), ink: ink), [2])
    let picture = try XCTUnwrap(pages.picture(visible: iPad(top: height), ink: ink))
    XCTAssertEqual(picture.rect, writing(page: 2).insetBy(dx: -40, dy: -40), "page 2's writing, with the margin")
    XCTAssertEqual(picture.scale, 2, "drawn at the screen's own size, not shrunk with the whole column")
  }

  func testScrollingToAnotherPageShowsThatOne() throws {
    let ink = [writing(page: 1), writing(page: 2), writing(page: 3)]
    let third = try XCTUnwrap(pages.picture(visible: iPad(top: 2 * height), ink: ink))
    XCTAssertEqual(third.rect.minY, writing(page: 3).minY - 40)
    let first = try XCTUnwrap(pages.picture(visible: iPad(top: 0), ink: ink))
    XCTAssertEqual(first.rect.minY, writing(page: 1).minY - 40)
  }

  func testTwoPagesHalfOnScreenAreBothInThePicture() throws {
    let ink = [writing(page: 1, down: 900), writing(page: 2, down: 100)]
    let between = iPad(top: height / 2)
    XCTAssertEqual(pages.pagesShown(visible: between, ink: ink), [1, 2])
    let picture = try XCTUnwrap(pages.picture(visible: between, ink: ink))
    XCTAssertEqual(picture.rect.minY, writing(page: 1, down: 900).minY - 40)
    XCTAssertEqual(picture.rect.maxY, writing(page: 2, down: 100).maxY + 40)
  }

  func testAPageShowsAllItsInkNotOnlyThePartOnScreen() throws {
    let low = writing(page: 2, down: 950)
    let ink = [writing(page: 2, down: 50), low]
    // Page 2's top on screen, its bottom just below.
    let picture = try XCTUnwrap(pages.picture(visible: iPad(top: height - 20), ink: ink))
    XCTAssertEqual(picture.rect.maxY, low.maxY + 40)
  }

  func testASliverOfAnotherPageDoesNotBringItIn() {
    // Page 1's last 60 points are on screen, ink and all, but most of the screen is page 2.
    let ink = [writing(page: 1, down: 1_000), writing(page: 2)]
    XCTAssertEqual(pages.pagesShown(visible: iPad(top: height - 60), ink: ink), [2])
  }

  func testTheMarginStaysOnThePagesShown() throws {
    // Writing hard against page 2's top: the margin doesn't reach up into page 1's ink.
    let ink = [writing(page: 1, down: 990), CGRect(x: 100, y: height + 5, width: 500, height: 60)]
    let picture = try XCTUnwrap(pages.picture(visible: iPad(top: height), ink: ink))
    XCTAssertEqual(picture.rect.minY, height, "cut at page 2's top")
  }

  func testAStrokeAcrossAPageEndIsCutAtIt() throws {
    let across = CGRect(x: 100, y: height - 200, width: 500, height: 400)
    let picture = try XCTUnwrap(pages.picture(visible: iPad(top: height), ink: [across]))
    XCTAssertEqual(picture.rect.minY, height, "only page 2's part of it")
    XCTAssertEqual(picture.rect.maxY, across.maxY + 40)
  }

  func testATallPageOfNotesStaysLegible() throws {
    let page = CGRect(x: 40, y: height + 40, width: 740, height: 980)
    let picture = try XCTUnwrap(pages.picture(visible: iPad(top: height), ink: [page]))
    XCTAssertEqual(picture.rect, CGRect(x: 0, y: height, width: 820, height: height))
    XCTAssertEqual(picture.scale, 2, "a whole page is within the budget at the screen's 2x")
  }

  // MARK: Story 522: nothing on screen, nothing to send

  func testABlankPageOnScreenHasNothingToSend() {
    let ink = [writing(page: 1)]
    XCTAssertEqual(pages.pagesShown(visible: iPad(top: height), ink: ink), [])
    XCTAssertNil(pages.picture(visible: iPad(top: height), ink: ink))
  }

  func testAPhonesBlankPageWithTheEmptyEndOfPageOneAboveIt() {
    // Two pages on a phone: it can't scroll page 2 to the top, so page 1's bottom shows above it, with no ink.
    let ink = [writing(page: 1, down: 200)]
    let bottom = phone(top: 2 * height - 1_530)
    XCTAssertNil(pages.picture(visible: bottom, ink: ink))
    let withInkShowing = [writing(page: 1, down: 800)]
    XCTAssertEqual(pages.pagesShown(visible: bottom, ink: withInkShowing), [1], "his ink on screen is sent")
  }

  func testAnEmptyPageOnScreenIsLeftOut() throws {
    let ink = [writing(page: 2, down: 900)]
    let between = iPad(top: height * 1.5)
    XCTAssertEqual(pages.pagesShown(visible: between, ink: ink), [2], "page 3 is on screen but blank")
    let picture = try XCTUnwrap(pages.picture(visible: between, ink: ink))
    XCTAssertEqual(picture.rect.maxY, writing(page: 2, down: 900).maxY + 40)
  }

  func testNoInkOrNoScreenIsNothing() {
    XCTAssertNil(pages.picture(visible: iPad(top: 0), ink: []))
    XCTAssertNil(pages.picture(visible: .null, ink: [writing(page: 1)]))
    XCTAssertNil(pages.picture(visible: .zero, ink: [writing(page: 1)]))
  }
}
