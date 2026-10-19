//  #406, story 269: wait for a network, and coalesce requests made while a send is out.

public struct InboxSendPolicy: Sendable {
  public enum Path: Sendable {
    case unknown, offline, online
  }

  public enum Decision: Equatable, Sendable {
    case wait, offlineSkipped, send, sendAgain
  }

  public private(set) var path: Path = .unknown

  public init() {}

  /// The first online reading releases launch's waiting items; repeated online readings do nothing.
  public mutating func updatePath(_ path: Path) -> Bool {
    let becameOnline = self.path != .online && path == .online
    self.path = path
    return becameOnline
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
