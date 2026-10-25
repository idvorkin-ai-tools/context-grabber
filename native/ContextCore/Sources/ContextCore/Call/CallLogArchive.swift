//  A call's log to the Cockpit's archive (#442, story 210). The bridge has never filed the dump the app sends it at
//  a hang-up, and an automatic report waits for a troubled call and the Mac's listener; a call that merely sounded
//  wrong left nothing Larry could read without the phone. The archive (`POST /archive`, story 270) takes a batch of
//  small records with a guid each, so each event line is one record under the call's key, in order, after a header
//  record saying what the call was. On the box: the `call.log` stream of cockpit-data's archive.sqlite3.

import Foundation

public enum CallLogArchive {
  public static let stream = "call.log"
  /// The archive takes 8 KB per record; one of Larry's captions can be long.
  public static let maxLineChars = 6000
  /// What a guid may hold (the archive's rule); a session the bridge named outside it takes the start-time key.
  private static let guidCharacters = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:+-")

  /// The call's key: the bridge's session from `call_ready`, else `local-<the start's t>`.
  public static func key<S: Sequence>(_ events: S) -> String where S.Element == CallEvent {
    var start: Int?
    for event in events {
      if event.type == "call_start", start == nil { start = event.t }
      if event.type == "call_ready", let session = event.fields["session"] as? String, isKey(session) {
        return session
      }
    }
    return "local-\(start ?? 0)"
  }

  private static func isKey(_ session: String) -> Bool {
    guard let first = session.first, first.isASCII, first.isLetter || first.isNumber, session.count <= 100 else {
      return false
    }
    return session.unicodeScalars.allSatisfy(guidCharacters.contains)
  }

  /// The batch's records: a header first (`guid` `<key>:00000`, the header's fields with spaces as underscores,
  /// `events`), then one per event (`seq`, `t`, `line`), guids in the events' order.
  public static func records(header: [(String, String)], events: ArraySlice<CallEvent>) -> [[String: Any]] {
    let call = key(events)
    var head: [String: Any] = [
      "guid": guid(call, 0), "call": call, "seq": 0, "kind": "header", "events": events.count,
    ]
    for (name, value) in header where !value.isEmpty { head[name.replacingOccurrences(of: " ", with: "_")] = value }
    var out = [head]
    for (i, event) in events.enumerated() {
      let seq = i + 1
      out.append([
        "guid": guid(call, seq), "call": call, "seq": seq, "t": event.t,
        "line": String(event.line.prefix(maxLineChars)),
      ])
    }
    return out
  }

  private static func guid(_ key: String, _ seq: Int) -> String { "\(key):" + String(format: "%05d", seq) }
}
