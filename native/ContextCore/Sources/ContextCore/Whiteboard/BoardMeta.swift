//  Larry's notes on his strokes (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry groups ink*, story 842): kept
//  exactly as he wrote them and given back with the strokes, never read by the board except `group`, which makes
//  strokes move as one.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardMeta: Equatable, Codable, Sendable {
  /// The JSON object as Larry wrote it (keys sorted, so the same notes compare equal).
  public let json: Data
  /// The one note the board reads: strokes with the same group move as one.
  public let group: String?

  /// A JSON object; nil for anything else.
  public init?(_ any: Any?) {
    guard let object = any as? [String: Any], JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else { return nil }
    json = data
    group = (object["group"] as? String).flatMap { $0.isEmpty ? nil : $0 }
  }

  /// As it goes back to Larry.
  public var object: Any { (try? JSONSerialization.jsonObject(with: json)) ?? [String: Any]() }

  /// The same note without its group (story 854); nil when the group was all it said.
  public var withoutGroup: BoardMeta? {
    guard var object = object as? [String: Any] else { return nil }
    object["group"] = nil
    return object.isEmpty ? nil : BoardMeta(object)
  }
}

/// Each stroke's notes on a board, by the name Larry knows it by, at most `most` (the oldest go first).
public struct BoardStrokeMeta: Equatable, Codable, Sendable {
  public static let most = 20_000

  private var metas: [String: BoardMeta] = [:]
  private var order: [String] = []

  public init() {}

  public subscript(name: String) -> BoardMeta? { metas[name] }

  public var isEmpty: Bool { metas.isEmpty }

  /// Some stroke's notes are like this.
  public func contains(where wanted: (BoardMeta) -> Bool) -> Bool { metas.values.contains(where: wanted) }

  /// name → group, for grouping strokes into what moves as one.
  public var groups: [String: String] { metas.compactMapValues(\.group) }

  public mutating func set(_ meta: BoardMeta, for name: String) {
    if metas[name] == nil { order.append(name) }
    metas[name] = meta
    if order.count > Self.most {
      for gone in order.prefix(order.count - Self.most) { metas[gone] = nil }
      order.removeFirst(order.count - Self.most)
    }
  }

  /// A batch's notes, by stroke name.
  public mutating func remove(_ name: String) {
    guard metas.removeValue(forKey: name) != nil else { return }
    order.removeAll { $0 == name }
  }

  public mutating func merge(_ other: [String: BoardMeta]) {
    for (name, meta) in other { set(meta, for: name) }
  }
}
