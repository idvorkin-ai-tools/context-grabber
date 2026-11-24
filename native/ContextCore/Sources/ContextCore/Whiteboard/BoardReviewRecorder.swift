//  The iPad's record of a writing session (spec 2026-11-23-board-interaction-review-design.md, *What a session is, and
//  what is recorded*; stories 1237–1239, 1248; bead context-grabber-8ao5.3). What changed comes from the board's real
//  strokes: at each step the board hands over every stroke as it is now (its key, whose, its box, hidden or not) and its
//  folds, and the recorder diffs that against what it knew. The board's own log events say only what kind of step it
//  was, who started it and what it was aimed at, and what the surface saw (a selection held, the pen, a kept mark drawn).
//  A change the board makes right after a step (a drop's room, a keep's room) joins that step. Pure: the caller says
//  when, and hands over the strokes.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardReviewRecorder: Sendable {
  /// A session ends after this long with no step (*Decisions*, 1): five minutes, in ms.
  public static let idle: Double = 5 * 60 * 1000
  /// A change the board makes within this long of a step, of its own, belongs to that step.
  public static let settle: Double = 2000

  public typealias Box = BoardSessionRecord.Box

  /// One stroke as the board holds it now.
  public struct InkNow: Equatable, Sendable {
    public var owner: String
    public var box: Box
    public var hidden: Bool
    public var header: Bool

    public init(owner: String, box: Box, hidden: Bool = false, header: Bool = false) {
      self.owner = owner
      self.box = box
      self.hidden = hidden
      self.header = header
    }
  }

  /// A header's fold as the board holds it now: the strokes it holds hidden while folded.
  public struct FoldNow: Equatable, Sendable {
    public var header: String
    public var held: [String]
    public var folded: Bool

    public init(header: String, held: [String], folded: Bool) {
      self.header = header
      self.held = held.sorted()
      self.folded = folded
    }
  }

  public let board: String
  public let surface: String
  public let build: String?
  private var known: [String: InkNow] = [:]
  private var folds: [String: FoldNow] = [:]
  private var begun = false
  private var selected: [String] = []
  private var holdAt: (Double, Double)?
  /// The last step may still take the board's own change that follows it.
  private var open = false
  private var start: [BoardSessionRecord.Ink]?
  private var startFolds: [BoardSessionRecord.Fold]?
  public private(set) var steps: [BoardSessionRecord.Step] = []
  public private(set) var began: Double?
  public private(set) var last: Double?

  public init(board: String, surface: String = "ipad", build: String? = nil) {
    self.board = board
    self.surface = surface
    self.build = build
  }

  /// Whether the session has a step of Igor's own (story 1239): one only looked at is never reviewed.
  public var hasIgorsStep: Bool {
    steps.contains { ["pencil", "finger", "menu"].contains($0.by) && !["select", "deselect"].contains($0.kind) }
  }

  /// Due a review: a step of his, then `idle` with none.
  public func due(now: Double) -> Bool {
    guard hasIgorsStep, let last else { return false }
    return now - last >= Self.idle
  }

  /// Whether it has the board it is measured from yet.
  public var hasBegun: Bool { begun }

  /// The session so far, or nil with no step.
  public var record: BoardSessionRecord? {
    guard let began, !steps.isEmpty else { return nil }
    let header = BoardSessionRecord.Header(
      record: BoardSessionRecord.version, board: board, session: "\(board)-\(Int(began))", surface: surface,
      build: build, observes: .init(selection: "yes", pen: "yes", kept: "yes"), ink: start ?? [],
      folds: startFolds)
    return BoardSessionRecord(header: header, steps: steps)
  }

  /// The next session starts from the board as it is now.
  public mutating func nextSession() {
    steps = []
    start = nil
    startFolds = nil
    began = nil
    last = nil
    open = false
  }

  /// The board as it opened: what every step after is measured from.
  public mutating func begin(ink: [String: InkNow], folds: [FoldNow]) {
    known = ink
    self.folds = Self.byHeader(folds)
    begun = true
  }

  private func snapshot() -> [BoardSessionRecord.Ink] {
    known.keys.sorted().compactMap { id in
      known[id].map {
        BoardSessionRecord.Ink(id: id, owner: $0.owner, box: $0.box, header: $0.header ? true : nil)
      }
    }
  }

  private func foldSnapshot() -> [BoardSessionRecord.Fold]? {
    let all = folds.keys.sorted().compactMap { folds[$0] }
      .map { BoardSessionRecord.Fold(header: $0.header, held: $0.held, folded: $0.folded) }
    return all.isEmpty ? nil : all
  }

  // MARK: Diffs

  static func moved(_ a: Box, _ b: Box) -> Bool {
    abs(a.x - b.x) > 0.01 || abs(a.y - b.y) > 0.01 || abs(a.w - b.w) > 0.01 || abs(a.h - b.h) > 0.01
  }

  /// What changed since the strokes last handed over; the board is known as `ink` from now on.
  private mutating func diff(_ ink: [String: InkNow]) -> [BoardSessionRecord.Change] {
    var out: [BoardSessionRecord.Change] = []
    for id in Set(known.keys).union(ink.keys).sorted() {
      switch (known[id], ink[id]) {
      case (nil, let now?):
        out.append(
          .init(
            id: id, owner: now.owner, after: now.box, header: now.header ? true : nil,
            hidden: now.hidden ? true : nil))
      case (let was?, nil):
        out.append(.init(id: id, owner: was.owner, before: was.box))
      case (let was?, let now?):
        guard Self.moved(was.box, now.box) || was.hidden != now.hidden else { continue }
        out.append(
          .init(
            id: id, owner: now.owner, before: was.box, after: now.box,
            hidden: was.hidden != now.hidden ? now.hidden : nil))
      case (nil, nil):
        continue
      }
    }
    known = ink
    return out
  }

  /// Folds by header, leaving out headers never folded: a header's first fold has no earlier one to compare with.
  static func byHeader(_ folds: [FoldNow]) -> [String: FoldNow] {
    Dictionary(
      folds.filter { $0.folded || !$0.held.isEmpty }.map { ($0.header, $0) }, uniquingKeysWith: { _, new in new })
  }

  /// The headers whose fold changed since the folds last handed over.
  private mutating func foldChanges(_ now: [FoldNow]) -> [FoldNow] {
    let next = Self.byHeader(now)
    var out: [FoldNow] = []
    for header in Set(folds.keys).union(next.keys).sorted() {
      let was = folds[header]
      let isNow = next[header] ?? FoldNow(header: header, held: was?.held ?? [], folded: false)
      if (was?.folded ?? false) != isNow.folded || (isNow.folded && was?.held != isNow.held) { out.append(isNow) }
    }
    folds = next
    return out
  }

  /// A step's later changes joined to it: each stroke's first before and last after.
  static func merged(_ a: [BoardSessionRecord.Change], _ b: [BoardSessionRecord.Change])
    -> [BoardSessionRecord.Change]
  {
    var out = a
    for change in b {
      guard let i = out.firstIndex(where: { $0.id == change.id }) else {
        out.append(change)
        continue
      }
      var joined = out[i]
      joined.after = change.after
      if let hidden = change.hidden { joined.hidden = hidden }
      if joined.before == nil, joined.after == nil {
        out.remove(at: i)
      } else if let before = joined.before, let after = joined.after, !moved(before, after), joined.hidden == nil {
        out.remove(at: i)
      } else {
        out[i] = joined
      }
    }
    return out.sorted { $0.id < $1.id }
  }

  // MARK: Events

  static func num(_ any: Any?) -> Double? {
    switch any {
    case let v as Double: return v
    case let v as Int: return Double(v)
    case let v as Int64: return Double(v)
    case let v as Float: return Double(v)
    case let v as Bool: return v ? 1 : 0
    default: return nil
    }
  }

  static func box(_ any: Any?) -> Box? {
    guard let list = any as? [Any], list.count == 4 else { return nil }
    let v = list.compactMap(num)
    return v.count == 4 ? Box(v[0], v[1], v[2], v[3]) : nil
  }

  static func inside(_ b: Box, _ outer: Box, slack: Double = 1.5) -> Bool {
    b.x >= outer.x - slack && b.y >= outer.y - slack && b.maxX <= outer.maxX + slack && b.maxY <= outer.maxY + slack
  }

  /// The events the recorder reads.
  public static let reads: Set<String> = [
    "paper_open", "paper_ink", "paper_keep", "paper_kept_ink", "room", "keep_text", "keep_late", "keep_all",
    "paper_drop",
    "paper_apart", "paste", "applied", "changed", "header_undo", "header_redo", "paper_selection",
    "group_tap_lost", "group_tap_lost_after", "hold_menu",
  ]

  /// Of those, the ones the board hands its strokes over with (the rest change no ink).
  public static let changesInk: Set<String> = reads.subtracting([
    "paper_kept_ink", "group_tap_lost_after", "hold_menu",
  ])

  /// Of those, the ones that may change a fold: the board hands its folds over with them too.
  public static func changesFolds(_ action: String, _ fields: [String: Any]) -> Bool {
    ["paper_open", "changed", "header_undo", "header_redo"].contains(action)
      || (action == "paper_ink" && (fields["undoing"] as? Bool) == true)
  }

  /// What a step is, from its event.
  struct Label {
    var kind: String
    var by: String
    var name: String?
    var aim: BoardSessionRecord.Aim?
    var room: BoardSessionRecord.Room?
    var seen: BoardSessionRecord.Seen?
    /// The board's own change after a step: it joins the step before rather than making its own.
    var joins = false
    /// It may take the board's change that follows it.
    var stays = false
  }

  /// One of the board's log events (`type`, its fields) at `t` (unix ms), with its strokes and folds as they are now
  /// when the event can change them. Events of other boards, and those the recorder doesn't read, are ignored.
  public mutating func take(
    type: String, t: Double, fields: [String: Any], ink: [String: InkNow]?, folds now: [FoldNow]? = nil
  ) {
    guard fields["board"] as? String == board, let action = fields["action"] as? String, Self.reads.contains(action)
    else { return }
    // Seen only: they change nothing.
    switch action {
    case "paper_kept_ink":
      guard let i = steps.lastIndex(where: { $0.kind == "keep" }),
        let shown = fields["ink_span"] as? [Any], let expected = fields["expected_ink_span"] as? [Any]
      else { return }
      let look = BoardSessionRecord.KeptLook(
        shown: shown.compactMap(Self.num), expected: expected.compactMap(Self.num),
        inkPx: Self.num(fields["ink_px"]).map { Int($0) }, darkPx: Self.num(fields["dark_px"]).map { Int($0) })
      let looks = (steps[i].seen?.kept ?? []) + [look]
      steps[i].seen?.kept = looks
      return
    case "group_tap_lost_after":
      guard let i = steps.lastIndex(where: { $0.kind == "selection_lost" }) else { return }
      steps[i].seen?.heldAfter = (fields["held"] as? Bool) ?? false
      return
    case "hold_menu":
      if let x = Self.num(fields["x"]), let y = Self.num(fields["y"]) { holdAt = (x, y) }
      return
    case "paper_open":
      // The board as it opened, if nothing was measured yet: a board that opens with ink starts from it.
      if !begun, let ink { begin(ink: ink, folds: now ?? []) }
      return
    default:
      break
    }
    // The first strokes handed over, before anything was measured: the board as it opened.
    if !begun {
      guard let ink else { return }
      begin(ink: ink, folds: now ?? [])
      if action == "paper_ink" { return }
    }
    if start == nil {
      start = snapshot()
      startFolds = foldSnapshot()
    }
    let changes = ink.map { diff($0) } ?? []
    let folded = now.map { foldChanges($0) } ?? []
    guard var label = label(action, fields, changes: changes, folded: folded) else { return }
    if action == "paper_selection" {
      let box = Self.box(fields["box"])
      selected =
        box.map { b in known.keys.sorted().filter { known[$0].map { !$0.hidden && Self.inside($0.box, b) } ?? false } }
        ?? []
      label.kind = selected.isEmpty ? "deselect" : "select"
      label.aim = selected.isEmpty ? nil : .init(ids: selected)
    }
    if label.joins, open, let i = steps.indices.last, let lastT = last, t - lastT <= Self.settle,
      Self.joins(label.kind, onto: steps[i])
    {
      relabel(i, with: label, changes: changes, folded: folded)
      last = t
      return
    }
    if label.kind == "join" { label.kind = "move" }
    if changes.isEmpty, folded.isEmpty,
      ["move", "ink", "erase", "undo", "redo", "outline", "room"].contains(label.kind)
    {
      return
    }
    var step = BoardSessionRecord.Step(
      t: t, kind: label.kind, by: label.by, name: label.name, aim: label.aim,
      changes: changes.isEmpty ? nil : changes, room: label.room, seen: label.seen)
    if let first = folded.first {
      step.fold = .init(header: first.header, held: first.held, folded: first.folded)
      if label.kind == "outline" { step.kind = first.folded ? "fold" : "unfold" }
    }
    emit(step)
    for more in folded.dropFirst() {
      emit(
        .init(
          t: t, kind: more.folded ? "fold" : "unfold", by: label.by, name: label.name,
          fold: .init(header: more.header, held: more.held, folded: more.folded)))
    }
    open = label.stays
  }

  /// Whether a step's label may take over the step before: the board's own change after any step, a drag's end, a
  /// keep's room after the keep, or a step of his over the system's change it caused.
  static func joins(_ kind: String, onto last: BoardSessionRecord.Step) -> Bool {
    kind == "join" || last.by == "system" || kind == last.kind || (kind == "drop" && last.kind == "move")
  }

  private mutating func relabel(
    _ i: Int, with label: Label, changes: [BoardSessionRecord.Change], folded: [FoldNow]
  ) {
    var step = steps[i]
    if label.kind != "join", !(label.by == "system" && step.by != "system") {
      step.kind = label.kind
      step.by = label.by
      step.name = label.name ?? step.name
      if let aim = label.aim { step.aim = aim }
    }
    if let room = label.room { step.room = room }
    if let seen = label.seen { step.seen = seen }
    let joined = Self.merged(step.changes ?? [], changes)
    step.changes = joined.isEmpty ? nil : joined
    // Larry's batch and an outline change he asked for aim at everything they moved, the system's half included.
    if ["ops", "outline"].contains(label.kind) || (label.kind == "room" && label.room == nil) {
      step.aim = .init(ids: joined.map(\.id))
    }
    if let first = folded.first { step.fold = .init(header: first.header, held: first.held, folded: first.folded) }
    steps[i] = step
  }

  private mutating func emit(_ step: BoardSessionRecord.Step) {
    if began == nil { began = step.t }
    last = step.t
    steps.append(step)
  }

  private func aimFromHold() -> [String] {
    guard let at = holdAt else { return [] }
    return known.keys.sorted().filter { id in known[id].map { Self.inside(Box(at.0, at.1, 0, 0), $0.box) } ?? false }
  }

  private func label(
    _ action: String, _ fields: [String: Any], changes: [BoardSessionRecord.Change], folded: [FoldNow]
  ) -> Label? {
    let room = Self.num(fields["cut"]).flatMap { cut in
      Self.num(fields["dy"]).map { BoardSessionRecord.Room(cut: cut, dy: $0) }
    }
    switch action {
    case "paper_ink":
      let inTouch = (fields["in_touch"] as? Bool) == true
      if (fields["undoing"] as? Bool) == true {
        return Label(kind: (fields["redoing"] as? Bool) == true ? "redo" : "undo", by: "menu")
      }
      let added = changes.contains { $0.before == nil }
      let removed = changes.contains { $0.after == nil }
      let shifted = changes.contains { $0.before != nil && $0.after != nil }
      let kind = shifted ? "move" : (removed && !added ? "erase" : "ink")
      guard inTouch else {
        // The board's own change, not a touch's: it joins the step it follows, or stands as the system's.
        return Label(kind: kind, by: "system", name: kind, joins: true, stays: true)
      }
      guard kind == "move" else { return Label(kind: kind, by: "pencil", name: kind) }
      let held = (Self.num(fields["selected"]) ?? 0) > 0
      let start: String?
      switch fields["start_view"] as? String {
      case "CanvasElementResizeHandle": start = held ? "knob" : "handle"
      case "CanvasElementResizeView": start = "inside"
      default: start = nil
      }
      return Label(
        kind: "move", by: held ? "finger" : "system", name: "Move",
        aim: .init(ids: held ? selected : [], start: start), stays: true)
    case "paper_drop":
      // A drag's end: the room it opened joins the drag, which becomes a drop.
      guard (fields["room"] as? Bool) == true else { return Label(kind: "join", by: "", joins: true, stays: true) }
      let drag = steps.last
      return Label(kind: "drop", by: drag?.by ?? "finger", name: "Move", aim: drag?.aim, joins: true, stays: true)
    case "paper_apart":
      return Label(kind: "apart", by: "rule")
    case "paper_keep":
      return Label(
        kind: "keep", by: "menu", name: "Keep",
        seen: .init(
          heldAfter: nil, penBefore: fields["tool_before"] as? String, penAfter: fields["tool_after"] as? String,
          kept: [], drawnWhole: nil), joins: true, stays: true)
    case "keep_text", "keep_late", "keep_all":
      return Label(kind: "keep", by: "menu", name: "Keep", room: room, joins: true, stays: true)
    case "room":
      return Label(
        kind: "room", by: "menu", name: "Make room", aim: .init(ids: aimFromHold()), room: room, joins: true,
        stays: true)
    case "paste":
      return Label(kind: "paste", by: "menu", name: "Paste", joins: true, stays: true)
    case "applied":
      // Larry's batch moves what it names, and what its rules push.
      return Label(
        kind: "ops", by: "larry", name: "Larry", aim: .init(ids: changes.map(\.id)), joins: true, stays: true)
    case "changed":
      // An outline change he made (a fold, a room from the margin, a header): what it moves is what he asked for.
      let label = fields["label"] as? String ?? "outline"
      let kind = folded.isEmpty && label.lowercased().contains("room") ? "room" : "outline"
      return Label(kind: kind, by: "menu", name: label, aim: .init(ids: changes.map(\.id)), joins: true, stays: true)
    case "header_undo":
      return Label(kind: "undo", by: "menu")
    case "header_redo":
      return Label(kind: "redo", by: "menu")
    case "paper_selection":
      return Label(kind: "select", by: "finger")
    case "group_tap_lost":
      return Label(
        kind: "selection_lost", by: "system", aim: .init(ids: selected),
        seen: .init(heldAfter: false, penBefore: nil, penAfter: nil, kept: nil, drawnWhole: nil))
    default:
      return nil
    }
  }
}
