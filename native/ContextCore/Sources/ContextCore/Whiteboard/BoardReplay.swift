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
    /// A reply of Larry's with marks (#941): they show as his ghosts, replacing his unkept ones, where the iPad places
    /// them, and each is tried with a tap on it.
    case marks(WhiteboardMarks.Row)
    /// A finger tap at a board point: which of his marks it chooses (#941).
    case tap(CGPoint)
    /// Igor's Keep group on a mark of this reply (#942): its marks still showing become ink, one group.
    case keepGroup(String)

    /// A step file's JSON: a batch, a chat message carrying one under `ops`, `{"keep": [ids]}`, or a list of those.
    public static func steps(_ any: Any, key: String) -> [Step] {
      if let list = any as? [Any] {
        return list.enumerated().flatMap { steps($1, key: "\(key)-\($0)") }
      }
      guard let json = any as? [String: Any] else { return [] }
      if let ids = json["keep"] as? [String] { return [.keep(ids)] }
      if let reply = json["keep_group"] as? String { return [.keepGroup(reply)] }
      if let at = json["tap"] as? [NSNumber], at.count == 2 {
        return [.tap(CGPoint(x: at[0].doubleValue, y: at[1].doubleValue))]
      }
      if json["shapes"] != nil, let row = WhiteboardMarks.row(json.merging(["who": "larry"]) { a, _ in a }) {
        return [.marks(row)]
      }
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
    /// His marks the step showed, by id (#941).
    public var marks: [String] = []
    /// Taps tried: a mark's own (`mark` set) or one asked for, and which mark each chose.
    public var taps: [Tap] = []

    /// The marks a tap on them doesn't reach: another mark takes it, or none does.
    public var unreachable: [Tap] { taps.filter { $0.mark != nil && $0.chose != $0.mark } }

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
      if !marks.isEmpty { out["marks"] = marks }
      if !taps.isEmpty { out["taps"] = taps.map(\.wire) }
      if !unreachable.isEmpty { out["unreachable"] = unreachable.compactMap(\.mark) }
      return out
    }
  }

  /// A tap tried on the marks.
  public struct Tap: Equatable, Sendable {
    public var at: CGPoint
    /// The mark the tap was aimed at; nil for a tap at a point.
    public var mark: String?
    /// The mark it chose; nil for none.
    public var chose: String?

    public var wire: [String: Any] {
      var out: [String: Any] = ["at": [Double(at.x), Double(at.y)], "chooses": chose ?? NSNull()]
      if let mark { out["mark"] = mark }
      return out
    }
  }

  /// One of Larry's marks showing, in board points, as the iPad draws its ghost.
  public struct Mark: Equatable, Sendable {
    public var id: String
    public var kind: WhiteboardTurn.Shape.Kind
    public var text: String?
    public var lines: [[CGPoint]]
    public var width: CGFloat
    public var color: UInt32

    /// The middle of a label's words, or of any other mark's first stretch.
    public var aim: CGPoint? {
      if kind == .text {
        let box = WhiteboardMarkChoice.bounds(lines)
        return box.isNull ? nil : CGPoint(x: box.midX, y: box.midY)
      }
      guard let line = lines.first, let a = line.first else { return nil }
      let b = line.count > 1 ? line[1] : a
      return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
  }

  /// Larry's marks showing, oldest first, as the board's ghosts hold them.
  public private(set) var marks: [Mark] = []

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
      case .marks(let row): show(row)
      case .keepGroup(let reply): keepGroup(reply)
      case .tap(let at):
        var outcome = Outcome(label: "tap", action: "tapped")
        outcome.taps = [Tap(at: at, mark: nil, chose: choose(at: at)?.id)]
        outcomes.append(outcome)
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
    let plan = BoardOps.plan(
      batch.ops, strokes: strokes, texts: texts, metas: metas, ghosts: board.ghosts, pages: pages)
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
    // His texts with notes, lettered onto the board as Keep letters them (#937).
    for text in plan.inked {
      board.texts.append(
        BoardSnapshot.Kept(
          id: text.id, text: text.text, font: text.font, box: text.box, color: BoardSnapshot.hex(text.color),
          t: nextTime(), size: text.size))
      outcome.drawn.append(text.id)
    }
    for name in plan.forgetMetas { setMeta(nil, on: name) }
    for (name, meta) in plan.metas { setMeta(meta, on: name) }
    board.ghosts.removeAll { plan.dismissed.contains($0.id) }
    outcome.ghostsGone = plan.dismissed
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

  /// A moment after everything on the board: a kept text's glyphs are known by theirs.
  private func nextTime() -> Int64 {
    ((board.texts.map(\.t) + board.ink.compactMap(\.t)).max() ?? 1_700_000_000_000) + 1000
  }

  /// Igor keeps Larry's text ghosts: each becomes a kept text under Larry's id, where its ghost showed, one change.
  private mutating func keep(_ ids: [String]) {
    var outcome = Outcome(label: "keep", action: "kept")
    for id in ids {
      guard let ghost = board.ghosts.first(where: { $0.id == id }) else {
        outcome.why = (outcome.why.map { $0 + ", " } ?? "no ghost ") + id
        continue
      }
      let t = nextTime()
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

  /// The mark a finger tap at `at` chooses, as the board's tap does at a zoom of 1: the nearest within reach (#941).
  public func choose(at point: CGPoint) -> Mark? {
    WhiteboardMarkChoice.nearest(marks) {
      WhiteboardTurn.reach($0.lines, kind: $0.kind, at: point, tolerance: WhiteboardTurn.tapReach)
    }
  }

  /// Where a finger best reaches `mark`: of the points along it (a label's middle, for a label), the one furthest from
  /// every other mark. A mark that point can't reach is one no tap can.
  public func spot(on mark: Mark) -> CGPoint? {
    let others = marks.filter { $0.id != mark.id }
    let candidates =
      mark.kind == .text ? mark.aim.map { [$0] } ?? [] : mark.lines.flatMap { WhiteboardTurn.inkPoints($0) }
    let room = { (point: CGPoint) -> CGFloat in
      others.compactMap { WhiteboardTurn.reach($0.lines, kind: $0.kind, at: point, tolerance: .infinity) }.min()
        ?? .infinity
    }
    return candidates.max { room($0) < room($1) }
  }

  /// His reply's marks replace his unkept ones (story 357), placed by the reply's own frame, and each is tried with a tap.
  private mutating func show(_ row: WhiteboardMarks.Row) {
    var outcome = Outcome(label: "marks \(row.id)", action: row.drawable ? "shown" : "unplaced")
    defer { outcomes.append(outcome) }
    guard let frame = row.frame, row.drawable else { return }
    if !WhiteboardTurn.hasLetters("A", .print) {
      outcome.why = "no fonts here: his labels are dropped, so mark ids and taps after one are not the iPad's"
    }
    marks = row.shapes.enumerated().map { index, shape in
      Mark(
        id: WhiteboardMarks.mark(index, of: row.id), kind: shape.kind, text: shape.text,
        lines: WhiteboardTurn.lines(shape, frame: frame, scale: row.scale),
        width: WhiteboardTurn.width(shape, scale: row.scale), color: shape.color ?? WhiteboardTurn.larryColor)
    }
    outcome.marks = marks.map(\.id)
    outcome.taps = marks.compactMap { mark in
      spot(on: mark).map { Tap(at: $0, mark: mark.id, chose: choose(at: $0)?.id) }
    }
  }

  /// Keep group (#942, story 995): the reply's marks still showing become ink where they showed, each stroke named for
  /// its mark, all under the reply's one group; one change.
  private mutating func keepGroup(_ reply: String) {
    var outcome = Outcome(label: "keep group \(reply)", action: "kept")
    let kept = marks.filter { WhiteboardMarks.reply(of: $0.id) == reply }
    guard !kept.isEmpty else {
      outcome.action = "ignored"
      outcome.why = "no marks of \(reply) showing"
      outcomes.append(outcome)
      return
    }
    var names: [String] = []
    var strokes: [BoardSnapshot.Ink] = []
    for mark in kept {
      for (k, line) in mark.lines.enumerated() {
        let name = "\(mark.id).\(k)"
        names.append(name)
        strokes.append(
          BoardSnapshot.Ink(
            id: name, t: nextTime(), color: String(format: "#%06x", mark.color), width: mark.width,
            points: WhiteboardTurn.inkPoints(line)))
      }
    }
    let notes = WhiteboardMarks.groupNotes(names, reply: reply)
    for i in strokes.indices { strokes[i].meta = notes[strokes[i].id] }
    board.ink += strokes
    marks.removeAll { WhiteboardMarks.reply(of: $0.id) == reply }
    outcome.drawn = [WhiteboardMarks.group(reply: reply)]
    applier.changed()
    board.rev = applier.rev
    outcomes.append(outcome)
  }
}
