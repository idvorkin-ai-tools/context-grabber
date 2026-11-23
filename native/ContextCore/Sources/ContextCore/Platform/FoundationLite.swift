//  The few Foundation pieces the board's rules use that FoundationEssentials lacks, written out so the board wasm
//  links no ICU (bead context-grabber-pt1e, story 1236). Built everywhere and tested on the Mac against Foundation;
//  only the wasm build (FOUNDATION_ESSENTIALS_ONLY) calls them, through FoundationLiteShims.swift, so the app keeps
//  Foundation's own. Where Linux Foundation, which the wasm used before, differs from Apple's, they follow Linux's.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

// MARK: Character sets

/// A set of Unicode scalars, as a test. Foundation's `CharacterSet` without ICU.
public struct LiteCharacterSet: Sendable {
  let test: @Sendable (Unicode.Scalar) -> Bool

  public init(_ test: @escaping @Sendable (Unicode.Scalar) -> Bool) { self.test = test }

  public init(charactersIn string: String) {
    let scalars = Set(string.unicodeScalars)
    test = { scalars.contains($0) }
  }

  public func contains(_ scalar: Unicode.Scalar) -> Bool { test(scalar) }

  public var inverted: LiteCharacterSet {
    let test = test
    return LiteCharacterSet { !test($0) }
  }

  public func union(_ other: LiteCharacterSet) -> LiteCharacterSet {
    let (a, b) = (test, other.test)
    return LiteCharacterSet { a($0) || b($0) }
  }

  public func subtracting(_ other: LiteCharacterSet) -> LiteCharacterSet {
    let (a, b) = (test, other.test)
    return LiteCharacterSet { a($0) && !b($0) }
  }

  public mutating func insert(charactersIn string: String) { self = union(LiteCharacterSet(charactersIn: string)) }

  /// Unicode's space separators (Zs), the tab, and the zero-width space, as Foundation's table has it.
  public static let whitespaces = LiteCharacterSet {
    $0 == "\t" || $0.value == 0x200B || $0.properties.generalCategory == .spaceSeparator
  }
  /// U+000A to U+000D, NEL, and the line and paragraph separators.
  public static let newlines = LiteCharacterSet {
    (0x0A...0x0D).contains($0.value) || $0.value == 0x85 || $0.value == 0x2028 || $0.value == 0x2029
  }
  public static let whitespacesAndNewlines = whitespaces.union(newlines)
  /// Letters, marks and numbers (Unicode's L*, M* and N*).
  public static let alphanumerics = LiteCharacterSet {
    switch $0.properties.generalCategory {
    case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .nonspacingMark,
      .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber:
      return true
    default: return false
    }
  }
  /// Unicode's punctuation (P*).
  public static let punctuationCharacters = LiteCharacterSet {
    switch $0.properties.generalCategory {
    case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
      .finalPunctuation, .otherPunctuation:
      return true
    default: return false
    }
  }
  static let asciiAlphanumerics = LiteCharacterSet {
    $0.isASCII && $0.properties.isAlphabetic || ("0"..."9").contains($0)
  }
  public static let urlFragmentAllowed = asciiAlphanumerics.union(LiteCharacterSet(charactersIn: "!$&'()*+,-./:;=?@_~"))
}

// MARK: Text

public enum LiteText {
  /// `trimmingCharacters(in:)`: the scalars of `set` cut from both ends.
  public static func trimming<S: StringProtocol>(_ string: S, _ set: LiteCharacterSet) -> String {
    let scalars = string.unicodeScalars
    guard let first = scalars.firstIndex(where: { !set.contains($0) }),
      let last = scalars.lastIndex(where: { !set.contains($0) })
    else { return "" }
    return String(String.UnicodeScalarView(scalars[first...last]))
  }

