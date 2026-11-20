import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// #898 (story 1001): a reply of Larry's that is words with no marks stays in the note and the conversation panel and is
/// never drawn on the board. The oracle is the conversation spec (2026-11-12-whiteboard-conversation-design.md, *Words
/// alone are said, never drawn*). Each look runs the way the board's look at its thread does: the rows are read, the
/// marks take them, the note and its line hear his words, a row's marks become his ghosts, and the web source offers its
/// batches to the applier.
final class WhiteboardWordsOnlyTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  /// One look at the thread, as the board takes it.
  private struct Board {
    var marks = WhiteboardMarks()
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    var said = WhiteboardSaid()
    var source = WebBoardOpSource()
    var batches: [BoardOps.Batch] = []
    var panel: [WhiteboardNote.Row] = []

    mutating func look(_ body: Data, settled: String? = nil) throws -> WhiteboardMarks.Update {
      let rows = try XCTUnwrap(WhiteboardMarks.rows(body))
      panel = WhiteboardNote.recent(try XCTUnwrap(ChatWire.messages(body)))
      let update = marks.take(rows, settled: settled)
      turns.larrySaid(update.say, marks: update.marks != nil)
      said.larrySaid(update.say, marks: update.marks != nil)
      batches += source.batches(from: .rows(rows))
      if let row = update.marks {
        turns.larrysMarks(row.shapes.indices.map { G(id: WhiteboardMarks.mark($0, of: row.id), who: .larry) })
      }
      return update
    }
  }

  private let picture = #"{"id": "i1", "who": "igor", "text": "Your turn on the board", "picture_id": "p1"}"#
  private let marked = #"""
    {"id": "l1", "who": "larry", "text": "Here.", "picture_id": "p1",
     "frame": {"x": 0, "y": 0, "w": 400, "h": 300, "scale": 2},
     "shapes": [{"kind": "arrow", "points": [[0, 0], [100, 0]]}, {"kind": "circle", "cx": 50, "cy": 50, "r": 10}]}
    """#

  private func thread(_ messages: String...) -> Data {
    Data(#"{"ok": true, "messages": [\#(messages.joined(separator: ","))]}"#.utf8)
  }

  /// His words, in each form a words-only reply comes: no shapes at all, an empty list, or ops that aren't there.
  private let wordsOnly = [
    #"{"id": "l2", "who": "larry", "text": "That box is the bottleneck, not the queue."}"#,
    #"{"id": "l2", "who": "larry", "text": "That box is the bottleneck, not the queue.", "shapes": []}"#,
    #"""
    {"id": "l2", "who": "larry", "text": "That box is the bottleneck, not the queue.", "picture_id": "p1",
     "frame": {"x": 0, "y": 0, "w": 400, "h": 300, "scale": 2}, "shapes": [], "ops": null}
    """#,
  ]

  func testWordsAfterMarksAreSaidAndTheMarksStay() throws {
    for words in wordsOnly {
      var board = Board()
      board.marks.threadStarted()
      XCTAssertEqual(try board.look(thread(picture, marked)).marks?.id, "l1")
      let ghosts = board.turns.ghosts
      XCTAssertEqual(ghosts.map(\.id), ["l1#0", "l1#1"])

      let update = try board.look(thread(picture, marked, words))
      XCTAssertNil(update.marks, "nothing to draw: \(words)")
      XCTAssertEqual(update.unplaced, [], "words aren't marks with nowhere to go")
      XCTAssertTrue(update.replied, "it is still his answer")
      XCTAssertEqual(board.turns.ghosts, ghosts, "his marks from before stay, and nothing new is offered to keep")
      XCTAssertTrue(board.batches.isEmpty, "no change to the board")
      XCTAssertEqual(board.turns.note, "Larry: That box is the bottleneck, not the queue.")
      XCTAssertEqual(board.said.larry, "That box is the bottleneck, not the queue.")
      XCTAssertEqual(
        board.panel.last,
        .init(id: "l2", kind: .larry, who: "Larry", text: "That box is the bottleneck, not the queue.", mark: nil))
    }
  }

  func testAThreadOfOnlyWordsDrawsNothing() throws {
    for words in wordsOnly {
      // Opened on a thread that already holds his words, and a look that finds them new.
      var opened = Board()
      XCTAssertEqual(try opened.look(thread(picture, words)), .init())
      var asked = Board()
      asked.marks.threadStarted()
      let update = try asked.look(thread(picture, words))
      XCTAssertNil(update.marks)
      XCTAssertEqual(update.say, "That box is the bottleneck, not the queue.")
      for board in [opened, asked] {
        XCTAssertTrue(board.turns.ghosts.isEmpty, "nothing on the board: \(words)")
        XCTAssertTrue(board.batches.isEmpty)
        XCTAssertEqual(board.panel.map(\.text).last, "That box is the bottleneck, not the queue.")
      }
    }
  }

  /// Opening the board on a thread whose newest reply is words: the settled marks before it stay away, and the words
  /// bring none back.
  func testOpeningOnWordsAfterSettledMarksShowsNothing() throws {
    var board = Board()
    let update = try board.look(thread(picture, marked, wordsOnly[0]), settled: "l1")
    XCTAssertNil(update.marks)
    XCTAssertTrue(board.turns.ghosts.isEmpty)
    XCTAssertTrue(board.batches.isEmpty)
  }

  /// The replay harness (#936) agrees: his words as a step leave the board and his marks as they were, and say so.
  func testTheReplayLeavesTheBoardAsItWas() throws {
    let board = try BoardSnapshot(json: [
      "board": "b", "rev": 3, "strokes": [["id": "a", "points": [[10, 100], [200, 100]]]],
    ])
    var replay = BoardReplay(board)
    let steps = try BoardReplay.Step.steps(
      JSONSerialization.jsonObject(with: Data("[\(marked), \(wordsOnly[2])]".utf8)), key: "t")
    replay.run(steps)
    let marks = replay.marks.map(\.id)
    XCTAssertEqual(marks, ["l1#0", "l1#1"])
    XCTAssertEqual(replay.board, board, "nothing drawn, moved or erased")
    XCTAssertEqual(replay.outcomes.last?.action, "said", "words only: nothing to place")
    XCTAssertEqual(replay.outcomes.last?.marks, [])
    // A message with words and no `shapes` key is no step at all.
    XCTAssertTrue(
      BoardReplay.Step.steps(try JSONSerialization.jsonObject(with: Data(wordsOnly[0].utf8)), key: "w").isEmpty)
  }
}
