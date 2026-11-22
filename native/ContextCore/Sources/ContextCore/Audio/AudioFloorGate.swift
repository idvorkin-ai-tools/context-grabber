//  context-grabber-2r55: who holds the audio session now, for the audio queues that cannot ask AppModel on the main
//  actor. AppModel says when the call starts and stops holding; the Gym Timer's and breathing's audio ask before
//  every cue and every change to the session, and go without while the floor (`AudioFloor`) refuses them.

import Foundation

public final class AudioFloorGate: @unchecked Sendable {
  private let lock = NSLock()
  private var holding: Set<AudioUser> = []
  private var watchers: [@Sendable (Set<AudioUser>) -> Void] = []

  public init() {}

  /// `user` started or stopped holding the session. Watchers hear only a change, on the caller's thread.
  public func set(_ user: AudioUser, holding on: Bool) {
    let (changed, now, watchers): (Bool, Set<AudioUser>, [@Sendable (Set<AudioUser>) -> Void]) = lock.withLock {
      let was = holding
      if on { holding.insert(user) } else { holding.remove(user) }
      return (was != holding, holding, self.watchers)
    }
    guard changed else { return }
    for watcher in watchers { watcher(now) }
  }

  /// The holder that refuses `ask` now, nil when it may go ahead.
  public func refusal(_ ask: AudioAsk) -> AudioUser? {
    let now = lock.withLock { holding }
    for case .refuse(let by) in AudioFloor.decide(ask, holding: now) { return by }
    return nil
  }

  /// Called with who holds the session after each change.
  public func onChange(_ watcher: @escaping @Sendable (Set<AudioUser>) -> Void) {
    lock.withLock { watchers.append(watcher) }
  }
}
