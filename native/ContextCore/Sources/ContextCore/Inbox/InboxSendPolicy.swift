//  #406, story 269: wait for a network, and coalesce requests made while a send is out.

public struct InboxSendPolicy: Sendable {
  public enum Path: Equatable, Sendable {
    case unknown, offline, online
  }

  public enum Decision: Equatable, Sendable {
    case wait, offlineSkipped, send, sendAgain
  }

  public private(set) var path: Path = .unknown
  public private(set) var retryAfter: Double?
  private var interfaces: Set<String> = []
  private var expensive = false
  private var constrained = false
  private var failed = false

  public init() {}

  /// A changed route after failure may restore the tailnet even when the phone stayed online.
  public mutating func updatePath(
    _ path: Path, interfaces: Set<String> = [], expensive: Bool = false, constrained: Bool = false,
    waitingCount: Int = 0, now: Double = 0
  ) -> Bool {
    let becameOnline = self.path != .online && path == .online
    let changed = self.interfaces != interfaces || self.expensive != expensive || self.constrained != constrained
    self.path = path
    self.interfaces = interfaces
    self.expensive = expensive
    self.constrained = constrained
    if path != .online || becameOnline || waitingCount == 0 {
      retryAfter = nil
    } else if changed && failed {
      retryAfter = now + 0.5
    }
    return becameOnline
  }

  public mutating func finishedSend(retry: Bool) {
    failed = retry
    if !retry { retryAfter = nil }
  }

  /// Consume one retry only after meaningful updates have settled; identical updates do not extend the wait.
  public mutating func pathRetryDecision(waitingCount: Int, sending: Bool, now: Double) -> Decision {
    guard let retryAfter, now >= retryAfter else { return .wait }
    self.retryAfter = nil
    guard failed, path == .online else { return .wait }
    return decision(waitingCount: waitingCount, sending: sending)
  }

  public func decision(waitingCount: Int, sending: Bool) -> Decision {
    guard waitingCount > 0 else { return .wait }
    switch path {
    case .unknown: return .wait
    case .offline: return .offlineSkipped
    case .online: return sending ? .sendAgain : .send
    }
  }
}
