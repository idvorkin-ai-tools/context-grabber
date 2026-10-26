//  Speaking a message in Chat (#448, chat spec "Speaking a message"): a recorded clip goes to Deepgram's pre-recorded
//  API with the Cockpit's model and names, and the words land in the draft for Igor to read before he sends.

import Foundation

public enum ChatVoice {
  /// MIRRORED from DEEPGRAM_KEYTERMS in the Cockpit's serve.py (and voice_bridge.py): the names nova-3 is primed to
  /// spell right. Kept in step by hand; the phone cannot import them.
  public static let keyterms = ["Kettlebility", "Igor", "Tori", "Zach", "Amelia", "Larry", "beads", "Cockpit"]

  /// The Cockpit's DEEPGRAM_URL: nova-3, smart format, punctuation, then each keyterm.
  public static var url: URL {
    var parts = URLComponents()
    parts.scheme = "https"
    parts.host = "api.deepgram.com"
    parts.path = "/v1/listen"
    parts.queryItems =
      [
        URLQueryItem(name: "model", value: "nova-3"), URLQueryItem(name: "smart_format", value: "true"),
        URLQueryItem(name: "punctuate", value: "true"),
      ] + keyterms.map { URLQueryItem(name: "keyterm", value: $0) }
    // swiftlint:disable:next force_unwrapping
    return parts.url!  // a fixed address: the tests read it back
  }

  /// What the recorder writes: AAC in an MPEG-4 container, which Deepgram reads as `audio/mp4`.
  public static let contentType = "audio/mp4"

  /// One clip's POST. The key rides only in the header, so a logged URL never carries it.
  /// `userAgent` is not cosmetic: the Cockpit found some default agents refused with a 403 that reads exactly like a
  /// bad key (serve.py `_http_post`), so every clip names the app.
  public static func request(
    audio: Data, key: String, contentType: String = contentType, userAgent: String = "GrabberNative"
  ) -> URLRequest {
    var request = URLRequest(url: url, timeoutInterval: 60)
    request.httpMethod = "POST"
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(
      "Token \(key.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = audio
    return request
  }

  /// A LocalizedError, so `localizedDescription` (what the screen and the log show) is the message itself, not
  /// Foundation's generic line (CallAudioError's pattern).
  public struct Failure: Error, LocalizedError, Equatable, CustomStringConvertible {
    /// The HTTP status, 0 when the body was not Deepgram's.
    public let status: Int
    public let message: String
    public var description: String { message }
    public var errorDescription: String? { message }

    public init(status: Int, message: String) {
      self.status = status
      self.message = message
    }
  }

  /// The words in a 200's body, trimmed; "" for silence (not a failure, as the Cockpit has it). Throws for anything
  /// else, with Deepgram's own `err_msg` when it sent one.
  public static func transcript(status: Int, body: Data) throws -> String {
    let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    guard status == 200 else {
      let said = (json?["err_msg"] as? String) ?? (json?["message"] as? String) ?? (json?["reason"] as? String)
      let code = json?["err_code"] as? String
      var message = "Deepgram answered \(status)"
      if let code { message += " \(code)" }
      if let said { message += ": \(said)" }
      if status == 401 || status == 403 {
        message += (message.hasSuffix(".") ? " " : ". ") + "Check the key in Settings → Voice in Chat."
      }
      throw Failure(status: status, message: message)
    }
    guard let results = json?["results"] as? [String: Any], let channels = results["channels"] as? [[String: Any]],
      let alternatives = channels.first?["alternatives"] as? [[String: Any]]
    else { throw Failure(status: status, message: "Deepgram's answer had no transcript in it") }
    return ((alternatives.first?["transcript"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The draft with the words after what was typed, a space or a line between; unchanged for an empty transcript.
  public static func draft(_ text: String, adding transcript: String) -> String {
    let words = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !words.isEmpty else { return text }
    guard let last = text.last else { return words }
    return text + (last.isWhitespace ? "" : " ") + words
  }

  /// The recording button's clock: `0:07`, `1:12`.
  public static func elapsed(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):" + String(format: "%02d", s % 60)
  }
}
