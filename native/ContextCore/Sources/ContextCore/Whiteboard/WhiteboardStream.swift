//  Claude's answer as it arrives (spec 2026-11-01-whiteboard-shapes-design.md, story 370): the Cockpit's
//  `POST /whiteboard/suggest` streams one stroke per line and a last `{"done": true, "ms": …}` when asked for NDJSON
//  (cockpit#85), and a Cockpit that doesn't still answers with one JSON. The caller reads the body a byte at a time.

import Foundation

public struct WhiteboardStream: Sendable {
  /// False for anything but a 200 in NDJSON: the body is kept whole and read as one answer at the end.
  public let streaming: Bool
  /// The marks that have arrived.
  public private(set) var shapes: [WhiteboardTurn.Shape] = []
  /// The last line came: nothing more is on its way.
  public private(set) var done = false
  private let status: Int?
  private var buffer = Data()
  /// What a line said went wrong, for when no mark arrives.
  private var reason: String?

  /// `status` is nil when no response came, which reads as a failure in `answer`.
  public init(status: Int?, contentType: String?) {
    self.status = status
    streaming = status == 200 && contentType?.lowercased().contains("ndjson") == true
  }

  /// One byte of the body: the mark, when this byte ends a line that holds one.
  public mutating func take(_ byte: UInt8) -> WhiteboardTurn.Shape? {
    guard streaming, byte == UInt8(ascii: "\n") else {
      buffer.append(byte)
      return nil
    }
    return endLine()
  }

  /// The body ended cleanly: a last line with no newline after it still counts.
  public mutating func finish() -> WhiteboardTurn.Shape? {
    streaming ? endLine() : nil
  }

  /// A line that can't be read or isn't known is skipped: half a line, a kind this build doesn't draw, a blank.
  private mutating func endLine() -> WhiteboardTurn.Shape? {
    defer { buffer.removeAll(keepingCapacity: true) }
    guard !done, let json = try? JSONSerialization.jsonObject(with: buffer) as? [String: Any] else { return nil }
    if let error = json["error"] as? String { reason = error }
    if json["done"] as? Bool == true {
      done = true
      return nil
    }
    guard let shape = WhiteboardTurn.shapeJSON(stroke: json).flatMap(WhiteboardTurn.shape) else { return nil }
    shapes.append(shape)
    return shape
  }

  /// How the turn went, given what stopped the reading, if anything. Once a mark has arrived, nothing counts as failure.
  public func answer(error: String? = nil) -> WhiteboardTurn.Answer {
    guard streaming else {
      return WhiteboardTurn.answer(status: error == nil ? status : nil, body: buffer, error: error)
    }
    if !shapes.isEmpty || (done && reason == nil) { return .shapes(shapes, say: "", thread: nil) }
    return .away(reason: error ?? reason ?? "the answer ended early")
  }
}
