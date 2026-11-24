//  The chat wire's HTTP requests, kept out of ChatWireKit so that module builds for WebAssembly, whose Foundation has
//  no URLRequest (spec 2026-11-22-board-rules-on-the-web-design.md). Same types, same calls: these are extensions, and
//  ContextCore re-exports ChatWireKit, so callers are unchanged.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension ChatWire {
  public static func listRequest(cockpit: String) throws -> URLRequest {
    try get(cockpit, "/chat")
  }

  public static func threadRequest(_ key: String, cockpit: String) throws -> URLRequest {
    try get(cockpit, "/chat/" + encode(key))
  }

  public static func seenRequest(_ key: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("chat-seen"))
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["thread": key])
    return request
  }

  /// `POST /chat/<key>/archive` or `/unarchive` (#589, cockpit f94feae); the body is ignored, but the Cockpit's
  /// write boundary answers 415 to a POST that isn't `application/json`, an empty one included.
  public static func archiveRequest(_ key: String, archive: Bool, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit),
      let url = URL(
        string: cockpit.trimmingSuffix("/") + "/chat/" + encode(key) + (archive ? "/archive" : "/unarchive"))
    else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    return request
  }

  public static func get(_ cockpit: String, _ path: String) throws -> URLRequest {
    guard let url = URL(string: cockpit.trimmingSuffix("/") + path) else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }
}

extension ChatDecisions {
  public typealias Transport = ChatMove.Transport

  public static func listRequest(cockpit: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    return try ChatWire.get(cockpit, "/asks")
  }

  /// `build` says which build sent it, on every verb (story 1134).
  public static func request(_ verb: Verb, ask: ChatAsk, cockpit: String, build: AppBuild = .current) throws
    -> URLRequest
  {
    switch verb {
    case .answer(let option) where isOther(option): throw NotSent.ownAnswerLabel
    case .ownWords(let words) where !canSend(words: words): throw NotSent.noWords
    default: break
    }
    let path: String
    let body: [String: Any]
    switch verb {
    case .answer(let option):
      // What the Cockpit's own card sends for an option with no note (`submit()` in its index.html).
      path = "/act"
      body = [
        "id": ask.id, "action": "respond", "response": "DECISION: \(option.label)", "base_updated_at": ask.updatedAt,
      ]
      .merging(postToChat) { a, _ in a }
    case .ownWords(let words):
      // The Inbox's free-text answer (`submit()` in its index.html): DECISION: and the words.
      path = "/act"
      let words = words.trimmingCharacters(in: .whitespacesAndNewlines)
      body = ["id": ask.id, "action": "respond", "response": "DECISION: \(words)", "base_updated_at": ask.updatedAt]
        .merging(postToChat) { a, _ in a }
    case .snooze(let preset):
      path = "/snooze"
      body = ["id": ask.id, "preset": preset.rawValue]
    case .close(let reason):
      path = "/close"
      body = [
        "id": ask.id, "action": "close", "reason": reason.trimmingCharacters(in: .whitespaces),
        "base_updated_at": ask.updatedAt,
      ]
      .merging(postToChat) { a, _ in a }
    case .abandon(let reason):
      path = "/close"
      body = ["id": ask.id, "action": "abandon", "reason": reason ?? "", "base_updated_at": ask.updatedAt]
        .merging(postToChat) { a, _ in a }
    }
    guard let base = URL(string: cockpit), base.host != nil, let url = URL(string: cockpit.trimmingSuffix("/") + path)
    else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    // The write boundary answers 415 to a POST that isn't JSON, and refuses one from a foreign origin.
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: build.stamp(body))
    return request
  }

  public static func run(_ verb: Verb, ask: ChatAsk, cockpit: String, transport: Transport) async -> Outcome {
    do {
      let (data, status) = try await transport(try request(verb, ask: ask, cockpit: cockpit))
      return outcome(status: status, body: data)
    } catch {
      return outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }
}

extension ChatMove {
  /// `POST` the request; the answer's body and HTTP status (nil when it wasn't HTTP).
  public typealias Transport = @MainActor (URLRequest) async throws -> (Data, Int?)

  public static func request(thread: String, message: String, cockpit: String) throws -> URLRequest {
    guard let url = URL(string: cockpit.trimmingSuffix("/") + "/chat/move"), let base = URL(string: cockpit) else {
      throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    // The Cockpit's write boundary answers 415 to a POST that isn't JSON, and refuses one from a foreign origin.
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["thread": thread, "message_id": message])
    return request
  }

  /// One move, start to answer.
  public static func run(thread: String, message: String, cockpit: String, transport: Transport) async -> Outcome {
    do {
      let (data, status) = try await transport(try request(thread: thread, message: message, cockpit: cockpit))
      return outcome(status: status, body: data)
    } catch {
      return outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }
}

extension ChatSiteNames {
  /// GET /link-labels on the chat's Cockpit (story 1135).
  public static func request(cockpit: String) throws -> URLRequest { try ChatWire.get(cockpit, path) }
}
