//  A failed whiteboard sync as session-log fields (#1002): which call threw, on which board, and every record's own
//  CloudKit error, so a "Batch Request Failed / Atomic failure" names the sibling that really failed. CloudKit's
//  errors arrive here as plain `NSError`s (their userInfo keys are CloudKit's documented ones), so this stays
//  platform-free and the host tests can hand it a fake CloudKit result.

import Foundation

/// The call a whiteboard sync was making when it failed.
public enum BoardSyncStep: String, Sendable {
  /// Making sure the boards' zone exists.
  case zone
  /// A board deleted here: its tombstone saved, its record removed.
  case delete
  /// A board drawn here: its record saved, any tombstone removed.
  case upload
  /// Listing every board in iCloud.
  case list
  /// Fetching boards' drawings after the list; each failure is also logged with its board where it happens.
  case download
}

/// What a whiteboard sync knew when it failed, turned into the `whiteboard_sync` event's fields.
public struct BoardSyncFailure {
  public var why: String
  public var step: BoardSyncStep
  /// The board the step was writing, for an upload or a delete.
  public var board: String?
  /// That board's strokes, for an upload.
  public var strokes: Int?
  /// How many boards were waiting to go up when the sync began.
  public var pending: Int
  public var firstOfLaunch: Bool
  /// What was thrown.
  public var error: Error
  /// The saved record's own error, and the removed record's, from the write's per-record results.
  public var saveError: Error?
  public var deleteError: Error?
  /// The zone's own result, which the sync goes on without.
  public var zoneError: Error?
  /// A record ID's name, for a partial failure's keys (CloudKit's `CKRecord.ID` in the app).
  public var recordName: (AnyHashable) -> String

  public init(
    why: String, step: BoardSyncStep, board: String? = nil, strokes: Int? = nil, pending: Int,
    firstOfLaunch: Bool, error: Error, saveError: Error? = nil, deleteError: Error? = nil, zoneError: Error? = nil,
    recordName: @escaping (AnyHashable) -> String = { "\($0.base)" }
  ) {
    self.why = why
    self.step = step
    self.board = board
    self.strokes = strokes
    self.pending = pending
    self.firstOfLaunch = firstOfLaunch
    self.error = error
    self.saveError = saveError
    self.deleteError = deleteError
    self.zoneError = zoneError
    self.recordName = recordName
  }

  public var fields: [String: Any] {
    var out: [String: Any] = [
      "ok": false, "why": why, "step": step.rawValue, "pending": pending, "first_of_launch": firstOfLaunch,
      "message": "\(error)", "code": (error as NSError).code,
    ]
    if let board, step == .delete || step == .upload { out["board"] = board }
    if let strokes, step == .upload { out["strokes"] = strokes }
    if let saveError { out["save_error"] = CloudErrorFields.item(saveError) }
    if let deleteError { out["delete_error"] = CloudErrorFields.item(deleteError) }
    if let zoneError { out["zone_error"] = CloudErrorFields.item(zoneError) }
    let partial = [error, saveError, deleteError].compactMap { $0 }.compactMap {
      CloudErrorFields.partial($0, recordName: recordName)
    }
    if let first = partial.first { out["partial"] = first }
    if let retryAfter { out["retry_after"] = retryAfter }
    return out
  }

  /// How long CloudKit asked to wait before trying again, in seconds: the longest any of the errors names.
  public var retryAfter: Double? {
    [error, saveError, deleteError].compactMap { $0 }.compactMap(CloudErrorFields.retryAfter).max()
  }
}

/// When a failed whiteboard sync tries again by itself (#1002): 15 s after the first failure, twice as long after each
/// failure in a row, at most five minutes, and never sooner than CloudKit asked. After eight tries in a row it stops
/// and waits for the next sync something else starts. A sync that gets through starts over.
public struct BoardSyncRetry: Sendable {
  public static let first: Double = 15
  public static let longest: Double = 300
  public static let tries = 8
  /// Failed syncs in a row.
  public private(set) var failures = 0

  public init() {}

  /// A sync failed: the wait before the next try, in seconds, or nil once the tries are spent.
  public mutating func failed(retryAfter: Double? = nil) -> Double? {
    failures += 1
    guard failures <= Self.tries else { return nil }
    let backoff = min(Self.longest, Self.first * pow(2, Double(failures - 1)))
    return max(backoff, retryAfter ?? 0)
  }

  public mutating func succeeded() { failures = 0 }
}

/// One CloudKit error as log fields.
public enum CloudErrorFields {
  /// CloudKit's userInfo keys: `CKErrorRetryAfterKey`, `CKPartialErrorsByItemIDKey`, and the server's own message,
  /// which CloudKit prints as `server message = …`.
  static let retryKey = "CKRetryAfter"
  static let partialKey = "CKPartialErrors"
  static let serverKey = "ServerErrorDescription"
  static let cloudKitDomain = "CKErrorDomain"

  /// The code, the server's message when it gave one, the domain when it isn't CloudKit's, and the whole text.
  public static func item(_ error: Error) -> [String: Any] {
    let e = error as NSError
    var out: [String: Any] = ["code": e.code, "text": "\(error)"]
    if e.domain != cloudKitDomain { out["domain"] = e.domain }
    if let server = e.userInfo[serverKey] as? String { out["server"] = server }
    return out
  }

  /// How long CloudKit asked to wait before trying again, in seconds.
  public static func retryAfter(_ error: Error) -> Double? {
    let value = (error as NSError).userInfo[retryKey]
    return (value as? Double) ?? (value as? NSNumber)?.doubleValue
  }

  /// A partial failure's per-record errors, by record name; nil when the error carries none.
  public static func partial(_ error: Error, recordName: (AnyHashable) -> String) -> [String: Any]? {
    guard let byID = (error as NSError).userInfo[partialKey] as? [AnyHashable: Any], !byID.isEmpty else { return nil }
    var out: [String: Any] = [:]
    for (id, value) in byID {
      guard let itemError = value as? Error else { continue }
      out[recordName(id)] = item(itemError)
    }
    return out.isEmpty ? nil : out
  }
}
