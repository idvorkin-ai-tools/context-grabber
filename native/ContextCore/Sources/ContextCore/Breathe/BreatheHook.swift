//  The breathing screen's launch hook (docs/TESTING.md). Pure; the app's `runBreatheHook` opens the screen.

import Foundation

/// `GRABBER_BREATHE=<breath>,<cycles>[,<cue>[,<pause_at_seconds>]]` begins that exact session; anything else just
/// opens the sliders (`plan` nil). `GRABBER_BREATHE_STYLE` is this visit's ring style, read only beside it.
public struct BreatheHook: Equatable, Sendable {
  public var plan: BreathPlan?
  public var cue: BreathCue?
  public var pauseAt: Double?
  public var style: BreathStyle?

  public init?(_ env: [String: String]) {
    guard let spec = env["GRABBER_BREATHE"], !spec.isEmpty else { return nil }
    let parts = spec.split(separator: ",").map(String.init)
    style = env["GRABBER_BREATHE_STYLE"].flatMap(BreathStyle.init(rawValue:))
    if parts.count >= 2, let breath = Int(parts[0]), let cycles = Int(parts[1]) {
      plan = BreathPlan(breathSeconds: breath, cycles: cycles)
      cue = parts.count > 2 ? BreathCue(rawValue: parts[2]) : nil
      pauseAt = parts.count > 3 ? Double(parts[3]) : nil
    }
  }
}
