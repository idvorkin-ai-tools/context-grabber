//  #634, stories 460-464, 470-482: which window holds what, and the app's phase reported by every window.

import XCTest

@testable import ContextCore

final class WindowLedgerTests: XCTestCase {
  func testTheFirstWindowIsHomeAndALaterOneIsAnExtra() {
    var ledger = WindowLedger()
    XCTAssertTrue(ledger.claimHome("a"))
    XCTAssertFalse(ledger.claimHome("b"))
    XCTAssertTrue(ledger.claimHome("a"), "the home window asking again is still home")
  }

  func testHomeGoneTheNextWindowIsHome() {
    var ledger = WindowLedger()
    _ = ledger.claimHome("a")
    ledger.release("a")
    XCTAssertTrue(ledger.claimHome("b"))
  }

  func testAWindowTheSystemClosedWithoutAGoodbyeIsForgotten() {
    var ledger = WindowLedger()
    _ = ledger.claimHome("a")
    ledger.claim(.cockpit, window: "b")
    ledger.claim(.chat, window: "c")
    ledger.keep(alive: ["c"])
    XCTAssertNil(ledger.home)
    XCTAssertNil(ledger.window(holding: .cockpit))
    XCTAssertEqual(ledger.window(holding: .chat), "c")
  }

  func testReleasingAWindowLetsItsScreenGoOnly() {
    var ledger = WindowLedger()
    ledger.claim(.whiteboard, window: "b")
    ledger.claim(.chat, window: "c")
    ledger.release("b")
    XCTAssertNil(ledger.window(holding: .whiteboard))
    XCTAssertEqual(ledger.screen(in: "c"), .chat)
    XCTAssertNil(ledger.screen(in: "b"))
  }

  func testEachWindowsRoleIsWhatItShows() {
    var ledger = WindowLedger()
    _ = ledger.claimHome("a")
    ledger.claim(.chat, window: "b")
    _ = ledger.claimHome("c")  // iPadOS's own New Window, with home up
    XCTAssertEqual(ledger.role(of: "a"), .home)
    XCTAssertEqual(ledger.role(of: "b"), .screen(.chat))
    XCTAssertEqual(ledger.role(of: "c"), .noScreen)
    XCTAssertEqual(ledger.role(of: "never seen"), .noScreen)
  }

  func testAScreensWindowComingAndGoingLeavesTheHomeWindowsRoleAlone() {
    var ledger = WindowLedger()
    _ = ledger.claimHome("a")
    ledger.claim(.today, window: "b")
    XCTAssertEqual(ledger.role(of: "a"), .home)
    ledger.release("b")
    XCTAssertEqual(ledger.role(of: "a"), .home)
    XCTAssertEqual(ledger.role(of: "b"), .noScreen)
  }

  func testEveryScreenRoundTripsItsTileAndTheAudioScreensHaveNoWindow() {
    for screen in WindowScreen.allCases { XCTAssertEqual(WindowScreen(tile: screen.tile), screen) }
    XCTAssertNil(WindowScreen(tile: "gym_timer"))
    XCTAssertNil(WindowScreen(tile: "breathe"))
    XCTAssertNil(WindowScreen(tile: "call"))
    XCTAssertNil(WindowScreen(route: .call(via: nil)))
    XCTAssertNil(WindowScreen(route: .breathe(BreatheLink())))
    XCTAssertNil(WindowScreen(route: .timer(TimerLink())))
    XCTAssertEqual(WindowScreen(route: .chat(thread: "t")), .chat)
    XCTAssertEqual(WindowScreen(route: .whiteboard(board: nil)), .whiteboard)
  }

  func testAWindowsValueSurvivesBeingWrittenDown() throws {
    // The system keeps this to bring the window back after a relaunch.
    let data = try JSONEncoder().encode(WindowScreen.cockpit)
    XCTAssertEqual(try JSONDecoder().decode(WindowScreen.self, from: data), .cockpit)
  }

