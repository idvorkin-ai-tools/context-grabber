//  Larry's unkept marks hold to the ink they answer, and fade when written over (spec
//  2026-11-01-whiteboard-shapes-design.md, *His marks hold to the ink they answer, and fade when written over*; stories
//  1180, 1181, 1269–1271; bead context-grabber-p2an). A mark's anchor is chosen once, when it lands: the strokes of the
//  unit it overlaps most, else of the nearest unit above or beside it. Where it shows after that is a pure function of
//  the ink as it is now: moved by as much as its anchor moved, hidden while its anchor is folded away or erased. A stroke
//  Igor writes over it is remembered by name, so Undo of that stroke brings the mark back to full strength; the next
//  post takes faded and orphaned marks away. The board's ink and its marks are in board points.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// One unkept mark as the rule sees it: where it landed, its pen, and whether it is a label (written over inside its
/// letters' box) or a drawn mark (written over along its line).
public struct BoardMark: Equatable, Sendable {
  public var id: String
  /// Its lines where it landed, board points.
  public var lines: [[CGPoint]]
  public var pen: CGFloat
  public var label: Bool

  public init(id: String, lines: [[CGPoint]], pen: CGFloat, label: Bool) {
    self.id = id
    self.lines = lines
    self.pen = pen
    self.label = label
  }

  /// The box its lines fill where it landed.
  public var box: CGRect {
    lines.joined().reduce(CGRect.null) { $0.union(CGRect(x: $1.x, y: $1.y, width: 0, height: 0)) }
  }
}

/// What one mark holds to, chosen when it landed.
public struct BoardMarkAnchor: Equatable, Codable, Sendable {
  /// A stroke it holds to, by the name Larry knows it by, and where that stroke's box began when the mark landed.
  public struct Held: Equatable, Codable, Sendable {
    public var name: String
    public var x: Double
    public var y: Double

    public init(name: String, x: Double, y: Double) {
      self.name = name
      self.x = x
      self.y = y
    }
  }

  /// The anchor unit's strokes that show, nearest the mark first, then the rest of the unit's line, nearest first (at
  /// most `BoardMarkHolds.heldMost` in all); empty when the mark landed with nothing above, beside or under it.
  public var strokes: [Held]
  /// The gap between the mark and its unit when it landed, board points (0 when it overlaps it).
  public var gap: Double
  /// The strokes Igor wrote over it, by name, in the order he wrote them.
  public var writtenBy: [String]

  public init(strokes: [Held], gap: Double = 0, writtenBy: [String] = []) {
    self.strokes = strokes
    self.gap = gap
    self.writtenBy = writtenBy
  }
}

public enum BoardMarkHolds {
  /// The most strokes of its unit a mark remembers: enough that erasing a few hands it on, few enough to stay small.
  public static let heldMost = 8
  /// A stroke writes over a mark when at least this much of its path lies on it.
  public static let writtenShare = 1.0 / 3.0
  /// How close to a drawn mark's line a stroke's path is on it, beyond half the two pens' widths, board points.
  public static let reachBeyondPens: CGFloat = 2
  /// A faded mark's strength, of its usual.
  public static let fadedStrength: Double = 1.0 / 3.0

  /// The board's ink as the rule reads it: its strokes (by the names Larry knows them, folded or hidden ones marked) and
  /// what makes several of them one unit.
  public struct Ink: Sendable {
    public var strokes: [BoardOps.Stroke]
    public var texts: [BoardText]
    public var groups: [String: String]
    public var folds: [String: String]

    public init(
      strokes: [BoardOps.Stroke], texts: [BoardText] = [], groups: [String: String] = [:],
      folds: [String: String] = [:]
    ) {
      self.strokes = strokes
      self.texts = texts
      self.groups = groups
      self.folds = folds
    }
  }

  /// Why a mark doesn't show.
  public enum Hidden: String, Equatable, Sendable {
    /// Its anchor's ink is all folded away (or hidden by Larry).
    case folded
    /// Its anchor's ink is all gone from the board.
    case erased
  }

  /// Where a mark shows now.
  public struct Place: Equatable, Sendable {
    /// How far it moved from where it landed.
    public var dx: CGFloat
    public var dy: CGFloat
    /// Nil while it shows.
    public var hidden: Hidden?
    /// A stroke Igor wrote over it shows on the board.
    public var faded: Bool

    public init(dx: CGFloat = 0, dy: CGFloat = 0, hidden: Hidden? = nil, faded: Bool = false) {
      self.dx = dx
      self.dy = dy
      self.hidden = hidden
      self.faded = faded
    }

