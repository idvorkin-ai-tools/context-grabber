//  board-ops-harness (#936, story 990): Larry's changes replayed on a copy of Igor's board, on the Mac, in seconds, and
//  drawn so he can see what they will do before he sends them. The replay is ContextCore's (`BoardReplay`: the board's
//  own applier and planner); here only the arguments, the files and the picture.
//
//    board-ops-harness --board <snapshot.json> --ops <batch.json> [--ops <more.json>] [--keep id,id] [--tap x,y]
//                      [--out <prefix>] [--rev <n>] [--scale <px per point>]
//
//  A step file may also be a chat reply of Larry's with `shapes` (#941): his marks show as ghosts where the iPad puts
//  them, and each is tried with a tap; `--tap x,y` is a finger tap at a board point; `--keep-group <reply id>` is
//  Igor's Keep group (#942), the reply's marks kept as ink under one group.
//
//  Writes <prefix>.png (after), <prefix>-before.png, <prefix>.result.json (each step's op_result and what it touched)
//  and <prefix>.board.json (the board after, to replay the next batch on). Prints the result JSON.

import ContextCore
import Foundation

#if os(macOS)
  import CoreGraphics
  import CoreText
  import ImageIO
  import UniformTypeIdentifiers

  struct Failure: Error, CustomStringConvertible { let description: String }

  struct Arguments {
    var board = ""
    var steps: [(kind: String, value: String)] = []
    var out = ""
    var rev: Int?
    var scale: CGFloat = 1.5

    init(_ args: [String]) throws {
      var rest = args[...]
      func value(_ flag: String) throws -> String {
        guard let next = rest.popFirst() else { throw Failure(description: "\(flag) needs a value") }
        return next
      }
      while let flag = rest.popFirst() {
        switch flag {
        case "--board": board = try value(flag)
        case "--ops": steps.append(("ops", try value(flag)))
        case "--keep": steps.append(("keep", try value(flag)))
        case "--tap": steps.append(("tap", try value(flag)))
        case "--keep-group": steps.append(("keep-group", try value(flag)))
        case "--out": out = try value(flag)
        case "--rev": rev = Int(try value(flag))
        case "--scale": scale = CGFloat(Double(try value(flag)) ?? 1.5)
        case "-h", "--help": throw Failure(description: Self.usage)
        default: throw Failure(description: "unknown argument \(flag)\n\(Self.usage)")
        }
      }
      guard !board.isEmpty, !steps.isEmpty else { throw Failure(description: Self.usage) }
      if out.isEmpty {
        let stamp = Int(Date().timeIntervalSince1970)
        out = NSString(string: "~/tmp/agent/board-ops/replay-\(stamp)").expandingTildeInPath
      }
    }

    static let usage = """
      usage: board-ops-harness --board <snapshot.json> --ops <batch.json|reply.json> [--ops ...] [--keep id,id]
                               [--tap x,y] [--keep-group <reply id>]
                               [--out <prefix>] [--rev <n>] [--scale <px per point>]
      """
  }

  func readJSON(_ path: String) throws -> Any {
    let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    return try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
  }

  func writeJSON(_ any: Any, to path: String) throws {
    let data = try JSONSerialization.data(
      withJSONObject: any, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try data.write(to: URL(fileURLWithPath: path))
  }

  // MARK: The picture

  enum Look {
    static let moved = CGColor(red: 0.95, green: 0.55, blue: 0.05, alpha: 1)
    static let drawn = CGColor(red: 0.1, green: 0.65, blue: 0.25, alpha: 1)
    static let erased = CGColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)
    static let ghost = CGColor(red: 0.73, green: 0.22, blue: 0.9, alpha: 0.5)
    static let rule = CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1)
    static let page = CGColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    static let note = CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
  }

  func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
    return CGColor(
      red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255,
      alpha: alpha)
  }

  func stroke(_ lines: [[CGPoint]], in ctx: CGContext, color: CGColor, width: CGFloat) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for line in lines where !line.isEmpty {
      ctx.beginPath()
      ctx.move(to: line[0])
      if line.count == 1 { ctx.addLine(to: line[0]) }
      for point in line.dropFirst() { ctx.addLine(to: point) }
      ctx.strokePath()
    }
  }

  func box(_ rect: CGRect, in ctx: CGContext, color: CGColor, dashed: Bool) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(1.5)
    ctx.setLineDash(phase: 0, lengths: dashed ? [5, 4] : [])
    ctx.stroke(rect.insetBy(dx: -3, dy: -3))
    ctx.setLineDash(phase: 0, lengths: [])
  }

  /// Words at `point` (their baseline's left end), in board points, on the flipped context.
  func say(_ words: String, at point: CGPoint, in ctx: CGContext, color: CGColor, size: CGFloat = 11) {
    let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
    let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
    guard let text = CFAttributedStringCreate(nil, words as CFString, attributes) else { return }
    let line = CTLineCreateWithAttributedString(text)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = point
    CTLineDraw(line, ctx)
    ctx.restoreGState()
  }

  /// The board drawn: its ink, kept texts and Larry's ghosts, the steps' marks over it, and a note on top saying what
  /// each step came to.
  func render(
    _ board: BoardSnapshot, marks: [BoardReplay.Mark] = [], outcomes: [BoardReplay.Outcome], region: CGRect,
    scale: CGFloat, to path: String, title: String
  ) throws {
    let notes = [title] + outcomes.map(noteLine) + (outcomes.isEmpty ? [] : [legend])
    let header = CGFloat(notes.count) * 16 + 12
    let width = Int((region.width * scale).rounded(.up))
    let height = Int(((region.height + header) * scale).rounded(.up))
    guard
      let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw Failure(description: "no bitmap \(width)x\(height)") }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // Board points, y down, the region under the note.
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: scale, y: -scale)
    for (i, note) in notes.enumerated() {
      say(note, at: CGPoint(x: 8, y: 16 + CGFloat(i) * 16), in: ctx, color: Look.note, size: i == 0 ? 12 : 11)
    }
    ctx.translateBy(x: -region.minX, y: header - region.minY)
    ctx.clip(to: region)
    // The ruled lines rooms open by, and the page breaks.
    var y = (region.minY / BoardRoom.line).rounded(.down) * BoardRoom.line
    while y < region.maxY {
      stroke([[CGPoint(x: region.minX, y: y), CGPoint(x: region.maxX, y: y)]], in: ctx, color: Look.rule, width: 0.5)
      y += BoardRoom.line
    }
    var page = BoardPages.pageHeight
    while page < region.maxY {
      ctx.setLineDash(phase: 0, lengths: [8, 6])
      stroke(
        [[CGPoint(x: region.minX, y: page), CGPoint(x: region.maxX, y: page)]], in: ctx, color: Look.page, width: 1)
      ctx.setLineDash(phase: 0, lengths: [])
      page += BoardPages.pageHeight
    }
    for ink in board.ink where !ink.hidden {
      stroke([ink.points], in: ctx, color: color(ink.color), width: ink.width)
    }
    for text in board.texts {
      let lines = WhiteboardTurn.lines(text.shape, frame: .zero, scale: 1)
      stroke(lines, in: ctx, color: color(text.color), width: WhiteboardTurn.width(text.shape, scale: 1))
    }
    for ghost in board.ghosts {
      let lines = WhiteboardTurn.lines(ghost.shape, frame: .zero, scale: 1)
      stroke(lines, in: ctx, color: Look.ghost, width: WhiteboardTurn.width(ghost.shape, scale: 1))
      box(ghost.box, in: ctx, color: Look.ghost, dashed: true)
      say("ghost \(ghost.id)", at: CGPoint(x: ghost.box.maxX + 8, y: ghost.box.midY + 4), in: ctx, color: Look.ghost)
    }
    // Larry's marks from a reply, as ghosts; a mark a tap can't reach is ringed in red with what takes the tap.
    let unreachable = Dictionary(
      outcomes.flatMap(\.unreachable).compactMap { tap in tap.mark.map { ($0, tap) } }, uniquingKeysWith: { _, b in b })
    for mark in marks {
      stroke(mark.lines, in: ctx, color: color(String(format: "#%06X", mark.color), alpha: 0.5), width: mark.width)
      guard let tap = unreachable[mark.id] else { continue }
      let at = WhiteboardMarkChoice.bounds(mark.lines)
      box(at, in: ctx, color: Look.erased, dashed: true)
      say(
        "UNREACHABLE \(mark.text ?? mark.kind.rawValue): tap goes to \(tap.chose ?? "nothing")",
        at: CGPoint(x: at.minX, y: at.maxY + 12), in: ctx,
        color: Look.erased, size: 9)
    }
    for outcome in outcomes {
      for tap in outcome.taps where tap.mark == nil {
        ctx.setFillColor(Look.erased)
        ctx.fillEllipse(in: CGRect(x: tap.at.x - 4, y: tap.at.y - 4, width: 8, height: 8))
        say(
          "tap → \(tap.chose ?? "nothing")", at: CGPoint(x: tap.at.x + 8, y: tap.at.y - 6), in: ctx, color: Look.erased)
      }
    }
    // What the steps touched, by name: where it is now, or where it was. A group answers to its name with all its ink.
    var places = Dictionary(
      board.ink.map { ($0.id, $0.bounds) } + board.texts.map { ($0.id, $0.box) }, uniquingKeysWith: { a, _ in a })
    for ink in board.ink {
      if let group = ink.meta?.group { places[group] = (places[group] ?? .null).union(ink.bounds) }
    }
    for outcome in outcomes {
      for (id, was) in outcome.erased {
        box(was, in: ctx, color: Look.erased, dashed: true)
        say("erased \(id)", at: CGPoint(x: was.minX, y: was.maxY + 14), in: ctx, color: Look.erased)
      }
      for id in outcome.drawn {
        guard let at = places[id] else { continue }
        box(at, in: ctx, color: Look.drawn, dashed: false)
        say("+ \(id)", at: CGPoint(x: at.minX, y: at.maxY + 14), in: ctx, color: Look.drawn)
      }
      // Moved names are many after a push: one box each, one label for the lot, by the topmost.
      let moved = outcome.moved.compactMap { id, by in places[id].map { (id, by, $0) } }
      for (_, _, at) in moved { box(at, in: ctx, color: Look.moved, dashed: false) }
      if let top = moved.min(by: { $0.2.minY < $1.2.minY }) {
        say(
          "moved \(moved.count) by dy \(Int(top.1.dy)) (\(outcome.label))",
          at: CGPoint(x: top.2.minX, y: top.2.minY - 6),
          in: ctx, color: Look.moved)
      }
    }
    guard let image = ctx.makeImage(),
      let out = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw Failure(description: "can't write \(path)") }
    CGImageDestinationAddImage(out, image, nil)
    guard CGImageDestinationFinalize(out) else { throw Failure(description: "can't write \(path)") }
  }

  let legend = "orange: moved   green: drawn or kept   red dashed: erased   purple dashed: Larry's ghost (not ink)"

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
      line +=
        " UNREACHABLE=\(outcome.unreachable.map { "\($0.mark ?? "")->\($0.chose ?? "none")" }.joined(separator: ","))"
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

  func main() throws {
    let args = try Arguments(Array(CommandLine.arguments.dropFirst()))
    let snapshot = try BoardSnapshot(json: try readJSON(args.board))
    var steps: [BoardReplay.Step] = []
    for (i, step) in args.steps.enumerated() {
      if step.kind == "keep" {
        steps.append(.keep(step.value.split(separator: ",").map(String.init)))
      } else if step.kind == "keep-group" {
        steps.append(.keepGroup(step.value))
      } else if step.kind == "tap" {
        let xy = step.value.split(separator: ",").compactMap { Double($0) }
        guard xy.count == 2 else { throw Failure(description: "--tap wants x,y") }
        steps.append(.tap(CGPoint(x: xy[0], y: xy[1])))
      } else {
        steps += BoardReplay.Step.steps(try readJSON(step.value), key: "replay-\(i)")
      }
    }
    guard !steps.isEmpty else { throw Failure(description: "no batch in \(args.steps.map(\.value))") }
    var firstBase: Int?
    if case .batch(_, let json) = steps.first(where: { if case .batch = $0 { return true } else { return false } }) {
      firstBase = (json["base_rev"] as? NSNumber)?.intValue
    }
    var replay = BoardReplay(snapshot, rev: args.rev ?? firstBase)
    replay.run(steps)
    let out = args.out
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: out).deletingLastPathComponent(), withIntermediateDirectories: true)
    let area = region([replay.start, replay.board], marks: replay.marks, outcomes: replay.outcomes)
    try render(
      replay.start, outcomes: [], region: area, scale: args.scale, to: "\(out)-before.png",
      title: "BEFORE  board \(snapshot.board)  rev \(replay.start.rev ?? 0)")
    try render(
      replay.board, marks: replay.marks, outcomes: replay.outcomes, region: area, scale: args.scale, to: "\(out).png",
      title: "AFTER  board \(snapshot.board)  rev \(replay.board.rev ?? 0)")
    let result: [String: Any] = [
      "board": snapshot.board, "rev_before": replay.start.rev ?? 0, "rev": replay.board.rev ?? 0,
      "steps": replay.outcomes.map(\.wire), "ghosts": replay.board.ghosts.map(\.id),
      "marks": replay.marks.map(\.id),
      "png": "\(out).png", "png_before": "\(out)-before.png", "board_after": "\(out).board.json",
    ]
    try writeJSON(result, to: "\(out).result.json")
    try writeJSON(replay.board.json, to: "\(out).board.json")
    let data = try JSONSerialization.data(
      withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  do {
    try main()
  } catch {
    FileHandle.standardError.write(Data("board-ops-harness: \(error)\n".utf8))
    exit(1)
  }
#else
  FileHandle.standardError.write(Data("board-ops-harness draws with CoreGraphics: run it on the Mac\n".utf8))
  exit(1)
#endif
