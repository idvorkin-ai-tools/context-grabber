//  The picture as a PNG, on the Mac: CoreGraphics, Menlo for the words. Linux writes the SVG instead (#943).

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(CoreText)
  import CoreGraphics
  import CoreText
  import Foundation
  import ImageIO
  import UniformTypeIdentifiers

  extension RGBA {
    var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
  }

  extension Sketch {
    func png(scale: CGFloat, to path: String) throws {
      let width = Int((region.width * scale).rounded(.up))
      let height = Int(((region.height + header) * scale).rounded(.up))
      guard
        let ctx = CGContext(
          data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { throw Failure(description: "no bitmap \(width)x\(height)") }
      ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
      ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
      // Board points, y down, the region under the notes.
      ctx.translateBy(x: 0, y: CGFloat(height))
      ctx.scaleBy(x: scale, y: -scale)
      for (i, note) in notes.enumerated() {
        Self.say(note, at: CGPoint(x: 8, y: 16 + CGFloat(i) * 16), in: ctx, color: Look.note, size: i == 0 ? 12 : 11)
      }
      ctx.translateBy(x: -region.minX, y: header - region.minY)
      ctx.clip(to: region)
      ctx.setLineCap(.round)
      ctx.setLineJoin(.round)
      for mark in marks {
        switch mark {
        case .lines(let lines, let color, let width, let dash):
          ctx.setStrokeColor(color.cg)
          ctx.setLineWidth(width)
          ctx.setLineDash(phase: 0, lengths: dash)
          for line in lines {
            ctx.beginPath()
            ctx.move(to: line[0])
            if line.count == 1 { ctx.addLine(to: line[0]) }
            for point in line.dropFirst() { ctx.addLine(to: point) }
            ctx.strokePath()
          }
          ctx.setLineDash(phase: 0, lengths: [])
        case .words(let words, let at, let color, let size):
          Self.say(words, at: at, in: ctx, color: color, size: size)
        case .dot(let at, let radius, let color):
          ctx.setFillColor(color.cg)
          ctx.fillEllipse(in: CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2))
        }
      }
      guard let image = ctx.makeImage(),
        let out = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
      else { throw Failure(description: "can't write \(path)") }
      CGImageDestinationAddImage(out, image, nil)
      guard CGImageDestinationFinalize(out) else { throw Failure(description: "can't write \(path)") }
    }

    /// Words at `point` (their baseline's left end), in board points, on the flipped context.
    private static func say(_ words: String, at point: CGPoint, in ctx: CGContext, color: RGBA, size: CGFloat) {
      let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
      let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color.cg] as CFDictionary
      guard let text = CFAttributedStringCreate(nil, words as CFString, attributes) else { return }
      let line = CTLineCreateWithAttributedString(text)
      ctx.saveGState()
      ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      ctx.textPosition = point
      CTLineDraw(line, ctx)
      ctx.restoreGState()
    }
  }
#endif
