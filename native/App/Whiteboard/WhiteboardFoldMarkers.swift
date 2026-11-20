//  Story 900: a folded header's "▸ N lines folded" in every picture of the board (Larry's turn, Send, Claude's turn),
//  in the web board's words and place: 14-point grey letters starting 14 points past the header's row, on a baseline 5
//  below its middle (the Cockpit's assets/ink/ink.html, `data-fold`). Larry reads a folded board as a folded one.
//  Story 1016: an open header's grey ▾ in the margin too, so Larry sees which lines the board takes for headers.

import ContextCore
import UIKit

extension WhiteboardModel {
  /// The markers of the folds showing, drawn over the picture of `rect` (board points) in the current context, whose
  /// origin is the rect's top left.
  func drawFoldMarkers(in rect: CGRect) {
    guard !headers.isEmpty else { return }
    let font = UIFont.systemFont(ofSize: BoardOutline.markerPoints)
    let words: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(rgb: 0x999999)]
    let outline = outline()
    // Story 1016: the grey ▾ beside each open header, in the margin where the board shows it.
    let open = "▾" as NSString
    let size = open.size(withAttributes: words)
    for mark in outline.openHeaderMarks where mark.y >= rect.minY - size.height && mark.y <= rect.maxY + size.height {
      let at = CGPoint(x: BoardMargin.width / 2 - size.width / 2 - rect.minX, y: mark.y - size.height / 2 - rect.minY)
      open.draw(at: at, withAttributes: words)
    }
    for marker in outline.markers where marker.box.intersects(rect) {
      // `draw(at:)` takes the text's top left; the web board's origin is its baseline.
      let at = CGPoint(x: marker.origin.x - rect.minX, y: marker.origin.y - font.ascender - rect.minY)
      (marker.text as NSString).draw(at: at, withAttributes: words)
    }
  }
}
