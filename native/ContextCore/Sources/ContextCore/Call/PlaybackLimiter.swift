//  Larry's voice kept under full scale (#903, call spec "Larry's voice never goes over full scale").
//
//  What the bridge sends is PCM16, so a decoded sample is never over 1.0, yet a call on 2026-10-25 rendered a mixer
//  peak of 1.08: the mixer's rate conversion (the bridge's 16 or 24 kHz to the hardware's 48 kHz) rings above a peak
//  that was already at the top, and the speaker clips it flat. Headroom has to be made before that conversion, on the
//  samples scheduled for the player.
//
//  The curve is a memoryless soft knee: below `knee` (-3.1 dBFS, nearly all of speech) a sample passes untouched;
//  above it the excess bends along tanh toward `ceiling`, which it approaches but never reaches. The bend meets the
//  straight line with the same slope, so there is no corner to hear, and a full-scale sample comes out at about 0.875,
//  leaving room for a converter overshoot of up to about 1.14 (the measured one was 1.08). A fixed gain would make
//  every word quieter for the sake of a few peaks; a gain-riding limiter needs look-ahead (delay) or an envelope that
//  pumps. A curve that touches only the loudest peaks is the least audible change.

import Foundation

public enum PlaybackLimiter {
  /// Below this, a sample plays exactly as sent.
  public static let knee: Float = 0.7
  /// The level the loudest peaks bend toward; never reached.
  public static let ceiling: Float = 0.89

  /// One sample through the soft knee; the sign is kept.
  public static func limit(_ sample: Float) -> Float {
    let size = abs(sample)
    guard size > knee else { return sample }
    let room = ceiling - knee
    let bent = knee + room * tanh((size - knee) / room)
    return sample < 0 ? -bent : bent
  }

  /// Every sample through the knee, in place; returns how many were rounded down (for the level line).
  @discardableResult
  public static func apply(_ samples: inout [Float]) -> Int {
    var rounded = 0
    for i in samples.indices where abs(samples[i]) > knee {
      samples[i] = limit(samples[i])
      rounded += 1
    }
    return rounded
  }
}
