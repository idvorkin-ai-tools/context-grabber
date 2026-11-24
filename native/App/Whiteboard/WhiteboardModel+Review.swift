//  Reviewing each writing session (spec 2026-11-23-board-interaction-review-design.md; stories 1237–1249, bead
//  context-grabber-8ao5.2). The board's own log events feed `BoardReviewRecorder` as they are written, so the record
//  holds exactly what a pulled log would. Five minutes after a step of his with none since, or on close, `BoardReview`
//  runs off the main actor; the board shows a quiet note only when there is something to look at,
//  the review's words go to Larry with the next picture, and the record and report stay on this device for 14 days.

import ContextCore
import Foundation
import SwiftUI

extension WhiteboardModel {
  /// Five minutes, or the launch hook's seconds on the simulator.
  static var reviewIdle: Duration {
    LaunchHooks.current.whiteboard.reviewIdle.map { .seconds($0) } ?? .milliseconds(Int(BoardReviewRecorder.idle))
  }

  /// The launch hook's stand-in finding goes into the first session of the launch only.
  static var reviewFindingMade = false

  static var unixMsNow: Double { Date().timeIntervalSince1970 * 1000 }

  /// The board opened: its events start feeding the record, from the board as it is (story 1237); a session the app's
  /// closing cut short is reviewed now, a review that finished after the board closed shows now (story 1238), and
  /// records past their 14 days go (story 1248).
  func reviewOpened() {
    guard editable else { return }
    reviewListen()
    if !reviewRecorder.hasBegun, let paper = canvas as? PaperBoardController, let ink = paper.reviewInk() {
      reviewRecorder.begin(ink: ink, folds: paper.reviewFolds())
    }
    let id = board.id
    let store = BoardReviewDisk(board: id)
    let log = log
    BoardReviewDisk.queue.async { [weak self] in
      BoardReviewDisk.prune()
      // Story 1295: a session already reviewed (the app closed between its review and the clear) isn't again.
      if let cut = store.takePending(), cut.hasIgorsStep {
        _ = Self.runReview(cut, why: "next_open", store: store, log: log)
      }
      guard let (record, report) = store.unseen() else { return }
      Task { @MainActor in self?.reviewShown(report, of: record) }
    }
  }

  /// The board's events start feeding the record; once, from the model's start, so the board opening is heard.
  func reviewListen() {
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
  }

  /// One of the board's events, as the log wrote it, with the board's strokes and folds as they are now when it can
  /// change them (bead context-grabber-8ao5.3: what changed is the real strokes' change).
  func reviewTook(type: String, t: Double, fields: [String: Any]) {
    // Story 1295: an event handed on before the board closed, arriving after, starts no session of its own.
    guard reviewTap != nil, let action = fields["action"] as? String, BoardReviewRecorder.reads.contains(action) else {
      return
    }
    let paper = canvas as? PaperBoardController
    let ink = BoardReviewRecorder.changesInk.contains(action) ? paper?.reviewInk() : nil
    let folds = BoardReviewRecorder.changesFolds(action, fields) ? paper?.reviewFolds() : nil
    let before = reviewRecorder.steps.count
    reviewRecorder.take(type: type, t: t, fields: fields, ink: ink, folds: folds)
    guard reviewRecorder.steps.count > before, let step = reviewRecorder.steps.last else { return }
    // Story 1243: his next stroke puts the last note away.
    if step.kind == "ink", step.by == "pencil" { review.noteDone() }
    if LaunchHooks.current.whiteboard.reviewFinding, step.kind == "ink", !Self.reviewFindingMade {
      Self.reviewFindingMade = true
      reviewRecorder.take(
        type: "whiteboard", t: t + 1,
        fields: [
          "action": "paper_keep", "board": board.id, "tool_before": "com.apple.ink.pen #000000 2",
          "tool_after": "com.apple.ink.marker #ba39e6 6",
        ], ink: nil)
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
    guard let record = reviewRecorder.record, record.hasIgorsStep else { return }
    let since = reviewKeptAt.map { Date().timeIntervalSince($0) } ?? .infinity
    if since < 5 {
      guard reviewKeepTask == nil else { return }
      reviewKeepTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(5 - since))
        guard !Task.isCancelled, let self else { return }
        self.reviewKeepTask = nil
        self.keepPending()
      }
      return
    }
    reviewKeptAt = Date()
    let store = BoardReviewDisk(board: board.id)
    BoardReviewDisk.queue.async { store.keepPending(record) }
  }

  /// Reviews the session: `idle` and `close` end it (stories 1237, 1238; none on demand, story 1240). One
  /// with no step of his isn't reviewed (story 1239). The review needs nothing of the model: on close it finishes,
  /// logs and is kept after the board is gone, and the next open shows it.
  func reviewSession(why: String) {
    reviewIdleTask?.cancel()
    reviewIdleTask = nil
    reviewKeepTask?.cancel()
    reviewKeepTask = nil
    guard reviewRecorder.hasIgorsStep, let record = reviewRecorder.record else {
      let store = BoardReviewDisk(board: board.id)
      BoardReviewDisk.queue.async { store.clearPending() }
      return
    }
    reviewRecorder.nextSession()
    let store = BoardReviewDisk(board: board.id)
    let log = log
    let session = record.header.session
    BoardReviewDisk.queue.async { [weak self] in
      store.clearPending(session: session)
      let report = Self.runReview(record, why: why, store: store, log: log)
      // Closed, the board shows nothing now: its next open shows the review and sends Larry its words.
      guard why != "close" else { return }
      Task { @MainActor in self?.reviewShown(report, of: record) }
    }
  }

  /// The review itself, off the main actor, with only the record, the disk and the log: kept, marked unseen until a
  /// board shows it, and logged.
  nonisolated static func runReview(
    _ record: BoardSessionRecord, why: String, store: BoardReviewDisk, log: SessionLog
  ) -> BoardReview.Report {
    let started = Date()
    let report = BoardReview.run(record)
    let ms = Int(Date().timeIntervalSince(started) * 1000)
    store.keep(record, report)
    store.markUnseen(report.session)
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
        "action": "board_review", "board": record.header.board, "session": report.session, "why": why,
        "steps": report.steps, "findings": report.findings.count, "to_look_at": report.toLookAt, "counts": counts,
        "not_checked": report.checks.filter { $0.sight == .notChecked }.map(\.name),
        "approximate": report.checks.filter { $0.sight == .approximate }.map(\.name), "ms": ms,
      ])
    return report
  }

  /// A review finished: the note, and the words waiting for Larry's next picture.
  func reviewShown(_ report: BoardReview.Report, of record: BoardSessionRecord) {
    review.show(report, of: record)
    let store = BoardReviewDisk(board: board.id)
    BoardReviewDisk.queue.async { store.markSeen() }
    reviewToLarry()
  }

  /// Story 1247: the review's words, and his answers, ride with the board's next picture.
  func reviewToLarry() {
    guard let event = review.forLarry(t: Int64(Self.unixMsNow)) else { return }
    events.record(event)
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
