//  The board's revision and Larry's batches let through, held or refused, for the Cockpit's ink board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, version 16): the app's `BoardOpApplier`, kept in the
//  module as the loaded board is, stepped by the host. Only the export is WASI's; the steps build everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

struct WebApplier {
  var applier = BoardOpApplier()
  /// The batch let through to apply, by its key, until its report comes.
  var letThrough: BoardOps.Batch?

  static func strings(_ any: Any?) -> [String] { (any as? [Any] ?? []).compactMap { $0 as? String } }

  /// What the applier remembers, for the host to keep with the board and to see.
  var state: [String: Any] {
    [
      "rev": applier.rev, "since": applier.since, "handled": applier.handled,
      "touches": applier.touches.map { ["rev": $0.rev, "ids": $0.ids.sorted(), "all": $0.all] as [String: Any] },
      "held": applier.held?.label as Any? ?? NSNull(), "applying": applier.applying as Any? ?? NSNull(),
      "last_result": applier.lastResult?.wire as Any? ?? NSNull(),
    ]
  }

  mutating func decision(_ decision: BoardOpApplier.Decision?) -> [String: Any] {
    switch decision {
    case nil:
      return ["decision": NSNull()]
    case .ignored(let why):
      return ["decision": "ignored", "why": why]
    case .refused(let result):
      return ["decision": "refused", "result": result.wire]
    case .held(let replaced):
      return ["decision": "held", "replaced": replaced as Any? ?? NSNull()]
    case .apply(let batch):
      letThrough = batch
      return [
        "decision": "apply", "key": batch.key, "label": batch.label,
        "rebased_from": batch.rebasedFrom as Any? ?? NSNull(),
      ]
    }
  }

  /// One step, `{"step", ...}`, answered with what came of it and the applier's state after:
  /// - `load` `{"rev", "handled", "touches": [{"rev", "ids", "all"}], "since", "last_result"}`: the applier as the
  ///   board last kept it (a fresh one when nothing is given)
  /// - `changed` `{"ids", "all"}`: the board's ink changed, moving, erasing or dissolving `ids` (none for new ink
  ///   alone); `all` for a batch of Larry's that changed it
  /// - `receive` `{"key", "batch", "board", "editable", "ready"}`: a batch arrived (`decision`)
  /// - `release` `{"ready"}`: the Pencil lifted (`decision`, null with nothing held or not ready)
  /// - `report` `{"key", "outcome": "applied" | "unavailable" | "failed", "reason", "changes_board", "missing_ids",
  ///   "rooms"}`: what the board made of the batch let through (`report`: `applied`, `refused` or `late`)
  /// - `drop_held` `{"reason"}`: the board went away with a batch held (`result`, or null)
  /// - `closed`: the board closed; an answer still to come no longer counts
  mutating func step(_ any: Any?) throws -> [String: Any] {
    guard let json = any as? [String: Any], let step = json["step"] as? String else {
      throw WebOutlineUnreadable(description: "a step is {\"step\", ...}")
    }
    var out: [String: Any] = [:]
    switch step {
    case "load":
      // The board's own coding of each touch: {"rev", "ids", "all"}.
      let listed: [Any] = json["touches"] as? [Any] ?? []
      let touches: [BoardOpApplier.Touch]
      do {
        touches = try JSONDecoder().decode(
          [BoardOpApplier.Touch].self, from: JSONSerialization.data(withJSONObject: listed))
      } catch {
        throw WebOutlineUnreadable(description: "the touches could not be read: \(error)")
      }
      applier = BoardOpApplier(
        rev: JSONNumber(json["rev"])?.intValue ?? 0, handled: Self.strings(json["handled"]),
        lastResult: BoardOps.Result(wire: json["last_result"]), touches: touches, since: JSONNumber(json["since"])?.intValue)
      letThrough = nil
    case "changed":
      applier.changed()
      applier.touched(Self.strings(json["ids"]), all: json["all"] as? Bool ?? false)
    case "receive":
      let key = json["key"] as? String ?? ""
      guard let batch = BoardOps.batch(json["batch"], key: key, source: "web") else {
        throw WebOutlineUnreadable(description: "the batch is not an object")
      }
      out = decision(
        applier.receive(
          batch, board: json["board"] as? String ?? "", editable: json["editable"] as? Bool ?? true,
          ready: json["ready"] as? Bool ?? true))
    case "release":
      out = decision(applier.release(ready: json["ready"] as? Bool ?? true))
    case "report":
      // Only the batch let through, by its key, counts; any other is answered late, as the app answers it.
      let key = json["key"] as? String ?? ""
      let batch =
        letThrough.flatMap { $0.key == key ? $0 : nil }
        ?? BoardOps.Batch(key: key, source: "web", board: nil, label: "", baseRev: nil, ops: [])
      let outcome: BoardCanvasOutcome
      switch json["outcome"] as? String {
      case "applied":
        // The host says whether the board changed; the plan stands for that with its pages (any change would do).
        let changes = json["changes_board"] as? Bool ?? false
        var plan = BoardOps.Plan(pagesBefore: 1, pagesAfter: changes ? 2 : 1)
        plan.missingIDs = Self.strings(json["missing_ids"])
        plan.rooms = (json["rooms"] as? [Any] ?? []).compactMap(BoardOps.Room.init(wire:))
        outcome = .applied(plan)
      case "unavailable": outcome = .unavailable
      case "failed": outcome = .failed(reason: json["reason"] as? String ?? "")
      default: throw WebOutlineUnreadable(description: "the outcome is applied, unavailable or failed")
      }
      switch applier.report(batch, outcome) {
      case .applied(let result): out = ["report": "applied", "result": result.wire]
      case .refused(let result, let canvas): out = ["report": "refused", "result": result.wire, "canvas": canvas]
      case .late: out = ["report": "late"]
      }
      if letThrough?.key == key { letThrough = nil }
    case "drop_held":
      out = ["result": applier.dropHeld(reason: json["reason"] as? String ?? "")?.wire as Any? ?? NSNull()]
    case "closed":
      applier.closed()
    default:
      throw WebOutlineUnreadable(description: "no step \(step)")
    }
    out["state"] = state
    return out
  }
}

#if os(WASI)
  var webApplier = WebApplier()

  /// One step of the board's applier (`WebApplier.step`), as a reply; `{"error"}` when it can't be read.
  @_expose(wasm, "bw_applier")
  @_cdecl("bw_applier")
  public func bwApplier(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    do {
      return reply(json: try webApplier.step(JSONSerialization.jsonObject(with: input(pointer, length))))
    } catch {
      return reply(json: ["error": "the step could not be read: \(error)"])
    }
  }
#endif
