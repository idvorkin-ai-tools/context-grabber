//  Headers drawn in ink (#967, spec 2026-11-19-whiteboard-ink-headers-design.md, stories 1030–1036): an underline
//  drawn under a line of his writing, or a # written at the start of a line, makes that line a header; a stroke
//  written on a header's line joins its row; a long flat line that underlines nothing is a rule, which ends the
//  sections above it. Pure: the outline's strokes, the newest stroke by its place, and what the header became.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOutline {
  /// A rule is at least this long, about half the page; shorter, a flat line under nothing is plain ink (a dash, or
  /// the simulator's straight "writing").
  public static let ruleWidth: CGFloat = 400
  /// A # fits in this box each way: about a line and a half.
  public static let hashMost: CGFloat = 60
  /// Each of a #'s bars is at least this long.
  public static let barLeast: CGFloat = 8
  /// A bar this close to level is level, this close to upright (from upright) is upright.
  static let levelDegrees: CGFloat = 30
  static let uprightDegrees: CGFloat = 35
  /// Bars that miss each other by this little still cross: a hand's # doesn't always close.
  static let crossSlop: CGFloat = 4
  /// A further # this close across to a header's #s takes it deeper (#1034): half a # wide, less than a word's gap
  /// and a half.
  public static let hashGap: CGFloat = 30

  /// How the ink made a header, or added to one.
  public enum InkHeader: Equatable, Sendable {
    /// An underline under the line made it a header: the header's id, the line's middle, the underline's strokes.
    case underline(header: String, y: CGFloat, mark: [String])
    /// A # at the line's start made it one.
    case hash(header: String, y: CGFloat, mark: [String])
    /// The stroke was written on a header's own line and joined its row.
    case grew(header: String, names: [String])
    /// A # finished beside a # header's #s took it a level deeper (#1034): ## or ###.
    case deeper(header: String, level: Int, y: CGFloat, mark: [String])

    public var kind: String {
      switch self {
      case .underline: "underline"
      case .hash: "hash"
      case .grew: "grew"
      case .deeper: "deeper"
      }
    }

    public var header: String {
      switch self {
      case .underline(let id, _, _), .hash(let id, _, _), .grew(let id, _), .deeper(let id, _, _, _): id
      }
    }
  }

  /// The stroke at `newest`, just drawn by Igor: on a header's line it joins the row; an underline under a line of
  /// his writing makes it a header named `id`; so does the # it finishes at a line's start. Nil when it is none of
  /// these. Only a stroke drawn now ever makes a header: old ink is never read for marks.
  @discardableResult
  public mutating func inkHeader(newest: Int, id: String) -> InkHeader? {
    guard strokes.indices.contains(newest), !strokes[newest].hidden, !strokes[newest].points.isEmpty,
      !tagged.contains(newest)
    else { return nil }
    if let deeper = deepened(newest) { return deeper }
    if let grew = grow(newest) { return grew }
    if let made = underlined(newest, id: id) { return made }
    return hashed(newest, id: id)
  }

  /// The strokes in a group of Larry's or a kept text: never his writing.
  var tagged: Set<Int> { Set(units().filter { $0.tag != nil && $0.header == nil }.flatMap(\.members)) }

  // MARK: - Underlines and rules

  /// `u` underlines the line `l`: under it, across most of it, and not running far past it (that is a rule).
  static func underlineOf(_ u: CGRect, _ l: CGRect) -> Bool {
    underlines(u, l) && u.width <= 1.5 * l.width + line
  }

  /// The strokes that are rules: long, flat and straight, and under no line of his writing.
  func rules() -> Set<Int> {
    let flat = strokes.indices.filter {
      !strokes[$0].hidden && !erased.contains($0) && strokes[$0].bounds.width >= Self.ruleWidth
        && Self.isUnderline(strokes[$0])
    }
    guard !flat.isEmpty else { return [] }
    let lines = writingLines().map(\.box)
    return Set(flat.filter { i in !lines.contains { Self.underlineOf(strokes[i].bounds, $0) } })
  }

  private mutating func underlined(_ n: Int, id: String) -> InkHeader? {
    let s = strokes[n]
    guard Self.isUnderline(s) else { return nil }
    // The nearest line above it that it underlines.
    let lines = writingLines().filter { !$0.header && Self.underlineOf(s.bounds, $0.box) }
    guard let l = lines.min(by: { abs(s.bounds.midY - $0.box.maxY) < abs(s.bounds.midY - $1.box.maxY) }),
      let row = row(at: l.box.midY), row.header == nil, !row.names.isEmpty
    else { return nil }
    let mark = s.ids
    headers.append(BoardHeader(id: id, ids: Self.union(row.names, mark), mark: mark))
    return .underline(header: id, y: l.box.midY, mark: mark)
  }

  // MARK: - #

  struct Bar {
    var at: Int
    var a: CGPoint
    var z: CGPoint
    var level: Bool
  }

  /// A short straight stroke, level or upright: one of a #'s four.
  func bar(_ i: Int) -> Bar? {
    let s = strokes[i]
    guard !s.hidden, !erased.contains(i), let a = s.points.first, let z = s.points.last, s.points.count >= 2 else {
      return nil
    }
    let chord = hypot(z.x - a.x, z.y - a.y)
    guard chord >= Self.barLeast, max(s.bounds.width, s.bounds.height) <= Self.hashMost else { return nil }
    let path = zip(s.points, s.points.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    guard path <= 1.2 * chord else { return nil }
    let degrees = atan2(abs(z.y - a.y), abs(z.x - a.x)) * 180 / .pi
    if degrees <= Self.levelDegrees { return Bar(at: i, a: a, z: z, level: true) }
    if degrees >= 90 - Self.uprightDegrees { return Bar(at: i, a: a, z: z, level: false) }
    return nil
  }

  /// The two bars cross, each stretched a little at its ends.
  static func cross(_ p: Bar, _ q: Bar) -> Bool {
    func stretched(_ b: Bar) -> (CGPoint, CGPoint) {
      let d = hypot(b.z.x - b.a.x, b.z.y - b.a.y)
      guard d > 0 else { return (b.a, b.z) }
      let ux = (b.z.x - b.a.x) / d * crossSlop
      let uy = (b.z.y - b.a.y) / d * crossSlop
      return (CGPoint(x: b.a.x - ux, y: b.a.y - uy), CGPoint(x: b.z.x + ux, y: b.z.y + uy))
    }
    let (a, b) = stretched(p)
    let (c, d) = stretched(q)
    func side(_ o: CGPoint, _ p: CGPoint, _ q: CGPoint) -> CGFloat {
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x)
    }
    return side(a, b, c) * side(a, b, d) <= 0 && side(c, d, a) * side(c, d, b) <= 0
  }

  /// The # the stroke at `n` finishes: four bars, two level and two upright, each level one crossing both upright
  /// ones, in a small box, the leftmost ink on its line. Their places. `beside` a header, it is a further # right
  /// next to that header's #s instead (#1034): its bars may be the header's row already, never its #s.
  func hash(finishedBy n: Int, beside: BoardHeader? = nil) -> [Int]? {
    guard let newest = bar(n) else { return nil }
    let near = strokes[n].bounds.insetBy(dx: -Self.hashMost, dy: -Self.hashMost)
    var taken = Set(headers.flatMap(\.ids))
    if let beside { taken.subtract(Set(beside.ids).subtracting(hashes(beside))) }
    let tagged = tagged
    let bars =
      strokes.indices.filter {
        $0 != n && near.intersects(strokes[$0].bounds) && !tagged.contains($0)
          && !strokes[$0].ids.contains(where: taken.contains)
      }.compactMap(bar) + [newest]
    let levels = bars.filter(\.level)
    let uprights = bars.filter { !$0.level }
    for (i, l1) in levels.enumerated() {
      for l2 in levels.dropFirst(i + 1) {
        for (j, u1) in uprights.enumerated() {
          for u2 in uprights.dropFirst(j + 1) {
            let four = [l1, l2, u1, u2]
            guard four.contains(where: { $0.at == n }), Self.cross(l1, u1), Self.cross(l1, u2), Self.cross(l2, u1),
              Self.cross(l2, u2), !Self.cross(l1, l2), !Self.cross(u1, u2)
            else { continue }
            let box = four.reduce(CGRect.null) { $0.union(strokes[$1.at].bounds) }
            guard box.width <= Self.hashMost, box.height <= Self.hashMost,
              beside.map({ besideHashes(box, $0, four: four.map(\.at)) }) ?? leftmost(box, besides: four.map(\.at))
            else { continue }
            return four.map(\.at)
          }
        }
      }
    }
    return nil
  }

  /// No ink of the board's on the line of `box` starts left of it.
  private func leftmost(_ box: CGRect, besides: [Int]) -> Bool {
    let mine = Set(besides)
    return !strokes.indices.contains { i in
      let b = strokes[i].bounds
      guard !mine.contains(i), !strokes[i].hidden, !erased.contains(i), b.minX < box.minX - Self.crossSlop else {
        return false
      }
      let overlap = min(b.maxY, box.maxY) - max(b.minY, box.minY)
      return overlap >= 0.4 * min(b.height, box.height)
    }
  }

  private mutating func hashed(_ n: Int, id: String) -> InkHeader? {
    guard let four = hash(finishedBy: n) else { return nil }
    let box = four.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
    guard let row = row(at: box.midY), row.header == nil else { return nil }
    let mark = four.flatMap { strokes[$0].ids }
    headers.append(BoardHeader(id: id, ids: Self.union(row.names, mark), mark: mark))
    return .hash(header: id, y: box.midY, mark: mark)
  }

  // MARK: - ## and ### (#1034)

  /// A header's #s by their strokes' names: the first # and each further one still counted. None for an underline's
  /// or a margin tap's.
  func hashes(_ header: BoardHeader) -> [String] {
    guard let mark = header.mark else { return [] }
    return mark + header.further(liveNames).flatMap { $0 }
  }

  /// The new #'s box `box` sits right beside the header's #s, on their line, with none of the header's other ink
  /// between them.
  private func besideHashes(_ box: CGRect, _ header: BoardHeader, four: [Int]) -> Bool {
    let at = index
    let marks = hashes(header).compactMap { at[$0] }
    let hb = marks.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
    guard !hb.isNull, box.midY >= hb.minY, box.midY <= hb.maxY else { return false }
    // Its middle to one side of them, and the gap between them: a tight ## may overlap a little.
    let right = box.midX >= hb.maxX
    guard right || box.midX <= hb.minX else { return false }
    let (from, to) = right ? (hb.maxX, box.minX) : (box.maxX, hb.minX)
    guard to - from <= Self.hashGap else { return false }
    let mine = Set(marks + four)
    return !header.ids.compactMap { at[$0] }.contains { i in
      !mine.contains(i) && !strokes[i].hidden && strokes[i].bounds.midX > from && strokes[i].bounds.midX < to
    }
  }

  /// The stroke at `n` finishes a # beside a showing # header's #s: the header goes one level deeper, to ###
  /// at most. Nil for any other stroke, and for a header already at ###.
  private mutating func deepened(_ n: Int) -> InkHeader? {
    guard bar(n) != nil else { return nil }
    let live = liveNames
    let at = index
    // Only a # header deepens: one whose mark is its # (no underline in it).
    let unders = Set(strokes.indices.filter { Self.isUnderline(strokes[$0]) })
    let byHash = { (mark: [String]) in !mark.contains { name in at[name].map(unders.contains) ?? true } }
    for (h, header) in headers.enumerated() {
      guard let mark = header.mark, !mark.isEmpty, byHash(mark), shows(header),
        header.level(live) < BoardHeader.deepest,
        let four = hash(finishedBy: n, beside: header)
      else { continue }
      let names = four.flatMap { strokes[$0].ids }
      // A # undone before this one leaves no gap in the count: only the levels still on the board are kept.
      headers[h].deeper = Array(header.further(live)) + [names]
      headers[h].ids = Self.union(header.ids, names)
      let box = four.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
      return .deeper(header: header.id, level: headers[h].level(live), y: box.midY, mark: names)
    }
    return nil
  }

  // MARK: - Writing on a header's line

  /// The header's writing: its row less its underlines.
  func writingBox(_ header: BoardHeader) -> CGRect? {
    let at = index
    let own = header.ids.compactMap { at[$0] }
    let words = own.filter { !Self.isUnderline(strokes[$0]) }
    let box = (words.isEmpty ? own : words).reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
    return box.isNull ? nil : box
  }

  /// The stroke at `n` on a showing header's own line joins its row: it overlaps the header's writing by a good part
  /// of the shorter one's height, as a line's strokes do.
  private mutating func grow(_ n: Int) -> InkHeader? {
    let s = strokes[n]
    let names = Set(s.ids)
    for (h, header) in headers.enumerated() where shows(header) && !header.ids.contains(where: names.contains) {
      guard let wb = writingBox(header) else { continue }
      let overlap = min(wb.maxY, s.bounds.maxY) - max(wb.minY, s.bounds.minY)
      guard overlap >= 0.4 * min(s.bounds.height, wb.height) else { continue }
      headers[h].ids = Self.union(header.ids, s.ids)
      return .grew(header: header.id, names: s.ids)
    }
    return nil
  }

  static func union(_ a: [String], _ b: [String]) -> [String] {
    let have = Set(a)
    return a + b.filter { !have.contains($0) }
  }
}
