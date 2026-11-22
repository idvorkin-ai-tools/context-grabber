//  Whether the main thread is stuck (#946: "I think I just hung", and a log silent for 14 s that couldn't say). A watch
//  off the main thread looks often; the main thread answers each look. A wait past the threshold is a stall, said once
//  as it passes the threshold and once when the main thread answers again, so a hang that ends in a kill still leaves
//  its first line. Times are seconds on any one clock.

public struct MainStallMeter: Sendable {
  public enum Word: Equatable, Sendable {
    /// The main thread hasn't answered for `waited` seconds.
    case began(waited: Double)
    /// It answered again after `lasted` seconds without.
    case ended(lasted: Double)
  }

  public let threshold: Double
  private var lastAnswer: Double
  private var stalling = false

  public init(threshold: Double, now: Double) {
    self.threshold = threshold
    lastAnswer = now
  }

  /// The watch looking, off the main thread.
  public mutating func checked(at now: Double) -> Word? {
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
    stalling = false
  }
}