    /// The mark goes on the next post: written over, or its ink erased.
    public var drops: Drop.Why? {
      if hidden == .erased { return .inkErased }
      return faded && hidden == nil ? .writtenOver : nil
    }
  }

  /// A mark the next post takes away, and why: on the turn's report, so Larry knows.
  public struct Drop: Equatable, Codable, Sendable {
    public enum Why: String, Equatable, Codable, Sendable {
      case writtenOver = "written_over"
      case inkErased = "ink_erased"
    }

    public var id: String
    public var why: Why

    public init(id: String, why: Why) {
      self.id = id
      self.why = why
    }

    public var wire: [String: Any] { ["id": id, "why": why.rawValue] }
  }

  // MARK: The anchor

  /// The anchor of `mark`, landing on `ink` as it shows: the unit it overlaps most; else the nearest unit whose top is
  /// above its middle, by the gap between their boxes, the later on a tie; else none.
  public static func anchor(_ mark: BoardMark, on ink: Ink) -> BoardMarkAnchor {
    let box = mark.box
    guard !box.isNull else { return BoardMarkAnchor(strokes: []) }
    let items = BoardOps.items(strokes: ink.strokes, texts: ink.texts, groups: ink.groups, folds: ink.folds)
      .filter { !$0.hidden }
    var overlapping: (index: Int, area: CGFloat)?
    var near: (index: Int, gap: CGFloat)?
    for (index, item) in items.enumerated() {
      let overlap = area(box, item.bounds)
      if overlap > 0 {
        // The later of two that overlap it as much.
        if overlapping.map({ overlap >= $0.area }) ?? true { overlapping = (index, overlap) }
      } else if item.bounds.minY < box.midY {
        let gap = Self.gap(box, item.bounds)
        if near.map({ gap <= $0.gap }) ?? true { near = (index, gap) }
      }
    }
    guard let best = overlapping.map({ (index: $0.index, gap: CGFloat(0)) }) ?? near else {
      return BoardMarkAnchor(strokes: [])
    }
    // The unit's strokes nearest first, then the rest of its line: an erased stroke hands the mark on to the next.
    let unit = items[best.index]
    let shown = ink.strokes.indices.filter { !ink.strokes[$0].hidden }
    let members = unit.members.filter { ink.strokes.indices.contains($0) && !ink.strokes[$0].hidden }
    let rows = unit.bounds
    let line = shown.filter { index in
      let other = ink.strokes[index].bounds
      return !unit.members.contains(index) && other.minY < rows.maxY && rows.minY < other.maxY
    }
    let byGap = { (indices: [Int]) -> [Int] in
      let gaps: [(index: Int, gap: CGFloat)] = indices.map { ($0, Self.gap(box, ink.strokes[$0].bounds)) }
      return gaps.sorted { $0.gap == $1.gap ? $0.index > $1.index : $0.gap < $1.gap }.map(\.index)
    }
    let nearest = (byGap(members) + byGap(line)).prefix(heldMost).map { ink.strokes[$0] }
    let held = nearest.compactMap { stroke -> BoardMarkAnchor.Held? in
      guard let name = stroke.ids.first else { return nil }
      return BoardMarkAnchor.Held(name: name, x: Double(stroke.bounds.minX), y: Double(stroke.bounds.minY))
    }
    return BoardMarkAnchor(strokes: held, gap: Double(best.gap))
  }

  // MARK: Where it shows

  /// Where a mark with `anchor` shows on `strokes`: moved as its first anchor stroke that shows moved; hidden when all
  /// of its anchor's strokes on the board are hidden (folded), or none is left (erased). Faded while a stroke that wrote
  /// over it shows.
  public static func place(_ anchor: BoardMarkAnchor, on strokes: [BoardOps.Stroke]) -> Place {
    var byName: [String: BoardOps.Stroke] = [:]
    for stroke in strokes { for name in stroke.ids where byName[name] == nil { byName[name] = stroke } }
    let faded = anchor.writtenBy.contains { byName[$0].map { !$0.hidden } ?? false }
    guard !anchor.strokes.isEmpty else { return Place(faded: faded) }
    let present = anchor.strokes.compactMap { held in byName[held.name].map { (held, $0) } }
    guard !present.isEmpty else { return Place(hidden: .erased) }
    guard let (held, stroke) = present.first(where: { !$0.1.hidden }) else { return Place(hidden: .folded) }
    return Place(
      dx: stroke.bounds.minX - CGFloat(held.x), dy: stroke.bounds.minY - CGFloat(held.y), faded: faded)
  }

  // MARK: Written over

