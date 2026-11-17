//  Erasing part of a group leaves plain ink (spec 2026-11-16-whiteboard-board-ops-design.md, *Erasing part of a group
//  dissolves it*, story 854; the Cockpit's assets/ink/board.mjs, `dissolvePartial`). Pure.

import Foundation

public enum BoardDissolve {
  /// After Igor erased the strokes named `erased`, with `live` the strokes left: each of Larry's groups that lost some
  /// strokes and kept others loses its group note on those left, and each kept text with fewer glyphs left than it was
  /// kept as is forgotten, its glyphs plain ink. Returns the ids dissolved, groups first.
  public static func dissolve(
    erased: [String], live: [BoardOps.Stroke], metas: inout BoardStrokeMeta, texts: inout [BoardText]
  ) -> [String] {
    guard !erased.isEmpty else { return [] }
    var out: [String] = []
    let groups = metas.groups
    let left = Set(live.flatMap(\.ids))
    for group in Set(erased.compactMap { groups[$0] }).sorted() {
      let kept = groups.filter { $0.value == group && left.contains($0.key) }.keys.sorted()
      guard !kept.isEmpty else { continue }
      out.append(group)
      for name in kept {
        if let rest = metas[name]?.withoutGroup { metas.set(rest, for: name) } else { metas.remove(name) }
      }
    }
    let byTime = BoardText.byTime(texts)
    var glyphsLeft: [String: Int] = [:]
    for stroke in live { if let text = BoardText.owning(stroke.t, in: byTime) { glyphsLeft[text.id, default: 0] += 1 } }
    let parted = texts.filter { text in
      guard let glyphs = text.glyphs, let now = glyphsLeft[text.id] else { return false }
      return now < glyphs
    }.map(\.id)
    texts.removeAll { parted.contains($0.id) }
    return out + parted
  }
}
