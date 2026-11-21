import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// #1040: a batch of Larry's handed to the canvas, and what the board reports of it, through a canvas that records
/// what it was handed and answers as it is told. What Larry's next turn hears is `lastResult`.
final class BoardCanvasOutcomeTests: XCTestCase {
  private func batch(rev: Int = 0, key: String = "m1", label: String = "room") -> BoardOps.Batch {
    BoardOps.batch(
      ["board": "b1", "base_rev": rev, "label": label, "list": [["op": "translate", "below_y": 300, "dy": 120]]],
      key: key, source: "web")!
  }

  /// A plan that moves ink, as PaperKit is asked to.
  private var moving: BoardOps.Plan {
    BoardOps.plan(
      [.translateBelow(y: 300, dy: 120)],
      strokes: [BoardOps.Stroke(ids: ["s1"], t: nil, bounds: CGRect(x: 10, y: 400, width: 100, height: 20))],
      pages: 2)
  }

  /// The canvas: what it was handed, and what it answers, in turn.
  private final class RecordingCanvas {
    var answers: [BoardCanvasOutcome]
    var handed: [String] = []
    init(_ answers: BoardCanvasOutcome...) { self.answers = answers }
    func apply(_ batch: BoardOps.Batch) -> BoardCanvasOutcome {
      handed.append(batch.key)
      return answers.isEmpty ? .unavailable : answers.removeFirst()
    }
  }

  /// One delivery as the board makes it: checked, then applied on the canvas and reported if let through.
  private func deliver(
    _ batch: BoardOps.Batch, to applier: inout BoardOpApplier, canvas: RecordingCanvas, ready: Bool = true
  ) -> BoardApplyReport? {
    guard case .apply(let taken) = applier.receive(batch, board: "b1", editable: true, ready: ready) else { return nil }
    return applier.report(taken, canvas.apply(taken))
  }

  func testAnAppliedBatchIsReportedOnceAndATwiceDeliveredOneNeverReachesTheCanvasAgain() {
    var applier = BoardOpApplier()
    let canvas = RecordingCanvas(.applied(moving))
    XCTAssertTrue(moving.changesBoard)
    guard case .apply(let taken) = applier.receive(batch(), board: "b1", editable: true, ready: true) else {
      return XCTFail("let through")
    }
    let outcome = canvas.apply(taken)
    applier.changed()  // The canvas's own change, as PaperKit's markup reports it before the board does.
    XCTAssertEqual(applier.report(taken, outcome), .applied(BoardOps.Result(label: "room", ok: true, rev: 1)))
    XCTAssertEqual(applier.lastResult?.ok, true)
    XCTAssertNil(deliver(batch(), to: &applier, canvas: canvas), "the same batch again is ignored")
    XCTAssertEqual(canvas.handed, ["m1"], "the canvas was handed it once")
    // His change counts as touching everything: a batch from the look before it can't apply over it.
    XCTAssertEqual(
      applier.receive(batch(rev: 0, key: "m2"), board: "b1", editable: true, ready: true),
      .refused(BoardOps.Result(label: "room", ok: false, rev: 1, reason: BoardOps.Reason.stale)))
  }

  func testACanvasThatIsntThereRefusesAsNotAppliedAndChangesNothingElse() {
    var applier = BoardOpApplier()
    let canvas = RecordingCanvas(.unavailable)
    XCTAssertEqual(
      deliver(batch(), to: &applier, canvas: canvas),
      .refused(BoardOps.Result(label: "room", ok: false, rev: 0, reason: "not_applied"), canvas: "unavailable"))
    XCTAssertEqual(applier.lastResult?.reason, "not_applied", "the wire's reason, as before")
    XCTAssertEqual(applier.rev, 0)
    XCTAssertTrue(applier.touches.isEmpty, "nothing on the board changed, so nothing is marked touched")
    XCTAssertNil(deliver(batch(), to: &applier, canvas: canvas), "and it isn't retried")
  }

  func testAnEditTheCanvasRefusedIsReportedWithWhy() {
    var applier = BoardOpApplier()
    let canvas = RecordingCanvas(.failed(reason: "paper_ops_failed"))
    XCTAssertEqual(
      deliver(batch(), to: &applier, canvas: canvas),
      .refused(
        BoardOps.Result(label: "room", ok: false, rev: 0, reason: "not_applied"), canvas: "failed:paper_ops_failed"))
    XCTAssertTrue(applier.touches.isEmpty)
    // The next batch on the same look still applies: the failed one left nothing in its way.
    let next = RecordingCanvas(.applied(moving))
    XCTAssertEqual(
      deliver(batch(key: "m2", label: "next"), to: &applier, canvas: next),
      .applied(BoardOps.Result(label: "next", ok: true, rev: 0)))
  }

  func testALateOrRepeatedCompletionChangesNothing() {
    var applier = BoardOpApplier()
    guard case .apply(let first) = applier.receive(batch(), board: "b1", editable: true, ready: true) else {
      return XCTFail("let through")
    }
    XCTAssertEqual(applier.report(first, .applied(moving)), .applied(BoardOps.Result(label: "room", ok: true, rev: 0)))
    XCTAssertEqual(applier.report(first, .failed(reason: "again")), .late, "its completion came twice")
    XCTAssertEqual(applier.lastResult?.ok, true, "the first word stands")

    guard case .apply(let second) = applier.receive(batch(key: "m2"), board: "b1", editable: true, ready: true) else {
      return XCTFail("let through")
    }
    applier.closed()
    XCTAssertEqual(applier.report(second, .applied(moving)), .late, "the board closed before the canvas answered")
    XCTAssertEqual(applier.lastResult?.label, "room")
    XCTAssertTrue(applier.touches.allSatisfy { $0.rev == 0 })
  }

  func testABatchHeldForThePencilReportsOnceReleased() {
    var applier = BoardOpApplier()
    XCTAssertEqual(applier.receive(batch(), board: "b1", editable: true, ready: false), .held(replaced: nil))
    XCTAssertEqual(applier.report(batch(), .applied(moving)), .late, "not let through yet")
    let released = applier.release(ready: true)
    XCTAssertNotNil(released)
    XCTAssertEqual(
      applier.report(released!, .applied(moving)), .applied(BoardOps.Result(label: "room", ok: true, rev: 0)))
  }

  func testAPlanThatLeavesTheInkAloneIsAppliedWithoutTouchingIt() {
    var applier = BoardOpApplier()
    let still = BoardOps.Plan(pagesBefore: 2, pagesAfter: 2)
    XCTAssertFalse(still.changesBoard)
    _ = deliver(batch(), to: &applier, canvas: RecordingCanvas(.applied(still)))
    XCTAssertEqual(applier.lastResult?.ok, true)
    XCTAssertTrue(applier.touches.isEmpty, "text and notes alone leave Igor's ink free to be named")
  }
}
