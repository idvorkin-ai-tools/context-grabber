//  The band the room handle shows while held (spec 2026-11-01-whiteboard-design.md, *Every pen gesture shows what it
//  did (#1000)*; stories 1044–1046): from the moment a margin hold becomes the handle until the finger or the Pencil
//  lifts, a see-through band where the room a lift would open (or close) lies, with up and down arrows and a chip. What
//  it shows is `BoardRoomBand` in ContextCore, `BoardRoom.byHand`'s own answer, so the lift does what the band said.

import ContextCore
import PencilKit
import SwiftUI
import UIKit

/// The handle's band while it is held, and the Pencil's margin touch it watches.
@MainActor
final class BoardRoomBandState: ObservableObject {
  struct Shown: Equatable {
    var band: BoardRoomBand
    /// The band in the board view's points: the page's width, from the band's top, at least a hairline tall.
    var frame: CGRect
    /// The margin's width in the board view's points, where the arrows sit.
    var margin: CGFloat
  }

  @Published fileprivate(set) var shown: Shown?
  /// Where the handle went down, board `y`, which tool holds it, and the ink boxes a push moves whole, read once.
  fileprivate var held: (y: CGFloat, tool: String, boxes: [CGRect])?
  /// The Pencil's touch in the margin and its path so far, board points and seconds: the handle once it has held.
  fileprivate var pencil: (touch: ObjectIdentifier, path: [(point: CGPoint, time: Double)])?
  fileprivate var waiting: Task<Void, Never>?
  fileprivate var lingering: Task<Void, Never>?
}

extension PaperBoardController {
  /// The handle fired at board `y`: the band shows at once, a thin line until the drag reaches half a line.
  func roomBandBegan(at y: CGFloat, tool: String) {
    guard model.editable, let markup = paper.markup else { return }
    let (strokes, _) = opStrokes(markup)
    let tags = model.outline(of: strokes).tags
    let boxes = BoardOps.shownBoxes(strokes: strokes, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    roomBand.lingering?.cancel()
    roomBand.held = (y, tool, boxes)
    roomBandMoved(dy: 0)
    log.event("board_room", ["action": "band_shown", "board": model.board.id, "tool": tool, "y": Double(y)])
  }

  /// The handle dragged `dy` board points from where it went down.
  func roomBandMoved(dy: CGFloat) {
    guard let held = roomBand.held else { return }
    let band = BoardRoomBand.held(held.boxes, at: held.y, dy: dy)
    let scale = lines.spot(of: CGPoint(x: 1, y: 0)).x
    let page = lines.convert(lines.bounds, to: view)
    let top = lines.convert(lines.spot(of: CGPoint(x: 0, y: band.top)), to: view).y
    let frame = CGRect(x: page.minX, y: top, width: page.width, height: max(band.height * scale, 2))
    let shown = BoardRoomBandState.Shown(band: band, frame: frame, margin: BoardMargin.width * scale)
    if roomBand.shown != shown { roomBand.shown = shown }
  }

  /// The handle lifted, or became the menu: the band goes (after the launch hook's linger, for a UI test's picture).
  func roomBandEnded(why: String) {
    roomBand.waiting?.cancel()
    roomBand.waiting = nil
    roomBand.pencil = nil
    guard let held = roomBand.held else { return }
    roomBand.held = nil
    let band = roomBand.shown?.band
    log.event(
      "board_room",
      [
        "action": "band_hidden", "board": model.board.id, "tool": held.tool, "why": why,
        "kind": band?.kind.rawValue ?? "none", "lines": band?.lines ?? 0,
      ])
    let linger = LaunchHooks.current.whiteboard.feedbackSeconds ?? 0
    guard linger > 0 else {
      roomBand.shown = nil
      return
    }
    roomBand.lingering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(linger))
      guard !Task.isCancelled else { return }
      self?.roomBand.shown = nil
    }
  }

  /// The Pencil went down in the margin: once it has held still there for half a second, off a header's mark, the band
  /// shows, as the stroke's own verdict will find when it lifts.
  func roomBandPencilDown(_ touch: UITouch, at point: CGPoint) {
    guard model.editable, paper.drawingTool is PKInkingTool else { return }
    roomBand.pencil = (ObjectIdentifier(touch), [(point, touch.timestamp)])
    roomBand.waiting?.cancel()
    roomBand.waiting = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(BoardMargin.holdAfter))
      guard !Task.isCancelled, let self, let pencil = self.roomBand.pencil, let start = pencil.path.first,
        let last = pencil.path.last
      else { return }
      let now = ProcessInfo.processInfo.systemUptime
      guard case .hold = BoardMarginHold.pencil(pencil.path + [(last.point, max(now, last.time))]) else { return }
      let strokes = self.paper.markup.map { self.opStrokes($0).strokes } ?? []
      guard self.model.outline(of: strokes).header(at: start.point.y) == nil else { return }
      self.roomBandBegan(at: start.point.y, tool: "pencil")
      self.roomBandMoved(dy: last.point.y - start.point.y)
    }
  }

  /// The Pencil moved: before the hold it may stop being one; after, the drag moves the band.
  func roomBandPencilMoved(_ touch: UITouch, at point: CGPoint) {
    guard var pencil = roomBand.pencil, pencil.touch == ObjectIdentifier(touch), let start = pencil.path.first else {
      return
    }
    pencil.path.append((point, touch.timestamp))
    roomBand.pencil = pencil
    if roomBand.held != nil {
      roomBandMoved(dy: point.y - start.point.y)
    } else if case .moved = BoardMarginHold.pencil(pencil.path) {
      roomBand.waiting?.cancel()
      roomBand.pencil = nil
    }
  }

  /// A touch lifted: the Pencil's band goes with it.
  func roomBandPencilLifted(_ touch: UITouch) {
    guard roomBand.pencil?.touch == ObjectIdentifier(touch) else { return }
    roomBandEnded(why: "lifted")
  }
}

/// Stories 1044–1046: the band over the board, in no picture and taking no touches.
struct RoomBandOverlay: View {
  @ObservedObject var state: BoardRoomBandState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let shown = state.shown {
        let frame = shown.frame
        Rectangle()
          .fill(Color.accentColor.opacity(0.12))
          .overlay(alignment: .top) { Rectangle().fill(Color.accentColor.opacity(0.55)).frame(height: 2) }
          .overlay(alignment: .bottom) { Rectangle().fill(Color.accentColor.opacity(0.55)).frame(height: 2) }
          .frame(width: frame.width, height: frame.height)
          .offset(x: frame.minX, y: frame.minY)
        HStack(spacing: 8) {
          VStack(spacing: 2) {
            Image(systemName: "arrow.up")
            Image(systemName: "arrow.down")
          }
          .font(.title2.weight(.semibold))
          .foregroundStyle(Color.accentColor.opacity(0.6))
          .frame(width: max(shown.margin, 28))
          Text(shown.band.label)
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 6).padding(.horizontal, 12)
            .background(.regularMaterial, in: Capsule())
        }
        .offset(x: frame.minX, y: frame.minY + max(frame.height, 2) / 2 - 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shown.band.label)
        .accessibilityValue("\(shown.band.lines) lines")
        .accessibilityIdentifier("whiteboard-room-band")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .allowsHitTesting(false)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: state.shown?.band)
  }
}
