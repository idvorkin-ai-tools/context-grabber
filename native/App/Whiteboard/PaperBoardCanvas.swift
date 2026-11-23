//  The board on paper in SwiftUI: the canvas with its page number, and the buttons over it (Keep and Dismiss, the hold
//  menu, a paste's Delete). Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import SwiftUI
import UIKit

/// The board on paper with its page number, which floats over it and isn't in any picture.
struct PaperBoardCanvas: View {
  @ObservedObject var model: WhiteboardModel
  @StateObject private var controller: PaperBoardController

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    _controller = StateObject(wrappedValue: PaperBoardController(model: model, log: log))
  }

  var body: some View {
    PaperBoardHost(
      controller: controller, paper: model.paper, ghosts: model.ghosts, chosen: model.chosen?.id,
      rules: model.gridOn ? .grid : model.ruledOn ? .ruled : .none
    )
    .overlay {
      if model.editable { WhiteboardQuestionCards(questions: model.questions, place: controller.place) }
    }
    .overlay { BoardHeaderMarks(controller: controller, place: controller.place) }
    .overlay { MarkChoiceButtons(model: model, mark: controller.choiceFrame) }
    .overlay { PastedButtons(controller: controller, pasted: controller.pastedFrame) }
    .overlay { SelectionLabelView(state: controller.selectionLabel) }
    .overlay { ToTextButton(controller: controller, state: controller.toText) }
    .overlay { ConnectButton(controller: controller, arrow: controller.connectFrame, toText: controller.toText) }
    .overlay { RewordField(controller: controller, state: controller.reword) }
    .overlay { RoomBandOverlay(state: controller.roomBand) }
    .overlay { ScratchNoteOverlay(note: controller.scratchNote) }
    .overlay { HoldMenuButtons(controller: controller, menu: controller.holdMenu) }
    .overlay(alignment: .topTrailing) {
      Text(controller.pageText).font(.footnote.monospacedDigit())
        // Story 673. On this text, not Send: a toolbar button drops its accessibility value (iOS 27 simulator).
        .accessibilityValue(model.dirty ? "unsaved" : "saved")
        // The board's own name for a UI test, here rather than over the whole view: there it named every element on the
        // board, Keep and Dismiss too, which their tests then never found (the iPad simulator, 2026-11-14).
        .accessibilityIdentifier("whiteboard")
        .padding(.vertical, 4).padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
    }
  }
}

private struct PaperBoardHost: UIViewControllerRepresentable {
  let controller: PaperBoardController
  let paper: BoardPaper
  let ghosts: [Ghost]
  /// The chosen mark: a change places its Keep and Dismiss.
  let chosen: String?
  let rules: PaperRules

  func makeUIViewController(context: Context) -> PaperBoardController { controller }

  func updateUIViewController(_ controller: PaperBoardController, context: Context) {
    controller.setBoardPaper(paper)
    controller.setRules(rules)
    controller.show(ghosts)
  }

  static func dismantleUIViewController(_ controller: PaperBoardController, coordinator: ()) {
    controller.boardClosed()
  }
}

/// Story 825 (#883): Keep and Dismiss beside the chosen mark, wholly on screen. Over the board, not in it, so a tap on
/// them never reaches the board as a tap off the marks. Stories 995 and 1000 (#942): Keep group between them when more of the
/// mark's reply of Larry's shows; each button at least 36 points each way, the capsule taking every tap within it, and
/// never under the board's top-right corner.
private struct MarkChoiceButtons: View {
  @ObservedObject var model: WhiteboardModel
  let mark: CGRect?
  private static let height: CGFloat = 48

