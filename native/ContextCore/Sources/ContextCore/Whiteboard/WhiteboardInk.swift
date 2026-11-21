#if canImport(PencilKit)
  import Foundation
  import PencilKit

  /// #1083 (story 1063): a stroke's ink read without PencilKit's Swift `inkType`, which traps (signal 5) on a kind of ink
  /// its enum has no case for: three iPad crashes on 2026-11-21, each from the board hashing a stroke that had just landed.
  /// The Objective-C ink carries its kind as a string, read here with no trap.
  public enum WhiteboardInk {
    /// Told the first time each unknown kind is met in a launch: the kind as the ink spells it (nil for none), where it
    /// was met, and the stroke's point count (0 when not known). The board sets it to write the session log.
    public static var onUnknown: ((String?, String, Int) -> Void)? {
      get { box.withLock { box.onUnknown } }
      set { box.withLock { box.onUnknown = newValue } }
    }

    /// The ink's kind as it spells it (`com.apple.ink.pen`), or nil when it has none.
    public static func rawType(_ ink: PKInk) -> String? {
      (ink as PKInkReference).value(forKey: "inkType") as? String
    }

    /// The kind's name for the wire and the log (`com.apple.ink.pen`), reporting it once when PencilKit's Swift side
    /// has no case for it; nil when the ink has no kind at all.
    public static func name(_ ink: PKInk, at place: String, points: Int = 0) -> String? {
      let raw = rawType(ink)
      if raw.flatMap(PKInk.InkType.init(rawValue:)) == nil { report(raw, at: place, points: points) }
      return raw
    }

    /// `ink` at `alpha`, its colour otherwise kept: of its own kind, or the pen when that kind has no name here.
    public static func withAlpha(_ ink: PKInk, _ alpha: CGFloat, at place: String) -> PKInk {
      let kind = name(ink, at: place).flatMap(PKInk.InkType.init(rawValue:)) ?? .pen
      return PKInk(kind, color: ink.color.withAlphaComponent(alpha))
    }

    private static func report(_ raw: String?, at place: String, points: Int) {
      let tell = box.withLock { () -> ((String?, String, Int) -> Void)? in
        box.reported.insert(raw ?? "").inserted ? box.onUnknown : nil
      }
      tell?(raw, place, points)
    }

    /// Forget which kinds were reported, for tests.
    static func forgetReported() { box.withLock { box.reported = [] } }

    private final class Box: @unchecked Sendable {
      let lock = NSLock()
      var onUnknown: ((String?, String, Int) -> Void)?
      var reported: Set<String> = []
      func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
      }
    }
    private static let box = Box()
  }
#endif
