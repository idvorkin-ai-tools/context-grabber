//  The one place a board's changes are checked, held and recorded, whoever sent them (spec
//  2026-11-16-whiteboard-board-ops-design.md, stories 816, 819): the board's revision, the batches already handled, the
//  one held for the Pencil, and what came of the last. The board's model plans and applies what this lets through
//  (`BoardOps.plan`, then PaperKit) and hands the time and the Pencil in.

import Foundation

/// What the canvas made of a batch it was handed (#1040): it took it as planned, it wasn't there to take it (not laid
/// out yet, or closed), or PaperKit refused the edit.
public enum BoardCanvasOutcome: Equatable, Sendable {
  case applied(BoardOps.Plan)
  case unavailable
  case failed(reason: String)
}

/// What the board reports of one batch after the canvas answered (#1040).
public enum BoardApplyReport: Equatable, Sendable {
  /// The canvas took it; Larry's next turn hears `result`.
  case applied(BoardOps.Result)
  /// The canvas didn't take it; recorded as refused, with the wire's `not_applied`. `canvas` says why, for the log:
  /// `unavailable`, or `failed:<reason>`.
  case refused(BoardOps.Result, canvas: String)
  /// Not the batch this applier let through: its completion came twice, or after the board closed. Nothing recorded.
  case late
}

public struct BoardOpApplier: Equatable, Sendable {
  /// Batches remembered as handled, newest last: far more than a board's thread holds between looks.
  public static let remembered = 64

  /// Bumped on every change of the board's ink, Larry's own included: what `base_rev` is checked against.
  public private(set) var rev: Int
  public private(set) var handled: [String]
  /// A batch let through while the Pencil was down, waiting for it to lift.
  public private(set) var held: BoardOps.Batch?
  /// What came of the last batch handled, for Larry's next turn.
  public private(set) var lastResult: BoardOps.Result?

  /// Story 961: what each change since `since` moved or erased, oldest first, so a batch from an older look can still
  /// apply when it names none of it. Only on this run: a relaunch starts remembering afresh.
  public private(set) var touches: [Touch] = []
  /// The oldest revision `touches` covers every change after; a batch based before it is stale.
  public private(set) var since: Int

  /// The batch let through to the canvas whose answer hasn't come yet (#1040): only its report counts.
  public private(set) var applying: String?

  /// The most changes remembered: far more than Igor writes while Larry thinks.
  public static let rememberedChanges = 200

  public struct Touch: Equatable, Sendable {
    /// The revision the change made.
    public var rev: Int
    /// The names it moved, erased or dissolved.
    public var ids: Set<String>
    /// A batch of Larry's own applied: everything counts as touched, so one look is never applied twice.
    public var all: Bool
  }

  public init(rev: Int = 0, handled: [String] = [], lastResult: BoardOps.Result? = nil) {
    self.rev = rev
    self.handled = handled
    self.lastResult = lastResult
    since = rev
  }

  public enum Decision: Equatable, Sendable {
    /// Not for this board, or already handled: nothing applies and Larry is told nothing.
    case ignored(why: String)
    /// Nothing applies; Larry's next turn says why.
    case refused(BoardOps.Result)
    /// Waiting for the Pencil; `replaced` is the label of a batch held before it, now refused as superseded.
    case held(replaced: String?)
    /// Plan it and apply it now, then call `applied`.
    case apply(BoardOps.Batch)
  }

  /// The board's ink changed.
  public mutating func changed() { rev += 1 }

  /// The change that made the current revision moved, erased or dissolved `ids` (Igor's), or was a batch of Larry's
  /// (`all`). New strokes alone need no record: they never conflict.
  public mutating func touched(_ ids: some Sequence<String>, all: Bool = false) {
    let ids = Set(ids)
    guard all || !ids.isEmpty else { return }
    if let last = touches.last, last.rev == rev {
      touches[touches.count - 1].ids.formUnion(ids)
      touches[touches.count - 1].all = last.all || all
    } else {
      touches.append(Touch(rev: rev, ids: ids, all: all))
    }
    if touches.count > Self.rememberedChanges {
      since = touches.removeFirst().rev
    }
  }

  /// Why a batch based on `base` can't apply to the board as it is now: nil when it can. The names it uses that a
  /// change since moved or erased are `conflicts`.
  func conflict(_ batch: BoardOps.Batch) -> (reason: String, conflicts: [String])? {
    guard let base = batch.baseRev else { return (BoardOps.Reason.stale, []) }
    if base == rev { return nil }
    guard base >= since, base < rev else { return (BoardOps.Reason.stale, []) }
    let after = touches.filter { $0.rev > base }
    if after.contains(where: \.all) { return (BoardOps.Reason.stale, []) }
    let touched = after.reduce(into: Set<String>()) { $0.formUnion($1.ids) }
    let named = BoardOps.namesUsed(batch.ops)
    let conflicts = named.filter(touched.contains)
    return conflicts.isEmpty ? nil : (BoardOps.Reason.stale, conflicts.sorted())
  }

