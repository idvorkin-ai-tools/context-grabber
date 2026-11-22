//  The board's one edit lane (context-grabber-546e): every markup the board sets itself goes through here, unheard by
//  its own change callback, with the undo step back registered first when it has one. A move only: each caller still
//  decides what it reads back and what follows (frames, the model, the marks), as before.

import PaperKit
import UIKit

/// What one of the board's own markup sets came to: what it asked PaperKit to hold, and what PaperKit holds, read only
/// when asked for (#999, #1015: PaperKit can refuse a set).
@MainActor
struct PaperMarkupSet {
  let asked: PaperMarkup
  let paper: PaperMarkupViewController

  /// What PaperKit holds now: what was asked when it holds none.
  var held: PaperMarkup { paper.markup ?? asked }
}

extension PaperBoardController {
  /// The markup set, with its change callback quiet. `stepBack`: the markup Undo goes back to, registered before the set
  /// under `name`; none registers nothing.
  @discardableResult
  func setMarkup(_ markup: PaperMarkup, stepBack: PaperMarkup? = nil, named name: String? = nil) -> PaperMarkupSet {
    if let stepBack { registerStepBack(to: stepBack, named: name) }
    quiet = true
    paper.markup = markup
    quiet = false
    return PaperMarkupSet(asked: markup, paper: paper)
  }

  /// `body` with the change callback quiet, as the drop's take-back of PaperKit's step runs: set on and then off, never
  /// restored, so a step back inside it that sets the markup leaves it off as it always has.
  func quietly<T>(_ body: () -> T) -> T {
    quiet = true
    let out = body()
    quiet = false
    return out
  }
}
