//  What a batch of Larry's changes does to the board (spec 2026-11-16-whiteboard-board-ops-design.md, stories 814–817,
//  840–842, 847, 848): which strokes move, which go, which he draws, what notes they carry, what hides, and how many
//  pages the board needs after. The ops run in order, each on the board the ones before it left, so a later op can move
//  or erase what an earlier one drew. Pure: the app applies the plan to PaperKit.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOps {
  /// One stroke on the canvas as the plan sees it: the names Larry knows it by (one per visible stretch) and when it was
  /// made, unix ms.
  public struct Stroke: Equatable, Sendable {
    public var ids: [String]
    public var t: Int64?
    public var bounds: CGRect

    public init(ids: [String], t: Int64?, bounds: CGRect) {
      self.ids = ids
      self.t = t
      self.bounds = bounds
    }
  }

  /// What moves as a whole: a stroke, every glyph of a kept text, or a group of Larry's.
  public struct Item: Equatable, Sendable {
    /// Every name it answers to: its strokes', and its text's or group's.
    public var ids: Set<String>
    /// The strokes' places on the canvas.
    public var members: [Int]
    public var bounds: CGRect
  }

  /// The canvas's strokes as items: a kept text's glyphs (made at its time) are one item answering to its id, and
  /// strokes whose notes name one group are one item answering to the group.
  public static func items(strokes: [Stroke], texts: [BoardText] = [], groups: [String: String] = [:]) -> [Item] {
    let byTime = BoardText.byTime(texts)
    var out: [Item] = []
    var byTag: [String: Int] = [:]
    for (index, stroke) in strokes.enumerated() {
      let tag = BoardText.owning(stroke.t, in: byTime)?.id ?? stroke.ids.lazy.compactMap { groups[$0] }.first
      if let tag, let at = byTag[tag] {
        out[at].ids.formUnion(stroke.ids)
        out[at].members.append(index)
        out[at].bounds = out[at].bounds.union(stroke.bounds)
        continue
      }
      if let tag { byTag[tag] = out.count }
      out.append(Item(ids: Set(stroke.ids + (tag.map { [$0] } ?? [])), members: [index], bounds: stroke.bounds))
    }
    return out
  }

  public struct Plan: Equatable, Sendable {
    /// How far each canvas stroke moves, by its place on the canvas; strokes that stay or go are absent.
    public var offsets: [Int: CGVector] = [:]
    /// Canvas strokes erased, by place.
    public var erase: Set<Int> = []
    /// Strokes Larry draws, where the batch leaves them.
    public var added: [NewStroke] = []
    /// Notes set, by stroke name (his drawn strokes' included).
    public var metas: [String: BoardMeta] = [:]
    /// Canvas strokes hidden (true) or shown (false), by place. A stroke he draws carries its own.
    public var hidden: [Int: Bool] = [:]
    /// Names to select once the batch is on the board (story 848).
    public var select: [String] = []
    /// Larry's controls laid and taken away, in order (story 845): never ink, never undone.
    public var overlays: [BoardOverlays.Change] = []
    /// Ghosts of Larry's text to show.
    public var texts: [Text] = []
    public var pagesBefore: Int
    public var pagesAfter: Int
    /// Items that moved.
    public var moved = 0
    public var missingIDs: [String] = []

    public init(pagesBefore: Int, pagesAfter: Int) {
      self.pagesBefore = pagesBefore
      self.pagesAfter = pagesAfter
    }

    /// The board's ink changes: something moves, goes, is drawn, hides or shows, or a page is added. Text and notes
    /// alone leave the ink as it is.
    public var changesBoard: Bool {
      !offsets.isEmpty || !erase.isEmpty || !added.isEmpty || !hidden.isEmpty || pagesAfter != pagesBefore
    }
  }

  /// The batch's changes on the canvas's `strokes`, in order. `pages` is the column's page count now; it grows to hold
  /// the ink after, and the room a push opens below the last ink.
  public static func plan(
    _ ops: [Op], strokes: [Stroke], texts: [BoardText] = [], metas: BoardStrokeMeta = BoardStrokeMeta(), pages: Int,
    board: BoardPages = BoardPages()
  ) -> Plan {
    var work = Working(strokes: strokes, items: items(strokes: strokes, texts: texts, groups: metas.groups))
    var plan = Plan(pagesBefore: pages, pagesAfter: pages)
    var reach: CGFloat?
    for op in ops {
      switch op {
      case .translateBelow(let y, let dy):
        for item in work.items.indices where work.top(item).map({ $0 >= y }) == true { work.move(item, 0, dy) }
        if dy > 0 { reach = max(reach ?? y + dy, y + dy) }
      case .translateIDs(let ids, let dx, let dy):
        var hit = Set<Int>()
        for id in ids {
          let found = work.items(named: id)
          if found.isEmpty { plan.missingIDs.append(id) }
          hit.formUnion(found)
        }
        for item in hit.sorted() { work.move(item, dx, dy) }
      case .addText(let text):
        plan.texts.removeAll { $0.id == text.id }
        plan.texts.append(text)
      case .addStrokes(let new):
        work.add(new, plan: &plan)
      case .delete(let ids):
        for id in ids where !work.erase(named: id) { plan.missingIDs.append(id) }
      case .setMeta(let ids, let meta):
        for id in ids {
          let names = work.names(of: id)
          if names.isEmpty { plan.missingIDs.append(id) }
          for name in names { plan.metas[name] = meta }
        }
      case .replace(let ids, let new):
        for id in ids where !work.erase(named: id) { plan.missingIDs.append(id) }
        work.add(new, plan: &plan)
      case .setHidden(let ids, let hidden):
        for id in ids {
          let found = work.entries(named: id)
          if found.isEmpty { plan.missingIDs.append(id) }
          for e in found { work.entries[e].hidden = hidden }
        }
      case .select(let ids):
        for id in ids {
          let names = work.names(of: id)
          if names.isEmpty { plan.missingIDs.append(id) }
          plan.select += names.filter { !plan.select.contains($0) }
        }
      case .overlay(let overlay):
        plan.overlays.append(.set(overlay))
      case .removeOverlay(let id):
        plan.overlays.append(.remove(id))
      }
    }
    work.finish(into: &plan)
    let inkMaxY = (work.liveBounds.map(\.maxY) + (reach.map { [$0] } ?? [])).max()
    plan.pagesAfter = board.pages(after: pages, inkMaxY: inkMaxY, redoWaiting: false)
    return plan
  }

  /// The board as the batch changes it: entries are the canvas's strokes then the ones the batch draws.
  struct Working {
    struct Entry {
      var names: [String]
      /// Its place on the canvas, or in the plan's drawn strokes.
      var canvas: Int?
      var drawn: Int?
      var bounds: CGRect
      var shift = CGVector.zero
      var gone = false
      /// Set by the batch: hidden or shown.
      var hidden: Bool?
    }

    var entries: [Entry]
    /// Each item's entries, and the names it answers to as a whole (its text or group).
    var items: [(entries: [Int], tags: Set<String>)]
    var drawn: [NewStroke] = []

    init(strokes: [Stroke], items: [Item]) {
      entries = strokes.enumerated().map { Entry(names: $1.ids, canvas: $0, bounds: $1.bounds) }
      self.items = items.map { item in
        let own = Set(item.members.flatMap { strokes[$0].ids })
        return (item.members, item.ids.subtracting(own))
      }
    }

    func live(_ item: Int) -> [Int] { items[item].entries.filter { !entries[$0].gone } }

    func top(_ item: Int) -> CGFloat? { live(item).map { entries[$0].bounds.minY }.min() }

    var liveBounds: [CGRect] { entries.filter { !$0.gone }.map(\.bounds) }

    /// Items answering to `id`: by its text or group, or by one of its strokes' names. Moving a stroke of a group moves
    /// the group.
    func items(named id: String) -> [Int] {
      items.indices.filter { item in
        !live(item).isEmpty && (items[item].tags.contains(id) || live(item).contains { entries[$0].names.contains(id) })
      }
    }

    /// Live entries `id` names: a text's or group's, all of them; a stroke's name, that stroke alone.
    func entries(named id: String) -> [Int] {
      let tagged = items.indices.filter { items[$0].tags.contains(id) }.flatMap { live($0) }
      if !tagged.isEmpty { return tagged }
      return entries.indices.filter { !entries[$0].gone && entries[$0].names.contains(id) }
    }

    /// The stroke names `id` covers.
    func names(of id: String) -> [String] { entries(named: id).flatMap { entries[$0].names } }

    mutating func move(_ item: Int, _ dx: CGFloat, _ dy: CGFloat) {
      for e in live(item) {
        entries[e].bounds = entries[e].bounds.offsetBy(dx: dx, dy: dy)
        entries[e].shift.dx += dx
        entries[e].shift.dy += dy
      }
    }

    /// False when nothing answers to `id`.
    mutating func erase(named id: String) -> Bool {
      let found = entries(named: id)
      for e in found { entries[e].gone = true }
      return !found.isEmpty
    }

    /// Larry's strokes join the board: a name already there is redrawn (the Cockpit takes a name once), and one whose
    /// notes name a group joins that group.
    mutating func add(_ new: [NewStroke], plan: inout Plan) {
      for stroke in new {
        _ = erase(named: stroke.id)
        let entry = entries.count
        entries.append(Entry(names: [stroke.id], drawn: drawn.count, bounds: stroke.bounds))
        drawn.append(stroke)
        if let meta = stroke.meta { plan.metas[stroke.id] = meta }
        if let group = stroke.meta?.group, let item = items.indices.first(where: { items[$0].tags.contains(group) }) {
          items[item].entries.append(entry)
        } else {
          items.append(([entry], stroke.meta?.group.map { [$0] } ?? []))
        }
      }
    }

    func finish(into plan: inout Plan) {
      for entry in entries {
        if let canvas = entry.canvas {
          if entry.gone {
            plan.erase.insert(canvas)
          } else {
            if entry.shift.dx != 0 || entry.shift.dy != 0 { plan.offsets[canvas] = entry.shift }
            if let hidden = entry.hidden { plan.hidden[canvas] = hidden }
          }
        } else if let index = entry.drawn, !entry.gone {
          var stroke = drawn[index]
          stroke.points = stroke.points.map { CGPoint(x: $0.x + entry.shift.dx, y: $0.y + entry.shift.dy) }
          if let hidden = entry.hidden { stroke.hidden = hidden }
          plan.added.append(stroke)
        }
      }
      plan.moved =
        items.indices.filter { item in
          live(item).contains { entries[$0].canvas != nil && (entries[$0].shift.dx != 0 || entries[$0].shift.dy != 0) }
        }.count
      for stroke in plan.added {
        if plan.metas[stroke.id] == nil, let meta = stroke.meta { plan.metas[stroke.id] = meta }
      }
      // Notes on strokes that went are forgotten with them.
      let gone = Set(entries.filter(\.gone).flatMap(\.names))
      let live = Set(entries.filter { !$0.gone }.flatMap(\.names))
      for name in gone.subtracting(live) { plan.metas[name] = nil }
    }
  }
}
