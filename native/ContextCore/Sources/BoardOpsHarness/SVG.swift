//  The picture as an SVG (#943): where there is no CoreGraphics to make a PNG, as on Larry's Linux box. The same marks,
//  colours and words as the PNG; a viewer's monospace font stands in for Menlo.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension Sketch {
  func svg(scale: CGFloat) -> String {
    let n = { (v: CGFloat) in String(format: "%.1f", Double(v)) }
    let width = (region.width * scale).rounded(.up)
    let height = ((region.height + header) * scale).rounded(.up)
    let paint = { (c: RGBA) in "\(c.hex)\" stroke-opacity=\"\(c.a)" }
    let fill = { (c: RGBA) in "\(c.hex)\" fill-opacity=\"\(c.a)" }
    var out = [
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(n(width))\" height=\"\(n(height))\""
        + " viewBox=\"0 0 \(n(region.width)) \(n(region.height + header))\">",
      "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>",
    ]
    for (i, note) in notes.enumerated() {
      out.append(
        "<text x=\"8\" y=\"\(16 + i * 16)\" font-family=\"Menlo, monospace\" font-size=\"\(i == 0 ? 12 : 11)\""
          + " fill=\"\(fill(Look.note))\">\(Self.escape(note))</text>")
    }
    let clip = "<clipPath id=\"board\"><rect x=\"\(n(region.minX))\" y=\"\(n(region.minY))\""
      + " width=\"\(n(region.width))\" height=\"\(n(region.height))\"/></clipPath>"
    out.append(clip)
    out.append(
      "<g transform=\"translate(\(n(-region.minX)) \(n(header - region.minY)))\" clip-path=\"url(#board)\""
        + " stroke-linecap=\"round\" stroke-linejoin=\"round\">")
    for mark in marks {
      switch mark {
      case .lines(let lines, let color, let width, let dash):
        let dashing = dash.isEmpty ? "" : " stroke-dasharray=\"\(dash.map(n).joined(separator: " "))\""
        for line in lines {
          let points = (line.count == 1 ? [line[0], line[0]] : line).map { "\(n($0.x)),\(n($0.y))" }
          out.append(
            "<polyline points=\"\(points.joined(separator: " "))\" fill=\"none\" stroke=\"\(paint(color))\""
              + " stroke-width=\"\(n(width))\"\(dashing)/>")
        }
      case .words(let words, let at, let color, let size):
        out.append(
          "<text x=\"\(n(at.x))\" y=\"\(n(at.y))\" font-family=\"Menlo, monospace\" font-size=\"\(n(size))\""
            + " fill=\"\(fill(color))\">\(Self.escape(words))</text>")
      case .dot(let at, let radius, let color):
        out.append("<circle cx=\"\(n(at.x))\" cy=\"\(n(at.y))\" r=\"\(n(radius))\" fill=\"\(fill(color))\"/>")
      }
    }
    out.append("</g>")
    out.append("</svg>")
    return out.joined(separator: "\n") + "\n"
  }

  static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
  }
}
