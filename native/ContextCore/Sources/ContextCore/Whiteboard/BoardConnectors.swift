//  Connectors: arrows that join two things on the board and follow them (spec 2026-11-16-whiteboard-board-ops-design.md,
//  *Step 5: connectors*, stories 910–916; the Cockpit's assets/ink/board.mjs: `routeConnector`, `arrowEnds`, `connect`,
//  `connectorEnds`, `withConnectorInk`). A connector is one stroke under its name whose notes (`meta.connector`) say what
//  it joins; every plan ends by routing each one again from where its ends are after it. Pure: the app draws the plan.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// What a connector stroke's notes say: what it joins, by name, and the route it was last drawn on.
public struct BoardConnector: Equatable, Sendable {
  public enum Side: String, Sendable { case top, bottom, left, right, center }

  public var from: String
  public var to: String
  public var fromSide: Side
  public var toSide: Side
  /// The shaft's points, tail first, as last drawn (to a tenth of a point).
  public var route: [CGPoint]
  /// `0xRRGGBB`; nil is Larry's colour.
  public var color: UInt32?
  /// `larry` or `igor`.
  public var by: String

  public init(
    from: String, to: String, fromSide: Side, toSide: Side, route: [CGPoint] = [], color: UInt32? = nil,
    by: String = "larry"
  ) {
    self.from = from
    self.to = to
    self.fromSide = fromSide
    self.toSide = toSide
    self.route = route
    self.color = color
    self.by = by
  }

  /// The connector a stroke's notes describe; nil for any other note.
  public init?(_ meta: BoardMeta?) {
    guard let meta, meta.mayBeConnector, let object = meta.object as? [String: Any],
      let c = object["connector"] as? [String: Any],
      let from = c["from"] as? String, let to = c["to"] as? String
    else { return nil }
    self.from = from
    self.to = to
    fromSide = (c["from_side"] as? String).flatMap(Side.init(rawValue:)) ?? .center
    toSide = (c["to_side"] as? String).flatMap(Side.init(rawValue:)) ?? .center
    route = (c["route"] as? [[Any]] ?? []).compactMap { pair in
      guard pair.count == 2, let x = WhiteboardTurn.number(pair[0]), let y = WhiteboardTurn.number(pair[1]) else {
        return nil
      }
      return CGPoint(x: x, y: y)
    }
    color = WhiteboardTurn.hexColor(c["color"])
    by = c["by"] as? String ?? "larry"
  }

  /// These notes over `others` (the stroke's other notes kept as written).
  public func meta(over others: BoardMeta?) -> BoardMeta {
    var object = others?.object as? [String: Any] ?? [:]
    var c: [String: Any] = [
      "from": from, "to": to, "from_side": fromSide.rawValue, "to_side": toSide.rawValue,
      "route": route.map { [Double($0.x), Double($0.y)] }, "by": by,
    ]
    if let color { c["color"] = String(format: "#%06x", color) }
    object["connector"] = c
    // A note of strings, numbers and lists is always valid JSON.
    return BoardMeta(object)!
  }

  /// The stroke's notes once it is no connector: plain ink, its other notes kept; nil when that was all.
  public static func without(_ meta: BoardMeta?) -> BoardMeta? {
    guard var object = meta?.object as? [String: Any] else { return nil }
    object["connector"] = nil
    return object.isEmpty ? nil : BoardMeta(object)
  }
}

extension BoardMeta {
  /// Whether the notes could say this stroke is a connector, without reading them: most strokes' notes never do.
  var mayBeConnector: Bool { json.range(of: Data("\"connector\"".utf8)) != nil }
}

extension BoardStrokeMeta {
  /// Some stroke on the board is a connector: only then has anything to follow.
  public var hasConnectors: Bool { contains { BoardConnector($0) != nil } }
}

