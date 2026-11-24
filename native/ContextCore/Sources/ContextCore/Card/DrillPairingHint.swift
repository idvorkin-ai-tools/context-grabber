//  What the drill's Stats says when the ledger refuses the phone's key (story 227, #1371; spec
//  docs/superpowers/specs/2026-10-04-swift-native-app-design.md, *Think of a card*). The trainer's message names only
//  the status; a 401 or 403 means the pairing with Larry's box has lapsed or was refused, and the way back is a new
//  pair link from Larry. Pure.

import Foundation

public enum DrillPairingHint {
  /// The trainer's failure message, with what to do when the ledger refused the key; any other failure as it was.
  public static func explained(_ message: String) -> String {
    guard refusesKey(message) else { return message }
    return message
      + ". The phone's pairing has lapsed or was refused: ask Larry in chat for a pair link and paste it into"
      + " Pair with code."
  }

  /// The trainer says `the ledger answered <status>` (ThinkACardCore's `LedgerError`).
  private static func refusesKey(_ message: String) -> Bool {
    message.hasSuffix("the ledger answered 401") || message.hasSuffix("the ledger answered 403")
  }
}
