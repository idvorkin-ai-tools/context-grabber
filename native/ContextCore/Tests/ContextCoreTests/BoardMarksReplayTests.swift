import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// #941 (story 994): Larry's reply of 18:26 on board 13f700bf (Cockpit thread igor2-88g.1525, build 10b84a5f), exactly
/// as he sent it: four boxes, a name inside each, and three lines. The iPad showed all eleven (`paper_ghosts` count 11,
/// past_side false); Igor's three taps each chose a box or a line, and the names were never in reach.
final class BoardMarksReplayTests: XCTestCase {
  private func fixture(_ name: String) throws -> Any {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("Fixtures/board-ops/\(name).json")
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
  }

  private func family(then more: [BoardReplay.Step] = []) throws -> BoardReplay {
    var replay = BoardReplay(try BoardSnapshot(json: try fixture("family-board")))
    replay.run(BoardReplay.Step.steps(try fixture("family-marks"), key: "family") + more)
    return replay
  }

  private let row = "12c6abcb46e7"
  private func mark(_ i: Int) -> String { WhiteboardMarks.mark(i, of: row) }

  // The labels have letters only where there are fonts: the Mac, not `just test-linux`.
  #if canImport(CoreText)
    func testEveryMarkOfTheReplyShowsWhereHisPictureHadIt() throws {
      let replay = try family()
      XCTAssertEqual(replay.marks.count, 11, "four boxes, four names, three lines: nothing dropped")
      XCTAssertEqual(replay.marks.filter { $0.kind == .text }.compactMap(\.text), ["Igor", "Tori", "Zach", "Amelia"])
      // Placed by his frame's origin (0, 484.8), his picture's pixels at a scale of 1: Igor's box at 120, 1564.8.
      let igorBox = WhiteboardMarkChoice.bounds(replay.marks[0].lines)
      XCTAssertEqual(igorBox.minX, 120, accuracy: 0.01)
      XCTAssertEqual(igorBox.minY, 1564.8, accuracy: 0.01)
      // Each name sits inside its box.
      for (box, name) in [(0, 1), (2, 3), (7, 8), (9, 10)] {
        let outer = WhiteboardMarkChoice.bounds(replay.marks[box].lines)
        XCTAssertTrue(
          outer.contains(WhiteboardMarkChoice.bounds(replay.marks[name].lines)), "name \(name) in box \(box)")
      }
    }

    func testATapOnEachNameChoosesTheNameNotItsBox() throws {
      let outcome = try XCTUnwrap(try family().outcomes.last)
      for name in [1, 3, 8, 10] {
        let tap = try XCTUnwrap(outcome.taps.first { $0.mark == mark(name) })
        XCTAssertEqual(tap.chose, mark(name), "a tap on the words of \(name) chose \(tap.chose ?? "nothing")")
      }
      XCTAssertEqual(outcome.unreachable, [], "every mark of the reply can be tapped")
    }

    func testATapOnABoxSideStillChoosesTheBox() throws {
      let outcome = try XCTUnwrap(try family().outcomes.last)
      for box in [0, 2, 7, 9] {
        XCTAssertEqual(outcome.taps.first { $0.mark == mark(box) }?.chose, mark(box))
      }
    }

    func testIgorsOwnTapsChooseWhatTheyChoseOnTheIPad() throws {
      // From the iPad's session log: paper_tap at, then mark_chosen kind and the keep's ink box. His second tap
      // (464.5, 1712.7) chose the bottom line, 12 points away past its end; Amelia's box is 8 away and takes it now.
      // His third, (225.8, 1754.6), in the corner of the box round Zach, chose the box on the iPad, 10 points from its
      // bottom side, when the name was traced outlines. Written in single strokes (#895), the script Z's tail and the h
      // reach 6 points from the tap, so the nearer name takes it now, as #941's nearest-mark rule says.
      let replay = try family(then: [.tap(CGPoint(x: 487.1, y: 1544.5)), .tap(CGPoint(x: 225.8, y: 1754.6))])
      XCTAssertEqual(replay.outcomes.dropFirst().map { $0.taps.first?.chose }, [mark(2), mark(8)])
    }

