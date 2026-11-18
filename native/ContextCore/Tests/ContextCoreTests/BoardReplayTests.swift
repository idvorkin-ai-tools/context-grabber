import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// #936 (story 990): Larry's batches replayed on copies of Igor's board 13f700bf (Cockpit thread igor2-88g.1525,
/// 2026-11-17, build 10b84a5f) by the board's own applier and planner, as `board-ops-harness` replays them. The
/// fixtures are laid out from the pictures that board sent and carry his batches exactly as he sent them.
final class BoardReplayTests: XCTestCase {
  private func fixture(_ name: String) throws -> Any {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/board-ops/\(name).json")
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
  }

  private func replay(_ name: String, then more: [BoardReplay.Step] = []) throws -> BoardReplay {
    var replay = BoardReplay(try BoardSnapshot(json: try fixture("\(name)-board")))
    replay.run(BoardReplay.Step.steps(try fixture("\(name)-ops"), key: name) + more)
    return replay
  }

  // MARK: The snapshot

  func testASnapshotReadsAsTheBoardSendsItAndWritesBackTheSame() throws {
    let snapshot = try BoardSnapshot(json: try fixture("ghost-delete-board"))
    XCTAssertEqual(snapshot.rev, 119)
    XCTAssertEqual(snapshot.ghosts.map(\.id).first, "larry-m1a-2")
    XCTAssertEqual(try BoardSnapshot(json: snapshot.json), snapshot)
  }

  func testAKeptTextIsOneThingUnderItsIDThatMovesWhole() throws {
    let json: [String: Any] = [
      "board": "b", "rev": 3,
      "strokes": [
        ["id": "a", "points": [[10, 100], [200, 100]]],
        [
          "kind": "text", "id": "larry-t", "text": "hi", "font": "print", "x": 40, "y": 300, "w": 60, "h": 20,
          "color": "#ba39e6", "t": 1_763_430_000_000,
        ],
      ],
    ]
    var replay = BoardReplay(try BoardSnapshot(json: json))
    replay.run([
      .batch(
        key: "m",
        json: ["board": "b", "base_rev": 3, "label": "push", "list": [["op": "translate", "below_y": 200, "dy": 80]]]
      )
    ])
    XCTAssertEqual(replay.outcomes.first?.moved, ["larry-t": CGVector(dx: 0, dy: 80)])
    XCTAssertEqual(replay.board.texts.first?.box.minY, 380)
    XCTAssertEqual(replay.board.rev, 4, "a change of the ink is a new revision")
  }

  func testABatchFromAnOlderLookRebasesUnlessItNamesWhatIgorMoved() throws {
    let json: [String: Any] = [
      "board": "b", "rev": 12, "touched": [["rev": 11, "ids": ["a"]]],
      "strokes": [
        ["id": "a", "points": [[10, 100], [200, 100]]], ["id": "b", "points": [[10, 300], [200, 300]]],
      ],
    ]
    var replay = BoardReplay(try BoardSnapshot(json: json))
    replay.run([
      .batch(key: "1", json: ["board": "b", "base_rev": 10, "label": "b", "list": [["op": "delete", "ids": ["b"]]]]),
      .batch(key: "2", json: ["board": "b", "base_rev": 10, "label": "a", "list": [["op": "delete", "ids": ["a"]]]]),
    ])
    XCTAssertEqual(replay.outcomes[0].result?.rebasedFrom, 10)
    XCTAssertEqual(Array(replay.outcomes[0].erased.keys), ["b"])
    XCTAssertEqual(replay.outcomes[1].action, "refused")
    XCTAssertEqual(replay.outcomes[1].result?.reason, BoardOps.Reason.stale)
  }

  func testStepsReadFromABatchAMessageOrAList() {
    let batch: [String: Any] = ["board": "b", "base_rev": 1, "label": "x", "list": []]
    XCTAssertEqual(BoardReplay.Step.steps(batch, key: "k").count, 1)
    XCTAssertEqual(BoardReplay.Step.steps(["id": "m1", "ops": batch], key: "k").count, 1)
    XCTAssertEqual(BoardReplay.Step.steps([batch, ["keep": ["t"]]], key: "k").count, 2)
    XCTAssertTrue(BoardReplay.Step.steps(["text": "no ops"], key: "k").isEmpty)
  }

