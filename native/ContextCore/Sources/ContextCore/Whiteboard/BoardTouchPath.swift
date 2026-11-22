//  A pen touch's path in the session log (spec 2026-11-01-whiteboard-design.md, *A pen touch's path is in the log*;
//  story 1104, bead context-grabber-y544): its points in board points and each one's time since the touch went down, in
//  one short string a log line can carry, and back. What `BoardTouchReplay` reads to judge the stroke again on the Mac.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardTouchPath {
  /// A point of the path: where, in board points, and when, in milliseconds since the touch went down.
  public struct Sample: Equatable, Sendable {
    public var point: CGPoint
    public var ms: Double

    public init(_ point: CGPoint, ms: Double) {
      self.point = point
      self.ms = ms
    }
  }

  /// The most points one line holds: a longer path is thinned evenly, its first and last points kept. The iPad's touches
  /// come at the screen's rate, so a two-second scratch-out is about 120.
  public static let most = 600

  /// `x,y,ms;dx,dy,dms;...`: the first point as it is, then each one's change from the one before, x and y in tenths of a
  /// board point and ms whole. The changes are between rounded values, so the path never drifts.
  public static func encode(_ samples: [Sample]) -> String {
    var last = (x: 0, y: 0, ms: 0)
    var parts: [String] = []
    parts.reserveCapacity(min(samples.count, most))
    for sample in thinned(samples) {
      let now = (x: tenths(sample.point.x), y: tenths(sample.point.y), ms: Int(sample.ms.rounded()))
      parts.append("\(now.x - last.x),\(now.y - last.y),\(now.ms - last.ms)")
      last = now
    }
    return parts.joined(separator: ";")
  }

  /// The samples `encode` wrote; nil for text it didn't write. An empty string is an empty path.
  public static func decode(_ text: String) -> [Sample]? {
    guard !text.isEmpty else { return [] }
    var (x, y, ms) = (0, 0, 0)
    var samples: [Sample] = []
    for part in text.split(separator: ";", omittingEmptySubsequences: false) {
      let fields = part.split(separator: ",", omittingEmptySubsequences: false)
      guard fields.count == 3, let dx = Int(fields[0]), let dy = Int(fields[1]), let dms = Int(fields[2]) else {
        return nil
      }
      (x, y, ms) = (x + dx, y + dy, ms + dms)
      samples.append(Sample(CGPoint(x: CGFloat(x) / 10, y: CGFloat(y) / 10), ms: Double(ms)))
    }
    return samples
  }

  /// At most `most` of `samples`, evenly spread, the first and the last among them.
  public static func thinned(_ samples: [Sample]) -> [Sample] {
    guard samples.count > most else { return samples }
    let step = Double(samples.count - 1) / Double(most - 1)
    return (0..<most).map { samples[Int((Double($0) * step).rounded())] }
  }

  private static func tenths(_ v: CGFloat) -> Int { Int((v * 10).rounded()) }
}
