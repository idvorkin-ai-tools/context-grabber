//  Story 1130 (bead context-grabber-fjh0): a decision card folds and opens again, the fold kept per ask.

import ContextCore
import XCTest

final class ChatDecisionFoldsTests: XCTestCase {
  func testAFoldIsPerAskAndOpeningForgetsIt() {
    var folds = ChatDecisionFolds()
    XCTAssertFalse(folds.isFolded("a"))
    XCTAssertTrue(folds.set("a", folded: true))
    XCTAssertTrue(folds.isFolded("a"))
    XCTAssertFalse(folds.isFolded("b"), "only that ask")
    XCTAssertFalse(folds.set("a", folded: true), "already folded")
    XCTAssertTrue(folds.set("a", folded: false))
    XCTAssertFalse(folds.isFolded("a"))
    XCTAssertFalse(folds.set("a", folded: false), "already open")
    XCTAssertEqual(folds.ids, [])
  }

  func testWhatWasSavedReadsBackWithoutRepeatsOrBlanks() {
    let folds = ChatDecisionFolds(["a", "", "b", "a"])
    XCTAssertEqual(folds.ids, ["a", "b"])
    XCTAssertEqual(ChatDecisionFolds(folds.ids), folds, "the saved list is the folds")
  }

  func testTheOldestFoldsGoPastTheCap() {
    var folds = ChatDecisionFolds((0..<ChatDecisionFolds.cap).map { "ask-\($0)" })
    XCTAssertTrue(folds.isFolded("ask-0"))
    folds.set("new", folded: true)
    XCTAssertEqual(folds.ids.count, ChatDecisionFolds.cap)
    XCTAssertFalse(folds.isFolded("ask-0"), "the oldest went")
    XCTAssertTrue(folds.isFolded("ask-1"))
    XCTAssertTrue(folds.isFolded("new"))
    let long = ChatDecisionFolds((0...ChatDecisionFolds.cap).map { "x\($0)" })
    XCTAssertEqual(long.ids.first, "x1", "a long saved list too")
  }
}
