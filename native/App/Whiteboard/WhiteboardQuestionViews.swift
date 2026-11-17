//  Question cards on a board (spec 2026-11-16-whiteboard-question-cards-design.md, stories 880–886): the cards over the
//  paper, where the board puts them on screen, and the popup that answers one with Chat's decision card. They draw
//  `WhiteboardQuestionsModel`'s state and decide nothing.

import BugKit
import ContextCore
import PencilKit
import SwiftUI

/// Where the board's points are on screen, in the canvas view's points: the scale and where the board's corner is. The
/// canvas sets it as it scrolls and zooms; only the cards look at it, so a scroll redraws nothing else. With the eraser
/// in hand, a stroke over an answered card reaches the canvas, which takes the card (story 886).
@MainActor
final class WhiteboardBoardPlace: ObservableObject {
  @Published var scale: CGFloat = 1
  @Published var origin: CGPoint = .zero
  @Published var erasing = false

  func rect(_ board: CGRect) -> CGRect {
    CGRect(
      x: origin.x + board.minX * scale, y: origin.y + board.minY * scale, width: board.width * scale,
      height: board.height * scale)
  }
}

/// The board's cards, over the paper and moving with it.
struct WhiteboardQuestionCards: View {
  @ObservedObject var questions: WhiteboardQuestionsModel
  @ObservedObject var place: WhiteboardBoardPlace

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(questions.board.cards) { card in
        let frame = place.rect(WhiteboardQuestions.box(card))
        Button {
          questions.tap(card)
        } label: {
          WhiteboardQuestionCardFace(card: card, title: questions.title(of: card), scale: place.scale)
            .frame(width: frame.width, height: frame.height)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!(place.erasing && card.answered != nil))
        .accessibilityLabel(WhiteboardQuestions.lines(card, title: questions.title(of: card)).joined(separator: ", "))
        .accessibilityIdentifier("whiteboard-question-\(card.ask)")
        .position(x: frame.midX, y: frame.midY)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .clipped()
  }
}

/// One card as the web board draws it: open, a pale purple line edged in Larry's purple; answered, grey, the question
/// over the answer; folded, the question alone.
private struct WhiteboardQuestionCardFace: View {
  let card: WhiteboardQuestion
  let title: String?
  let scale: CGFloat

  private static let larry = Color(uiColor: UIColor(rgb: WhiteboardTurn.larryColor))

  var body: some View {
    let lines = WhiteboardQuestions.lines(card, title: title)
    let done = card.answered != nil
    let shape = RoundedRectangle(cornerRadius: 18 * scale)
    VStack(alignment: .leading, spacing: 1 * scale) {
      ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
        Text(line)
          .font(.system(size: max(6, size(line: i, of: lines.count) * scale)))
          .foregroundStyle(ink(line: i))
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .padding(.horizontal, 16 * scale)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(shape.fill(done ? Color(white: 0.953) : Color(red: 0.984, green: 0.957, blue: 1)))
    .overlay(shape.stroke(done ? Color(white: 0.78) : Self.larry, lineWidth: max(1, 2 * scale)))
    .contentShape(shape)
  }

  /// The web board's inks: an open card's deep purple, an answered one's grey question over its darker answer.
  private func ink(line: Int) -> Color {
    guard card.answered != nil else { return Color(red: 0.29, green: 0.12, blue: 0.36) }
    return Color(white: line == 0 ? 0.54 : 0.37)
  }

  /// The web board's sizes: an open card 19, an answered one's question 14 over the answer 13, a chip 14.
  private func size(line: Int, of count: Int) -> CGFloat {
    guard card.answered != nil else { return 19 }
    if count == 1 { return card.collapsed ? WhiteboardQuestions.chipLetters : 16 }
    return line == 0 ? 14 : 13
  }
}

/// The popup over the board: an open card's ask to answer, or an answered card read-only.
struct WhiteboardQuestionSheet: ViewModifier {
  @ObservedObject var questions: WhiteboardQuestionsModel
  let decisions: ChatDecisionsModel
  let logger: BugLogger

  func body(content: Content) -> some View {
    content.sheet(item: $questions.opened) { opened in
      WhiteboardQuestionPopup(questions: questions, decisions: decisions, logger: logger, cardID: opened.id)
    }
  }
}

private struct WhiteboardQuestionPopup: View {
  @ObservedObject var questions: WhiteboardQuestionsModel
  @ObservedObject var decisions: ChatDecisionsModel
  let logger: BugLogger
  let cardID: String
  @State private var words = ""
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          if let card = questions.board.card(cardID) {
            content(card)
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Question")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }.accessibilityIdentifier("whiteboard-question-close")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .accessibilityIdentifier("whiteboard-question-popup")
  }

  @ViewBuilder private func content(_ card: WhiteboardQuestion) -> some View {
    if let answer = card.answered, !card.needsAnswer {
      answered(card, answer)
    } else if let ask = questions.asks[card.ask] {
      ChatDecisionCard(decisions: decisions, ask: ask, place: "board", logger: logger) { verb, outcome in
        questions.decided(card, ask: ask, verb: verb, outcome: outcome)
      }
      ownWords(card, ask)
    } else if questions.reading {
      ProgressView("Loading the question…")
    } else {
      Text(
        questions.asksRead
          ? "This question is no longer open in the Cockpit (answered or closed)."
          : "The Cockpit's asks didn't load; try again."
      )
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("whiteboard-question-gone")
    }
  }

  /// Story 882: an answer in Igor's own words, for an ask with no options or one none of them fits.
  private func ownWords(_ card: WhiteboardQuestion, _ ask: ChatAsk) -> some View {
    let sending = decisions.card(ask.id).sending
    return HStack(alignment: .bottom) {
      TextField(ask.options.isEmpty ? "Your answer" : "Your own answer", text: $words, axis: .vertical)
        .lineLimit(1...4)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("whiteboard-question-words")
      Button("Send") {
        let verb = ChatDecisions.Verb.ownWords(words)
        Task {
          if let outcome = await decisions.run(verb, on: ask, from: "board") {
            questions.decided(card, ask: ask, verb: verb, outcome: outcome)
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(sending || !ChatDecisions.canSend(words: words))
      .accessibilityIdentifier("whiteboard-question-send")
    }
  }

  /// Story 885: the question and the answer in full, and the card folded from here.
  private func answered(_ card: WhiteboardQuestion, _ answer: WhiteboardQuestion.Answer) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(answer.title ?? "Answered", systemImage: "checkmark.circle")
        .font(.headline)
      if !answer.label.isEmpty { Text(answer.label).font(.body.weight(.semibold)) }
      if let note = answer.note { Text(note).foregroundStyle(.secondary) }
      Button("Collapse", systemImage: "rectangle.compress.vertical") { questions.collapse(card) }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("whiteboard-question-collapse")
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-question-answered")
  }
}

extension PaperHost: PKToolPickerObserver {
  func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) { toolChanged() }
  func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) { toolChanged() }
}

extension PaperBoardController {
  /// Where the board's corner and scale are in this view's points, for the cards over it.
  func placeCards() {
    let a = lines.convert(lines.spot(of: .zero), to: view)
    let b = lines.convert(lines.spot(of: CGPoint(x: 100, y: 100)), to: view)
    let scale = max((b.x - a.x) / 100, 0.01)
    if place.origin != a { place.origin = a }
    if place.scale != scale { place.scale = scale }
  }
}
