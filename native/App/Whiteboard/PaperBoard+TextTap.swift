//  A board on paper: the first finger tap on a kept text selects it, ready to drag; the second opens its words (story
//  1197, context-grabber-awz). It goes on as a group's tap does (PaperBoard+GroupTap.swift).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Story 1197: the kept text a finger tap at `at` (board points) reached, as a tapped thing to select: its strokes'
  /// names and whether it is already the whole selection. Nil off every text and on a look-only board.
  func tappedText(at: CGPoint) -> TappedGroup? {
    guard let keys = keptTextKeys(at: at), let markup = paper.markup else { return nil }
    let elements = markup.subelements.strokes
    let strokes = opStrokes(markup).strokes
    guard elements.count == strokes.count else { return nil }
    let picked = elements.indices.filter { keys.contains(Self.key(elements[$0].elementID)) }
    let names = Set(picked.flatMap { strokes[$0].ids })
    guard !names.isEmpty else { return nil }
    let selected = Set(paper.selection.map(Self.key)) == keys
    return TappedGroup(name: "text", names: names, selected: selected, kind: "text")
  }
}
