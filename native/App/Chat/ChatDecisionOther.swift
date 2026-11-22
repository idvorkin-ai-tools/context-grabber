//  Other on a decision card (story 1128, bead context-grabber-sm4l; spec 2026-11-14-chat-decision-cards-design.md,
//  *Other*): the field that answers an ask in Igor's own words, typed or dictated with Chat's mic beside *Send*, sent as
//  the board's own answer is (`ChatDecisions.Verb.ownWords`). It draws and hands back; the card sends.

import BugKit
import ContextCore
import SwiftUI

/// The card's *Other…*: Igor's words for an ask, typed or spoken.
struct ChatDecisionOtherField: View {
  @ObservedObject var voice: ChatVoiceModel
  let ask: ChatAsk
  @Binding var words: String
  let sending: Bool
  let logger: BugLogger
  let send: () -> Void

  var body: some View {
    let thread = Self.voiceThread(ask)
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .bottom, spacing: 8) {
        TextField("Your own answer", text: $words, axis: .vertical)
          .lineLimit(1...4)
          .textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("decision-other-words")
        MicButton(voice: voice, thread: thread, draft: words, identifier: "decision-other-mic")
        Button {
          voice.sent(thread: thread)
          send()
        } label: {
          Text("Send").frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(sending || !ChatDecisions.canSend(words: words))
        .accessibilityIdentifier("decision-other-send")
      }
      // What the mic could not do, copyable, and its quieter line (a call or another recording has the mic).
      if voice.thread == thread, let problem = voice.problem(context: "ChatDecisionOtherField.voice") {
        BugProblemView(problem: problem, logger: logger)
      }
      if voice.thread == thread, let notice = voice.notice {
        Text(notice).font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("decision-other-voice-notice")
      }
    }
    // The words stream into the field as Igor speaks, after what was typed, for him to read before he sends.
    .onChange(of: voice.words) { _, _ in
      if let heard = voice.take(thread: thread) { words = heard }
    }
    .onDisappear { voice.cancel(thread: thread, why: "left_decision") }
  }

  /// The mic's key for this field: its own, so the thread's message bar never takes these words, nor this field the bar's.
  static func voiceThread(_ ask: ChatAsk) -> String { "decision-other:\(ask.id)" }
}

/// The card's own *Other…* button, drawn as its options are.
struct ChatDecisionOtherButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Other…").font(.body.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.bordered)
    .accessibilityIdentifier("decision-other")
  }
}
