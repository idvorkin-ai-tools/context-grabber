//  Story 1143 (bead context-grabber-eg7v): what a move of ink says against what the touch held and whose ink it was.

import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class PaperProbeMoveAuditTests: XCTestCase {
  private func move(_ id: String, _ dx: CGFloat, _ dy: CGFloat, resized: Bool = false) -> PaperProbe.InkMove {
    PaperProbe.InkMove(id: id, dx: dx, dy: dy, resized: resized)
  }

  /// The iPad's case: Larry's text and two of Igor's strokes moved with nothing selected, each its own way.
  func testANothingHeldMoveOfTheirsAndMineSaysSo() {
    let moved = [move("l1", 21, -3), move("l2", 30, -3), move("i1", 12, 5, resized: true)]
    let frames = [
      "l1": CGRect(x: 56, y: 1683, width: 10, height: 20), "l2": CGRect(x: 100, y: 1690, width: 10, height: 10),
      "i1": CGRect(x: 155, y: 1715, width: 26, height: 27),
    ]
    let fields = PaperProbe.moveAudit(moved, held: [], theirs: ["l1", "l2"], frames: frames)
    XCTAssertEqual(fields["moved_held"] as? Int, 0)
    XCTAssertEqual(fields["moved_not_held"] as? Int, 3)
    XCTAssertEqual(fields["moved_theirs"] as? Int, 2)
    XCTAssertEqual(fields["moved_mine"] as? Int, 1)
    XCTAssertEqual(fields["moved_box"] as? [Double], [56, 1683, 125, 59])
    XCTAssertEqual(fields["dx_min"] as? Double, 12)
    XCTAssertEqual(fields["dx_max"] as? Double, 30)
    XCTAssertEqual(fields["dy_min"] as? Double, -3)
    XCTAssertEqual(fields["dy_max"] as? Double, 5)
    XCTAssertEqual(fields["moved_alike"] as? Bool, false)
    XCTAssertEqual(fields["resized"] as? Int, 1)
  }

  /// A lasso dragged: everything held, everything alike.
  func testADraggedSelectionIsHeldAndAlike() {
    let moved = [move("a", 40, 10), move("b", 40.4, 10.2)]
    let fields = PaperProbe.moveAudit(moved, held: ["a", "b", "c"], theirs: [], frames: [:])
    XCTAssertEqual(fields["moved_held"] as? Int, 2)
    XCTAssertEqual(fields["moved_not_held"] as? Int, 0)
    XCTAssertEqual(fields["moved_mine"] as? Int, 2)
    XCTAssertEqual(fields["moved_alike"] as? Bool, true)
    XCTAssertEqual(fields["moved_box"] as? [Double], [])
  }

  func testNothingMovedSaysNothing() {
    XCTAssertTrue(PaperProbe.moveAudit([], held: ["a"], theirs: ["a"], frames: [:]).isEmpty)
  }
}
