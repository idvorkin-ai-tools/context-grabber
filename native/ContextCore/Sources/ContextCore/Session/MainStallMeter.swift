//  Whether the main thread is stuck (#946: "I think I just hung", and a log silent for 14 s that couldn't say). A watch
//  off the main thread looks often; the main thread answers each look. A wait past the threshold is a stall, said once
//  as it passes the threshold and once when the main thread answers again, so a hang that ends in a kill still leaves
//  its first line. Times are seconds on any one clock.
//
//  Time the whole app spent suspended is no stall (bead context-grabber-55vm, story 1221): the watch's own looks stop
//  then too, so a look that comes long after the one before it means the process was asleep, not the main thread stuck.
//  During a real stall the watch keeps looking on its own queue, a quarter of a second apart.

public struct MainStallMeter: Sendable {
  public enum Word: Equatable, Sendable {
    /// The main thread hasn't answered for `waited` seconds.
    case began(waited: Double)
    /// It answered again after `lasted` seconds without.
    case ended(lasted: Double)
    /// The watch itself didn't look for `gap` seconds: the app was suspended, and the wait so far is forgotten.
    /// `wasStalling` when a stall had been said to begin before it went away (its end isn't known).
    case away(gap: Double, wasStalling: Bool)
  }

  public let threshold: Double
  /// A gap between the watch's own looks this long means the process was suspended.
  public let awayGap: Double
  private var lastAnswer: Double
  private var lastLook: Double
  private var stalling = false

  public init(threshold: Double, now: Double, awayGap: Double = 5) {
    self.threshold = threshold
    self.awayGap = awayGap
    lastAnswer = now
    lastLook = now
  }

  /// The watch looking, off the main thread.
  public mutating func checked(at now: Double) -> Word? {
    let gap = now - lastLook
    lastLook = now
    if gap >= awayGap {
      let wasStalling = stalling
      lastAnswer = now
      stalling = false
      return .away(gap: gap, wasStalling: wasStalling)
    }
    guard !stalling, now - lastAnswer >= threshold else { return nil }
    stalling = true
    return .began(waited: now - lastAnswer)
  }

  /// The main thread answering a look.
  public mutating func answered(at now: Double) -> Word? {
    defer {
      lastAnswer = now
      stalling = false
    }
    return stalling ? .ended(lasted: now - lastAnswer) : nil
  }

  /// The watch stopping (the app going inactive), from the main thread: a stall under way ends here.
  public mutating func stopped(at now: Double) -> Word? { answered(at: now) }

  /// The watch starting again: the time away was no stall.
  public mutating func restart(at now: Double) {
    lastAnswer = now
    lastLook = now
    stalling = false
  }
}
