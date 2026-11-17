import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Stories 923–925: the web board's shape recogniser (cockpit assets/ink/board.mjs `cleanShape`), with its thresholds.
final class BoardShapeSnapTests: XCTestCase {
  /// `corners` walked every 2 points, each point nudged by `wobble` across the way.
  private func walk(_ corners: [CGPoint], wobble: CGFloat = 0) -> [CGPoint] {
    var out: [CGPoint] = []
    for (a, b) in zip(corners, corners.dropFirst()) {
      let length = hypot(b.x - a.x, b.y - a.y)
      let n = max(1, Int(length / 2))
      let (nx, ny) = (-(b.y - a.y) / length, (b.x - a.x) / length)
      for k in 0..<n {
        let t = CGFloat(k) / CGFloat(n)
        let side = (k % 2 == 0 ? 1 : -1) * wobble
        out.append(CGPoint(x: a.x + (b.x - a.x) * t + nx * side, y: a.y + (b.y - a.y) * t + ny * side))
      }
    }
    out.append(corners.last!)
    return out
  }

  private func ellipse(center: CGPoint, rx: CGFloat, ry: CGFloat, wobble: CGFloat = 0, sweep: CGFloat = 2 * .pi)
    -> [CGPoint]
  {
    (0...120).map { k in
      let t = sweep * CGFloat(k) / 120
      let r = 1 + (k % 2 == 0 ? wobble : -wobble)
      return CGPoint(x: center.x + rx * r * cos(t), y: center.y + ry * r * sin(t))
    }
  }

  // MARK: Story 923: a line

  func testANearlyStraightStrokeSnapsToTheLineFromItsStartToItsEnd() throws {
    let raw = walk([CGPoint(x: 100, y: 200), CGPoint(x: 400, y: 230)], wobble: 4)
    let shape = try XCTUnwrap(BoardShapeSnap.clean(raw))
    XCTAssertEqual(shape.kind, .line)
    // Rounded to a tenth of a point, as the web board keeps them.
    let tenth = { (p: CGPoint) in CGPoint(x: (p.x * 10).rounded() / 10, y: (p.y * 10).rounded() / 10) }
    XCTAssertEqual(shape.points.first, raw.first.map(tenth))
    XCTAssertEqual(shape.points.last, raw.last.map(tenth))
    XCTAssertLessThanOrEqual(shape.error, 0.06)
    // About every 4 points, so PencilKit's spline follows it.
    XCTAssertEqual(shape.points.count, 77)
  }

