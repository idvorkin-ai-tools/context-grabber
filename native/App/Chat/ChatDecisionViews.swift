//  Decision cards in Chat (#878, spec 2026-11-14-chat-decision-cards-design.md): the card, drawn in its thread and on
//  Decisions, its ⋯ menu, and the Decisions screen. They draw `ChatDecisionsModel`'s state and decide nothing.

import BugKit
import ContextCore
import SwiftUI

/// The top of a thread: its ask's card, or the line the card gave way to; nothing for a thread with neither.
struct ChatDecisionSlot: View {
  @ObservedObject var decisions: ChatDecisionsModel
  let key: String
  let logger: BugLogger

  var body: some View {
    if let ask = decisions.ask(on: key) {
      ChatDecisionCard(decisions: decisions, ask: ask, place: "thread", logger: logger)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    } else if let line = decisions.card(key).line {
      ChatDecisionLine(text: line)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }
  }
}

/// What a card gave way to: *You decided: …* and the rest.
struct ChatDecisionLine: View {
  let text: String

  var body: some View {
    Label(text, systemImage: "checkmark.circle")
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("decision-line")
  }
}

struct ChatDecisionCard: View {
  @ObservedObject var decisions: ChatDecisionsModel
  let ask: ChatAsk
  /// thread or list, for the log and the problem's context.
  let place: String
  let logger: BugLogger
  @State private var contextOpen = false
  @State private var closing = false
  @State private var closeReason = ""

  private var state: ChatDecisionsModel.Card { decisions.card(ask.id) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Image(systemName: "questionmark.bubble").foregroundStyle(.orange)
        Text(ask.title).font(.headline).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        menu
      }
      if !ask.context.isEmpty {
        Text(ask.context)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(contextOpen ? nil : 3)
          .onTapGesture { contextOpen.toggle() }
          .accessibilityIdentifier("decision-context")
      }
      ForEach(ask.options) { option in
        Button {
          go(.answer(option))
        } label: {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
              Text(option.label).font(.body.weight(.semibold))
              if !option.detail.isEmpty {
                Text(option.detail).font(.caption).foregroundStyle(.secondary)
              }
            }
            Spacer(minLength: 8)
            if let mark = ask.marked, mark.key == option.key {
              Text(mark.word).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .multilineTextAlignment(.leading)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("decision-option-\(option.key)")
      }
      if let expiry = ChatDecisions.expiry(ask.expiresAt, now: Date()) {
        Text(expiry.text).font(.caption).foregroundStyle(expiry.expired ? Color.orange : .secondary)
          .accessibilityIdentifier("decision-expiry")
      }
      if let note = state.note {
        Text(note).font(.footnote).foregroundStyle(.orange).accessibilityIdentifier("decision-note")
      }
      if let problem = state.problem {
        BugProblemView(problem: problem, logger: logger)
      }
    }
    .disabled(state.sending)
    .opacity(state.sending ? 0.6 : 1)
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("decision-card-\(ask.id)")
    .task(id: ask.id) { decisions.shown(ask, from: place) }
    .alert("Close this decision", isPresented: $closing) {
      TextField("What finished it", text: $closeReason)
      Button("Close") { go(.close(reason: closeReason)) }
        .disabled(!ChatDecisions.canClose(reason: closeReason))
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("One line, and it goes to Larry.")
    }
  }

  private var menu: some View {
    Menu {
      Menu("Snooze") {
        ForEach(ChatDecisions.Snooze.allCases, id: \.self) { preset in
          Button(preset.label) { go(.snooze(preset)) }
        }
      }
      Button("Close…") {
        closeReason = ""
        closing = true
      }
      Menu("Abandon") {
        ForEach(ChatDecisions.abandonReasons, id: \.self) { reason in
          Button(reason) { go(.abandon(reason: reason)) }
        }
        Button("No reason") { go(.abandon(reason: nil)) }
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
    }
    .accessibilityIdentifier("decision-menu")
  }

  private func go(_ verb: ChatDecisions.Verb) {
    Task { await decisions.run(verb, on: ask, from: place) }
  }
}

/// The list's *Decisions (N)* row, under Larry's pinned thread.
struct ChatDecisionsRow: View {
  let count: Int

  var body: some View {
    Label("Decisions (\(count))", systemImage: "checklist")
      .font(.body.weight(.semibold))
      .foregroundStyle(.orange)
  }
}

/// Every open ask as a card: answerable here, each with its chat a tap away.
struct ChatDecisionsView: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var decisions: ChatDecisionsModel
  let voice: ChatVoiceModel
  let logger: BugLogger

  init(chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.decisions = chat.decisions
    self.voice = voice
    self.logger = logger
  }

  var body: some View {
    // A scroll view, not a List: a List row holding a link takes every tap on its buttons for the link.
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        if let problem = decisions.readProblem {
          BugProblemView(
            problem: .grabber(problem, context: "ChatDecisionsView.refresh", extra: ["cockpit": .string(chat.cockpit)]),
            logger: logger)
        }
        ForEach(decisions.asks) { ask in
          VStack(alignment: .leading, spacing: 4) {
            ChatDecisionCard(decisions: decisions, ask: ask, place: "list", logger: logger)
            NavigationLink {
              ChatThreadView(chat: chat, voice: voice, key: ask.id, title: ask.title, logger: logger)
                .onAppear { decisions.openedChat(ask) }
            } label: {
              Label("Open chat", systemImage: "bubble.left.and.bubble.right").font(.footnote)
            }
            .accessibilityIdentifier("decision-open-chat-\(ask.id)")
            .padding(.leading, 12)
          }
        }
        ForEach(decisions.finished, id: \.id) { done in
          VStack(alignment: .leading, spacing: 2) {
            Text(done.title).font(.subheadline).foregroundStyle(.secondary)
            if let line = decisions.card(done.id).line { ChatDecisionLine(text: line) }
          }
          .padding(.horizontal, 12)
        }
        if decisions.asks.isEmpty && decisions.finished.isEmpty && decisions.readProblem == nil {
          Text("No decisions waiting.").foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Decisions")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("chat-decisions-list")
    .refreshable { await decisions.refresh(reason: "pull") }
    .task { await decisions.refresh(reason: "decisions") }
    .onDisappear { decisions.clearFinished() }
    .chatTextSize()
  }
}
