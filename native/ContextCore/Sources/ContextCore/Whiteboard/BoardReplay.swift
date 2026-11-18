//  Larry's changes replayed on a copy of a board, off the iPad (#936, story 990): the board's own applier
//  (`BoardOpApplier`) and planner (`BoardOps.plan`) run on a snapshot, the plan is applied to the snapshot as the iPad
//  applies it to the canvas, and what each batch did is reported as Larry would read it in `op_result`, with the names it
//  moved, erased, drew and left as ghosts. The `board-ops-harness` tool renders the result; the host tests pin it.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct BoardReplay {
  /// One thing that happens to the board, in order.
  public enum Step {
    /// A batch of Larry's: the `ops` object of his message (`{board, base_rev, label, list}`).
    case batch(key: String, json: [String: Any])
    /// Igor keeps these ghosts of Larry's text, as a tap on Keep does.
    case keep([String])

    /// A step file's JSON: a batch, a chat message carrying one under `ops`, `{"keep": [ids]}`, or a list of those.
    public static func steps(_ any: Any, key: String) -> [Step] {
      if let list = any as? [Any] {
        return list.enumerated().flatMap { steps($1, key: "\(key)-\($0)") }
      }
      guard let json = any as? [String: Any] else { return [] }
      if let ids = json["keep"] as? [String] { return [.keep(ids)] }
      if let ops = json["ops"] as? [String: Any] { return [.batch(key: json["id"] as? String ?? key, json: ops)] }
      return json["list"] != nil ? [.batch(key: key, json: json)] : []
    }
  }

  /// What one step did.
  public struct Outcome: Equatable, Sendable {
    public var label: String
    /// applied, refused, ignored, held, or kept.
    public var action: String
    public var why: String?
    public var result: BoardOps.Result?
    /// The names that moved, and by how much.
    public var moved: [String: CGVector] = [:]
    /// The names erased, with where they were.
    public var erased: [String: CGRect] = [:]
    /// Strokes and texts that came onto the board, by name.
    public var drawn: [String] = []
    /// Larry's text ghosts the step left showing or took away.
    public var ghosts: [String] = []
    public var ghostsGone: [String] = []
    public var pagesBefore = 0
    public var pagesAfter = 0

    public var wire: [String: Any] {
      var out: [String: Any] = ["label": label, "action": action]
      if let why { out["why"] = why }
      if let result { out["op_result"] = result.wire }
      if !moved.isEmpty {
        out["moved"] = moved.keys.sorted().map {
          ["id": $0, "dx": Double(moved[$0]?.dx ?? 0), "dy": Double(moved[$0]?.dy ?? 0)]
        }
      }
      if !erased.isEmpty { out["erased"] = erased.keys.sorted() }
      if !drawn.isEmpty { out["drawn"] = drawn }
      if !ghosts.isEmpty { out["ghosts"] = ghosts }
      if !ghostsGone.isEmpty { out["ghosts_gone"] = ghostsGone }
      if pagesAfter != pagesBefore {
        out["pages_before"] = pagesBefore
        out["pages"] = pagesAfter
      }
      return out
    }
  }

  public private(set) var board: BoardSnapshot
  public private(set) var applier: BoardOpApplier
  public private(set) var outcomes: [Outcome] = []
  /// The board before the first step, for the before picture.
  public let start: BoardSnapshot

  /// `rev`: the board's revision when the snapshot doesn't say; the first batch's `base_rev` otherwise.
  public init(_ board: BoardSnapshot, rev: Int? = nil) {
    self.board = board
    start = board
    let now = board.rev ?? rev ?? 0
    // The changes Igor made after an older look, replayed onto the applier so a batch from that look rebases on them
    // exactly as the iPad's would (story 961).
    let oldest = min(now, board.touched.map { $0.rev - 1 }.min() ?? now)
    var applier = BoardOpApplier(rev: oldest)
    while applier.rev < now {
      applier.changed()
      let at = applier.rev
      applier.touched(board.touched.filter { $0.rev == at }.flatMap(\.ids))
    }
    self.applier = applier
    self.board.rev = now
  }

  public mutating func run(_ steps: [Step]) {
    for step in steps {
      switch step {
      case .batch(let key, let json): run(key: key, json: json)
      case .keep(let ids): keep(ids)
      }
    }
  }

  private mutating func run(key: String, json: [String: Any]) {
    guard let batch = BoardOps.batch(json, key: key, source: "replay") else { return }
    // Igor writing between Larry's looks moves the revision on without touching what he names: the batch is never
    // older than the board as the replay has it.
    if let base = batch.baseRev, base > applier.rev {
      while applier.rev < base { applier.changed() }
    }
    var outcome = Outcome(label: batch.label, action: "")
    switch applier.receive(batch, board: board.board, editable: true, ready: true) {
    case .ignored(let why):
      outcome.action = "ignored"
      outcome.why = why
    case .refused(let result):
      outcome.action = "refused"
      outcome.result = result
    case .held:
      outcome.action = "held"
    case .apply(let batch):
      outcome.action = "applied"
      apply(batch, into: &outcome)
    }
    board.rev = applier.rev
    outcomes.append(outcome)
  }

  /// The plan applied to the snapshot as the iPad applies it to the canvas, one revision for a change of the ink.
  private mutating func apply(_ batch: BoardOps.Batch, into outcome: inout Outcome) {
    let (strokes, texts, metas) = board.planInput
    let pages = board.pageCount
    let plan = BoardOps.plan(batch.ops, strokes: strokes, texts: texts, metas: metas, pages: pages)
    let names = strokes.map { $0.ids.first ?? "" }
    let inkCount = board.ink.count
    let textIDs = board.texts.map(\.id)
    let name = { (index: Int) -> String in index < inkCount ? names[index] : textIDs[index - inkCount] }
    for (index, shift) in plan.offsets {
      outcome.moved[name(index)] = shift
      if index < inkCount {
        board.ink[index].points = board.ink[index].points.map { CGPoint(x: $0.x + shift.dx, y: $0.y + shift.dy) }
      } else {
        board.texts[index - inkCount].box = board.texts[index - inkCount].box.offsetBy(dx: shift.dx, dy: shift.dy)
      }
    }
    for (index, hidden) in plan.hidden where index < inkCount { board.ink[index].hidden = hidden }
    for index in plan.erase {
      outcome.erased[name(index)] = index < inkCount ? board.ink[index].bounds : board.texts[index - inkCount].box
    }
    let erasedInk = Set(plan.erase.filter { $0 < inkCount })
    let erasedTexts = Set(plan.erase.filter { $0 >= inkCount }.map { $0 - inkCount })
    board.ink = board.ink.enumerated().filter { !erasedInk.contains($0.offset) }.map(\.element)
    board.texts = board.texts.enumerated().filter { !erasedTexts.contains($0.offset) }.map(\.element)
    for stroke in plan.added {
      board.ink.append(
        BoardSnapshot.Ink(
          id: stroke.id, color: BoardSnapshot.hex(stroke.color), width: stroke.width, points: stroke.points,
          hidden: stroke.hidden, meta: stroke.meta))
      outcome.drawn.append(stroke.id)
    }
    for name in plan.forgetMetas { setMeta(nil, on: name) }
    for (name, meta) in plan.metas { setMeta(meta, on: name) }
    for text in plan.texts {
      board.ghosts.removeAll { $0.id == text.id }
      board.ghosts.append(text)
      outcome.ghosts.append(text.id)
    }
    if plan.changesBoard { applier.changed() }
    outcome.result = applier.applied(batch, plan: plan)
    if plan.changesBoard { applier.touched([], all: true) }
    outcome.pagesBefore = plan.pagesBefore
    outcome.pagesAfter = plan.pagesAfter
    board.pages = plan.pagesAfter
  }

  private mutating func setMeta(_ meta: BoardMeta?, on name: String) {
    if let at = board.ink.firstIndex(where: { $0.id == name }) { board.ink[at].meta = meta }
    if let at = board.texts.firstIndex(where: { $0.id == name }) { board.texts[at].meta = meta }
  }

  /// Igor keeps Larry's text ghosts: each becomes a kept text under Larry's id, where its ghost showed, one change.
  private mutating func keep(_ ids: [String]) {
    var outcome = Outcome(label: "keep", action: "kept")
    var t = (board.texts.map(\.t) + board.ink.compactMap(\.t)).max() ?? 1_700_000_000_000
    for id in ids {
      guard let ghost = board.ghosts.first(where: { $0.id == id }) else {
        outcome.why = (outcome.why.map { $0 + ", " } ?? "no ghost ") + id
        continue
      }
      t += 1000
      board.ghosts.removeAll { $0.id == id }
      board.texts.append(
        BoardSnapshot.Kept(
          id: id, text: ghost.text, font: ghost.font, box: ghost.box, color: BoardSnapshot.hex(ghost.color), t: t,
          size: ghost.size))
      outcome.drawn.append(id)
    }
    if !outcome.drawn.isEmpty { applier.changed() }
    board.rev = applier.rev
    outcomes.append(outcome)
  }
}
