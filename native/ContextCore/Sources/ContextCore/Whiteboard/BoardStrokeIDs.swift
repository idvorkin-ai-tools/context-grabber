//  A stroke keeps its name through a move (spec 2026-11-16-whiteboard-board-ops-design.md, stories 814, 815; Larry on
//  thread igor2-88g.1499: his connectors and his "new since my last reply" key on stroke ids). A stroke's id is a hash of
//  its ink (`WhiteboardStrokes.id`), so a moved stroke would hash anew; this remembers, for each moved stroke's new hash,
//  the name it had before. Only a change of the ink itself (drawn, erased, partly erased) gives a new name. Undo and
//  redo land on hashes already known, so they keep the name too.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardStrokeIDs: Equatable, Codable, Sendable {
  /// The most names remembered; past it the oldest go, and a stroke moved that long ago is named by its hash again.
  public static let most = 20_000

  /// New hash to the name it keeps, oldest first.
  private var names: [String: String] = [:]
  private var order: [String] = []

  public init() {}

  /// The name Larry knows the stroke whose ink hashes to `hash` by.
  public func stable(_ hash: String) -> String { names[hash] ?? hash }

  /// Strokes moved: each stretch that hashed to `from[i]` now hashes to `to[i]`, and keeps its name. Pairs whose counts
  /// differ (the ink itself changed) are left alone.
  public mutating func moved(from: [String], to: [String]) {
    guard from.count == to.count else { return }
    for (old, new) in zip(from, to) where old != new {
      let name = stable(old)
      if names[new] == nil { order.append(new) }
      names[new] = name == new ? nil : name
    }
    if order.count > Self.most {
      for hash in order.prefix(order.count - Self.most) { names[hash] = nil }
      order.removeFirst(order.count - Self.most)
    }
  }

  /// A stroke Larry drew (story 840): known by the name he gave it.
  public mutating func name(_ hash: String, as name: String) {
    guard hash != name else { return }
    if names[hash] == nil { order.append(hash) }
    names[hash] = name
  }

  /// `strokes` named as Larry knows them.
  public func named(_ strokes: [WhiteboardStrokes.Stroke]) -> [WhiteboardStrokes.Stroke] {
    guard !names.isEmpty else { return strokes }
    return strokes.map { stroke in
      var named = stroke
      named.id = stable(stroke.id)
      return named
    }
  }
}
