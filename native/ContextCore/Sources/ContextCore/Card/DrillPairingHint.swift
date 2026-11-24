//  What the drill's Stats says about pairing: where a pair link comes from (story 571, #1356), and what to do when the
//  ledger refuses the phone's key (story 227, #1371; spec
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

  /// Where a pair link comes from (story 571, #1356): Larry makes a one-time link on the box when asked, good for 10
  /// minutes. Nothing on the phone can make one.
  public static let whereALinkComesFrom = "He sends a pair link in chat when asked; it lasts 10 minutes."

  /// What Stats says above *Pair with code*: the pairing's status, and where a link comes from while one is needed.
  public static func pairingMessage(_ status: String, needsPairing: Bool) -> String {
    needsPairing ? status + " " + whereALinkComesFrom : status
  }

  /// The trainer says `the ledger answered <status>` (ThinkACardCore's `LedgerError`).
  private static func refusesKey(_ message: String) -> Bool {
    message.hasSuffix("the ledger answered 401") || message.hasSuffix("the ledger answered 403")
  }
}
