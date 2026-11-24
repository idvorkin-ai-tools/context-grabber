//  What a board shows of its last review (spec 2026-11-23-board-interaction-review-design.md, *What Igor sees*; stories
//  1242–1246): the quiet note, which findings he answered, the words that go to Larry, and a step as the review saw it
//  for *Show me*. Pure; the app's note and list draw it.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardReviewShown: Equatable, Sendable {
  public enum Answer: String, Equatable, Sendable {
    case meant = "meant"
    case notMeant = "not_meant"
  }

  public private(set) var report: BoardReview.Report?
  public private(set) var record: BoardSessionRecord?
  /// He asked for it from the menu: a clean review then says so.
  public private(set) var asked = false
  /// The note went: he opened it, or wrote again.
  public private(set) var noteGone = false
  /// His answers to unclear findings, by the finding's key (`key(_:)`).
  public private(set) var answers: [String: Answer] = [:]
  /// Whether its words have gone to Larry yet.
  public private(set) var toLarry = false

  public init() {}

  public static func key(_ finding: BoardReview.Finding) -> String {
    "\(finding.check)|\(finding.step)|\(finding.ids.joined(separator: ","))"
  }

  /// A review finished: it replaces the last.
  public mutating func show(_ report: BoardReview.Report, of record: BoardSessionRecord, asked: Bool) {
    self.report = report
    self.record = record
    self.asked = asked
    noteGone = false
    answers = [:]
    toLarry = false
  }

  /// What the corner says, or nil (story 1242: a clean review he didn't ask for shows nothing).
  public var note: String? {
    guard !noteGone, let report else { return nil }
    let open = report.findings.filter { $0.verdict != .asDesigned && answers[Self.key($0)] == nil }.count
    if open > 0 { return "Reviewed · \(open) to look at" }
    return asked && report.toLookAt == 0 ? "Reviewed · clean" : nil
  }

  /// He opened the findings, or wrote again: the note goes (story 1243).
  public mutating func noteDone() { noteGone = true }

  /// Story 1246: his answer to an unclear finding.
  public mutating func answer(_ finding: BoardReview.Finding, _ answer: Answer) {
    answers[Self.key(finding)] = answer
    toLarry = false
  }

  /// The findings as the list shows them, newest first.
  public var findings: [BoardReview.Finding] { (report?.findings ?? []).reversed() }

  /// The most the event to Larry takes as sent: the Cockpit keeps each event under 8 KB (Larry, 2026-11-23).
  public static let larryBytes = 6000

  /// The event that goes to Larry with the board's next picture (story 1247), once: the review's words and his
  /// answers, cut short to whole lines so the event stays within `larryBytes`, saying how many lines went.
  public mutating func forLarry(t: Int64) -> BoardEvent? {
    guard !toLarry, let report else { return nil }
    toLarry = true
    var text = BoardReviewText.larry(report)
    for finding in report.findings {
      guard let answer = answers[Self.key(finding)] else { continue }
      text +=
        "\nIgor on step \(finding.step) (check \(finding.check)): "
        + (answer == .meant ? "I meant that" : "not what I meant")
    }
    let (words, cut) = Self.cut(text, to: Self.larryBytes - 200)
    return .review(text: words, cut: cut, t: t)
  }

  /// `text` within `bytes` once escaped as a JSON string, whole lines, ending with a line that says it was cut; and
  /// how many lines went, nil when none did.
  public static func cut(_ text: String, to bytes: Int) -> (text: String, cut: Int?) {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let sizes = lines.map { escaped($0) + 2 }
    guard sizes.reduce(0, +) > bytes else { return (text, nil) }
    var size = 0
    var kept = 0
    while kept < lines.count, size + sizes[kept] <= bytes - 120 {
      size += sizes[kept]
      kept += 1
    }
    let gone = lines.count - kept
    let closing: Substring = "(cut short: \(gone) more lines are in the copy on the iPad)"
    return ((lines[..<kept] + [closing]).joined(separator: "\n"), gone)
  }

  /// A line's size in a JSON string at its most escaped: a quote, backslash, slash or control character as two
  /// bytes, or six as `\u00XX`.
  private static func escaped(_ line: Substring) -> Int {
    line.unicodeScalars.reduce(0) { size, c in
      switch c {
      case "\"", "\\", "/", "\n", "\r", "\t": return size + 2
      case _ where c.value < 0x20: return size + 6
      default: return size + UTF8.width(c)
      }
    }
  }
}

extension BoardReview {
  /// One unit of ink as *Show me* draws it.
  public struct Drawn: Equatable, Sendable {
    public var id: String
    public var owner: String
    public var box: BoardSessionRecord.Box
    public var hidden: Bool
  }

  /// The board just before a step and once it settled, as the review replayed it (story 1245): erased ink is in the
  /// before as it was.
  public static func around(_ record: BoardSessionRecord, step: Int) -> (before: [Drawn], after: [Drawn]) {
    let pass = Pass(record)
    guard step >= 0, step < record.steps.count else { return ([], []) }
    let group = pass.groups.first { $0.first == step } ?? [step]
    func drawn(_ state: State) -> [Drawn] {
      state.units.keys.sorted().compactMap { id in
        state.units[id].map { Drawn(id: id, owner: $0.owner, box: $0.box, hidden: $0.hidden) }
      }
    }
    return (drawn(pass.states[step]), drawn(pass.settled(group)))
  }
}

extension BoardSessionRecord {
  /// The record as JSONL, as it is kept on the device and read back.
  public func jsonl() -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var out = Data()
    for part in [try? encoder.encode(header)] + steps.map({ try? encoder.encode($0) }) {
      guard let part else { continue }
      out.append(part)
      out.append(0x0A)
    }
    return out
  }
}
