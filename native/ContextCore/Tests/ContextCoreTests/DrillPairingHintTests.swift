import XCTest

@testable import ContextCore

/// Story 227 (#1371): a Stats load the ledger refused says the pairing lapsed and how to pair again.
final class DrillPairingHintTests: XCTestCase {
  func testARefusedKeySaysWhatToDo() {
    let said = DrillPairingHint.explained("Could not load the stats: the ledger answered 401")
    XCTAssertTrue(said.hasPrefix("Could not load the stats: the ledger answered 401. "), said)
    XCTAssertTrue(said.contains("pairing has lapsed or was refused"), said)
    XCTAssertTrue(said.contains("ask Larry in chat for a pair link"), said)
    XCTAssertTrue(said.contains("Pair with code"), said)
    XCTAssertTrue(
      DrillPairingHint.explained("Could not load the stats: the ledger answered 403").contains("Pair with code"))
  }

  func testAnyOtherFailureReadsAsBefore() {
    for message in [
      "Could not load the stats: the ledger answered 503", "Could not load the stats: the ledger answered 4011",
      "Could not load the stats: The Internet connection appears to be offline.",
    ] {
      XCTAssertEqual(DrillPairingHint.explained(message), message)
    }
  }

  /// Story 571 (#1356): while the phone needs pairing, Stats says where a code comes from.
  func testWhilePairingIsNeededItSaysWhereALinkComesFrom() {
    let said = DrillPairingHint.pairingMessage("Not paired. Ask Larry to pair this device.", needsPairing: true)
    XCTAssertEqual(
      said, "Not paired. Ask Larry to pair this device. He sends a pair link in chat when asked; it lasts 10 minutes.")
  }

  func testAPairedPhoneSaysOnlyItsPairing() {
    XCTAssertEqual(
      DrillPairingHint.pairingMessage("Paired as Igor's iPhone until Dec 8", needsPairing: false),
      "Paired as Igor's iPhone until Dec 8")
  }
}
