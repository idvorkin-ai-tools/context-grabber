//  The wasm build only (bead context-grabber-pt1e, story 1700): CGFloat, CGPoint, CGSize and CGRect, which Linux
//  Foundation carries and FoundationEssentials does not. The same fields, arithmetic and edge rules as Linux
//  Foundation's, which the wasm used before (a 32-bit target, where its CGFloat is a Float). LinuxGeometry.swift adds
//  the vector and the transform on top, as it does on Linux.

#if FOUNDATION_ESSENTIALS_ONLY
  #if arch(wasm32) || arch(i386) || arch(arm)
    public typealias CGFloat = Float
  #else
    public typealias CGFloat = Double
  #endif

  public struct CGPoint: Equatable, Hashable, Sendable, Codable {
    public var x: CGFloat
    public var y: CGFloat

    public init() { self.init(x: 0, y: 0) }
    public init(x: CGFloat, y: CGFloat) { (self.x, self.y) = (x, y) }
    public init(x: Double, y: Double) { self.init(x: CGFloat(x), y: CGFloat(y)) }
    public init(x: Int, y: Int) { self.init(x: CGFloat(x), y: CGFloat(y)) }

    public static let zero = CGPoint(x: 0, y: 0)

    public init(from decoder: Decoder) throws {
      var c = try decoder.unkeyedContainer()
      x = try c.decode(CGFloat.self)
      y = try c.decode(CGFloat.self)
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.unkeyedContainer()
      try c.encode(x)
      try c.encode(y)
    }
  }

  public struct CGSize: Equatable, Hashable, Sendable, Codable {
    public var width: CGFloat
    public var height: CGFloat

    public init() { self.init(width: 0, height: 0) }
    public init(width: CGFloat, height: CGFloat) { (self.width, self.height) = (width, height) }
    public init(width: Double, height: Double) { self.init(width: CGFloat(width), height: CGFloat(height)) }
    public init(width: Int, height: Int) { self.init(width: CGFloat(width), height: CGFloat(height)) }

    public static let zero = CGSize(width: 0, height: 0)

    public init(from decoder: Decoder) throws {
      var c = try decoder.unkeyedContainer()
      width = try c.decode(CGFloat.self)
      height = try c.decode(CGFloat.self)
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.unkeyedContainer()
      try c.encode(width)
      try c.encode(height)
    }
  }

  public struct CGRect: Equatable, Hashable, Sendable, Codable {
    public var origin: CGPoint
    public var size: CGSize

    public init() { self.init(origin: .zero, size: .zero) }
    public init(origin: CGPoint, size: CGSize) { (self.origin, self.size) = (origin, size) }
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
      self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
    public init(x: Double, y: Double, width: Double, height: Double) {
      self.init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
    public init(x: Int, y: Int, width: Int, height: Int) {
      self.init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }

    public static let zero = CGRect(x: 0, y: 0, width: 0, height: 0)
    public static let null = CGRect(x: CGFloat.infinity, y: CGFloat.infinity, width: 0, height: 0)
    public static let infinite = CGRect(
      x: -CGFloat.greatestFiniteMagnitude / 2, y: -CGFloat.greatestFiniteMagnitude / 2,
      width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

    public var width: CGFloat { abs(size.width) }
    public var height: CGFloat { abs(size.height) }
    public var minX: CGFloat { origin.x + min(size.width, 0) }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var maxX: CGFloat { origin.x + max(size.width, 0) }
    public var minY: CGFloat { origin.y + min(size.height, 0) }
    public var midY: CGFloat { origin.y + size.height / 2 }
    public var maxY: CGFloat { origin.y + max(size.height, 0) }
    public var isNull: Bool { origin.x == .infinity || origin.y == .infinity }
    public var isEmpty: Bool { isNull || size.width == 0 || size.height == 0 }
    public var isInfinite: Bool { self == .infinite }

    public var standardized: CGRect { isNull ? .null : CGRect(x: minX, y: minY, width: width, height: height) }

    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
      if isNull { return self }
      var rect = standardized
      rect.origin.x += dx
      rect.origin.y += dy
      rect.size.width -= 2 * dx
      rect.size.height -= 2 * dy
      return rect.size.width < 0 || rect.size.height < 0 ? .null : rect
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
      if isNull { return self }
      var rect = standardized
      rect.origin.x += dx
      rect.origin.y += dy
      return rect
    }

    public func union(_ r2: CGRect) -> CGRect {
      if isNull { return r2 }
      if r2.isNull { return self }
      let (a, b) = (standardized, r2.standardized)
      let x = min(a.minX, b.minX)
      let y = min(a.minY, b.minY)
      return CGRect(x: x, y: y, width: max(a.maxX, b.maxX) - x, height: max(a.maxY, b.maxY) - y)
    }

    public mutating func formUnion(_ r2: CGRect) { self = union(r2) }

    public func intersection(_ r2: CGRect) -> CGRect {
      if isNull || r2.isNull { return .null }
      let (a, b) = (standardized, r2.standardized)
      let (aH, aV, bH, bV) = (a.minX...a.maxX, a.minY...a.maxY, b.minX...b.maxX, b.minY...b.maxY)
      guard aH.overlaps(bH), aV.overlaps(bV) else { return .null }
      let h = aH.clamped(to: bH)
      let v = aV.clamped(to: bV)
      let width = h == aH ? a.width : h == bH ? b.width : h.upperBound - h.lowerBound
      let height = v == aV ? a.height : v == bV ? b.height : v.upperBound - v.lowerBound
      return CGRect(x: h.lowerBound, y: v.lowerBound, width: width, height: height)
    }

    public func intersects(_ r2: CGRect) -> Bool { !intersection(r2).isNull }

    public func contains(_ point: CGPoint) -> Bool {
      if isNull || isEmpty { return false }
      return (minX..<maxX).contains(point.x) && (minY..<maxY).contains(point.y)
    }

    public func contains(_ rect2: CGRect) -> Bool { union(rect2) == self && !isEmpty }

    public init(from decoder: Decoder) throws {
      var c = try decoder.unkeyedContainer()
      origin = try c.decode(CGPoint.self)
      size = try c.decode(CGSize.self)
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.unkeyedContainer()
      try c.encode(origin)
      try c.encode(size)
    }
  }
#endif
