//  What the board says about its own sending, for the Cockpit's board debug page (spec 2026-11-16-whiteboard-board-ops-design.md,
//  *What the board says about its own sending, for the debug page*; story 1155, bead context-grabber-7zmj): the iPad's half
//  of a picture's way to Larry, and spoken words' mic-off-to-text timing. Both ride among the turn's events.

import Foundation

/// One picture's send, as the iPad saw it. `t` is when its message left, unix ms.
public struct BoardPostTiming: Equatable, Codable, Sendable {
  public var t: Int64
  /// `<sha> <branch>`, as a shake report names the build.
  public var build: String
  /// What sent it: button, responder, retry, …
  public var from: String
  public var renderMs: Int?
  public var encodeMs: Int?
  public var strokesMs: Int?
  public var uploadMs: Int?
  public var bytes: Int

  public init(
    t: Int64, build: String, from: String, renderMs: Int? = nil, encodeMs: Int? = nil, strokesMs: Int? = nil,
    uploadMs: Int? = nil, bytes: Int
  ) {
    self.t = t
    self.build = build
    self.from = from
    self.renderMs = renderMs
    self.encodeMs = encodeMs
    self.strokesMs = strokesMs
    self.uploadMs = uploadMs
    self.bytes = bytes
  }

  var wire: [String: Any] {
    var out: [String: Any] = ["type": "post", "t": t, "build": build, "from": from, "bytes": bytes]
    for (name, ms) in [
      ("render_ms", renderMs), ("encode_ms", encodeMs), ("strokes_ms", strokesMs), ("upload_ms", uploadMs),
    ] {
      if let ms { out[name] = ms }
    }
    return out
  }
}

/// One spoken stretch taken for a turn, every time unix ms. `since` is the mic opening for its first words, else when the
/// words before were taken. `off` is nil while the mic stayed open; `sent` nil until a picture or a batch carries it.
public struct BoardMicTiming: Equatable, Codable, Sendable {
  public var on: Int64
  public var since: Int64
  public var words: Int64?
  public var off: Int64?
  public var text: Int64
  public var sent: Int64?
  public var chars: Int

  public init(
    on: Int64, since: Int64, words: Int64? = nil, off: Int64? = nil, text: Int64, sent: Int64? = nil, chars: Int
  ) {
    self.on = on
    self.since = since
    self.words = words
    self.off = off
    self.text = text
    self.sent = sent
    self.chars = chars
  }

  /// The gaps, in ms: what the session log's `spoke` line and the `mic` event both carry.
  public var gaps: [String: Int] {
    var out: [String: Int] = [:]
    let gap = { (a: Int64?, b: Int64?) -> Int? in
      guard let a, let b, b >= a else { return nil }
      return Int(b - a)
    }
    if let ms = gap(since, words) { out["to_words_ms"] = ms }
    if let ms = gap(on, off) { out["on_to_off_ms"] = ms }
    if let ms = gap(off, text) { out["off_to_text_ms"] = ms }
    if let ms = gap(text, sent) { out["text_to_sent_ms"] = ms }
    return out
  }

  var wire: [String: Any] {
    var out: [String: Any] = ["type": "mic", "t": on, "text_t": text, "chars": chars]
    if let words { out["words_t"] = words }
    if let off { out["off_t"] = off }
    if let sent { out["sent_t"] = sent }
    for (name, ms) in gaps { out[name] = ms }
    return out
  }
}

/// The board's mic, timed: opened, the first words heard, closed, the words taken for a turn, and those going out.
public struct BoardMicClock: Equatable, Sendable {
  /// Taken words not yet sent, at most this many (the newest kept).
  public static let cap = 20

  private var on: Int64?
  private var since: Int64?
  private var words: Int64?
  private var off: Int64?
  public private(set) var waiting: [BoardMicTiming] = []

  public init() {}

  public mutating func opened(t: Int64) {
    on = t
    since = t
    words = nil
    off = nil
  }

  public mutating func heard(t: Int64) {
    guard on != nil, words == nil else { return }
    words = t
  }

  public mutating func closed(t: Int64) {
    guard on != nil, off == nil else { return }
    off = t
  }

  /// Words were taken at `t`: their timing, kept to go with the next picture unless `kept` is false (Ghosts off drops
  /// them). Nil with no mic opened (a launch hook's words). Words said after, with the mic still open, are timed from
  /// these.
  @discardableResult
  public mutating func taken(t: Int64, chars: Int, kept: Bool = true) -> BoardMicTiming? {
    guard let on, let since else { return nil }
    let timing = BoardMicTiming(on: on, since: since, words: words, off: off, text: t, chars: chars)
    if kept {
      waiting.append(timing)
      if waiting.count > Self.cap { waiting.removeFirst(waiting.count - Self.cap) }
    }
    if off != nil {
      self.on = nil
      self.since = nil
      self.off = nil
    } else {
      self.since = t
    }
    words = nil
    return timing
  }

  /// The waiting timings as events, sent at `t`; none wait after.
  public mutating func sent(t: Int64) -> [BoardEvent] {
    defer { waiting = [] }
    return waiting.map {
      var timing = $0
      timing.sent = t
      return .mic(timing)
    }
  }
}
