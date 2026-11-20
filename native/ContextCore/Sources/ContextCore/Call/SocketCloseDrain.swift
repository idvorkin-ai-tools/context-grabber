//  #902: a hang-up sends the dump, `stt_stop` and `stop`, then closes the socket. Closing at once can cancel
//  frames still queued, so the close waits until every send has completed (sent or failed) or a short bound has
//  passed, whichever is first. It never waits longer than the bound, and it closes exactly once.

import Foundation

public final class SocketCloseDrain {
  /// How long a hang-up waits for the last frames to leave before the socket closes anyway.
  public static let defaultBoundMs: Double = 2000

  /// How the close went, for the log: whether every send had completed, how many had not, and the wait.
  public struct Outcome: Equatable {
    public let drained: Bool
    public let pending: Int
    public let waitedMs: Double
  }

  private let scheduler: CallScheduler
  private let boundMs: Double
  private var pending = 0
  private var closeRequestedAt: Double?
  private var timer: CallTimer?
  private var closeNow: ((Outcome) -> Void)?
  public private(set) var closed = false

  public init(scheduler: CallScheduler, boundMs: Double = SocketCloseDrain.defaultBoundMs) {
    self.scheduler = scheduler
    self.boundMs = boundMs
  }

  /// A frame was handed to the socket; call `completed()` when its send finishes, either way.
  public func sending() { pending += 1 }

  /// A send finished (sent or failed).
  public func completed() {
    pending = max(0, pending - 1)
    if pending == 0, closeNow != nil { fire(drained: true) }
  }

  /// Close once the sends in flight have completed, or after the bound. `close` runs exactly once.
  public func close(_ close: @escaping (Outcome) -> Void) {
    guard !closed, closeNow == nil else { return }
    closeNow = close
    closeRequestedAt = scheduler.now
    if pending == 0 { return fire(drained: true) }
    timer = scheduler.after(boundMs) { [weak self] in self?.fire(drained: false) }
  }

  private func fire(drained: Bool) {
    guard !closed, let close = closeNow else { return }
    closed = true
    closeNow = nil
    timer?.cancel()
    timer = nil
    let waited = scheduler.now - (closeRequestedAt ?? scheduler.now)
    close(Outcome(drained: drained, pending: pending, waitedMs: waited))
  }
}
