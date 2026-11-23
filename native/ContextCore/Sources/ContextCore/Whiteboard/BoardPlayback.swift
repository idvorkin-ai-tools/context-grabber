//  Playing a board back (spec 2026-11-01-whiteboard-design.md, *Playing a board back, as Notability does*; stories 954,
//  956–958; bead context-grabber-3tdv): the board's strokes again in the order they were drawn, each at the pace the
//  hand drew it, a long pause between them shortened. Platform-free: the app turns PencilKit's strokes into these.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// A board's strokes laid on a playback timeline, in seconds from the start of playback.
public struct BoardPlayback: Equatable, Sendable {
  /// One stroke as the drawing keeps it.
  public struct Stroke: Equatable, Sendable {
    /// When it began, seconds since 1970.
    public var began: TimeInterval
    /// Each point's time since `began`, in seconds, in the stroke's order.
    public var offsets: [TimeInterval]

    public init(began: TimeInterval, offsets: [TimeInterval]) {
      self.began = began
      self.offsets = offsets
    }
  }

  /// One stroke on the timeline.
  public struct Entry: Equatable, Sendable {
    /// Its place in the drawing.
    public let index: Int
    /// When it starts drawing, seconds into playback.
    public let start: TimeInterval
    /// How long it takes to draw; 0 when it appears at once.
    public let duration: TimeInterval
    /// Its points' times since its start, as drawn.
    public let offsets: [TimeInterval]
    public var end: TimeInterval { start + duration }
  }

  /// What shows at one moment of playback.
  public struct Frame: Equatable, Sendable {
    /// The strokes begun, in the drawing's order, so the board stacks as it does when open.
    public var shown: [Int]
    /// The one stroke still being drawn, and how many of its points are drawn so far (at least 1).
    public var partial: Part?

    public init(shown: [Int], partial: Part?) {
      self.shown = shown
      self.partial = partial
    }

    public struct Part: Equatable, Sendable {
      public var index: Int
      public var points: Int

      public init(index: Int, points: Int) {
        self.index = index
        self.points = points
      }
    }
  }

  /// A pause between strokes longer than this plays as `pausePlays`.
  public static let longPause: TimeInterval = 2
  public static let pausePlays: TimeInterval = 0.5
  /// Strokes that began this close together appear together (a kept text's letters, a paste).
  public static let together: TimeInterval = 0.001
  /// The bar's skip back and on.
  public static let skip: TimeInterval = 10
  /// Notability's speeds; playback starts at 1×.
  public static let speeds: [Double] = [0.7, 1, 1.25, 1.5, 2]

  /// In playback order: by start, the drawing's order breaking ties.
  public let entries: [Entry]
  /// The whole playback, seconds.
  public let length: TimeInterval
  /// Strokes drawn over time (their points have offsets), for the log.
  public let timed: Int
  /// Strokes that share their moment with another and appear together, for the log.
  public let shared: Int
  /// From the first stroke's start to the last one's end, as drawn, seconds.
  public let realSpan: TimeInterval

  public init(_ strokes: [Stroke]) {
    let order = strokes.indices.sorted {
      (Self.finite(strokes[$0].began), $0) < (Self.finite(strokes[$1].began), $1)
    }
    var entries: [Entry] = []
    entries.reserveCapacity(strokes.count)
    var clock: TimeInterval = 0
    var realEnd: TimeInterval?
    var realStart: TimeInterval?
    var (timed, shared) = (0, 0)
    var i = 0
    while i < order.count {
      let began = Self.finite(strokes[order[i]].began)
      var j = i + 1
      while j < order.count, Self.finite(strokes[order[j]].began) - began < Self.together { j += 1 }
      let group = order[i..<j]
      let offsets = group.map { Self.clean(strokes[$0].offsets) }
      let alone = group.count == 1
      let durations = offsets.map { alone ? ($0.last ?? 0) : 0 }
      if alone, durations[0] > 0 { timed += 1 }
      if !alone { shared += group.count }
      if let realEnd {
        let gap = began - realEnd
        clock += gap <= 0 ? 0 : gap > Self.longPause ? Self.pausePlays : gap
      }
      for (index, (offsets, duration)) in zip(group, zip(offsets, durations)) {
        entries.append(Entry(index: index, start: clock, duration: duration, offsets: offsets))
      }
      let longest = durations.max() ?? 0
      clock += longest
      realEnd = max(realEnd ?? -.infinity, began + longest)
      realStart = realStart ?? began
      i = j
    }
    self.entries = entries
    length = clock
    self.timed = timed
    self.shared = shared
    realSpan = realStart.flatMap { start in realEnd.map { $0 - start } } ?? 0
  }