    func testEveryPartOfANamesBoxChoosesTheName() throws {
      let replay = try family()
      for name in [1, 3, 8, 10] {
        let box = WhiteboardMarkChoice.bounds(replay.marks[name].lines)
        var points: [CGPoint] = []
        for i in 0...10 {
          for j in 0...10 {
            points.append(
              CGPoint(x: box.minX + box.width * CGFloat(i) / 10, y: box.minY + box.height * CGFloat(j) / 10))
          }
        }
        let other = points.filter { replay.choose(at: $0)?.id != mark(name) }
        XCTAssertEqual(other, [], "parts of name \(name)'s box go to another mark")
      }
    }
  #endif

  // MARK: Keep group (#942, story 995)

  func testKeepGroupMakesTheReplyInkUnderOneGroupThatMovesAsOne() throws {
    var replay = try family(then: [.keepGroup(row)])
    let kept = replay.board.ink.filter { $0.meta?.group == "reply-\(row)" }
    XCTAssertGreaterThanOrEqual(kept.count, 7, "the four boxes and three lines at least, and the names' letters")
    XCTAssertEqual(replay.marks, [], "nothing of the reply left to keep")
    XCTAssertEqual(replay.outcomes.last?.action, "kept")

    let move: [String: Any] = [
      "board": "13f700bf-ddcb-4a89-a6b7-64c0047f24e3", "base_rev": replay.board.rev ?? 0, "label": "move family",
      "list": [["op": "translate", "ids": ["reply-\(row)"], "dy": 80]],
    ]
    replay.run(BoardReplay.Step.steps(move, key: "move"))
    let outcome = try XCTUnwrap(replay.outcomes.last)
    XCTAssertEqual(outcome.action, "applied", "\(outcome.wire)")
    XCTAssertEqual(outcome.result?.missingIDs ?? [], [], "the group answers to its one name")
    XCTAssertEqual(Set(outcome.moved.keys), Set(kept.map(\.id)), "every stroke of the group moved, and only those")
    XCTAssertTrue(outcome.moved.values.allSatisfy { $0.dy == 80 })
  }

  // MARK: A late reply makes room (#894, stories 1003, 1005)

  /// The family board with a line Igor wrote at 1600 after the picture (made `at`), where the reply's top boxes land
  /// (they show from 1564.8 to 1764.8 on the board).
  private func familyWithALateLine(madeAt at: Int64, then more: [BoardReplay.Step]) throws -> BoardReplay {
    var json = try XCTUnwrap(try fixture("family-board") as? [String: Any])
    var strokes = try XCTUnwrap(json["strokes"] as? [[String: Any]])
    strokes.append([
      "id": "igor005", "t": at, "color": "#000000", "width": 3, "tool": "pen",
      "points": [[100, 1600], [330, 1606], [560, 1610]],
    ])
    json["strokes"] = strokes
    var replay = BoardReplay(try BoardSnapshot(json: json))
    replay.run(BoardReplay.Step.steps(try fixture("family-marks"), key: "family") + more)
    return replay
  }

  /// When the picture was taken: after every stroke of the fixture, which end at 1763432004000.
  private let picture: Int64 = 1_763_432_004_500

  func testKeepGroupOverALineWrittenAfterThePicturePushesItUnderTheReply() throws {
    let replay = try familyWithALateLine(madeAt: picture + 90_000, then: [.keepGroup(row, seen: picture)])
    let outcome = try XCTUnwrap(replay.outcomes.last)
    XCTAssertEqual(outcome.action, "kept")
    XCTAssertEqual(outcome.covered, 1, "\(outcome.wire)")
    let push = try XCTUnwrap(outcome.room)
    XCTAssertEqual(Set(outcome.moved.keys), ["igor005"], "only the late line; his writing above stays")
    let line = try XCTUnwrap(replay.board.ink.first { $0.id == "igor005" })
    let reply = replay.board.ink.filter { $0.meta?.group == "reply-\(row)" }.map(\.bounds)
      .reduce(CGRect.null) { $0.union($1) }
    XCTAssertGreaterThanOrEqual(line.bounds.minY + 1, reply.maxY + BoardRoom.air, "the line now sits under the reply")
    XCTAssertEqual(push.dy.truncatingRemainder(dividingBy: BoardRoom.line), 0, "whole lines")
    XCTAssertEqual(reply.minY, 1564.8, accuracy: 4, "the reply stays where it showed")
  }

