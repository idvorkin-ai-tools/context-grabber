//  The label on a selection (spec 2026-11-22-whiteboard-selection-label-design.md, story 1095, #1045): what the lasso
//  holds and what applies to it, just above it, over the board. It takes no touch and is in no picture. What it says is
//  `BoardSelectionLabel` in ContextCore.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI

/// What the selection is, and where it is on screen (nil with nothing to name, or nowhere to show it).
@MainActor
final class BoardSelectionLabelState: ObservableObject {
  @Published var label: BoardSelectionLabel.Label?
  @Published var frame: CGRect?
}

extension PaperBoardController {
  /// Story 1095: says what the selection holds now. On every selection change, and after each change of Igor's own (an
  /// erase, a move, an undo), which can make a text plain ink under the same lasso.
  func nameSelection(connectReady: Bool) {
    var label: BoardSelectionLabel.Label?
    var strokes = 0
    if model.editable, let markup = paper.markup, !paper.selection.isEmpty {
      let elements = markup.subelements.strokes
      let board = elements.map { element in
        BoardSelectionLabel.Piece(
          names: (model.ink.hashes[Self.key(element.elementID)] ?? []).map(model.strokeIDs.stable),
          t: BoardMoment.ms(element.path.creationDate))
      }
      let picked = elements.indices.filter { paper.selection.contains(elements[$0].elementID) }.map { board[$0] }
      strokes = picked.count
      label = BoardSelectionLabel.label(
        picked: picked, board: board, texts: model.texts, metas: model.strokeMeta, connectReady: connectReady)
    }
    if label != selectionLabel.label {
      selectionLabel.label = label
      if let label {
        log.event(
          "whiteboard",
          [
            "action": "selection_label", "board": model.board.id, "kind": label.kind.rawValue, "label": label.text,
            "strokes": strokes,
          ])
      }
    }
    showSelectionLabel()
  }

  /// Where the selection is on screen now; none beside a paste (it has its own Delete) or while a text is reworded.
  func showSelectionLabel() {
    var frame: CGRect?
    if selectionLabel.label != nil, pastedFrame == nil, reword.editing == nil, let markup = paper.markup {
      let box = markup.subelements.strokes.filter { paper.selection.contains($0.elementID) }
        .compactMap { markup.subelements[$0.elementID] as? PKStroke }.reduce(CGRect.null) { $0.union($1.renderBounds) }
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    if frame != selectionLabel.frame { selectionLabel.frame = frame }
  }
}

/// Story 1095: the label, just above the selection (below it with no room above), its left edge on the selection's.
struct SelectionLabelView: View {
  @ObservedObject var state: BoardSelectionLabelState
  private static let height: CGFloat = 24
  private static let gap: CGFloat = 6

  /// Its top-left corner: above `selection`, or below it, kept inside `view` for a label about `width` wide.
  static func corner(selection: CGRect, width: CGFloat, in view: CGRect) -> CGPoint {
    let above = selection.minY - gap - height
    let y = above >= view.minY + gap ? above : min(selection.maxY + gap, view.maxY - gap - height)
    let x = max(view.minX + gap, min(selection.minX, view.maxX - gap - width))
    return CGPoint(x: x, y: y)
  }

  var body: some View {
    GeometryReader { geometry in
      if let label = state.label, let frame = state.frame {
        // About as wide as its letters, to keep it on screen at the right edge.
        let width = CGFloat(label.text.count) * 7 + 20
        let corner = Self.corner(selection: frame, width: width, in: CGRect(origin: .zero, size: geometry.size))
        Text(label.text)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
          .fixedSize()
          .padding(.horizontal, 10)
          .frame(height: Self.height)
          .background(.thinMaterial, in: Capsule())
          .offset(x: corner.x, y: corner.y)
          .accessibilityElement()
          .accessibilityLabel(label.spoken)
          .accessibilityIdentifier("whiteboard-selection-label")
      }
    }
    // The Pencil and a finger go through it to the board: the next stroke always draws.
    .allowsHitTesting(false)
  }
}
