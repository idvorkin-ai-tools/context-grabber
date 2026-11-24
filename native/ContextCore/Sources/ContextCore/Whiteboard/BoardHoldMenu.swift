//  What a finger held still on the board offers (spec 2026-11-16-whiteboard-board-ops-design.md, *Press and hold*,
//  stories 874, 1186, 1187, 1309; context-grabber-y4y): the rows by what the finger is on, so the menu is about that thing.
//  Pure: the board shows the rows and does what was chosen.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// A row of the hold menu.
public enum BoardHoldChoice: Equatable, Sendable {
  case select, toText, delete, makeRoom, paste, makeHeader, foldAll, unfoldAll
  case notHeader(String)
  case level(Int)

  /// Its name in the log and in its button's accessibility identifier (`whiteboard-hold-<id>`).
  public var id: String {
    switch self {
    case .select: "select"
    case .toText: "to-text"
    case .delete: "delete"
    case .makeRoom: "make-room"
    case .paste: "paste"
    case .makeHeader: "make-header"
    case .notHeader: "not-header"
    case .foldAll: "fold-all"
    case .unfoldAll: "unfold-all"
    case .level(let n): "level-\(n)"
    }
  }

  public var title: String {
    switch self {
    case .select: "Select"
    case .toText: "To text"
    case .delete: "Delete"
    case .makeRoom: "Make room here"
    case .paste: "Paste"
    case .makeHeader: "Make header"
    case .notHeader: "Not a header"
    case .foldAll: "Fold all"
    case .unfoldAll: "Unfold all"
    case .level(let n): "\(n)"
    }
  }

  /// Its SF Symbol; nil for the outline's levels, which are their numbers.
  public var symbol: String? {
    switch self {
    case .select: "lasso"
    case .toText: "character.textbox"
    case .delete: "trash"
    case .makeRoom: "arrow.up.and.down.text.horizontal"
    case .paste: "doc.on.clipboard"
    case .makeHeader: "textformat.size"
    case .notHeader: "textformat.size.smaller"
    case .foldAll: "chevron.right.2"
    case .unfoldAll: "chevron.down.2"
    case .level: nil
    }
  }
}

/// The menu for a hold: its rows, in order, and the thing the finger is on, by its strokes' names.
public struct BoardHoldMenu: Equatable, Sendable {
  public var choices: [BoardHoldChoice]
  /// The strokes `select` and `delete` take; empty off ink.
  public var names: [String]
  /// What the finger is on, for the log: "header-mark", "header", "group", "ink" or "paper".
  public var on: String
}

extension BoardOutline {
  /// The menu for a finger held still at `point`, in board points: `inMargin` when it is left of the margin's edge,
  /// `slop` how near ink counts as on it (a fingertip). On a header's mark in the margin, the outline. On ink on the
  /// page, *Select*, *To text* and *Delete* that thing first (no *Delete* on a header's row: erasing one has its own
  /// rules; no *To text* on a kept text, which is text already, story 1309), then the rows for its line. Elsewhere *Make room here*, *Paste*, and *Make header* or *Not a header* beside a line.
  ///
  /// Story 1310 (#1386, "a touch inside his selection acts on the selection"): held on a thing any of whose strokes are
  /// in `selected` (the strokes' names selected now), the menu is about the whole selection: *To text* and *Delete*
  /// take all of it (no *Select*: it is selected already), on "selection". That is how a lasso round two lines reaches
  /// To text, which shows nowhere else.
  public func holdMenu(
    at point: CGPoint, inMargin: Bool, slop: CGFloat, selected: [String] = []
  ) -> BoardHoldMenu {
    let menu = thingMenu(at: point, inMargin: inMargin, slop: slop)
    guard !selected.isEmpty, !menu.names.isEmpty, !Set(menu.names).isDisjoint(with: selected) else { return menu }
    let line = menu.choices.filter { ![.select, .toText, .delete].contains($0) }
    return BoardHoldMenu(choices: toText(selected) + [.delete] + line, names: selected, on: "selection")
  }

  private func thingMenu(at point: CGPoint, inMargin: Bool, slop: CGFloat) -> BoardHoldMenu {
    if inMargin, header(at: point.y) != nil {
      return BoardHoldMenu(
        choices: [.foldAll, .level(1), .level(2), .level(3), .unfoldAll], names: [], on: "header-mark")
    }
    var line: [BoardHoldChoice] = [.makeRoom, .paste]
    if let row = row(at: point.y) {
      if let header = row.header {
        line.append(.notHeader(header))
      } else if !row.names.isEmpty {
        line.append(.makeHeader)
      }
    }
    guard !inMargin else { return BoardHoldMenu(choices: line, names: [], on: "paper") }
    if let hit = group(at: point, slop: slop) {
      return BoardHoldMenu(choices: [.select] + toText(hit.names) + [.delete] + line, names: hit.names, on: "group")
    }
    guard let names = word(at: point, slop: slop), !names.isEmpty else {
      return BoardHoldMenu(choices: line, names: [], on: "paper")
    }
    let chosen = Set(names)
    if headers.contains(where: { !chosen.isDisjoint(with: $0.ids) }) {
      return BoardHoldMenu(choices: [.select] + toText(names) + line, names: names, on: "header")
    }
    return BoardHoldMenu(choices: [.select] + toText(names) + [.delete] + line, names: names, on: "ink")
  }

  private func toText(_ names: [String]) -> [BoardHoldChoice] { isKeptText(names) ? [] : [.toText] }
}
