//  The harness's picture as a list of marks in board points (#943): what to draw, decided once, then written as a PNG
//  where CoreGraphics is (the Mac) or as an SVG where it isn't (Larry's Linux box), with the same colours and words.

import ContextCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

struct RGBA: Equatable {
  var r: Double
  var g: Double
  var b: Double
  var a: Double = 1

  init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
    (self.r, self.g, self.b, self.a) = (r, g, b, a)
  }

  /// `#rrggbb`; black for anything else.
  init(hex: String, alpha: Double = 1) {
    let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
    self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, alpha)
  }

  var hex: String { String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255)) }
}

enum Look {
  static let moved = RGBA(0.95, 0.55, 0.05)
  static let drawn = RGBA(0.1, 0.65, 0.25)
  static let erased = RGBA(0.85, 0.1, 0.1)
  static let ghost = RGBA(0.73, 0.22, 0.9, 0.5)
  static let rule = RGBA(0.85, 0.88, 0.95)
  static let page = RGBA(0.6, 0.6, 0.6)
  static let note = RGBA(0.15, 0.15, 0.15)
}

/// One picture: the notes on top, then the board's region under them, in board points with y down.
struct Sketch {
  enum Mark {
    case lines([[CGPoint]], RGBA, width: CGFloat, dash: [CGFloat])
    /// Words, `at` the left end of their baseline.
    case words(String, at: CGPoint, RGBA, size: CGFloat)
    case dot(CGPoint, radius: CGFloat, RGBA)
  }

  var notes: [String]
  var region: CGRect
  var marks: [Mark] = []

  /// Above the region, in board points.
  var header: CGFloat { CGFloat(notes.count) * 16 + 12 }

  mutating func stroke(_ lines: [[CGPoint]], _ color: RGBA, width: CGFloat, dash: [CGFloat] = []) {
    marks.append(.lines(lines.filter { !$0.isEmpty }, color, width: width, dash: dash))
  }

  mutating func box(_ rect: CGRect, _ color: RGBA, dashed: Bool) {
    let r = rect.insetBy(dx: -3, dy: -3)
    let corners = [
      CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
      CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY),
    ]
    stroke([corners], color, width: 1.5, dash: dashed ? [5, 4] : [])
  }

  mutating func say(_ words: String, at point: CGPoint, _ color: RGBA, size: CGFloat = 11) {
    marks.append(.words(words, at: point, color, size: size))
  }
}

let legend = "orange: moved   green: drawn or kept   red dashed: erased   purple dashed: Larry's ghost (not ink)"

