//  What a selection is, said on a small label beside it (spec 2026-11-22-whiteboard-selection-label-design.md, story
//  1095, #1045): plain ink, a kept text, a group, a connector, or a mix, and what applies to it. Pure.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardSelectionLabel {
  /// A stroke as the label reads it: the names Larry knows it by, and when it was made (a kept text's glyphs share one
  /// time).
  public struct Piece: Equatable, Sendable {
    public var names: [String]
    public var t: Int64?

    public init(names: [String], t: Int64?) {
      self.names = names
      self.t = t
    }
  }

  public enum Kind: String, Sendable {
    case connector, arrow, text, group, ink, things, mixed
    case partText = "part_text"
    case partGroup = "part_group"
  }

  public struct Label: Equatable, Sendable {
    public var kind: Kind
    /// What it is, then what applies: shown joined by a middle dot.
    public var words: [String]

    public init(kind: Kind, words: [String]) {
      self.kind = kind
      self.words = words
    }

    public var text: String { words.joined(separator: " · ") }
    /// As VoiceOver reads it.
    public var spoken: String { "Selected: " + words.joined(separator: ", ") }
  }

  private enum Thing: Hashable {
    case text(String)
    case group(String)
    case connector(String)
  }

  /// The label for the strokes `picked`, of the strokes on the `board` (which holds them); nil with none picked.
  /// `connectReady`: Connect would join them (story 910).
  public static func label(
    picked: [Piece], board: [Piece], texts: [BoardText], metas: BoardStrokeMeta, connectReady: Bool
  ) -> Label? {
    guard !picked.isEmpty else { return nil }
    let groups = metas.groups
    let byTime = BoardText.byTime(texts)
    // A kept text Larry grouped (notes under its id, #937) belongs to its group, as the board moves it
    // (bead context-grabber-owy).
    func thing(_ piece: Piece) -> Thing? {
      if let name = piece.names.first(where: { BoardConnector(metas[$0]) != nil }) { return .connector(name) }
      let text = BoardText.owning(piece.t, in: byTime)?.id
      if let group = text.flatMap({ groups[$0] }) ?? piece.names.lazy.compactMap({ groups[$0] }).first {
        return .group(group)
      }
      return text.map(Thing.text)
    }
    let things = picked.map(thing)
    let plain = things.filter { $0 == nil }.count
    var found: [Thing] = []
    for case let one? in things where !found.contains(one) { found.append(one) }
    let connectors = found.filter { if case .connector = $0 { true } else { false } }.count
    if plain == 0, connectors == found.count {
      return connectors == 1
        ? Label(kind: .connector, words: ["Connector", "follows its two ends"])
        : Label(kind: .connector, words: ["\(connectors) connectors", "follow their ends"])
    }
    if connectReady { return Label(kind: .arrow, words: ["Arrow", "Connect"]) }
    if found.isEmpty { return Label(kind: .ink, words: ["Ink", "To text"]) }
    if plain > 0 {
      guard found.count == 1, let one = found.first else {
        return Label(kind: .mixed, words: ["Ink and \(found.count) things"])
      }
      switch one {
      case .text: return Label(kind: .mixed, words: ["Ink and a text"])
      case .group: return Label(kind: .mixed, words: ["Ink and a group"])
      case .connector: return Label(kind: .mixed, words: ["Ink and a connector"])
      }
    }
    guard found.count == 1, let one = found.first else {
      return Label(kind: .things, words: ["\(found.count) things", "move together"])
    }
    let all = board.filter { thing($0) == one }.count
    let whole = picked.count >= all
    var label: Label
    let id: String
    switch one {
    case .text(let text):
      id = text
      label =
        whole
        ? Label(kind: .text, words: ["Text", "tap to reword"])
        : Label(kind: .partText, words: ["Part of a text", "erasing it leaves ink"])
    case .group(let group):
      id = group
      label =
        whole
        ? Label(kind: .group, words: ["Group", "moves as one"])
        : Label(kind: .partGroup, words: ["Part of a group", "erasing it leaves ink"])
    case .connector(let name):
      id = name
      label = Label(kind: .connector, words: ["Connector", "follows its two ends"])
    }
    // A connector on a text inside the group follows the group too.
    let ends = Set(picked.flatMap(\.names)).union(picked.compactMap { BoardText.owning($0.t, in: byTime)?.id })
    if whole, followed(id, or: ends, board: board, metas: metas) {
      label.words.append("a connector follows it")
    }
    return label
  }

  /// Some connector on the board ends on `id` (a text's or a group's name) or on one of `names`.
  private static func followed(_ id: String, or names: Set<String>, board: [Piece], metas: BoardStrokeMeta) -> Bool {
    guard metas.hasConnectors else { return false }
    for piece in board {
      for name in piece.names {
        guard let c = BoardConnector(metas[name]) else { continue }
        if c.from == id || c.to == id || names.contains(c.from) || names.contains(c.to) { return true }
      }
    }
    return false
  }
}
