//  Story 1036, #1001: every picture of the board (Larry's turn, Send, Claude's turn) labels each open header "▾ header"
//  in 14-point grey letters 14 points past its line, where the board puts a fold's marker. The strokes Larry is sent
//  carry no headers, so the picture is where he learns them; a bare ▾ in the margin sat on the # it marked or fell
//  outside the picture. A board with a fold showing is drawn by `shot` (WhiteboardFoldPicture), which labels them too.

import ContextCore
import UIKit

extension WhiteboardModel {
  /// Each open header's "▾ header", drawn over the picture of `rect` (board points) in the current context,
  /// whose origin is the rect's top left.
  func drawFoldMarkers(in rect: CGRect) {
    guard !headers.isEmpty else { return }
    let font = UIFont.systemFont(ofSize: BoardOutline.markerPoints)
    let words: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(rgb: 0x999999)]
    for marker in outline().headerLabels where marker.box.intersects(rect) {
      // `draw(at:)` takes the text's top left; the web board's origin is its baseline.
      let at = CGPoint(x: marker.origin.x - rect.minX, y: marker.origin.y - font.ascender - rect.minY)
      (marker.text as NSString).draw(at: at, withAttributes: words)
    }
  }

  /// The open headers' labels' boxes, which a picture of the board takes in with the ink (#1001): none without headers.
  /// With a fold showing, the opened picture's, an open sub-header inside a folded section too (context-grabber-e91y).
  func pictureLabelBoxes() -> [CGRect] {
    headers.isEmpty ? [] : outline().pictureLabelBoxes
  }
}
