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
    /// The chat the ask continued, so its thread finds the line once the ask has left the list.
    var thread: String?
  }

  @Published private(set) var asks: [ChatAsk] = []
  /// Why the asks could not be read; only Decisions shows it.
  @Published private(set) var readProblem: String?
  @Published private(set) var cards: [String: Card] = [:]
  /// Asks finished from the Decisions screen while it is open, with their titles, so its card leaves a line.
  @Published private(set) var finished: [(id: String, title: String)] = []
  /// Story 1130: the asks whose cards Igor folded to one line, kept on this device until he opens them.
  @Published private(set) var folds = ChatDecisionFolds(
    UserDefaults.standard.stringArray(forKey: ChatDecisionsModel.foldsKey) ?? [])
  static let foldsKey = "chat_decision_folds"

  private let log: SessionLog
  private let inbox: InboxModel
  let cockpit: String
  private var readFailing = false
  /// Counts the verbs that changed the asks here; a read that began before one is dropped, so it can't bring back an
  /// ask the verb has just taken away (#911 review).
  private var changes = 0
  /// The Cockpit wrote Igor's row into this thread: read it again, so the message is there as the card leaves.
  var readThread: (String) async -> Void = { _ in }
  private let transport: ChatDecisions.Transport = { request in
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode)
  }

  init(log: SessionLog, inbox: InboxModel, cockpit: String) {
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
    // The UI tests start with every card whole: a fold one of them left behind would hide another's options.
    if ProcessInfo.processInfo.environment["GRABBER_DECISION_FOLDS"] == "reset" {
      folds = ChatDecisionFolds()
      UserDefaults.standard.removeObject(forKey: Self.foldsKey)
    }
  }

  private var reachable: Bool { !inbox.offline && cockpit != ChatCockpit.nowhere }

  /// The open asks the screens show: none offline or with no address, even when some were read earlier (#911 review).
  var shown: [ChatAsk] { reachable ? asks : [] }

  func ask(on key: String) -> ChatAsk? { ChatDecisions.ask(on: key, in: shown) }

  func card(_ id: String) -> Card { cards[id] ?? Card() }

  /// What a thread's card gave way to, if it gave way to a line.
  func line(on key: String) -> String? { cards.values.first { $0.thread == key && $0.line != nil }?.line }

  /// Offline or with no address nothing is read and nothing shows; a failed read keeps what was shown, logged once
  /// until one succeeds.
  func refresh(reason: String) async {
    guard reachable else {
      asks = []
      readProblem = nil
      return
    }
    let began = changes
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatDecisions.listRequest(cockpit: cockpit))
      guard began == changes else { return }
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
  /// `other`: the card's own *Other…*, the ask's, or none (story 1128).
  func shown(_ ask: ChatAsk, from place: String, other: String) {
    log.event(
      "chat",
      [
        "action": "decision_shown", "ask": ask.id, "from": place, "options": ask.options.count,
        "expired": ask.expired, "other": other,
      ])
  }

  /// Story 1128: *Other…* (or the ask's own *Other*) opened the own-words field; the answer is logged once it is sent.
  func otherOpened(_ ask: ChatAsk, from place: String) {
    log.event("chat", ["action": "decision_other", "ask": ask.id, "from": place])
  }

  /// #1072: *Close…* opened its prompt; the close itself is logged only once it is sent.
  func closeAsked(_ ask: ChatAsk, from place: String) {
    log.event("chat", ["action": "decision_close_asked", "ask": ask.id, "from": place])
  }

  /// Story 1130: a card folded to its line or opened from it; nothing reaches the Cockpit.
  func fold(_ ask: ChatAsk, _ folded: Bool, from place: String) {
    guard folds.set(ask.id, folded: folded) else { return }
    UserDefaults.standard.set(folds.ids, forKey: Self.foldsKey)
    log.event("chat", ["action": folded ? "decision_fold" : "decision_unfold", "ask": ask.id, "from": place])
  }

  func openedChat(_ ask: ChatAsk) {
    log.event("chat", ["action": "decision_open_chat", "ask": ask.id])
  }

  /// A thread opened: what its card said on an earlier visit goes, unless a verb is still on its way.
  func threadOpened(_ key: String) {
    cards = cards.filter { $0.value.sending || $0.value.thread != key }
  }

  /// Decisions left the screen: the lines, notes and problems of its cards go with it.
  func leftDecisions() {
    finished = []
    cards = cards.filter { $0.value.sending }
  }

  /// One verb on one card, and what it came to. A second tap while it goes does nothing, and comes to nil.
  @discardableResult
  func run(_ verb: ChatDecisions.Verb, on ask: ChatAsk, from place: String) async -> ChatDecisions.Outcome? {
    guard !card(ask.id).sending else { return nil }
    cards[ask.id] = Card(sending: true, thread: ask.chat)
    let outcome: ChatDecisions.Outcome =
      inbox.offline
      ? .refused("the phone is offline")
      : cockpit == ChatCockpit.nowhere
        ? .refused(ChatCockpit.noAddress)
        : await ChatDecisions.run(verb, ask: ask, cockpit: cockpit, transport: transport)
    var fields: [String: Any] = ["ask": ask.id, "from": place, "outcome": outcome.logName]
    fields["action"] = {
      switch verb {
      case .answer, .ownWords: return "decision_answer"
      default: return "decision_menu"
      }
    }()
    if case .refused(let why) = outcome { fields["reason"] = why }
    if case .done(_, let chat) = outcome {
      for (key, value) in ChatDecisions.chatLogFields(verb, chat: chat) { fields[key] = value }
    }
    // The menu's verb rides as `verb`, so it doesn't overwrite the event's own action.
    for (key, value) in verb.logFields { fields[key == "action" ? "verb" : key] = value }
    // #1072: the open asks the screens still list once this one has left them (an outcome that keeps it, counted with it).
    let finishes: Bool = {
      switch outcome {
      case .done, .alreadyAnswered: return true
      case .changed, .refused: return false
      }
    }()
    fields["asks_left"] = asks.filter { !finishes || $0.id != ask.id }.count
    log.event("chat", fields)

    switch outcome {
    case .done(let until, let chat):
      if ChatDecisions.givesWayToMessage(verb, chat: chat, inThread: place == "thread") {
        // The card gives way to Igor's own row, which the Cockpit has just written into the chat.
        await readThread(chat?.thread ?? ask.chatToOpen)
        leave(ask, line: nil, from: place)
      } else {
        leave(ask, line: ChatDecisions.doneLine(verb, snoozedUntil: until), from: place)
      }
    case .alreadyAnswered:
      leave(ask, line: ChatDecisions.alreadyAnswered, from: place)
      await refresh(reason: "already_answered")
    case .changed(let fresh):
      changes += 1
      if let fresh, let i = asks.firstIndex(where: { $0.id == ask.id }) { asks[i] = fresh }
      cards[ask.id] = Card(note: ChatDecisions.changed, thread: ask.chat)
      await refresh(reason: "changed")
    case .refused(let why):
      cards[ask.id] = Card(
        problem: .grabber(
          ChatDecisions.problem(verb, why), context: "ChatDecisionCard.\(place)",
          extra: [
            "ask": .string(ask.id), "verb": .string(verb.word), "updated_at": .string(ask.updatedAt),
            "cockpit": .string(cockpit),
          ]),
        thread: ask.chat)
    }
    return outcome
  }

  private func leave(_ ask: ChatAsk, line: String?, from place: String) {
    changes += 1
    cards[ask.id] = line.map { Card(line: $0, thread: ask.chat) }
    asks.removeAll { $0.id == ask.id }
    if place == "list" { finished.append((ask.id, ask.title)) }
  }
}
