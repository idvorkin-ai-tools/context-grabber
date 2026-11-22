//  touch-replay (story 1105, bead context-grabber-y544): a pulled session log's pen touches judged again on the Mac,
//  and written as a host fixture. The cases and the rules are ContextCore's (`BoardTouchReplay`); here only the
//  arguments and the files.
//
//    touch-replay <log.jsonl> [<log.jsonl> ...] [--board <id>] [--all] [--out <fixture.json>] [--source <text>]
//
//  Prints one line per case: what the iPad decided, what the Mac decides, and DIFFERS where the two part. --out writes
//  the fixture (each case's `expect` is what the Mac says now; edit it to what Igor meant, and the host test fails until
//  the rule does). --all takes every pen touch, writing too; by default only gestures.

import ContextCore
import Foundation

struct Failure: Error, CustomStringConvertible { let description: String }

func run() throws {
  var logs: [String] = []
  var board: String?
  var all = false
  var out: String?
  var source: String?
  var args = CommandLine.arguments.dropFirst()
  func value(_ flag: String) throws -> String {
    guard let next = args.popFirst() else { throw Failure(description: "\(flag) needs a value") }
    return next
  }
  while let arg = args.popFirst() {
    switch arg {
    case "--board": board = try value(arg)
    case "--all": all = true
    case "--out": out = try value(arg)
    case "--source": source = try value(arg)
    case "-h", "--help":
      print("touch-replay <log.jsonl> [...] [--board <id>] [--all] [--out <fixture.json>] [--source <text>]")
      return
    default:
      guard !arg.hasPrefix("--") else { throw Failure(description: "unknown flag \(arg)") }
      logs.append(arg)
    }
  }
  guard !logs.isEmpty else { throw Failure(description: "name a pulled session log (just pull-logs)") }
  var cases: [BoardTouchReplay.Case] = []
  for log in logs {
    let text = try String(contentsOfFile: (log as NSString).expandingTildeInPath, encoding: .utf8)
    cases += BoardTouchReplay.cases(fromLog: text, board: board, all: all)
  }
  var differ = 0
  for c in cases {
    let agrees = BoardTouchReplay.agrees(c)
    if agrees == false { differ += 1 }
    print((agrees == false ? "DIFFERS " : "        ") + c.name)
  }
  print("\(cases.count) cases, \(differ) where the iPad and the Mac differ")
  guard let out else { return }
  let names = logs.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
  let fixture = BoardTouchReplay.Fixture(
    source: source ?? "touch-replay from \(names)\(board.map { ", board \($0)" } ?? ""): board points, ms since the "
      + "touch went down; phone is what the iPad logged, host what the Mac decided when written, expect what it must",
    cases: cases)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  try encoder.encode(fixture).write(to: URL(fileURLWithPath: (out as NSString).expandingTildeInPath))
  print("wrote \(out)")
}

do {
  try run()
} catch {
  FileHandle.standardError.write(Data("touch-replay: \(error)\n".utf8))
  exit(2)
}
