//  Stories 1040, 1041 (#1004; spec 2026-11-19-whiteboard-ink-headers-design.md, *Seeing the headers*): each header's
//  ▾ (▸ and its lines, folded) over the ink in one spot at the margin's left, standing on the line's baseline, and a
//  brief tint over a line the moment it becomes a header. Over the canvas, not on its paper, so the # that made a header
//  never hides its ▾. Taps go through to the canvas: the margin tap there folds, as before.

import ContextCore
import SwiftUI

/// A line just made a header, tinted for a moment: its row, board points.
struct HeaderTint: Equatable {
  var header: String
  var box: CGRect
}

extension PaperBoardController {
  /// How long a new header's tint stays before it fades.
  static let tintSeconds = 1.2

  /// The headers' marks as the outline has them now.
  func showHeaderMarks(_ outline: BoardOutline) {
    let marks = outline.headerMarks
    if marks != headerMarks { headerMarks = marks }
  }

  /// The headers `outline` has that `before` didn't, or that a # took a level deeper (#1034): the newest one's row
  /// tints, then fades (story 1040). `before` is each header's level before the change.
  func tintNew(_ outline: BoardOutline, before: [String: Int]) {
    guard let made = outline.headers.last(where: { h in before[h.id].map { outline.level(h) > $0 } ?? true }),
      let box = outline.box(made)
    else {
      return
    }
    let tint = HeaderTint(header: made.id, box: box.insetBy(dx: -6, dy: -4))
    headerTint = tint
    log.event(
      "board_outline",
      [
        "action": "header_tint", "board": model.board.id, "header": made.id, "y": round(box.midY),
        "level": outline.level(made),
        "baseline": outline.baseline(made).map { Double(round($0)) } ?? -1,
      ])
    tinting?.cancel()
    tinting = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(Self.tintSeconds))
      guard !Task.isCancelled, let self, self.headerTint == tint else { return }
      self.headerTint = nil
    }
  }
}

/// The margin's header marks and a new header's tint, over the ink and moving with the board.
struct BoardHeaderMarks: View {
  @ObservedObject var controller: PaperBoardController
  @ObservedObject var place: WhiteboardBoardPlace

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let tint = controller.headerTint {
        let frame = place.rect(tint.box)
        RoundedRectangle(cornerRadius: 6 * place.scale)
          .fill(Color.accentColor.opacity(0.22))
          .frame(width: frame.width, height: frame.height)
          .position(x: frame.midX, y: frame.midY)
          .transition(.opacity)
          .accessibilityElement()
          .accessibilityLabel("Header made")
          .accessibilityIdentifier("whiteboard-header-tint")
      }
      ForEach(controller.headerMarks, id: \.header) { mark in
        let frame = place.rect(mark.box)
        let corner = 6 * place.scale
        // A chevron as bold as the line's own ink, not the font's small ▾ (#1004: "roughly 10 pt" and grey).
        HStack(spacing: 2 * place.scale) {
          Image(systemName: mark.folded ? "chevron.right" : "chevron.down")
          // The folded lines, then a deeper header's #s (#1034): "▸ 4 ##" shows 4 and ##.
          let words = mark.text.split(separator: " ").dropFirst().joined(separator: " ")
          if !words.isEmpty { Text(words) }
        }
        .font(.system(size: 13 * place.scale, weight: .bold))
        .foregroundStyle(Color.primary.opacity(0.7))
        .frame(width: frame.width, height: frame.height)
        .background(
          RoundedRectangle(cornerRadius: corner).fill(Color(uiColor: controller.paperColor).opacity(0.92))
        )
        .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
        .position(x: frame.midX, y: frame.midY)
        .accessibilityElement()
        .accessibilityLabel(mark.folded ? "Folded header" : "Header")
        .accessibilityValue(mark.text)
        .accessibilityIdentifier("whiteboard-margin-header-\(mark.header)")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .clipped()
    .allowsHitTesting(false)
    .animation(.easeOut(duration: 0.5), value: controller.headerTint)
  }
}
