//  Linux only (just test-linux): the one CoreGraphics value the board's geometry uses that Linux Foundation lacks.
//  Foundation there has CGFloat, CGPoint, CGSize and CGRect; on Apple platforms CoreGraphics has this, so it is not built.

#if !canImport(CoreGraphics)
  import Foundation

  public struct CGVector: Equatable, Sendable {
    public var dx: CGFloat
    public var dy: CGFloat

    public init(dx: CGFloat, dy: CGFloat) {
      self.dx = dx
      self.dy = dy
    }

    public static let zero = CGVector(dx: 0, dy: 0)
  }
#endif
