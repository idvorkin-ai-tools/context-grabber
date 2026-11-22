//  #673, stories 544–545: finding the web link in what a share hands over, in ContextCore so the host can test it: the
//  rules against any `ShareAttachment` (Linux too), the share sheet's own item providers on the Mac. The other app
//  chooses the form: a URL, its plain words or its bytes, and not always the first attachment.

import Foundation

#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers
#endif

public enum ShareLink {
  /// The three forms `find` reads an attachment in: a URL (a file URL is one too), plain words, or any text, which
  /// includes marked-up text such as RTF and HTML.
  public enum Form: Sendable { case url, plainText, text }

  /// The first web link any attachment holds: as a URL, then as plain words, then as marked-up text whose words are
  /// the link. Nothing shared ahead of it hides it. With no web link, the first other address that is not a file.
  /// `markedUp` turns an attachment's RTF or HTML into its words: that takes UIKit's text system, so the card brings it.
  public static func find<A: ShareAttachment>(
    in attachments: [A], markedUp: (A) async -> String? = { _ in nil }
  ) async -> URL? {
    var other: URL?
    for attachment in attachments where attachment.holds(.url) {
      guard let item = await attachment.item(.url), let found = url(from: item) else { continue }
      if isWeb(found) { return found }
      if other == nil, !found.isFileURL { other = found }
    }
    for attachment in attachments where attachment.holds(.plainText) {
      guard let item = await attachment.item(.plainText), let found = url(from: item), isWeb(found) else { continue }
      return found
    }
    for attachment in attachments where attachment.holds(.text) && !attachment.holds(.plainText) {
      if let words = await markedUp(attachment), let found = fromText(words) { return found }
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

/// What `ShareLink.find` asks of an attachment: whether it holds a form, and its item in that form. The share sheet's
/// `NSItemProvider` is one (below); a test brings its own, so the rules run where there is none (`just test-linux`).
public protocol ShareAttachment {
  func holds(_ form: ShareLink.Form) -> Bool
  func item(_ form: ShareLink.Form) async -> Any?
}

#if canImport(UniformTypeIdentifiers)
  extension ShareLink.Form {
    var type: UTType {
      switch self {
      case .url: .url
      case .plainText: .plainText
      case .text: .text
      }
    }
  }

  extension NSItemProvider: ShareAttachment {
    public func holds(_ form: ShareLink.Form) -> Bool { hasItemConformingToTypeIdentifier(form.type.identifier) }

    public func item(_ form: ShareLink.Form) async -> Any? {
      try? await loadItem(forTypeIdentifier: form.type.identifier)
    }
  }
#endif