  /// `addingPercentEncoding(withAllowedCharacters:)`: every scalar outside `allowed`, and every one past ASCII, as
  /// its UTF-8 bytes in upper-case `%XX`.
  public static func addingPercentEncoding<S: StringProtocol>(_ string: S, _ allowed: LiteCharacterSet) -> String {
    var out = ""
    for scalar in string.unicodeScalars {
      if scalar.isASCII && allowed.contains(scalar) {
        out.unicodeScalars.append(scalar)
        continue
      }
      for byte in String(scalar).utf8 { out += "%" + hex(byte >> 4) + hex(byte & 0xF) }
    }
    return out
  }

  private static func hex(_ nibble: UInt8) -> String { String(UnicodeScalar(nibble < 10 ? 48 + nibble : 55 + nibble)) }

  /// `removingPercentEncoding`: nil for a `%` without two hex digits after it, or bytes that are not UTF-8.
  public static func removingPercentEncoding<S: StringProtocol>(_ string: S) -> String? {
    var bytes: [UInt8] = []
    var input = Array(string.utf8)[...]
    while let byte = input.popFirst() {
      guard byte == UInt8(ascii: "%") else {
        bytes.append(byte)
        continue
      }
      guard input.count >= 2, let high = nibble(input.removeFirst()), let low = nibble(input.removeFirst()) else {
        return nil
      }
      bytes.append(high << 4 | low)
    }
    return utf8(bytes)
  }

  /// The bytes as a string, or nil when they are not UTF-8.
  static func utf8(_ bytes: [UInt8]) -> String? {
    let string = String(decoding: bytes, as: UTF8.self)
    return Array(string.utf8) == bytes ? string : nil
  }

  private static func nibble(_ c: UInt8) -> UInt8? {
    switch c {
    case 48...57: return c - 48
    case 65...70: return c - 55
    case 97...102: return c - 87
    default: return nil
    }
  }

  /// `components(separatedBy:)` with a character set: split at every scalar of `set`, empty pieces kept.
  public static func components<S: StringProtocol>(_ string: S, separatedBy set: LiteCharacterSet) -> [String] {
    var out: [String] = []
    var piece = String.UnicodeScalarView()
    for scalar in string.unicodeScalars {
      if set.contains(scalar) {
        out.append(String(piece))
        piece = String.UnicodeScalarView()
      } else {
        piece.append(scalar)
      }
    }
    out.append(String(piece))
    return out
  }

  /// `String(format:)` for whole numbers: `%%` and `%d`, `%x` or `%X` with an optional zero flag, width and `l`/`ll`.
  public static func format(_ format: String, _ args: [Any]) -> String {
    var out = ""
    var args = args[...]
    var chars = Array(format)[...]
    while let c = chars.popFirst() {
      guard c == "%" else {
        out.append(c)
        continue
      }
      if chars.first == "%" {
        chars.removeFirst()
        out.append("%")
        continue
      }
      let zero = chars.first == "0"
      var width = 0
      while let d = chars.first, let n = d.wholeNumberValue, d.isASCII {
        width = width * 10 + n
        chars.removeFirst()
      }
      var long = 0
      while chars.first == "l" {
        long += 1
        chars.removeFirst()
      }
      guard let conversion = chars.popFirst(), let arg = args.popFirst() else { break }
      let value: Int64
      switch arg {
      case let n as Int: value = Int64(n)
      case let n as Int64: value = n
      case let n as Int32: value = Int64(n)
      case let n as UInt32: value = Int64(n)
      case let n as UInt64: value = Int64(bitPattern: n)
      case let n as UInt: value = Int64(bitPattern: UInt64(n))
      default: value = 0
      }
      var text: String
      switch conversion {
      case "x", "X":
        let bits = long >= 1 ? UInt64(bitPattern: value) : UInt64(UInt32(truncatingIfNeeded: value))
        text = String(bits, radix: 16, uppercase: conversion == "X")
      default:
        text = String(long >= 1 ? value : Int64(Int32(truncatingIfNeeded: value)))
      }
      if text.count < width {
        let pad = String(repeating: zero ? "0" : " ", count: width - text.count)
        if zero, text.hasPrefix("-") { text = "-" + pad + text.dropFirst() } else { text = pad + text }
      }
      out += text
    }
    return out
  }