  func testKeepGroupOverALineInHisPictureMovesNothing() throws {
    let replay = try familyWithALateLine(madeAt: picture - 500, then: [.keepGroup(row, seen: picture)])
    let outcome = try XCTUnwrap(replay.outcomes.last)
    XCTAssertEqual(outcome.covered, 0)
    XCTAssertNil(outcome.room)
    XCTAssertEqual(outcome.moved, [:])
  }

  func testKeepGroupOverAReplyOfHisKeptAfterThePictureMovesNothing() throws {
    // He answers the same picture twice, and the second reply lands on the first, kept a moment before: his own ink,
    // made after the picture, is never Igor's to push.
    var again = try XCTUnwrap(try fixture("family-marks") as? [String: Any])
    again["id"] = "second"
    var replay = try family(then: [.keepGroup(row, seen: picture)])
    replay.run(BoardReplay.Step.steps(again, key: "again") + [.keepGroup("second", seen: picture)])
    let outcome = try XCTUnwrap(replay.outcomes.last)
    XCTAssertEqual(outcome.action, "kept")
    XCTAssertEqual(outcome.covered, 0, "\(outcome.wire)")
    XCTAssertNil(outcome.room)
    XCTAssertEqual(outcome.moved, [:])
  }

  func testKeepGroupWithThePicturesTimeUnknownMovesNothing() throws {
    let replay = try familyWithALateLine(madeAt: picture + 90_000, then: [.keepGroup(row)])
    XCTAssertEqual(replay.outcomes.last?.moved, [:])
  }

  func testAKeepGroupStepFileCarriesThePicturesTime() {
    let steps = BoardReplay.Step.steps(["keep_group": "r", "seen": 42], key: "k")
    guard case .keepGroup(let reply, let seen)? = steps.first else { return XCTFail("not a keep group") }
    XCTAssertEqual(reply, "r")
    XCTAssertEqual(seen, 42)
  }

  func testKeepGroupOfAReplyNotShowingKeepsNothing() throws {
    let replay = try family(then: [.keepGroup("nope")])
    XCTAssertEqual(replay.outcomes.last?.action, "ignored")
    XCTAssertEqual(replay.marks.count, replay.outcomes.first?.marks.count)
  }

  func testAReplyWithNoFrameShowsNothing() throws {
    var replay = BoardReplay(try BoardSnapshot(json: try fixture("family-board")))
    let row = WhiteboardMarks.Row(id: "r", shapes: [.init(kind: .line, points: [.zero, CGPoint(x: 9, y: 9)])])
    replay.run([.marks(row)])
    XCTAssertEqual(replay.outcomes.last?.action, "unplaced")
    XCTAssertEqual(replay.marks, [])
  }

  // MARK: The rule

  func testTheNearestMarkTakesTheTapAndTheLaterOneATie() {
    let near = WhiteboardMarkChoice.nearest(["a", "b", "c"]) { ["a": 5, "b": 2, "c": nil][$0] ?? nil }
    XCTAssertEqual(near, "b")
    XCTAssertEqual(WhiteboardMarkChoice.nearest(["a", "b"]) { _ in 3 }, "b", "on top wins a tie")
    XCTAssertNil(WhiteboardMarkChoice.nearest(["a"]) { _ in nil })
  }

  func testALabelIsReachedAnywhereInItsBox() {
    let letters: [[CGPoint]] = [
      [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20)], [CGPoint(x: 50, y: 0), CGPoint(x: 60, y: 20)],
    ]
    // Between two letters, far from either outline.
    XCTAssertEqual(WhiteboardTurn.reach(letters, kind: .text, at: CGPoint(x: 30, y: 10), tolerance: 5), 0)
    XCTAssertNil(WhiteboardTurn.reach(letters, kind: .line, at: CGPoint(x: 30, y: 10), tolerance: 5))
    XCTAssertEqual(
      WhiteboardTurn.reach(letters, kind: .text, at: CGPoint(x: 63, y: 24), tolerance: 6) ?? -1, 5, accuracy: 0.01)
  }
}
