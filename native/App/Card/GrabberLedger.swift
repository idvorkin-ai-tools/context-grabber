//  Story 220: Grabber Native's one practice-ledger client (ThinkACardUI's `DrillLedger`), its own and not the
//  trainer app's: the outbox in Application Support, the URL in the standard defaults, the key in this app's Keychain
//  item, and the session log for what each send did. Igor pastes the URL and key once in the drill's Stats.

import Foundation
import ThinkACardUI

@MainActor
enum GrabberLedger {
  private static var made: DrillLedger?

  /// One for the launch, made on the first drill: two clients would race on the one outbox file.
  static func shared(log: SessionLog) -> DrillLedger {
    if let made { return made }
    let ledger = DrillLedger(
      outbox: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ledger-outbox.json"),
      defaults: .standard, keys: KeychainLedgerKey(service: "com.idvorkin.grabbernative.ledger"), log: log)
    made = ledger
    return ledger
  }
}
