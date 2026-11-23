//  When Igor has stopped writing (spec 2026-11-01-whiteboard-shapes-design.md, *When he has stopped writing*;
//  stories 892, 893): voice activity detection, for writing. A speech turn ends after a silence longer than the speaker's
//  own pauses; this ends a writing turn the same way. It learns his rhythm, the median of the gaps between his strokes,
//  and waits about four times that, from 1.5 to 5 s. End-of-thought cues cut it to the floor: a question mark, the
//  hovering Pencil going back to the start of a new line, the hand leaving the paper. Being mid-line, or still in quick
//  strokes, lengthens it. Ported from the Cockpit's web board (`WritingVad` in assets/ink/turns.mjs) with its numbers.
//  The board's model owns the timers and hands the time in, so a host test can step it.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct WhiteboardWritingVad: Sendable {
  public static let floor: Duration = .milliseconds(1500)
  public static let ceiling: Duration = .milliseconds(5000)
  /// The wait is this many of his usual gaps.
  public static let factor = 4.0
  /// A longer gap was a pause for a turn, not his rhythm (ms).
  static let gapCap = 3000.0
  /// His usual gap until three are seen (ms).
  static let seedGap = 350.0
  /// The gaps kept, newest last.
  static let gapsKept = 40
  /// No pointer for this long, where the Pencil's hover is seen at all: the hand has left.
  public static let awayAfter: Duration = .seconds(1)

  /// The wait after the last lift, and why it is that long: `rhythm`, `mid-line`, `+quick`, `question`.
  public struct Pause: Equatable, Sendable {
    public var ms: Int
    public var cue: String
    /// His usual gap, in ms, as the wait was worked out from it.
    public var median: Int
    public var duration: Duration { .milliseconds(ms) }
  }

  /// The gaps between a lift and the next touch down, in ms.
  public private(set) var gaps: [Double] = []
  /// The Pencil's hover has been seen on this board, so the hand leaving can be.
  public private(set) var hoverSeen = false
  private var lastUp: ContinuousClock.Instant?
  private var lastPointer: ContinuousClock.Instant?
  /// The last strokes' boxes, newest last.
  private var boxes: [CGRect] = []
  private let margin: CGFloat
  private let pageWidth: CGFloat
  /// The pause under way: when it started, and whether a cue has already cut it short.
  private var waiting: (since: ContinuousClock.Instant, shortened: Bool)?

  /// `margin`: where a line starts, as the web board's left margin; `pageWidth`: where it ends.
  public init(margin: CGFloat = 64, pageWidth: CGFloat = 820) {
    self.margin = margin
    self.pageWidth = pageWidth
  }

  // MARK: The pen

  /// The Pencil, or a drawing finger, touching down.
  public mutating func down(at now: ContinuousClock.Instant) {
    lastPointer = now
    waiting = nil
    guard let lastUp else { return }
    let gap = Self.ms(now - lastUp)
    guard gap >= 0, gap < Self.gapCap else { return }
    gaps.append(gap)
    if gaps.count > Self.gapsKept { gaps.removeFirst() }
  }

  public mutating func lifted(at now: ContinuousClock.Instant) {
    lastUp = now
    lastPointer = now
  }

  /// The stroke the lift left, in board points.
  public mutating func stroke(_ box: CGRect) {
    boxes.append(box)
    if boxes.count > 3 { boxes.removeFirst() }
  }

  /// His usual gap between strokes, in ms: the median of the last ones, or the seed until three are seen.
  public var median: Double {
    guard gaps.count >= 3 else { return Self.seedGap }
    return gaps.sorted()[gaps.count / 2]
  }

  /// How long to wait after the last lift.
  public var pause: Pause {
    let (floor, ceiling) = (Self.ms(Self.floor), Self.ms(Self.ceiling))
    let clamp = { (v: Double) in min(ceiling, max(floor, v)).rounded() }
    let med = median
    if question { return Pause(ms: Int(floor), cue: "question", median: Int(med)) }
    var ms = clamp(Self.factor * med)
    var cue = "rhythm"
    if let last = boxes.last, last.minX > margin + 120, last.maxX < pageWidth - 160 {
      ms = clamp(ms * 1.5)
      cue = "mid-line"
    }
    let recent = gaps.suffix(2)
    if gaps.count >= 3, recent.count == 2, recent.allSatisfy({ $0 < med }) {
      ms = clamp(ms * 1.25)
      cue += "+quick"
    }
    return Pause(ms: Int(ms), cue: cue, median: Int(med))
  }

  /// A "?": the last stroke a dot just under the stroke before it, the hook. An "i"'s dot sits above its stem.
  public var question: Bool {
    guard boxes.count >= 2 else { return false }
    let (hook, dot) = (boxes[boxes.count - 2], boxes[boxes.count - 1])
    let middle = dot.midX
    return dot.width <= 10 && dot.height <= 10 && hook.height >= 12 && hook.height <= 60
      && middle >= hook.minX - 6 && middle <= hook.maxX + 6 && dot.minY >= hook.maxY - 4 && dot.minY - hook.maxY <= 24
  }

  // MARK: The pause and its cues

  /// The pause starts: the wait it has, counted from now.
  public mutating func pauseStarted(at now: ContinuousClock.Instant) -> Pause {
    waiting = (now, false)
    return pause
  }

  /// The pause ran out, or was stopped.
  public mutating func pauseOver() { waiting = nil }

  /// The Pencil hovering at `point` (board points): seen, and when it's back at the start of a line below the last
  /// stroke, the end of a thought. Returns what is left of the pause when that cuts it short.
  public mutating func hovered(at point: CGPoint, now: ContinuousClock.Instant) -> Duration? {
    hoverSeen = true
    lastPointer = now
    guard let last = boxes.last, point.x < margin + 120, point.y > last.maxY + 8 else { return nil }
    return shorten(now: now)
  }

  /// A look for the hand having left: no pointer for a second, where the hover would have shown it. What is left of the
  /// pause when that cuts it short.
  public mutating func lookedForTheHand(now: ContinuousClock.Instant) -> Duration? {
    guard hoverSeen, let lastPointer, now - lastPointer >= Self.awayAfter else { return nil }
    return shorten(now: now)
  }

  /// A cue cuts the wait to the floor, counted from the lift; once per pause.
  private mutating func shorten(now: ContinuousClock.Instant) -> Duration? {
    guard let waiting, !waiting.shortened else { return nil }
    self.waiting = (waiting.since, true)
    let left = Self.floor - (now - waiting.since)
    return left > .zero ? left : .zero
  }

  static func ms(_ duration: Duration) -> Double {
    let (seconds, attoseconds) = duration.components
    return Double(seconds) * 1000 + Double(attoseconds) / 1e15
  }
}