  /// A batch arrived. `ready`: the Pencil lets ink move now (`BoardOps.readiness`). The revision is checked here, on
  /// arrival: a batch held for the Pencil applies on the lift to the board as it is then, the stroke just drawn included.
  public mutating func receive(_ batch: BoardOps.Batch, board: String, editable: Bool, ready: Bool) -> Decision {
    guard !handled.contains(batch.key) else { return .ignored(why: "handled") }
    remember(batch.key)
    if let refusal = batch.refusal { return refuse(batch, refusal) }
    guard batch.board == board else { return .ignored(why: "other_board") }
    guard editable else { return refuse(batch, BoardOps.Reason.lookOnly) }
    if let (reason, conflicts) = conflict(batch) {
      var result = refusal(batch, reason)
      if !conflicts.isEmpty {
        result.conflictIDs = conflicts
        lastResult = result
      }
      return .refused(result)
    }
    var batch = batch
    if batch.baseRev != rev { batch.rebasedFrom = batch.baseRev }
    if ready {
      applying = batch.key
      return .apply(batch)
    }
    let replaced = held?.label
    if let older = held { _ = refusal(older, BoardOps.Reason.superseded) }
    held = batch
    return .held(replaced: replaced)
  }

  /// The held batch, once the Pencil lets it apply.
  public mutating func release(ready: Bool) -> BoardOps.Batch? {
    guard ready, let batch = held else { return nil }
    held = nil
    applying = batch.key
    return batch
  }

  /// The board went away with a batch still held: it never applies, and Larry is told.
  public mutating func dropHeld(reason: String) -> BoardOps.Result? {
    guard let batch = held else { return nil }
    held = nil
    return refusal(batch, reason)
  }

  /// The canvas answered for `batch` (#1040): taken, it is recorded as applied and, if it changed the ink, as
  /// touching everything since, so no batch from an earlier look applies over it; not taken, it is refused as
  /// `not_applied` and nothing else changes. Only the batch let through counts, once: a repeated answer, or one after
  /// the board closed, is `late`. The board's own change (if any) has already bumped `rev`.
  public mutating func report(_ batch: BoardOps.Batch, _ outcome: BoardCanvasOutcome) -> BoardApplyReport {
    guard applying == batch.key else { return .late }
    applying = nil
    switch outcome {
    case .applied(let plan):
      let result = applied(batch, plan: plan)
      if plan.changesBoard { touched([], all: true) }
      return .applied(result)
    case .unavailable:
      return .refused(refusal(batch, BoardOps.Reason.notApplied), canvas: "unavailable")
    case .failed(let reason):
      return .refused(refusal(batch, BoardOps.Reason.notApplied), canvas: "failed:\(reason)")
    }
  }

  /// The board closed: an answer still to come from the canvas no longer counts (#1040).
  public mutating func closed() { applying = nil }

  /// `batch` was applied as planned; the board's own change (if any) has already bumped `rev`.
  @discardableResult
  public mutating func applied(_ batch: BoardOps.Batch, plan: BoardOps.Plan) -> BoardOps.Result {
    var result = BoardOps.Result(
      label: batch.label, ok: true, rev: rev, missingIDs: plan.missingIDs.isEmpty ? nil : plan.missingIDs,
      rooms: plan.rooms.isEmpty ? nil : plan.rooms)
    result.rebasedFrom = batch.rebasedFrom
    lastResult = result
    return result
  }

  private mutating func refuse(_ batch: BoardOps.Batch, _ reason: String) -> Decision {
    .refused(refusal(batch, reason))
  }

  /// `batch` could not be applied after all (the canvas wasn't there): recorded as refused for `reason`.
  @discardableResult
  public mutating func refusal(_ batch: BoardOps.Batch, _ reason: String) -> BoardOps.Result {
    let result = BoardOps.Result(label: batch.label, ok: false, rev: rev, reason: reason)
    lastResult = result
    return result
  }

  private mutating func remember(_ key: String) {
    handled.append(key)
    if handled.count > Self.remembered { handled.removeFirst(handled.count - Self.remembered) }
  }
}

