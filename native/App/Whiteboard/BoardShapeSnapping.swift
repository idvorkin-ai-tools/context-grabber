//  Shapes that snap on paper (spec 2026-11-16-whiteboard-to-text-and-snap-design.md, stories 923–925; the web board's
//  shape cleanup): a stroke the Pencil was held still at the end of, for half a second, that is nearly a line, a
//  rectangle or an ellipse, swapped for the clean shape as it lands, one undo back to the raw ink. The recogniser and the
//  hold's rule are `BoardShapeSnap` in ContextCore. ponytail: it lands on lift; the web board shows it clean while the
//  pen is still down (upgrade: draw the shape in `PaperLines` once the hold is seen, if the iPad wants it).

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
    case .moved:
      guard snaps.touch == id else { return }
      snaps.hold?.moved(to: point, at: touch.timestamp)
    case .lifted:
      guard snaps.touch == id, var hold = snaps.hold else { return }
      snaps.hold = nil
      snaps.touch = nil
      guard touch.phase != .cancelled, hold.held(liftedAt: point, time: touch.timestamp) else { return }
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
}
