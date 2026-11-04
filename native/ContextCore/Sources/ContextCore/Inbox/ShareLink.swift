//  #673, stories 544–545: finding the web link in what a share hands over, in ContextCore so the host can test it with
//  real item providers. The other app chooses the form: a URL, its plain words or its bytes, and not always the first
//  attachment.

import Foundation
import UniformTypeIdentifiers

public enum ShareLink {
  /// The first web link any provider holds: as a URL, then as plain words, then as marked-up text whose words are the
  /// link. Nothing shared ahead of it hides it. With no web link, the first other address that is not a file.
  /// `markedUp` turns a provider's RTF or HTML into its words: that takes UIKit's text system, so the card brings it.
  public static func find(
    in providers: [NSItemProvider], markedUp: (NSItemProvider) async -> String? = { _ in nil }
  ) async -> URL? {
    var other: URL?
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
        let found = url(from: item)
      else { continue }
      if isWeb(found) { return found }
      if other == nil, !found.isFileURL { other = found }
    }
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
        let found = url(from: item), isWeb(found)
      else { continue }
      return found
    }
    for provider in providers
    where provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
      && !provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
    {
      if let words = await markedUp(provider), let found = fromText(words) { return found }
    }
    return other
  }

  /// What a provider's URL item holds, in any of the forms apps register it as. Even a provider made from a URL can
  /// answer with its bytes (seen on the Mac under `swift test`, 2026-11-04), so `as? URL` alone is not enough.
  static func url(from item: Any) -> URL? {
    if let url = item as? URL { return url }
    if let words = item as? String { return parse(words) }
    if let data = item as? Data, let words = String(data: data, encoding: .utf8) { return parse(words) }
    return nil
  }

  /// Text that is nothing but a web link. Text with more in it stays text, the link inside it word for word.
  public static func fromText(_ text: String) -> URL? {
    guard let link = parse(text), isWeb(link) else { return nil }
    return link
  }

  private static func isWeb(_ link: URL) -> Bool {
    ["http", "https"].contains(link.scheme?.lowercased() ?? "")
  }

  private static func parse(_ words: String) -> URL? {
    let link = URL(string: words.trimmingCharacters(in: .whitespacesAndNewlines), encodingInvalidCharacters: false)
    return link?.scheme == nil ? nil : link
  }
}
