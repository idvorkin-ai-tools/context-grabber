//  #423, story 204: a car's microphone needs time to connect before the no-buffer heal restarts it.

public struct MicStartupDeadline: Equatable, Sendable {
  public let ms: Double
  public let why: String

  public init(bluetooth: Bool = false, sampleRate: Double? = nil) {
    if bluetooth {
      ms = 10000
      why = "bluetooth"
    } else if sampleRate == 0 {
      ms = 10000
      why = "zero_sample_rate"
    } else {
      ms = 1500
      why = "ordinary_mic"
    }
  }

  /// A route becoming ready must not take away a settling window already granted.
  public func extended(by current: Self) -> Self { current.ms > ms ? current : self }
}