  func testHoldOffersANewWindowOnlyWhereWindowsExist() {
    XCTAssertEqual(HoldChoices.choices(forTile: "inbox", windows: true).map(\.action), [.window(.chat)])
    XCTAssertTrue(HoldChoices.choices(forTile: "inbox", windows: false).isEmpty)
    XCTAssertEqual(HoldChoices.choices(forTile: "think_a_card", windows: true).last?.action, .window(.card))
    XCTAssertEqual(HoldChoices.choices(forTile: "think_a_card", windows: true).count, 4)
    XCTAssertEqual(HoldChoices.choices(forTile: "think_a_card", windows: false).count, 3)
    for tile in ["gym_timer", "breathe", "workout_supermix"] {
      XCTAssertFalse(HoldChoices.choices(forTile: tile, windows: true).contains { $0.title == "New window" }, tile)
    }
    XCTAssertTrue(HoldChoices.choices(forTile: "call", windows: true).isEmpty)
  }

  // #634: the ids are the home rows' own (HomeRows.swift), and these six are the ones the issue names.
  func testEachNamedTileOffersNewWindowLastAndOnAPhoneOffersNothingNew() {
    let tiles: [(String, WindowScreen)] = [
      ("inbox", .chat), ("cockpit", .cockpit), ("places", .places), ("whiteboard", .whiteboard),
      ("think_a_card", .card), ("today", .today),
    ]
    for (tile, screen) in tiles {
      let last = HoldChoices.choices(forTile: tile, windows: true).last
      XCTAssertEqual(last?.title, "New window", tile)
      XCTAssertEqual(last?.action, .window(screen), tile)
      XCTAssertFalse(HoldChoices.choices(forTile: tile, windows: false).contains { $0.title == "New window" }, tile)
      XCTAssertEqual(
        HoldChoices.choices(forTile: tile, windows: false), HoldChoices.choices(forTile: tile), "\(tile) on a phone")
    }
  }

  func testALinkToAWindowedScreenFindsItsWindowAndAnAudioLinkNeverDoes() {
    let windowed: [(String, WindowScreen)] = [
      ("grabbernative://chat?thread=t", .chat), ("grabbernative://today", .today),
      ("grabbernative://cockpit", .cockpit), ("grabbernative://places", .places),
      ("grabbernative://whiteboard?board=b", .whiteboard), ("grabbernative://card?think=1", .card),
    ]
    for (link, screen) in windowed { XCTAssertEqual(WindowScreen(route: AppLink.parse(link).route), screen, link) }
    for link in [
      "grabbernative://timer?preset=2min", "grabbernative://breathe?breath=10", "grabbernative://call",
      "grabbernative://home", "grabbernative://supermix",
    ] {
      XCTAssertNil(WindowScreen(route: AppLink.parse(link).route), link)
    }
  }

  func testALateGoodbyeFromAClosedWindowLeavesItsSuccessorAlone() {
    var ledger = WindowLedger()
    _ = ledger.claimHome("home")
    ledger.claim(.chat, window: "old")
    ledger.keep(alive: ["home"])  // iOS let "old" go without a goodbye
    XCTAssertNil(ledger.window(holding: .chat), "its tile opens it again as usual")
    ledger.claim(.chat, window: "new")
    ledger.release("old")  // the goodbye arrives after all
    XCTAssertEqual(ledger.window(holding: .chat), "new")
    XCTAssertEqual(ledger.home, "home")
  }

  func testOneChangeReportedByTwoWindowsCountsOnce() {
    var latch = AppPhaseLatch()
    XCTAssertEqual(latch.report(.active), .launch)
    XCTAssertNil(latch.report(.active))
    XCTAssertEqual(latch.report(.background), .background)
    XCTAssertNil(latch.report(.background))
    XCTAssertEqual(latch.report(.active), .foreground)
    XCTAssertNil(latch.report(.active))
  }

  func testComingBackFromInactiveIsAForegroundAsItAlwaysWas() {
    var latch = AppPhaseLatch()
    _ = latch.report(.active)
    XCTAssertNil(latch.report(.inactive))
    XCTAssertEqual(latch.report(.active), .foreground)
  }

  func testAnAppStartedInTheBackgroundStillHasItsLaunchToCome() {
    var latch = AppPhaseLatch()
    XCTAssertEqual(latch.report(.background), .background)
    XCTAssertEqual(latch.report(.active), .launch)
  }
}