  /// How much of `stroke`'s path lies on `mark`, moved by `place`: inside a label's letters' box, or within reach of a
  /// drawn mark's line. 0 to 1; a stroke with no length is all on it or not at all.
  public static func share(of stroke: BoardOps.Stroke, on mark: BoardMark, at place: Place = Place()) -> Double {
    let points = stroke.points.isEmpty ? [CGPoint(x: stroke.bounds.midX, y: stroke.bounds.midY)] : stroke.points
    let lines = mark.lines.map { $0.map { CGPoint(x: $0.x + place.dx, y: $0.y + place.dy) } }
    let box = mark.box.offsetBy(dx: place.dx, dy: place.dy)
    let reach = (stroke.pen + mark.pen) / 2 + reachBeyondPens
    let near = box.insetBy(dx: -reach, dy: -reach)
    let on: (CGPoint) -> Bool = { point in
      if mark.label { return box.contains(point) }
      guard near.contains(point) else { return false }
      return lines.contains { line in distance(point, to: line) <= reach }
    }
    guard points.count > 1 else { return on(points[0]) ? 1 : 0 }
    var total: CGFloat = 0
    var onMark: CGFloat = 0
    for (a, b) in zip(points, points.dropFirst()) {
      let length = hypot(b.x - a.x, b.y - a.y)
      total += length
      if on(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)) { onMark += length }
    }
    guard total > 0 else { return on(points[0]) ? 1 : 0 }
    return Double(onMark / total)
  }

  /// Whether `stroke` writes over `mark` where it shows.
  public static func writesOver(_ stroke: BoardOps.Stroke, _ mark: BoardMark, at place: Place = Place()) -> Bool {
    place.hidden == nil && share(of: stroke, on: mark, at: place) >= writtenShare
  }

  /// Igor wrote `stroke`: it is remembered on each shown mark it writes over, by its first name. Returns each mark it
  /// wrote over with the share of the stroke on it, for the log.
  public static func wrote(
    _ stroke: BoardOps.Stroke, marks: [BoardMark], anchors: inout [String: BoardMarkAnchor],
    strokes: [BoardOps.Stroke]
  ) -> [(id: String, share: Double)] {
    guard let name = stroke.ids.first else { return [] }
    var out: [(id: String, share: Double)] = []
    for mark in marks {
      let anchor = anchors[mark.id] ?? BoardMarkAnchor(strokes: [])
      let place = place(anchor, on: strokes)
      guard place.hidden == nil else { continue }
      let share = share(of: stroke, on: mark, at: place)
      guard share >= writtenShare else { continue }
      var changed = anchor
      if !changed.writtenBy.contains(name) { changed.writtenBy.append(name) }
      anchors[mark.id] = changed
      out.append((mark.id, share))
    }
    return out
  }

  /// What the next post takes away, in the marks' order.
  public static func drops(_ marks: [BoardMark], anchors: [String: BoardMarkAnchor], strokes: [BoardOps.Stroke])
    -> [Drop]
  {
    marks.compactMap { mark in
      guard let anchor = anchors[mark.id], let why = place(anchor, on: strokes).drops else { return nil }
      return Drop(id: mark.id, why: why)
    }
  }

  // MARK: Geometry

  /// How much two boxes overlap: a line's or a dot's box, with no area, overlaps by its length.
  static func area(_ a: CGRect, _ b: CGRect) -> CGFloat {
    guard !a.isNull, !b.isNull else { return 0 }
    let w = min(a.maxX, b.maxX) - max(a.minX, b.minX)
    let h = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    let flat = a.width == 0 || a.height == 0 || b.width == 0 || b.height == 0
    guard w >= 0, h >= 0, (w > 0 && h > 0) || flat else { return 0 }
    return max(w, 0.5) * max(h, 0.5)
  }

  /// The gap between two boxes: 0 when they meet.
  static func gap(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let dx = max(0, max(a.minX - b.maxX, b.minX - a.maxX))
    let dy = max(0, max(a.minY - b.maxY, b.minY - a.maxY))
    return hypot(dx, dy)
  }

  /// From `point` to the nearest of `line`'s segments (to its one point, for a dot).
  static func distance(_ point: CGPoint, to line: [CGPoint]) -> CGFloat {
    guard let first = line.first else { return .infinity }
    guard line.count > 1 else { return hypot(point.x - first.x, point.y - first.y) }
    var best = CGFloat.infinity
    for (a, b) in zip(line, line.dropFirst()) {
      let dx = b.x - a.x
      let dy = b.y - a.y
      let length = dx * dx + dy * dy
      let t = length == 0 ? 0 : max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length))
      best = min(best, hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy)))
    }
    return best
  }
}
