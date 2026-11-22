//  context-grabber-ikya: a kept text of Larry's showed in his purple only up to one vertical edge, the rest blank or black,
//  now and then on the iPad simulator; once the other way round, the part left of the edge black. PaperKit held every
//  stroke purple: it drew one tile of the mark wrong or not at all. `paper_ink_look` counts any pixel unlike the paper,
//  so a mark partly drawn passed for drawn. Here the kept strokes' own colour is measured where they are: a mark whose
//  colour spans less of the spot than the same strokes drawn alone would, or that has turned dark where nothing dark was
//  before the keep, is drawn again as a missed one is (story 650).

import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// What a picture of a spot holds, sorted against the paper: pixels near the ink's colour, near black, the rest, and how
  /// wide and tall the ink's colour spans.
  struct KeptColours {
    var ink = 0
    var dark = 0
    var other = 0
    var inkWidth = 0
    var inkHeight = 0
    /// Every pixel unlike the paper, whatever its colour: how wide and tall the strokes span.
    var allWidth = 0
    var allHeight = 0
    static let unread = KeptColours(ink: -1, dark: -1, other: -1)
  }

  /// A second after a keep: the kept strokes' inks as made, as held then and now, and the colours drawn where they are.
  /// Part of it missing or dark, in view, redraws and looks again, twice at most. `before`: the spot's dark pixels before
  /// the keep (ink of Igor's already there).
  func lookAtKeptInk(_ made: [PKStroke], why: String, attempt: Int = 0, before: Int? = nil) {
    guard !made.isEmpty else { return }
    let moments = Set(made.map { Self.keptMoment($0) })
    let box = PKDrawing(strokes: made).bounds
    let darkBefore = before ?? max(drawnColours(in: keptSpot(box), ink: [0, 0, 0]).dark, 0)
    let madeInks = Self.inkKinds(made)
    let heldNow = Self.inkKinds(heldStrokes(at: moments))
    let want = Self.inkRGB(made[0].ink.color)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self else { return }
      let spot = self.keptSpot(box)
      let inView = self.view.bounds.contains(spot)
      let heldLater = self.heldStrokes(at: moments)
      let drawn = self.drawnColours(in: spot, ink: want)
      let expected = heldLater.isEmpty ? KeptColours() : self.expectedColours(made, box: box, ink: want)
      let part = Self.partMissing(drawn: drawn, expected: expected, darkBefore: darkBefore, ink: want)
      let missing = inView && part != nil
      self.log.event(
        "whiteboard",
        [
          "action": "paper_kept_ink", "why": why, "board": self.model.board.id, "strokes": made.count,
          "inks_made": madeInks, "inks_held": heldNow, "inks_held_later": Self.inkKinds(heldLater),
          "ink": self.rect(box), "spot": self.rect(spot), "in_view": inView, "ink_px": drawn.ink,
          "dark_px": drawn.dark, "dark_before": darkBefore, "other_px": drawn.other,
          "ink_span": [drawn.inkWidth, drawn.inkHeight],
          "expected_px": expected.ink, "expected_span": [expected.allWidth, expected.allHeight], "attempt": attempt,
          "missing": part ?? "",
        ])
      guard missing, attempt < 2, self.touchesDown == 0 else { return }
      // The view's nudge (`redrawSoon`, #906) left such a tile as it was, both tries, on the iPad simulator, and so did
      // setting the same markup again or marking every view to draw again. The first try takes the mark out of the markup
      // and puts it back a moment later; the second scrolls the view a screen away and back.
      let how = attempt == 0 ? "readd" : "scroll"
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_heal", "why": "kept_\(part ?? "")", "board": self.model.board.id, "attempt": attempt + 1,
          "how": how,
        ])
      if attempt == 0 {
        await self.readd(moments)
      } else {
        let place = self.paper.contentVisibleFrame
        self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: place.height)
        try? await Task.sleep(for: .seconds(0.1))
        if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
      }
      self.lookAtKeptInk(made, why: why, attempt: attempt + 1, before: darkBefore)
    }
  }

  /// Why a kept mark looks only partly drawn, or nil when it looks whole: **cut** when its colour spans under three
  /// quarters of what the same strokes span drawn alone (a tile left empty or drawn in another colour), **dark** when the
  /// spot has dark pixels the keep added and the ink isn't dark itself (a tile drawn black). Nothing is judged when the
  /// strokes drawn alone show none of their colour (a pen too thin to read).
  static func partMissing(drawn: KeptColours, expected: KeptColours, darkBefore: Int, ink: [Int]) -> String? {
    guard drawn.ink >= 0, expected.ink > 0, expected.allWidth > 0, expected.allHeight > 0 else { return nil }
    if drawn.inkWidth * 4 < expected.allWidth * 3 || drawn.inkHeight * 4 < expected.allHeight * 3 { return "cut" }
    let inkIsDark = ink.allSatisfy { $0 < 80 }
    if !inkIsDark, drawn.dark - darkBefore > max(20, drawn.ink / 10) { return "dark" }
    return nil
  }

  /// The markup set without the strokes made at `moments`, and a moment later with them again, as it was: their ids kept.
  private func readd(_ moments: Set<Int64>) async {
    guard let markup = paper.markup else { return }
    var without = markup
    for stroke in markup.subelements.strokes where moments.contains(Self.keptMoment(stroke)) {
      _ = without.subelements.removeElement(for: stroke.elementID)
    }
    guard without.subelements.count < markup.subelements.count else { return }
    setMarkup(without)
    try? await Task.sleep(for: .seconds(0.1))
    setMarkup(markup)
  }

  /// Where `box` (board points) is in this view's own points.
  private func keptSpot(_ box: CGRect) -> CGRect {
    let corner = lines.convert(lines.spot(of: box.origin), to: view)
    let scale = screenScale
    return CGRect(x: corner.x, y: corner.y, width: box.width * scale, height: box.height * scale)
  }

  /// The strokes PaperKit holds that were made at one of `moments` (a kept mark's strokes share their moment).
  private func heldStrokes(at moments: Set<Int64>) -> [PKStroke] {
    guard let markup = paper.markup else { return [] }
    return markup.inkDrawing.strokes.filter { moments.contains(Self.keptMoment($0)) }
  }

  private static func keptMoment(_ stroke: PKStroke) -> Int64 {
    Int64((stroke.path.creationDate.timeIntervalSince1970 * 1000).rounded())
  }

  /// Each ink kind and colour among `strokes`, with how many strokes have it: `com.apple.ink.pen #ba39e6 x13`.
  static func inkKinds(_ strokes: [PKStroke]) -> [String] {
    var counts: [String: Int] = [:]
    for stroke in strokes {
      let rgb = inkRGB(stroke.ink.color)
      let hex = String(format: "#%02x%02x%02x", rgb[0], rgb[1], rgb[2])
      counts["\(stroke.ink.inkType.rawValue) \(hex)", default: 0] += 1
    }
    return counts.keys.sorted().map { "\($0) x\(counts[$0] ?? 0)" }
  }

  private static func inkRGB(_ color: UIColor) -> [Int] {
    var (r, g, b): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: nil)
    return [r, g, b].map { Int(($0 * 255).rounded()) }
  }

  /// The view's own picture at `spot`, sorted. Unread when none of it is in the view.
  private func drawnColours(in spot: CGRect, ink: [Int]) -> KeptColours {
    let box = spot.intersection(view.bounds)
    guard !box.isNull, !box.isEmpty else { return .unread }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let picture = UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
      let whole = CGRect(origin: CGPoint(x: -box.minX, y: -box.minY), size: view.bounds.size)
      view.drawHierarchy(in: whole, afterScreenUpdates: false)
    }
    return picture.cgImage.flatMap { sortedColours($0, ink: ink) } ?? .unread
  }

  /// The kept strokes alone drawn on the paper at the view's scale, sorted as the view is: what they show when every one
  /// of them is drawn. Empty when it can't be drawn.
  private func expectedColours(_ strokes: [PKStroke], box: CGRect, ink: [Int]) -> KeptColours {
    let scale = screenScale
    let size = CGSize(width: box.width * scale, height: box.height * scale)
    guard size.width >= 1, size.height >= 1 else { return KeptColours() }
    var inkImage: UIImage?
    traitCollection.performAsCurrent { inkImage = PKDrawing(strokes: strokes).image(from: box, scale: scale) }
    guard let inkImage else { return KeptColours() }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let paperFill = paperColor.resolvedColor(with: traitCollection)
    let picture = UIGraphicsImageRenderer(size: size, format: format).image { context in
      paperFill.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      inkImage.draw(in: CGRect(origin: .zero, size: size))
    }
    return picture.cgImage.flatMap { sortedColours($0, ink: ink) } ?? KeptColours()
  }

  /// A picture's pixels unlike the paper, sorted: near `ink`, near black, the rest; and the spans.
  private func sortedColours(_ cg: CGImage, ink: [Int]) -> KeptColours? {
    let paperRGB = Self.inkRGB(paperColor.resolvedColor(with: traitCollection))
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
    guard drawn else { return nil }
    var out = KeptColours()
    var inkX = (w, -1)
    var inkY = (h, -1)
    var allX = (w, -1)
    var allY = (h, -1)
    for y in 0..<h {
      for x in 0..<w {
        let i = (y * w + x) * 4
        let px = [Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2])]
        guard (0..<3).contains(where: { abs(px[$0] - paperRGB[$0]) > 40 }) else { continue }
        allX = (min(allX.0, x), max(allX.1, x))
        allY = (min(allY.0, y), max(allY.1, y))
        if (0..<3).allSatisfy({ abs(px[$0] - ink[$0]) <= 50 }) {
          out.ink += 1
          inkX = (min(inkX.0, x), max(inkX.1, x))
          inkY = (min(inkY.0, y), max(inkY.1, y))
        } else if px.allSatisfy({ $0 < 80 }) {
          out.dark += 1
        } else {
          out.other += 1
        }
      }
    }
    out.inkWidth = max(inkX.1 - inkX.0 + 1, 0)
    out.inkHeight = max(inkY.1 - inkY.0 + 1, 0)
    out.allWidth = max(allX.1 - allX.0 + 1, 0)
    out.allHeight = max(allY.1 - allY.0 + 1, 0)
    return out
  }
}