  // MARK: Tonight's three, as the board answered them on 10b84a5f

  /// #937: a box and its label grouped in one change both land as ink, the label as a kept text in the group, and
  /// nothing is missing (on 10b84a5f the label stayed a ghost and came back as a missing id, rev 180).
  func testIssue937GroupedBoxAndLabelBothLand() throws {
    var replay = try replay("judge")
    let outcome = try XCTUnwrap(replay.outcomes.first)
    XCTAssertEqual(outcome.result?.ok, true)
    XCTAssertNil(outcome.result?.missingIDs)
    XCTAssertEqual(Set(outcome.drawn), ["larry-judge-box", "larry-judge-label"])
    XCTAssertTrue(replay.board.ghosts.isEmpty, "nothing left to keep")
    XCTAssertTrue(outcome.moved.isEmpty, "a label in his own box makes no room (#938)")
    let label = try XCTUnwrap(replay.board.texts.first { $0.id == "larry-judge-label" })
    XCTAssertEqual(label.meta?.group, "judge-block")
    XCTAssertEqual(label.box.minX, 545)
    replay.run([
      .batch(
        key: "move",
        json: [
          "board": replay.board.board, "base_rev": replay.board.rev ?? 0, "label": "move",
          "list": [["op": "translate", "ids": ["judge-block"], "dx": -100, "dy": 300]],
        ])
    ])
    let moved = try XCTUnwrap(replay.outcomes.last)
    XCTAssertEqual(moved.moved["larry-judge-box"], CGVector(dx: -100, dy: 300))
    XCTAssertEqual(moved.moved["larry-judge-label"], CGVector(dx: -100, dy: 300), "the label moves with its group")
  }

  /// #938: his list makes room: Igor's two lines under the diagram, and everything under them, move down clear of it;
  /// the diagram stays (on 10b84a5f the list landed on his writing and nothing moved).
  func testIssue938TextMakesRoomBelowIt() throws {
    let start = try BoardSnapshot(json: try fixture("list-board"))
    let replay = try replay("list")
    let outcome = try XCTUnwrap(replay.outcomes.first)
    XCTAssertEqual(outcome.result?.ok, true)
    XCTAssertNil(outcome.result?.missingIDs)
    let ink = replay.board.ink.map(\.bounds)
    for ghost in replay.board.ghosts {
      XCTAssertFalse(ink.contains { $0.intersects(ghost.box) }, "\(ghost.id) sits on ink")
    }
    let lowest = try XCTUnwrap(replay.board.ghosts.map(\.box.maxY).max())
    let moved = Set(outcome.moved.keys)
    for (before, after) in zip(start.ink, replay.board.ink) {
      if before.bounds.minY >= 570 {
        XCTAssertTrue(moved.contains(before.id), "\(before.id) under the list moves")
        XCTAssertGreaterThan(after.bounds.minY, lowest, "\(before.id) ends up under the list")
      } else {
        XCTAssertFalse(moved.contains(before.id), "\(before.id) above the list stays")
      }
      XCTAssertEqual(
        after.bounds.minY.truncatingRemainder(dividingBy: 1), before.bounds.minY.truncatingRemainder(dividingBy: 1))
    }
    XCTAssertEqual(replay.board.rev, 93, "the room is a change of the ink")
  }

  /// #939: a delete of texts still showing as ghosts came back as missing ids, and the ghosts stayed for Igor to keep.
  func testIssue939DeleteOfGhostsMisses() throws {
    let replay = try replay("ghost-delete", then: [.keep(["larry-m1b-2", "larry-m1d-2", "larry-m1e-2"])])
    XCTAssertEqual(
      replay.outcomes.first?.result?.missingIDs,
      ["larry-m1a-2", "larry-m1b-2", "larry-m1c-2", "larry-m1d-2", "larry-m1e-2"])
    XCTAssertEqual(replay.board.texts.map(\.id), ["larry-m1b-2", "larry-m1d-2", "larry-m1e-2"])
  }
}
