//  Shapes that snap on paper (spec 2026-11-16-whiteboard-to-text-and-snap-design.md, stories 923–925; the web board's
//  shape cleanup): a stroke the Pencil was held still at the end of, for half a second, that is nearly a line, a
//  rectangle or an ellipse, swapped for the clean shape as it lands, one undo back to the raw ink. The recogniser and the
//  hold's rule are `BoardShapeSnap` in ContextCore. Stories 943–944 (spec 2026-11-17-whiteboard-reword-and-live-snap-
//  design.md): the clean shape shows once the hold is seen, with the Pencil still down, and goes if it moves on.
//  ponytail: PaperKit's own wet stroke can't be hidden, so the preview covers it with a band of paper colour along the
//  touch's points, which hides the rules (and any ink) under it until the lift; a canvas of our own is the upgrade.

import ContextCore
import PaperKit
import PencilKit
import UIKit

/// The drawing touch's hold, and the stroke a held lift is waiting for.
@MainActor
final class BoardSnapWatch {
  fileprivate var hold: BoardShapeSnap.Hold?
  /// The touch drawing it: a palm or a second finger beside it is no part of it.
  fileprivate var touch: ObjectIdentifier?
  /// A held lift, until this time: the next single stroke PaperKit adds is its stroke.
  fileprivate var waitingUntil: Double = 0
  /// The last lone stroke PaperKit added, and when: its lift may come after it. No key when another gesture took it.
  fileprivate var lastAdded: (key: String?, time: Double)?
  /// Stories 943–944: the touch's points so far, and the clean shape showing for them, if any.
  fileprivate var live = BoardShapeSnap.Live()
  fileprivate var waiting: Task<Void, Never>?
  fileprivate var cover: CAShapeLayer?
  fileprivate var clean: CAShapeLayer?
  fileprivate var shownKind: String?
  /// A held lift's clean shape and cover, kept up until its snap lands; the next stroke's preview is no part of them.
  fileprivate var landing: [CAShapeLayer] = []
}

extension PaperBoardController {
  enum SnapTouch { case down, moved, lifted }

  /// A touch that draws, from the base's touch hooks: `draws` when it is the Pencil, or a finger while fingers draw.
  func snapTouch(_ touch: UITouch, _ phase: SnapTouch, draws: Bool) {
    guard model.editable, draws, paper.drawingTool is PKInkingTool else { return }
    let id = ObjectIdentifier(touch)
    let point = lines.columnPoint(of: touch.location(in: lines))
    switch phase {
    case .down:
      snaps.hold = BoardShapeSnap.Hold()
      snaps.touch = id
      snaps.hold?.moved(to: point, at: touch.timestamp)
      hidePreview(why: nil)
      snaps.live = BoardShapeSnap.Live()
      if snaps.live.moved(to: point, at: touch.timestamp) { waitForStill() }
    case .moved:
      guard snaps.touch == id else { return }
      snaps.hold?.moved(to: point, at: touch.timestamp)
      if snaps.live.moved(to: point, at: touch.timestamp) {
        hidePreview(why: "moved")
        waitForStill()
      }
    case .lifted:
      guard snaps.touch == id, var hold = snaps.hold else { return }
      snaps.hold = nil
      snaps.touch = nil
      snaps.waiting?.cancel()
      guard touch.phase != .cancelled, hold.held(liftedAt: point, time: touch.timestamp) else {
        hidePreview(why: nil)
        return
      }
      // The clean shape stays up until the snap lands, so the raw stroke doesn't flash back in between.
      if snaps.cover != nil {
        let layers = [snaps.cover, snaps.clean].compactMap { $0 }
        snaps.cover = nil
        snaps.clean = nil
        snaps.shownKind = nil
        snaps.landing += layers
        Task { @MainActor [weak self] in
          try? await Task.sleep(for: .seconds(1))
          layers.forEach { $0.removeFromSuperlayer() }
          self?.snaps.landing.removeAll { layers.contains($0) }
        }
      }
      let now = CACurrentMediaTime()
      if let added = snaps.lastAdded, now - added.time < 0.5 {
        snaps.lastAdded = nil
        if let key = added.key { snapSoon(key) }
      } else {
        snaps.waitingUntil = now + 1
      }
    }
  }

  /// PaperKit's change to the ink: a lone stroke added is the one a held lift waits for, or may be, when it comes first.
  /// A change another gesture `consumed` (a margin hold, a pick-up, a scratch-out, a tap dot) is that lift's too, and
  /// snaps nothing.
  func snapNoticed(_ change: PaperProbe.InkChange, consumed: Bool) {
    guard consumed || (change.added.count == 1 && change.removed.isEmpty) else { return }
    let key = consumed ? nil : change.added.first
    let now = CACurrentMediaTime()
    if now <= snaps.waitingUntil {
      snaps.waitingUntil = 0
      if let key { snapSoon(key) }
    } else {
      snaps.lastAdded = (key, now)
    }
  }

