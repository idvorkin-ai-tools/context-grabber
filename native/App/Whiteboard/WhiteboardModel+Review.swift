//  Reviewing each writing session (spec 2026-11-23-board-interaction-review-design.md; stories 1237–1249, bead
//  context-grabber-8ao5.2). The board's own log events feed `BoardReviewRecorder` as they are written, so the record
//  holds exactly what a pulled log would. Five minutes after a step of his with none since, on close, or from the Board
//  menu, `BoardReview` runs off the main actor; the board shows a quiet note only when there is something to look at,
//  the review's words go to Larry with the next picture, and the record and report stay on this device for 14 days.

import ContextCore
import Foundation
import SwiftUI

extension WhiteboardModel {
  /// Five minutes, or the launch hook's seconds on the simulator.
  static var reviewIdle: Duration {
    LaunchHooks.current.whiteboard.reviewIdle.map { .seconds($0) } ?? .milliseconds(Int(BoardReviewRecorder.idle))
  }

  static var unixMsNow: Double { Date().timeIntervalSince1970 * 1000 }

  /// The board opened: its events start feeding the record, a session the app's closing cut short is reviewed now
  /// (story 1238), and records past their 14 days go (story 1248).
  func reviewOpened() {
    guard editable, reviewTap == nil else { return }
    let id = board.id
    reviewTap = log.listen { [weak self] type, fields in
      guard fields["board"] as? String == id else { return }
      let t = Self.unixMsNow
      if Thread.isMainThread {
        MainActor.assumeIsolated { self?.reviewTook(type: type, t: t, fields: fields) }
      } else {
        nonisolated(unsafe) let fields = fields
        DispatchQueue.main.async { self?.reviewTook(type: type, t: t, fields: fields) }
      }
    }
    let store = BoardReviewDisk(board: id)
    Task.detached(priority: .utility) { [weak self] in
      BoardReviewDisk.prune()
      guard let cut = store.pending() else { return }
      let report = BoardReview.run(cut)
      store.keep(cut, report)
      store.clearPending()
      await self?.reviewed(report, of: cut, why: "next_open", ms: 0)
    }
  }

  /// One of the board's events, as the log wrote it.
  func reviewTook(type: String, t: Double, fields: [String: Any]) {
    let before = reviewRecorder.steps.count
    reviewRecorder.take(type: type, t: t, fields: fields)
    guard reviewRecorder.steps.count > before, let step = reviewRecorder.steps.last else { return }
    // Story 1243: his next stroke puts the last note away.
    if step.kind == "ink" { review.noteDone() }
    if LaunchHooks.current.whiteboard.reviewFinding, step.kind == "ink", before == 0 {
      reviewRecorder.take(
        type: "whiteboard", t: t + 1,
        fields: [
          "action": "paper_keep", "board": board.id, "ink": [60, 600, 120, 30], "strokes": 3,
          "tool_before": "com.apple.ink.pen #000000 2", "tool_after": "com.apple.ink.marker #ba39e6 6",
        ])
    }
    keepPending()
    reviewIdleTask?.cancel()
    reviewIdleTask = Task { [weak self] in
      try? await Task.sleep(for: Self.reviewIdle)
      guard !Task.isCancelled else { return }
      self?.reviewSession(why: "idle")
    }
  }

  /// The session so far, every few seconds at most, so one the app's closing cuts short is reviewed on the next open.
  private func keepPending() {
    if let at = reviewKeptAt, Date().timeIntervalSince(at) < 5 { return }
    reviewKeptAt = Date()
    guard let record = reviewRecorder.record else { return }
    let store = BoardReviewDisk(board: board.id)
    Task.detached(priority: .utility) { store.keepPending(record) }
  }

