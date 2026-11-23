// Story 1236 (bead context-grabber-pt1e): the board wasm's stand-ins for Foundation, which it links without ICU, give
// what Foundation gives on the same inputs. Where Linux Foundation (what the wasm ran before) differs from Apple's,
// the expected text is Linux's, pinned from a run there.

import Foundation
import XCTest

@testable import ContextCore

final class FoundationLiteTests: XCTestCase {
  let awkward = [
    "", " ", "  hello  ", "\t\n x \r\n", "\u{00A0}nbsp\u{00A0}", "\u{2028}sep\u{2029}", "\u{0085}nel\u{0085}",
    " \u{0301}combining ", "\u{3000}ideo\u{3000}", "a b", "\u{200B}zero width\u{200B}", "é", "日本 語 ",
    "\u{1680}x\u{205F}",
  ]

  func testTrimmingMatchesFoundation() {
    for s in awkward {
      XCTAssertEqual(LiteText.trimming(s, .whitespaces), s.trimmingCharacters(in: .whitespaces), s.debugDescription)
      XCTAssertEqual(
        LiteText.trimming(s, .whitespacesAndNewlines), s.trimmingCharacters(in: .whitespacesAndNewlines),
        s.debugDescription)
      XCTAssertEqual(
        LiteText.trimming(s, .punctuationCharacters), s.trimmingCharacters(in: .punctuationCharacters),
        s.debugDescription)
    }
    let quoteless = LiteCharacterSet.punctuationCharacters.subtracting(LiteCharacterSet(charactersIn: "'"))
    let foundation = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'"))
    for s in ["'okay.'", "«done»!", "...it's", "¿qué?", "—dash—"] {
      XCTAssertEqual(LiteText.trimming(s, quoteless), s.trimmingCharacters(in: foundation), s)
    }
  }

  func testCharacterSetsMatchFoundationOverTheBMP() {
    let pairs: [(LiteCharacterSet, CharacterSet, String)] = [
      (.whitespaces, .whitespaces, "whitespaces"), (.newlines, .newlines, "newlines"),
      (.whitespacesAndNewlines, .whitespacesAndNewlines, "whitespacesAndNewlines"),
      (.alphanumerics, .alphanumerics, "alphanumerics"), (.punctuationCharacters, .punctuationCharacters, "punct"),
      (.urlFragmentAllowed, .urlFragmentAllowed, "fragment"),
    ]
    for (lite, foundation, name) in pairs {
      var differ: [UInt32] = []
      for value in UInt32(0)...0xFFFF {
        guard let scalar = Unicode.Scalar(value) else { continue }
        if lite.contains(scalar) != foundation.contains(scalar) { differ.append(value) }
      }
      // Foundation's tables can trail the Swift runtime's Unicode version by a few new letters, never more; the
      // spaces and newlines the board trims match exactly.
      let most = ["whitespaces", "newlines", "whitespacesAndNewlines"].contains(name) ? 1 : 100
      XCTAssertLessThan(differ.count, most, "\(name): \(differ.prefix(10).map { String($0, radix: 16) })")
      XCTAssertTrue(differ.allSatisfy { $0 > 0x7F }, "\(name) differs in ASCII: \(differ.prefix(10))")
    }
  }

