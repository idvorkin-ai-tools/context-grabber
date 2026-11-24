//  A board of the Cockpit's web ink page, named by a board link (story 569, #1354; spec
//  docs/superpowers/specs/2026-10-06-native-links-design.md). The Cockpit writes a web board's id as `ink-` and its
//  name (its board debug page's chips); the app's own boards are UUIDs, so the prefix tells them apart. The app can't
//  draw a web board, so its link opens the board's page instead. Pure; the app does the opening.

import Foundation

public struct WebInkBoard: Equatable, Sendable {
  /// The web board's name, as the ink page's `?b=` takes it.
  public let name: String

  /// The web board a link's board id names, or nil for one of the app's own boards.
  public init?(board id: String) {
    guard id.hasPrefix("ink-") else { return nil }
    let name = String(id.dropFirst(4))
    guard !name.isEmpty else { return nil }
    self.name = name
  }

  /// The board's page on the Cockpit: `<cockpit>/ink?b=<name>`.
  public func url(cockpit: String) -> URL? {
    guard var parts = URLComponents(string: cockpit), parts.scheme != nil, parts.host != nil else { return nil }
    let base = parts.path.hasSuffix("/") ? String(parts.path.dropLast()) : parts.path
    parts.path = base + "/ink"
    parts.percentEncodedQueryItems = [
      URLQueryItem(
        name: "b", value: name.addingPercentEncoding(withAllowedCharacters: Self.queryValue) ?? name)
    ]
    return parts.url
  }

  /// A query value's characters left as they are: `&`, `=`, `+` and `#` would end or change it.
  private static let queryValue = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#"))
}
