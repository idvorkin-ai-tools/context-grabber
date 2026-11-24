//  The iPad's record of a writing session (spec 2026-11-23-board-interaction-review-design.md, *What a session is, and
//  what is recorded*; stories 1237–1239, 1248): it takes the board's own session-log events as they are written, one
//  board at a time, and keeps the board as the session began and each step since in `BoardSessionRecord`'s form. The
//  same observations a pulled log carries, so a session reviewed on the iPad and one converted from its log
//  (`scripts/native/board-review-from-log.py`) are the same record. Units are what the events can name: each stroke
//  written, the board as first opened, a kept reply's group. Only observations go in, never the log's own verdicts.
//  Pure: the caller says when.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardReviewRecorder: Sendable {
  /// A session ends after this long with no step (*Decisions*, 1): five minutes, in ms.
  public static let idle: Double = 5 * 60 * 1000

  typealias Box = BoardSessionRecord.Box

  struct Unit: Sendable {
    var owner: String
    var box: Box
    var n: Int
  }

  public let board: String
  public let surface: String
  public let build: String?
  private var units: [String: Unit] = [:]
  private var order: [String] = []
  private var selected: [String] = []
  private var holdAt: (Double, Double)?
  /// What a move's `paper_ink` said, waiting for its `paper_drop`.
  struct PendingMove: Sendable {
    var alike: Bool
    var selected: Double
    var startView: String?
  }
  private var pendingMove: PendingMove?
  private var movedFrom: [String: Box]?
  private var start: [BoardSessionRecord.Ink]?
  public private(set) var steps: [BoardSessionRecord.Step] = []
  /// When the session's first step came, and its last.
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

  /// The session so far, or nil with no step.
  public var record: BoardSessionRecord? {
    guard let began, !steps.isEmpty else { return nil }
    let header = BoardSessionRecord.Header(
      record: BoardSessionRecord.version, board: board, session: "\(board)-\(Int(began))", surface: surface,
      build: build, observes: .init(selection: "yes", pen: "yes", kept: "yes"), ink: start ?? [], folds: nil)
    return BoardSessionRecord(header: header, steps: steps)
  }

  /// The next session starts from the board as it is now.
  public mutating func nextSession() {
    steps = []
    start = nil
    began = nil
    last = nil
  }

  private func snapshot() -> [BoardSessionRecord.Ink] {
    order.compactMap { id in
      units[id].map { BoardSessionRecord.Ink(id: id, owner: $0.owner, box: $0.box, n: $0.n > 1 ? $0.n : nil) }
    }
  }

  private mutating func emit(_ step: BoardSessionRecord.Step) {
    if began == nil {
      began = step.t
    }
    last = step.t
    steps.append(step)
  }

  // MARK: Events

  static func num(_ any: Any?) -> Double? {
    switch any {
    case let v as Double: return v
    case let v as Int: return Double(v)
    case let v as Float: return Double(v)
    case let v as CGFloat: return Double(v)
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

  private mutating func move(_ ids: [String], _ to: (Box) -> Box) -> [BoardSessionRecord.Change] {
    ids.compactMap { id in
      guard var unit = units[id] else { return nil }
      let before = unit.box
      let after = to(before)
      unit.box = Box(Self.round(after.x), Self.round(after.y), Self.round(after.w), Self.round(after.h))
      units[id] = unit
      return BoardSessionRecord.Change(id: id, owner: unit.owner, before: before, after: unit.box)
    }
  }

  static func round(_ v: Double) -> Double { (v * 10).rounded() / 10 }

  /// One session-log event (`type`, its fields) at `t`. Events of other boards, and of no board, are ignored.
  public mutating func take(type: String, t: Double, fields: [String: Any]) {
    guard fields["board"] as? String == board, let action = fields["action"] as? String else { return }
    let isStep = Self.steps.contains(action)
    if isStep, start == nil, !(action == "paper_open") {
      start = snapshot()
    }
    switch action {
    case "paper_open":
      if units.isEmpty, let n = Self.num(fields["strokes"]), n > 0, let ink = Self.box(fields["ink"]) {
        units["board"] = Unit(owner: "igor", box: ink, n: Int(n))
        order.append("board")
      }
    case "paper_ink":
      let added = Int(Self.num(fields["added"]) ?? 0)
      let moved = Int(Self.num(fields["moved"]) ?? 0)
      let removed = Int(Self.num(fields["removed"]) ?? 0)
      if added > 0, moved == 0, removed == 0, let box = Self.box(fields["added_box"]) {
        let id = "s\(Int(Self.num(fields["strokes"]) ?? Double(order.count)))"
        units[id] = Unit(owner: "igor", box: box, n: added)
        order.append(id)
        emit(
          .init(
            t: t, kind: "ink", by: "pencil",
            changes: [.init(id: id, owner: "igor", after: box, n: added > 1 ? added : nil)]))
      } else if moved > 0, added == 0 {
        pendingMove = PendingMove(
          alike: (fields["moved_alike"] as? Bool) == true, selected: Self.num(fields["selected"]) ?? 0,
          startView: fields["start_view"] as? String)
      }
    case "paper_keep":
      guard let ink = Self.box(fields["ink"]) else { return }
      let n = Int(Self.num(fields["strokes"]) ?? 1)
      let id = "keep\(Int(t))"
      units[id] = Unit(owner: "larry", box: ink, n: n)
      order.append(id)
      emit(
        .init(
          t: t, kind: "keep", by: "menu", name: "Keep", changes: [.init(id: id, owner: "larry", after: ink, n: n)],
          seen: .init(
            heldAfter: nil, penBefore: fields["tool_before"] as? String, penAfter: fields["tool_after"] as? String,
            kept: [], drawnWhole: nil)))
    case "paper_kept_ink":
      guard let i = steps.lastIndex(where: { $0.kind == "keep" }),
        let shown = fields["ink_span"] as? [Any], let expected = fields["expected_ink_span"] as? [Any]
      else { return }
      let look = BoardSessionRecord.KeptLook(
        shown: shown.compactMap(Self.num), expected: expected.compactMap(Self.num),
        inkPx: Self.num(fields["ink_px"]).map { Int($0) }, darkPx: Self.num(fields["dark_px"]).map { Int($0) })
      let looks = (steps[i].seen?.kept ?? []) + [look]
      steps[i].seen?.kept = looks
    case "hold_menu":
      if let x = Self.num(fields["x"]), let y = Self.num(fields["y"]) { holdAt = (x, y) }
    case "room":
      guard let cut = Self.num(fields["cut"]), let dy = Self.num(fields["dy"]) else { return }
      let aim =
        holdAt.map { at in
          order.filter { id in units[id].map { Self.inside(Box(at.0, at.1, 0, 0), $0.box) } ?? false }
        } ?? []
      let pushed = order.filter { units[$0].map { $0.box.y >= cut } ?? false }
      let changes = move(pushed) { Box($0.x, $0.y + dy, $0.w, $0.h) }
      emit(
        .init(
          t: t, kind: "room", by: "menu", name: "Make room", aim: .init(ids: aim),
          changes: changes, room: .init(cut: cut, dy: dy)))
    case "paper_selection":
      let box = Self.box(fields["box"])
      selected = box.map { b in order.filter { id in units[id].map { Self.inside($0.box, b) } ?? false } } ?? []
      emit(
        .init(
          t: t, kind: selected.isEmpty ? "deselect" : "select", by: "finger",
          aim: selected.isEmpty ? nil : .init(ids: selected)))
    case "group_tap_lost":
      emit(
        .init(
          t: t, kind: "selection_lost", by: "system", aim: .init(ids: selected),
          seen: .init(heldAfter: false, penBefore: nil, penAfter: nil, kept: nil, drawnWhole: nil)))
    case "group_tap_lost_after":
      guard let i = steps.lastIndex(where: { $0.kind == "selection_lost" }) else { return }
      steps[i].seen?.heldAfter = (fields["held"] as? Bool) ?? false
    case "paper_drop":
      guard let m = pendingMove, let from = Self.box(fields["from"]), let at = Self.box(fields["at"]) else { return }
      pendingMove = nil
      let moved = order.filter { units[$0].map { Self.inside($0.box, from) } ?? false }
      var before: [String: Box] = [:]
      for id in moved { before[id] = units[id]?.box }
      var changes: [BoardSessionRecord.Change]
      if m.alike {
        let dx = at.x - from.x
        let dy = at.y - from.y
        changes = move(moved) { Box($0.x + dx, $0.y + dy, $0.w, $0.h) }
      } else if moved.count == 1 {
        changes = move(moved) { _ in at }
      } else {
        let sx = from.w > 0 ? at.w / from.w : 1
        let sy = from.h > 0 ? at.h / from.h : 1
        changes = move(moved) {
          Box(at.x + ($0.x - from.x) * sx, at.y + ($0.y - from.y) * sy, $0.w * sx, $0.h * sy)
        }
      }
      let room = (fields["room"] as? Bool) == true
      if room, let cut = Self.num(fields["cut"]), let dy = Self.num(fields["dy"]) {
        let pushed = order.filter { id in !moved.contains(id) && (units[id].map { $0.box.y >= cut } ?? false) }
        changes += move(pushed) { Box($0.x, $0.y + dy, $0.w, $0.h) }
      }
      let held = m.selected > 0
      let start: String?
      switch m.startView {
      case "CanvasElementResizeHandle": start = held ? "knob" : "handle"
      case "CanvasElementResizeView": start = "inside"
      default: start = nil
      }
      emit(
        .init(
          t: t, kind: room ? "drop" : "move", by: held ? "finger" : "system", name: "Move",
          aim: .init(ids: held ? moved : [], start: start), changes: changes))
      movedFrom = before
    case "paper_apart":
      guard let before = movedFrom else { return }
      movedFrom = nil
      let whose = (fields["whose"] as? String) == "theirs" ? "larry" : "igor"
      let back = order.filter { before[$0] != nil && units[$0]?.owner == whose }
      var changes: [BoardSessionRecord.Change] = []
      for id in back {
        guard var unit = units[id], let was = before[id] else { continue }
        changes.append(.init(id: id, owner: whose, before: unit.box, after: was))
        unit.box = was
        units[id] = unit
      }
      emit(.init(t: t, kind: "apart", by: "rule", changes: changes))
    default:
      break
    }
  }

  /// The events that make a step: the board before the first of them is the session's start.
  static let steps: Set<String> = [
    "paper_ink", "paper_keep", "room", "paper_selection", "group_tap_lost", "paper_drop", "paper_apart",
  ]
}
