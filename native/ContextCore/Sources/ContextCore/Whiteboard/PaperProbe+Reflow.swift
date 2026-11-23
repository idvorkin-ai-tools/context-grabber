//  Story 1188 (#1256, #1255): PaperKit's handwriting reflow, for the log. On the iPad its reflow animation gave a word
//  picture a position that is not a number and the system stopped the app; these say what the reflow showed, so the
//  log can settle what put it there.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension PaperProbe {
  /// Story 1188: what is wrong with a frame a layer would be given. The system stops the app for a position that is not
  /// a number; an endless one (as an empty union's) becomes one the moment it is scaled by zero.
  public enum ReflowFlaw: String, Equatable, Sendable, CaseIterable {
    case notANumber = "nan"
    case endless
    case empty
  }

  /// Story 1188: the flaw of a frame, by its origin and size, or nil when it is a sound, non-empty one.
  public static func reflowFlaw(x: Double, y: Double, width: Double, height: Double) -> ReflowFlaw? {
    let parts = [x, y, width, height]
    if parts.contains(where: \.isNaN) { return .notANumber }
    if parts.contains(where: \.isInfinite) { return .endless }
    if width <= 0 || height <= 0 { return .empty }
    return nil
  }

  /// Story 1188: a frame for the log, whole points, or empty when any part is not a finite number (which the log's JSON
  /// can't carry, and whole-number rounding would trap on).
  public static func reflowRect(x: Double, y: Double, width: Double, height: Double) -> [Int] {
    let parts = [x, y, width, height]
    guard parts.allSatisfy(\.isFinite) else { return [] }
    return parts.map { Int($0.rounded()) }
  }

  /// Story 1188: a view of PaperKit's handwriting reflow (`HandwritingReflowView`, `ReflowTextView` and their kin).
  public static func isReflowKind(_ kind: String) -> Bool { kind.contains("Reflow") }

  /// Story 1188: one reflow view as the log says it.
  public struct ReflowView: Equatable, Sendable {
    public var kind: String
    public var frame: [Int]
    public var within: String
    /// Layers under it that show a picture.
    public var pictures: Int
    /// Layers under it (and itself) whose frame has a flaw, by flaw.
    public var flawed: [String: Int]

    public init(kind: String, frame: [Int], within: String, pictures: Int, flawed: [String: Int]) {
      self.kind = kind
      self.frame = frame
      self.within = within
      self.pictures = pictures
      self.flawed = flawed
    }

    /// For the log line.
    public var fields: [String: Any] {
      ["kind": kind, "frame": frame, "within": within, "pictures": pictures, "flawed": flawed]
    }
  }

  /// Story 1188: the reflow views worth saying. PaperKit keeps an empty `HandwritingReflowView` over every board, so that
  /// one counts only while it shows a picture or has a flaw; a board with no reflow showing has nothing to say.
  public static func reflowShown(_ views: [ReflowView]) -> [ReflowView] {
    views.filter { $0.kind != "HandwritingReflowView" || $0.pictures > 0 || !$0.flawed.isEmpty }
  }
}
