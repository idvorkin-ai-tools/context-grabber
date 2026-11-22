//  Igor's blog from the home screen (story 137; spec 2026-10-07-native-eulogy-design.md): the eulogy post, its song,
//  the recent changes, and a random page (#259, story 247).

import Foundation

public enum BlogLinks {
  public static let eulogy = URL(string: "https://idvork.in/eulogy")!
  public static let recent = URL(string: "https://idvork.in/recent")!
  /// The blog picks the page, so each visit lands somewhere else.
  public static let random = URL(string: "https://idvork.in/random")!

  /// #392, stories 465-469: what holding Random offers. The blog decides which posts are in a topic; the app only
  /// opens the link, and cannot see whether the blog read the topic (story 468).
  public enum Topic: String, CaseIterable, Sendable {
    case anything, ai, tech, family, health, mind, work, books

    public var title: String {
      switch self {
      case .anything: return "Anything"
      case .ai: return "AI"
      case .tech: return "Tech"
      case .family: return "Family"
      case .health: return "Health"
      case .mind: return "Mind"
      case .work: return "Work"
      case .books: return "Books"
      }
    }

    /// Apple's nearest symbol, drawn until the art is.
    public var symbol: String {
      switch self {
      case .anything: return "dice"
      case .ai: return "sparkles"
      case .tech: return "wrench.and.screwdriver"
      case .family: return "figure.2.and.child.holdinghands"
      case .health: return "heart.fill"
      case .mind: return "brain.head.profile"
      case .work: return "briefcase.fill"
      case .books: return "book.fill"
      }
    }

    /// Anything is the tile's own link; a topic is that link asking for the topic.
    public var link: URL {
      self == .anything ? random : random.appending(queryItems: [URLQueryItem(name: "topic", value: rawValue)])
    }
  }

  /// The Suno song the post embeds, as its song page (which the Suno app opens): the post carries it as an embed
  /// (`suno.com/embed/<id>`) and as a link (`suno.com/song/<id>`). The first one wins; nil when there is none.
  public static func song(inPost html: String) -> URL? {
    let pattern =
      #"suno\.com/(?:song|embed)/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
      let id = Range(match.range(at: 1), in: html)
    else { return nil }
    return URL(string: "https://suno.com/song/\(html[id].lowercased())")
  }
}
