//  Story 233 (spec 2026-11-03-ipad-windows-design.md, "Its name says what's open in it"): a window's name, place ·
//  detail, in the Cockpit's words. The detail rule mirrors the Cockpit's `titleDetail` (cockpit_core.js, its story
//  211), so a Mac's window list reads alike across the app and the Cockpit's browser tabs.

import Foundation

public enum WindowTitle {
  /// The Cockpit's `TITLE_DETAIL_MAX`: a tab strip cuts at about 30 characters, a window list a little later.
  public static let detailMax = 40

  /// The window's name. `pageTitle` is the Cockpit's own name for its view, used whole when it has one; otherwise
  /// the tile's name, with what is open in it (`detail`, a thread's or a board's title) after a dot.
  public static func name(tile: String, pageTitle: String? = nil, detail: String? = nil) -> String {
    if let page = pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !page.isEmpty { return page }
    let shown = self.detail(detail ?? "")
    return shown.isEmpty ? tile : "\(tile) · \(shown)"
  }

  /// A title as plain words: a markdown link reads as its label, markdown's marks go, runs of space are one space,
  /// and past `detailMax` it is cut, trailing space dropped, with an ellipsis.
  public static func detail(_ text: String) -> String {
    var plain = text.replacingOccurrences(
      of: #"\[([^\]\n]+)\]\([^)\s]*\)"#, with: "$1", options: .regularExpression)
    plain = plain.replacingOccurrences(of: "[*_`#>]+", with: "", options: .regularExpression)
    plain = plain.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
    guard plain.count > detailMax else { return plain }
    let kept = String(plain.prefix(detailMax - 1))
    return kept.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) + "…"
  }
}
