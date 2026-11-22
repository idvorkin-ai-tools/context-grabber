//  The ink mirror: what the canvas says changed, settled or stepped, the save debounce it starts, and the picture's
//  frame.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  func changed(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    let added = new.strokes.count > drawing.strokes.count
    logStrokesMoved(to: new)
    drawing = new
    if added, let last = new.strokes.last { vad.stroke(last.renderBounds) }
    if added { strokeLanded() }
    drawingMoved()
  }

  /// Kept ink as the canvas reads it back. Nothing to ask about or save that the keep hasn't already started.
  func settled(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    inkMoved()
  }

  /// A kept mark undone or redone on paper: saved like any change, and not a stroke for Claude to answer.
  func stepped(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    drawingMoved()
  }

  /// #624: a board's ink below a line moved on its own, splitting a kept label. Names the next one.
  private func logStrokesMoved(to new: PKDrawing) {
    guard
      let moved = WhiteboardFrame.strokesMoved(
        before: drawing.strokes.map(\.renderBounds), after: new.strokes.map(\.renderBounds))
    else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_moved", "board": board.id, "strokes": new.strokes.count, "moved": moved.count,
        "dx": Double(moved.dx), "dy": Double(moved.dy), "top_moved_y": Double(moved.topY),
        "zoom": Double(canvas?.zoom ?? 1),
      ])
  }

  func drawingMoved() {
    ops.changed()
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    sentFrame = nil
    inkMoved()
    pasteNote = nil
    dirty = true
    saveSoon()
  }

  /// The ink changed: what's on screen may have too.
  private func inkMoved() {
    inkBoxes = drawing.strokes.map(\.renderBounds)
    cachedLabelBoxes = nil
    screenMoved()
  }

  /// On paper, the view moved or the ink changed (story 433): what Send and Larry's turn would show. A Send already made is
  /// of the pages it showed, so another page on screen can be sent too.
  func screenMoved() {
    let frame = pictureFrame()?.rect
    let nothing = !drawing.strokes.isEmpty && frame == nil
    if nothing != nothingOnScreen { nothingOnScreen = nothing }
    if let sentFrame, sentFrame != frame {
      self.sentFrame = nil
      sent = nil
    }
  }

  /// Larry's picture, for Send and his turn: the pages on screen (story 433). Claude's own turns frame theirs as they
  /// always have.
  func pictureFrame() -> (rect: CGRect, scale: CGFloat)? {
    BoardPages().picture(visible: canvas?.visibleRect ?? .null, ink: inkBoxes + labelBoxes())
  }

  /// The header markers' boxes, kept until the ink or the headers change: the picture's frame is asked for on every
  /// scroll (#1001).
  func labelBoxes() -> [CGRect] {
    if let cachedLabelBoxes { return cachedLabelBoxes }
    let boxes = pictureLabelBoxes()
    cachedLabelBoxes = boxes
    return boxes
  }
}
