//  Which kept labels Tidy overlaps may move (spec 2026-11-01-whiteboard-shapes-design.md, *Keep all and Tidy overlaps*;
//  story 896, bead context-grabber-cg3). A label is known by its moment; one in a group of Larry's (story 991: a box and
//  its label grouped in one change) is part of what moves whole, so Tidy leaves it where it is, as ink.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension WhiteboardTidy {
  /// The canvas split for a tidy: each kept label free to move, by its moment, with its strokes' places on the canvas;
  /// every other stroke that shows is ink. `known`: the moments of kept labels. `texts` and `groups` (stroke or text name
  /// to group) say what moves whole: a label in a group is ink, so Tidy never pulls a group apart. `folded`: places of
  /// folded strokes, neither moved nor in the way. `grouped`: how many labels a group held.
  public static func laid(
    _ strokes: [BoardOps.Stroke], known: Set<Int64>, texts: [BoardText] = [], groups: [String: String] = [:],
    folded: Set<Int> = []
  ) -> (labels: [String: [Int]], ink: [Int], grouped: Int) {
    let names = Set(groups.values)
    var inGroup = Set<Int>()
    for item in BoardOps.items(strokes: strokes, texts: texts, groups: groups) {
      if let tag = item.tag, names.contains(tag) { inGroup.formUnion(item.members) }
    }
    var labels: [String: [Int]] = [:]
    var ink: [Int] = []
    var held = Set<Int64>()
    for (i, stroke) in strokes.enumerated() where !folded.contains(i) {
      guard let t = stroke.t, known.contains(t) else {
        ink.append(i)
        continue
      }
      if inGroup.contains(i) {
        held.insert(t)
        ink.append(i)
      } else {
        labels["\(t)", default: []].append(i)
      }
    }
    return (labels, ink, held.count)
  }
}
