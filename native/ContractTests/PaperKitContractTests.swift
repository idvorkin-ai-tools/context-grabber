//  Contract tests on real PaperKit and PencilKit (bead 0u3k, arch 3): what the whiteboard relies on the platform doing,
//  or works around it not doing, pinned on the simulator, so the iOS that changes it fails here and not on Igor's
//  iPad. Each test names the board's code that rests on it. When one fails, the platform moved: read what the board
//  does with that behaviour before changing the test. The touches (a finger tap's dot, cancel against end, a pick made
//  with a finger in the picker, a drawn stroke's undo name) need a real touch, so they are UI tests, not these.

import PaperKit
import PencilKit
import UIKit
import XCTest

@MainActor
final class PaperKitContractTests: XCTestCase {
  private var stage: PaperStage?

  override func setUp() async throws {
    continueAfterFailure = true
    stage = try PaperStage()
  }

  override func tearDown() async throws {
    stage?.close()
    stage = nil
  }

  private func theStage() throws -> PaperStage { try XCTUnwrap(stage) }

  /// Where each held stroke sits down the page, in order: which strokes a markup holds, at a glance.
  private func ys(_ markup: PaperMarkup?) -> [Int] {
    (markup?.subelements.strokes.map { Int($0.renderFrame.midY.rounded()) } ?? []).sorted()
  }

  // MARK: - The tool

  /// #1078 (story 1064): the board decides eraser-or-ink from `paper.drawingTool`, believing it follows the picker on
  /// the next turn. A pick made in code doesn't move it: the picker's own `selectedToolItem` says the eraser, and its
  /// observers hear the pick, while the paper's tool stays the pen, half a second on. (A pick made with a finger is the
  /// UI tests' and the iPad's.)
  func testAPickInThePickerMovesTheItemButNotThePapersTool() throws {
    let stage = try theStage()
    XCTAssertTrue(stage.picker.isVisible, "the picker shows while the paper holds the responder state")
    // The picker keeps its pick across launches, so a run starts it on the pen.
    let pen = try XCTUnwrap(
      stage.picker.toolItems.first { ($0 as? PKToolPickerInkingItem)?.inkingTool.inkType == .pen }, "a pen")
    stage.picker.selectedToolItem = pen
    PaperStage.wait(0.3)
    XCTAssertTrue(stage.paper.drawingTool is PKInkingTool)
    let eraser = try XCTUnwrap(
      stage.picker.toolItems.first { $0 is PKToolPickerEraserItem }, "the picker has an eraser")
    let heard = stage.delegate.toolPicks
    stage.picker.selectedToolItem = eraser
    XCTAssertEqual(stage.picker.selectedToolItem.identifier, eraser.identifier, "the picker holds the pick at once")
    XCTAssertGreaterThan(stage.delegate.toolPicks, heard, "the picker's observers hear the pick at once")
    PaperStage.wait(0.5)
    XCTAssertTrue(
      stage.paper.drawingTool is PKInkingTool,
      "the paper's tool now follows the picker (\(type(of: stage.paper.drawingTool))): #1078's stale getter is gone")
    let lasso = try XCTUnwrap(stage.picker.toolItems.first { $0 is PKToolPickerLassoItem })
    stage.picker.selectedToolItem = lasso
    PaperStage.wait(0.5)
    XCTAssertTrue(stage.paper.drawingTool is PKInkingTool, "nor does a lasso pick move it")
  }

  /// The other way round: setting the paper's tool (the board does, to give the Pencil back after Keep) leaves the
  /// picker where it was, so the picker still shows the last pick.
  func testSettingThePapersToolLeavesThePicker() throws {
    let stage = try theStage()
    let eraser = try XCTUnwrap(stage.picker.toolItems.first { $0 is PKToolPickerEraserItem })
    stage.picker.selectedToolItem = eraser
    PaperStage.wait(0.2)
    stage.paper.drawingTool = PKInkingTool(.marker, color: .red, width: 10)
    PaperStage.wait(0.3)
    XCTAssertEqual(stage.picker.selectedToolItem.identifier, eraser.identifier, "the picker doesn't follow the paper")
    XCTAssertEqual((stage.paper.drawingTool as? PKInkingTool)?.inkType, .marker, "the paper holds the tool it was set")
  }

  /// The picker offers every ink the board's feature set names, and an eraser and a lasso: what `pickerText` and the
  /// fold and card erases read.
  func testThePickerOffersTheBoardsInksAnEraserAndALasso() throws {
    let stage = try theStage()
    let items = Set(stage.picker.toolItems.map(\.identifier))
    for ink in PaperStage.inks {
      XCTAssertTrue(
        stage.picker.toolItems.contains { ($0 as? PKToolPickerInkingItem)?.inkingTool.inkType == ink },
        "the picker offers \(ink.rawValue): \(items.sorted())")
    }
    XCTAssertTrue(stage.picker.toolItems.contains { $0 is PKToolPickerEraserItem }, "an eraser")
    XCTAssertTrue(stage.picker.toolItems.contains { $0 is PKToolPickerLassoItem }, "a lasso")
  }

  // MARK: - Setting the markup