  var body: some View {
    GeometryReader { geometry in
      if let mark {
        let group = model.chosenReplyCount
        let size = CGSize(width: group > 1 ? 400 : 210, height: Self.height)
        let origin = geometry.frame(in: .global).origin
        let place = WhiteboardMarkChoice.place(
          mark: mark, buttons: size, in: CGRect(origin: .zero, size: geometry.size),
          avoid: model.cornerFrame.offsetBy(dx: -origin.x, dy: -origin.y))
        HStack(spacing: 4) {
          Button(action: model.keepChosen) { Self.label("Keep", "checkmark") }
            .accessibilityIdentifier("whiteboard-mark-keep")
          if group > 1 {
            Button(action: model.keepChosenReply) { Self.label("Keep group · \(group)", "square.on.square") }
              .accessibilityHint("Keeps all \(group) marks of this reply of Larry's as one group that moves together")
              .accessibilityIdentifier("whiteboard-mark-keep-group")
          }
          Button(action: model.dismissChosen) { Self.label("Dismiss", "xmark") }
            .accessibilityIdentifier("whiteboard-mark-dismiss")
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .lineLimit(1)
        .frame(width: place.width, height: place.height)
        .background(.regularMaterial, in: Capsule())
        // A tap between the buttons lands on the capsule, never on the paper under it.
        .contentShape(Capsule())
        .onTapGesture {}
        .position(x: place.midX, y: place.midY)
      }
    }
  }

  /// A button's whole face, at least 36 points each way, takes its tap (#933: a bare glyph let taps through).
  private static func label(_ title: String, _ image: String) -> some View {
    Label(title, systemImage: image).frame(minWidth: 36, minHeight: 36).contentShape(Rectangle())
  }
}

/// Story 858: what a held finger offers; its rows by what the finger is on (stories 1186, 1187), from ContextCore.
struct HoldMenu: Equatable {
  typealias Item = BoardHoldChoice

  /// Where the finger was, in the board view's points, and board `y`.
  var spot: CGPoint
  var y: CGFloat
  var items: [Item]
  /// The thing under the finger, by its strokes' names, that Select and Delete take.
  var names: [String] = []
  var on = "paper"
}

/// The hold menu's rows in a column beside the finger, each with its icon, kept on screen (stories 874, 1186).
private struct HoldMenuButtons: View {
  let controller: PaperBoardController
  let menu: HoldMenu?
  private static let width: CGFloat = 200
  private static let rowHeight: CGFloat = 44

  var body: some View {
    GeometryReader { geometry in
      if let menu {
        let levels = menu.items.filter { $0.symbol == nil }
        let rows = menu.items.filter { $0.symbol != nil }
        let height = CGFloat(rows.count + (levels.isEmpty ? 0 : 1)) * Self.rowHeight + 12
        VStack(alignment: .leading, spacing: 0) {
          ForEach(rows, id: \.id) { item in
            Button(role: item == .delete ? .destructive : nil) {
              controller.chose(item)
            } label: {
              Label(item.title, systemImage: item.symbol ?? "")
                .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("whiteboard-hold-\(item.id)")
          }
          if !levels.isEmpty {
            HStack(spacing: 4) {
              Text("Collapse to").foregroundStyle(.secondary)
              ForEach(levels, id: \.id) { item in
                Button(item.title) { controller.chose(item) }
                  .buttonStyle(.bordered)
                  .accessibilityIdentifier("whiteboard-hold-\(item.id)")
              }
            }
            .frame(minHeight: Self.rowHeight)
          }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(width: Self.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6)
        .position(
          x: min(max(menu.spot.x + Self.width / 2 + 16, Self.width / 2 + 8), geometry.size.width - Self.width / 2 - 8),
          y: min(max(menu.spot.y, height / 2 + 8), geometry.size.height - height / 2 - 8))
      }
    }
  }
}

/// Story 852: Delete beside a paste that just landed, selected.
private struct PastedButtons: View {
  let controller: PaperBoardController
  let pasted: CGRect?
  private static let size = CGSize(width: 104, height: 44)

  var body: some View {
    GeometryReader { geometry in
      if let pasted {
        let place = WhiteboardMarkChoice.place(
          mark: pasted, buttons: Self.size, in: CGRect(origin: .zero, size: geometry.size))
        Button("Delete", systemImage: "trash", role: .destructive) { controller.deletePasted() }
          .accessibilityIdentifier("whiteboard-paste-delete")
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.bordered)
          .controlSize(.small)
          .frame(width: Self.size.width, height: Self.size.height)
          .background(.regularMaterial, in: Capsule())
          .position(x: place.midX, y: place.midY)
      }
    }
  }
}
