//  Searching the asks (story 1132, bead context-grabber-4dme; spec 2026-11-14-chat-decision-cards-design.md,
//  *Searching the asks*): the words in the box on *Decisions*, read by the Cockpit's GET /asks/search once typing rests,
//  the *Answered too* tick, and what came back. The request, the answer and the highlights are `ChatAskSearch`.

import BugKit
import ContextCore
import Foundation

@MainActor
final class ChatAskSearchModel: ObservableObject {
  /// What is in the box.
  @Published var query = ""
  /// *Answered too*: the answered and closed asks join the open ones.
  @Published var answeredToo = false
  /// The last search that came back for the words in the box; nil while there are none.
  @Published private(set) var result: ChatAskSearchResult?
  /// Why the last search failed: its words and status in the copyable problem.
  @Published private(set) var problem: BugProblem?
  /// A search is on its way.
  @Published private(set) var searching = false

  private let log: SessionLog
  private let inbox: InboxModel
  let cockpit: String
  /// Counts the searches; an answer to an older one is dropped (each keystroke starts another).
  private var generation = 0
  private var pending: Task<Void, Never>?
  private let transport: ChatDecisions.Transport = { request in
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode)
  }

  init(log: SessionLog, inbox: InboxModel, cockpit: String) {
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
  }

  /// Words in the box: the screen shows the search, not the cards.
  var active: Bool { !ChatAskSearch.terms(query).isEmpty }

  /// The box or the tick changed: the search goes once typing rests. An emptied box brings the cards back at once.
  func changed() {
    pending?.cancel()
    generation += 1
    guard active else {
      result = nil
      problem = nil
      searching = false
      return
    }
    let ticket = generation
    let words = query
    let all = answeredToo
    searching = true
    pending = Task { [weak self] in
      try? await Task.sleep(for: ChatAskSearch.pause)
      guard !Task.isCancelled else { return }
      await self?.search(words, all: all, ticket: ticket)
    }
  }

  private func search(_ words: String, all: Bool, ticket: Int) async {
    let outcome: ChatAskSearch.Outcome
    if inbox.offline {
      outcome = .failed("the phone is offline", status: nil)
    } else if cockpit == ChatCockpit.nowhere {
      outcome = .failed(ChatCockpit.noAddress, status: nil)
    } else {
      do {
        guard let request = try ChatAskSearch.request(cockpit: cockpit, q: words, all: all) else { return }
        let (data, status) = try await transport(request)
        outcome = ChatAskSearch.outcome(status: status, body: data)
      } catch is CancellationError {
        return
      } catch let error as URLError where error.code == .cancelled {
        return
      } catch {
        outcome = ChatAskSearch.outcome(status: nil, body: nil, error: error.localizedDescription)
      }
    }
    guard ticket == generation else { return }
    searching = false
    var fields = ChatAskSearch.logFields(q: words, all: all)
    fields["action"] = "ask_search"
    switch outcome {
    case .found(let found):
      result = found
      problem = nil
      fields["outcome"] = "ok"
      fields["open"] = found.open
      fields["answered"] = found.answered
      fields["count"] = found.threads.count
    case .failed(let why, let status):
      result = nil
      var extra: [String: JSONValue] = [
        "q": .string(words), "all": .bool(all), "cockpit": .string(cockpit),
      ]
      if let status {
        extra["status"] = .int(status)
        fields["status"] = status
      }
      problem = .grabber(ChatAskSearch.problem(why), context: "ChatDecisionsView.search", extra: extra)
      fields["outcome"] = "failed"
      fields["reason"] = why
    }
    log.event("chat", fields)
  }

  /// A row was tapped: which ask (never the words) and where it went.
  func opened(_ hit: ChatAskHit, _ opens: ChatAskSearch.Opens) {
    let to: String = {
      switch opens {
      case .thread: return "thread"
      case .web: return "cockpit"
      }
    }()
    log.event("chat", ["action": "ask_search_open", "ask": hit.key, "open": hit.open, "to": to])
  }
}