  /// The regex `^\d{4}-\d{2}-\d{2}/[0-9a-f]{16}\.(png|jpg|gif|webp|pdf|txt|docx|xlsx|pptx)$`, by hand (`\d` taken
  /// as ASCII digits).
  public static func isAttachmentRef(_ ref: String) -> Bool {
    let s = Array(ref.utf8)
    let digit = { (c: UInt8) in (48...57).contains(c) }
    let hex = { (c: UInt8) in (48...57).contains(c) || (97...102).contains(c) }
    guard s.count > 28, s[0..<4].allSatisfy(digit), s[4] == 45, s[5..<7].allSatisfy(digit), s[7] == 45,
      s[8..<10].allSatisfy(digit), s[10] == 47, s[11..<27].allSatisfy(hex), s[27] == 46
    else { return false }
    let ext = String(decoding: s[28...], as: UTF8.self)
    return ["png", "jpg", "gif", "webp", "pdf", "txt", "docx", "xlsx", "pptx"].contains(ext)
  }

  /// `EEE h:mm a` in en_US_POSIX: `Mon 3:07 PM`, at `timeZone`'s offset for that moment.
  public static func weekdayTime(_ date: Date, timeZone: TimeZone) -> String {
    let (days, rest) = localDay(date, timeZone)
    let weekday = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"][((days % 7) + 7) % 7]
    let hour = rest / 3600
    let minute = rest / 60 % 60
    let twelve = hour % 12 == 0 ? 12 : hour % 12
    return "\(weekday) \(twelve):\(minute < 10 ? "0" : "")\(minute) \(hour < 12 ? "AM" : "PM")"
  }

  /// `MMM d` in en_US_POSIX: `Nov 1`, on `timeZone`'s calendar day.
  public static func monthDay(_ date: Date, timeZone: TimeZone) -> String {
    let (_, month, day) = LiteISO8601.civilFromDays(localDay(date, timeZone).days)
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return "\(months[month - 1]) \(day)"
  }

  /// Days since 1970-01-01 and seconds into that day, on `timeZone`'s clock.
  private static func localDay(_ date: Date, _ timeZone: TimeZone) -> (days: Int, seconds: Int) {
    let local = Int(date.timeIntervalSince1970.rounded(.down)) + timeZone.secondsFromGMT(for: date)
    let days = Int((Double(local) / 86400).rounded(.down))
    return (days, local - days * 86400)
  }

  /// `(path as NSString).pathExtension`: what follows the last dot of the last path component, or "".
  public static func pathExtension(_ path: String) -> String {
    var trimmed = Substring(path)
    while trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }
    let name = trimmed.split(separator: "/", omittingEmptySubsequences: false).last ?? ""
    guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
    let ext = name[name.index(after: dot)...]
    return String(ext)
  }
}

// MARK: Dates

/// `ISO8601DateFormatter` for the internet date-time form, `2026-11-23T12:00:00Z` or with `.123` before the zone, in
/// UTC. Without fractional seconds it reads only whole seconds; with them, only a fraction.
public struct LiteISO8601: Sendable {
  public var fractionalSeconds = false

  public init(fractionalSeconds: Bool = false) { self.fractionalSeconds = fractionalSeconds }