  public var count: Int { entries.count }

  /// How many strokes have begun at `t`: those starting before it, or all of them at the end.
  public func begun(at t: TimeInterval) -> Int {
    if t >= length { return entries.count }
    var (low, high) = (0, entries.count)
    while low < high {
      let mid = (low + high) / 2
      if entries[mid].start < t { low = mid + 1 } else { high = mid }
    }
    return low
  }

  public func frame(at t: TimeInterval) -> Frame {
    let k = begun(at: t)
    var partial: Frame.Part?
    if k > 0, t < length {
      let last = entries[k - 1]
      if last.end > t {
        let into = t - last.start
        let drawn = last.offsets.prefix { $0 <= into }.count
        partial = Frame.Part(index: last.index, points: max(1, drawn))
      }
    }
    return Frame(shown: entries[..<k].map(\.index).sorted(), partial: partial)
  }

  /// When the stroke at this place in the drawing starts, seconds into playback.
  public func start(of index: Int) -> TimeInterval? {
    entries.first { $0.index == index }?.start
  }

  /// The stroke a tap at `point` means: the one with a point nearest it, within `reach`, among those given (the ones
  /// showing), each as its place in the drawing and its points in board points.
  public static func nearest(_ point: CGPoint, among strokes: [(index: Int, points: [CGPoint])], within reach: CGFloat)
    -> Int?
  {
    var best: (index: Int, distance: CGFloat)?
    for stroke in strokes {
      for p in stroke.points {
        let d = hypot(p.x - point.x, p.y - point.y)
        if d <= reach, d < (best?.distance ?? .infinity) { best = (stroke.index, d) }
      }
    }
    return best?.index
  }

  private static func finite(_ t: TimeInterval) -> TimeInterval { t.isFinite ? t : 0 }

  /// Offsets as a timeline can use them: finite, not before the stroke's start, never going back.
  private static func clean(_ offsets: [TimeInterval]) -> [TimeInterval] {
    var last: TimeInterval = 0
    return offsets.map {
      last = max(last, $0.isFinite ? $0 : 0)
      return last
    }
  }
}

/// Playback's playhead: where it is, whether it plays and how fast.
public struct BoardPlaybackClock: Equatable, Sendable {
  public let length: TimeInterval
  public private(set) var position: TimeInterval = 0
  public private(set) var playing = false
  public private(set) var speed: Double = 1

  public init(length: TimeInterval) {
    self.length = max(0, length.isFinite ? length : 0)
  }

  public var atEnd: Bool { position >= length }

  /// Plays from where it is; from the start once it has reached the end.
  public mutating func play() {
    if atEnd { position = 0 }
    playing = true
  }

  public mutating func pause() { playing = false }

  /// Moves to `t`, kept within the playback.
  public mutating func seek(to t: TimeInterval) {
    position = min(max(0, t.isFinite ? t : 0), length)
  }

  /// The bar's 10 s back (negative) or on.
  public mutating func skip(_ by: TimeInterval) { seek(to: position + by) }

  /// The next of Notability's speeds, back to the first after the last.
  public mutating func nextSpeed() {
    let speeds = BoardPlayback.speeds
    let at = speeds.firstIndex(of: speed) ?? 0
    speed = speeds[(at + 1) % speeds.count]
  }

  /// `seconds` of real time passed: playing, the playhead moves at the speed and stops at the end.
  public mutating func advance(_ seconds: TimeInterval) {
    guard playing, seconds > 0 else { return }
    position = min(length, position + seconds * speed)
    if atEnd { playing = false }
  }
}
