//  Stories 1030–1036 (#967): headers drawn in ink (spec 2026-11-19-whiteboard-ink-headers-design.md). The stroke Igor
//  just drew, read once: an underline under a line of his writing, or the last bar of a # at a line's start, makes the
//  line a header; a stroke on a header's line joins its row. The mark's own Undo takes the header with it, as
//  `BoardHeader.mark` says; nothing here is an undo step of its own.

import ContextCore
import PaperKit
import PencilKit

extension PaperBoardController {
  /// One stroke drawn with an inking tool (the element `key`): read for a header after PaperKit's callback.
  func inkHeaderSoon(_ change: PaperProbe.InkChange) {
    guard model.editable, change.added.count == 1, change.removed.isEmpty, change.moved.isEmpty,
      paper.drawingTool is PKInkingTool, let key = change.added.first
    else { return }
    Task { @MainActor [weak self] in self?.inkHeader(key) }
  }

  private func inkHeader(_ key: String) {
    guard let markup = paper.markup,
      let newest = markup.subelements.strokes.firstIndex(where: { Self.key($0.elementID) == key })
    else { return }
    var made: BoardOutline.InkHeader?
    _ = changeOutline("Make header") { outline in
      made = outline.inkHeader(newest: newest, id: WhiteboardModel.newHeaderID())
      return made != nil
    }
    guard let made else { return }
    var event: [String: Any] = [
      "action": "ink_header", "board": model.board.id, "by": made.kind, "header": made.header,
    ]
    switch made {
    case .underline(_, let y, let mark), .hash(_, let y, let mark):
      event["y"] = round(y)
      event["mark"] = mark.count
    case .grew(_, let names): event["joined"] = names.count
    }
    log.event("board_outline", event)
  }

  /// The headers whose underline or # is away (an Undo, or the eraser) and back again, in the session log.
  func noteMarksGone(_ outline: BoardOutline) {
    let live = outline.liveNames
    let gone = Set(model.headers.filter { $0.markGone(live) }.map(\.id))
    guard gone != marksGone else { return }
    for id in gone.subtracting(marksGone) {
      log.event("board_outline", ["action": "ink_header_gone", "board": model.board.id, "header": id])
    }
    for id in marksGone.subtracting(gone) where outline.header(id) != nil {
      log.event("board_outline", ["action": "ink_header_back", "board": model.board.id, "header": id])
    }
    marksGone = gone
  }
}
