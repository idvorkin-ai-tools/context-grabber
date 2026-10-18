//  #391, stories 222-225: the popovers a press and hold on a home tile opens.

import XCTest

@testable import ContextCore

final class HoldChoicesTests: XCTestCase {
  func testOnlyTheFourTilesHaveAPopover() {
    for tile in ["workout_supermix", "gym_timer", "breathe", "think_a_card"] {
      XCTAssertFalse(HoldChoices.choices(forTile: tile).isEmpty, tile)
    }
    for tile in ["call", "today", "places", "cockpit", "eulogy", "recent", "random", "settings", "inbox"] {
      XCTAssertTrue(HoldChoices.choices(forTile: tile).isEmpty, "\(tile) keeps no hold")
    }
  }

  func testTheMusicPopoverIsTheThreeMixesWorkoutFirst() {
    let music = HoldChoices.choices(forTile: "workout_supermix")
    XCTAssertEqual(music.map(\.action), [.supermix(.workout), .supermix(.liked), .supermix(.feelGood)])
    XCTAssertEqual(music.map(\.art), ["tile-workout_supermix", "choice-liked", "choice-feel_good"])
  }

  func testTimerPresetsStartAndCustomIsTheRememberedOne() {
    let timer = HoldChoices.choices(forTile: "gym_timer")
    XCTAssertEqual(timer.map(\.title), ["30 SEC", "1 MIN", "2 MIN", "5-1", "CUSTOM"])
    XCTAssertEqual(timer[2].action, .route(.timer(TimerLink(preset: "2min", start: true))))
    XCTAssertEqual(timer[4].action, .route(.timer(TimerLink(preset: "custom", start: true))))
    // Each is what the app's own link for it says, so the popover and Shortcuts open the same workout.
    XCTAssertEqual(AppLink.parse("grabbernative://timer?preset=2min").route, timer[2].action.route)
  }

  func testBreathingBeginsAtEachPresetLength() {
    let breathe = HoldChoices.choices(forTile: "breathe")
    XCTAssertEqual(breathe.map(\.title), ["8 s", "10 s", "12 s", "15 s"])
    XCTAssertEqual(breathe[1].action, .route(.breathe(BreatheLink(breath: 10, start: true))))
    XCTAssertEqual(
      AppLink.parse("grabbernative://breathe?breath=10").route, .breathe(BreatheLink(breath: 10, start: true)))
  }

  func testTheCardPopoverThinksFirstThenFaceUpThenTheDrill() {
    let card = HoldChoices.choices(forTile: "think_a_card")
    XCTAssertEqual(card.map(\.action), [.route(.card(think: true)), .route(.card(think: false)), .drill])
    XCTAssertTrue(card.allSatisfy { $0.art != nil }, "each has drawn art")
  }

  func testEveryChoiceHasAPictureOrANumberAndAUniqueId() {
    let all = ["workout_supermix", "gym_timer", "breathe", "think_a_card"].flatMap(HoldChoices.choices(forTile:))
    XCTAssertEqual(Set(all.map(\.id)).count, all.count)
    for choice in all where choice.art == nil {
      XCTAssertTrue(choice.title.contains { $0.isNumber } || choice.symbol != nil, choice.id)
    }
  }
}

extension HoldChoice.Action {
  fileprivate var route: AppRoute? {
    if case .route(let r) = self { return r }
    return nil
  }
}
