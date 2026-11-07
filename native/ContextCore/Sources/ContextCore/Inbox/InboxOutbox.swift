//  #305, #406, #525, #565, stories 039, 269, 488, 507–510: when the Inbox sends. A send starts from a refresh (launch,
//  foreground, compose, Send again), the network coming back or settling on a new route, or the backoff after a failed
//  send; only one is ever out, and a refresh that comes meanwhile runs one more pass when it ends. The app's model is
//  the humble half: it reads the network path, the clock and URLSession and hands them in, and shows what this says.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A wait the outbox can call off: the app's sleeps on a Task, a host test fires its own by hand.
public protocol InboxTimer {
  func cancel()
}

@MainActor
public final class InboxOutbox {
  /// After `seconds`, `fire`, unless the returned timer is cancelled first.
  public typealias Schedule = @MainActor (_ seconds: Double, _ fire: @escaping @MainActor () -> Void) -> InboxTimer
  public typealias Log = (String, [String: Any]) -> Void

  public private(set) var policy = InboxSendPolicy()
  public private(set) var sending = false
  /// #565: the last send found the Cockpit not answering; a waiting message says so.
  public private(set) var cockpitAway = false
  public var offline: Bool { policy.path == .offline }

  /// The app's refresh: read the Inbox, log what is new, then `send(reason:)`. Called for the network's return, a
  /// settled route change and the backoff's try.
  public var refresh: @MainActor (String) -> Void = { _ in }
  /// A send ended: the app reads the Inbox again (the backoff, decided next, counts what still waits) and, when
  /// something went, chat reads its threads.
  public var finished: @MainActor (InboxSender.Report) -> Void = { _ in }
  /// What waits as the app last read it; the store's own count when the app hands none in.
  public var waitingCount: @MainActor () -> Int

  private let store: InboxStore?
  private let sender: InboxSender?
  private let now: () -> Double
  private let schedule: Schedule
  private let log: Log
  private var pathRetry: InboxTimer?
  /// #565: the next try on its own after a failed send, while the app is open.
  private var backoff: InboxTimer?
  /// A refresh came while a send was out: one more pass when it ends, for what was shared meanwhile (local review).
  private var again = false
  private var inFlight: Task<Void, Never>?

  /// `store`: nil without an App Group, and then nothing is sent. `now`: seconds on a clock that only goes forward.
  public init(
    store: InboxStore?, cockpit: String, now: @escaping () -> Double, schedule: @escaping Schedule,
    log: @escaping Log, transport: @escaping InboxSender.Transport
  ) {
    self.store = store
    self.sender = store.map { InboxSender(store: $0, cockpit: cockpit, transport: transport) }
    self.now = now
    self.schedule = schedule
    self.log = log
    waitingCount = { store?.waitingCount ?? 0 }
  }

  // MARK: The network

  /// A path reading. `.requiresConnection` (an on-demand VPN such as Tailscale's) counts as available.
  public func networkChanged(available: Bool, interfaces: Set<String>, expensive: Bool, constrained: Bool) {
    let wasOffline = offline
    let previousRetry = policy.retryAfter
    let becameOnline = policy.updatePath(
      available ? .online : .offline, interfaces: interfaces, expensive: expensive, constrained: constrained,
      waitingCount: store?.waitingCount ?? 0, now: now())
    schedulePathRetry(ifChangedFrom: previousRetry)
    if becameOnline {
      // Read shares made while away before deciding whether there is anything to send.
      refresh(wasOffline ? "network_back" : "network_ready")
    } else if offline && !wasOffline {
      refresh("network_offline")
    }
  }

  private func schedulePathRetry(ifChangedFrom previousRetry: Double?) {
    guard previousRetry != policy.retryAfter else { return }
    pathRetry?.cancel()
    pathRetry = nil
    guard policy.retryAfter != nil else { return }
    pathRetry = schedule(0.5) { [weak self] in
      guard let self else { return }
      let decision = policy.pathRetryDecision(
        waitingCount: store?.waitingCount ?? 0, sending: sending, now: now())
      if decision == .send || decision == .sendAgain { refresh("network_changed") }
    }
  }

  // MARK: Sending

  /// The app read the Inbox: with nothing waiting, nothing says the Cockpit is away (local review).
  public func read(waiting: Int) {
    if waiting == 0 { cockpitAway = false }
  }

  /// Story 488: a refused file is waiting again, the same message under the same id, and goes now.
  public func sendAgain(_ item: InboxItem) {
    do {
      try store?.sendAgain(item.id)
      log("chat", ["action": "send_again", "item": item.id, "kind": item.kind.rawValue])
    } catch {
      log("error", ["where": "inbox_send_again", "item": item.id, "message": "\(error)"])
    }
    refresh("send_again")
  }

