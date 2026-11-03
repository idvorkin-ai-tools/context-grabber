//  #634, stories 460-464, 470-482 (spec 2026-11-03-ipad-windows-design.md): which window holds what on an iPad. Pure; the
//  app names each window by its scene session and does the opening.

import Foundation

/// A screen that can have a window of its own. The Gym Timer, breathing and the call screen are not here: each holds
/// the audio session, and only the home window keeps them from overlapping (story 476).
public enum WindowScreen: String, Codable, Hashable, CaseIterable, Sendable {
  case chat, today, cockpit, places, whiteboard, card

  /// The home row it opens from.
  public var tile: String {
    switch self {
    case .chat: return "inbox"
    case .today: return "today"
    case .cockpit: return "cockpit"
    case .places: return "places"
    case .whiteboard: return "whiteboard"
    case .card: return "think_a_card"
    }
  }

  public init?(tile: String) {
    guard let screen = Self.allCases.first(where: { $0.tile == tile }) else { return nil }
    self = screen
  }

  /// The window a link to this route belongs in, if it can have one.
  public init?(route: AppRoute) {
    switch route {
    case .chat: self = .chat
    case .today: self = .today
    case .cockpit: self = .cockpit
    case .places: self = .places
    case .whiteboard: self = .whiteboard
    case .card: self = .card
    case .home, .timer, .breathe, .call, .supermix: return nil
    }
  }
}

/// One home window, which presents the app's shared screens, and at most one window per screen.
public struct WindowLedger: Equatable, Sendable {
  public private(set) var home: String?
  private var screens: [WindowScreen: String] = [:]

  public init() {}

  /// True when this window is the home window. A later one is an extra: it must not show what the home window shows.
  public mutating func claimHome(_ window: String) -> Bool {
    if home == nil { home = window }
    return home == window
  }

  public mutating func claim(_ screen: WindowScreen, window: String) { screens[screen] = window }

  public mutating func release(_ window: String) {
    if home == window { home = nil }
    screens = screens.filter { $0.value != window }
  }

  /// Forgets windows the system has let go of: a window's own goodbye is not reliable when iOS closes it.
  public mutating func keep(alive: Set<String>) {
    if let home, !alive.contains(home) { self.home = nil }
    screens = screens.filter { alive.contains($0.value) }
  }

  public func window(holding screen: WindowScreen) -> String? { screens[screen] }

  public func screen(in window: String) -> WindowScreen? { screens.first { $0.value == window }?.key }
}

/// #634: every window reports the app's phase, so one change arrives once per window. This says what it means, once.
public struct AppPhaseLatch: Equatable, Sendable {
  public enum Phase: Equatable, Sendable { case active, inactive, background }
  public enum Change: Equatable, Sendable { case launch, foreground, background }

  private var last: Phase?
  private var launched = false

  public init() {}

  /// The first activation is the launch; every later arrival at active is a foreground.
  public mutating func report(_ phase: Phase) -> Change? {
    guard phase != last else { return nil }
    last = phase
    switch phase {
    case .inactive: return nil
    case .background: return .background
    case .active:
      defer { launched = true }
      return launched ? .foreground : .launch
    }
  }
}
