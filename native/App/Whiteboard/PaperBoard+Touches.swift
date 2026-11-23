//  A board on paper: what a touch means to the board beyond PaperKit: the pacer's word, whether fingers draw, and the
//  picked tool in hand. Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import UIKit

extension PaperBoardController {
  /// The word to the pacer: the Pencil touching down, or a finger once it's seen to be drawing.
  func toolWentDown() {
    guard !toolDown else { return }
    toolDown = true
    model.beganDrawing()
  }

  var fingersDraw: Bool {
    paper.directTouchAutomaticallyDraws
      ? !UIPencilInteraction.prefersPencilOnlyDrawing : paper.directTouchMode == .drawing
  }

  /// Story 1091: what the picked tool means beyond the touch, set at each pick and again at each touch-down, so a pick the
  /// observer never heard still lands: answered cards stand aside for the eraser, and Larry's labels take the pen's width
  /// (#949; the eraser or lasso leaves the last pen's).
  func toolInHand(_ tool: PickedTool) {
    if place.erasing != tool.erases { place.erasing = tool.erases }
    if let ink = tool.ink, model.penInHand != ink.width { model.penInHand = ink.width }
  }
}
