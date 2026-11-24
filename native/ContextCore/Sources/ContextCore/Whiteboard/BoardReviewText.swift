//  The words of a review, the same on every surface (spec 2026-11-23-board-interaction-review-design.md, *What Igor
//  sees* and *How Larry gets findings*; stories 1243, 1244, 1247): the note, a finding as copyable text, and the short
//  list that goes to Larry with the board's next picture.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardReviewText {
  static func verdict(_ v: BoardReview.Verdict) -> String {
    switch v {
    case .bug: return "bug"
    case .asDesigned: return "as designed"
    case .unclear: return "unclear"
    }
  }

  /// The board's corner note, or nil when there is nothing to look at and he didn't ask (*Decisions*, 6).
  public static func note(_ report: BoardReview.Report, asked: Bool) -> String? {
    let n = report.toLookAt
    if n > 0 { return "Reviewed · \(n) to look at" }
    return asked ? "Reviewed · clean" : nil
  }

  /// A finding as he copies it: the check, the verdict, the step, the evidence, the board, the session and the build.
  public static func copy(_ finding: BoardReview.Finding, of report: BoardReview.Report) -> String {
    var lines = [
      "Board review: check \(finding.check) \(finding.name), \(verdict(finding.verdict))",
      finding.summary,
      "step \(finding.step) at \(BoardReview.num(finding.t)): \(finding.kind) by \(finding.by)",
    ]
    if let story = finding.story { lines.append("rule: story \(story)") }
    lines += finding.evidence.map { "\($0.key): \($0.value)" }
    lines.append(
      "board \(report.board) · session \(report.session) · \(report.surface)"
        + (report.build.map { " · build \($0)" } ?? ""))
    return lines.joined(separator: "\n")
  }

  /// What goes to Larry: one line for a clean session; else the counts by check and verdict, then each bug or unclear
  /// finding as its copyable text.
  public static func larry(_ report: BoardReview.Report) -> String {
    let head = "Board review of session \(report.session) on \(report.surface), \(report.steps) steps"
    let seen = report.checks.filter { $0.sight != .checked }.map { "check \($0.check) \($0.sight.rawValue)" }
    let sight = seen.isEmpty ? "" : " (" + seen.joined(separator: ", ") + ")"
    guard !report.findings.isEmpty else { return head + ": clean" + sight }
    var lines = [head + sight + ":"]
    for c in report.checks where c.bug + c.asDesigned + c.unclear > 0 {
      lines.append("check \(c.check) \(c.name): \(c.bug) bug, \(c.unclear) unclear, \(c.asDesigned) as designed")
    }
    for f in report.findings where f.verdict != .asDesigned {
      lines.append("")
      lines.append(copy(f, of: report))
    }
    return lines.joined(separator: "\n")
  }
}
