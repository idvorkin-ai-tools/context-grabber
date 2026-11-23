//  Whether two boxes overlap, the same on every platform the board's rules run on (spec
//  2026-11-22-board-rules-on-the-web-design.md, Precision). Apple's `CGRect.intersects` says boxes that only share an
//  edge or a corner do not meet, where swift-corelibs-foundation (Linux, and the WebAssembly build the Cockpit runs)
//  says they do, so the board's rules ask this instead. It answers as CoreGraphics does (checked on the Mac,
//  2026-11-23): an edge or a corner shared is no overlap, any area is, and a box with no width inside another meets it.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension CGRect {
  /// Strictly inside each other's span on both axes: `intersects` as Apple answers it, on every platform.
  func overlaps(_ other: CGRect) -> Bool {
    guard !isNull, !other.isNull else { return false }
    let a = standardized
    let b = other.standardized
    return a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
  }
}
