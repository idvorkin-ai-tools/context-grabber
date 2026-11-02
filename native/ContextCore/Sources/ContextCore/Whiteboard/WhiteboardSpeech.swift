//  What the board's mic has heard and not yet sent (spec 2026-11-01-whiteboard-shapes-design.md, story 345). The
//  recognizer hands over all its words so far each time; a turn wants only the new ones.

public struct WhiteboardSpeech: Sendable {
  private var text = ""
  private var sent = 0

  public init() {}

  public mutating func heard(_ text: String) {
    self.text = text
    // ponytail: a revision of words already sent isn't sent again; the recognizer rarely reworks more than the last few.
    sent = min(sent, text.count)
  }

  /// The words since the last call, once; nil when there are none.
  public mutating func takeNew() -> String? {
    let new = text.dropFirst(sent).trimmingCharacters(in: .whitespacesAndNewlines)
    sent = text.count
    return new.isEmpty ? nil : new
  }

  /// The whole of what the turn tells the Cockpit about the board.
  public static func context(title: String, said: String?) -> String {
    guard let said else { return title }
    return "\(title)\nIgor just said: \(said)"
  }
}