  func testPercentEncodingMatchesFoundation() {
    var keyAllowed = CharacterSet.alphanumerics
    keyAllowed.insert(charactersIn: "-._~:")
    var liteKeyAllowed = LiteCharacterSet.alphanumerics
    liteKeyAllowed.insert(charactersIn: "-._~:")
    let inputs = [
      "", "plain", "a b", "auto:note:2026-10-25", "a/b?c#d", "100%", "é日本🙂", "x+y=z&w", "tab\there", "~._-",
      "context-grabber-pt1e", "ü\u{0301}",
    ]
    for s in inputs {
      XCTAssertEqual(
        LiteText.addingPercentEncoding(s, .urlFragmentAllowed),
        s.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed), s)
      XCTAssertEqual(
        LiteText.addingPercentEncoding(s, liteKeyAllowed), s.addingPercentEncoding(withAllowedCharacters: keyAllowed), s
      )
    }
    let encoded = [
      "plain", "a%20b", "%E2%9C%93", "%e2%9c%93", "100%", "%", "%Z1", "%2", "%41%42", "%FF", "%C3", "%C3%A9", "a%2Fb",
      "%00", "mixed%20%F0%9F%99%82end",
    ]
    for s in encoded { XCTAssertEqual(LiteText.removingPercentEncoding(s), s.removingPercentEncoding, s) }
  }

  func testComponentsAndPathExtensionMatchFoundation() {
    let set = LiteCharacterSet(charactersIn: "/|()—")
    let foundationSet = CharacterSet(charactersIn: "/|()—")
    for s in ["Something else / Type your own answer", "(other)", "a|b|", "", "—", "none"] {
      XCTAssertEqual(LiteText.components(s, separatedBy: set), s.components(separatedBy: foundationSet), s)
      XCTAssertEqual(
        LiteText.components(s, separatedBy: LiteCharacterSet.alphanumerics.inverted),
        s.components(separatedBy: CharacterSet.alphanumerics.inverted), s)
    }
    for path in [
      "a.png", "dir/a.tar.gz", ".hidden", "noext", "dir.d/noext", "a.", "trailing/", "a.png/", "", "/", "a b.txt",
      "Report final.docx", "2026-11-23/0123456789abcdef.pdf",
    ] {
      XCTAssertEqual(LiteText.pathExtension(path), (path as NSString).pathExtension, path)
    }
  }

  func testAttachmentRefMatchesTheRegex() {
    let regex = #"^\d{4}-\d{2}-\d{2}/[0-9a-f]{16}\.(png|jpg|gif|webp|pdf|txt|docx|xlsx|pptx)$"#
    for ref in [
      "2026-11-23/0123456789abcdef.png", "2026-11-23/0123456789abcdef.pptx", "2026-11-23/0123456789ABCDEF.png",
      "2026-11-23/0123456789abcde.png", "2026-11-23/0123456789abcdef.exe", "2026-11-23/0123456789abcdef.png.png",
      "26-11-23/0123456789abcdef.png", "2026-11-23/0123456789abcdef.", "x2026-11-23/0123456789abcdef.png", "",
    ] {
      XCTAssertEqual(LiteText.isAttachmentRef(ref), ref.range(of: regex, options: .regularExpression) != nil, ref)
    }
  }

  func testFormatMatchesFoundation() {
    XCTAssertEqual(LiteText.format("#%06x", [UInt32(0xAB12)]), String(format: "#%06x", UInt32(0xAB12)))
    XCTAssertEqual(LiteText.format("#%06X", [UInt32(0xab12ff)]), String(format: "#%06X", UInt32(0xab12ff)))
    XCTAssertEqual(LiteText.format("%016llx", [UInt64.max - 5]), String(format: "%016llx", UInt64.max - 5))
    XCTAssertEqual(LiteText.format("%016llx", [UInt64(42)]), String(format: "%016llx", UInt64(42)))
    XCTAssertEqual(LiteText.format("%02d", [7]), String(format: "%02d", 7))
    XCTAssertEqual(LiteText.format("%02d", [123]), String(format: "%02d", 123))
    XCTAssertEqual(LiteText.format("%06d", [42]), String(format: "%06d", 42))
    XCTAssertEqual(LiteText.format("%06d", [-42]), String(format: "%06d", -42))
    XCTAssertEqual(LiteText.format("#%02x%02x%02x", [255, 0, 16]), String(format: "#%02x%02x%02x", 255, 0, 16))
    XCTAssertEqual(LiteText.format("100%% %d", [3]), String(format: "100%% %d", 3))
  }

  func testDatesMatchFoundation() {
    let plain = ISO8601DateFormatter()
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let strings = [
      "2026-11-23T12:00:00Z", "2026-11-23T12:00:00.123Z", "2026-11-23T12:00:00.5Z", "1969-07-20T20:17:40Z",
      "2000-02-29T23:59:59.999Z", "2026-11-23T12:00:00+05:30", "2026-11-23T12:00:00.250-08:00", "2026-11-23 12:00:00Z",
      "2026-11-23T12:00Z", "2026-13-01T00:00:00Z", "garbage", "", "2026-11-23T12:00:00", "1900-01-01T00:00:00Z",
    ]
    for s in strings {
      XCTAssertEqual(LiteISO8601().date(from: s), plain.date(from: s), "plain \(s)")
      let lite = LiteISO8601(fractionalSeconds: true).date(from: s)?.timeIntervalSince1970
      let foundation = fractional.date(from: s)?.timeIntervalSince1970
      XCTAssertEqual(lite == nil, foundation == nil, "fractional \(s)")
      if let lite, let foundation { XCTAssertEqual(lite, foundation, accuracy: 0.0005, "fractional \(s)") }
    }
    for t in [0, 1_763_900_000.123, 1_763_900_000.9995, -1.5, -86_400 * 365 * 70.0, 951_868_799.999] {
      let date = Date(timeIntervalSince1970: t)
      XCTAssertEqual(LiteISO8601().string(from: date), plain.string(from: date), "\(t)")
      XCTAssertEqual(LiteISO8601(fractionalSeconds: true).string(from: date), fractional.string(from: date), "\(t)")
    }
    let posix = { (format: String, zone: TimeZone, date: Date) -> String in
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = zone
      f.dateFormat = format
      return f.string(from: date)
    }
    for zone in ["UTC", "America/Los_Angeles", "Asia/Kolkata", "Pacific/Chatham"].compactMap(TimeZone.init(identifier:))
    {
      for t in [0, 1_763_900_000, 1_763_946_000, 1_741_510_800, 1_700_000_000, -100_000] as [Double] {
        let date = Date(timeIntervalSince1970: t)
        XCTAssertEqual(LiteText.weekdayTime(date, timeZone: zone), posix("EEE h:mm a", zone, date), "\(zone) \(t)")
        XCTAssertEqual(LiteText.monthDay(date, timeZone: zone), posix("MMM d", zone, date), "\(zone) \(t)")
      }
    }
  }

  func testJSONReadsWhatFoundationReads() throws {
    let texts = [
      #"{"a":1,"b":[true,false,null],"c":"x\/y\u00e9\ud83d\ude42","d":-0.5e3,"e":{}}"#, #"[]"#, #" [ 1 , 2 ] "#,
      #"{"t":1700000000000,"x":3.0,"y":1e2,"z":-7}"#, #"{"s":"tab\tnew\nquote\"back\\"}"#,
    ]
    for text in texts {
      let lite = try LiteJSON.object(with: Data(text.utf8))
      let foundation = try JSONSerialization.jsonObject(with: Data(text.utf8))
      XCTAssertEqual(try canonical(lite), try canonical(foundation), text)
    }
    for bad in ["not json", "", "{", #"{"a" 1}"#, "01", "1.", "\"\u{1}\"", #""\ud83d""#, "[1] x", "tru", "\"x\""] {
      XCTAssertThrowsError(try LiteJSON.object(with: Data(bad.utf8)), bad)
      XCTAssertThrowsError(try JSONSerialization.jsonObject(with: Data(bad.utf8)), bad)
    }
    XCTAssertEqual(try LiteJSON.object(with: Data("\"x\"".utf8), fragmentsAllowed: true) as? String, "x")
  }

  func testJSONReadsNumbersAsTheBoardNeeds() throws {
    let json = try XCTUnwrap(
      try LiteJSON.object(with: Data(#"{"t":1700000000000,"x":3.0,"y":1,"b":true,"f":2.5}"#.utf8)) as? [String: Any])
    XCTAssertEqual(json["t"] as? Int64, 1_700_000_000_000)
    XCTAssertEqual(json["x"] as? Double, 3.0)
    XCTAssertEqual(json["y"] as? Int64, 1)
    XCTAssertEqual(json["b"] as? Bool, true)
    XCTAssertTrue(json["n"] == nil)
    XCTAssertEqual(try LiteJSON.object(with: Data("[null]".utf8)) as? [LiteNull], [LiteNull()])
    // JSONNumber reads Foundation's NSNumber here as it reads LiteJSON's values on the wasm.
    let foundation = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: Data(#"{"t":1700000000000,"x":3.5,"b":true}"#.utf8)) as? [String: Any])
    XCTAssertEqual(JSONNumber(foundation["t"])?.int64Value, 1_700_000_000_000)
    XCTAssertEqual(JSONNumber(foundation["x"])?.intValue, 3)
    XCTAssertEqual(JSONNumber(foundation["x"])?.doubleValue, 3.5)
    XCTAssertTrue(JSONNumber.isBool(foundation["b"]))
    XCTAssertFalse(JSONNumber.isBool(foundation["t"]))
    XCTAssertEqual(JSONNumber.int(foundation["t"]), 1_700_000_000_000)
    XCTAssertNil(JSONNumber.int(foundation["x"]))
  }

  func testJSONWritesAsLinuxFoundationDoes() throws {
    let write = { (object: Any) in String(decoding: try LiteJSON.data(object, sortedKeys: true), as: UTF8.self) }
    // Pinned from swift-corelibs-foundation 6.4: slashes escaped, control characters as lower-case \u00XX, the rest raw.
    XCTAssertEqual(
      try write(["a/b\u{1}\u{1f}é\u{7f}\u{2028}\"\\\t\n\u{8}\u{c}"]),
      #"["a\/b\u0001\u001fé\#u{7f}\#u{2028}\"\\\t\n\b\f"]"#)
    XCTAssertEqual(
      try write([1e20, 1.5e-7, 3.0, 0.1 + 0.2, Int64(1_700_000_000_000), Float(0.3) + Float(0.6), Float(3), true, -0.0]
      ),
      "[1e+20,1.5e-07,3,0.30000000000000004,1700000000000,0.90000004,3,true,-0]")
    XCTAssertEqual(
      try write([
        "b10": 1, "B9": 1, "a": 1, "_x": 1, "Z": 1, "a2": 1, "a10": 1, "A": 1, "e": 1, "f": 1, "-": 1, "a b": 1,
        "s9": 1, "s09": 1, "s10": 1,
      ]), #"{"_x":1,"-":1,"a":1,"A":1,"a b":1,"a2":1,"a10":1,"B9":1,"b10":1,"e":1,"f":1,"s9":1,"s09":1,"s10":1,"Z":1}"#)
    XCTAssertEqual(
      try write(["n": LiteNull(), "o": Optional<Int>.none as Any, "p": Optional(2) as Any]),
      #"{"n":null,"o":null,"p":2}"#)
    XCTAssertThrowsError(try LiteJSON.data("top"))
    XCTAssertThrowsError(try LiteJSON.data([Double.nan]))
    XCTAssertThrowsError(try LiteJSON.data([Date()]))
    XCTAssertFalse(LiteJSON.isValid([Date()]))
    XCTAssertTrue(LiteJSON.isValid(["a": [1, "b"]]))
    // Writing what it read gives back the same JSON.
    let text = #"{"list":[{"hidden":false,"id":"s1","points":[[1.5,2],[3,4.25]]}],"rev":12}"#
    XCTAssertEqual(try write(try LiteJSON.object(with: Data(text.utf8))), text)
  }

  func testJSONFailureReadsAsLinuxFoundationsError() {
    XCTAssertThrowsError(try LiteJSON.object(with: Data("not json".utf8))) { error in
      XCTAssertEqual(
        "\(error)",
        #"Error Domain=NSCocoaErrorDomain Code=3840 "The data is not in the correct format."UserInfo={NSDebugDescription=Invalid value around character 1.}"#
      )
    }
  }

  /// A JSON value as sorted, typed text, so Foundation's NSNumbers and LiteJSON's Swift numbers compare by value.
  private func canonical(_ value: Any) throws -> String {
    switch value {
    case let d as [String: Any]:
      return try "{" + d.keys.sorted().map { "\($0):\(try canonical(d[$0]!))" }.joined(separator: ",") + "}"
    case let a as [Any]: return try "[" + a.map(canonical).joined(separator: ",") + "]"
    case let s as String: return "s:" + s
    case is NSNull, is LiteNull: return "null"
    default:
      if JSONNumber.isBool(value) { return "b:\(value as? Bool ?? false)" }
      guard let n = JSONNumber(value) else {
        throw NSError(domain: "unexpected \(type(of: value))", code: 0)
      }
      return "n:\(n.doubleValue)"
    }
  }
}
