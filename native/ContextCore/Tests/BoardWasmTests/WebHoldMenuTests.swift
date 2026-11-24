import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Stories 1309, 1310 (spec 2026-11-22-board-rules-on-the-web-design.md, Interface 21): the web board's hold menu, as
/// `bw_hold_menu` and `bw_hold_menu_on` answer it, offers To text after Select, and held on the selection takes all of
/// it, as the iPad's menu does.
final class WebHoldMenuTests: XCTestCase {
  private func letter(_ id: String, x: CGFloat, y: CGFloat) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + 24), CGPoint(x: x + 10, y: y), CGPoint(x: x + 20, y: y + 24)]
    return BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: 20, height: 24), points: points, pen: 3)
  }

  private var twoLines: BoardOutline {
    BoardOutline(
      strokes: (0..<3).map { letter("a\($0)", x: 100 + CGFloat($0) * 24, y: 100) }
        + (0..<3).map { letter("b\($0)", x: 100 + CGFloat($0) * 24, y: 200) }, headers: [])
  }

  func testAWordOffersToTextAfterSelect() {
    let menu = WebHit.holdMenu(twoLines, x: 110, y: 112, inMargin: false, slop: 22)
    XCTAssertEqual(menu["choices"] as? [String], ["select", "to-text", "delete", "make-room", "paste", "make-header"])
    XCTAssertEqual(menu["on"] as? String, "ink")
  }

  func testHeldOnTheSelectionItTakesAllOfIt() {
    let lasso = ["a0", "a1", "a2", "b0", "b1", "b2"]
    let on = WebHit.holdMenu(twoLines, x: 110, y: 212, inMargin: false, slop: 22, selected: lasso)
    XCTAssertEqual(on["choices"] as? [String], ["to-text", "delete", "make-room", "paste", "make-header"])
    XCTAssertEqual((on["names"] as? [String])?.sorted(), lasso)
    XCTAssertEqual(on["on"] as? String, "selection")
    let none = WebHit.holdMenu(twoLines, x: 110, y: 212, inMargin: false, slop: 22, selected: [])
    XCTAssertEqual(none["on"] as? String, "ink", "nothing selected: the word, as bw_hold_menu")
  }
}
