//  One record for the Cockpit's archive (`POST /archive`, story 270), cut to fit: the call's log and the board's both
//  send their lines this way. In ChatWireKit, below ContextCore, so the board's module can reach it too
//  (plan 2026-11-22-contextcore-targets-plan.md).

import Foundation

public enum ArchiveRecord {
  /// The archive takes 8 KB per record, measured as the record's JSON; a long caption, escaped or not ASCII, is cut
  /// until its whole record fits (Codex on #443).
  public static let maxBytes = 8000

  /// The record with as much of `text` in `field` as keeps the record's JSON within `maxBytes`.
  public static func fitted(_ record: [String: Any], field: String, text line: String) -> [String: Any] {
    func size(_ text: Substring) -> Int {
      var r = record
      r[field] = String(text)
      return (try? JSONSerialization.data(withJSONObject: r))?.count ?? Int.max
    }
    var out = record
    guard size(line[...]) > maxBytes else {
      out[field] = line
      return out
    }
    var low = 0
    var high = line.count
    while low < high {  // the longest prefix that fits
      let mid = (low + high + 1) / 2
      if size(line.prefix(mid)) <= maxBytes { low = mid } else { high = mid - 1 }
    }
    if low > 0 { out[field] = String(line.prefix(low)) }  // no room at all: the field stays out
    return out
  }
}
