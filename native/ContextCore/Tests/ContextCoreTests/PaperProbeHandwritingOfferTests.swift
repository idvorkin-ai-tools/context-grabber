//  Stories 945, 946 (bead context-grabber-4nnh): the system's handwriting offer told apart, and when a tapped group's
//  selection is put back.

import ContextCore
import XCTest

final class PaperProbeHandwritingOfferTests: XCTestCase {
  func testTheIPadsRemotePopoverAtThePaperIsTheOffer() {
    // The iPad, 2026-11-22: _UICampoPresentedViewController, a popover from the PaperView, drawn by another process.
    XCTAssertTrue(
      PaperProbe.isHandwritingOffer(
        popover: true, pointsAtPaper: true, remote: true, kind: "_UICampoPresentedViewController"))
    XCTAssertTrue(PaperProbe.isHandwritingOffer(popover: true, pointsAtPaper: true, remote: false, kind: "_UICampoX"))
    XCTAssertTrue(PaperProbe.isHandwritingOffer(popover: true, pointsAtPaper: true, remote: true, kind: "Other"))
  }

  func testTheBoardsOwnSheetsAndPopoversElsewhereAreLeftAlone() {
    // The board itself, a full-screen cover.
    XCTAssertFalse(
      PaperProbe.isHandwritingOffer(
        popover: false, pointsAtPaper: false, remote: false, kind: "PresentationHostingController<AnyView>"))
    // A popover from a toolbar button, or the tool picker's.
    XCTAssertFalse(PaperProbe.isHandwritingOffer(popover: true, pointsAtPaper: false, remote: true, kind: "_UICampo"))
    // A local popover at the paper that isn't the system's text offer.
    XCTAssertFalse(PaperProbe.isHandwritingOffer(popover: true, pointsAtPaper: true, remote: false, kind: "Menu"))
  }

  func testASilentlyEmptiedSelectionIsPutBackThreeTimesThenLeft() {
    let lost = { (tries: Int) in
      PaperProbe.groupTapLoss(selected: 0, wanted: 93, same: false, live: true, undoing: false, putBacks: tries)
    }
    // The iPad, 2026-11-22: 93 strokes selected by the tap, 0 a second later, no touch since.
    XCTAssertEqual(lost(0), .putBack)
    XCTAssertEqual(lost(2), .putBack)
    XCTAssertEqual(lost(3), .givenUp)
  }

  func testAHeldSelectionAndOneThatIsntTheBoardsAreLeftAlone() {
    XCTAssertEqual(
      PaperProbe.groupTapLoss(selected: 93, wanted: 93, same: true, live: true, undoing: false, putBacks: 0), .held)
    // Something else selected: Igor's or PaperKit's choice, never fought.
    XCTAssertEqual(
      PaperProbe.groupTapLoss(selected: 4, wanted: 93, same: false, live: true, undoing: false, putBacks: 0), .notOurs)
    // A touch since, or the window over.
    XCTAssertEqual(
      PaperProbe.groupTapLoss(selected: 0, wanted: 93, same: false, live: false, undoing: false, putBacks: 0), .notOurs)
    XCTAssertEqual(
      PaperProbe.groupTapLoss(selected: 0, wanted: 93, same: false, live: true, undoing: true, putBacks: 0), .notOurs)
    // The group's strokes gone (deleted, or turned to text).
    XCTAssertEqual(
      PaperProbe.groupTapLoss(selected: 0, wanted: 0, same: true, live: true, undoing: false, putBacks: 0), .notOurs)
  }

  func testTheFakeOfferHookIsReadFromTheEnvironment() {
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_FAKE_OFFER": "1"]).fakeHandwritingOffer)
    XCTAssertFalse(WhiteboardHooks([:]).fakeHandwritingOffer)
  }
}
