//  Searching the asks (story 1132, bead context-grabber-4dme; spec 2026-11-14-chat-decision-cards-design.md,
//  *Searching the asks*): what *Decisions* shows while the box has words — the count line, the *Answered too* tick,
//  the rows with their matched-field lines and the words highlighted, *No asks match.*, and a failed search's
//  copyable problem. They draw `ChatAskSearchModel`'s state and decide nothing.

import BugKit
import ContextCore
import SwiftUI

struct ChatAskSearchResults: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var search: ChatAskSearchModel
  let voice: ChatVoiceModel
  let logger: BugLogger
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Group {
          if let result = search.result {
            Text(result.countLine)
          } else if search.searching {
            Text("Searching…")
          }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("ask-search-count")
        Spacer(minLength: 8)
        Toggle("Answered too", isOn: $search.answeredToo)
          .toggleStyle(.button)
          .font(.footnote)
          .accessibilityIdentifier("ask-search-all")
      }
      if let problem = search.problem {
        BugProblemView(problem: problem, logger: logger)
      }
      if let result = search.result {
        ForEach(result.threads) { hit in
          row(hit, terms: result.terms)
        }
        if let empty = result.emptyLine {
          Text(empty).foregroundStyle(.secondary).accessibilityIdentifier("ask-search-empty")
        }
      }
    }
  }

  @ViewBuilder private func row(_ hit: ChatAskHit, terms: [String]) -> some View {
    let opens = ChatAskSearch.opens(hit, asks: chat.decisions.shown, known: Set(chat.threads.map(\.key)))
    switch opens {
    case .thread(let key):
      NavigationLink {
        ChatThreadView(chat: chat, voice: voice, key: key, title: hit.title, logger: logger)
          .onAppear { search.opened(hit, opens) }
      } label: {
        ChatAskHitRow(hit: hit, terms: terms)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("ask-search-row-\(hit.key)")
    case .web(let page):
      Button {
        search.opened(hit, opens)
        openURL(page)
      } label: {
        ChatAskHitRow(hit: hit, terms: terms)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("ask-search-row-\(hit.key)")
    }
  }
}

/// One ask the search found: its title with the words marked, whether it is snoozed or answered, and a line for each
/// place past the title where they matched.
struct ChatAskHitRow: View {
  let hit: ChatAskHit
  let terms: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: hit.open ? "questionmark.bubble" : "checkmark.circle")
          .foregroundStyle(hit.open ? Color.orange : .secondary)
        Text(Self.marked(hit.title, terms)).font(.body.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 4)
        if let state = state {
          Text(state).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
      }
      ForEach(Array(hit.matches.enumerated()), id: \.offset) { _, match in
        Text(Self.line(match, terms)).font(.footnote).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("ask-search-match")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }

  private var state: String? {
    if !hit.open { return "Answered" }
    return hit.snoozedUntil == nil ? nil : "Snoozed"
  }

  /// A matched-field line: the field's word in small capitals, then the snippet with the words marked.
  static func line(_ match: ChatAskHit.Match, _ terms: [String]) -> AttributedString {
    var label = AttributedString(match.label.uppercased() + "  ")
    label.font = .caption2.weight(.semibold)
    return label + marked(match.snippet, terms)
  }

  /// The words marked as the Cockpit's Inbox marks them: every place, case ignored.
  static func marked(_ text: String, _ terms: [String]) -> AttributedString {
    var out = AttributedString()
    for piece in ChatAskSearch.pieces(text, terms: terms) {
      var run = AttributedString(piece.text)
      if piece.hit {
        run.backgroundColor = Color.yellow.opacity(0.45)
        run.inlinePresentationIntent = .stronglyEmphasized
      }
      out += run
    }
    return out
  }
}
