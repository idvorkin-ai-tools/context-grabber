//  Larry's playback, watched (#442, story 210). Igor, 2026-10-25, on a Direct call: "I got a bunch of noise and
//  static there." The bridge's recording of what it sent was clean, so the fault was between the socket and the
//  speaker — and the log had nothing on that stretch. Two platform-free pieces: the bytes read as the stream they
//  are, and a window of counters the engine logs every five seconds while his audio plays.

import Foundation

/// Larry's PCM16 as the byte stream it is, not the frames the socket cut it into.
///
/// The Direct backend forwards ElevenLabs' HTTP chunks as they land, and a chunk can end mid-sample: 12 of 38
/// frames in one sentence, measured 2026-10-25. Decoded frame by frame, the byte after an odd frame was read as the
/// low byte of a sample and every sample after it was a half-swapped pair — broadband static until the next odd
/// frame flipped it back. Carried to the next frame, the odd byte is the stream as sent. A flush or a rebuild drops
/// the carry: what follows is a new stream.
public struct PCM16Stream: Sendable {
  private var carry: UInt8?
  /// Frames so far whose byte count was odd.
  public private(set) var oddFrames = 0

  public init() {}

  /// A frame ended mid-sample and its last byte waits for the next.
  public var carrying: Bool { carry != nil }

  /// One frame's samples: the previous frame's odd byte in front, this frame's odd byte kept back.
  public mutating func decode(_ frame: Data) -> [Float] {
    if frame.count % 2 == 1 { oddFrames += 1 }
    var bytes = Data(capacity: frame.count + 1)
    if let carry { bytes.append(carry) }
    bytes.append(frame)
    if bytes.count % 2 == 1 {
      carry = bytes.removeLast()
    } else {
      carry = nil
    }
    return PCM.pcm16ToFloat(bytes)
  }

  /// A flush or a rebuild: the next frame starts a new stream.
  public mutating func reset() { carry = nil }
}

/// Five seconds of Larry's frames as the engine took them: how many and how big, how many were odd, how many it had
/// to drop, the longest wait between two, how often the player had already run dry when the next one came and for
/// how long in all, and how much was queued ahead at the thinnest and the thickest.
public struct PlaybackWindow: Equatable, Sendable {
  /// A frame this soon after the last is the same reply still arriving; a dry player then is an underrun. Later is
  /// Larry pausing between sentences, and a dry player is the quiet it should be.
  public static let sameReplyMs = 1000.0
  /// Queued audio under this is one IO cycle from silence: as good as dry.
  public static let dryS = 0.01

  public private(set) var frames = 0
  public private(set) var bytesMin = 0
  public private(set) var bytesMax = 0
  public private(set) var oddFrames = 0
  /// Frames with no running engine to take them: lost, and the stream's alignment with them.
  public private(set) var droppedFrames = 0
  public private(set) var underruns = 0
  /// Milliseconds the player had nothing to play before the frame that ended each underrun, summed.
  public private(set) var starvedMs = 0.0
  public private(set) var gapMaxMs = 0.0
  public private(set) var depthMinMs = 0.0
  public private(set) var depthMaxMs = 0.0

  public init() {}

  /// Nothing came and nothing was dropped: no line to write.
  public var isEmpty: Bool { frames == 0 && droppedFrames == 0 }

  /// One frame scheduled: its bytes, the clock (ms), the seconds still queued ahead of it (negative: how long ago
  /// the player passed the end of the queue), and when the previous frame was scheduled (0: none since the
  /// playback opened or was flushed).
  public mutating func scheduled(bytes: Int, at now: Double, queuedS: Double, previousAt: Double) {
    frames += 1
    bytesMin = frames == 1 ? bytes : min(bytesMin, bytes)
    bytesMax = max(bytesMax, bytes)
    if bytes % 2 == 1 { oddFrames += 1 }
    let depth = max(0, queuedS) * 1000
    depthMinMs = frames == 1 ? depth : min(depthMinMs, depth)
    depthMaxMs = max(depthMaxMs, depth)
    guard previousAt > 0 else { return }
    let gap = now - previousAt
    gapMaxMs = max(gapMaxMs, gap)
    if queuedS < Self.dryS, gap < Self.sameReplyMs {
      underruns += 1
      starvedMs += max(0, -queuedS) * 1000
    }
  }

  /// A frame that found no running engine.
  public mutating func dropped() { droppedFrames += 1 }

  /// The log line's fields, milliseconds whole.
  public var fields: [String: Any] {
    [
      "frames": frames, "bytes_min": bytesMin, "bytes_max": bytesMax, "odd_frames": oddFrames,
      "dropped": droppedFrames, "underruns": underruns, "starved_ms": starvedMs.rounded(),
      "gap_max_ms": gapMaxMs.rounded(), "depth_min_ms": depthMinMs.rounded(), "depth_max_ms": depthMaxMs.rounded(),
    ]
  }
}
