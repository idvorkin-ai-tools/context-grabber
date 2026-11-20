//  What a scratch-out did, shown (spec 2026-11-01-whiteboard-design.md, *Every pen gesture shows what it did (#1000)*;
//  stories 1050–1052, 1043): the struck ink flashes and fades where it was, and a zigzag that finds nothing to erase goes,
//  with *Nothing under the scribble to erase* beside where it was. Over the paper, in no picture, taking no touches.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit

/// What a scratch-out shows: the word, while it shows, and the struck ink's flash.
@MainActor
final class BoardScratchNote: ObservableObject {
  struct Shown: Equatable {
    var text: String
    /// Where the zigzag was, in the board view's points.
    var near: CGRect
  }

  /// The struck ink, in the board view's points, and the pen's width there.
  struct Flash: Equatable {
    var id = UUID()
    var path: Path
    var width: CGFloat
    /// How long it stays bright before it fades: the launch hook's, for a UI test's picture.
    var hold: Double
  }

  @Published fileprivate(set) var shown: Shown?
  @Published fileprivate(set) var flash: Flash?
  fileprivate var hiding: Task<Void, Never>?
  fileprivate var flashing: Task<Void, Never>?
}

extension PaperBoardController {
  /// Story 1050: the strokes `gone` (the zigzag's too), read from `markup` before they went, flash and fade where they
  /// were. Reduce Motion: no flash, a plain fade (the overlay's).
  func flashScratched(_ gone: Set<String>, from markup: PaperMarkup) {
    let strokes = markup.subelements.strokes.filter { gone.contains(PaperHost.key($0.elementID)) }
    guard !strokes.isEmpty else { return }
    var path = Path()
    var widest: CGFloat = 2
    for stroke in strokes {
      let points = stroke.path.map { view.convert(lines.spot(of: $0.location.applying(stroke.transform)), from: lines) }
      guard let first = points.first else { continue }
      path.move(to: first)
      for point in points.dropFirst() { path.addLine(to: point) }
      if points.count == 1 { path.addLine(to: first) }
      widest = max(widest, stroke.path.map(\.size.width).max() ?? 2)
    }
    let scale = abs(
      view.convert(lines.spot(of: CGPoint(x: 1, y: 0)), from: lines).x
        - view.convert(lines.spot(of: .zero), from: lines).x)
    let hold = LaunchHooks.current.whiteboard.feedbackSeconds ?? 0
    let flash = BoardScratchNote.Flash(path: path, width: max(3, widest * scale + 2), hold: hold)
    scratchNote.flashing?.cancel()
    scratchNote.flash = flash
    scratchNote.flashing = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(hold + 0.8))
      guard !Task.isCancelled, self?.scratchNote.flash?.id == flash.id else { return }
      self?.scratchNote.flash = nil
    }
    log.event(
      "whiteboard",
      [
        "action": "scratch_flash", "board": model.board.id, "strokes": strokes.count,
        "reduce_motion": UIAccessibility.isReduceMotionEnabled,
      ])
  }

  /// Stories 1051, 1052: a zigzag that found nothing to erase goes, as an Undo would take it (Redo brings it back), and says so
  /// beside where it was for a few seconds. When PaperKit's step for it can't be taken back, it stays ink, unsaid.
  func scratchFoundNothing(_ key: String, frame: CGRect, event: [String: Any]) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      let undo = self.paper.undoManager
      let before = self.paper.markup?.strokeFrames ?? [:]
      let could = self.takeBackPaperKitsStep(why: "scratch_nothing")
      let wanted = before.filter { $0.key != key }
      let gone = could && PaperProbe.inkChange(before: wanted, after: self.paper.markup?.strokeFrames ?? [:]).isEmpty
      if !gone {
        if could { undo?.redo() }
        if let markup = self.paper.markup { self.model.changed(markup.inkDrawing) }
      } else {
        self.sayScratchFoundNothing(near: frame)
      }
      var event = event
      event["nothing"] = gone ? "taken_away" : "kept"
      event["could_undo"] = could
      self.log.event("whiteboard", event)
    }
  }

  /// The word, over the board-point `frame` the zigzag took.
  private func sayScratchFoundNothing(near frame: CGRect) {
    let a = view.convert(lines.spot(of: CGPoint(x: frame.minX, y: frame.minY)), from: lines)
    let b = view.convert(lines.spot(of: CGPoint(x: frame.maxX, y: frame.maxY)), from: lines)
    let near = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    scratchNote.hiding?.cancel()
    scratchNote.shown = BoardScratchNote.Shown(text: "Nothing under the scribble to erase", near: near)
    let seconds = max(3, LaunchHooks.current.whiteboard.feedbackSeconds ?? 0)
    scratchNote.hiding = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.scratchNote.shown = nil
    }
  }
}

/// Story 1051: the word beside where the zigzag was, in no picture and taking no touches.
struct ScratchNoteOverlay: View {
  @ObservedObject var note: BoardScratchNote

  var body: some View {
    GeometryReader { geometry in
      if let flash = note.flash {
        ScratchFlash(flash: flash).id(flash.id)
      }
      if let shown = note.shown {
        Text(shown.text)
          .font(.subheadline.weight(.semibold))
          .padding(.vertical, 6).padding(.horizontal, 12)
          .background(.regularMaterial, in: Capsule())
          .fixedSize()
          .position(
            x: min(max(shown.near.midX, 160), max(geometry.size.width - 160, 160)),
            y: max(shown.near.minY - 24, 24)
          )
          .accessibilityIdentifier("whiteboard-scratch-nothing")
          .transition(.opacity)
      }
    }
    .allowsHitTesting(false)
  }
}

/// Stories 1050, 1043: the struck ink, bright for a moment, then fading over about half a second. Reduce Motion: no flash, it
/// shows plainly and fades.
private struct ScratchFlash: View {
  let flash: BoardScratchNote.Flash
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var opacity: Double = 0

  var body: some View {
    flash.path
      .stroke(Color.orange, style: StrokeStyle(lineWidth: flash.width, lineCap: .round, lineJoin: .round))
      .opacity(opacity)
      .accessibilityElement()
      .accessibilityLabel("Scratched out")
      .accessibilityIdentifier("whiteboard-scratch-flash")
      .task {
        if reduceMotion {
          opacity = 0.6
        } else {
          withAnimation(.easeOut(duration: 0.08)) { opacity = 1 }
        }
        try? await Task.sleep(for: .seconds(0.1 + flash.hold))
        withAnimation(.easeOut(duration: 0.45)) { opacity = 0 }
      }
  }
}
