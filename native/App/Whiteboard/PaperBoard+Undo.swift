//  A board on paper: the board's steps on the undo stack: registering one, taking back PaperKit's, watching the stack,
//  the bar's Undo and Redo, the board closing, and the step itself. Moved from PaperBoard.swift as it was
//  (context-grabber-fz4x).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Undo or redo of a kept mark or a batch of Larry's changes: back to the markup as it was, and the way forward again
  /// the same way. `named`: what Undo and Redo say (a batch's label).
  func registerStepBack(to markup: PaperMarkup, named name: String? = nil) {
    guard let undo = paper.undoManager else { return }
    stepsOn = undo
    undo.registerUndo(withTarget: self) { controller in
      MainActor.assumeIsolated { controller.step(to: markup, named: name) }
    }
    if let name, !name.isEmpty { undo.setActionName(name) }
  }

  /// #966: PaperKit's own step on top of the stack taken back (a tap's dot, a zigzag, a drag), never one of the board's:
  /// a keep's step on top is left there, Redo putting it straight back, so Undo still reaches it. False when nothing of
  /// PaperKit's went.
  func takeBackPaperKitsStep(why: String) -> Bool {
    guard let undo = paper.undoManager else { return false }
    let name = undo.undoActionName
    let outcome = probe.takeBackOthers(on: undo)
    guard case .leftOurs(let ours) = outcome else { return outcome == .tookBack }
    log.event(
      "whiteboard",
      [
        "action": "paper_undo_left_ours", "board": model.board.id, "why": why, "name": ours, "undo_name": name,
        "can_undo": undo.canUndo, "can_redo": undo.canRedo, "strokes": inkFrames.count,
      ])
    return false
  }

  /// #966: every Undo and Redo on the board's stack in the log, by name, with the ink before and after; the board's own
  /// take-backs say themselves.
  func watchUndo() {
    let center = NotificationCenter.default
    for (will, did) in [
      (Notification.Name.NSUndoManagerWillUndoChange, Notification.Name.NSUndoManagerDidUndoChange),
      (.NSUndoManagerWillRedoChange, .NSUndoManagerDidRedoChange),
    ] {
      center.addObserver(self, selector: #selector(undoWill(_:)), name: will, object: nil)
      center.addObserver(self, selector: #selector(undoDid(_:)), name: did, object: nil)
    }
    // #965: the bar's Undo and Redo follow every change to the stack, PaperKit's own steps too.
    for name in [
      Notification.Name.NSUndoManagerCheckpoint, .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange,
      .NSUndoManagerDidRedoChange,
    ] {
      center.addObserver(self, selector: #selector(undoChanged(_:)), name: name, object: nil)
    }
  }

  @objc private func undoChanged(_ note: Notification) {
    guard let undo = note.object as? UndoManager, undo === paper.undoManager else { return }
    showUndoSoon()
  }

  /// The bar's buttons once the stack has settled, never from inside a change: a take-back's undo and redo, and a view
  /// update, are over by then.
  func showUndoSoon() {
    guard !undoShowing else { return }
    undoShowing = true
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.undoShowing = false
      let undo = self.paper.undoManager
      let now = BoardUndoButtons(
        canUndo: undo?.canUndo ?? false, canRedo: undo?.canRedo ?? false, undoName: undo?.undoActionName ?? "",
        redoName: undo?.redoActionName ?? "")
      if self.model.undoButtons != now { self.model.undoButtons = now }
    }
  }

  /// #965: the bar's Undo or Redo, the same step as the tool picker's; the paper keeps the Pencil after it.
  func pressUndo(redo: Bool) {
    guard let undo = paper.undoManager else { return }
    let can = redo ? undo.canRedo : undo.canUndo
    log.event(
      "whiteboard",
      [
        "action": "paper_undo_button", "board": model.board.id, "redo": redo, "can": can,
        "name": redo ? undo.redoActionName : undo.undoActionName, "strokes": inkFrames.count,
      ])
    if can { redo ? undo.redo() : undo.undo() }
    // As after the Board menu: the next stroke draws.
    takeTheResponderBack()
    showUndoSoon()
  }

  @objc private func undoWill(_ note: Notification) {
    guard let undo = note.object as? UndoManager, undo === paper.undoManager, !probe.probing else { return }
    let redo = note.name == .NSUndoManagerWillRedoChange
    stepping = (
      redo ? undo.redoActionName : undo.undoActionName, inkFrames.count, paper.markup?.strokeFrames ?? inkFrames
    )
  }

  @objc private func undoDid(_ note: Notification) {
    guard let undo = note.object as? UndoManager, undo === paper.undoManager, !probe.probing, let was = stepping else {
      return
    }
    stepping = nil
    log.event(
      "whiteboard",
      [
        "action": note.name == .NSUndoManagerDidRedoChange ? "paper_redo" : "paper_undo", "board": model.board.id,
        "name": was.name, "strokes_before": was.strokes, "strokes": paper.markup?.strokeFrames.count ?? inkFrames.count,
        "can_undo": undo.canUndo, "can_redo": undo.canRedo, "undo_name": undo.undoActionName,
      ])
    // Story 1203: ink the step left in place can be left undrawn; the board redraws around the change and looks.
    redrawAfterStep(redo: note.name == .NSUndoManagerDidRedoChange, before: was.frames)
  }

  /// The board really closed, which a cancelled swipe back isn't: the stack can be the window's, and the next board's Undo
  /// mustn't reach this one's steps.
  func boardClosed() {
    guard let stepsOn else { return }
    stepsOn.removeAllActions(withTarget: self)
    log.event(
      "whiteboard",
      [
        "action": "paper_undo_closed", "board": model.board.id, "can_undo": stepsOn.canUndo,
        "can_redo": stepsOn.canRedo,
      ])
  }

  private func step(to markup: PaperMarkup, named name: String? = nil) {
    if probe.reached(name ?? "") {
      // #966: the board's take-back of PaperKit's step reached this one instead; Redo puts it straight back, unsaid.
      setMarkup(markup, stepBack: paper.markup, named: name)
      inkFrames = markup.strokeFrames
      pages = board.pages(in: markup.bounds)
      return
    }
    // Story 851: an undo of one of Larry's batches, by its label.
    if let name, !name.isEmpty, paper.undoManager?.isUndoing == true { model.undid(name) }
    setMarkup(markup, stepBack: paper.markup, named: name)
    pages = board.pages(in: markup.bounds)
    let framesBefore = inkFrames
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    noteInk(markup, since: framesBefore, report: true)
    // An undo can open a fold or close it again: the marks follow the ink.
    showMarks()
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      [
        "action": "paper_step", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "can_undo": paper.undoManager?.canUndo ?? false, "can_redo": paper.undoManager?.canRedo ?? false,
      ])
    redrawSoon()
  }
}