  public func date(from string: String) -> Date? {
    let s = Array(string.utf8)
    func digits(_ at: Int, _ count: Int) -> Int? {
      guard at + count <= s.count else { return nil }
      var n = 0
      for c in s[at..<at + count] {
        guard (48...57).contains(c) else { return nil }
        n = n * 10 + Int(c - 48)
      }
      return n
    }
    func at(_ i: Int, _ c: Unicode.Scalar) -> Bool { i < s.count && UInt32(s[i]) == c.value }
    guard let year = digits(0, 4), at(4, "-"), let month = digits(5, 2), at(7, "-"), let day = digits(8, 2),
      at(10, "T"), let hour = digits(11, 2), at(13, ":"), let minute = digits(14, 2), at(16, ":"),
      let second = digits(17, 2), (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60,
      second < 61
    else { return nil }
    var i = 19
    var fraction = 0.0
    if fractionalSeconds {
      guard at(i, ".") else { return nil }
      i += 1
      var scale = 0.1
      let start = i
      while i < s.count, (48...57).contains(s[i]) {
        fraction += Double(s[i] - 48) * scale
        scale /= 10
        i += 1
      }
      guard i > start else { return nil }
    }
    var offset = 0
    if at(i, "Z") {
      i += 1
    } else if at(i, "+") || at(i, "-") {
      let sign = at(i, "-") ? -1 : 1
      guard let h = digits(i + 1, 2), at(i + 3, ":"), let m = digits(i + 4, 2) else { return nil }
      offset = sign * (h * 3600 + m * 60)
      i += 6
    } else {
      return nil
    }
    guard i == s.count else { return nil }
    let days = Self.daysFromCivil(year, month, day)
    let seconds = days * 86400 + hour * 3600 + minute * 60 + second - offset
    return Date(timeIntervalSince1970: Double(seconds) + fraction)
  }

  public func string(from date: Date) -> String {
    // To the nearest millisecond first, as Foundation does; without the fraction, the seconds are then cut.
    let total = Int((date.timeIntervalSince1970 * 1000).rounded())
    let seconds = Int((Double(total) / 1000).rounded(.down))
    let millis = total - seconds * 1000
    let days = Int((Double(seconds) / 86400).rounded(.down))
    let rest = seconds - days * 86400
    let (y, m, d) = Self.civilFromDays(days)
    func pad(_ n: Int, _ width: Int) -> String {
      let s = String(n)
      return String(repeating: "0", count: max(0, width - s.count)) + s
    }
    var out =
      "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))T\(pad(rest / 3600, 2)):\(pad(rest / 60 % 60, 2)):\(pad(rest % 60, 2))"
    if fractionalSeconds { out += "." + pad(millis, 3) }
    return out + "Z"
  }

  // Howard Hinnant's days-from-civil and its inverse, proleptic Gregorian.
  static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
  }

  static func civilFromDays(_ days: Int) -> (Int, Int, Int) {
    let z = days + 719468
    let era = (z >= 0 ? z : z - 146096) / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
  }
}

// MARK: JSON

/// JSON's null, as `NSNull` is in Foundation.
public final class LiteNull: Equatable, Hashable, Sendable {
  public init() {}
  public static func == (lhs: LiteNull, rhs: LiteNull) -> Bool { true }
  public func hash(into hasher: inout Hasher) {}
}

/// `JSONSerialization` for the board: it reads to `[String: Any]`, `[Any]`, `String`, `Bool`, `Int64` (a whole
/// number that fits), `Double` and `LiteNull`, and writes those and the other integer and float types back as Linux
/// Foundation writes them: `/` escaped, a double's `.0` dropped, sorted keys in collation order.
public enum LiteJSON {
  /// Why JSON couldn't be read or written, printed as Linux Foundation prints its own error, which the board's
  /// errors used to carry.
  public struct Failure: Error, Equatable, CustomStringConvertible {
    public let message: String

    public var description: String {
      #"Error Domain=NSCocoaErrorDomain Code=3840 "The data is not in the correct format."UserInfo={NSDebugDescription="#
        + message + "}"
    }
  }

  public static func object(with data: Data, fragmentsAllowed: Bool = false) throws -> Any {
    var parser = Parser(bytes: Array(data))
    parser.skipSpace()
    let value = try parser.value(depth: 0)
    parser.skipSpace()
    guard parser.at == parser.bytes.count else { throw Failure(message: "garbage at end") }
    guard fragmentsAllowed || value is [String: Any] || value is [Any] else {
      throw Failure(message: "top level is not an object or array")
    }
    return value
  }

