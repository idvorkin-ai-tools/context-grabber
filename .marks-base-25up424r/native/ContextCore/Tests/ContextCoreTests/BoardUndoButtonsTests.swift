//  #965 (stories 1008, 1009): the board's Undo and Redo buttons, from the stack's state.

import ContextCore
import XCTest

final class BoardUndoButtonsTests: XCTestCase {
  func testABoardJustOpenedHasBothDimmed() {
    let buttons = BoardUndoButtons.none
    XCTAssertEqual(buttons.undo, .init(label: "Undo", enabled: false))
    XCTAssertEqual(buttons.redo, .init(label: "Redo", enabled: false))
  }

  /// Story 1009: a kept group on top reads *Undo Keep group*.
  func testANamedStepIsNamed() {
    let buttons = BoardUndoButtons(canUndo: true, canRedo: true, undoName: "Keep group", redoName: "Paste")
    XCTAssertEqual(buttons.undo, .init(label: "Undo Keep group", enabled: true))
    XCTAssertEqual(buttons.redo, .init(label: "Redo Paste", enabled: true))
  }

  /// His own stroke has no name: plain *Undo*.
  func testAStepWithNoNameIsPlain() {
    let buttons = BoardUndoButtons(canUndo: true, canRedo: false, undoName: "  ", redoName: "")
    XCTAssertEqual(buttons.undo, .init(label: "Undo", enabled: true))
    XCTAssertEqual(buttons.redo, .init(label: "Redo", enabled: false))
  }

  /// PencilKit names his stroke *Add Strokes*; the button still reads plain *Undo* and *Redo* (story 1009).
  func testHisStrokeReadsPlainUndoThoughPencilKitNamesIt() {
    let buttons = BoardUndoButtons(canUndo: true, canRedo: true, undoName: "Add Strokes", redoName: "Add Strokes")
    XCTAssertEqual(buttons.undo, .init(label: "Undo", enabled: true))
    XCTAssertEqual(buttons.redo, .init(label: "Redo", enabled: true))
  }

  /// A stale name with nothing to do isn't read: a dimmed button says only what it is.
  func testADimmedButtonNamesNoStep() {
    let buttons = BoardUndoButtons(canUndo: false, canRedo: false, undoName: "Keep", redoName: "Keep")
    XCTAssertEqual(buttons.undo.label, "Undo")
    XCTAssertEqual(buttons.redo.label, "Redo")
  }

  func testAButtonIsAFingersSize() {
    XCTAssertGreaterThanOrEqual(BoardUndoButtons.side, 44, "Apple's smallest tap target")
  }
}