  /// Reviews the session: `idle` and `close` end it (stories 1237, 1238), `asked` reviews it so far (story 1240). One
  /// with no step of his isn't reviewed (story 1239).
  func reviewSession(why: String) {
    reviewIdleTask?.cancel()
    reviewIdleTask = nil
    let asked = why == "asked"
    guard asked || reviewRecorder.hasIgorsStep, let record = reviewRecorder.record else {
      if asked { review = BoardReviewShown() }
      return
    }
    if !asked { reviewRecorder.nextSession() }
    let store = BoardReviewDisk(board: board.id)
    Task.detached(priority: .utility) { [weak self] in
      let started = Date()
      let report = BoardReview.run(record)
      let ms = Int(Date().timeIntervalSince(started) * 1000)
      store.keep(record, report)
      if !asked { store.clearPending() }
      await self?.reviewed(report, of: record, why: why, ms: ms)
    }
  }

  /// A review finished: the note, the log line, and the words waiting for Larry's next picture.
  func reviewed(_ report: BoardReview.Report, of record: BoardSessionRecord, why: String, ms: Int) {
    review.show(report, of: record, asked: why == "asked")
    var counts: [String: Int] = [:]
    for check in report.checks {
      for (verdict, n) in [("bug", check.bug), ("as_designed", check.asDesigned), ("unclear", check.unclear)]
      where n > 0 {
        counts["\(check.name).\(verdict)"] = n
      }
    }
    log.event(
      "whiteboard",
      [
        "action": "board_review", "board": board.id, "session": report.session, "why": why, "steps": report.steps,
        "findings": report.findings.count, "to_look_at": report.toLookAt, "counts": counts,
        "not_checked": report.checks.filter { $0.sight == .notChecked }.map(\.name),
        "approximate": report.checks.filter { $0.sight == .approximate }.map(\.name), "ms": ms,
      ])
    reviewToLarry()
  }

  /// Story 1247: the review's words, and his answers, ride with the board's next picture.
  func reviewToLarry() {
    guard let text = review.forLarry() else { return }
    events.record(.review(text: text, t: Int64(Self.unixMsNow)))
  }

  /// Story 1243: he opened the findings.
  func openReview() {
    review.noteDone()
    reviewListOpen = true
  }

  /// Story 1246: his answer to an unclear finding.
  func answerReview(_ finding: BoardReview.Finding, meant: Bool) {
    review.answer(finding, meant ? .meant : .notMeant)
    log.event(
      "whiteboard",
      [
        "action": "board_review_answer", "board": board.id, "session": review.report?.session ?? "",
        "check": finding.name, "step": finding.step, "answer": meant ? "meant" : "not_meant",
      ])
    reviewToLarry()
  }

  /// The board closed: a session with a step of his is reviewed (story 1238), and its events stop feeding the record.
  func reviewClosed() {
    if let tap = reviewTap { log.stopListening(tap) }
    reviewTap = nil
    reviewSession(why: "close")
  }
}

/// Where a board's records and reports stay: this device's Application Support, never iCloud (story 1248).
struct BoardReviewDisk: Sendable {
  static let keepDays: Double = 14
  let board: String

  static var root: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("board-reviews", isDirectory: true)
  }

  var folder: URL { Self.root.appendingPathComponent(board, isDirectory: true) }
  var pendingURL: URL { folder.appendingPathComponent("pending.jsonl") }

  private func ready() {
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  func keepPending(_ record: BoardSessionRecord) {
    ready()
    try? record.jsonl().write(to: pendingURL, options: .atomic)
  }

  func pending() -> BoardSessionRecord? {
    guard let data = try? Data(contentsOf: pendingURL) else { return nil }
    return try? BoardSessionRecord(jsonl: data)
  }

  func clearPending() { try? FileManager.default.removeItem(at: pendingURL) }

  func keep(_ record: BoardSessionRecord, _ report: BoardReview.Report) {
    ready()
    let name = record.header.session
    try? record.jsonl().write(to: folder.appendingPathComponent("\(name).jsonl"), options: .atomic)
    try? report.json().write(to: folder.appendingPathComponent("\(name).report.json"), options: .atomic)
  }

  /// Everything older than 14 days goes, and a board's folder once it is empty.
  static func prune(now: Date = Date()) {
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
  static func forget(board: String) {
    try? FileManager.default.removeItem(at: BoardReviewDisk(board: board).folder)
  }
}
