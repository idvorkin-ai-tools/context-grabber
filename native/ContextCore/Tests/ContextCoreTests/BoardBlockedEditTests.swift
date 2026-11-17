import XCTest

@testable import ContextCore

/// The oracle is the board ops spec's *When Larry's edit is blocked* (stories 970–972).
final class BoardBlockedEditTests: XCTestCase {
  func testARefusedChangeShowsTheChipWithItsLabelAndWhy() {
    var chip = BoardBlockedEdit()
    XCTAssertFalse(chip.showing)
    XCTAssertTrue(chip.refused(label: "make room", reason: "stale"))
    XCTAssertTrue(chip.showing)
    XCTAssertEqual(chip.label, "make room")
    XCTAssertEqual(chip.reason, "stale")
  }

  func testANewerRefusalReplacesTheChipNeverPilesUp() {
    var chip = BoardBlockedEdit()
    chip.refused(label: "make room", reason: "stale")
    chip.refused(label: "add text", reason: "not_applied")
    XCTAssertEqual(chip.label, "add text")
    XCTAssertTrue(chip.retry())
    XCTAssertFalse(chip.showing, "one chip: one Retry clears it")
  }

  func testRetryClearsItAndSaysToSendOnlyWhenItShowed() {
    var chip = BoardBlockedEdit()
    XCTAssertFalse(chip.retry(), "no chip, nothing to send")
    chip.refused(label: "make room", reason: "stale")
    XCTAssertTrue(chip.retry())
    XCTAssertFalse(chip.showing)
  }

  func testDismissPutsItAwayAndALaterAppliedChangeClearsIt() {
    var chip = BoardBlockedEdit()
    chip.refused(label: "make room", reason: "stale")
    XCTAssertTrue(chip.dismissed())
    XCTAssertFalse(chip.showing)
    chip.refused(label: "make room", reason: "stale")
    XCTAssertTrue(chip.applied())
    XCTAssertFalse(chip.showing)
    XCTAssertFalse(chip.applied(), "nothing showing to clear")
  }

  func testAChangeDroppedAsTheBoardClosesShowsNothing() {
    var chip = BoardBlockedEdit()
    XCTAssertFalse(chip.refused(label: "make room", reason: "board_closed"))
    XCTAssertFalse(chip.showing)
  }
}
