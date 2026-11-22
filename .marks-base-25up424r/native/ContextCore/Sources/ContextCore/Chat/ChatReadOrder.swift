//  Bead context-grabber-exg6: the chat list, and each open thread, is read from several places at once (opening the
//  list, the app coming to the front, a closed thread, a send, a poll). Only the newest read that finished may show
//  its answer or its problem, and a read that was stopped shows nothing.

import Foundation

/// The order of one screen's reads: each read takes a ticket as it starts and asks before it shows anything.
public struct ChatReadOrder: Equatable, Sendable {
  private var started = 0
  private var shown = 0

  public init() {}

  /// A new read's ticket, newer than every ticket before it.
  public mutating func start() -> Int {
    started += 1
    return started
  }

  /// Whether the read with this ticket may show its answer or its problem: true unless a read that started after it
  /// has shown already. A true answer makes this ticket the newest shown. A stopped read never asks, so an older
  /// read finishing after it still shows.
  public mutating func mayShow(_ ticket: Int) -> Bool {
    guard ticket > shown else { return false }
    shown = ticket
    return true
  }

  /// A read stopped by leaving its screen, or by iOS: not a failure, nothing to show.
  public static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
