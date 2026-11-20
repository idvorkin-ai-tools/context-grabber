//  What a scratch-out did, shown (spec 2026-11-01-whiteboard-design.md, *Every pen gesture shows what it did (#1000)*;
//  stories 1047, 1048): the struck ink flashes and fades where it was, and a zigzag that finds nothing to erase goes,
//  with *Nothing under the scribble to erase* beside where it was. Over the paper, in no picture, taking no touches.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit

/// The scratch-out's word, while it shows.
@MainActor
final class BoardScratchNote: ObservableObject {
  struct Shown: Equatable {
    var text: String
    /// Where the zigzag was, in the board view's points.
    var near: CGRect
  }

  @Published fileprivate(set) var shown: Shown?
  fileprivate var hiding: Task<Void, Never>?
}

/// The struck ink's ghost: one tinted path per stroke, fading. A view, not a bare layer, so a UI test can find it.
final class ScratchFlashView: UIView {
  init(frame: CGRect, path: CGPath, width: CGFloat) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = true
    accessibilityIdentifier = "whiteboard-scratch-flash"
    accessibilityLabel = "Scratched out"
    let shape = CAShapeLayer()
    shape.frame = bounds
    shape.path = path
    shape.fillColor = nil
    shape.strokeColor = UIColor.systemOrange.cgColor
    shape.lineWidth = width
    shape.lineCap = .round
    shape.lineJoin = .round
    layer.addSublayer(shape)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("not from a storyboard") }
}

extension PaperBoardController {
  /// Story 1047: the strokes `gone` (the zigzag's too), read from `markup` before they went, flash and fade where they
  /// were. Reduce Motion: no flash, a plain fade.
  func flashScratched(_ gone: Set<String>, from markup: PaperMarkup) {
    let strokes = markup.subelements.strokes.filter { gone.contains(PaperHost.key($0.elementID)) }
    guard !strokes.isEmpty else { return }
    let path = CGMutablePath()
    var widths: [CGFloat] = []
    for stroke in strokes {
      let points = stroke.path.map { view.convert(lines.spot(of: $0.location.applying(stroke.transform)), from: lines) }
      guard let first = points.first else { continue }
      path.move(to: first)
      for point in points.dropFirst() { path.addLine(to: point) }
      if points.count == 1 { path.addLine(to: first) }
      widths.append(stroke.path.map(\.size.width).max() ?? 2)
    }
    let scale = lines.spot(of: CGPoint(x: 1, y: 0)).x
    let width = max(3, (widths.max() ?? 2) * scale + 2)
    let flash = ScratchFlashView(frame: view.bounds, path: path, width: width)
    view.addSubview(flash)
    let still = UIAccessibility.isReduceMotionEnabled
    let hold = LaunchHooks.current.whiteboard.feedbackSeconds ?? 0
    flash.alpha = still ? 0.6 : 0
    if !still {
      // The flash: up bright at once, then the fade.
      UIView.animate(withDuration: 0.08) { flash.alpha = 1 }
    }
    UIView.animate(withDuration: 0.45, delay: 0.1 + hold, options: [.curveEaseOut]) {
      flash.alpha = 0
    } completion: { _ in
      flash.removeFromSuperview()
    }
    log.event(
      "whiteboard",
      ["action": "scratch_flash", "board": model.board.id, "strokes": strokes.count, "reduce_motion": still])
  }

  /// Story 1048: a zigzag that found nothing to erase goes, as an Undo would take it (Redo brings it back), and says so
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
    let scale = lines.spot(of: CGPoint(x: 1, y: 0)).x
    let origin = view.convert(lines.spot(of: frame.origin), from: lines)
    let near = CGRect(origin: origin, size: CGSize(width: frame.width * scale, height: frame.height * scale))
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

/// Story 1048: the word beside where the zigzag was, in no picture and taking no touches.
struct ScratchNoteOverlay: View {
  @ObservedObject var note: BoardScratchNote

  var body: some View {
    GeometryReader { geometry in
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
