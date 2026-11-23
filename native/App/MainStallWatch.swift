//  #946: a watch off the main thread that says in the session log when the main thread stops answering (`main_stall`),
//  so "I think I just hung" is a number rather than a guess. It runs only while the app is active: time away isn't a
//  stall. What counts is ContextCore's MainStallMeter. The app suspended without going inactive first (bead
//  context-grabber-55vm) is caught by the meter too: the watch's own looks stop with the process, so a long gap between
//  them is said as `away`, not a stall. Start and stop log the app's and its scenes' states, to show why a stop was missed.

import ContextCore
import Foundation
import UIKit

final class MainStallWatch: @unchecked Sendable {
  /// Looks four times a second; a second without an answer is a stall.
  static let every = 0.25
  static let threshold = 1.0

  private let log: SessionLog
  private let queue = DispatchQueue(label: "grabber.main-stall", qos: .utility)
  private let lock = NSLock()
  private var meter = MainStallMeter(threshold: threshold, now: ProcessInfo.processInfo.systemUptime)
  /// One answer asked of the main thread at a time: a stuck one doesn't pile up a look per tick.
  private var asking = false
  private var timer: DispatchSourceTimer?
  private var observers: [NSObjectProtocol] = []

  init(log: SessionLog) {
    self.log = log
  }

  /// From the main thread, once: watches while the app is active.
  func install() {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) {
        [weak self] _ in self?.start()
      },
      center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) {
        [weak self] _ in self?.stop()
      },
    ]
    if UIApplication.shared.applicationState == .active { start() }
  }

  private func start() {
    guard timer == nil else { return }
    lock.withLock {
      meter.restart(at: ProcessInfo.processInfo.systemUptime)
      asking = false
    }
    log.event("main_stall", ["action": "watching", "app": Self.appState(), "scenes": Self.sceneStates()])
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + Self.every, repeating: Self.every, leeway: .milliseconds(50))
    timer.setEventHandler { [weak self] in self?.look() }
    timer.resume()
    self.timer = timer
  }

  private func stop() {
    timer?.cancel()
    timer = nil
    let word = lock.withLock { meter.stopped(at: ProcessInfo.processInfo.systemUptime) }
    say(word, why: "inactive")
    log.event("main_stall", ["action": "stopped", "app": Self.appState(), "scenes": Self.sceneStates()])
  }

  /// Off the main thread.
  private func look() {
    let now = ProcessInfo.processInfo.systemUptime
    let (word, ask): (MainStallMeter.Word?, Bool) = lock.withLock {
      let word = meter.checked(at: now)
      let ask = !asking
      asking = true
      return (word, ask)
    }
    say(word, why: nil)
    guard ask else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let word = self.lock.withLock {
        self.asking = false
        return self.meter.answered(at: ProcessInfo.processInfo.systemUptime)
      }
      self.say(word, why: nil)
    }
  }

  private func say(_ word: MainStallMeter.Word?, why: String?) {
    switch word {
    case .began(let waited):
      log.event("main_stall", ["action": "began", "waited_ms": Int((waited * 1000).rounded())])
    case .ended(let lasted):
      var fields: [String: Any] = ["action": "ended", "ms": Int((lasted * 1000).rounded())]
      if let why { fields["why"] = why }
      log.event("main_stall", fields)
    case .away(let gap, let wasStalling):
      log.event(
        "main_stall", ["action": "away", "gap_ms": Int((gap * 1000).rounded()), "was_stalling": wasStalling])
    case nil:
      break
    }
  }

  /// From the main thread.
  private static func appState() -> String {
    switch UIApplication.shared.applicationState {
    case .active: "active"
    case .inactive: "inactive"
    case .background: "background"
    @unknown default: "unknown"
    }
  }

  /// From the main thread: each connected scene's activation state.
  private static func sceneStates() -> [String] {
    UIApplication.shared.connectedScenes.map { scene in
      switch scene.activationState {
      case .foregroundActive: "foreground_active"
      case .foregroundInactive: "foreground_inactive"
      case .background: "background"
      case .unattached: "unattached"
      @unknown default: "unknown"
      }
    }
  }
}
