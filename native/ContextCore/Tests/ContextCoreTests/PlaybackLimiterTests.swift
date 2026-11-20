import XCTest

@testable import ContextCore

/// #903: Larry's samples get headroom before the mixer's rate conversion, without a change to anything quieter than
/// the knee. Expected values come from Python's `math.tanh` (an independent oracle), full scale = 1.0:
/// `t, c = 0.7, 0.89; t + (c - t) * math.tanh((x - t) / (c - t))`.
final class PlaybackLimiterTests: XCTestCase {
  func testBelowTheKneePlaysExactlyAsSent() {
    for x: Float in [0, 0.001, -0.25, 0.5, -0.69, 0.7, -0.7] {
      XCTAssertEqual(PlaybackLimiter.limit(x), x, "\(x) is under the knee")
    }
  }

  func testLoudPeaksBendTowardTheCeiling() {
    let oracle: [(Float, Float)] = [
      (0.75, 0.7488768993019558), (0.8, 0.791686367431431), (0.9, 0.8487371977956251),
      (1.0, 0.8745030953108763), (-1.0, -0.8745030953108763), (-0.8, -0.791686367431431),
    ]
    for (x, expected) in oracle {
      XCTAssertEqual(PlaybackLimiter.limit(x), expected, accuracy: 1e-6, "limit(\(x))")
    }
  }

  func testEveryPcm16SampleLeavesRoomForTheMeasuredOvershoot() {
    // Every value the bridge can send, decoded as the call decodes it.
    let all = (Int(Int16.min)...Int(Int16.max)).map { Int16($0) }
    let data = all.withUnsafeBufferPointer { Data(buffer: $0) }
    var samples = PCM.pcm16ToFloat(data)
    PlaybackLimiter.apply(&samples)
    let peak = samples.map(abs).max() ?? 0
    XCTAssertLessThan(peak, PlaybackLimiter.ceiling)
    // The mixer's conversion rang 8% over on 2026-10-25; what it now renders from a full-scale sample stays under 1.
    XCTAssertLessThan(peak * 1.08, 1.0)
    // Louder in, never quieter out: the curve keeps the order of the samples.
    for i in 1..<samples.count { XCTAssertLessThanOrEqual(samples[i - 1], samples[i]) }
  }

  func testApplyCountsOnlyTheRoundedSamples() {
    var samples: [Float] = [0.1, -0.5, 0.95, -1.0, 0.7]
    XCTAssertEqual(PlaybackLimiter.apply(&samples), 2)
    XCTAssertEqual(samples[0], 0.1)
    XCTAssertEqual(samples[1], -0.5)
    XCTAssertEqual(samples[4], 0.7)
    XCTAssertEqual(samples[3], -0.8745030953108763, accuracy: 1e-6)
  }
}
