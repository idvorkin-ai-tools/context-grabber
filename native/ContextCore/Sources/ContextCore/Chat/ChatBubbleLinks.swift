//  Short links in a bubble (spec 2026-10-25-native-chat-design.md, Links in a thread: Short links in a bubble; story
//  743). Inside one message's words a lone pull request reads *PR* and a link to Igor's blog or its tailnet preview
//  reads *Preview*; several in one message keep words that tell them apart. The chips (`ChatLinks`) are unchanged.

import Foundation

public enum ChatBubbleLinks {
  /// The blog's preview servers on the tailnet listen on these ports (Jekyll on the Cockpit's host).
  static let previewPorts = 8400...8499

  /// What each link in `text` reads in its bubble, keyed by the link as written with its sentence punctuation dropped
  /// (`ChatLinks.trimmed` of what the link finder matched). A link that shows as written has no entry.
  public static func labels(in text: String) -> [String: String] {
    guard let finder = ChatLinks.Finder() else { return [:] }
    let links = ChatLinks.written(in: text, finder)
    // Each pull request once (a PR written twice, or to two of its pages, is one), and how many share its number.
    var prs: [String: Int] = [:]
    var previews = Set<String>()
    for (_, link) in links {
      if case .pullRequest(_, let number) = link.kind { prs[link.id] = number }
      if isPreview(link) { previews.insert(link.id) }
    }
    let perNumber = Dictionary(grouping: prs.values) { $0 }.mapValues(\.count)
    var out: [String: String] = [:]
    for (written, link) in links {
      if case .pullRequest(let repo, let number) = link.kind {
        out[written] =
          prs.count == 1 ? "PR" : (perNumber[number] ?? 0) > 1 ? "\(repoName(repo)) PR #\(number)" : link.label
      } else if isPreview(link) {
        out[written] = previews.count == 1 ? "Preview" : "Preview: \(slug(link.label))"
      }
    }
    return out
  }

  /// Igor's blog, on its site or a preview of it on the tailnet.
  static func isPreview(_ link: ChatLink) -> Bool {
    guard link.kind == .web, let raw = link.url.host?.lowercased() else { return false }
    let host = raw.hasPrefix("www.") ? String(raw.dropFirst(4)) : raw
    if host == "idvork.in" || host == "idvorkin.github.io" { return true }
    return host == CockpitPage.host && link.url.port.map { previewPorts.contains($0) } ?? false
  }

  /// `idvorkin/context-grabber` → `context-grabber`.
  private static func repoName(_ repo: String) -> String {
    repo.split(separator: "/").last.map(String.init) ?? repo
  }

  /// A web chip's words without its site: `idvork.in/ai-journal` → `ai-journal`; a front page keeps the site.
  private static func slug(_ label: String) -> String {
    guard let slash = label.firstIndex(of: "/") else { return label }
    return String(label[label.index(after: slash)...])
  }
}