  public static func data(_ object: Any, sortedKeys: Bool = false, fragmentsAllowed: Bool = false) throws -> Data {
    guard fragmentsAllowed || isContainer(object) else { throw Failure(message: "top level is not an object or array") }
    var out: [UInt8] = []
    try write(object, sortedKeys: sortedKeys, into: &out)
    return Data(out)
  }

  public static func isValid(_ object: Any) -> Bool {
    guard isContainer(object) else { return false }
    var out: [UInt8] = []
    return (try? write(object, sortedKeys: false, into: &out)) != nil
  }

  private static func isContainer(_ object: Any) -> Bool {
    let value = unwrap(object)
    return value is [String: Any] || value is [Any]
  }

  private static func unwrap(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return value }
    return mirror.children.first.flatMap { unwrap($0.value) }
  }

  private static func write(_ object: Any, sortedKeys: Bool, into out: inout [UInt8]) throws {
    guard let value = unwrap(object) else {
      out += Array("null".utf8)
      return
    }
    switch value {
    case let string as String: writeString(string, into: &out)
    case let bool as Bool: out += Array((bool ? "true" : "false").utf8)
    case let n as Int: out += Array(String(n).utf8)
    case let n as Int64: out += Array(String(n).utf8)
    case let n as Int32: out += Array(String(n).utf8)
    case let n as Int16: out += Array(String(n).utf8)
    case let n as Int8: out += Array(String(n).utf8)
    case let n as UInt: out += Array(String(n).utf8)
    case let n as UInt64: out += Array(String(n).utf8)
    case let n as UInt32: out += Array(String(n).utf8)
    case let n as UInt16: out += Array(String(n).utf8)
    case let n as UInt8: out += Array(String(n).utf8)
    case let n as Double: try writeFloat(n, into: &out)
    case let n as Float: try writeFloat(n, into: &out)
    case is LiteNull: out += Array("null".utf8)
    case let array as [Any]:
      out.append(UInt8(ascii: "["))
      for (i, element) in array.enumerated() {
        if i > 0 { out.append(UInt8(ascii: ",")) }
        try write(element, sortedKeys: sortedKeys, into: &out)
      }
      out.append(UInt8(ascii: "]"))
    case let dictionary as [String: Any]:
      out.append(UInt8(ascii: "{"))
      let pairs = sortedKeys ? dictionary.sorted { collationOrder($0.key, $1.key) } : Array(dictionary)
      for (i, pair) in pairs.enumerated() {
        if i > 0 { out.append(UInt8(ascii: ",")) }
        writeString(pair.key, into: &out)
        out.append(UInt8(ascii: ":"))
        try write(pair.value, sortedKeys: sortedKeys, into: &out)
      }
      out.append(UInt8(ascii: "}"))
    default: throw Failure(message: "Invalid object cannot be serialized: \(type(of: value))")
    }
  }

  private static func writeFloat<F: BinaryFloatingPoint & LosslessStringConvertible>(_ n: F, into out: inout [UInt8])
    throws
  {
    guard n.isFinite else { throw Failure(message: "Invalid number value (\(n)) in JSON write") }
    var text = n.description
    if text.hasSuffix(".0") { text.removeLast(2) }
    out += Array(text.utf8)
  }

  private static func writeString(_ string: String, into out: inout [UInt8]) {
    out.append(UInt8(ascii: "\""))
    for scalar in string.unicodeScalars {
      switch scalar {
      case "\"": out += Array(#"\""#.utf8)
      case "\\": out += Array(#"\\"#.utf8)
      case "/": out += Array(#"\/"#.utf8)
      case "\u{8}": out += Array(#"\b"#.utf8)
      case "\u{c}": out += Array(#"\f"#.utf8)
      case "\n": out += Array(#"\n"#.utf8)
      case "\r": out += Array(#"\r"#.utf8)
      case "\t": out += Array(#"\t"#.utf8)
      case "\u{0}"..."\u{1f}":
        let hex = String(scalar.value, radix: 16)
        out += Array(("\\u" + String(repeating: "0", count: 4 - hex.count) + hex).utf8)
      default: out += Array(String(scalar).utf8)
      }
    }
    out.append(UInt8(ascii: "\""))
  }

  /// The order Linux Foundation's sorted keys take (a numeric, case-insensitive comparison in the root collation):
  /// whitespace, then punctuation and symbols in the collation's own order, digits as numbers, letters with lower
  /// case first. Past ASCII, scalars sort by value after everything ASCII.
  static func collationOrder(_ a: String, _ b: String) -> Bool {
    let (x, y) = (collationKey(a), collationKey(b))
    if x.primary != y.primary { return x.primary.lexicographicallyPrecedes(y.primary) }
    if x.tertiary != y.tertiary { return x.tertiary.lexicographicallyPrecedes(y.tertiary) }
    if a.unicodeScalars.count != b.unicodeScalars.count { return a.unicodeScalars.count < b.unicodeScalars.count }
    return a.unicodeScalars.lexicographicallyPrecedes(b.unicodeScalars)
  }

  private static let punctuation = Array("\t\n\u{b}\u{c}\r _-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$".unicodeScalars)

  private struct CollationKey {
    var primary: [UInt64] = []
    var tertiary: [UInt8] = []
  }

  private static func collationKey(_ string: String) -> CollationKey {
    var key = CollationKey()
    let scalars = Array(string.unicodeScalars)
    var i = 0
    while i < scalars.count {
      let s = scalars[i]
      if ("0"..."9").contains(s) {
        var n: UInt64 = 0
        var overflow = false
        while i < scalars.count, ("0"..."9").contains(scalars[i]) {
          let (m, o1) = n.multipliedReportingOverflow(by: 10)
          let (a, o2) = m.addingReportingOverflow(UInt64(scalars[i].value - 48))
          overflow = overflow || o1 || o2
          n = a
          i += 1
        }
        key.primary += [1 << 40, overflow ? UInt64.max >> 1 : n]
        continue
      }
      if let p = punctuation.firstIndex(of: s) {
        key.primary.append(UInt64(p))
        key.tertiary.append(0)
      } else if s.isASCII, s.properties.isAlphabetic {
        let lower = s.value | 0x20
        key.primary.append(2 << 40 + UInt64(lower))
        key.tertiary.append(s.value == lower ? 0 : 1)
      } else {
        key.primary.append(3 << 40 + UInt64(s.value))
        key.tertiary.append(0)
      }
      i += 1
    }
    return key
  }

  private struct Parser {
    let bytes: [UInt8]
    var at = 0

    mutating func skipSpace() {
      while at < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[at]) { at += 1 }
    }

    func fail(_ what: String) -> Failure { Failure(message: "\(what) around character \(at).") }
    func invalid() -> Failure { Failure(message: "Invalid value around character \(at).") }

    mutating func value(depth: Int) throws -> Any {
      guard depth < 512 else { throw fail("too deep") }
      guard at < bytes.count else { throw fail("unexpected end") }
      switch bytes[at] {
      case UInt8(ascii: "{"):
        at += 1
        var object: [String: Any] = [:]
        skipSpace()
        if at < bytes.count, bytes[at] == UInt8(ascii: "}") {
          at += 1
          return object
        }
        while true {
          skipSpace()
          guard at < bytes.count, bytes[at] == UInt8(ascii: "\"") else { throw fail("expected a key") }
          let key = try string()
          skipSpace()
          guard at < bytes.count, bytes[at] == UInt8(ascii: ":") else { throw fail("expected :") }
          at += 1
          skipSpace()
          object[key] = try value(depth: depth + 1)
          skipSpace()
          guard at < bytes.count else { throw fail("unexpected end") }
          if bytes[at] == UInt8(ascii: ",") {
            at += 1
            continue
          }
          guard bytes[at] == UInt8(ascii: "}") else { throw fail("expected , or }") }
          at += 1
          return object
        }
      case UInt8(ascii: "["):
        at += 1
        var array: [Any] = []
        skipSpace()
        if at < bytes.count, bytes[at] == UInt8(ascii: "]") {
          at += 1
          return array
        }
        while true {
          skipSpace()
          array.append(try value(depth: depth + 1))
          skipSpace()
          guard at < bytes.count else { throw fail("unexpected end") }
          if bytes[at] == UInt8(ascii: ",") {
            at += 1
            continue
          }
          guard bytes[at] == UInt8(ascii: "]") else { throw fail("expected , or ]") }
          at += 1
          return array
        }
      case UInt8(ascii: "\""): return try string()
      case UInt8(ascii: "t"): return try literal("true", true)
      case UInt8(ascii: "f"): return try literal("false", false)
      case UInt8(ascii: "n"): return try literal("null", LiteNull())
      default: return try number()
      }
    }

    mutating func literal(_ word: String, _ value: Any) throws -> Any {
      let w = Array(word.utf8)
      for (i, c) in w.enumerated() where at + i >= bytes.count || bytes[at + i] != c {
        at += i
        throw invalid()
      }
      at += w.count
      return value
    }

    mutating func number() throws -> Any {
      let start = at
      var integral = true
      if at < bytes.count, bytes[at] == UInt8(ascii: "-") { at += 1 }
      let digitsStart = at
      while at < bytes.count, (48...57).contains(bytes[at]) { at += 1 }
      guard at > digitsStart else { throw invalid() }
      guard bytes[digitsStart] != 48 || at == digitsStart + 1 else { throw fail("leading zero") }
      if at < bytes.count, bytes[at] == UInt8(ascii: ".") {
        integral = false
        at += 1
        let fraction = at
        while at < bytes.count, (48...57).contains(bytes[at]) { at += 1 }
        guard at > fraction else { throw fail("bad fraction") }
      }
      if at < bytes.count, bytes[at] == UInt8(ascii: "e") || bytes[at] == UInt8(ascii: "E") {
        integral = false
        at += 1
        if at < bytes.count, bytes[at] == UInt8(ascii: "+") || bytes[at] == UInt8(ascii: "-") { at += 1 }
        let exponent = at
        while at < bytes.count, (48...57).contains(bytes[at]) { at += 1 }
        guard at > exponent else { throw fail("bad exponent") }
      }
      let text = String(decoding: bytes[start..<at], as: UTF8.self)
      if integral, let n = Int64(text) { return n }
      guard let d = Double(text) else { throw fail("bad number") }
      return d
    }

    mutating func string() throws -> String {
      at += 1
      var out: [UInt8] = []
      while true {
        guard at < bytes.count else { throw fail("unterminated string") }
        let c = bytes[at]
        at += 1
        switch c {
        case UInt8(ascii: "\""):
          guard let s = LiteText.utf8(out) else { throw fail("not UTF-8") }
          return s
        case UInt8(ascii: "\\"):
          guard at < bytes.count else { throw fail("unterminated escape") }
          let e = bytes[at]
          at += 1
          switch e {
          case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): out.append(e)
          case UInt8(ascii: "b"): out.append(8)
          case UInt8(ascii: "f"): out.append(12)
          case UInt8(ascii: "n"): out.append(10)
          case UInt8(ascii: "r"): out.append(13)
          case UInt8(ascii: "t"): out.append(9)
          case UInt8(ascii: "u"):
            var unit = try hex4()
            if (0xD800...0xDBFF).contains(unit) {
              guard at + 1 < bytes.count, bytes[at] == UInt8(ascii: "\\"), bytes[at + 1] == UInt8(ascii: "u") else {
                throw fail("lone surrogate")
              }
              at += 2
              let low = try hex4()
              guard (0xDC00...0xDFFF).contains(low) else { throw fail("bad surrogate pair") }
              unit = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
            } else if (0xDC00...0xDFFF).contains(unit) {
              throw fail("lone surrogate")
            }
            guard let scalar = UnicodeScalar(unit) else { throw fail("bad \\u escape") }
            out += Array(String(scalar).utf8)
          default: throw fail("bad escape")
          }
        case 0..<0x20: throw fail("control character in string")
        default: out.append(c)
        }
      }
    }

    mutating func hex4() throws -> UInt32 {
      guard at + 4 <= bytes.count else { throw fail("short \\u escape") }
      var n: UInt32 = 0
      for c in bytes[at..<at + 4] {
        let digit: UInt8
        switch c {
        case 48...57: digit = c - 48
        case 65...70: digit = c - 55
        case 97...102: digit = c - 87
        default: throw fail("bad \\u escape")
        }
        n = n << 4 | UInt32(digit)
      }
      at += 4
      return n
    }
  }
}

// MARK: Numbers

/// A number read from JSON, as `as? NSNumber` reads one: Foundation's own on the app, the value LiteJSON read on the
/// wasm. A JSON `true` is the number 1, as it is in an NSNumber.
public struct JSONNumber {
  public let doubleValue: Double
  public let int64Value: Int64

  public var intValue: Int { Int(truncatingIfNeeded: int64Value) }

  public init?(_ any: Any?) {
    guard let any else { return nil }
    #if FOUNDATION_ESSENTIALS_ONLY
      switch any {
      case let n as Int64: self.init(Double(n), n)
      case let n as Int: self.init(Double(n), Int64(n))
      case let n as Double: self.init(n, Self.truncate(n))
      case let n as Float: self.init(Double(n), Self.truncate(Double(n)))
      case let n as Int32: self.init(Double(n), Int64(n))
      case let n as UInt8: self.init(Double(n), Int64(n))
      case let b as Bool: self.init(b ? 1 : 0, b ? 1 : 0)
      default: return nil
      }
    #else
      guard let n = any as? NSNumber else { return nil }
      self.init(n.doubleValue, n.int64Value)
    #endif
  }

  private init(_ double: Double, _ int64: Int64) {
    doubleValue = double
    int64Value = int64
  }

  static func truncate(_ d: Double) -> Int64 {
    guard d.isFinite else { return 0 }
    guard d > -9.223_372_036_854_775_808e18, d < 9.223_372_036_854_775_808e18 else { return d < 0 ? .min : .max }
    return Int64(d)
  }

  /// `any as? Int`: a whole number that fits.
  public static func int(_ any: Any?) -> Int? {
    #if FOUNDATION_ESSENTIALS_ONLY
      switch any {
      case let n as Int: return n
      case let n as Int64: return Int(exactly: n)
      case let n as Double: return Int(exactly: n)
      default: return nil
      }
    #else
      return any as? Int
    #endif
  }

  /// `any as? Double`: any number exactly a double.
  public static func double(_ any: Any?) -> Double? {
    #if FOUNDATION_ESSENTIALS_ONLY
      switch any {
      case let n as Double: return n
      case let n as Int64: return Double(exactly: n)
      case let n as Int: return Double(exactly: n)
      default: return nil
      }
    #else
      return any as? Double
    #endif
  }

  /// Whether `any` is a JSON boolean rather than a number.
  public static func isBool(_ any: Any?) -> Bool {
    #if FOUNDATION_ESSENTIALS_ONLY
      return any is Bool
    #else
      guard let number = any as? NSNumber else { return false }
      #if canImport(Darwin)
        return CFGetTypeID(number) == CFBooleanGetTypeID()
      #else
        return type(of: number) == type(of: NSNumber(value: true))
      #endif
    #endif
  }
}
