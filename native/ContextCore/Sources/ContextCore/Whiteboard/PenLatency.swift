//  Story 1311 (context-grabber-7xv6): how fast the board answers the Pencil, from the touch's own timestamp to the next
//  frame's presentation time, summed up for the session log. The math is here; the clocks are read by the app.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct PenLatency {
  /// One Pencil moment in this many is measured, so measuring costs a stroke nothing.
  public static let measureEvery = 4
  /// A line goes in the log once this many moments are measured.
  public static let lineEvery = 200
  /// A lift writes a line once at least this many are waiting; fewer carry over to the next stroke.
  public static let lineOnLift = 20

  public struct Summary: Equatable {
    public let count: Int
    /// Milliseconds, to a tenth.
    public let p50: Double
    public let p90: Double
    public let slowest: Double

    public init(count: Int, p50: Double, p90: Double, slowest: Double) {
      self.count = count
      self.p50 = p50
      self.p90 = p90
      self.slowest = slowest
    }
  }

  private var milliseconds: [Double] = []
  private var heard = 0

  public init() {}

  /// Moments measured and not yet in a line.
  public var pending: Int { milliseconds.count }

  /// Whether the Pencil moment just heard is one to measure.
  public mutating func measuresNext() -> Bool {
    defer { heard += 1 }
    return heard % Self.measureEvery == 0
  }

  /// One measured moment; a summary when it makes a line. A moment under zero or over a second is a clock mix-up, never
  /// a latency, and is dropped.
  public mutating func add(milliseconds ms: Double) -> Summary? {
    guard ms >= 0, ms < 1000 else { return nil }
    milliseconds.append(ms)
    return milliseconds.count >= Self.lineEvery ? take() : nil
  }

  /// The Pencil lifted: a summary when enough are waiting.
  public mutating func lifted() -> Summary? {
    milliseconds.count >= Self.lineOnLift ? take() : nil
  }

  private mutating func take() -> Summary? {
    defer { milliseconds = [] }
    return Self.summary(milliseconds)
  }

  /// Nearest-rank percentiles, each to a tenth of a millisecond.
  public static func summary(_ ms: [Double]) -> Summary? {
    guard !ms.isEmpty else { return nil }
    let sorted = ms.sorted()
    func rank(_ p: Double) -> Double {
      let index = max(Int((p * Double(sorted.count)).rounded(.up)) - 1, 0)
      return tenth(sorted[min(index, sorted.count - 1)])
    }
    return Summary(count: sorted.count, p50: rank(0.5), p90: rank(0.9), slowest: tenth(sorted[sorted.count - 1]))
  }

  private static func tenth(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}
