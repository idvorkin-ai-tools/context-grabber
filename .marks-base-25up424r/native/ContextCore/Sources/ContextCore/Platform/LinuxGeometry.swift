//  Linux only (just test-linux): the CoreGraphics values the board's geometry uses that Linux Foundation lacks, a vector
//  and an affine transform. Foundation there has CGFloat, CGPoint, CGSize and CGRect; on Apple platforms CoreGraphics
//  has these, so none of this is built.

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

#if !canImport(CoreGraphics)
  /// Linux only: CoreGraphics' affine transform, as much of it as ContextCore and its tests use: a pen's width under a
  /// lasso's scale, and the move of old ink onto the pages. Same fields and the same arithmetic as Apple's.
  public struct CGAffineTransform: Equatable, Sendable {
    public var a, b, c, d, tx, ty: CGFloat

    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
      (self.a, self.b, self.c, self.d, self.tx, self.ty) = (a, b, c, d, tx, ty)
    }

    public init(translationX tx: CGFloat, y ty: CGFloat) { self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty) }
    public init(scaleX sx: CGFloat, y sy: CGFloat) { self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0) }

    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
  }

  extension CGPoint {
    public func applying(_ t: CGAffineTransform) -> CGPoint {
      CGPoint(x: t.a * x + t.c * y + t.tx, y: t.b * x + t.d * y + t.ty)
    }
  }

  extension CGRect {
    /// As on Apple: the smallest rectangle holding the transformed corners.
    public func applying(_ t: CGAffineTransform) -> CGRect {
      let corners = [
        CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: minX, y: maxY), CGPoint(x: maxX, y: maxY),
      ].map { $0.applying(t) }
      let xs = corners.map(\.x)
      let ys = corners.map(\.y)
      let x = xs.reduce(xs[0], min)
      let y = ys.reduce(ys[0], min)
      return CGRect(x: x, y: y, width: xs.reduce(xs[0], max) - x, height: ys.reduce(ys[0], max) - y)
    }
  }
#endif
