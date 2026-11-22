//  #1013 (Igor, 2026-11-20, W4 on PR #912: "the picture shows the whole section, flagged as folded"; spec
//  2026-11-16-whiteboard-board-ops-design.md, *Headers fold their sections*; stories 900, 1046): Larry's picture of a
//  folded board draws every folded section in full, in place, as the board would look with it open, and shades it.
//  Pure: where the opened board puts each stroke, the shaded bands, and the map from the picture's places back to the
//  folded board's, so Larry's marks on that picture land where he drew them.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// How a picture drawn with its folds open maps onto the folded board: the folds opened, in the order they opened.
public struct BoardFoldMap: Codable, Equatable, Sendable {
  /// One fold opened: from `top` (its header row's bottom, at that moment) down, everything slid `slide` points.
  public struct Step: Codable, Equatable, Sendable {
    public var header: String
    public var top: CGFloat
    public var slide: CGFloat

    public init(header: String, top: CGFloat, slide: CGFloat) {
      self.header = header
      self.top = top
      self.slide = slide
    }
  }

  public var steps: [Step]

  public init(steps: [Step]) { self.steps = steps }

  /// A place on the folded board, in the picture.
  public func toPicture(_ y: CGFloat) -> CGFloat {
    steps.reduce(y) { y, step in y >= step.top ? y + step.slide : y }
  }

  /// A place in the picture, on the folded board: below an opened section it moves up by what the section took; on
  /// the folded lines themselves it lands just under their header.
  public func toBoard(_ y: CGFloat) -> CGFloat {
    steps.reversed().reduce(y) { y, step in
      y >= step.top + step.slide ? y - step.slide : y > step.top ? step.top : y
    }
  }

  public func toBoard(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: toBoard(p.y)) }

  /// The folded board's `rect` as the picture has it: as wide, and taller by the sections opened inside it.
  public func toPicture(_ rect: CGRect) -> CGRect {
    let top = toPicture(rect.minY)
    return CGRect(x: rect.minX, y: top, width: rect.width, height: toPicture(rect.maxY) - top)
  }

  /// What goes with the picture as `picture_folds` (the strokes already carry `folds`): the folds opened in order, each
  /// as the place `y` from which the picture slid `h` board points further down.
  public var wire: [[String: Any]] {
    steps.map { ["header": $0.header, "y": Double($0.top), "h": Double($0.slide)] }
  }
}

extension BoardOutline {
  /// The board with its folds open, for a picture: what moves and shows, the shaded bands and the way back.
  public struct FoldPicture: Sendable {
    /// A folded section, opened: its header and the stretch of the page its lines take, picture board points.
    public struct Band: Equatable, Sendable {
      public var header: String
      public var top: CGFloat
      public var bottom: CGFloat
    }

    /// The outline opened, every header in it open.
    public var open: BoardOutline
    /// By the strokes' places: how far each one moves, and the ones a fold hid that show.
    public var offsets: [Int: CGVector]
    public var shown: Set<Int>
    public var bands: [Band]
    public var map: BoardFoldMap
    /// The headers that were folded, by their row's middle, for the ▸ beside them.
    public var foldedMarks: [(header: String, y: CGFloat)]
    /// The headers that were open, each labelled "▾ header" past its line in the opened picture (story 1036, #1001).
    public var openLabels: [Marker]
  }

  /// Nil when no fold shows: the picture is the board as it is.
  public func foldPicture() -> FoldPicture? {
    var open = self
    var steps: [BoardFoldMap.Step] = []
    var reach: [String: CGFloat] = [:]
    while let id = open.bottomUp().first(where: { id in
      open.header(id).map { open.isFolded($0) && open.shows($0) } ?? false
    }) {
      reach[id] = open.header(id)?.fold?.bottom ?? 0
      guard let opened = open.opening(id) else { break }
      steps.append(BoardFoldMap.Step(header: id, top: opened.top, slide: opened.slide))
    }
    guard !steps.isEmpty else { return nil }
    let plan = open.plan(from: strokes, pages: 1)
    let map = BoardFoldMap(steps: steps)
    // Each section's stretch, carried down through the folds opened after it (one opened inside it widens it).
    let bands = steps.enumerated().map { i, step in
      let later = BoardFoldMap(steps: Array(steps[(i + 1)...]))
      return FoldPicture.Band(
        header: step.header, top: later.toPicture(step.top),
        bottom: later.toPicture(step.top + max(reach[step.header] ?? 0, 0)))
    }
    let folded = Set(steps.map(\.header))
    let marks = open.headers.compactMap { header in open.box(header).map { (header: header.id, y: $0.midY) } }
    return FoldPicture(
      open: open, offsets: plan.offsets, shown: Set(plan.hidden.filter { !$0.value }.keys), bands: bands, map: map,
      foldedMarks: marks.filter { folded.contains($0.header) },
      openLabels: open.headerLabels.filter { !folded.contains($0.header) })
  }

  /// The boxes of the labels a picture of the board draws, on the board as it is, for its frame to take in (#1001):
  /// each open header's; with a fold showing, each one the opened picture labels, an open sub-header inside a folded
  /// section too (context-grabber-e91y), mapped back through the folds.
  public var pictureLabelBoxes: [CGRect] {
    guard let opened = foldPicture() else { return headerLabels.map(\.box) }
    return opened.openLabels.map { label in
      CGRect(origin: opened.map.toBoard(label.box.origin), size: label.box.size)
    }
  }

  /// The tag in the margin at the top of a folded section in the picture.
  public static let foldedTag = "folded"
}

extension WhiteboardFrame {
  /// A picture's scale for `rect`, never finer than `atMost`, within the pixel budget and the long side.
  public static func scale(for rect: CGRect, atMost: CGFloat) -> CGFloat {
    guard rect.width > 0, rect.height > 0 else { return atMost }
    let budget = (maxPixels * maxPixels / (rect.width * rect.height)).squareRoot()
    return min(atMost, budget, maxLong / max(rect.width, rect.height))
  }
}

/// The fold maps of the pictures this device sent Larry, per board (#1013, story 1046): a reply names its picture, and
/// its marks are mapped back onto the folded board by that picture's map. Kept across launches, as the pictures' times
/// are. ponytail: UserDefaults on this device, the newest `kept` a board; a picture sent from another device isn't
/// known, and its marks land as its frame says.
public struct WhiteboardPictureFolds: @unchecked Sendable {
  public static let kept = 200
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  private func key(_ board: String) -> String { "whiteboard_picture_folds_\(board)" }

  private struct Entry: Codable {
    var picture: String
    var map: BoardFoldMap
  }

  private func entries(_ board: String) -> [Entry] {
    defaults.data(forKey: key(board)).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
  }

  /// A picture drawn with folds open; one with none is never kept.
  public func record(_ pictureID: String, map: BoardFoldMap?, board: String) {
    guard let map, !map.steps.isEmpty else { return }
    let kept = Array(
      (entries(board).filter { $0.picture != pictureID } + [Entry(picture: pictureID, map: map)]).suffix(Self.kept))
    if let data = try? JSONEncoder().encode(kept) { defaults.set(data, forKey: key(board)) }
  }

  /// `pictureID`'s map on this board; nil for a picture with no folds open, or one this device doesn't remember.
  public func map(_ pictureID: String?, board: String) -> BoardFoldMap? {
    guard let pictureID else { return nil }
    return entries(board).last { $0.picture == pictureID }?.map
  }
}
