import CoreGraphics
import XCTest

@testable import ContextCore

final class WhiteboardPasteTests: XCTestCase {
  private let view = CGRect(x: 9000, y: 9000, width: 1000, height: 800)

  private func bounds(_ lines: [[CGPoint]]) -> CGRect {
    let points = lines.joined()
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    return CGRect(
      x: xs.min() ?? 0, y: ys.min() ?? 0, width: (xs.max() ?? 0) - (xs.min() ?? 0),
      height: (ys.max() ?? 0) - (ys.min() ?? 0))
  }

  func testShortTextIsCentredInTheView() {
    let layout = WhiteboardPaste.layout("Hello", visible: view, height: 24)
    XCTAssertFalse(layout.lines.isEmpty)
    XCTAssertFalse(layout.cut)
    let box = bounds(layout.lines)
    XCTAssertEqual(box.midX, view.midX, accuracy: 0.5)
    XCTAssertEqual(box.midY, view.midY, accuracy: 0.5)
  }

  func testEachLineKeepsItsRowEvenAfterABlankOne() {
    let one = WhiteboardPaste.layout("HI", visible: view, height: 24)
    let two = WhiteboardPaste.layout("HI\nHI", visible: view, height: 24)
    let gap = WhiteboardPaste.layout("HI\n\nHI", visible: view, height: 24)
    XCTAssertEqual(two.lines.count, 2 * one.lines.count)
    XCTAssertEqual(bounds(two.lines).width, bounds(one.lines).width, accuracy: 0.5)
    XCTAssertEqual(bounds(two.lines).height, bounds(one.lines).height + 30, accuracy: 0.5)
    XCTAssertEqual(bounds(gap.lines).height, bounds(one.lines).height + 60, accuracy: 0.5)
  }

  func testWindowsLineEndsAndSurroundingSpaceAreNotExtraRows() {
    let plain = WhiteboardPaste.layout("HI\nHI", visible: view, height: 24)
    let messy = WhiteboardPaste.layout("\n  HI\r\nHI \n\n", visible: view, height: 24)
    XCTAssertEqual(bounds(messy.lines).height, bounds(plain.lines).height, accuracy: 0.5)
    XCTAssertEqual(messy.lines.count, plain.lines.count)
    XCTAssertFalse(messy.cut)
  }

  func testALongLineWrapsInsideTheView() {
    let long = String(repeating: "word ", count: 60)
    let layout = WhiteboardPaste.layout(long, visible: view, height: 24)
    let box = bounds(layout.lines)
    XCTAssertLessThanOrEqual(box.width, view.width * 0.8)
    XCTAssertGreaterThan(box.height, 24 * 2)
    XCTAssertGreaterThan(box.minX, view.minX)
    XCTAssertLessThan(box.maxX, view.maxX)
    XCTAssertFalse(layout.cut)
  }

  func testOverTheCharacterCapIsCutAndSaysHowMuch() {
    let layout = WhiteboardPaste.layout(String(repeating: "x", count: 1234), visible: view, height: 24)
    XCTAssertEqual(layout.kept, WhiteboardPaste.maxCharacters)
    XCTAssertEqual(layout.total, 1234)
    XCTAssertTrue(layout.cut)
  }

  func testOverTheLineCapIsCutAndATallBlockStartsAtTheTopOfTheView() {
    let text = (0..<100).map { _ in "a" }.joined(separator: "\n")
    let layout = WhiteboardPaste.layout(text, visible: view, height: 24)
    XCTAssertEqual(layout.total, 199)
    XCTAssertEqual(layout.kept, 2 * WhiteboardPaste.maxLines)
    XCTAssertTrue(layout.cut)
    let box = bounds(layout.lines)
    let letter = bounds(WhiteboardPaste.layout("a", visible: view, height: 24).lines)
    XCTAssertEqual(box.height, 30 * CGFloat(WhiteboardPaste.maxLines - 1) + letter.height, accuracy: 1)
    XCTAssertEqual(box.minY, view.minY + 24, accuracy: 0.5)
  }

  func testNothingWithAnOutlineMeansNoInk() {
    XCTAssertTrue(WhiteboardPaste.layout("   \n ", visible: view, height: 24).lines.isEmpty)
    XCTAssertTrue(WhiteboardPaste.layout("🎉🎉", visible: view, height: 24).lines.isEmpty)
    XCTAssertFalse(WhiteboardPaste.layout("🎉 yes", visible: view, height: 24).lines.isEmpty)
  }

  func testStaysOnTheBoardAtItsCorner() {
    let corner = CGRect(x: 19_900, y: 19_900, width: 100, height: 100)
    let box = bounds(WhiteboardPaste.layout("Hello there", visible: corner, height: 24).lines)
    XCTAssertLessThanOrEqual(box.maxX, WhiteboardFrame.side)
    XCTAssertLessThanOrEqual(box.maxY, WhiteboardFrame.side)
  }
}
