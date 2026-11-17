//  Story 900: a folded header's "▸ N lines folded" in every picture of the board (Larry's turn, Send, Claude's turn),
//  in the web board's words and place: 14-point grey letters starting 14 points past the header's row, on a baseline 5
//  below its middle (the Cockpit's assets/ink/ink.html, `data-fold`). Larry reads a folded board as a folded one.

import ContextCore
import UIKit

extension WhiteboardModel {
  /// The markers of the folds showing, drawn over the picture of `rect` (board points) in the current context, whose
  /// origin is the rect's top left.
  func drawFoldMarkers(in rect: CGRect) {
    guard headers.contains(where: { $0.fold != nil }) else { return }
    let font = UIFont.systemFont(ofSize: BoardOutline.markerPoints)
    let words: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(rgb: 0x999999)]
    for marker in outline().markers where marker.box.intersects(rect) {
      // `draw(at:)` takes the text's top left; the web board's origin is its baseline.
      let at = CGPoint(x: marker.origin.x - rect.minX, y: marker.origin.y - font.ascender - rect.minY)
      (marker.text as NSString).draw(at: at, withAttributes: words)
    }
  }
}
