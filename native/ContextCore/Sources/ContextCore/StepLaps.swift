//  Story 1168 (bead context-grabber-uktm): how long each named part of one piece of work took, so a slow one can say in
//  the log which part held it up. The clock is passed in, so a test drives it.

import Foundation

public final class StepLaps {
  public typealias Clock = () -> Double

  private let clock: Clock
  private let started: Double
  private var last: Double
  /// Each part's seconds, by name, in the order each name first ran; a name used again adds to its own.
  public private(set) var laps: [(name: String, seconds: Double)] = []

  public init(clock: @escaping Clock = { ProcessInfo.processInfo.systemUptime }) {
    self.clock = clock
    started = clock()
    last = started
  }

  /// Ends the part that ran since the last lap (or the start), under `name`.
  public func lap(_ name: String) {
    let now = clock()
    add(name, now - last)
    last = now
  }

  /// Runs `body` as a part of its own. Time since the last lap that no lap named goes to `other`.
  public func time<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
    let before = clock()
    if before > last { add("other", before - last) }
    defer {
      let now = clock()
      add(name, now - before)
      last = now
    }
    return try body()
  }

  /// The whole time so far and each part's, in whole milliseconds, when the whole took `overMs` or more; nil sooner.
  public func report(overMs: Int) -> (totalMs: Int, laps: [String: Int])? {
    let total = Self.ms(clock() - started)
    guard total >= overMs else { return nil }
    var parts: [String: Int] = [:]
    for lap in laps { parts[lap.name] = Self.ms(lap.seconds) }
    return (total, parts)
  }

  private func add(_ name: String, _ seconds: Double) {
    if let index = laps.firstIndex(where: { $0.name == name }) {
      laps[index].seconds += seconds
    } else {
      laps.append((name, seconds))
    }
  }

  private static func ms(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }
}
