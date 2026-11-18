//  A finger in the board's left margin (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry hears the margin, the
//  view and Undo*, story 849): how Igor will ask for room by hand. The margin is the column's left 64 points, as on the
//  web board (`MARGIN` in the Cockpit's assets/ink/board.mjs).

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardMargin {
  public static let width: CGFloat = 64
  /// Further than this, in board points, and a touch is a drag.
  public static let dragAfter: CGFloat = 10
  /// Longer than this, still, and a touch is a hold.
  public static let holdAfter: Double = 0.5

  public enum Gesture: String, Equatable, Codable, Sendable {
    case tap, hold
    case dragEnd = "drag_end"
  }

  /// What a lone finger did, from where it went down to where it came up, in board points; nil when it didn't start in
  /// the margin. `y` is where it went down, `dy` how far it went down the board.
  public static func gesture(from start: CGPoint, to end: CGPoint, seconds: Double) -> (
    Gesture, y: CGFloat, dy: CGFloat
  )? {
    guard start.x >= 0, start.x < width else { return nil }
    let dy = end.y - start.y
    if hypot(end.x - start.x, dy) >= dragAfter { return (.dragEnd, start.y, dy) }
    return (seconds >= holdAfter ? .hold : .tap, start.y, 0)
  }
}

/// `POST /whiteboard/events` on the Cockpit (story 846): events that can't wait for the next turn, a tap on one of
/// Larry's controls, with the board's revision and the last op_result.
public enum BoardEventsSend {
  public enum Answer: Equatable, Sendable {
    case taken
    /// No such route on this Cockpit yet: the events wait for the next turn.
    case notThere
    case away(reason: String)
  }

  public static let timeout: TimeInterval = 5

  public static func request(board: String, report: BoardTurnReport, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("events"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    var body = report.wire
    body["board"] = board
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
  }

  public static func answer(status: Int?, error: String? = nil) -> Answer {
    guard let status else { return .away(reason: error ?? "no answer") }
    if (200..<300).contains(status) { return .taken }
    if status == 404 || status == 405 { return .notThere }
    return .away(reason: "HTTP \(status)")
  }
}
