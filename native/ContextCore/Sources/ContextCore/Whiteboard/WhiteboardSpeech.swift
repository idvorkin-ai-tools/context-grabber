//  What the board's mic has heard and not yet sent (spec 2026-11-01-whiteboard-shapes-design.md, story 345). The
//  recognizer hands over all its words so far each time; a turn wants only the new ones.

public struct WhiteboardSpeech: Sendable {
  private var words: [Substring] = []
  private var sent = 0

  public init() {}

  /// True when the words changed: a callback that only repeats them changes nothing (story 1281).
  @discardableResult
  public mutating func heard(_ text: String) -> Bool {
    let before = words
    words = text.split(whereSeparator: \.isWhitespace)
    // ponytail: counted in words, so a revision of words already sent isn't sent again; one that changes how many there
    // are shifts the cut by that many. A longest-common-prefix would resend everything after the first changed word.
    sent = min(sent, words.count)
    return words != before
  }

  /// The words not yet taken, left in place: waiting words keep *Send to Larry* undimmed (story 1287).
  public var pending: String? {
    sent < words.count ? words[sent...].joined(separator: " ") : nil
  }

  /// Story 1305 (Igor, 2026-11-24: "Keep a silence send, only after 5 s or more"): how long the mic must hear nothing
  /// new before the waiting words go.
  public static let silenceSendMs = 5000

  /// Story 1305: whether `silentMs` of silence since the last change sends: only words not yet taken, only at 5 s.
  public func silenceSends(silentMs: Int) -> Bool { pending != nil && silentMs >= Self.silenceSendMs }

  /// The words since the last call, once; nil when there are none.
  public mutating func takeNew() -> String? {
    guard sent < words.count else { return nil }
    defer { sent = words.count }
    return words[sent...].joined(separator: " ")
  }

  /// The whole of what the turn tells the Cockpit about the board.
  public static func context(title: String, said: String?) -> String {
    guard let said else { return title }
    return "\(title)\nIgor just said: \(said)"
  }
}
