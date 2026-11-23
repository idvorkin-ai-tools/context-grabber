//  A pulled log's pen touches judged again on the Mac (spec 2026-11-01-whiteboard-design.md, *A pen touch's path is in
//  the log, and a pulled log replays on the Mac*; story 1105, bead context-grabber-y544). The log's lines with a path
//  (`BoardTouchPath`) become cases: a scratch-out's zigzag, a shape snap's stroke, a margin hold's stroke, and a pen
//  touch's own path. Each case carries what the iPad decided and what the board's own rules decide for the same points
//  here, so a gesture bug is settled against Igor's real stroke, and a fixture of them holds the verdicts
//  (`just touch-fixture`, docs/TESTING.md).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardTouchReplay {
  /// Which line a case came from, and so which rule judges it.
  public enum Kind: String, Codable, Sendable {
    /// `whiteboard` scratch: the zigzag's own stroke, as the scratch-out read it.
    case scratch
    /// `whiteboard` shape_snap or shape_snap_none: the held stroke the snap read.
    case snap
    /// `board_margin` hold_stroke: the Pencil's stroke from the margin.
    case marginHold = "margin_hold"
    /// `board_touch` path: the touch itself, as the board's touch hooks saw it.
    case touch
  }

  /// What the rules say of a path. Only what applies to the case's kind is set.
  public struct Verdict: Codable, Equatable, Sendable {
    /// The scratch-out's shape and speed: its reason (short, small, few turns, short sweeps, marches along, slow), or
    /// zigzag, or wanders (a scribble that drifts along the word: it takes only ink under it). Whether ink is under it
    /// isn't in the path, so no ink and beside ink are zigzag or wanders here.
    public var scratch: String?
    public var reversals: Int?
    /// A touch held still at its lift, which asks for a snap.
    public var held: Bool?
    /// The clean shape the stroke snaps to (line, rectangle, ellipse), or none.
    public var snap: String?
    /// A Pencil stroke from the margin: hold, moved or too_short.
    public var margin: String?

    public init(
      scratch: String? = nil, reversals: Int? = nil, held: Bool? = nil, snap: String? = nil, margin: String? = nil
    ) {
      self.scratch = scratch
      self.reversals = reversals
      self.held = held
      self.snap = snap
      self.margin = margin
    }
  }

  public struct Case: Codable, Equatable, Sendable {
    public var name: String
    public var kind: Kind
    public var board: String?
    /// The line's `t`: milliseconds into its launch.
    public var t: Int?
    public var touchType: String?
    public var pickerTool: String?
    /// ended, or cancelled when the system called the touch off.
    public var phase: String?
    /// The line's own fields, the path left out: what the iPad decided.
    public var phone: [String: String]?
    /// What the rules say on the Mac now, as the fixture was written.
    public var host: Verdict
    /// What they must say: `host` as written, edited to what Igor meant when the case is a bug.
    public var expect: Verdict
    /// The path, as `BoardTouchPath.encode` wrote it.
    public var path: String

    enum CodingKeys: String, CodingKey {
      case name, kind, board, t, phase, phone, host, expect, path
      case touchType = "touch_type"
      case pickerTool = "picker_tool"
    }
  }

  public struct Fixture: Codable, Equatable, Sendable {
    public var source: String
    public var cases: [Case]

    public init(source: String, cases: [Case]) {
      self.source = source
      self.cases = cases
    }
  }

  /// The rules on `samples`, as `kind` calls for. `touchType` matters to a touch: only the Pencil holds in the margin.
  public static func verdict(_ kind: Kind, _ samples: [BoardTouchPath.Sample], touchType: String? = nil) -> Verdict {
    let points = samples.map(\.point)
    switch kind {
    case .scratch:
      return scratch(samples)
    case .snap:
      return Verdict(snap: snap(points))
    case .marginHold:
      return Verdict(margin: margin(samples))
    case .touch:
      var verdict = Verdict(held: held(samples))
      if verdict.held == true { verdict.snap = snap(points) }
      if touchType == nil || touchType == "pencil" { verdict.margin = margin(samples) }
      if WhiteboardScratchOut.shape(points).reversals >= WhiteboardScratchOut.reversals {
        let scratch = scratch(samples)
        verdict.scratch = scratch.scratch
        verdict.reversals = scratch.reversals
      }
      return verdict
    }
  }

  /// Whether the iPad and the Mac agree on `c`; nil when the line carried nothing to compare (a touch's own path).
  public static func agrees(_ c: Case) -> Bool? {
    guard let phone = c.phone else { return nil }
    switch c.kind {
    case .scratch:
      guard let host = c.host.scratch else { return false }
      let took = phone["fired"] == "true" || ["no ink", "beside ink"].contains(phone["why"] ?? "")
      if took { return host == "zigzag" || host == "wanders" }
      if (phone["why"] ?? "").hasPrefix("wanders") { return host == "wanders" }
      return phone["why"] == host
    case .snap: return (phone["kind"] ?? "none") == c.host.snap
    case .marginHold: return phone["verdict"] == c.host.margin
    case .touch: return nil
    }
  }

  /// The cases in a session log's `text`, oldest first: every scratch, snap and margin hold line that carries a path,
  /// and the pen touches that are gestures (held at the lift, from the margin, or a zigzag's turns). `all` takes every
  /// pen touch, writing too; `board` keeps only that board's.
  public static func cases(fromLog text: String, board: String? = nil, all: Bool = false) -> [Case] {
    var cases: [Case] = []
    for line in text.split(separator: "\n") {
      guard let data = line.data(using: .utf8),
        let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
        let encoded = fields["path"] as? String, let samples = BoardTouchPath.decode(encoded), !samples.isEmpty,
        let kind = kind(type: fields["type"] as? String, action: fields["action"] as? String)
      else { continue }
      let lineBoard = fields["board"] as? String
      if let board, lineBoard != board { continue }
      let touchType = fields["touch_type"] as? String
      let host = verdict(kind, samples, touchType: touchType)
      if kind == .touch, !all, host.held != true, host.margin == nil, host.scratch == nil { continue }
      var phone: [String: String]?
      if kind != .touch {
        var said: [String: String] = [:]
        for (key, value) in fields where !["path", "type", "t", "board", "action"].contains(key) {
          said[key] = fieldText(value)
        }
        phone = said
      }
      let t = JSONNumber(fields["t"])?.intValue
      cases.append(
        Case(
          name: name(kind, t: t, board: lineBoard, phone: phone, host: host), kind: kind, board: lineBoard, t: t,
          touchType: touchType, pickerTool: fields["picker_tool"] as? String, phase: fields["phase"] as? String,
          phone: phone, host: host, expect: host, path: encoded))
    }
    return cases
  }

  static func kind(type: String?, action: String?) -> Kind? {
    switch (type, action) {
    case ("whiteboard", "scratch"): .scratch
    case ("whiteboard", "shape_snap"), ("whiteboard", "shape_snap_none"): .snap
    case ("board_margin", "hold_stroke"): .marginHold
    case ("board_touch", "path"): .touch
    default: nil
    }
  }

  private static func scratch(_ samples: [BoardTouchPath.Sample]) -> Verdict {
    let points = samples.map(\.point)
    let shape = WhiteboardScratchOut.shape(points)
    let ms = samples.last.map { $0.ms - (samples.first?.ms ?? 0) }
    if let why = shape.why { return Verdict(scratch: why, reversals: shape.reversals) }
    if !WhiteboardScratchOut.isZigzag(points, ms: ms.flatMap { $0 > 0 ? $0 : nil }) {
      return Verdict(scratch: "slow", reversals: shape.reversals)
    }
    return Verdict(scratch: shape.wanders ? "wanders" : "zigzag", reversals: shape.reversals)
  }

  private static func snap(_ points: [CGPoint]) -> String {
    BoardShapeSnap.clean(points).map { BoardShapeSnap.name($0.kind) } ?? "none"
  }

  /// The margin's verdict, nil for a stroke that didn't start there.
  private static func margin(_ samples: [BoardTouchPath.Sample]) -> String? {
    let verdict = BoardMarginHold.pencil(samples.map { (point: $0.point, time: $0.ms / 1000) })
    return verdict == .notInMargin ? nil : verdict.reason
  }

  /// The snap's hold, replayed from the touch's points: held still at the lift for `BoardShapeSnap.hold`.
  private static func held(_ samples: [BoardTouchPath.Sample]) -> Bool {
    guard let last = samples.last else { return false }
    var hold = BoardShapeSnap.Hold()
    for sample in samples.dropLast() { hold.moved(to: sample.point, at: sample.ms / 1000) }
    return hold.held(liftedAt: last.point, time: last.ms / 1000)
  }

  private static func name(_ kind: Kind, t: Int?, board: String?, phone: [String: String]?, host: Verdict) -> String {
    let said = phone.flatMap { $0["why"] ?? $0["kind"] ?? $0["verdict"] } ?? (kind == .scratch ? "fired" : nil)
    let mac = [host.scratch, host.snap, host.margin, host.held == true ? "held" : nil].compactMap { $0 }
    return [
      kind.rawValue, t.map { "t=\($0)" }, board.map { String($0.prefix(8)) }, said.map { "iPad: \($0)" },
      "Mac: \(mac.isEmpty ? "nothing" : mac.joined(separator: ", "))",
    ].compactMap { $0 }.joined(separator: " ")
  }

  private static func fieldText(_ value: Any) -> String {
    switch value {
    case let string as String: return string
    #if FOUNDATION_ESSENTIALS_ONLY
      case is Bool, is Int64, is Double:
        return (try? LiteJSON.data(value, fragmentsAllowed: true)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    #else
      case let number as NSNumber:
        // JSONSerialization hands back NSNumber for both 1 and true; only a JSON boolean is a boolean.
        return JSONNumber.isBool(number) ? (number.boolValue ? "true" : "false") : number.stringValue
    #endif
    default:
      guard JSONSerialization.isValidJSONObject(value),
        let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
      else { return String(describing: value) }
      return String(decoding: data, as: UTF8.self)
    }
  }
}
