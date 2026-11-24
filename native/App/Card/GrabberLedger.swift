//  Story 220: Grabber Native's one practice-ledger client (ThinkACardUI's `DrillLedger`), its own and not the
//  trainer app's: the outbox in Application Support, the URL in the standard defaults, the key in this app's Keychain
//  item, and the session log for what each send did.
//  Story 238: while the phone is paired with Larry's box (the trainer's D19), the drill sends with the phone's own key
//  from the Keychain item every app of Igor's on the phone shares (BugKit's `PairedDeviceStore`), and *Stats* pairs
//  from a pasted link or a typed code (the trainer's story 074). The pasted URL and key wait under *Advanced*.

import BugKit
import ContextCore
import Foundation
import ThinkACardCore
import ThinkACardUI
import UIKit

@MainActor
enum GrabberLedger {
  private static var made: DrillLedger?

  /// The shared pairing item. A Mac build lacks the entitlement, and an unsigned one has no team prefix, so each
  /// keeps the item in its own group.
  private static let pairedDevices: KeychainPairedDeviceStore = {
    #if targetEnvironment(macCatalyst)
      KeychainPairedDeviceStore(accessGroup: nil)
    #else
      KeychainPairedDeviceStore(
        accessGroup: (Bundle.main.object(forInfoDictionaryKey: "PairedDeviceAccessGroup") as? String)
          .flatMap { $0 == "com.idvorkin.paired-device" ? nil : $0 })
    #endif
  }()

  /// The one host a pairing may name: Larry's box, the Cockpit's host.
  static let box = URL(string: CockpitPage.url)?.host ?? ""
  /// Where a code is redeemed: the keyring on the box, which serves pairing on its own port.
  static let pairingHost = "https://\(box):8456"

  /// One for the launch, made on the first drill: two clients would race on the one outbox file.
  static func shared(log: SessionLog) -> DrillLedger {
    if let made { return made }
    let ledger = DrillLedger(
      outbox: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ledger-outbox.json"),
      defaults: .standard, keys: KeychainLedgerKey(service: "com.idvorkin.grabbernative.ledger"), log: log,
      pairing: { pairing(refused: $0) }, pair: { await pair(code: $0, log: log) })
    made = ledger
    return ledger
  }

  /// The pairing in the drill's terms: the paired key and ledger URL, and BugKit's words for the status.
  static func pairing(refused: Bool) -> LedgerPairing {
    let device = pairedDevices.load()
    let status = PairingStatus(device: device, refused: refused)
    var config = LedgerConfig.off
    if let device, let ledger = device.services["ledger"] {
      config = LedgerConfig(url: ledger.absoluteString, key: device.key)
    }
    // #1356: beside *Pair with code*, where a code comes from.
    let message = DrillPairingHint.pairingMessage(status.message(), needsPairing: status.needsPairing)
    return LedgerPairing(config: config, message: message, needsPairing: status.needsPairing)
  }

  /// Story 238: a code from *Stats*, redeemed at the box's pairing host, never a host that was pasted. The code
  /// and the key are never logged.
  static func pair(code: String, log: SessionLog) async -> LedgerPairOutcome {
    var parts = URLComponents()
    parts.scheme = "grabber"
    parts.host = "pair"
    parts.queryItems = [URLQueryItem(name: "code", value: code), URLQueryItem(name: "host", value: pairingHost)]
    guard let url = parts.url, let link = PairingLink(url, box: box) else {
      log.event("pairing", ["how": "failed", "error": "pairing host \(pairingHost) is not on the box \(box)"])
      return .failed("This build's pairing host (\(pairingHost)) is not on the box (\(box)).")
    }
    let before = pairedDevices.load()
    let device = [
      "model": BugAppInfo.hardwareModel(), "os": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
      "app": "grabbernative", "build": BugAppInfo.fromMainBundle(device: "").buildLine,
    ]
    do {
      let paired = try await PairingClient().redeem(link, device: device, replacing: before?.deviceID)
      try pairedDevices.save(paired)
      log.event("pairing", ["how": "paired", "name": paired.name, "expires_at": paired.expiresAt.ISO8601Format()])
      await made?.paired()
      return .paired(PairingStatus(device: paired, refused: false).message())
    } catch let error as PairingError {
      log.event("pairing", ["how": "failed", "error": "\(error)"])
      return .failed(error.message)
    } catch {
      log.event("pairing", ["how": "failed", "error": "\(error)"])
      return .failed("Could not keep the pairing on this phone: \(error)")
    }
  }
}