  /// Not from inside PaperKit's own callback.
  private func snapSoon(_ key: String) {
    Task { @MainActor [weak self] in self?.snap(key) }
  }

  /// Story 923–924: the stroke swapped for its clean shape, in its ink, colour and width, drawn evenly; one undo.
  private func snap(_ key: String) {
    guard let markup = paper.markup,
      let raw = markup.subelements.strokes.first(where: { Self.key($0.elementID) == key })
    else { return }
    let points = raw.path.map { $0.location.applying(raw.transform) }
    defer {
      snaps.landing.forEach { $0.removeFromSuperlayer() }
      snaps.landing = []
    }
    guard let shape = BoardShapeSnap.clean(points) else {
      log.event("whiteboard", ["action": "shape_snap_none", "board": model.board.id, "points": points.count])
      return
    }
    let sizes = raw.path.map(\.size.width)
    let width = sizes.isEmpty ? WhiteboardTurn.defaultPen : sizes.reduce(0, +) / CGFloat(sizes.count)
    let clean = PKStroke(
      ink: raw.ink,
      path: PKStrokePath(
        controlPoints: shape.points.enumerated().map { i, p in
          PKStrokePoint(
            location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: width, height: width), opacity: 1,
            force: 1, azimuth: 0, altitude: .pi / 2)
        }, creationDate: raw.path.creationDate))
    let name = BoardShapeSnap.name(shape.kind)
    replaceInk(removing: [key], adding: [clean], named: "Snap to \(name)")
    log.event(
      "whiteboard",
      [
        "action": "shape_snap", "board": model.board.id, "kind": name, "err": shape.error, "points": points.count,
        "clean_points": shape.points.count, "width": Double(width),
      ])
  }

  /// Stories 943–944: once the Pencil has been still for the hold, the clean shape of the stroke so far, if it is one.
  private func waitForStill() {
    snaps.waiting?.cancel()
    snaps.waiting = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(BoardShapeSnap.hold + 0.02))
      guard !Task.isCancelled, let self, self.snaps.touch != nil,
        let shape = self.snaps.live.still(at: CACurrentMediaTime())
      else { return }
      self.showPreview(shape)
    }
  }

  /// The clean shape over the stroke, in the pen's colour and width, the wet stroke covered in paper colour beneath it.
  private func showPreview(_ shape: BoardShapeSnap.Shape) {
    guard snaps.cover == nil, let tool = paper.drawingTool as? PKInkingTool else { return }
    let zoom = screenScale
    let path = { (points: [CGPoint]) -> CGPath in
      let out = CGMutablePath()
      let spots = points.map { self.lines.convert(self.lines.spot(of: $0), to: self.view) }
      if let first = spots.first {
        out.move(to: first)
        for spot in spots.dropFirst() { out.addLine(to: spot) }
      }
      return out
    }
    let layer = { (points: [CGPoint], color: UIColor, width: CGFloat) -> CAShapeLayer in
      let layer = CAShapeLayer()
      layer.path = path(points)
      layer.strokeColor = color.cgColor
      layer.fillColor = nil
      layer.lineWidth = width
      layer.lineCap = .round
      layer.lineJoin = .round
      self.view.layer.addSublayer(layer)
      return layer
    }
    let dark = view.traitCollection.userInterfaceStyle == .dark
    let ink = dark ? PKInkingTool.convertColor(tool.color, from: .light, to: .dark) : tool.color
    snaps.cover = layer(
      snaps.live.points, paperColor.resolvedColor(with: view.traitCollection), tool.width * zoom * 2 + 6)
    snaps.clean = layer(shape.points, ink.resolvedColor(with: view.traitCollection), max(1, tool.width * zoom))
    let name = BoardShapeSnap.name(shape.kind)
    snaps.shownKind = name
    log.event(
      "whiteboard",
      [
        "action": "shape_snap_preview", "board": model.board.id, "kind": name, "err": shape.error,
        "points": snaps.live.points.count,
      ])
  }

  /// The clean shape away and the wet stroke showing again. `why`: "moved" logs the Pencil moving on.
  private func hidePreview(why: String?) {
    guard snaps.cover != nil || snaps.clean != nil else { return }
    snaps.cover?.removeFromSuperlayer()
    snaps.clean?.removeFromSuperlayer()
    snaps.cover = nil
    snaps.clean = nil
    if why == "moved", let kind = snaps.shownKind {
      log.event("whiteboard", ["action": "shape_snap_preview_off", "board": model.board.id, "kind": kind])
    }
    snaps.shownKind = nil
  }
}
