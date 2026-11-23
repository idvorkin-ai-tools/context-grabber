import XCTest

@testable import ContextCore

/// The oracle is story 998, *It moves as one*: a group moves as one, whoever moves it (bead context-grabber-1xdh).
final class PaperProbeGroupCarryTests: XCTestCase {
  private func moves(_ ids: [String], dx: CGFloat = 286, dy: CGFloat = -250) -> [PaperProbe.InkMove] {
    ids.map { PaperProbe.InkMove(id: $0, dx: dx, dy: dy, resized: false) }
  }

  private func group(_ name: String, _ ids: [String]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: ids.map { ($0, name) })
  }

  /// The iPad, 2026-11-22: the reflow's drag took 102 of the kept reply's 120 strokes; the other 18 come along.
  func testTheReflowTakesPartOfAGroupAndTheRestComesAlong() throws {
    let reply = (0..<120).map { "r\($0)" }
    var groupOf = group("reply-e77c4f60b064", reply)
    groupOf.merge(group("reply-b587616ebb23", (0..<69).map { "b\($0)" })) { $1 }
    let carry = try XCTUnwrap(PaperProbe.groupCarry(moves(Array(reply[18...])), groupOf: groupOf))
    XCTAssertEqual(carry.carry, Set(reply[..<18]))
    XCTAssertEqual(carry.groups, ["reply-e77c4f60b064"])
    XCTAssertEqual(carry.dx, 286)
    XCTAssertEqual(carry.dy, -250)
  }

  func testAWholeGroupMovedCarriesNothing() {
    let groupOf = group("g", ["a", "b"])
    XCTAssertNil(PaperProbe.groupCarry(moves(["a", "b"]), groupOf: groupOf))
  }

  func testInkInNoGroupCarriesNothing() {
    XCTAssertNil(PaperProbe.groupCarry(moves(["mine1", "mine2"]), groupOf: group("g", ["a", "b"])))
  }

  func testNothingMovedCarriesNothing() {
    XCTAssertNil(PaperProbe.groupCarry([], groupOf: group("g", ["a", "b"])))
  }

  /// His own ink caught in the drag stays as it moved; only the group's left-behind strokes are added.
  func testOnlyTheGroupsLeftBehindStrokesAreCarried() throws {
    var groupOf = group("g", ["a", "b", "c"])
    groupOf.merge(group("h", ["x", "y"])) { $1 }
    let carry = try XCTUnwrap(PaperProbe.groupCarry(moves(["a", "mine", "x", "y"]), groupOf: groupOf))
    XCTAssertEqual(carry.carry, ["b", "c"])
    XCTAssertEqual(carry.groups, ["g"])
  }
}
