#if canImport(PencilKit)
  #if FOUNDATION_ESSENTIALS_ONLY
    import FoundationEssentials
  #else
    import Foundation
  #endif
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

    /// What saving a drawing found among its inks this build has no name for (bead context-grabber-3b02).
    public struct SaveCheck: Equatable, Sendable {
      /// Each unknown kind the drawing holds, as the ink spells it ("none" for no kind), sorted.
      public var kinds: [String]
      /// Of those, the ones a saved drawing can't be read back with.
      public var unreadable: [String]
      /// How many strokes were saved as the pen.
      public var asPen: Int

      public init(kinds: [String], unreadable: [String], asPen: Int) {
        self.kinds = kinds
        self.unreadable = unreadable
        self.asPen = asPen
      }
    }

    /// `drawing` as it can be saved and read back: a drawing holding an ink this PencilKit can't name is written but
    /// refused when read ("from a future version"), so its board wouldn't open. Each unknown kind is tried once a launch
    /// on a drawing of one stroke; a stroke of a kind that doesn't read back becomes the pen in its own colour and
    /// alpha, its path, transform and mask kept. The check is nil when every ink has a name here.
    public static func savable(_ drawing: PKDrawing) -> (PKDrawing, SaveCheck?) {
      var strokes = drawing.strokes
      var kinds: Set<String> = []
      var unreadable: Set<String> = []
      var asPen = 0
      for index in strokes.indices {
        let raw = rawType(strokes[index].ink)
        guard raw.flatMap(PKInk.InkType.init(rawValue:)) == nil else { continue }
        let kind = raw ?? "none"
        kinds.insert(kind)
        guard !readsBack(kind, stroke: strokes[index]) else { continue }
        unreadable.insert(kind)
        strokes[index].ink = PKInk(.pen, color: strokes[index].ink.color)
        asPen += 1
      }
      guard !kinds.isEmpty else { return (drawing, nil) }
      let check = SaveCheck(kinds: kinds.sorted(), unreadable: unreadable.sorted(), asPen: asPen)
      return (asPen == 0 ? drawing : PKDrawing(strokes: strokes), check)
    }

    /// Whether a drawing of `stroke` alone reads back, remembered per kind for the launch.
    private static func readsBack(_ kind: String, stroke: PKStroke) -> Bool {
      if let known = box.withLock({ box.readsBack[kind] }) { return known }
      let reads = (try? PKDrawing(data: PKDrawing(strokes: [stroke]).dataRepresentation())) != nil
      box.withLock { box.readsBack[kind] = reads }
      return reads
    }

    private static func report(_ raw: String?, at place: String, points: Int) {
      let tell = box.withLock { () -> ((String?, String, Int) -> Void)? in
        box.reported.insert(raw ?? "").inserted ? box.onUnknown : nil
      }
      tell?(raw, place, points)
    }

    /// Forget which kinds were reported, for tests.
    static func forgetReported() {
      box.withLock {
        box.reported = []
        box.readsBack = [:]
      }
    }

    private final class Box: @unchecked Sendable {
      let lock = NSLock()
      var onUnknown: ((String?, String, Int) -> Void)?
      var reported: Set<String> = []
      var readsBack: [String: Bool] = [:]
      func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
      }
    }
    private static let box = Box()
  }
#endif
