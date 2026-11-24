//  Where a board's session records and reviews stay (spec 2026-11-23-board-interaction-review-design.md; stories 1238,
//  1248, 1295): this device's Application Support, never iCloud. Ported from the app so the host can test it.

import Foundation

/// A board's records and reports on this device, for 14 days (story 1248).
public struct BoardReviewDisk: Sendable {
  public static let keepDays: Double = 14
  /// Every read and write of the records, one after another: a clear always lands after the writes before it.
  public static let queue = DispatchQueue(label: "board-reviews", qos: .utility)
  public let board: String
  public let root: URL

  public static var defaultRoot: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("board-reviews", isDirectory: true)
  }

  public init(board: String, root: URL = BoardReviewDisk.defaultRoot) {
    self.board = board
    self.root = root
  }

  public var folder: URL { root.appendingPathComponent(board, isDirectory: true) }
  public var pendingURL: URL { folder.appendingPathComponent("pending.jsonl") }
  public var unseenURL: URL { folder.appendingPathComponent("unseen.txt") }

  private func ready() {
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  private func recordURL(_ session: String) -> URL { folder.appendingPathComponent("\(session).jsonl") }

  /// Whether this session's review is already kept (story 1295: a session is reviewed once).
  public func reviewed(_ session: String) -> Bool {
    FileManager.default.fileExists(atPath: recordURL(session).path)
  }

  /// The session so far, so one the app's closing cuts short is reviewed on the next open; never a session already
  /// reviewed, so a write that was on its way when the board closed can't bring it back (story 1295).
  public func keepPending(_ record: BoardSessionRecord) {
    guard !reviewed(record.header.session) else { return }
    ready()
    try? record.jsonl().write(to: pendingURL, options: .atomic)
  }

  public func pending() -> BoardSessionRecord? {
    guard let data = try? Data(contentsOf: pendingURL) else { return nil }
    return try? BoardSessionRecord(jsonl: data)
  }

  /// The pending session for the next open to review, cleared as it is taken; nil when there is none, or when it
  /// was reviewed after all (story 1295).
  public func takePending() -> BoardSessionRecord? {
    let cut = pending()
    clearPending()
    guard let cut, !reviewed(cut.header.session) else { return nil }
    return cut
  }

  public func clearPending() { try? FileManager.default.removeItem(at: pendingURL) }

  /// Clears the pending record only when it is this session's (or can't be read): the next session's stays.
  public func clearPending(session: String) {
    if let kept = pending(), kept.header.session != session { return }
    clearPending()
  }

  /// A finished review no board has shown yet: its session's name.
  public func markUnseen(_ session: String) {
    ready()
    try? Data(session.utf8).write(to: unseenURL, options: .atomic)
  }

  public func markSeen() { try? FileManager.default.removeItem(at: unseenURL) }

  /// The session whose review no board has shown yet.
  public var unseenSession: String? { try? String(contentsOf: unseenURL, encoding: .utf8) }

  /// The review no board has shown yet, with its record.
  public func unseen() -> (BoardSessionRecord, BoardReview.Report)? {
    guard let name = unseenSession, let data = try? Data(contentsOf: recordURL(name)),
      let record = try? BoardSessionRecord(jsonl: data)
    else { return nil }
    return (record, BoardReview.run(record))
  }

  public func keep(_ record: BoardSessionRecord, _ report: BoardReview.Report) {
    ready()
    let name = record.header.session
    try? record.jsonl().write(to: recordURL(name), options: .atomic)
    try? report.json().write(to: folder.appendingPathComponent("\(name).report.json"), options: .atomic)
  }

  /// Everything older than 14 days goes, and a board's folder once it is empty.
  public static func prune(now: Date = Date(), root: URL = BoardReviewDisk.defaultRoot) {
    let fm = FileManager.default
    guard let boards = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
    for folder in boards {
      let files =
        (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
      for file in files {
        let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
        if now.timeIntervalSince(date) > keepDays * 86400 { try? fm.removeItem(at: file) }
      }
      if (try? fm.contentsOfDirectory(atPath: folder.path))?.isEmpty == true { try? fm.removeItem(at: folder) }
    }
  }

  /// The board was deleted: its records go with it (story 1248).
  public static func forget(board: String, root: URL = BoardReviewDisk.defaultRoot) {
    let folder = BoardReviewDisk(board: board, root: root).folder
    queue.async { try? FileManager.default.removeItem(at: folder) }
  }
}
