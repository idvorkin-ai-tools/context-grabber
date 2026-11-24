import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Story 1164 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 16): `bw_applier`'s steps leave
/// the app's own `BoardOpApplier` as the app's calls leave it, and decide each batch as it does, on the batches of the
/// Cockpit's recorded sessions and on seeded runs of changes, batches, lifts and reports.
final class WebApplierTests: XCTestCase {
  /// A step through JSON, as the module reads it.
  private func step(_ web: inout WebApplier, _ json: [String: Any]) throws -> [String: Any] {
    try web.step(JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: json)))
  }

  /// The app's decision in the reply's terms: its kind, and the label or key it names.
  private func kind(_ decision: BoardOpApplier.Decision?) -> [String] {
    switch decision {
    case nil: return []
    case .ignored(let why): return ["ignored", why]
    case .refused(let result):
      return ["refused", result.reason ?? "", (result.conflictIDs ?? []).joined(separator: ",")]
    case .held(let replaced): return ["held", replaced ?? ""]
    case .apply(let batch): return ["apply", batch.key, batch.rebasedFrom.map(String.init) ?? ""]
    }
  }

  private func kind(_ reply: [String: Any]) -> [String] {
    switch reply["decision"] as? String {
    case nil: return []
    case "ignored": return ["ignored", reply["why"] as? String ?? "?"]
    case "refused":
      let result = reply["result"] as? [String: Any] ?? [:]
      return [
        "refused", result["reason"] as? String ?? "",
        (result["conflict_ids"] as? [String] ?? []).joined(separator: ","),
      ]
    case "held": return ["held", reply["replaced"] as? String ?? ""]
    case "apply":
      return ["apply", reply["key"] as? String ?? "?", (reply["rebased_from"] as? Int).map(String.init) ?? ""]
    case let other: return [other ?? "?"]
    }
  }

  /// Larry's batches in the recorded sessions, in the order they came.
  private func recordedBatches() throws -> [(session: String, ops: [String: Any])] {
    var out: [(String, [String: Any])] = []
    for name in ["ops-move", "plain-draw", "question-card", "title-build"] {
      let text = try String(
        contentsOf: WebBoard.fixtures.appendingPathComponent("\(name).jsonl"), encoding: .utf8)
      for line in text.split(separator: "\n") {
        guard let step = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          step["step"] as? String == "reply",
          let row = (step["expect"] as? [String: Any])?["row"] as? [String: Any],
          let ops = row["ops"] as? [String: Any]
        else { continue }
        out.append((name, ops))
      }
    }
    return out
  }

  func testTheRecordedBatchesAreDecidedAsTheAppDecidesThem() throws {
    let batches = try recordedBatches()
    XCTAssertGreaterThanOrEqual(batches.count, 3, "the recorded sessions carry batches")
    for (i, (session, ops)) in batches.enumerated() {
      let base = JSONNumber(ops["base_rev"])?.intValue ?? 0
      let board = ops["board"] as? String ?? ""
      // A board at the batch's own look, then one his pen moved under since (its first name), then one Larry's own
      // batch changed: the batch applies, rebases or conflicts, as the app decides.
      for since in 0...2 {
        var app = BoardOpApplier(rev: base)
        var web = WebApplier()
        _ = try step(&web, ["step": "load", "rev": base])
        let named = BoardOps.namesUsed(BoardOps.batch(ops, key: "k", source: "web")?.ops ?? []).sorted()
        if since == 1 {
          app.changed()
          app.touched(named.prefix(1))
          _ = try step(&web, ["step": "changed", "ids": Array(named.prefix(1))])
        } else if since == 2 {
          app.changed()
          app.touched([], all: true)
          _ = try step(&web, ["step": "changed", "ids": [String](), "all": true])
        }
        let key = "\(session)-\(i)"
        let want = app.receive(
          try XCTUnwrap(BoardOps.batch(ops, key: key, source: "web")), board: board, editable: true, ready: true)
        let got = try step(&web, ["step": "receive", "key": key, "batch": ops, "board": board, "ready": true])
        XCTAssertEqual(kind(got), kind(want), "\(key) after change \(since)")
        XCTAssertEqual(web.applier, app, "\(key) after change \(since)")
      }
    }
  }

  /// A seeded run: the board changes (new ink, a move of some names, a batch of Larry's), batches arrive (based on now,
  /// an older look, or none; for this board or another; again), the Pencil lifts, the board reports; checked against
  /// the app's applier step by step.
  func testSeededRunsStepAsTheAppsApplier() throws {
    var decided: [String: Int] = [:]
    for seed in UInt64(1)...60 {
      var rng = Seeded(seed)
      var app = BoardOpApplier()
      var web = WebApplier()
      var sent: [String] = []
      // The batch the app let through last, as its board keeps it until the canvas answers.
      var letThrough: BoardOps.Batch?
      let names = ["a", "b", "c", "d", "e"]
      for n in 0..<80 {
        let pick = { () -> [String] in
          (0..<rng.int(0...2)).map { _ in names[rng.int(0...(names.count - 1))] }
        }
        switch rng.int(0...9) {
        case 0, 1:
          let ids = pick()
          let all = rng.int(0...5) == 0
          app.changed()
          app.touched(ids, all: all)
          _ = try step(&web, ["step": "changed", "ids": ids, "all": all])
        case 2, 3, 4:
          let resend = !sent.isEmpty && rng.int(0...5) == 0
          let key = resend ? sent[rng.int(0...(sent.count - 1))] : "m\(n)"
          sent.append(key)
          let base: Any = rng.int(0...7) == 0 ? NSNull() : max(0, app.rev - rng.int(0...3))
          let ids = pick() + ["a"]
          var list: [[String: Any]] = [["op": "translate", "ids": ids, "dx": 0, "dy": 10]]
          if rng.int(0...9) == 0 { list = [["op": "nope"]] }
          let ops: [String: Any] = [
            "board": rng.int(0...9) == 0 ? "other" : "B", "base_rev": base, "label": "l\(n)", "list": list,
          ]
          let ready = rng.int(0...2) > 0
          let editable = rng.int(0...11) > 0
          let json = try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: ops))
          let want = app.receive(
            try XCTUnwrap(BoardOps.batch(json, key: key, source: "web")), board: "B", editable: editable,
            ready: ready)
          let got = try step(
            &web, ["step": "receive", "key": key, "batch": ops, "board": "B", "editable": editable, "ready": ready])
          XCTAssertEqual(kind(got), kind(want), "seed \(seed) step \(n)")
          decided[kind(want).first ?? "none", default: 0] += 1
          if case .apply(let batch) = want { letThrough = batch }
        case 5, 6:
          let ready = rng.int(0...3) > 0
          let want = app.release(ready: ready)
          if case .apply(let batch) = want { letThrough = batch }
          let got = try step(&web, ["step": "release", "ready": ready])
          XCTAssertEqual(kind(got), kind(want), "seed \(seed) step \(n)")
        case 7, 8:
          // The board answers for what was let through, or for something else (late), as it may.
          let key = rng.int(0...4) == 0 ? "stray" : app.applying ?? "none"
          let batch =
            letThrough.flatMap { $0.key == key ? $0 : nil }
            ?? BoardOps.Batch(key: key, source: "web", board: "B", label: "", baseRev: 0, ops: [])
          let outcome = rng.int(0...3)
          let changes = rng.int(0...1) == 0
          var plan = BoardOps.Plan(pagesBefore: 1, pagesAfter: changes ? 2 : 1)
          plan.missingIDs = rng.int(0...3) == 0 ? ["gone"] : []
          let canvas: BoardCanvasOutcome =
            outcome == 0 ? .unavailable : outcome == 1 ? .failed(reason: "edit") : .applied(plan)
          if case .applied = canvas, changes { app.changed() }
          if case .applied = canvas, changes { _ = try step(&web, ["step": "changed", "ids": [String]()]) }
          let want = app.report(batch, canvas)
          let got = try step(
            &web,
            [
              "step": "report", "key": key, "outcome": ["unavailable", "failed", "applied", "applied"][outcome],
              "reason": "edit", "changes_board": changes, "missing_ids": plan.missingIDs,
            ])
          switch want {
          case .late: XCTAssertEqual(got["report"] as? String, "late", "seed \(seed) step \(n)")
          case .applied(let result):
            XCTAssertEqual(got["report"] as? String, "applied")
            XCTAssertEqual(
              (got["result"] as? [String: Any]).map(NSDictionary.init), NSDictionary(dictionary: result.wire))
          case .refused(let result, let why):
            XCTAssertEqual(got["canvas"] as? String, why)
            XCTAssertEqual(
              (got["result"] as? [String: Any]).map(NSDictionary.init), NSDictionary(dictionary: result.wire))
          }
        default:
          if rng.int(0...1) == 0 {
            let want = app.dropHeld(reason: "closed")
            let got = try step(&web, ["step": "drop_held", "reason": "closed"])
            XCTAssertEqual(got["result"] is NSNull, want == nil, "seed \(seed) step \(n)")
          } else {
            app.closed()
            _ = try step(&web, ["step": "closed"])
          }
        }
        XCTAssertEqual(web.applier, app, "seed \(seed) step \(n)")
      }
    }
    for kind in ["apply", "held", "refused", "ignored"] {
      XCTAssertGreaterThan(decided[kind] ?? 0, 20, "the seeded runs reach \(kind): \(decided)")
    }
  }

  func testLoadKeepsWhatTheBoardRemembersAndTheStateSaysIt() throws {
    var web = WebApplier()
    let reply = try step(
      &web,
      [
        "step": "load", "rev": 7, "since": 5, "handled": ["m1"],
        "touches": [["rev": 6, "ids": ["b", "a"], "all": false]],
        "last_result": ["label": "l", "ok": false, "rev": 6, "reason": "stale", "conflict_ids": ["a"]],
      ])
    let want = BoardOpApplier(
      rev: 7, handled: ["m1"],
      lastResult: BoardOps.Result(label: "l", ok: false, rev: 6, reason: "stale", conflictIDs: ["a"]),
      touches: try JSONDecoder().decode(
        [BoardOpApplier.Touch].self, from: Data(#"[{"rev": 6, "ids": ["a", "b"], "all": false}]"#.utf8)),
      since: 5)
    XCTAssertEqual(web.applier, want)
    let state = try XCTUnwrap(reply["state"] as? [String: Any])
    XCTAssertEqual(state["rev"] as? Int, 7)
    XCTAssertEqual(state["since"] as? Int, 5)
    XCTAssertEqual(state["touches"] as? [[String: AnyHashable]], [["rev": 6, "ids": ["a", "b"], "all": false]])
    XCTAssertThrowsError(try step(&web, ["step": "nope"]))
    XCTAssertThrowsError(try step(&web, ["step": "report", "outcome": "maybe"]))
  }
}
