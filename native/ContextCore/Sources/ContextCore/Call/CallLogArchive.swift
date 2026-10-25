//  A call's log to the Cockpit's archive (#442, story 212). The bridge has never filed the dump the app sends it at
//  a hang-up, and an automatic report waits for a troubled call and the Mac's listener; a call that merely sounded
//  wrong left nothing Larry could read without the phone. The archive (`POST /archive`, story 270) takes a batch of
//  small records with a guid each, so each event line is one record under the call's key, in order, after a header
//  record saying what the call was. On the box: the `call.log` stream of cockpit-data's archive.sqlite3.

import Foundation

public enum CallLogArchive {
  public static let stream = "call.log"
  /// The archive takes 8 KB per record, measured as the record's JSON; a long caption, escaped or not ASCII, is cut
  /// until its whole record fits (Codex on #443).
  public static let maxRecordBytes = 8000
  /// What a guid may hold (the archive's rule); a session the bridge named outside it takes the start-time key.
  private static let guidCharacters = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:+-")

  /// The call's key: the bridge's session from `call_ready`, else `fallback`. A call's `t` counts from the app's
  /// launch, so the fallback is a fresh id: two failed calls from different launches never share a key, and the
  /// archive (which drops a guid it has) never takes one for the other (Codex on #443).
  public static func key<S: Sequence>(_ events: S, fallback: String = newLocalKey()) -> String
  where S.Element == CallEvent {
    for event in events
    where event.type == "call_ready" {
      if let session = event.fields["session"] as? String, isKey(session) { return session }
    }
    return fallback
  }

  public static func newLocalKey() -> String { "local-" + UUID().uuidString.lowercased() }

  private static func isKey(_ session: String) -> Bool {
    guard let first = session.first, first.isASCII, first.isLetter || first.isNumber, session.count <= 100 else {
      return false
    }
    return session.unicodeScalars.allSatisfy(guidCharacters.contains)
  }

  /// The batch's records: a header first (`guid` `<key>:00000`, the header's fields with spaces as underscores,
  /// `events`), then one per event (`seq`, `t`, `line`), guids in the events' order.
  public static func records(
    header: [(String, String)], events: ArraySlice<CallEvent>, fallback: String = newLocalKey()
  ) -> [[String: Any]] {
    let call = key(events, fallback: fallback)
    var head: [String: Any] = [
      "guid": guid(call, 0), "call": call, "seq": 0, "kind": "header", "events": events.count,
    ]
    // Each field goes in with what room is left (Codex on #523), shortest first: a long problem or ending never
    // costs the batch, nor the route and bridge beside it.
    for (name, value) in header.sorted(by: { $0.1.utf8.count < $1.1.utf8.count }) where !value.isEmpty {
      head = fitted(head, field: name.replacingOccurrences(of: " ", with: "_"), text: value)
    }
    var out = [head]
    for (i, event) in events.enumerated() {
      let seq = i + 1
      out.append(
        fitted(["guid": guid(call, seq), "call": call, "seq": seq, "t": event.t], field: "line", text: event.line))
    }
    return out
  }

  /// The record with as much of `text` in `field` as keeps the record's JSON within `maxRecordBytes`.
  static func fitted(_ record: [String: Any], field: String, text line: String) -> [String: Any] {
    func size(_ text: Substring) -> Int {
      var r = record
      r[field] = String(text)
      return (try? JSONSerialization.data(withJSONObject: r))?.count ?? Int.max
    }
    var out = record
    guard size(line[...]) > maxRecordBytes else {
      out[field] = line
      return out
    }
    var low = 0
    var high = line.count
    while low < high {  // the longest prefix that fits
      let mid = (low + high + 1) / 2
      if size(line.prefix(mid)) <= maxRecordBytes { low = mid } else { high = mid - 1 }
    }
    if low > 0 { out[field] = String(line.prefix(low)) }  // no room at all: the field stays out
    return out
  }

  private static func guid(_ key: String, _ seq: Int) -> String { "\(key):" + String(format: "%05d", seq) }
}
