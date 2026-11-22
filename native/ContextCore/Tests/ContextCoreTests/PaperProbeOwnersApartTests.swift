import ContextCore
import XCTest

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Story 1145: the system's own move never carries Igor's ink and Larry's together.
final class PaperProbeOwnersApartTests: XCTestCase {
  private func moves(_ ids: [String], dx: CGFloat = 21, dy: CGFloat = -3) -> [PaperProbe.InkMove] {
    ids.map { PaperProbe.InkMove(id: $0, dx: dx, dy: dy, resized: false) }
  }

  private let larrys = (1...52).map { "L\($0)" }

  /// The iPad, 2026-11-22: the reflow moved Larry's 52-stroke text and two of Igor's, nothing selected.
  func testTheReflowOnLarrysTextLeavesIgorsTwoStrokesBehind() {
    let out = PaperProbe.ownersApart(moves(larrys + ["I1", "I2"]), held: [], theirs: Set(larrys))
    XCTAssertEqual(out.verdict, .split)
    XCTAssertEqual(out.putBack, ["I1", "I2"])
    XCTAssertFalse(out.putBackTheirs)
  }

  func testIgorsLineWithAFewOfLarrysStrokesCaughtLeavesLarrysBehind() {
    let mine = (1...20).map { "I\($0)" }
    let out = PaperProbe.ownersApart(moves(mine + ["L1", "L2", "L3"]), held: [], theirs: Set(larrys))
    XCTAssertEqual(out.verdict, .split)
    XCTAssertEqual(out.putBack, ["L1", "L2", "L3"])
    XCTAssertTrue(out.putBackTheirs)
  }

  func testOnATieIgorsInkKeepsTheMove() {
    let out = PaperProbe.ownersApart(moves(["I1", "I2", "L1", "L2"]), held: [], theirs: Set(larrys))
    XCTAssertEqual(out.putBack, ["L1", "L2"])
    XCTAssertTrue(out.putBackTheirs)
  }

  func testOneOwnersMoveIsLeftAsItIs() {
    XCTAssertEqual(PaperProbe.ownersApart(moves(larrys), held: [], theirs: Set(larrys)).verdict, .oneOwner)
    XCTAssertEqual(PaperProbe.ownersApart(moves(["I1", "I2"]), held: [], theirs: Set(larrys)).verdict, .oneOwner)
  }

  func testWhatIgorSelectedMovesWhole() {
    let ids = ["L1", "L2", "I1"]
    let out = PaperProbe.ownersApart(moves(ids), held: Set(ids + ["I9"]), theirs: Set(larrys))
    XCTAssertEqual(out.verdict, .selected)
    XCTAssertTrue(out.putBack.isEmpty)
  }

  func testAMoveBeyondTheSelectionIsStillSplit() {
    let out = PaperProbe.ownersApart(moves(["L1", "L2", "I1"]), held: ["L1", "L2"], theirs: Set(larrys))
    XCTAssertEqual(out.verdict, .split)
    XCTAssertEqual(out.putBack, ["I1"])
  }

  func testWithNothingKnownAsLarrysTheMoveIsLeftAndSaysWhy() {
    XCTAssertEqual(PaperProbe.ownersApart(moves(["I1", "I2"]), held: [], theirs: []).verdict, .theirsUnknown)
  }

  func testNothingMoved() {
    XCTAssertEqual(PaperProbe.ownersApart([], held: [], theirs: Set(larrys)).verdict, .nothingMoved)
  }
}
