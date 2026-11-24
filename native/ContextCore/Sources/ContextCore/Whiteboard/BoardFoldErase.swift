//  Erasing a fold whole (spec 2026-11-16-whiteboard-board-ops-design.md, *Headers fold their sections*, stories 902,
//  903; the Cockpit's assets/ink/board.mjs: `foldHits`, `eraseFold`). Pure: which folds a path takes, by their marker
//  (BoardFoldMarker.swift) or their header's ink, and the outline with those folds erased and the ink below closed up.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOutline {
  /// How near an eraser has to come to the marker or the header's ink to take the fold, board points.
  public static let eraseReach: CGFloat = 8

  /// A fold a path took: the header the path crossed, the headers that go (it and every fold folded inside it), the
  /// strokes that go by name (their rows and all they hide), and the header's top, where what was below closes up to.
  public struct FoldHit: Equatable, Sendable {
    public var header: String
    /// The path crossed its "▸ N lines folded", not only the header's words.
    public var byMarker = false
    public var headers: Set<String>
    public var names: Set<String>
    public var top: CGFloat
  }

  /// The shown folds `path` (board points) crosses: by their marker, and with `onHeader` by the header's words too
  /// (its underline or # is no part of them: context-grabber-bov). Worked out on the board as it was when the path
  /// began, so ink the eraser took on its way still counts.
  public func foldHits(along path: [CGPoint], reach r: CGFloat = eraseReach, onHeader: Bool) -> [FoldHit] {
    guard let first = path.first else { return [] }
    let p = path.count > 1 ? path : [first, first]
    // Every 4 points along the path, as the web board walks it.
    var dots: [CGPoint] = []
    for (a, b) in zip(p, p.dropFirst()) {
      let n = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 4).rounded(.up)))
      for i in 0...n {
        let t = CGFloat(i) / CGFloat(n)
        dots.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
      }
    }
    let at = index
    let crossed = { (box: CGRect) in dots.contains { box.insetBy(dx: -r, dy: -r).contains($0) } }
    let inked = { (header: BoardHeader) in
      header.words.compactMap { at[$0] }.contains { m in
        let s = self.strokes[m]
        let pad = r + (s.pen > 0 ? s.pen : 3) / 2
        guard !s.hidden, s.bounds.insetBy(dx: -pad, dy: -pad).overlaps(Self.bounds(of: dots)) else { return false }
        let line = s.points.count > 1 ? s.points : s.points + s.points
        return dots.contains { d in zip(line, line.dropFirst()).contains { Self.distance(d, $0.0, $0.1) <= pad } }
      }
    }
    let markers = Dictionary(uniqueKeysWithValues: self.markers.map { ($0.header, $0.box) })
    return bottomUp().compactMap { id in
      guard let header = header(id), let box = markers[id], let hb = self.box(header) else { return nil }
      let byMarker = crossed(box)
      guard byMarker || (onHeader && inked(header)) else { return nil }
      var found = hit(header, top: hb.minY)
      found.byMarker = byMarker
      return found
    }
  }

  /// The fold header `id` heads, as a path that crossed its marker would take it: nil unless it is folded and shows.
  /// For the web board, which erases a fold by its header (BoardWasm, `bw_fold_erase`).
  package func foldHit(_ id: String) -> FoldHit? {
    guard let header = header(id), isFolded(header), shows(header), let hb = box(header) else { return nil }
    var found = hit(header, top: hb.minY)
    found.byMarker = true
    return found
  }

  private static func bounds(of points: [CGPoint]) -> CGRect {
    points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
  }

  /// The fold `header` heads, with every header whose row it folded away.
  private func hit(_ header: BoardHeader, top: CGFloat) -> FoldHit {
    var gone: Set<String> = [header.id]
    var names = Set(header.ids + (header.fold?.ids ?? []))
    var grew = true
    while grew {
      grew = false
      for inner in headers where !gone.contains(inner.id) && inner.ids.contains(where: names.contains) {
        gone.insert(inner.id)
        names.formUnion(inner.ids + (inner.fold?.ids ?? []))
        grew = true
      }
    }
    return FoldHit(header: header.id, headers: gone, names: names, top: top)
  }

  /// How an eraser stroke ended, for which folds it takes.
  public enum EraserStroke: Sendable {
    /// The eraser lifted: it took whole strokes.
    case lifted
    /// The pixel eraser lifted: it rubbed out what it touched, and a rubbed stroke comes back under new names.
    case rubbed
    /// The system called it off (a palm, a system gesture).
    case cancelled
  }

  /// The folds an eraser stroke takes, of the `hits` it crossed, once PaperKit's own erase is on the board (`live`,
  /// the stroke names on it now; nil when the board can't be read, so no header's words are seen gone). By the marker
  /// as ever, unless called off. By the header's words only where the eraser took them, not where it passed near them
  /// (an underline sits just under its words: context-grabber-bov): the eraser some of them, the pixel eraser all of
  /// them (a rub on the corner of one letter leaves the section folded), a called-off stroke all of them.
  public func foldsTaken(_ hits: [FoldHit], by stroke: EraserStroke, live: Set<String>?) -> [FoldHit] {
    hits.filter { hit in
      if hit.byMarker && stroke != .cancelled { return true }
      guard let live, let words = header(hit.header)?.words, !words.isEmpty else { return false }
      let left = words.filter(live.contains).count
      return stroke == .lifted ? left < words.count : left == 0
    }
  }

  /// The folds erased: their strokes go, their headers go, and what was below each closes up to where its header was,
  /// in whole lines, the lowest first so each leaves the ones above where they were. False when nothing went.
  @discardableResult
  public mutating func eraseFolds(_ hits: [FoldHit]) -> Bool {
    let gone = hits.reduce(into: Set<Int>()) { out, hit in
      for (i, s) in strokes.enumerated() where s.ids.contains(where: hit.names.contains) { out.insert(i) }
    }
    let headersGone = hits.reduce(into: Set<String>()) { $0.formUnion($1.headers) }
    guard !gone.isEmpty || headers.contains(where: { headersGone.contains($0.id) }) else { return false }
    erased.formUnion(gone)
    headers.removeAll { headersGone.contains($0.id) }
    for top in hits.map(\.top).sorted(by: >) {
      let below = units().filter { $0.bounds.minY >= top }
      guard let next = below.map(\.bounds.minY).min() else { continue }
      let d = ((next - top) / Self.line).rounded(.down) * Self.line
      for unit in below where d > 0 { shift(unit, by: -d) }
    }
    return true
  }

  /// The strokes on the board now: none a fold's erase took.
  public var liveNames: Set<String> {
    Set(strokes.indices.filter { !erased.contains($0) }.flatMap { strokes[$0].ids })
  }

  /// The headers to keep after an outline change: the outline's own, and those of `previous` whose ink is all gone from
  /// the board (erased with their fold, or by the eraser), so an Undo that brings the ink back brings the header back,
  /// still folded. Unmarking a header, whose ink is still there, drops it. One made by an underline or a # whose mark
  /// is gone is kept too, so the mark's Redo brings it back (#967), unless the row has been made a header since.
  /// ponytail: a header whose ink is gone for good stays in the list, a few bytes each; prune ones no Undo can reach
  /// (older than the board's open) if a board ever carries many.
  public static func keeping(_ headers: [BoardHeader], previous: [BoardHeader], live: Set<String>) -> [BoardHeader] {
    let ids = Set(headers.map(\.id))
    let taken = Set(headers.flatMap(\.ids))
    return headers
      + previous.filter { header in
        guard !ids.contains(header.id) else { return false }
        if !header.ids.contains(where: live.contains) { return true }
        return header.markGone(live) && !header.ids.contains(where: taken.contains)
      }
  }
}
