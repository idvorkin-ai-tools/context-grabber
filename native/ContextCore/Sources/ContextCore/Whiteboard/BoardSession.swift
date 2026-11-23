//  A recorded board session (the Cockpit's board contract v1, *Recorded sessions*; bead context-grabber-09tx, stories
//  1182, 1183): one real board conversation, what the iPad posted in its order, what Larry replied and the receipts, as the
//  Cockpit's `board/session.py` writes it. The Cockpit replays the same files through its server, Larry's skill dry-runs
//  them, and here the board's own rules replay them: each of Larry's batches is tried on the board as it stood when it
//  arrived (`BoardReplay`) and set beside the answer the iPad really sent on its next turn, his marks show as for one
//  reply, and each turn's board fields are put as the Cockpit's hint to Larry puts them. The copy in this repository is
//  scrubbed (`scripts/native/board-sessions.py`): ids, counts, revisions, events and changes as recorded, no words.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct BoardSession {
  /// The contract version this replay reads (`board.session.CONTRACT_VERSION` on the Cockpit).
  public static let contractVersion = 1

  public struct Unreadable: Error, CustomStringConvertible {
    public let description: String
  }

  public let name: String
  public let thread: String
  public let board: String
  public let contract: Int
  /// Every step after the header, as recorded.
  public let steps: [[String: Any]]

  /// A session's JSONL: its header, then one step per line.
  public init(jsonl data: Data) throws {
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").filter {
      !$0.trimmingCharacters(in: .whitespaces).isEmpty
    }
    let all = try lines.enumerated().map { index, line -> [String: Any] in
      guard let step = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
        throw Unreadable(description: "line \(index + 1) is not a JSON object")
      }
      return step
    }
    guard let header = all.first, header["step"] as? String == "header" else {
      throw Unreadable(description: "a session starts with its header")
    }
    guard let thread = header["thread"] as? String, let board = header["board"] as? String else {
      throw Unreadable(description: "the header names no thread or board")
    }
    name = header["name"] as? String ?? ""
    self.thread = thread
    self.board = board
    contract = (header["contract"] as? NSNumber)?.intValue ?? 0
    steps = Array(all.dropFirst())
  }

  // MARK: Igor's turns

  /// One of Igor's turns on the board: the board fields of its chat message and its strokes post's counts.
  public struct Turn: Equatable, Sendable {
    public var id: String
    /// The message names the board; a plain words message on a board thread doesn't, and wakes Larry with no board hint.
    public var onBoard: Bool
    public var picture: String?
    public var rev: Int?
    public var opResult: BoardOps.Result?
    public var events: Int
    public var eventsDropped: Int?
    /// The strokes post's answer: how many, and how many new since the board's send before (nil: none was posted).
    public var strokes: Int?
    public var new: Int?

    /// The board half of the Cockpit's hint to Larry for this turn (board contract, *What wakes the agent*), from
    /// `· board` on.
    public func hint(board: String, thread: String) -> String {
      var out = "· board \(board) · draw back: chat.py reply --shapes"
      if let rev { out += " · rev \(rev) (move it: chat.py reply --ops, base_rev \(rev))" }
      if let result = opResult {
        let state = result.ok ? "ok" : "refused (\(result.reason ?? "?"))"
        var line = " · op_result \(state) for \(Self.quoted(result.label)) at rev \(result.rev)"
        if let missing = result.missingIDs, !missing.isEmpty { line += ", \(missing.count) ids missing" }
        out += line
      }
      if events > 0 { out += " · \(events) events: whiteboard_events.py show \(board) --thread \(thread)" }
      if let strokes, let picture {
        out += " · strokes \(strokes) (\(new ?? 0) new): whiteboard_strokes.py render \(board) \(picture) --thread"
        out += " \(thread) --out <png>"
      }
      return out
    }

    /// A label as the Cockpit's hint quotes it (Python's repr): in single quotes, or double when it holds a single one.
    static func quoted(_ label: String) -> String {
      label.contains("'") && !label.contains("\"") ? "\"\(label)\"" : "'\(label)'"
    }
  }

  /// One of Larry's batches tried on the board as it stood when the batch arrived.
  public struct Batch: Equatable, Sendable {
    /// The reply that carried it.
    public var reply: String
    public var label: String
    /// The board's revision when it arrived: Igor's strokes since the reply's look included.
    public var arrivedAt: Int
    /// What the board's own rules answer now.
    public var replayed: BoardOps.Result?
    /// What the iPad answered on its next turn; nil when the session ends before one.
    public var recorded: BoardOps.Result?

    /// The fields Larry reads: label, ok, rev, reason, missing ids, the revision it was rebased from, and the room used
    /// when the recording has it (story 1195; older recordings don't).
    public var matches: Bool {
      guard let replayed, let recorded else { return recorded == nil }
      return replayed.label == recorded.label && replayed.ok == recorded.ok && replayed.rev == recorded.rev
        && replayed.reason == recorded.reason && (replayed.missingIDs ?? []) == (recorded.missingIDs ?? [])
        && replayed.rebasedFrom == recorded.rebasedFrom && (recorded.rooms == nil || replayed.rooms == recorded.rooms)
    }
  }

  /// What a replay found.
  public struct Report {
    public var turns: [Turn] = []
    public var batches: [Batch] = []
    /// Larry's replies with marks, as the board shows them (`BoardReplay`'s outcomes: shown, said or unplaced).
    public var marks: [BoardReplay.Outcome] = []
    /// Every place the replay and the recording part, in words; empty when they agree.
    public var mismatches: [String] = []

    public var wire: [String: Any] {
      [
        "turns": turns.map { turn -> [String: Any] in
          var out: [String: Any] = ["id": turn.id, "events": turn.events]
          if let picture = turn.picture { out["picture_id"] = picture }
          if let rev = turn.rev { out["rev"] = rev }
          if let result = turn.opResult { out["op_result"] = result.wire }
          if let strokes = turn.strokes { out["strokes"] = strokes }
          if let new = turn.new { out["new"] = new }
          return out
        },
        "batches": batches.map { batch -> [String: Any] in
          var out: [String: Any] = [
            "reply": batch.reply, "label": batch.label, "arrived_at": batch.arrivedAt, "matches": batch.matches,
          ]
          if let replayed = batch.replayed { out["replayed"] = replayed.wire }
          if let recorded = batch.recorded { out["recorded"] = recorded.wire }
          return out
        },
        "marks": marks.map(\.wire),
        "mismatches": mismatches,
      ]
    }
  }

  // MARK: The replay

  /// One of Igor's ink changes, from a turn's `strokes_changed` events.
  private struct Change {
    var t: Int64
    var rev: Int
    var ids: [String]
  }

  /// The whole session through the board's own rules.
  public func replay() -> Report {
    var report = Report()
    if contract != Self.contractVersion {
      report.mismatches.append("contract \(contract), this replay reads \(Self.contractVersion)")
    }
    let changes = steps.filter(isChat).flatMap { step -> [Change] in
      (body(step)["events"] as? [[String: Any]] ?? []).compactMap { event in
        guard event["type"] as? String == "strokes_changed", let t = (event["t"] as? NSNumber)?.int64Value,
          let rev = (event["rev"] as? NSNumber)?.intValue
        else { return nil }
        // Moves and erasures are what can conflict with a batch; new strokes never do (BoardOpApplier.touched).
        let ids = ["moved", "erased"].flatMap { event[$0] as? [String] ?? [] }
        return Change(t: t, rev: rev, ids: ids)
      }
    }
    var previous: Set<String>?
    var answers: [String: (count: Int, new: Int)] = [:]
    var looked: BoardSnapshot?
    var lastRev: Int?
    for (index, step) in steps.enumerated() {
      switch step["step"] as? String {
      case "post" where isStrokes(step):
        let body = body(step)
        guard let snapshot = try? BoardSnapshot(json: body) else {
          report.mismatches.append("strokes post \(index + 1) doesn't read as the board's snapshot")
          continue
        }
        let ids = Set(snapshot.ink.map(\.id) + snapshot.texts.map(\.id))
        let new = previous.map { ids.subtracting($0).count } ?? ids.count
        previous = ids
        looked = snapshot
        guard let picture = body["picture_id"] as? String, step["expect"] is [String: Any] else { continue }
        answers[picture] = (ids.count, new)
        if let want = (step["expect"] as? [String: Any])?["response"] as? [String: Any],
          (want["count"] as? NSNumber)?.intValue != ids.count || (want["new"] as? NSNumber)?.intValue != new
        {
          report.mismatches.append("strokes \(picture): \(ids.count) (\(new) new), the Cockpit answered \(want)")
        }
      case "post" where isChat(step):
        let body = body(step)
        let picture = body["picture_id"] as? String
        let answer = picture.flatMap { answers[$0] }
        let turn = Turn(
          id: body["id"] as? String ?? "", onBoard: body["board"] != nil, picture: picture,
          rev: (body["rev"] as? NSNumber)?.intValue,
          opResult: Self.result(body["op_result"]), events: (body["events"] as? [Any])?.count ?? 0,
          eventsDropped: (body["events_dropped"] as? NSNumber)?.intValue, strokes: answer?.count, new: answer?.new)
        if turn.events > BoardTurnReport.maxEvents {
          report.mismatches.append("turn \(turn.id) carries \(turn.events) events, over \(BoardTurnReport.maxEvents)")
        }
        lastRev = turn.rev ?? lastRev
        if var snapshot = looked, let rev = turn.rev, snapshot.rev == nil {
          snapshot.rev = rev
          looked = snapshot
        }
        report.turns.append(turn)
      case "reply":
        guard let row = (step["expect"] as? [String: Any])?["row"] as? [String: Any] else { continue }
        guard let read = WhiteboardMarks.row(row) else {
          report.mismatches.append("reply \(index + 1) doesn't read as Larry's row")
          continue
        }
        if !read.shapes.isEmpty || row["shapes"] != nil {
          var marks = BoardReplay(looked ?? BoardSnapshot(board: board))
          marks.run([.marks(read)])
          report.marks += marks.outcomes
        }
        if read.ops != nil, let ops = row["ops"] as? [String: Any] {
          let batch = tryBatch(
            ops, reply: read.id, at: Self.millis(step["at"]), on: looked, lastRev: lastRev, changes: changes,
            after: index)
          if !batch.matches {
            report.mismatches.append(
              "batch \(batch.reply) '\(batch.label)': replayed \(batch.replayed?.wire.description ?? "nothing"),"
                + " the iPad answered \(batch.recorded?.wire.description ?? "nothing")")
          }
          report.batches.append(batch)
        }
      default: continue
      }
    }
    return report
  }

  /// A batch on the board Larry looked at, at the revision the board had when it arrived, with Igor's moves and
  /// erasures since his look (story 961), and the answer the iPad sent on its next turn (not the last one it sent
  /// before the reply, which it repeats on every turn until it fetches the batch). When it arrived is what that
  /// answer says (a refusal names the board's revision, an applied change the one after it): the Cockpit's clock says
  /// when Larry wrote the batch, not when the iPad fetched it. With no answer, the newest of Igor's changes before the
  /// reply's time.
  private func tryBatch(
    _ ops: [String: Any], reply: String, at: Int64?, on looked: BoardSnapshot?, lastRev: Int?, changes: [Change],
    after index: Int
  ) -> Batch {
    let label = ops["label"] as? String ?? ""
    let base = (ops["base_rev"] as? NSNumber)?.intValue ?? lastRev ?? 0
    let repeated = steps[..<index].last(where: isChat).flatMap { Self.result(body($0)["op_result"]) }
    let recorded = steps[(index + 1)...].lazy.filter(isChat).compactMap { Self.result(body($0)["op_result"]) }
      .first { $0.label == label && $0 != repeated }
    let before = changes.filter { change in at.map { change.t <= $0 } ?? false }.map(\.rev).max()
    let arrived =
      recorded.map { $0.ok ? max(base, $0.rev - 1) : $0.rev } ?? max(lastRev ?? base, before ?? base)
    var snapshot = looked ?? BoardSnapshot(board: board)
    snapshot.rev = arrived
    // Every revision from his look on is one the board remembers (an empty first one says where they start), and those
    // that moved or erased Igor's things name them; the events a turn dropped to fit are unknown, so untouched.
    let touched = changes.filter { $0.rev > base && $0.rev <= arrived && !$0.ids.isEmpty }.map {
      BoardSnapshot.Touch(rev: $0.rev, ids: $0.ids)
    }
    snapshot.touched = arrived > base ? [BoardSnapshot.Touch(rev: base + 1, ids: [])] + touched : []
    var replay = BoardReplay(snapshot)
    replay.run([.batch(key: reply, json: ops)])
    return Batch(
      reply: reply, label: label, arrivedAt: arrived, replayed: replay.outcomes.last?.result, recorded: recorded)
  }

  private func body(_ step: [String: Any]) -> [String: Any] { step["body"] as? [String: Any] ?? [:] }

  private func isStrokes(_ step: [String: Any]) -> Bool {
    step["step"] as? String == "post" && step["route"] as? String == "/whiteboard/strokes"
  }

  private func isChat(_ step: [String: Any]) -> Bool {
    step["step"] as? String == "post" && (step["route"] as? String)?.hasPrefix("/chat/") == true
  }

  /// An `op_result` as the iPad sends it.
  static func result(_ any: Any?) -> BoardOps.Result? {
    guard let json = any as? [String: Any], let label = json["label"] as? String, let ok = json["ok"] as? Bool,
      let rev = (json["rev"] as? NSNumber)?.intValue
    else { return nil }
    return BoardOps.Result(
      label: label, ok: ok, rev: rev, reason: json["reason"] as? String, missingIDs: json["missing_ids"] as? [String],
      rebasedFrom: (json["rebased_from"] as? NSNumber)?.intValue, conflictIDs: json["conflict_ids"] as? [String],
      rooms: (json["room"] as? [Any])?.compactMap(BoardOps.Room.init(wire:)))
  }

  /// A step's `at` (ISO 8601, as the Cockpit stores it) in unix ms.
  static func millis(_ any: Any?) -> Int64? {
    guard let text = any as? String else { return nil }
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime]
    var date = parser.date(from: text)
    if date == nil {
      parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      date = parser.date(from: text)
    }
    return date.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) }
  }
}
