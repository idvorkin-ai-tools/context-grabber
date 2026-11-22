//  board-ops-harness (#936, story 990): Larry's changes replayed on a copy of Igor's board, on the Mac, in seconds, and
//  drawn so he can see what they will do before he sends them. The replay is ContextCore's (`BoardReplay`: the board's
//  own applier and planner); here only the arguments, the files and the picture.
//
//    board-ops-harness --board <snapshot.json> --ops <batch.json> [--ops <more.json>] [--keep id,id] [--tap x,y]
//                      [--out <prefix>] [--rev <n>] [--scale <px per point>]
//
//  A step file may also be a chat reply of Larry's with `shapes` (#941): his marks show as ghosts where the iPad puts
//  them, and each is tried with a tap; `--tap x,y` is a finger tap at a board point; `--keep-group <reply id>` is
//  Igor's Keep group (#942), the reply's marks kept as ink under one group; `--keep-group <reply id>@<ms>` keeps it
//  as if its picture was taken at that unix ms, so ink made after it makes room under the reply (#894).
//
//  Writes <prefix>.png (after), <prefix>-before.png, <prefix>.result.json (each step's op_result and what it touched)
//  and <prefix>.board.json (the board after, to replay the next batch on). Prints the result JSON. Where there is no
//  CoreGraphics (Linux, #943), the pictures are <prefix>.svg and <prefix>-before.svg, the same marks and
//  words. The result's `picture` and `picture_before` name them.

import ContextCore
import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

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
                             [--tap x,y] [--keep-group <reply id>[@<picture ms>]]
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

func main() throws {
  let args = try Arguments(Array(CommandLine.arguments.dropFirst()))
  let snapshot = try BoardSnapshot(json: try readJSON(args.board))
  var steps: [BoardReplay.Step] = []
  for (i, step) in args.steps.enumerated() {
    if step.kind == "keep" {
      steps.append(.keep(step.value.split(separator: ",").map(String.init)))
    } else if step.kind == "keep-group" {
      // `<reply id>@<ms>`: when the picture it answers was taken, so ink made after it makes room (#894).
      let parts = step.value.split(separator: "@", maxSplits: 1).map(String.init)
      steps.append(.keepGroup(parts[0], seen: parts.count > 1 ? Int64(parts[1]) : nil))
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
  let before = sketch(
    replay.start, outcomes: [], region: area, title: "BEFORE  board \(snapshot.board)  rev \(replay.start.rev ?? 0)")
  let after = sketch(
    replay.board, marks: replay.marks, outcomes: replay.outcomes, region: area,
    title: "AFTER  board \(snapshot.board)  rev \(replay.board.rev ?? 0)")
  let beforePath = try draw(before, scale: args.scale, to: "\(out)-before")
  let afterPath = try draw(after, scale: args.scale, to: out)
  var result: [String: Any] = [
    "board": snapshot.board, "rev_before": replay.start.rev ?? 0, "rev": replay.board.rev ?? 0,
    "steps": replay.outcomes.map(\.wire), "ghosts": replay.board.ghosts.map(\.id),
    "marks": replay.marks.map(\.id),
    "picture": afterPath, "picture_before": beforePath,
    "board_after": "\(out).board.json",
  ]
  // The keys a PNG went under before the SVG (#943), for whoever reads them.
  if afterPath.hasSuffix(".png") {
    result["png"] = afterPath
    result["png_before"] = beforePath
  }
  try writeJSON(result, to: "\(out).result.json")
  try writeJSON(replay.board.json, to: "\(out).board.json")
  let data = try JSONSerialization.data(
    withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data("\n".utf8))
}

/// The picture at `prefix`, as a PNG on the Mac, an SVG where CoreGraphics can't make one: its path.
func draw(_ sketch: Sketch, scale: CGFloat, to prefix: String) throws -> String {
  #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(CoreText)
    try sketch.png(scale: scale, to: prefix + ".png")
    return prefix + ".png"
  #else
    try Data(sketch.svg(scale: scale).utf8).write(to: URL(fileURLWithPath: prefix + ".svg"))
    return prefix + ".svg"
  #endif
}

do {
  try main()
} catch {
  FileHandle.standardError.write(Data("board-ops-harness: \(error)\n".utf8))
  exit(1)
}
