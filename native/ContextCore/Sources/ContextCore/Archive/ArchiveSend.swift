//  context-grabber-3il, story 262: everything the app collects goes to the Cockpit's archive, `POST /archive` (its
//  story 124), in batches that each carry a stream, this device, a batch id and records with a guid each. The
//  Cockpit keeps one row per (stream, guid), so a batch sent twice, an overlapping page or a re-imported point
//  changes nothing there, and the delta stamp on this side (ArchiveCursorStore) moves only after a 2xx.

import Foundation

/// One upload: a page of one stream's records.
public struct ArchiveBatch {
  public var stream: String
  public var deviceId: String
  public var batchId: String
  /// Each a JSON object with its `guid`; what else it carries is the stream's own.
  public var records: [[String: Any]]

  public init(
    stream: String, deviceId: String, batchId: String = UUID().uuidString.lowercased(), records: [[String: Any]]
  ) {
    self.stream = stream
    self.deviceId = deviceId
    self.batchId = batchId
    self.records = records
  }
}

public enum ArchiveStream {
  /// The trail's points, keyed by content (`ArchiveGUID.point`).
  public static let points = "location.points"
  /// One stream per Health sample type, named by Health's own identifier (`HKQuantityTypeIdentifierStepCount`).
  public static func health(_ identifier: String) -> String { "health." + identifier }
}

/// What a record is called in the archive: the Cockpit takes 1-128 characters of `[A-Za-z0-9_.:+-]`.
public enum ArchiveGUID {
  /// A Health sample: its own uuid.
  public static func sample(_ uuid: UUID) -> String { uuid.uuidString.lowercased() }
  /// A Health deletion, in the sample's stream so the tombstone sits beside what it ends.
  public static func deleted(_ uuid: UUID) -> String { "del:" + sample(uuid) }
  /// A point's content: the three fields the import dedupes on (LocationStore.importDatabase), so a point that
  /// came back by import, or was uploaded before, is the same record. A Double prints exactly (shortest round
  /// trip), so two equal points always spell the same.
  public static func point(_ p: LocationPoint) -> String { "p:\(p.timestamp):\(p.latitude):\(p.longitude)" }
}

public enum ArchiveSend {
  /// Records per batch: the Cockpit takes 5000; a page this size keeps a background task's minute in reach.
  public static let pageSize = 1000

  public enum Outcome: Equatable, Sendable {
    /// Every record is in the archive now, `inserted` new to it and `duplicate` already there.
    case taken(inserted: Int, duplicate: Int)
    /// The batch itself is wrong (4xx): the cursor stays, and the log says why, until the code changes.
    case refused(status: Int, reason: String)
    /// The Cockpit is down or unreachable (5xx, no answer): the same page goes again next run.
    case retry(reason: String)
  }

  public static func request(_ batch: ArchiveBatch, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("archive"))
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: body(batch), options: [.sortedKeys])
    return request
  }

  static func body(_ batch: ArchiveBatch) -> [String: Any] {
    ["stream": batch.stream, "device_id": batch.deviceId, "batch_id": batch.batchId, "records": batch.records]
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard let status else { return .retry(reason: error ?? "no answer") }
    if status == 200, json?["ok"] as? Bool == true {
      return .taken(inserted: json?["inserted"] as? Int ?? 0, duplicate: json?["duplicate"] as? Int ?? 0)
    }
    let reason = (json?["reason"] as? String) ?? (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }
}
