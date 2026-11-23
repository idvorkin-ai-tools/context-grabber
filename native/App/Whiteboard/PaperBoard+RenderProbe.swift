//  A board on paper: whether the view's own picture shows the ink it holds, and the heal when it doesn't. Moved from
//  PaperBoard.swift as it was (context-grabber-fz4x).

import UIKit

extension PaperBoardController {
  /// A second after ink is kept or pasted or the sheet changes under it, whether the view's own picture has it. 0 with the
  /// ink in view is the ink missing, and the view redraws and looks again, twice at most, each try moving the view further
  /// (#906: a paste on a centred iPad page went unseen about 1 in 6 on the simulator, and a missed tile the first redraw
  /// leaves empty was never drawn after). `paper_ink_heal` says a try was made; the look after it, whether it drew. Ink
  /// gone from the board by then (`held` false) is not missing and is never healed (context-grabber-2jw).
  func lookForInk(_ ink: CGRect, why: String, attempt: Int = 0) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, let markup = self.paper.markup else { return }
      let corner = self.lines.convert(self.lines.spot(of: ink.origin), to: self.view)
      let scale = self.screenScale
      let spot = CGRect(x: corner.x, y: corner.y, width: ink.width * scale, height: ink.height * scale)
      let inView = self.view.bounds.contains(spot)
      let shown = self.shownPixels(in: spot)
      // context-grabber-2jw: an undo, a delete or a clear inside the second takes the ink away, and its spot reads empty
      // for that reason, not a missed tile. Only ink still held there can be missing.
      let held = markup.strokeFrames.values.contains { $0.intersects(ink.insetBy(dx: -1, dy: -1)) }
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_look", "why": why, "board": self.model.board.id, "ink": self.rect(ink),
          "spot": self.rect(spot), "in_view": inView, "strokes": markup.subelements.strokes.count,
          "visible": self.rect(self.paper.contentVisibleFrame), "shown_px": shown, "attempt": attempt, "held": held,
        ])
      guard held, inView, shown == 0, !ink.isEmpty, attempt < 2, self.touchesDown == 0 else { return }
      let step: CGFloat = attempt == 0 ? 8 : 32
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_heal", "why": why, "board": self.model.board.id, "attempt": attempt + 1,
          "step": Double(step),
        ])
      self.redrawSoon(step: step)
      self.lookForInk(ink, why: why, attempt: attempt + 1)
    }
  }

  /// Pixels unlike the paper in this view's own picture of itself, in a part of it.
  private func shownPixels(in spot: CGRect) -> Int {
    let box = spot.intersection(view.bounds)
    guard !box.isNull, !box.isEmpty else { return -1 }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let picture = UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
      let whole = CGRect(origin: CGPoint(x: -box.minX, y: -box.minY), size: view.bounds.size)
      view.drawHierarchy(in: whole, afterScreenUpdates: false)
    }
    guard let cg = picture.cgImage else { return -1 }
    var (r, g, b): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    paperColor.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: nil)
    let paper = [Int(r * 255), Int(g * 255), Int(b * 255)]
    let (w, h) = (cg.width, cg.height)
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    guard drawn else { return -1 }
    return stride(from: 0, to: bytes.count, by: 4).filter { i in
      (0..<3).contains { abs(Int(bytes[i + $0]) - paper[$0]) > 40 }
    }.count
  }
}
