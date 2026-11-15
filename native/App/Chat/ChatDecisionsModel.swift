//  Decision cards in Chat (#878, spec 2026-11-14-chat-decision-cards-design.md): the Cockpit's open asks, read when
//  the list, a thread or Decisions opens and after each verb, and each card's state while a verb goes and after. The
//  rules — requests, outcomes, which chat carries a card, the lines — are `ChatDecisions` in ContextCore.

import BugKit
import ContextCore
import Foundation

@MainActor
final class ChatDecisionsModel: ObservableObject {
  /// One card's state: a verb on its way, the line it gave way to, or why the last verb failed.
  struct Card: Equatable {
    var sending = false
    /// *You decided: …*, *Snoozed until …*, *Closed*, *Abandoned* or *Already answered elsewhere*: the card has gone.
    var line: String?
    /// *This decision changed since it loaded*: the card shows the ask as it now is.
    var note: String?
    var problem: BugProblem?
  }

  @Published private(set) var asks: [ChatAsk] = []
  /// Why the asks could not be read; only Decisions shows it.
  @Published private(set) var readProblem: String?
  @Published private(set) var cards: [String: Card] = [:]
  /// Asks finished from the Decisions screen while it is open, with their titles, so its card leaves a line.
  @Published private(set) var finished: [(id: String, title: String)] = []

  private let log: SessionLog
  private let inbox: InboxModel
  let cockpit: String
  private var readFailing = false
  private let transport: ChatDecisions.Transport = { request in
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode)
  }

  init(log: SessionLog, inbox: InboxModel, cockpit: String) {
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
  }

  private var reachable: Bool { !inbox.offline && cockpit != ChatCockpit.nowhere }

  func ask(on key: String) -> ChatAsk? { ChatDecisions.ask(on: key, in: asks) }

  func card(_ id: String) -> Card { cards[id] ?? Card() }

  /// Offline or with no address nothing is read and nothing shows; a failed read keeps what was shown, logged once
  /// until one succeeds.
  func refresh(reason: String) async {
    guard reachable else {
      asks = []
      readProblem = nil
      return
    }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatDecisions.listRequest(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let read = ChatDecisions.asks(data) else {
        let said = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
        return readFailed(said.map { "\($0) (HTTP \(status))" } ?? "HTTP \(status)", reason: reason)
      }
      asks = read
      readProblem = nil
      readFailing = false
    } catch is CancellationError {
    } catch let error as URLError where error.code == .cancelled {
    } catch {
      readFailed(error.localizedDescription, reason: reason)
    }
  }

  private func readFailed(_ why: String, reason: String) {
    readProblem = "Could not read the open decisions from the Cockpit: \(why)"
    guard !readFailing else { return }
    readFailing = true
    log.event("chat", ["action": "decisions_read_failed", "why": reason, "reason": why])
  }

  /// A card came on screen: in its thread or on Decisions.
  func shown(_ ask: ChatAsk, from place: String) {
    log.event(
      "chat",
      [
        "action": "decision_shown", "ask": ask.id, "from": place, "options": ask.options.count,
        "expired": ask.expired,
      ])
  }

  func openedChat(_ ask: ChatAsk) {
    log.event("chat", ["action": "decision_open_chat", "ask": ask.id])
  }

  /// A thread opened: what its card said on an earlier visit goes, unless a verb is still on its way.
  func threadOpened(_ key: String) {
    if !card(key).sending { cards[key] = nil }
  }

  /// Decisions left the screen: the lines, notes and problems of its cards go with it.
  func leftDecisions() {
    finished = []
    cards = cards.filter { $0.value.sending }
  }

  /// One verb on one card. A second tap while it goes does nothing.
  func run(_ verb: ChatDecisions.Verb, on ask: ChatAsk, from place: String) async {
    guard !card(ask.id).sending else { return }
    cards[ask.id] = Card(sending: true)
    let outcome: ChatDecisions.Outcome =
      inbox.offline
      ? .refused("the phone is offline")
      : cockpit == ChatCockpit.nowhere
        ? .refused(ChatCockpit.noAddress)
        : await ChatDecisions.run(verb, ask: ask, cockpit: cockpit, transport: transport)
    var fields: [String: Any] = ["ask": ask.id, "from": place, "outcome": outcome.logName]
    fields["action"] = { if case .answer = verb { return "decision_answer" } else { return "decision_menu" } }()
    if case .refused(let why) = outcome { fields["reason"] = why }
    // The menu's verb rides as `verb`, so it doesn't overwrite the event's own action.
    for (key, value) in verb.logFields { fields[key == "action" ? "verb" : key] = value }
    log.event("chat", fields)

    switch outcome {
    case .done(let until):
      leave(ask, line: ChatDecisions.doneLine(verb, snoozedUntil: until), from: place)
    case .alreadyAnswered:
      leave(ask, line: ChatDecisions.alreadyAnswered, from: place)
      await refresh(reason: "already_answered")
    case .changed(let fresh):
      if let fresh, let i = asks.firstIndex(where: { $0.id == ask.id }) { asks[i] = fresh }
      cards[ask.id] = Card(note: ChatDecisions.changed)
      await refresh(reason: "changed")
    case .refused(let why):
      cards[ask.id] = Card(
        problem: .grabber(
          ChatDecisions.problem(verb, why), context: "ChatDecisionCard.\(place)",
          extra: [
            "ask": .string(ask.id), "verb": .string(verb.word), "updated_at": .string(ask.updatedAt),
            "cockpit": .string(cockpit),
          ]))
    }
  }

  private func leave(_ ask: ChatAsk, line: String, from place: String) {
    cards[ask.id] = Card(line: line)
    asks.removeAll { $0.id == ask.id }
    if place == "list" { finished.append((ask.id, ask.title)) }
  }
}