  func testAWobblyOrShortStrokeStaysInk() {
    XCTAssertNil(BoardShapeSnap.clean(walk([CGPoint(x: 100, y: 200), CGPoint(x: 400, y: 200)], wobble: 25)))
    XCTAssertNil(BoardShapeSnap.clean(walk([CGPoint(x: 100, y: 200), CGPoint(x: 125, y: 200)])), "under 30 points")
    XCTAssertNil(BoardShapeSnap.clean([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 200, y: 0)]), "3 points")
  }

  /// Ordinary writing: a zigzag that's neither open straight nor closed.
  func testWritingNeverSnaps() {
    let zigzag = walk([
      CGPoint(x: 100, y: 100), CGPoint(x: 115, y: 140), CGPoint(x: 130, y: 100), CGPoint(x: 145, y: 140),
      CGPoint(x: 160, y: 100),
    ])
    XCTAssertNil(BoardShapeSnap.clean(zigzag))
    XCTAssertNil(BoardShapeSnap.clean(ellipse(center: CGPoint(x: 300, y: 300), rx: 60, ry: 40, sweep: .pi)), "an arc")
  }

  // MARK: Story 924: a rectangle and an ellipse

  func testANearlySquareBoxSnapsToItsBox() throws {
    let raw = walk(
      [
        CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 102), CGPoint(x: 302, y: 200), CGPoint(x: 101, y: 198),
        CGPoint(x: 103, y: 104),
      ], wobble: 2)
    let shape = try XCTUnwrap(BoardShapeSnap.clean(raw))
    XCTAssertEqual(shape.kind, .rect)
    let xs = shape.points.map(\.x)
    let ys = shape.points.map(\.y)
    XCTAssertEqual(shape.points.first, shape.points.last, "closed")
    XCTAssertEqual(xs.min()!, 98, accuracy: 3)
    XCTAssertEqual(xs.max()!, 304, accuracy: 3)
    XCTAssertEqual(ys.min()!, 98, accuracy: 3)
    XCTAssertEqual(ys.max()!, 202, accuracy: 3)
    // Square to the page: every point on one of the box's four sides.
    for p in shape.points {
      let onSide = [p.x - xs.min()!, xs.max()! - p.x, p.y - ys.min()!, ys.max()! - p.y].contains { abs($0) < 0.2 }
      XCTAssertTrue(onSide, "\(p)")
    }
  }

  func testATiltedBoxStaysInk() {
    let c = CGPoint(x: 300, y: 300)
    let corners = [(-100.0, -50.0), (100.0, -50.0), (100.0, 50.0), (-100.0, 50.0), (-100.0, -50.0)].map { x, y in
      let a = CGFloat.pi / 6
      let (x, y) = (CGFloat(x), CGFloat(y))
      return CGPoint(x: c.x + x * cos(a) - y * sin(a), y: c.y + x * sin(a) + y * cos(a))
    }
    XCTAssertNil(BoardShapeSnap.clean(walk(corners)))
  }

  func testANearlyRoundLoopSnapsToTheEllipseInItsBoxFromWhereItStarted() throws {
    // Nearly round: a fat 2:1 one reaches its box's corners and reads as a rectangle, on the web board too.
    let raw = ellipse(center: CGPoint(x: 400, y: 300), rx: 100, ry: 90, wobble: 0.03)
    let shape = try XCTUnwrap(BoardShapeSnap.clean(raw))
    XCTAssertEqual(shape.kind, .ellipse)
    let first = try XCTUnwrap(shape.points.first)
    XCTAssertEqual(first.x, raw[0].x, accuracy: 6)
    XCTAssertEqual(first.y, raw[0].y, accuracy: 6)
    for p in shape.points {
      let r = hypot((p.x - 400) / 103, (p.y - 300) / 92.7)
      XCTAssertEqual(r, 1, accuracy: 0.02, "\(p)")
    }
  }

  func testAnOpenLoopStaysInk() {
    XCTAssertNil(BoardShapeSnap.clean(ellipse(center: CGPoint(x: 400, y: 300), rx: 120, ry: 60, sweep: 1.5 * .pi)))
  }

  // MARK: Story 925: only a stroke held still at its end

  func testOnlyAPencilHeldStillHalfASecondAtTheEndAsks() {
    var hold = BoardShapeSnap.Hold()
    for i in 0...30 { hold.moved(to: CGPoint(x: 100 + CGFloat(i) * 10, y: 100), at: Double(i) * 0.01) }
    var lifted = hold
    XCTAssertFalse(lifted.held(liftedAt: CGPoint(x: 400, y: 100), time: 0.35), "lifted at once")
    // Still, give or take a tremor under 5 points, for half a second.
    for i in 1...50 { hold.moved(to: CGPoint(x: 400 + CGFloat(i % 3), y: 100), at: 0.3 + Double(i) * 0.01) }
    lifted = hold
    XCTAssertTrue(lifted.held(liftedAt: CGPoint(x: 401, y: 101), time: 0.81))
    // A move of 5 points or more starts the half second again.
    hold.moved(to: CGPoint(x: 410, y: 100), at: 0.82)
    XCTAssertFalse(hold.held(liftedAt: CGPoint(x: 410, y: 100), time: 1.1))
  }

  // MARK: Stories 943, 944: the shape shown while the Pencil is held, before the lift

  /// `points` drawn 10 ms apart from `start`; the time after the last.
  private func draw(_ points: [CGPoint], into live: inout BoardShapeSnap.Live, from start: Double = 0) -> Double {
    var time = start
    for point in points {
      live.moved(to: point, at: time)
      time += 0.01
    }
    return time - 0.01
  }

  func testHeldStillTheCleanShapeShowsBeforeTheLift() throws {
    var live = BoardShapeSnap.Live()
    let end = draw(walk([CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 104)], wobble: 2), into: &live)
    XCTAssertNil(live.still(at: end + 0.3), "not yet: under half a second")
    let shape = try XCTUnwrap(live.still(at: end + 0.5))
    XCTAssertEqual(shape.kind, .line)
    XCTAssertEqual(live.shown, shape)
    // A tremble under 5 points keeps it showing.
    XCTAssertFalse(live.moved(to: CGPoint(x: 302, y: 105), at: end + 0.6))
    XCTAssertEqual(live.shown, shape)
  }

  func testMovingOnTakesTheShapeAwayUntilHeldAgain() throws {
    var live = BoardShapeSnap.Live()
    let end = draw(walk([CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100)]), into: &live)
    XCTAssertNotNil(live.still(at: end + 0.5))
    // On into a curl: the raw stroke is back, and the longer stroke is no shape when held again.
    XCTAssertTrue(live.moved(to: CGPoint(x: 320, y: 140), at: end + 0.7))
    XCTAssertNil(live.shown)
    let curl = draw(
      ellipse(center: CGPoint(x: 330, y: 180), rx: 30, ry: 30, sweep: 1.4 * .pi), into: &live, from: end + 0.71)
    XCTAssertNil(live.still(at: curl + 0.2), "too soon after moving")
    XCTAssertNil(live.still(at: curl + 0.6), "a line with a curl is no shape")
  }

  func testWritingHeldStillShowsNothing() {
    var live = BoardShapeSnap.Live()
    let squiggle = (0..<60).map { i in CGPoint(x: 100 + CGFloat(i) * 2, y: 100 + (i % 6 < 3 ? 0 : 14)) }
    let end = draw(squiggle, into: &live)
    XCTAssertNil(live.still(at: end + 1))
  }

  func testNamesForUndo() {
    XCTAssertEqual(BoardShapeSnap.name(.rect), "rectangle")
    XCTAssertEqual(BoardShapeSnap.name(.line), "line")
    XCTAssertEqual(BoardShapeSnap.name(.ellipse), "ellipse")
  }
}