/// The board drawn: its ink, kept texts and Larry's ghosts, the steps' marks over it, and a note on top saying what
/// each step came to.
func sketch(
  _ board: BoardSnapshot, marks: [BoardReplay.Mark] = [], outcomes: [BoardReplay.Outcome], region: CGRect,
  title: String
) -> Sketch {
  var out = Sketch(notes: [title] + outcomes.map(noteLine) + (outcomes.isEmpty ? [] : [legend]), region: region)
  // The ruled lines rooms open by, and the page breaks.
  var y = (region.minY / BoardRoom.line).rounded(.down) * BoardRoom.line
  while y < region.maxY {
    out.stroke([[CGPoint(x: region.minX, y: y), CGPoint(x: region.maxX, y: y)]], Look.rule, width: 0.5)
    y += BoardRoom.line
  }
  var page = BoardPages.pageHeight
  while page < region.maxY {
    out.stroke(
      [[CGPoint(x: region.minX, y: page), CGPoint(x: region.maxX, y: page)]], Look.page, width: 1, dash: [8, 6])
    page += BoardPages.pageHeight
  }
  for ink in board.ink where !ink.hidden {
    out.stroke([ink.points], RGBA(hex: ink.color), width: ink.width)
  }
  for text in board.texts {
    out.stroke(
      WhiteboardTurn.lines(text.shape, frame: .zero, scale: 1), RGBA(hex: text.color),
      width: WhiteboardTurn.width(text.shape, scale: 1))
  }
  for ghost in board.ghosts {
    out.stroke(
      WhiteboardTurn.lines(ghost.shape, frame: .zero, scale: 1), Look.ghost,
      width: WhiteboardTurn.width(ghost.shape, scale: 1))
    out.box(ghost.box, Look.ghost, dashed: true)
    out.say("ghost \(ghost.id)", at: CGPoint(x: ghost.box.maxX + 8, y: ghost.box.midY + 4), Look.ghost)
  }
  // Larry's marks from a reply, as ghosts; a mark a tap can't reach is ringed in red with what takes the tap.
  let unreachable = Dictionary(
    outcomes.flatMap(\.unreachable).compactMap { tap in tap.mark.map { ($0, tap) } }, uniquingKeysWith: { _, b in b })
  for mark in marks {
    out.stroke(mark.lines, RGBA(hex: String(format: "#%06X", mark.color), alpha: 0.5), width: mark.width)
    guard let tap = unreachable[mark.id] else { continue }
    let at = WhiteboardMarkChoice.bounds(mark.lines)
    out.box(at, Look.erased, dashed: true)
    out.say(
      "UNREACHABLE \(mark.text ?? mark.kind.rawValue): tap goes to \(tap.chose ?? "nothing")",
      at: CGPoint(x: at.minX, y: at.maxY + 12), Look.erased, size: 9)
  }
  for outcome in outcomes {
    for tap in outcome.taps where tap.mark == nil {
      out.marks.append(.dot(tap.at, radius: 4, Look.erased))
      out.say("tap → \(tap.chose ?? "nothing")", at: CGPoint(x: tap.at.x + 8, y: tap.at.y - 6), Look.erased)
    }
  }
  // What the steps touched, by name: where it is now, or where it was. A group answers to its name with all its ink.
  var places = Dictionary(
    board.ink.map { ($0.id, $0.bounds) } + board.texts.map { ($0.id, $0.box) }, uniquingKeysWith: { a, _ in a })
  for ink in board.ink { if let group = ink.meta?.group { places[group] = (places[group] ?? .null).union(ink.bounds) } }
  for outcome in outcomes {
    for (id, was) in outcome.erased {
      out.box(was, Look.erased, dashed: true)
      out.say("erased \(id)", at: CGPoint(x: was.minX, y: was.maxY + 14), Look.erased)
    }
    for id in outcome.drawn {
      guard let at = places[id] else { continue }
      out.box(at, Look.drawn, dashed: false)
      out.say("+ \(id)", at: CGPoint(x: at.minX, y: at.maxY + 14), Look.drawn)
    }
    // Moved names are many after a push: one box each, one label for the lot, by the topmost.
    let moved = outcome.moved.compactMap { id, by in places[id].map { (id, by, $0) } }
    for (_, _, at) in moved { out.box(at, Look.moved, dashed: false) }
    if let top = moved.min(by: { $0.2.minY < $1.2.minY }) {
      out.say(
        "moved \(moved.count) by dy \(Int(top.1.dy)) (\(outcome.label))", at: CGPoint(x: top.2.minX, y: top.2.minY - 6),
        Look.moved)
    }
  }
  return out
}

func noteLine(_ outcome: BoardReplay.Outcome) -> String {
  var line = "\(outcome.label): \(outcome.action)"
  if let why = outcome.why { line += " (\(why))" }
  if let result = outcome.result {
    line += " ok=\(result.ok) rev=\(result.rev)"
    if let reason = result.reason { line += " reason=\(reason)" }
    if let missing = result.missingIDs, !missing.isEmpty { line += " MISSING=\(missing.joined(separator: ","))" }
    if let from = result.rebasedFrom { line += " rebased_from=\(from)" }
    if let conflicts = result.conflictIDs { line += " conflicts=\(conflicts.joined(separator: ","))" }
  }
  if !outcome.ghostsGone.isEmpty { line += " ghosts_gone=\(outcome.ghostsGone.joined(separator: ","))" }
  if !outcome.marks.isEmpty {
    line += " marks=\(outcome.marks.count) reachable=\(outcome.marks.count - outcome.unreachable.count)"
  }
  if !outcome.unreachable.isEmpty {
    let taken = outcome.unreachable.map { "\($0.mark ?? "")->\($0.chose ?? "none")" }
    line += " UNREACHABLE=\(taken.joined(separator: ","))"
  }
  return line
}

/// Everything either picture shows, with a margin, from the page's left edge.
func region(_ boards: [BoardSnapshot], marks: [BoardReplay.Mark] = [], outcomes: [BoardReplay.Outcome]) -> CGRect {
  var all = CGRect(x: 0, y: 0, width: BoardPages.pageWidth, height: BoardRoom.line)
  for board in boards {
    for ink in board.ink { all = all.union(ink.bounds) }
    for text in board.texts { all = all.union(text.box) }
    for ghost in board.ghosts { all = all.union(ghost.box) }
  }
  for mark in marks { all = all.union(WhiteboardMarkChoice.bounds(mark.lines)) }
  for outcome in outcomes { for was in outcome.erased.values { all = all.union(was) } }
  return all.insetBy(dx: -40, dy: -40).intersection(
    CGRect(x: -400, y: -400, width: all.maxX + 440, height: all.maxY + 440))
}