  /// Every `paper.markup = …` on the board (12 of them) takes the set as held at once, and wraps it in `quiet` because
  /// PaperKit tells the delegate about the app's own set, at once, once. A set is no step on the undo stack: the board
  /// registers its own.
  func testASetIsHeldAtOnceToldOnceAndIsNoUndoStep() throws {
    let stage = try theStage()
    let undo = try XCTUnwrap(stage.paper.undoManager, "the paper has an undo manager")
    let before = stage.delegate.changes
    let wanted = PaperStage.markup([100, 200])
    stage.paper.markup = wanted
    XCTAssertEqual(stage.held, 2, "held at once")
    XCTAssertEqual(stage.delegate.changes - before, 1, "the delegate is told at once, once")
    XCTAssertFalse(undo.canUndo, "a set is no undo step")
    PaperStage.wait(0.3)
    XCTAssertEqual(stage.delegate.changes - before, 1, "and not again a beat later")
    XCTAssertEqual(stage.paper.markup, wanted, "what is held is what was set")
    stage.paper.markup = PaperStage.adding(wanted, at: 300)
    XCTAssertEqual(stage.held, 3)
    stage.paper.markup = wanted
    XCTAssertEqual(stage.held, 2, "a set back to an older markup is held too")
  }

  /// #999, #1015: PaperKit refuses a set whole when the markup was built from an older one than the paper now holds:
  /// a sibling of what it holds, with ink of its own. Neither branch's new ink stays, the paper going back to the
  /// markup both were built from. The scratch-out was built from the markup the zigzag's change handed over, before
  /// PaperKit's step was taken back, and the scratched ink came back; the fix builds from what the paper holds.
  func testASetBuiltFromAnOlderMarkupThanTheHeldOneIsRefused() throws {
    let stage = try theStage()
    let base = PaperStage.markup([100, 200, 300])
    stage.paper.markup = base
    let held = PaperStage.adding(base, at: 600)
    stage.paper.markup = held
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300, 600], "a markup built from the held one is held")
    stage.paper.markup = PaperStage.adding(base, at: 500)
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300], "the sibling is refused, and the held 600 goes too")
    PaperStage.wait(0.3)
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300], "and stays refused a beat later")
    stage.paper.markup = held
    var less = base
    let first = try XCTUnwrap(base.subelements.strokes.first?.elementID)
    less.subelements.removeElement(for: first)
    stage.paper.markup = less
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300], "a sibling that only takes ink away is refused too")
  }

  /// The way round it, the one the board takes (#999, #1015): build the set from `paper.markup` as it is now. And a set
  /// of a markup the paper held before (an Undo step's) is held, as is a new markup built from nothing.
  func testASetBuiltFromTheHeldMarkupAnEarlierOneOrANewOneIsHeld() throws {
    let stage = try theStage()
    let base = PaperStage.markup([100, 200, 300])
    stage.paper.markup = base
    stage.paper.markup = PaperStage.adding(base, at: 600)
    var now = try XCTUnwrap(stage.paper.markup)
    let gone = try XCTUnwrap(now.subelements.strokes.first { $0.renderFrame.midY.rounded() == 600 }?.elementID)
    now.subelements.removeElement(for: gone)
    now.append(contentsOf: PKDrawing(strokes: [PaperStage.stroke(at: 500)]))
    stage.paper.markup = now
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300, 500], "built from what is held: held")
    stage.paper.markup = base
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300], "a markup held before: held")
    stage.paper.markup = PaperStage.adding(try XCTUnwrap(stage.paper.markup), at: 700)
    stage.paper.markup = PaperStage.markup([50, 150])
    XCTAssertEqual(ys(stage.paper.markup), [50, 150], "a new markup, built from nothing: held")
  }

  /// The board never sets the markup from inside PaperKit's change callback, always on a later turn. A set built from
  /// what the paper holds, made inside the callback, is held all the same: the refusals are the older base's, not the
  /// callback's.
  func testASetFromInsideTheChangeCallbackBuiltFromTheHeldMarkupIsHeld() throws {
    let stage = try theStage()
    stage.paper.markup = PaperStage.markup([100, 200, 300])
    var heldInside: [Int] = []
    stage.delegate.duringNextChange = { paper in
      heldInside = self.ys(paper.markup)
      if let now = paper.markup { paper.markup = PaperStage.adding(now, at: 700) }
    }
    stage.paper.markup = PaperStage.adding(try XCTUnwrap(stage.paper.markup), at: 600)
    XCTAssertEqual(heldInside, [100, 200, 300, 600], "inside the callback, the outer set is held")
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300, 600, 700], "the callback's own set is held")
    PaperStage.wait(0.3)
    XCTAssertEqual(ys(stage.paper.markup), [100, 200, 300, 600, 700], "and a beat later")
  }

  /// The board's selection checks (`paper.selection`, 21 reads) take an id there as a stroke on the sheet. A set that
  /// takes the selected stroke away leaves its id selected.
  func testASetThatTakesTheSelectedStrokeLeavesItsIdSelected() throws {
    let stage = try theStage()
    stage.paper.markup = PaperStage.markup([100, 200, 300])
    var markup = try XCTUnwrap(stage.paper.markup)
    let first = try XCTUnwrap(markup.subelements.strokes.first?.elementID)
    stage.paper.selection = [first]
    PaperStage.wait(0.2)
    XCTAssertEqual(stage.paper.selection, [first], "a selection set in code is held")
    markup.subelements.removeElement(for: first)
    stage.paper.markup = markup
    PaperStage.wait(0.3)
    XCTAssertEqual(stage.held, 2, "a set with a selection showing is held")
    XCTAssertEqual(stage.paper.selection, [first], "the gone stroke's id is still selected")
  }

  // MARK: - Undo

  /// #966, #965: the board registers its own steps (a keep, Larry's batch) on PaperKit's undo manager and names them;
  /// the bar's Undo reads the name. A registered step's name is what Undo says, and Redo says it once undone.
  func testABoardsOwnStepOnPaperKitsStackKeepsItsName() throws {
    let stage = try theStage()
    let undo = try XCTUnwrap(stage.paper.undoManager)
    stage.paper.markup = PaperStage.markup([100])
    XCTAssertFalse(undo.canUndo)
    var undone = 0
    undo.registerUndo(withTarget: stage.delegate) { _ in undone += 1 }
    undo.setActionName("Keep group")
    XCTAssertTrue(undo.canUndo)
    XCTAssertEqual(undo.undoActionName, "Keep group")
    PaperStage.wait(0.2)
    XCTAssertEqual(undo.undoActionName, "Keep group", "the name holds past the turn")
    undo.undo()
    XCTAssertEqual(undone, 1, "Undo runs the board's step")
    XCTAssertEqual(undo.redoActionName, "", "a step that registers no redo leaves none")
    XCTAssertFalse(undo.canUndo)
  }

  // MARK: - Ink

  /// #1083 (story 1063): `WhiteboardInk` reads a stroke's kind through the Objective-C ink's `inkType` key, never
  /// PencilKit's Swift getter. Every ink the board offers reads its own name that way, through a markup and back.
  func testEveryInkReadsItsKindThroughAMarkup() throws {
    let stage = try theStage()
    var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
    let strokes = PaperStage.inks.enumerated().map { index, kind in
      PaperStage.stroke(at: CGFloat(60 * (index + 1)), ink: PKInk(kind, color: .blue))
    }
    markup.append(contentsOf: PKDrawing(strokes: strokes))
    stage.paper.markup = markup
    let read = Set(stage.paper.markup?.subelements.strokes.compactMap { PaperStage.kind($0.ink) } ?? [])
    XCTAssertEqual(read, Set(PaperStage.inks.map(\.rawValue)), "each ink's kind, by the key, as it was drawn")
  }

  /// An ink of a kind PencilKit's Swift enum has no case for (the iPad's three crashes): its kind is stored under
  /// `identifier` and read back by `inkType`, it rides a markup and the paper unchanged, and the Swift enum has no case
  /// for it, which is why the getter traps.
  func testAnInkOfAnUnknownKindRidesTheMarkupAndReadsByKey() throws {
    let stage = try theStage()
    let unknown = "com.apple.ink.somethingnew"
    let ref = PKInk(.pen, color: .red) as PKInkReference
    XCTAssertEqual(ref.value(forKey: "identifier") as? String, PKInk.InkType.pen.rawValue, "the kind is stored here")
    ref.setValue(unknown, forKey: "identifier")
    XCTAssertEqual(PaperStage.kind(ref as PKInk), unknown, "and read back by inkType")
    XCTAssertNil(PKInk.InkType(rawValue: unknown), "the Swift enum has no case for it")
    var markup = PaperMarkup(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
    markup.append(contentsOf: PKDrawing(strokes: [PaperStage.stroke(at: 100, ink: ref as PKInk)]))
    XCTAssertEqual(markup.subelements.strokes.first.flatMap { PaperStage.kind($0.ink) }, unknown, "through a markup")
    stage.paper.markup = markup
    XCTAssertEqual(
      stage.paper.markup?.subelements.strokes.first.flatMap { PaperStage.kind($0.ink) }, unknown, "held by the paper")
  }

  /// A board is saved as a PencilKit drawing. A drawing holding an ink of a kind this PencilKit doesn't know is written,
  /// and refused when read back ("from a future version"): a board file with one can't be opened by this build.
  func testADrawingWithAnUnknownInkWritesButDoesNotReadBack() throws {
    let ref = PKInk(.pen, color: .red) as PKInkReference
    ref.setValue("com.apple.ink.somethingnew", forKey: "identifier")
    let data = PKDrawing(strokes: [PaperStage.stroke(at: 100, ink: ref as PKInk)]).dataRepresentation()
    XCTAssertFalse(data.isEmpty, "it writes")
    XCTAssertThrowsError(try PKDrawing(data: data), "it doesn't read back") { error in
      XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain, "\(error)")
    }
    let known = PKDrawing(strokes: [PaperStage.stroke(at: 100)]).dataRepresentation()
    XCTAssertEqual(try PKDrawing(data: known).strokes.count, 1, "a drawing of known inks reads back")
  }
}
