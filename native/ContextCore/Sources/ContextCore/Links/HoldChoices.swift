//  #391, stories 222-225 (spec 2026-10-18-press-and-hold-popovers-design.md): what a press and hold on a home tile
//  offers. Pure; the app draws the popover and does the opening.

import Foundation

public struct HoldChoice: Equatable, Sendable, Identifiable {
  public enum Action: Equatable, Sendable {
    /// Where a link of the app's own would go.
    case route(AppRoute)
    case supermix(WorkoutSupermix.Mix)
    /// The card screen with *Drill the stack* already tapped (story 220).
    case drill
  }

  public let id: String
  /// Its name under the picture, and what VoiceOver says after the tile's name.
  public let title: String
  /// The drawn picture in the asset catalog; nil for a preset, which is its title written large on the tile's colour.
  public let art: String?
  /// Apple's nearest symbol, drawn until the art is (and for Custom, which has no number).
  public let symbol: String?
  public let action: Action
}

public enum HoldChoices {
  /// The tiles a press and hold opens a popover on; every other tile keeps no hold at all.
  public static func choices(forTile tile: String) -> [HoldChoice] {
    switch tile {
    case "workout_supermix":
      return WorkoutSupermix.Mix.allCases.map {
        HoldChoice(
          id: "supermix-\($0.rawValue)", title: $0.title,
          art: $0 == .workout ? "tile-workout_supermix" : "choice-\($0.rawValue)", symbol: nil,
          action: .supermix($0))
      }
    case "gym_timer":
      // Each starts at once: its get-ready countdown is the moment to put the phone down.
      return TimerProfile.presets.map {
        HoldChoice(
          id: "timer-\($0.id)", title: $0.label, art: nil, symbol: nil,
          action: .route(.timer(TimerLink(preset: $0.id, start: true))))
      }
        + [
          HoldChoice(
            id: "timer-\(CustomPreset.id)", title: "CUSTOM", art: nil, symbol: "slider.horizontal.3",
            action: .route(.timer(TimerLink(preset: CustomPreset.id, start: true))))
        ]
    case "breathe":
      return BreathPlan.presets.map {
        HoldChoice(
          id: "breathe-\($0)", title: "\($0) s", art: nil, symbol: nil,
          action: .route(.breathe(BreatheLink(breath: $0, start: true))))
      }
    case "think_a_card":
      return [
        HoldChoice(
          id: "card-think", title: "Think of a card", art: "choice-card_think", symbol: "brain",
          action: .route(.card(think: true))),
        HoldChoice(
          id: "card-face", title: "A card face up", art: "choice-card_face", symbol: "suit.spade.fill",
          action: .route(.card(think: false))),
        HoldChoice(
          id: "card-drill", title: "Drill the stack", art: "choice-card_drill", symbol: "target", action: .drill),
      ]
    default:
      return []
    }
  }
}