extension BoardOps {
  /// A connector Larry asks for (`{op:"connector"}`), or Igor's Connect.
  public struct NewConnector: Equatable, Sendable {
    public enum End: Equatable, Sendable {
      /// A stroke's, group's or kept text's name.
      case id(String)
      /// A point on the board: what is under it.
      case point(CGPoint)
    }

    public var id: String
    public var from: End
    public var to: End
    public var color: UInt32?
    public var width: CGFloat
    public var by: String

    public init(
      id: String, from: End, to: End, color: UInt32? = nil, width: CGFloat = BoardConnectors.pen, by: String = "larry"
    ) {
      self.id = id
      self.from = from
      self.to = to
      self.color = color
      self.width = width
      self.by = by
    }
  }

  static func connector(_ json: [String: Any]) -> Swift.Result<Op, Refusal> {
    guard let id = json["id"] as? String, isName(id) else { return .failure(Refusal(reason: Reason.badOp)) }
    func end(_ key: String, _ x: String, _ y: String) -> NewConnector.End? {
      if let name = json[key] as? String { return name.isEmpty ? nil : .id(name) }
      if let pair = json[key] as? [Any], pair.count == 2, let px = WhiteboardTurn.number(pair[0]),
        let py = WhiteboardTurn.number(pair[1])
      {
        return .point(CGPoint(x: px, y: py))
      }
      if let place = json[key] as? [String: Any], let px = place["x"].flatMap(WhiteboardTurn.number),
        let py = place["y"].flatMap(WhiteboardTurn.number)
      {
        return .point(CGPoint(x: px, y: py))
      }
      if json[key] == nil, let px = json[x].flatMap(WhiteboardTurn.number),
        let py = json[y].flatMap(WhiteboardTurn.number)
      {
        return .point(CGPoint(x: px, y: py))
      }
      return nil
    }
    guard let from = end("from", "x1", "y1"), let to = end("to", "x2", "y2") else {
      return .failure(Refusal(reason: Reason.badOp))
    }
    let width = (json["width"] as? NSNumber).map { CGFloat($0.doubleValue) }.flatMap { $0.isFinite ? $0 : nil }
    return .success(
      .connector(
        NewConnector(
          id: id, from: from, to: to, color: WhiteboardTurn.hexColor(json["color"]),
          width: min(WhiteboardTurn.widestPen, max(WhiteboardTurn.thinnestPen, width ?? BoardConnectors.pen)))))
  }
}

public enum BoardConnectors {
  /// An end lands on a thing within this many points of it (board.mjs `SLOP_END`).
  public static let reach: CGFloat = 16
  /// The head's wings: this long, this far either side of the shaft (board.mjs `connectorLines`).
  public static let head: CGFloat = 12
  public static let wing: CGFloat = 0.45
  public static let pen: CGFloat = 3
  /// Igor's connectors are drawn in black, which shows light in dark mode as his Pencil's does.
  public static let igorColor: UInt32 = 0x000000

  // MARK: The route

  /// Where a side of a box is (board.mjs `anchor`).
  public static func anchor(_ box: CGRect, _ side: BoardConnector.Side) -> CGPoint {
    switch side {
    case .top: CGPoint(x: box.midX, y: box.minY)
    case .bottom: CGPoint(x: box.midX, y: box.maxY)
    case .left: CGPoint(x: box.minX, y: box.midY)
    case .right: CGPoint(x: box.maxX, y: box.midY)
    case .center: CGPoint(x: box.midX, y: box.midY)
    }
  }

