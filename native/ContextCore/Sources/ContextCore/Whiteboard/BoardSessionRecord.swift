//  One writing session on a board, as the review reads it (spec 2026-11-23-board-interaction-review-design.md, *What a
//  session is, and what is recorded*; stories 1237–1262). JSONL: a header holding the board as the session began, then
//  one step per line. Both surfaces write this form, the iPad and the Cockpit's web board, and `BoardReview` reads it
//  the same wherever it runs. Geometry only: ink is ids, owners and boxes, never points or words. Pure: no disk, no
//  network, no clock.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardSessionRecord: Equatable, Sendable {
  /// This form's version: up when a field's meaning changes.
  public static let version = 1

  public struct Unreadable: Error, CustomStringConvertible, Equatable {
    public let description: String
  }

  /// A box in board points, `[x, y, width, height]` on the wire. Doubles everywhere, so the iPad and the 32-bit wasm
  /// read the same numbers.
  public struct Box: Equatable, Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
      self.x = x
      self.y = y
      self.w = w
      self.h = h
    }

    public var maxX: Double { x + w }
    public var maxY: Double { y + h }

    public init(from decoder: Decoder) throws {
      var c = try decoder.unkeyedContainer()
      self.init(
        try c.decode(Double.self), try c.decode(Double.self), try c.decode(Double.self), try c.decode(Double.self))
    }

    public func encode(to encoder: Encoder) throws {
      var c = encoder.unkeyedContainer()
      try c.encode(x)
      try c.encode(y)
      try c.encode(w)
      try c.encode(h)
    }
  }

  /// One unit of ink on the board: a stroke, or strokes that move whole (a kept reply's group). `n` counts its strokes.
  public struct Ink: Equatable, Sendable, Codable {
    public var id: String
    /// `igor`, `larry` or `claude`: whose it is.
    public var owner: String
    public var box: Box
    public var n: Int?
    /// A header's own line, which a fold folds under.
    public var header: Bool?

    public init(id: String, owner: String, box: Box, n: Int? = nil, header: Bool? = nil) {
      self.id = id
      self.owner = owner
      self.box = box
      self.n = n
      self.header = header
    }
  }

  /// A fold: the header and the ink it holds hidden. `folded` false is a header open now, `held` what its last fold hid.
  public struct Fold: Equatable, Sendable, Codable {
    public var header: String
    public var held: [String]
    public var folded: Bool?

    public init(header: String, held: [String], folded: Bool? = nil) {
      self.header = header
      self.held = held
      self.folded = folded
    }
  }

  /// What a surface can observe for the checks that need its eyes: `yes`, `approx`, or absent (not observed).
  public struct Observes: Equatable, Sendable, Codable {
    public var selection: String?
    public var pen: String?
    public var kept: String?

    public init(selection: String? = nil, pen: String? = nil, kept: String? = nil) {
      self.selection = selection
      self.pen = pen
      self.kept = kept
    }
  }

  public struct Header: Equatable, Sendable, Codable {
    public var record: Int
    public var board: String
    public var session: String
    /// `ipad` or `web`.
    public var surface: String
    public var build: String?
    public var observes: Observes?
    public var ink: [Ink]
    public var folds: [Fold]?
  }

  /// What a step was aimed at: the ink selected, dragged or chosen on, and where a drag began on it.
  public struct Aim: Equatable, Sendable, Codable {
    public var ids: [String]?
    /// `inside` (the selection's body), `knob` (a corner knob outside it), `handle` (a system handle, such as the
    /// handwriting reflow's), or absent.
    public var start: String?

    public init(ids: [String]? = nil, start: String? = nil) {
      self.ids = ids
      self.start = start
    }
  }

  /// One unit's change in a step: added (no `before`), removed (no `after`), moved or resized, hidden or shown.
  public struct Change: Equatable, Sendable, Codable {
    public var id: String
    public var owner: String?
    public var before: Box?
    public var after: Box?
    public var n: Int?
    public var header: Bool?
    /// Hidden (true) or shown (false) by this step; absent when it didn't change.
    public var hidden: Bool?

    public init(
      id: String, owner: String? = nil, before: Box? = nil, after: Box? = nil, n: Int? = nil, header: Bool? = nil,
      hidden: Bool? = nil
    ) {
      self.id = id
      self.owner = owner
      self.before = before
      self.after = after
      self.n = n
      self.header = header
      self.hidden = hidden
    }
  }

  /// Room a step asked for: everything at or below `cut` goes down `dy`.
  public struct Room: Equatable, Sendable, Codable {
    public var cut: Double
    public var dy: Double
  }

  /// A kept mark as the surface drew it, one look per redraw: its span against the span it should have, and how much
  /// of it drew in its own colour against drawn dark.
  public struct KeptLook: Equatable, Sendable, Codable {
    public var shown: [Double]
    public var expected: [Double]
    public var inkPx: Int?
    public var darkPx: Int?

    enum CodingKeys: String, CodingKey {
      case shown, expected
      case inkPx = "ink_px"
      case darkPx = "dark_px"
    }
  }

  /// What the surface saw that the ink can't say. Each field is absent when not observed.
  public struct Seen: Equatable, Sendable, Codable {
    /// After a selection was taken from him: whether it was held again.
    public var heldAfter: Bool?
    public var penBefore: String?
    public var penAfter: String?
    public var kept: [KeptLook]?
    /// After an Undo or Redo: whether the ink it changed drew whole, once the surface's redraws had their chance.
    public var drawnWhole: Bool?

    enum CodingKeys: String, CodingKey {
      case heldAfter = "held_after"
      case penBefore = "pen_before"
      case penAfter = "pen_after"
      case kept
      case drawnWhole = "drawn_whole"
    }
  }

  public struct Step: Equatable, Sendable, Codable {
    /// Unix milliseconds.
    public var t: Double
    /// `ink`, `erase`, `select`, `deselect`, `move`, `drop`, `paste`, `keep`, `text`, `late`, `ops`, `room`, `fold`,
    /// `unfold`, `apart`, `selection_lost`, `pen`, `undo`, `redo`, or another the surface names.
    public var kind: String
    /// `pencil`, `finger`, `menu`, `larry`, `claude`, `rule` or `system`.
    public var by: String
    /// The Undo stack's name for this step (`Move`, `Keep`), so an Undo can say which it took back.
    public var name: String?
    public var aim: Aim?
    public var changes: [Change]?
    public var room: Room?
    /// For `fold` and `unfold`: the header's fold after the step.
    public var fold: Fold?
    public var seen: Seen?

    public init(
      t: Double, kind: String, by: String, name: String? = nil, aim: Aim? = nil, changes: [Change]? = nil,
      room: Room? = nil, fold: Fold? = nil, seen: Seen? = nil
    ) {
      self.t = t
      self.kind = kind
      self.by = by
      self.name = name
      self.aim = aim
      self.changes = changes
      self.room = room
      self.fold = fold
      self.seen = seen
    }
  }

  public var header: Header
  public var steps: [Step]

  public init(header: Header, steps: [Step]) {
    self.header = header
    self.steps = steps
  }

  /// A record's JSONL: its header, then one step per line.
  public init(jsonl data: Data) throws {
    let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").filter {
      !$0.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\r" }
    }
    guard let first = lines.first else { throw Unreadable(description: "a record starts with its header") }
    let decoder = JSONDecoder()
    do {
      header = try decoder.decode(Header.self, from: Data(first.utf8))
    } catch {
      throw Unreadable(description: "the header could not be read: \(error)")
    }
    guard header.record == Self.version else {
      throw Unreadable(description: "record version \(header.record), this review reads \(Self.version)")
    }
    steps = try lines.dropFirst().enumerated().map { index, line in
      do {
        return try decoder.decode(Step.self, from: Data(line.utf8))
      } catch {
        throw Unreadable(description: "step \(index + 1) could not be read: \(error)")
      }
    }
  }
}
