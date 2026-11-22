//  Folding a decision card (spec 2026-11-14-chat-decision-cards-design.md, *Folding a card*; story 1130, bead
//  context-grabber-fjh0): every card in Chat folds to one line and opens again, the fold kept per ask on the device.
//  Its own file, so the card's own file grows by its one control.

import BugKit
import ContextCore
import SwiftUI

/// A card in Chat, in its thread or on Decisions: whole, with its fold control, or folded to its line.
struct ChatDecisionFoldable: View {
  @ObservedObject var decisions: ChatDecisionsModel
  let ask: ChatAsk
  let place: String
  let voice: ChatVoiceModel?
  let logger: BugLogger
  @State private var contextOpen = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if decisions.folds.isFolded(ask.id) {
        ChatDecisionFoldedLine(ask: ask) { fold(false) }
      } else {
        ChatDecisionCard(
          decisions: decisions, ask: ask, place: place, voice: voice, logger: logger, contextOpen: $contextOpen,
          fold: { fold(true) })
      }
    }
    #if targetEnvironment(simulator)
      .task(id: ask.id) {
        guard ProcessInfo.processInfo.environment["GRABBER_CHAT_DECISION_FOLD"] == ask.id else { return }
        fold(true)
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        fold(false)
      }
    #endif
  }

  private func fold(_ folded: Bool) { decisions.fold(ask, folded, from: place) }
}

/// The folded card: its question on one line, a tap away from the whole card.
struct ChatDecisionFoldedLine: View {
  let ask: ChatAsk
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "questionmark.bubble").foregroundStyle(.orange)
        Text(ask.title).font(.headline).foregroundStyle(.primary).lineLimit(1).truncationMode(.tail)
        Spacer(minLength: 8)
        Image(systemName: "chevron.down").foregroundStyle(.secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(ask.title)
    .accessibilityValue("Folded")
    .accessibilityHint("Opens the decision")
    .accessibilityIdentifier("decision-folded-\(ask.id)")
  }
}

/// The card's fold control, beside its ⋯.
struct ChatDecisionFoldButton: View {
  let fold: () -> Void

  var body: some View {
    Button(action: fold) {
      Label("Fold", systemImage: "chevron.up").labelStyle(.iconOnly)
    }
    .accessibilityIdentifier("decision-fold")
  }
}
