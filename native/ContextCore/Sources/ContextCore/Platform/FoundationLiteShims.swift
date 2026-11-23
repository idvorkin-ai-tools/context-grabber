//  The wasm build only (bead context-grabber-pt1e): Foundation's names for FoundationLite's pieces, so the board's
//  code reads the same on the wasm as on the app, which keeps Foundation's own.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
  #if canImport(WASILibc)
    // The C maths (hypot, atan2, pow) Foundation brought along.
    @_exported import WASILibc
  #elseif canImport(Glibc)
    @_exported import Glibc
  #endif

  public typealias CharacterSet = LiteCharacterSet
  public typealias NSNull = LiteNull

  extension String {
    public init(format: String, _ args: CVarArg...) { self = LiteText.format(format, args) }
  }

  extension Error {
    /// Foundation's text for an error without a description of its own. Nothing the wasm runs shows one.
    public var localizedDescription: String { "The operation couldn’t be completed. (\(String(reflecting: self)))" }
  }

  /// The wasm runs on one thread: a lock with nothing to wait for.
  public final class NSLock: @unchecked Sendable {
    public init() {}
    public func lock() {}
    public func unlock() {}
  }

  extension StringProtocol {
    public func replacingOccurrences<T: StringProtocol, R: StringProtocol>(of target: T, with replacement: R) -> String
    {
      String(self).replacing(String(target), with: String(replacement))
    }

    public func trimmingCharacters(in set: CharacterSet) -> String { LiteText.trimming(self, set) }

    public func addingPercentEncoding(withAllowedCharacters allowed: CharacterSet) -> String? {
      LiteText.addingPercentEncoding(self, allowed)
    }

    public var removingPercentEncoding: String? { LiteText.removingPercentEncoding(self) }

    public func components(separatedBy set: CharacterSet) -> [String] { LiteText.components(self, separatedBy: set) }
  }

  public enum JSONSerialization {
    public struct ReadingOptions: OptionSet, Sendable {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }
      public static let fragmentsAllowed = ReadingOptions(rawValue: 1)
    }

    public struct WritingOptions: OptionSet, Sendable {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }
      public static let sortedKeys = WritingOptions(rawValue: 1)
      public static let fragmentsAllowed = WritingOptions(rawValue: 2)
    }

    public static func jsonObject(with data: Data, options: ReadingOptions = []) throws -> Any {
      try LiteJSON.object(with: data, fragmentsAllowed: options.contains(.fragmentsAllowed))
    }

    public static func data(withJSONObject object: Any, options: WritingOptions = []) throws -> Data {
      try LiteJSON.data(
        object, sortedKeys: options.contains(.sortedKeys), fragmentsAllowed: options.contains(.fragmentsAllowed))
    }

    public static func isValidJSONObject(_ object: Any) -> Bool { LiteJSON.isValid(object) }
  }

  public final class ISO8601DateFormatter {
    public struct Options: OptionSet, Sendable {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }
      public static let withInternetDateTime = Options(rawValue: 1)
      public static let withFractionalSeconds = Options(rawValue: 2)
    }

    public var formatOptions: Options = .withInternetDateTime

    public init() {}

    private var lite: LiteISO8601 { LiteISO8601(fractionalSeconds: formatOptions.contains(.withFractionalSeconds)) }
    public func date(from string: String) -> Date? { lite.date(from: string) }
    public func string(from date: Date) -> String { lite.string(from: date) }
  }
#endif
