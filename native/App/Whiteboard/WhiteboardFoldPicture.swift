//  #1013 (Igor, 2026-11-20, W4 on PR #912: "the picture shows the whole section, flagged as folded"; story 900): every
//  picture of a folded board (Larry's turn, Send, Claude's turn) draws each folded section in full, in place, shaded
//  light grey across the page, with "folded" in the margin at its top and ▸ beside its header. The board on the iPad
//  stays folded: the picture is drawn from a copy with the folds open. `BoardOutline.foldPicture` decides it.

import ContextCore
import PencilKit
import UIKit

/// A picture of the board and where it sits on the board: `rect`, `scale` and the map back through the folds it draws
/// open (nil with none).
struct BoardShot {
  let image: UIImage
  let rect: CGRect
  let scale: CGFloat
  let folds: BoardFoldMap?
}

extension WhiteboardModel {
  static let foldShade = UIColor(rgb: 0xECECEC)

  /// Dark ink on white whatever the iPad's mode and the board's colour: what Larry and Claude see. `rect` and `scale`
  /// are the screen's; with folds showing, the shot's are the picture's, taller by what it opened.
  func shot(rect: CGRect, scale: CGFloat) -> BoardShot {
    guard let opened = headers.contains(where: { $0.fold != nil }) ? outline().foldPicture() : nil else {
      let image = render(drawing, rect: rect, scale: scale, over: { self.drawFoldMarkers(in: rect) })
      return BoardShot(image: image, rect: rect, scale: scale, folds: nil)
    }
    var strokes = drawing.strokes
    for (index, by) in opened.offsets where strokes.indices.contains(index) {
      strokes[index].transform = strokes[index].transform.concatenating(
        CGAffineTransform(translationX: by.dx, y: by.dy))
    }
    for index in opened.shown where strokes.indices.contains(index) {
      strokes[index].ink = WhiteboardInk.withAlpha(strokes[index].ink, 1, at: "fold")
    }
    let tall = opened.map.toPicture(rect)
    let fine = WhiteboardFrame.scale(for: tall, atMost: scale)
    let image = render(
      PKDrawing(strokes: strokes), rect: tall, scale: fine, under: { self.shade(opened, in: tall) },
      over: { self.drawMargin(opened, in: tall) })
    return BoardShot(image: image, rect: tall, scale: fine, folds: opened.map)
  }

  private func render(
    _ ink: PKDrawing, rect: CGRect, scale: CGFloat, under: () -> Void = {}, over: () -> Void
  ) -> UIImage {
    var drawn = UIImage()
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { drawn = ink.image(from: rect, scale: scale) }
    let format = UIGraphicsImageRendererFormat()
    format.scale = drawn.scale
    format.opaque = true
    return UIGraphicsImageRenderer(size: drawn.size, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: drawn.size))
      under()
      drawn.draw(at: .zero)
      over()
    }
  }

  /// The opened sections' shading, across the whole picture.
  private func shade(_ opened: BoardOutline.FoldPicture, in rect: CGRect) {
    Self.foldShade.setFill()
    for band in opened.bands where band.bottom > rect.minY && band.top < rect.maxY {
      UIRectFillUsingBlendMode(
        CGRect(x: 0, y: band.top - rect.minY, width: rect.width, height: band.bottom - band.top), .normal)
    }
  }

  /// The margin: ▸ beside each header folded on the board and "folded" at the top of each section the picture opened;
  /// and each open header labelled "▾ header" past its line, clear of its ink (story 1036, #1001).
  private func drawMargin(_ opened: BoardOutline.FoldPicture, in rect: CGRect) {
    let font = UIFont.systemFont(ofSize: BoardOutline.markerPoints)
    let words: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(rgb: 0x999999)]
    let inMargin = { (text: String, y: CGFloat, top: Bool) in
      let mark = text as NSString
      let size = mark.size(withAttributes: words)
      let at = CGPoint(
        x: BoardMargin.width / 2 - size.width / 2 - rect.minX, y: (top ? y + 2 : y - size.height / 2) - rect.minY)
      guard at.y + size.height >= 0, at.y <= rect.height else { return }
      mark.draw(at: at, withAttributes: words)
    }
    for label in opened.openLabels {
      // `draw(at:)` takes the text's top left; the label's origin is its baseline.
      let at = CGPoint(x: label.origin.x - rect.minX, y: label.origin.y - font.ascender - rect.minY)
      guard at.y + font.lineHeight >= 0, at.y <= rect.height else { continue }
      (label.text as NSString).draw(at: at, withAttributes: words)
    }
    for mark in opened.foldedMarks { inMargin("▸", mark.y, false) }
    for band in opened.bands { inMargin(BoardOutline.foldedTag, band.top, true) }
  }
}
