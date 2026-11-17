//  A folded header's "▸ N lines folded" (spec 2026-11-16-whiteboard-board-ops-design.md, *Headers fold their sections*,
//  stories 900, 901; the Cockpit's assets/ink/board.mjs: `MARKER_PX`, `foldMarkerText`, `foldMarkerBox`). Pure: what
//  the marker says, where its words start and the box an eraser has to cross.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOutline {
  /// The marker's letters, board points, as the web board draws them.
  public static let markerPoints: CGFloat = 14
  /// How far past the header's last stroke the marker's words start.
  public static let markerGap: CGFloat = 14

  public static func markerText(lines: Int) -> String {
    "▸ \(lines) " + (lines == 1 ? "line folded" : "lines folded")
  }

  /// A folded header's marker: its words, where they start (`origin`, the baseline's left end) and the box an eraser
  /// has to cross, the web board's box.
  public struct Marker: Equatable, Sendable {
    public var header: String
    public var text: String
    public var origin: CGPoint
    public var box: CGRect
  }

  /// The markers of the folded headers that show (a fold folded away inside another's shows none).
  public var markers: [Marker] {
    headers.compactMap { header in
      guard isFolded(header), shows(header), let hb = box(header), let lines = header.fold?.lines else { return nil }
      let text = Self.markerText(lines: lines)
      let cy = hb.midY
      let right = hb.maxX + 18 + CGFloat(text.count) * Self.markerPoints * 0.55
      return Marker(
        header: header.id, text: text, origin: CGPoint(x: hb.maxX + Self.markerGap, y: cy + 5),
        box: CGRect(x: hb.maxX + 10, y: cy - 12, width: right - (hb.maxX + 10), height: 20))
    }
  }
}
