//  Checks 3 and 4 (spec 2026-11-23-board-interaction-review-design.md, *The checks*; stories 1252, 1253): Igor's ink
//  moved without his aim, a selection stretched by a drag, and both owners' ink left moved together. Each judges the
//  board once the step has settled (an owners-apart step right after it included), and intent is the step's aim plus
//  what the room and drop rules say it pushes.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension BoardReview {
  /// Steps whose moves are another check's business, or a rule's own slide: folds, and Undo and Redo (check 6).
  static let notMoves: Set<String> = ["fold", "unfold", "undo", "redo"]

  /// The push a step's rules call for: the room it asked for, or the room a drop calls for.
  static func push(_ pass: Pass, _ group: [Int]) -> (cut: Double, dy: Double)? {
    let step = pass.steps[group[0]]
    if let room = step.room { return (room.cut, room.dy) }
    if step.kind == "drop" { return dropRoom(pass, group).predicted }
    return nil
  }

  /// Check 3: Igor's strokes move only when the step was aimed at them or a rule pushed them as it says; a drag that
  /// began inside a selection never changes its size (story 1201), and one from a corner knob that did is asked about.
  static func movedWithoutAim(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    for group in pass.groups {
      let i = group[0]
      let step = pass.steps[i]
      guard !notMoves.contains(step.kind) else { continue }
      let start = pass.states[i]
      let end = pass.settled(group)
      let aimed = Set(step.aim?.ids ?? [])
      let rule = push(pass, group)

      // A selection dragged that changed size.
      if ["move", "drop"].contains(step.kind), !aimed.isEmpty,
        let from = union(aimed.sorted().compactMap { start.units[$0]?.box }),
        let to = union(aimed.sorted().compactMap { end.units[$0]?.box }), resized(from, to)
      {
        let evidence = [
          Evidence("selection", "\(many(strokes(Array(aimed), in: start))): \(list(Array(aimed)))"),
          Evidence("before", box(from)), Evidence("after", box(to)),
          Evidence("size", "\(num(to.w - from.w)) wide, \(num(to.h - from.h)) high"),
          Evidence("drag began", step.aim?.start ?? "unknown"),
        ]
        if step.aim?.start == "inside" {
          out.append(
            pass.finding(
              3, .bug, step: i, story: 1201, ids: Array(aimed),
              "a drag from inside the selection stretched it by \(num(to.w - from.w)) pt", evidence))
        } else {
          out.append(
            pass.finding(
              3, .unclear, step: i, story: 1201, ids: Array(aimed),
              "a drag from the selection's \(step.aim?.start ?? "edge") stretched it by \(num(to.w - from.w)) pt;"
                + " did you mean to?", evidence))
        }
      }

      // Igor's strokes moved that the step wasn't aimed at.
      let (wrongPush, unaimed) = igorMoves(start, end, aimed: aimed, cut: rule?.cut, dy: rule?.dy)
      if !wrongPush.isEmpty, let rule {
        out.append(
          pass.finding(
            3, .bug, step: i, story: step.kind == "drop" ? 973 : 858, ids: wrongPush,
            "\(strokes(wrongPush, in: start)) of your strokes were pushed other than the rules say",
            [Evidence("rules", "down \(num(rule.dy)) from \(num(rule.cut))")]
              + moveEvidence(wrongPush, start, end)))
      }
      if !unaimed.isEmpty {
        let fromHandle = step.by == "system" && aimed.isEmpty && ["handle", "knob"].contains(step.aim?.start ?? "")
        out.append(
          pass.finding(
            3, fromHandle ? .unclear : .bug, step: i, story: 1252, ids: unaimed,
            fromHandle
              ? "the system moved \(strokes(unaimed, in: start)) of your strokes from a handle; did you mean to?"
              : "\(strokes(unaimed, in: start)) of your strokes moved that the step wasn't aimed at",
            moveEvidence(unaimed, start, end)))
      }
    }
    return out
  }

  /// Igor's strokes that moved without the step's aim: those under the rule's cut that didn't move as it says, and the
  /// rest. Kept out of `movedWithoutAim` and given the rule as plain values: Swift 6.4.2's Release optimizer crashes
  /// (CopyPropagation's ownership verifier) on the optional tuple bound inside that loop (bead context-grabber-6ocd).
  static func igorMoves(
    _ start: State, _ end: State, aimed: Set<String>, cut: Double?, dy: Double?
  ) -> (wrongPush: [String], unaimed: [String]) {
    var wrongPush: [String] = []
    var unaimed: [String] = []
    for id in start.units.keys.sorted() where !aimed.contains(id) {
      guard let was = start.units[id], was.owner == "igor", let now = end.units[id], moved(was.box, now.box)
      else { continue }
      if let cut, let dy, was.box.y >= cut - tolerance {
        let ok =
          abs(now.box.y - was.box.y - dy) <= tolerance && abs(now.box.x - was.box.x) <= tolerance
          && !resized(was.box, now.box)
        if !ok { wrongPush.append(id) }
      } else {
        unaimed.append(id)
      }
    }
    return (wrongPush, unaimed)
  }

  /// Check 4: one step never leaves both owners' ink moved together unless he aimed at both; put apart by the rules
  /// is as designed (stories 1145, 1146).
  static func ownersTogether(_ pass: Pass) -> [Finding] {
    var out: [Finding] = []
    for group in pass.groups {
      let i = group[0]
      let step = pass.steps[i]
      guard !notMoves.contains(step.kind), step.room == nil, step.kind != "drop" else { continue }
      let start = pass.states[i]
      let first = pass.states[i + 1]
      let end = pass.settled(group)
      let aimed = Set(step.aim?.ids ?? [])
      let aimedOwners = Set(aimed.compactMap { start.units[$0]?.owner })
      func movers(_ to: State) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for (id, was) in start.units {
          guard let now = to.units[id], moved(was.box, now.box) else { continue }
          out[was.owner, default: []].append(id)
        }
        return out
      }
      let moving = movers(first)
      guard moving.count >= 2, aimedOwners.count < 2 else { continue }
      let settled = movers(end)
      let owners = moving.keys.sorted()
      var evidence = owners.map { owner in
        Evidence("\(owner) moved", "\(many(strokes(moving[owner] ?? [], in: start)))")
      }
      let back = owners.filter { settled[$0] == nil }
      if settled.count >= 2 {
        let ids = settled.values.flatMap { $0 }
        out.append(
          pass.finding(
            4, .bug, step: i, story: 1145, ids: ids,
            "one step left \(owners.joined(separator: " and "))'s ink moved together", evidence))
      } else {
        evidence.append(Evidence("went back", back.joined(separator: ", ")))
        let ids = moving.values.flatMap { $0 }
        out.append(
          pass.finding(
            4, .asDesigned, step: i, story: 1145, ids: ids,
            "a move of both owners' ink was put apart: \(back.joined(separator: ", "))'s went back", evidence))
      }
    }
    return out
  }

  static func moveEvidence(_ ids: [String], _ start: State, _ end: State) -> [Evidence] {
    var dxs: [Double] = []
    var dys: [Double] = []
    for id in ids {
      guard let a = start.units[id]?.box, let b = end.units[id]?.box else { continue }
      dxs.append(b.x - a.x)
      dys.append(b.y - a.y)
    }
    let alike = (dxs.max() ?? 0) - (dxs.min() ?? 0) <= tolerance && (dys.max() ?? 0) - (dys.min() ?? 0) <= tolerance
    return [
      Evidence("moved", "\(many(strokes(ids, in: start))): \(list(ids))"),
      Evidence("dx", "\(num(dxs.min() ?? 0))..\(num(dxs.max() ?? 0))"),
      Evidence("dy", "\(num(dys.min() ?? 0))..\(num(dys.max() ?? 0))"),
      Evidence("alike", alike ? "yes" : "no"),
    ]
  }
}