/// Where each board's meaning was kept before it had a file of its own (`BoardMeaning`): six UserDefaults keys per
/// board on this device. Read now only to move them into the board's file, once (`BoardKeeping.migrateMeaning`), and
/// as the fallback while that move hasn't happened.
public struct BoardOpLedger: @unchecked Sendable {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  struct Saved: Codable {
    var rev: Int
    var handled: [String]
    var lastResult: BoardOps.Result?
  }

  /// The most kept texts remembered per board; the oldest go first.
  public static let mostTexts = 500

  private func key(_ board: String) -> String { "whiteboard_ops_\(board)" }
  private func textsKey(_ board: String) -> String { "whiteboard_texts_\(board)" }

  public func applier(board: String) -> BoardOpApplier {
    guard let data = defaults.data(forKey: key(board)), let saved = try? JSONDecoder().decode(Saved.self, from: data)
    else { return BoardOpApplier() }
    return BoardOpApplier(rev: saved.rev, handled: saved.handled, lastResult: saved.lastResult)
  }

  public func save(_ applier: BoardOpApplier, board: String) {
    let saved = Saved(rev: applier.rev, handled: applier.handled, lastResult: applier.lastResult)
    if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: key(board)) }
  }

  private func idsKey(_ board: String) -> String { "whiteboard_stroke_ids_\(board)" }
  private func metaKey(_ board: String) -> String { "whiteboard_stroke_meta_\(board)" }
  private func headersKey(_ board: String) -> String { "whiteboard_headers_\(board)" }
  private func questionsKey(_ board: String) -> String { "whiteboard_questions_\(board)" }

  private func keys(_ board: String) -> [String] {
    [key(board), textsKey(board), idsKey(board), metaKey(board), headersKey(board), questionsKey(board)]
  }

  /// The board's meaning as these keys hold it; nil when it has none of them.
  public func meaning(board: String) -> BoardMeaning? {
    guard keys(board).contains(where: { defaults.object(forKey: $0) != nil }) else { return nil }
    var meaning = BoardMeaning()
    meaning.take(applier(board: board))
    meaning.texts = texts(board: board)
    meaning.strokeIDs = strokeIDs(board: board)
    meaning.strokeMeta = strokeMeta(board: board)
    meaning.headers = headers(board: board)
    meaning.questions =
      defaults.data(forKey: questionsKey(board)).flatMap {
        try? JSONDecoder().decode(WhiteboardQuestions.self, from: $0)
      }
      ?? WhiteboardQuestions()
    return meaning
  }

  /// The board's keys, gone once its file holds what they did.
  public func forget(board: String) {
    for key in keys(board) { defaults.removeObject(forKey: key) }
  }

  /// The board's headers and their folds (`BoardOutline`, story 855).
  public func headers(board: String) -> [BoardHeader] {
    defaults.data(forKey: headersKey(board)).flatMap { try? JSONDecoder().decode([BoardHeader].self, from: $0) } ?? []
  }

  public func setHeaders(_ headers: [BoardHeader], board: String) {
    if let data = try? JSONEncoder().encode(headers) { defaults.set(data, forKey: headersKey(board)) }
  }

  /// Larry's notes on the board's strokes (`BoardStrokeMeta`).
  public func strokeMeta(board: String) -> BoardStrokeMeta {
    defaults.data(forKey: metaKey(board)).flatMap { try? JSONDecoder().decode(BoardStrokeMeta.self, from: $0) }
      ?? BoardStrokeMeta()
  }

  public func setStrokeMeta(_ meta: BoardStrokeMeta, board: String) {
    if let data = try? JSONEncoder().encode(meta) { defaults.set(data, forKey: metaKey(board)) }
  }

  /// The names moved strokes keep (`BoardStrokeIDs`).
  public func strokeIDs(board: String) -> BoardStrokeIDs {
    defaults.data(forKey: idsKey(board)).flatMap { try? JSONDecoder().decode(BoardStrokeIDs.self, from: $0) }
      ?? BoardStrokeIDs()
  }

  public func setStrokeIDs(_ ids: BoardStrokeIDs, board: String) {
    if let data = try? JSONEncoder().encode(ids) { defaults.set(data, forKey: idsKey(board)) }
  }

  public func texts(board: String) -> [BoardText] {
    defaults.data(forKey: textsKey(board)).flatMap { try? JSONDecoder().decode([BoardText].self, from: $0) } ?? []
  }

  public func setTexts(_ texts: [BoardText], board: String) {
    if let data = try? JSONEncoder().encode(Array(texts.suffix(Self.mostTexts))) {
      defaults.set(data, forKey: textsKey(board))
    }
  }
}
