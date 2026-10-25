//  #442 (story 210): Larry's PCM read as the stream it is, and the window of counters the engine logs.

import XCTest

@testable import ContextCore

final class PCM16StreamTests: XCTestCase {
  private func bytes(_ samples: [Int16]) -> Data {
    var data = Data()
    for s in samples { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
    return data
  }

  /// The oracle is the format: PCM16 LE is two bytes a sample, so a stream cut anywhere decodes to the same samples
  /// as the whole. The cuts are the shape the bridge sent on 2026-10-25 (odd frames among even ones).
  func testFramesCutMidSampleDecodeToTheStreamAsSent() {
    let samples: [Int16] = (0..<40).map { Int16(truncatingIfNeeded: $0 * 1234 - 20000) }
    let whole = bytes(samples)
    let cuts = [7, 10, 5, 12, 1, 45]
    XCTAssertEqual(cuts.reduce(0, +), whole.count)
    var stream = PCM16Stream()
    var out: [Float] = []
    var offset = 0
    for cut in cuts {
      out += stream.decode(whole[offset..<offset + cut])
      offset += cut
    }
    XCTAssertEqual(out, PCM.pcm16ToFloat(whole))
    XCTAssertEqual(stream.oddFrames, 4)
    XCTAssertFalse(stream.carrying)
  }

  /// What the phone did before: each frame on its own, so after an odd cut every sample was a half-swapped pair.
  func testFrameByFrameDecodingAfterAnOddCutWasNotTheStream() {
    let samples: [Int16] = (0..<8).map { Int16(truncatingIfNeeded: $0 * 1234 - 20000) }
    let whole = bytes(samples)
    let naive = PCM.pcm16ToFloat(whole[0..<7]) + PCM.pcm16ToFloat(whole[7..<16])
    XCTAssertEqual(naive.count, 7)  // one sample lost to the dropped bytes
    XCTAssertNotEqual(Array(naive[3...]), Array(PCM.pcm16ToFloat(whole)[3..<7]))
  }

  func testTheCarryWaitsForTheNextFrameAndNotPastAReset() {
    var stream = PCM16Stream()
    XCTAssertEqual(stream.decode(Data()), [])
    XCTAssertFalse(stream.carrying)
    XCTAssertEqual(stream.decode(Data([0xE8])), [])
    XCTAssertTrue(stream.carrying)
    XCTAssertEqual(stream.oddFrames, 1)
    // The high byte lands: 0x03E8 = 1000.
    XCTAssertEqual(stream.decode(Data([0x03])).map { ($0 * 32767).rounded() }, [1000])
    XCTAssertFalse(stream.carrying)
    XCTAssertEqual(stream.decode(Data([0xE8, 0x03, 0x01])).count, 1)
    XCTAssertTrue(stream.carrying)
    stream.reset()
    XCTAssertFalse(stream.carrying)
    XCTAssertEqual(stream.decode(Data([0xE8, 0x03])).map { ($0 * 32767).rounded() }, [1000])
    XCTAssertEqual(stream.oddFrames, 3)  // the three odd frames above; a reset forgets the carry, not the count
  }
}

final class PlaybackWindowTests: XCTestCase {
  func testCountsFramesTheirSizesAndTheOddOnes() {
    var w = PlaybackWindow()
    XCTAssertTrue(w.isEmpty)
    w.scheduled(bytes: 5462, at: 1000, queuedS: 0, previousAt: 0)
    w.scheduled(bytes: 5512, at: 1100, queuedS: 0.2, previousAt: 1000)
    w.scheduled(bytes: 4857, at: 1200, queuedS: 0.3, previousAt: 1100)
    XCTAssertFalse(w.isEmpty)
    XCTAssertEqual(w.frames, 3)
    XCTAssertEqual(w.bytesMin, 4857)
    XCTAssertEqual(w.bytesMax, 5512)
    XCTAssertEqual(w.oddFrames, 1)
    XCTAssertEqual(w.depthMinMs, 0)
    XCTAssertEqual(w.depthMaxMs, 300)
    XCTAssertEqual(w.gapMaxMs, 100)
    XCTAssertEqual(w.underruns, 0)
  }

  /// The first frame of a reply finds an empty queue by design; a frame 300 ms after the last that finds the player
  /// 50 ms past the end of its queue is an underrun; a frame after a second's pause is Larry's next sentence.
  func testAnEmptyQueueMidReplyIsAnUnderrunAndAPauseBetweenRepliesIsNot() {
    var w = PlaybackWindow()
    w.scheduled(bytes: 4800, at: 1000, queuedS: 0, previousAt: 0)
    XCTAssertEqual(w.underruns, 0)
    w.scheduled(bytes: 4800, at: 1100, queuedS: 0.1, previousAt: 1000)
    XCTAssertEqual(w.underruns, 0)
    w.scheduled(bytes: 4800, at: 1400, queuedS: -0.05, previousAt: 1100)
    XCTAssertEqual(w.underruns, 1)
    XCTAssertEqual(w.starvedMs, 50, accuracy: 1e-9)
    w.scheduled(bytes: 4800, at: 1500, queuedS: 0.008, previousAt: 1400)  // within one IO cycle of dry
    XCTAssertEqual(w.underruns, 2)
    XCTAssertEqual(w.starvedMs, 50, accuracy: 1e-9)
    w.scheduled(bytes: 4800, at: 3000, queuedS: -1.2, previousAt: 1500)
    XCTAssertEqual(w.underruns, 2)
    XCTAssertEqual(w.gapMaxMs, 1500)
    XCTAssertEqual(w.depthMinMs, 0)
    XCTAssertEqual(w.depthMaxMs, 100)
    let fields = w.fields
    XCTAssertEqual(fields["frames"] as? Int, 5)
    XCTAssertEqual(fields["underruns"] as? Int, 2)
    XCTAssertEqual(fields["starved_ms"] as? Double, 50)
    XCTAssertEqual(fields["gap_max_ms"] as? Double, 1500)
    XCTAssertEqual(fields["depth_max_ms"] as? Double, 100)
    XCTAssertEqual(fields["dropped"] as? Int, 0)
  }

  func testADroppedFrameIsSaidEvenWhenNothingWasScheduled() {
    var w = PlaybackWindow()
    w.dropped()
    XCTAssertFalse(w.isEmpty)
    XCTAssertEqual(w.droppedFrames, 1)
    XCTAssertEqual(w.fields["dropped"] as? Int, 1)
    XCTAssertEqual(w.fields["frames"] as? Int, 0)
  }
}
