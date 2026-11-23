//  The review of one writing session (spec 2026-11-23-board-interaction-review-design.md, *The checks*; stories
//  1241, 1250–1262): replay the record's steps on the board as it began, ask the board's rules what each step should
//  have done, and compare with what the record says it did. Each check lives in its own `BoardReview+…` file. Pure and
//  deterministic: the same record gives the same report on the iPad, the Mac and the Cockpit's wasm, and nothing it is
//  given is changed.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardReview {
  /// A move or resize under this many points is no move, and boxes must overlap by more than it on both axes to meet
  /// (spec, *Positions compare with a tolerance*). Far above the 32-bit wasm's arithmetic noise.
  public static let tolerance = 0.5

  /// The nine checks by number, as the spec numbers them.
  public static let names: [Int: String] = [
    1: "inside_fold", 2: "under_ink", 3: "moved_without_aim", 4: "owners_together", 5: "fold_swallowed",
    6: "undo_restored", 7: "selection_lost", 8: "pen_changed", 9: "kept_drawn",
  ]

  public enum Verdict: String, Sendable, Codable {
    case bug
    case asDesigned = "as_designed"
    case unclear
  }

  /// How well the surface could see what a check needs.
  public enum Sight: String, Sendable, Codable {
    case checked
    case approximate
    case notChecked = "not_checked"
  }

  public struct Evidence: Equatable, Sendable, Encodable {
    public var key: String
    public var value: String

    public init(_ key: String, _ value: String) {
      self.key = key
      self.value = value
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.unkeyedContainer()
      try c.encode(key)
      try c.encode(value)
    }
  }

  public struct Finding: Equatable, Sendable, Encodable {
    public var check: Int
    public var name: String
    public var verdict: Verdict
    /// The step's index in the record, from 0.
    public var step: Int
    public var t: Double
    public var kind: String
    public var by: String
    /// The story whose rule the finding is judged by.
    public var story: Int?
    public var ids: [String]
    /// One line of what happened, as the findings list shows it.
    public var summary: String
    public var evidence: [Evidence]
  }

  public struct CheckResult: Equatable, Sendable, Encodable {
    public var check: Int
    public var name: String
    public var sight: Sight
    public var bug: Int
    public var asDesigned: Int
    public var unclear: Int

    enum CodingKeys: String, CodingKey {
      case check, name, sight, bug, unclear
      case asDesigned = "as_designed"
    }
  }

  public struct Report: Equatable, Sendable, Encodable {
    public var record: Int
    public var board: String
    public var session: String
    public var surface: String
    public var build: String?
    public var steps: Int
    public var checks: [CheckResult]
    public var findings: [Finding]

    /// What the board's note counts: bugs and unclear findings, never *as designed*.
    public var toLookAt: Int { findings.filter { $0.verdict != .asDesigned }.count }

    enum CodingKeys: String, CodingKey {
      case record, board, session, surface, build, steps, checks, findings
      case toLookAt = "to_look_at"
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(record, forKey: .record)
      try c.encode(board, forKey: .board)
      try c.encode(session, forKey: .session)
      try c.encode(surface, forKey: .surface)
      try c.encodeIfPresent(build, forKey: .build)
      try c.encode(steps, forKey: .steps)
      try c.encode(checks, forKey: .checks)
      try c.encode(findings, forKey: .findings)
      try c.encode(toLookAt, forKey: .toLookAt)
    }

    /// The report as JSON, keys sorted, as `bw_review` replies and the goldens hold it.
    public func json() -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return (try? encoder.encode(self)) ?? Data(#"{"error":"no JSON"}"#.utf8)
    }
  }

  /// Reviews a session: every check, in order, and what each could see.
  public static func run(_ record: BoardSessionRecord) -> Report {
    let pass = Pass(record)
    var all: [Finding] = []
    all += insideFold(pass)
    all += underInk(pass)
    all += movedWithoutAim(pass)
    all += ownersTogether(pass)
    all += foldSwallowed(pass)
    all += undoRestored(pass)
    all += selectionLost(pass)
    all += penChanged(pass)
    all += keptDrawn(pass)
    var seen = Set<String>()
    let findings = all.filter { seen.insert("\($0.check)|\($0.step)|\($0.ids.joined(separator: ","))").inserted }
      .sorted { ($0.step, $0.check) < ($1.step, $1.check) }
    let checks = (1...9).map { n -> CheckResult in
      let mine = findings.filter { $0.check == n }
      return CheckResult(
        check: n, name: names[n] ?? "", sight: sight(n, record.header.observes),
        bug: mine.filter { $0.verdict == .bug }.count, asDesigned: mine.filter { $0.verdict == .asDesigned }.count,
        unclear: mine.filter { $0.verdict == .unclear }.count)
    }
    let h = record.header
    return Report(
      record: h.record, board: h.board, session: h.session, surface: h.surface, build: h.build,
      steps: record.steps.count, checks: checks, findings: findings)
  }

  /// Checks 1–6 read the record alone; 7–9 need the surface's eyes (spec, *The checks*; *Larry's answer*).
  static func sight(_ check: Int, _ observes: BoardSessionRecord.Observes?) -> Sight {
    let said: String?
    switch check {
    case 7: said = observes?.selection
    case 8: said = observes?.pen
    case 9: said = observes?.kept
    default: return .checked
    }
    switch said {
    case "yes": return .checked
    case "approx": return .approximate
    default: return .notChecked
    }
  }

  // MARK: The board replayed

  typealias Box = BoardSessionRecord.Box

  struct Unit: Equatable {
    var owner: String
    var box: Box
    var hidden: Bool
    var header: Bool
    var n: Int
    /// When it was added in this session; nil for ink the session began with.
    var added: Double?
  }

  struct FoldState: Equatable {
    var held: Set<String>
    var folded: Bool
    /// When it was last folded in this session; nil for a fold the session began with.
    var at: Double?
  }

  struct State: Equatable {
    var units: [String: Unit] = [:]
    var folds: [String: FoldState] = [:]

    func showing(_ id: String) -> Bool { units[id].map { !$0.hidden } ?? false }
  }

  /// The record replayed: the board before each step (`states[i]`, and `states[steps.count]` at the end), and the
  /// steps grouped so a step and the owners-apart step that settles it are judged together.
  struct Pass {
    let record: BoardSessionRecord
    let states: [State]
    /// Each group's step indices: a step, then any `apart` steps that settle it.
    let groups: [[Int]]

    var steps: [BoardSessionRecord.Step] { record.steps }

    init(_ record: BoardSessionRecord) {
      self.record = record
      var state = State()
      for ink in record.header.ink {
        state.units[ink.id] = Unit(
          owner: ink.owner, box: ink.box, hidden: false, header: ink.header ?? false, n: ink.n ?? 1, added: nil)
      }
      for fold in record.header.folds ?? [] {
        let folded = fold.folded ?? true
        state.folds[fold.header] = FoldState(held: Set(fold.held), folded: folded, at: nil)
        if folded { for id in fold.held { state.units[id]?.hidden = true } }
      }
      var states = [state]
      var groups: [[Int]] = []
      for (i, step) in record.steps.enumerated() {
        state = Self.apply(step, to: state)
        states.append(state)
        // An owners-apart step settles the last step that changed ink, past selections that changed none.
        if step.kind == "apart",
          let g = groups.lastIndex(where: { !(record.steps[$0[0]].changes ?? []).isEmpty })
        {
          groups[g].append(i)
        } else {
          groups.append([i])
        }
      }
      self.states = states
      self.groups = groups
    }

    static func apply(_ step: BoardSessionRecord.Step, to state: State) -> State {
      var out = state
      for change in step.changes ?? [] {
        if change.after == nil, change.hidden == nil {
          out.units[change.id] = nil
          continue
        }
        if var unit = out.units[change.id] {
          if let after = change.after { unit.box = after }
          if let hidden = change.hidden { unit.hidden = hidden }
          out.units[change.id] = unit
        } else if let after = change.after {
          out.units[change.id] = Unit(
            owner: change.owner ?? "igor", box: after, hidden: change.hidden ?? false, header: change.header ?? false,
            n: change.n ?? 1, added: step.t)
        }
      }
      if let fold = step.fold {
        let folded = fold.folded ?? (step.kind != "unfold")
        let previous = out.folds[fold.header]
        out.folds[fold.header] = FoldState(
          held: Set(fold.held), folded: folded, at: folded && step.kind == "fold" ? step.t : previous?.at)
        for id in fold.held where step.changes?.contains(where: { $0.id == id && $0.hidden != nil }) != true {
          out.units[id]?.hidden = folded
        }
      }
      return out
    }

    /// The board once a group's steps are done.
    func settled(_ group: [Int]) -> State { states[(group.last ?? 0) + 1] }

    func finding(
      _ check: Int, _ verdict: Verdict, step i: Int, story: Int?, ids: [String], _ summary: String,
      _ evidence: [Evidence]
    ) -> Finding {
      let step = steps[i]
      return Finding(
        check: check, name: BoardReview.names[check] ?? "", verdict: verdict, step: i, t: step.t, kind: step.kind,
        by: step.by, story: story, ids: ids.sorted(), summary: summary,
        evidence: [Evidence("step", "\(i) \(step.kind) by \(step.by)")] + evidence)
    }
  }

  // MARK: Geometry with the tolerance

  static func moved(_ a: Box, _ b: Box) -> Bool {
    abs(a.x - b.x) > tolerance || abs(a.y - b.y) > tolerance || resized(a, b)
  }

  static func resized(_ a: Box, _ b: Box) -> Bool {
    abs(a.w - b.w) > tolerance || abs(a.h - b.h) > tolerance
  }

  /// Overlapping by more than the tolerance on both axes: boxes that only touch don't meet.
  static func meet(_ a: Box, _ b: Box) -> Bool {
    min(a.maxX, b.maxX) - max(a.x, b.x) > tolerance && min(a.maxY, b.maxY) - max(a.y, b.y) > tolerance
  }

  static func union(_ boxes: [Box]) -> Box? {
    guard let first = boxes.first else { return nil }
    var minX = first.x
    var minY = first.y
    var maxX = first.maxX
    var maxY = first.maxY
    for b in boxes.dropFirst() {
      minX = min(minX, b.x)
      minY = min(minY, b.y)
      maxX = max(maxX, b.maxX)
      maxY = max(maxY, b.maxY)
    }
    return Box(minX, minY, maxX - minX, maxY - minY)
  }

  /// A number as evidence shows it: one decimal at most, so the iPad and the 32-bit wasm print the same.
  static func num(_ v: Double) -> String {
    guard v.isFinite else { return "\(v)" }
    let tenths = Int64((v * 10).rounded())
    let sign = tenths < 0 ? "-" : ""
    let a = abs(tenths)
    return a % 10 == 0 ? "\(sign)\(a / 10)" : "\(sign)\(a / 10).\(a % 10)"
  }

  static func box(_ b: Box) -> String { "[\(num(b.x)), \(num(b.y)), \(num(b.w)), \(num(b.h))]" }

  /// Up to five ids, then how many more.
  static func list(_ ids: [String]) -> String {
    let sorted = ids.sorted()
    let head = sorted.prefix(5).joined(separator: ", ")
    return sorted.count > 5 ? "\(head) and \(sorted.count - 5) more" : head
  }

  /// "1 stroke", "2 strokes".
  static func many(_ n: Int) -> String { n == 1 ? "1 stroke" : "\(n) strokes" }

  static func strokes(_ ids: [String], in state: State) -> Int {
    ids.reduce(0) { $0 + (state.units[$1]?.n ?? 1) }
  }
}
