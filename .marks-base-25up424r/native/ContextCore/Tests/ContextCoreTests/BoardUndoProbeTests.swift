//  #966 (story 1007): the board's take-back of PaperKit's own step never takes a keep's step instead.

import ContextCore
import XCTest

final class BoardUndoProbeTests: XCTestCase {
  /// A stack of steps, each an undo and its redo, as an undo manager holds them.
  private final class Stack: BoardUndoStack {
    struct Step {
      var undo: () -> Void
      var redo: () -> Void
    }
    var done: [Step] = []
    var undone: [Step] = []
    var canUndo: Bool { !done.isEmpty }
    func push(_ step: Step) {
      done.append(step)
      undone = []
    }
    func undo() {
      guard let step = done.popLast() else { return }
      step.undo()
      undone.append(step)
    }
    func redo() {
      guard let step = undone.popLast() else { return }
      step.redo()
      done.append(step)
    }
  }

  private var board: [String] = []
  private var told: [String] = []

  /// PaperKit's own step: a stroke drawn, taken back by an undo.
  private func paperKits(_ stroke: String, on stack: Stack) {
    board.append(stroke)
    stack.push(.init(undo: { self.board.removeAll { $0 == stroke } }, redo: { self.board.append(stroke) }))
  }

  /// The board's own step, a keep: its run asks the probe first, and tells Larry of an undo only when not probing.
  private func keep(_ strokes: [String], named name: String, on stack: Stack, probe: BoardUndoProbe) {
    board += strokes
    stack.push(
      .init(
        undo: {
          if !probe.reached(name) { self.told.append("undo \(name)") }
          self.board.removeAll { strokes.contains($0) }
        },
        redo: {
          if !probe.reached(name) { self.told.append("redo \(name)") }
          self.board += strokes
        }))
  }

  func testPaperKitsStepOnTopIsTakenBack() {
    let stack = Stack()
    let probe = BoardUndoProbe()
    keep(["his-1", "his-2"], named: "Keep group", on: stack, probe: probe)
    paperKits("dot", on: stack)
    XCTAssertEqual(probe.takeBackOthers(on: stack), .tookBack)
    XCTAssertEqual(board, ["his-1", "his-2"], "the dot went, the group stayed")
    XCTAssertEqual(stack.done.count, 1, "the keep is still a step")
    XCTAssertFalse(probe.probing)
  }

  /// The bug: PaperKit's step not on top yet, so the take-back reached the keep. It stays, still a step, and one Undo
  /// takes it back.
  func testAKeepOnTopIsLeftWhereItWasAndOneUndoStillTakesItBack() {
    let stack = Stack()
    let probe = BoardUndoProbe()
    paperKits("plan", on: stack)
    keep(["his-1", "his-2", "his-3"], named: "Keep group", on: stack, probe: probe)
    XCTAssertEqual(probe.takeBackOthers(on: stack), .leftOurs("Keep group"))
    XCTAssertEqual(board, ["plan", "his-1", "his-2", "his-3"], "nothing changed")
    XCTAssertEqual(stack.done.count, 2, "both steps still there")
    XCTAssertTrue(stack.undone.isEmpty, "nothing left as Redo")
    XCTAssertTrue(told.isEmpty, "Larry hears of no undo the probe made")
    stack.undo()
    XCTAssertEqual(board, ["plan"], "one Undo took the whole group back")
    XCTAssertEqual(told, ["undo Keep group"])
  }

  func testNothingToUndoDoesNothing() {
    let stack = Stack()
    XCTAssertEqual(BoardUndoProbe().takeBackOthers(on: stack), .nothing)
  }

  func testAStepRunOutsideTheProbeIsNotTheProbes() {
    XCTAssertFalse(BoardUndoProbe().reached("Keep"))
  }

  #if canImport(ObjectiveC)
    /// The same with Foundation's own undo manager, as the board's is.
    func testFoundationsUndoManagerKeepsTheKeep() {
      let undo = UndoManager()
      undo.groupsByEvent = false
      let probe = BoardUndoProbe()
      final class Target {}
      let target = Target()
      func step(to now: [String], from was: [String], named name: String) {
        undo.registerUndo(withTarget: target) { _ in
          _ = probe.reached(name)
          self.board = was
          step(to: was, from: now, named: name)
        }
        undo.setActionName(name)
      }
      board = ["plan"]
      undo.beginUndoGrouping()
      step(to: ["plan", "his"], from: ["plan"], named: "Keep group")
      board = ["plan", "his"]
      undo.endUndoGrouping()
      XCTAssertEqual(probe.takeBackOthers(on: undo), .leftOurs("Keep group"))
      XCTAssertEqual(board, ["plan", "his"])
      XCTAssertTrue(undo.canUndo)
      XCTAssertFalse(undo.canRedo)
      XCTAssertEqual(undo.undoActionName, "Keep group")
      undo.undo()
      XCTAssertEqual(board, ["plan"])
    }
  #endif
}
