//  What Igor did to the ink, for Larry (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry hears my ink change and
//  my selection*, story 843). PaperKit keeps an id for each element through a move, so the board keeps each element's
//  ink hashes and, when PaperKit says elements changed, tells added, erased and moved apart: an element whose hashes
//  changed but not their count moved, and keeps its names (`BoardStrokeIDs`); one whose count changed was rubbed, which
//  is new ink.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardInk: Equatable, Sendable {
  /// Each element's ink hashes, one per visible stretch, by PaperKit's element key.
  public private(set) var hashes: [String: [String]] = [:]

  public init(hashes: [String: [String]] = [:]) {
    self.hashes = hashes
  }

  public struct Change: Equatable, Sendable {
    public var added: [String] = []
    public var erased: [String] = []
    public var moved: [String] = []
    public var isEmpty: Bool { added.isEmpty && erased.isEmpty && moved.isEmpty }
  }

  /// Elements came or changed (`updated`, their hashes now) and went (`removed`). Names as Larry knows them; a moved
  /// stroke's are kept in `ids`.
  public mutating func changed(updated: [String: [String]], removed: [String], ids: inout BoardStrokeIDs) -> Change {
    var change = Change()
    for (key, now) in updated.sorted(by: { $0.key < $1.key }) {
      defer { hashes[key] = now }
      guard let was = hashes[key] else {
        change.added += now.map(ids.stable)
        continue
      }
      guard was != now else { continue }
      if was.count == now.count {
        ids.moved(from: was, to: now)
        change.moved += now.map(ids.stable)
      } else {
        change.erased += was.map(ids.stable)
        change.added += now.map(ids.stable)
      }
    }
    for key in removed.sorted() {
      guard let was = hashes.removeValue(forKey: key) else { continue }
      change.erased += was.map(ids.stable)
    }
    return change
  }

  /// The board as it is now, without telling anyone: after a load, or a change of Larry's own.
  public mutating func reset(_ hashes: [String: [String]]) { self.hashes = hashes }
}
