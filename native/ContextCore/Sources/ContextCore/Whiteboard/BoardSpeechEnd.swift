//  When a spoken phrase on the board is finished (spec 2026-11-01-whiteboard-shapes-design.md, *Talking while drawing*;
//  story 1118, bead context-grabber-u1yy): the silence after his last new words, longer for a phrase that doesn't end
//  like a sentence, longest, and bounded, for one left hanging.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardSpeechEnd {
  public enum Why: String, Sendable {
    /// Ends with a full stop, question or exclamation mark.
    case sentence
    /// No sentence end: on-device dictation rarely punctuates, so the usual case.
    case open
    /// The last word leaves it hanging ("that says", "when I", "the"): the bound.
    case dangling
  }

  public static let sentenceMs = 1500
  public static let openMs = 3000
  /// Nothing waits longer: a phrase he trails off still goes.
  public static let danglingMs = 5000

  /// Words that rarely end a thought. Lowercased, without punctuation.
  static let hanging: Set<String> = [
    "a", "an", "the", "and", "or", "but", "so", "because", "if", "when", "then", "than", "that", "which", "who",
    "where", "what", "to", "of", "in", "on", "at", "for", "with", "from", "into", "about", "like", "is", "are", "was",
    "were", "be", "my", "your", "his", "her", "its", "our", "their", "this", "these", "those", "says", "say", "said",
    "i", "i'm", "it's", "um", "uh", "let's", "can", "could", "would", "should", "will", "do", "does",
  ]

  /// How long the silence after these words must last before they go, and why.
  public static func wait(after words: String) -> (ms: Int, why: Why) {
    let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
    if let last = trimmed.last, ".?!".contains(last) { return (sentenceMs, .sentence) }
    let lastWord = trimmed.split(whereSeparator: \.isWhitespace).last.map {
      $0.lowercased().trimmingCharacters(in: .punctuationCharacters.subtracting(CharacterSet(charactersIn: "'")))
    }
    if let lastWord, hanging.contains(lastWord) { return (danglingMs, .dangling) }
    return (openMs, .open)
  }

  /// Whether words last changed `silentMs` ago are finished.
  public static func finished(_ words: String, silentMs: Int) -> Bool { silentMs >= wait(after: words).ms }
}