  /// Sends what waits, unless the path is unknown or offline, or a send is already out (then once more after it).
  public func send(reason: String) {
    guard let sender else { return }
    let waiting = waitingCount()
    let decision = policy.decision(waitingCount: waiting, sending: sending)
    if reason == "network_back" || reason == "network_changed", decision == .send || decision == .sendAgain {
      log("inbox", ["action": reason, "waiting": waiting, "sending": sending])
    }
    switch decision {
    case .wait: return
    case .offlineSkipped:
      log("inbox", ["action": "offline_skipped", "waiting": waiting, "why": reason])
      return
    case .sendAgain:
      again = true
      return
    case .send: break
    }
    sending = true
    policy.startedSend()
    let log = self.log
    inFlight = Task { [weak self] in
      let report = await sender.sendWaiting { type, fields in
        var fields = fields
        fields["why"] = reason
        log(type, fields)
      }
      self?.ended(report, reason: reason)
    }
  }

  private func ended(_ report: InboxSender.Report, reason: String) {
    let previousRetry = policy.retryAfter
    policy.finishedSend(retry: report.retry != nil, now: now(), scheduled: reason == "backoff")
    schedulePathRetry(ifChangedFrom: previousRetry)
    sending = false
    cockpitAway = report.unreachable
    finished(report)
    scheduleBackoff()
    if again {
      again = false
      send(reason: "again")
    }
  }

  /// #565: a failed send is tried again on its own (30 s, doubling to 5 min) until nothing waits or the phone is
  /// offline; a send from any other trigger replaces the wait. ponytail: a suspended app's timer fires late, on resume.
  private func scheduleBackoff() {
    backoff?.cancel()
    backoff = nil
    guard let delay = policy.backoffDelay, waitingCount() > 0 else { return }
    log("inbox", ["action": "backoff", "seconds": delay, "failed_in_a_row": policy.failedInARow])
    backoff = schedule(delay) { [weak self] in
      // A send already out reschedules when it ends; joining it would be a second try straight after (local review).
      guard let self, !offline, !sending, waitingCount() > 0 else { return }
      refresh("backoff")
    }
  }

  /// Returns once no send is out, including the extra pass one asked for: for tests and the app's shutdown.
  public func settled() async {
    while let task = inFlight {
      await task.value
      if inFlight == task { inFlight = nil }
    }
  }

  deinit {
    pathRetry?.cancel()
    backoff?.cancel()
  }
}

/// The app's timer: a Task that sleeps, then fires on the main actor.
public struct InboxTaskTimer: InboxTimer {
  let task: Task<Void, Never>

  public func cancel() { task.cancel() }

  @MainActor
  public static func schedule(_ seconds: Double, _ fire: @escaping @MainActor () -> Void) -> InboxTimer {
    InboxTaskTimer(
      task: Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(Int(seconds * 1000))) } catch { return }
        fire()
      })
  }
}

extension InboxItem {
  /// The `inbox` *added* line for an item the app sees for the first time: the kind and the size, never the content.
  public func addedLogFields(bytes: Int?) -> [String: Any] {
    var fields: [String: Any] = ["action": "added", "item": id, "kind": kind.rawValue]
    fields["note"] = note != nil
    fields["new_thread"] = thread == nil
    if let thread { fields["thread"] = thread }
    if let offered { fields["offered"] = offered }
    if let shareTypes { fields["share_types"] = shareTypes }
    if let text { fields["text_chars"] = text.count }
    if let bytes { fields["bytes"] = bytes }
    if let site { fields["site"] = site }
    return fields
  }
}

/// Which Inbox items the app has not seen before, by the ids it saved last time (one comma-separated setting).
public enum InboxSeen {
  public struct Look: Equatable {
    /// New since the last look, oldest first: the order their *added* lines go in the log.
    public var fresh: [InboxItem]
    /// Something real is on its way to Larry (not a simulator fixture): chat asks for notifications once.
    public var anyReal: Bool
    /// The setting to save: only ids still in the Inbox, so it does not grow forever.
    public var setting: String
  }

  /// `items`: newest first, as the store lists them.
  public static func look(_ items: [InboxItem], seen setting: String?) -> Look {
    let seen = Set((setting ?? "").split(separator: ",").map(String.init))
    let fresh = items.filter { !seen.contains($0.id) }
    return Look(
      fresh: fresh.reversed(), anyReal: fresh.contains { !$0.isFixture },
      setting: items.map(\.id).joined(separator: ","))
  }
}
