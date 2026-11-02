import XCTest

@testable import ContextCore

/// Story 378: every colour against the ink and the ghosts, in both modes, by WCAG contrast. A ghost is its author's
/// system colour at half strength over the paper, and orange at half strength is already faint on white (1.5:1), so
/// ghosts are held to Plain and not to a fixed number. Hue, which helps them, isn't counted.
final class BoardPaperTests: XCTestCase {
  private typealias RGB = (r: Double, g: Double, b: Double)

  private func rgb(_ hex: UInt32) -> RGB {
    (Double(hex >> 16 & 0xFF), Double(hex >> 8 & 0xFF), Double(hex & 0xFF))
  }

  private func luminance(_ c: RGB) -> Double {
    let linear = { (v: Double) -> Double in
      v / 255 <= 0.03928 ? v / 255 / 12.92 : pow((v / 255 + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  }

  private func contrast(_ a: RGB, _ b: RGB) -> Double {
    let (la, lb) = (luminance(a), luminance(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
  }

  private func ghost(_ color: UInt32, on paper: UInt32) -> Double {
    let (c, p) = (rgb(color), rgb(paper))
    return contrast((c.r / 2 + p.r / 2, c.g / 2 + p.g / 2, c.b / 2 + p.b / 2), p)
  }

  // UIColor.systemOrange and .systemBlue in each mode.
  private let ghostsLight: [UInt32] = [0xFF9500, 0x007AFF]
  private let ghostsDark: [UInt32] = [0xFF9F0A, 0x0A84FF]

  func testInkIsEasyToReadOnEveryColourInBothModes() {
    for paper in BoardPaper.allCases {
      XCTAssertGreaterThan(contrast((0, 0, 0), rgb(paper.light)), 7, "\(paper) light")
      XCTAssertGreaterThan(contrast((255, 255, 255), rgb(paper.dark)), 7, "\(paper) dark")
    }
  }

  func testGhostsAreNearlyAsVisibleAsOnPlain() {
    for paper in BoardPaper.allCases {
      for color in ghostsLight {
        XCTAssertGreaterThanOrEqual(
          ghost(color, on: paper.light), 0.9 * ghost(color, on: BoardPaper.plain.light), "\(paper) light")
      }
      for color in ghostsDark {
        XCTAssertGreaterThanOrEqual(
          ghost(color, on: paper.dark), 0.9 * ghost(color, on: BoardPaper.plain.dark), "\(paper) dark")
      }
    }
  }
}
