//  #417, story 085: the Cockpit chooses the model; an offline call keeps the last good recommendation.

import Foundation

public struct CallRecommendations: Codable, Sendable {
  public struct Voice: Codable, Sendable {
    public let pick: String
    public let id: String
    public let model: String
  }

  public let ok: Bool
  public let schema: Int
  public let voices: [Voice]

  public static func decode(_ data: Data) -> CallRecommendations? {
    guard let value = try? JSONDecoder().decode(Self.self, from: data), value.ok, value.schema == 1 else {
      return nil
    }
    return value
  }
}

/// Persisted as one setting: body and validators advance together, only after a valid response.
public struct CallSettings: Codable, Sendable {
  public private(set) var recommendations: CallRecommendations?
  public private(set) var etag: String?
  public private(set) var expiresAt: Date?
  public private(set) var maxAge: Double = 300
  /// This launch's network result is distinct from the persisted copy in call_start.
  private var fromServer = false

  private enum CodingKeys: String, CodingKey { case recommendations, etag, expiresAt, maxAge }

  public init(saved: String? = nil) {
    if let saved, let restored = try? JSONDecoder().decode(Self.self, from: Data(saved.utf8)),
      restored.recommendations?.ok == true, restored.recommendations?.schema == 1
    {
      self = restored
    }
  }

  public var saved: String? {
    (try? JSONEncoder().encode(self)).map { String(decoding: $0, as: UTF8.self) }
  }

  public func needsRefresh(at now: Date) -> Bool {
    recommendations == nil || now >= (expiresAt ?? .distantPast)
  }

  /// An invalid response never replaces the last good body or its validator.
  @discardableResult
  public mutating func receive(
    status: Int, data: Data, etag: String?, cacheControl: String?, at now: Date
  ) -> Bool {
    if status == 200 {
      guard let value = CallRecommendations.decode(data) else { return false }
      recommendations = value
      self.etag = etag
    } else if status == 304 {
      guard recommendations != nil else { return false }
      if let etag { self.etag = etag }
    } else {
      return false
    }
    if let age = Self.maxAge(cacheControl) { maxAge = age } else if status == 200 { maxAge = 300 }
    expiresAt = now.addingTimeInterval(maxAge)
    fromServer = true
    return true
  }

  private static func maxAge(_ header: String?) -> Double? {
    for part in (header ?? "").split(separator: ",") {
      let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      if pair.count == 2, pair[0].lowercased() == "max-age",
        let age = Double(pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))),
        age.isFinite, age >= 0
      {
        return age
      }
    }
    return nil
  }

  public func fields(for backend: CallBackend, voice: CallVoice) -> (voice: String, model: String, source: String) {
    let fallback = voice.frameFields(for: backend)
    guard CallVoice.hasPick(backend),
      let row = recommendations?.voices.first(where: { $0.pick == voice.rawValue }),
      !row.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !row.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return (fallback.voice, fallback.model, "bridge-default") }
    return (voice == .tony ? "" : row.id, row.model, fromServer ? "server" : "cache")
  }
}