  /// The side of `a` that faces `b` (board.mjs `sideFacing`).
  public static func facing(_ a: CGRect, _ b: CGRect) -> BoardConnector.Side {
    let dx = b.midX - a.midX
    let dy = b.midY - a.midY
    return abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .bottom : .top)
  }

  /// The shaft from `a` to `b`: straight, unless that crosses one of `obstacles`; then one orthogonal elbow that crosses
  /// nothing (across then down, else down then across), if either does; else straight anyway (board.mjs
  /// `routeConnector`).
  public static func route(
    from a: CGRect, to b: CGRect, fromSide: BoardConnector.Side, toSide: BoardConnector.Side, obstacles: [CGRect]
  ) -> [CGPoint] {
    let straight = [anchor(a, fromSide), anchor(b, toSide)]
    let clear = { (pts: [CGPoint], ends: [CGRect]) in
      zip(pts, pts.dropFirst()).allSatisfy { p, q in !(obstacles + ends).contains { hits(p, q, $0) } }
    }
    if clear(straight, []) { return straight }
    let across = { (p: CGRect, q: CGRect) -> BoardConnector.Side in q.midX > p.midX ? .right : .left }
    let upright = { (p: CGRect, q: CGRect) -> BoardConnector.Side in q.midY > p.midY ? .bottom : .top }
    let f1 = anchor(a, across(a, b))
    let t1 = anchor(b, upright(b, a))
    let f2 = anchor(a, upright(a, b))
    let t2 = anchor(b, across(b, a))
    let shrink = { (box: CGRect) in box.insetBy(dx: 1, dy: 1) }
    for pts in [[f1, CGPoint(x: t1.x, y: f1.y), t1], [f2, CGPoint(x: f2.x, y: t2.y), t2]]
    where clear(pts, [shrink(a), shrink(b)]) {
      return pts
    }
    return straight
  }

  /// Does the segment `p`–`q` pass through `box` (Liang–Barsky, as board.mjs `segHitsBox`)?
  static func hits(_ p: CGPoint, _ q: CGPoint, _ box: CGRect) -> Bool {
    let dx = q.x - p.x
    let dy = q.y - p.y
    var t0: CGFloat = 0
    var t1: CGFloat = 1
    for (pp, qq) in [(-dx, p.x - box.minX), (dx, box.maxX - p.x), (-dy, p.y - box.minY), (dy, box.maxY - p.y)] {
      if pp == 0 {
        if qq < 0 { return false }
        continue
      }
      let r = qq / pp
      if pp < 0 {
        if r > t1 { return false }
        t0 = max(t0, r)
      } else {
        if r < t0 { return false }
        t1 = min(t1, r)
      }
    }
    return t1 - t0 > 1e-9
  }

  /// The ink of a route: the shaft, then the head's two wings from its tip, as one stroke.
  public static func polyline(_ route: [CGPoint]) -> [CGPoint] {
    guard route.count >= 2, let tip = route.last else { return route }
    let back = route[route.count - 2]
    let angle = atan2(tip.y - back.y, tip.x - back.x)
    let wing = { (d: CGFloat) in CGPoint(x: tip.x - head * cos(angle + d), y: tip.y - head * sin(angle + d)) }
    return route + [wing(Self.wing), tip, wing(-Self.wing)]
  }

  static func tenth(_ points: [CGPoint]) -> [CGPoint] {
    points.map { CGPoint(x: ($0.x * 10).rounded() / 10, y: ($0.y * 10).rounded() / 10) }
  }

  // MARK: Igor's arrow

  /// A lassoed hand-drawn arrow's tail and head: the longest stroke is the shaft; its end nearest the other strokes'
  /// points (the arrowhead) is the head, else its last point (board.mjs `arrowEnds`). Strokes need their points.
  public static func arrow(_ selected: [BoardOps.Stroke]) -> (tail: CGPoint, head: CGPoint)? {
    let length = { (s: BoardOps.Stroke) in
      zip(s.points, s.points.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }
    guard let shaft = selected.indices.max(by: { length(selected[$0]) < length(selected[$1]) }),
      var tail = selected[shaft].points.first, var tip = selected[shaft].points.last, tail != tip
    else { return nil }
    let rest = selected.indices.filter { $0 != shaft }.flatMap { selected[$0].points }
    if !rest.isEmpty {
      let c = CGPoint(
        x: rest.map(\.x).reduce(0, +) / CGFloat(rest.count), y: rest.map(\.y).reduce(0, +) / CGFloat(rest.count))
      if hypot(tail.x - c.x, tail.y - c.y) < hypot(tip.x - c.x, tip.y - c.y) { swap(&tail, &tip) }
    }
    return (tail, tip)
  }

  /// Igor's Connect on the strokes he lassoed (`selected`, their names): his arrow's ink erased and a connector in its
  /// place, as ops for `BoardOps.plan`; nil unless both ends land on two different things outside the selection.
  public static func connect(
    selected names: Set<String>, id: String, strokes: [BoardOps.Stroke], texts: [BoardText] = [],
    metas: BoardStrokeMeta = BoardStrokeMeta(), folds: [String: String] = [:]
  ) -> [BoardOps.Op]? {
    let chosen = strokes.filter { !$0.hidden && $0.ids.contains(where: names.contains) }
    guard !chosen.isEmpty, let ends = arrow(chosen) else { return nil }
    let ops: [BoardOps.Op] = [
      .delete(chosen.flatMap(\.ids)),
      .connector(
        BoardOps.NewConnector(id: id, from: .point(ends.tail), to: .point(ends.head), color: igorColor, by: "igor")),
    ]
    let plan = BoardOps.plan(ops, strokes: strokes, texts: texts, metas: metas, folds: folds, pages: 1)
    let made = plan.added.first { $0.id == id }
    return BoardConnector(made?.meta) == nil ? nil : ops
  }

  // MARK: On a plan

  /// The board as a plan leaves it: its strokes (the canvas's kept, moved, hidden as the plan says, then the ones it
  /// draws), their notes, and what moves whole.
  struct After {
    enum Source { case canvas(Int), added(Int) }

    var strokes: [BoardOps.Stroke] = []
    var source: [Source] = []
    var shift: [CGVector] = []
    var metas: [String: BoardMeta?] = [:]
    let base: BoardStrokeMeta
    var groups: [String: String]
    var items: [BoardOps.Item] = []
    /// The strokes that are connectors: the name carrying the notes, and the notes.
    var connectors: [Int: (name: String, connector: BoardConnector)] = [:]
    let byTime: [Int64: BoardText]
    let texts: [BoardText]

    init(
      _ plan: BoardOps.Plan, strokes start: [BoardOps.Stroke], texts: [BoardText], metas: BoardStrokeMeta,
      folds: [String: String]
    ) {
      base = metas
      self.texts = texts
      byTime = BoardText.byTime(texts)
      for name in plan.forgetMetas { self.metas[name] = .some(nil) }
      for (name, meta) in plan.metas { self.metas[name] = meta }
      var groups = metas.groups
      for name in plan.forgetMetas { groups[name] = nil }
      for (name, meta) in plan.metas { groups[name] = meta.group }
      self.groups = groups
      for (i, s) in start.enumerated() where !plan.erase.contains(i) {
        let by = plan.offsets[i] ?? .zero
        var moved = s
        moved.bounds = s.bounds.offsetBy(dx: by.dx, dy: by.dy)
        moved.points = s.points.map { CGPoint(x: $0.x + by.dx, y: $0.y + by.dy) }
        if let hidden = plan.hidden[i] { moved.hidden = hidden }
        strokes.append(moved)
        source.append(.canvas(i))
        shift.append(by)
      }
      for (j, s) in plan.added.enumerated() {
        strokes.append(
          BoardOps.Stroke(ids: [s.id], t: nil, bounds: s.bounds, hidden: s.hidden, points: s.points, pen: s.width))
        source.append(.added(j))
        shift.append(.zero)
      }
      items = BoardOps.items(strokes: strokes, texts: texts, groups: groups, folds: folds)
      for k in strokes.indices {
        for name in strokes[k].ids {
          if let c = BoardConnector(meta(name)) {
            connectors[k] = (name, c)
            break
          }
        }
      }
    }

    func meta(_ name: String) -> BoardMeta? {
      if let set = metas[name] { return set }
      return base[name]
    }

    func isConnector(_ k: Int) -> Bool { connectors[k] != nil }

    /// The strokes `id` names: a stroke's own name, a group's, or a kept text's.
    func members(_ id: String) -> [Int] {
      strokes.indices.filter { k in
        let s = strokes[k]
        guard !isConnector(k) else { return false }
        return s.ids.contains(id) || s.ids.contains { groups[$0] == id } || BoardText.owning(s.t, in: byTime)?.id == id
      }
    }

    /// Where the end is now: what shows of it, or, all of it folded away, the item that shows in its place (its
    /// header's row). Nil when nothing does.
    func box(_ members: [Int]) -> CGRect? {
      let shown = members.filter { !strokes[$0].hidden }
      if !shown.isEmpty { return shown.reduce(CGRect.null) { $0.union(strokes[$1].bounds) } }
      return items.first { !$0.hidden && $0.members.contains(where: members.contains) }?.bounds
    }

    /// Texts' and groups' boxes that show, none of `ends` among them: what a route keeps clear of. Headers, connectors and
    /// lone strokes are not in the way, as on the web board.
    func obstacles(excluding ends: Set<Int>) -> [CGRect] {
      items.filter { item in
        guard let tag = item.tag, !tag.hasPrefix("h:"), !item.hidden else { return false }
        return !item.members.contains { ends.contains($0) || isConnector($0) }
      }.map(\.bounds)
    }

    /// What a point on the board lands on: the smallest text or group within `reach`, by its name; else the word
    /// there, by its stroke names.
    func thing(at point: CGPoint) -> (id: String?, word: [String]) {
      let hit = items.filter { item in
        guard let tag = item.tag, !tag.hasPrefix("h:"), !item.hidden, !item.members.contains(where: isConnector) else {
          return false
        }
        return item.bounds.insetBy(dx: -reach, dy: -reach).contains(point)
      }.min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
      if let tag = hit?.tag { return (tag, []) }
      // A word of Igor's: connectors and folded ink are no words.
      var plain = strokes
      for k in plain.indices where isConnector(k) { plain[k].hidden = true }
      let word =
        BoardOutline(strokes: plain, headers: [], texts: texts, groups: groups).word(at: point, slop: reach) ?? []
      // A word that runs into one of Larry's groups takes only Igor's plain ink.
      return (nil, word.filter { groups[$0] == nil })
    }
  }

  /// A batch's connectors on the board its other ops leave: each end resolved (a point to the thing under it; a word
  /// becomes a group `<id>-from` or `<id>-to`), its sides facing, its route drawn. A name the board lacks draws nothing
  /// and is missing; an end at a point on bare paper draws a plain arrow.
  static func draw(
    _ list: [BoardOps.NewConnector], into plan: inout BoardOps.Plan, strokes: [BoardOps.Stroke], texts: [BoardText],
    metas: BoardStrokeMeta, folds: [String: String]
  ) {
    for new in list {
      // A name already there is drawn again (the Cockpit takes a name once).
      plan.added.removeAll { $0.id == new.id }
      for (i, s) in strokes.enumerated() where s.ids.contains(new.id) {
        plan.erase.insert(i)
        plan.offsets[i] = nil
        plan.hidden[i] = nil
      }
      var board = After(plan, strokes: strokes, texts: texts, metas: metas, folds: folds)
      var ends: [(id: String, members: [Int])] = []
      for (end, suffix) in [(new.from, "from"), (new.to, "to")] {
        switch end {
        case .id(let id):
          let members = board.members(id)
          if members.isEmpty { plan.missingIDs.append(id) } else { ends.append((id, members)) }
        case .point(let p):
          let (id, word) = board.thing(at: p)
          if let id {
            ends.append((id, board.members(id)))
          } else if !word.isEmpty {
            let group = "\(new.id.prefix(58))-\(suffix)"
            for name in word {
              var object = board.meta(name)?.object as? [String: Any] ?? [:]
              object["group"] = group
              plan.metas[name] = BoardMeta(object)
            }
            plan.forgetMetas.subtract(word)
            board = After(plan, strokes: strokes, texts: texts, metas: metas, folds: folds)
            ends.append((group, board.members(group)))
          }
        }
      }
      if ends.count == 2, ends[0].id != ends[1].id, let a = board.box(ends[0].members),
        let b = board.box(ends[1].members)
      {
        var c = BoardConnector(
          from: ends[0].id, to: ends[1].id, fromSide: facing(a, b), toSide: facing(b, a), color: new.color, by: new.by)
        c.route = tenth(
          route(
            from: a, to: b, fromSide: c.fromSide, toSide: c.toSide,
            obstacles: board.obstacles(excluding: Set(ends[0].members + ends[1].members))))
        let meta = c.meta(over: nil)
        plan.added.append(
          BoardOps.NewStroke(id: new.id, points: polyline(c.route), width: new.width, color: new.color, meta: meta))
        plan.metas[new.id] = meta
        plan.forgetMetas.remove(new.id)
        plan.connected.append(new.id)
        continue
      }
      // Ends on bare paper: a plain arrow where it was asked for, as the web board keeps one.
      if case .point(let p) = new.from, case .point(let q) = new.to, p != q {
        plan.added.append(
          BoardOps.NewStroke(id: new.id, points: polyline([p, q]), width: new.width, color: new.color))
      }
    }
  }

  /// Every connector that shows, routed again from where its ends are once `plan` is on the board: a route that changed
  /// is drawn again in the plan (the same name), an unchanged one only has its notes follow it, and one whose end is
  /// gone is plain ink from now on (its connector notes go). `folds` is the board's after the plan.
  public static func follow(
    _ plan: inout BoardOps.Plan, strokes: [BoardOps.Stroke], texts: [BoardText] = [],
    metas: BoardStrokeMeta = BoardStrokeMeta(), folds: [String: String] = [:]
  ) {
    let board = After(plan, strokes: strokes, texts: texts, metas: metas, folds: folds)
    for k in board.connectors.keys.sorted() where !board.strokes[k].hidden {
      guard let (name, c) = board.connectors[k] else { continue }
      let from = board.members(c.from)
      let to = board.members(c.to)
      guard !from.isEmpty, !to.isEmpty else {
        if let rest = BoardConnector.without(board.meta(name)) {
          plan.metas[name] = rest
        } else {
          plan.metas[name] = nil
          plan.forgetMetas.insert(name)
        }
        plan.loosened.append(name)
        continue
      }
      guard let a = board.box(from), let b = board.box(to) else { continue }
      var now = c
      now.route = tenth(
        route(
          from: a, to: b, fromSide: c.fromSide, toSide: c.toSide,
          obstacles: board.obstacles(excluding: Set(from + to))))
      let by = board.shift[k]
      let was = c.route.map { CGPoint(x: $0.x + by.dx, y: $0.y + by.dy) }
      let same =
        was.count == now.route.count
        && zip(was, now.route).allSatisfy { abs($0.x - $1.x) <= 0.5 && abs($0.y - $1.y) <= 0.5 }
      if same, by == .zero { continue }
      let meta = now.meta(over: board.meta(name))
      plan.metas[name] = meta
      if same { continue }
      switch board.source[k] {
      case .canvas(let i):
        plan.erase.insert(i)
        plan.offsets[i] = nil
        plan.hidden[i] = nil
        let pen = board.strokes[k].pen > 0 ? board.strokes[k].pen : Self.pen
        plan.added.append(
          BoardOps.NewStroke(id: name, points: polyline(now.route), width: pen, color: c.color, meta: meta))
      case .added(let j):
        plan.added[j].points = polyline(now.route)
        plan.added[j].meta = meta
      }
      plan.rerouted.append(name)
    }
  }
}
