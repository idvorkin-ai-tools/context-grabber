//  Ink side by side (story 1209, bead context-grabber-vabk; spec docs/superpowers/specs/2026-11-22-ink-side-by-side-design.md):
//  one half's pen-down-to-next-frame times, the readout in its corner, and the web half's probe script.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

/// One half's samples: the time from a pen touching down to the start of the next frame, in milliseconds.
public struct InkLatency: Equatable, Sendable {
  /// Which half: the app's own PencilKit ink, or the web board in a web view.
  public enum Side: String, Sendable {
    case native
    case web
  }

  /// A sample outside this range is a fault in the measuring, not a stroke (spec, *What the number means*).
  public static let validRange: ClosedRange<Double> = 0...1000

  /// What `add` did with a sample, for the log.
  public enum Outcome: Equatable, Sendable {
    case kept
    case dropped
  }

  public let side: Side
  public private(set) var samples: [Double] = []
  public private(set) var dropped = 0

  public init(side: Side) { self.side = side }

  public var last: Double? { samples.last }
  public var count: Int { samples.count }

  /// The middle sample (the mean of the two middle ones for an even count), nil before the first.
  public var median: Double? {
    guard !samples.isEmpty else { return nil }
    let sorted = samples.sorted()
    let mid = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
  }

  @discardableResult
  public mutating func add(_ ms: Double) -> Outcome {
    guard ms.isFinite, Self.validRange.contains(ms) else {
      dropped += 1
      return .dropped
    }
    samples.append(ms)
    return .kept
  }

  /// The corner's words: "Draw to measure", then "last 18 ms · median 21 ms · 12 strokes".
  public var readout: String {
    guard let last, let median else { return "Draw to measure" }
    let noun = count == 1 ? "stroke" : "strokes"
    return "last \(Self.ms(last)) ms · median \(Self.ms(median)) ms · \(count) \(noun)"
  }

  /// The session log's fields for one sample (`ink_side_by_side`).
  public func logFields(ms: Double, outcome: Outcome) -> [String: Any] {
    var fields: [String: Any] = [
      "side": side.rawValue, "ms": Self.rounded(ms), "kept": outcome == .kept, "n": count, "dropped": dropped,
    ]
    if let median { fields["median"] = Self.rounded(median) }
    return fields
  }

  static func ms(_ value: Double) -> String { String(Int(value.rounded())) }
  static func rounded(_ value: Double) -> Double { value.isFinite ? (value * 10).rounded() / 10 : -1 }

  /// The name the web half's probe posts to.
  public static let messageHandler = "inkLatency"

  /// Injected into the web board at document start. It never changes the page: it listens on the window in the
  /// capture phase, before the page's own handlers can stop the event, takes the pointer event's own timestamp,
  /// and posts the time to the first animation frame after it. Both times are on the page's performance clock.
  /// A pen-down on the page's own controls is not a stroke, so it is not timed.
  public static let webProbeScript = """
    (() => {
      if (window.__inkLatencyProbe) return;
      window.__inkLatencyProbe = true;
      addEventListener("pointerdown", (e) => {
        const t = e.target;
        if (t && t.closest && t.closest("button, a, input, select, textarea, label, [role=button], [role=menuitem]")) return;
        const down = e.timeStamp;
        requestAnimationFrame(() => {
          const ms = performance.now() - down;
          try {
            window.webkit.messageHandlers.\(messageHandler).postMessage({ ms: ms, pointer: e.pointerType });
          } catch (_) {}
        });
      }, { capture: true, passive: true });
    })();
    """

  /// The web board's address on its scratch board, from the Cockpit's base address.
  public static func webBoardURL(cockpit: String) -> URL? {
    guard var parts = URLComponents(string: cockpit) else { return nil }
    let base = parts.path.hasSuffix("/") ? String(parts.path.dropLast()) : parts.path
    parts.path = base + "/ink"
    parts.queryItems = [URLQueryItem(name: "b", value: "scratch")]
    return parts.url
  }
}
