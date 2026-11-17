//  The one place a board's changes are checked, held and recorded, whoever sent them (spec
//  2026-11-16-whiteboard-board-ops-design.md, stories 816, 819): the board's revision, the batches already handled, the
//  one held for the Pencil, and what came of the last. The board's model plans and applies what this lets through
//  (`BoardOps.plan`, then PaperKit) and hands the time and the Pencil in.

import Foundation

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

  public init(rev: Int = 0, handled: [String] = [], lastResult: BoardOps.Result? = nil) {
    self.rev = rev
    self.handled = handled
    self.lastResult = lastResult
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

  /// A batch arrived. `ready`: the Pencil lets ink move now (`BoardOps.readiness`). The revision is checked here, on
  /// arrival: a batch held for the Pencil applies on the lift to the board as it is then, the stroke just drawn included.
  public mutating func receive(_ batch: BoardOps.Batch, board: String, editable: Bool, ready: Bool) -> Decision {
    guard !handled.contains(batch.key) else { return .ignored(why: "handled") }
    remember(batch.key)
    if let refusal = batch.refusal { return refuse(batch, refusal) }
    guard batch.board == board else { return .ignored(why: "other_board") }
    guard editable else { return refuse(batch, BoardOps.Reason.lookOnly) }
    guard batch.baseRev == rev else { return refuse(batch, BoardOps.Reason.stale) }
    if ready { return .apply(batch) }
    let replaced = held?.label
    if let older = held { _ = refusal(older, BoardOps.Reason.superseded) }
    held = batch
    return .held(replaced: replaced)
  }

  /// The held batch, once the Pencil lets it apply.
  public mutating func release(ready: Bool) -> BoardOps.Batch? {
    guard ready, let batch = held else { return nil }
    held = nil
    return batch
  }

  /// The board went away with a batch still held: it never applies, and Larry is told.
  public mutating func dropHeld(reason: String) -> BoardOps.Result? {
    guard let batch = held else { return nil }
    held = nil
    return refusal(batch, reason)
  }

  /// `batch` was applied as planned; the board's own change (if any) has already bumped `rev`.
  @discardableResult
  public mutating func applied(_ batch: BoardOps.Batch, plan: BoardOps.Plan) -> BoardOps.Result {
    let result = BoardOps.Result(
      label: batch.label, ok: true, rev: rev, missingIDs: plan.missingIDs.isEmpty ? nil : plan.missingIDs)
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

/// Each board's revision, handled batches, last result and kept texts on this device, by board id. ponytail:
/// UserDefaults on this device, as `WhiteboardThreads`; it moves to the board's file if boards ever change hands.
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
