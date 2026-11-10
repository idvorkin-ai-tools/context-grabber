//  #808: one name per screen of the home window, every spelling of it pinned both ways, and the steps a link takes.

import XCTest

@testable import ContextCore

final class HomeStackTests: XCTestCase {
  typealias Screen = HomeStack.Screen
  typealias Step = HomeStack.Step

  // MARK: - The vocabulary

  /// Every spelling that leaves the app: the report's, the link's (and the log's `route`), the home tile's, and the
  /// window's (the `window` log lines). Changing a string here changes what a log, a link or a window title says.
  private let table: [(screen: Screen, report: String, route: String?, tile: String?, window: String?)] = [
    (.home, "home", "home", nil, nil),
    (.timer, "gym_timer", "timer", "gym_timer", nil),
    (.breathe, "breathe", "breathe", "breathe", nil),
    (.card, "card", "card", "think_a_card", "card"),
    (.places, "places", "places", "places", "places"),
    (.cockpit, "cockpit", "cockpit", "cockpit", "cockpit"),
    (.whiteboard, "whiteboard", "whiteboard", "whiteboard", "whiteboard"),
    (.call, "call", "call", "call", nil),
    (.today, "today", "today", "today", "today"),
    (.chat, "chat", "chat", "inbox", "chat"),
    (.eulogySong, "eulogy_song", nil, "eulogy_song", nil),
    (.whatsNew, "whats_new", nil, nil, nil),
    (.homeSettings, "home_settings", nil, "settings", nil),
    (.drill, "drill", nil, nil, nil),
  ]

  func testTheTableCoversEveryFixedScreen() {
    XCTAssertEqual(table.map(\.screen), Screen.fixed)
  }

  func testEverySpellingOfEveryScreen() {
    for row in table {
      XCTAssertEqual(row.screen.reportName, row.report)
      XCTAssertEqual(row.screen.routeName, row.route, row.report)
      XCTAssertEqual(row.screen.tile, row.tile, row.report)
      XCTAssertEqual(row.screen.window?.rawValue, row.window, row.report)
    }
  }

  func testEverySpellingReadsBackToItsScreen() {
    for row in table {
      XCTAssertEqual(Screen(reportName: row.report), row.screen)
      if let route = row.route { XCTAssertEqual(Screen(routeName: route), row.screen) }
      if let tile = row.tile { XCTAssertEqual(Screen(tile: tile), row.screen) }
      if let window = row.window.flatMap(WindowScreen.init(rawValue:)) {
        XCTAssertEqual(Screen(window: window), row.screen)
      }
    }
    XCTAssertNil(Screen(reportName: "timer"), "the report's word for the timer is gym_timer")
    XCTAssertNil(Screen(routeName: "gym_timer"), "the link's is timer")
    XCTAssertNil(Screen(routeName: "eulogy_song"))
    XCTAssertNil(Screen(tile: "workout_supermix"), "a tile that opens another app is no screen")
  }

  func testAMetricsWeekIsNamedByItsMetric() {
    for key in MetricKey.allCases {
      XCTAssertEqual(Screen.metric(key).reportName, "metric_\(key.rawValue)")
      XCTAssertEqual(Screen(reportName: "metric_\(key.rawValue)"), .metric(key))
      XCTAssertNil(Screen.metric(key).routeName)
      XCTAssertNil(Screen.metric(key).tile)
      XCTAssertNil(Screen.metric(key).window)
    }
    XCTAssertEqual(Screen.metric(.heartRate).reportName, "metric_heartRate")
    XCTAssertNil(Screen(reportName: "metric_nothing"))
  }

  func testEveryRouteLandsOnItsScreen() {
    let routes: [(AppRoute, Screen?)] = [
      (.home, .home), (.today, .today), (.timer(TimerLink()), .timer), (.breathe(BreatheLink()), .breathe),
      (.places, .places), (.cockpit, .cockpit), (.call(via: nil), .call), (.card(think: true), .card),
      (.chat(thread: "t"), .chat), (.whiteboard(board: nil), .whiteboard), (.supermix, nil),
    ]
    for (route, screen) in routes {
      XCTAssertEqual(Screen(route: route), screen, route.name)
      if let screen { XCTAssertEqual(screen.routeName, route.name) }
      // The windows' own table agrees.
      XCTAssertEqual(WindowScreen(route: route), screen?.window, route.name)
    }
  }

  func testTheWindowsTilesAgree() {
    for window in WindowScreen.allCases {
      XCTAssertEqual(Screen(window: window).tile, window.tile)
      XCTAssertEqual(Screen(window: window).window, window)
    }
  }

  func testEveryLinkPathIsReadAsItsScreen() {
    XCTAssertEqual(Screen.home.linkPaths, ["home", "main"])
    XCTAssertEqual(Screen.today.linkPaths, ["today", "grab"])
    XCTAssertEqual(Screen.timer.linkPaths, ["timer"])
    XCTAssertEqual(Screen.breathe.linkPaths, ["breathe", "breathing"])
    XCTAssertEqual(Screen.card.linkPaths, ["card", "think"])
    XCTAssertEqual(Screen.chat.linkPaths, ["chat", "inbox"])
    XCTAssertEqual(Screen.eulogySong.linkPaths, [])
    for screen in Screen.fixed {
      XCTAssertEqual(screen.linkPaths.first, screen.routeName)
      for path in screen.linkPaths {
        let parsed = AppLink.parse("grabbernative://\(path)")
        XCTAssertTrue(parsed.understood, path)
        XCTAssertEqual(Screen(route: parsed.route), screen, path)
      }
    }
    // And the link each route is written as starts with the route's name.
    XCTAssertEqual(AppLink.link(for: .timer(TimerLink())), "grabbernative://timer")
    XCTAssertEqual(AppLink.link(for: .chat(thread: nil)), "grabbernative://chat")
  }

  // MARK: - Which screen is in front

  func testTheFrontIsTheTopmostScreenALinkNames() {
    XCTAssertEqual(HomeStack.front(of: []), .home)
    XCTAssertEqual(HomeStack.front(of: [.chat, .today]), .today)
    XCTAssertEqual(HomeStack.front(of: [.today, .call, .timer]), .timer)
    XCTAssertEqual(HomeStack.front(of: [.call, .cockpit]), .cockpit)
    XCTAssertEqual(HomeStack.front(of: [.eulogySong, .homeSettings, .whatsNew]), .home, "a sheet over home is home")
    XCTAssertEqual(HomeStack.front(of: [.eulogySong, .chat]), .chat)
    XCTAssertEqual(
      HomeStack.order.filter { $0.routeName != nil },
      [.timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .today, .chat])
  }

  func testTheHomeWindowIsNamedForTheTopmostScreenOfAll() {
    XCTAssertEqual(HomeStack.named(of: []), .home)
    XCTAssertEqual(HomeStack.named(of: [.eulogySong, .today]), .eulogySong)
    XCTAssertEqual(HomeStack.named(of: [.whatsNew, .homeSettings, .chat]), .whatsNew)
    XCTAssertEqual(HomeStack.named(of: [.homeSettings, .today, .chat]), .homeSettings)
    XCTAssertEqual(HomeStack.named(of: [.call, .eulogySong]), .call)
    XCTAssertEqual(
      HomeStack.order,
      [
        .timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .eulogySong, .whatsNew, .homeSettings, .today,
        .chat,
      ])
    // Every screen that can name the window has a tile, but What's new, which has its own words.
    XCTAssertEqual(HomeStack.order.filter { $0.tile == nil }, [.whatsNew])
  }

  // MARK: - The steps to a screen

  private func go(_ route: AppRoute, up: Set<Screen> = [], ownWindow: Bool = false) -> [Step] {
    HomeStack.go(to: route, up: up, ownWindow: ownWindow)
  }

  func testFromHomeTheScreenComesStraightUp() {
    XCTAssertEqual(go(.places), [.showHomeWindow, .present(.places)])
    XCTAssertEqual(go(.call(via: nil)), [.showHomeWindow, .present(.call(via: nil))])
  }

  func testWhatIsInFrontGoesThenAWaitThenTheScreen() {
    XCTAssertEqual(
      go(.places, up: [.timer]),
      [.showHomeWindow, .close(.timer), .wait(milliseconds: 700), .present(.places)])
    XCTAssertEqual(HomeStack.coverSettles, 700)
  }

  func testEverythingALinkNamesClosesTopFirstAndASheetStays() {
    XCTAssertEqual(
      go(.cockpit, up: [.chat, .today, .call, .eulogySong, .homeSettings, .whatsNew, .timer]),
      [
        .showHomeWindow, .close(.timer), .close(.call), .close(.today), .close(.chat), .wait(milliseconds: 700),
        .present(.cockpit),
      ])
    XCTAssertEqual(go(.places, up: [.eulogySong]), [.showHomeWindow, .present(.places)], "no cover is going down")
  }

  func testTheScreenAlreadyInFrontStaysWhenTheLinkStartsNothing() {
    XCTAssertEqual(go(.timer(TimerLink()), up: [.timer]), [.showHomeWindow])
    XCTAssertEqual(go(.home), [.showHomeWindow])
    XCTAssertEqual(go(.home, up: [.eulogySong]), [.showHomeWindow])
    XCTAssertEqual(go(.chat(thread: nil), up: [.chat]), [.showHomeWindow])
    // Only the front counts: Today under the timer is not in front.
    XCTAssertEqual(
      go(.today, up: [.timer, .today]),
      [.showHomeWindow, .close(.timer), .close(.today), .wait(milliseconds: 700), .present(.today)])
  }

  func testALinkThatStartsSomethingReopensTheScreenInFront() {
    let start = AppRoute.timer(TimerLink(start: true))
    XCTAssertEqual(
      go(start, up: [.timer]), [.showHomeWindow, .close(.timer), .wait(milliseconds: 700), .present(start)])
    let thread = AppRoute.chat(thread: "t")
    XCTAssertEqual(
      go(thread, up: [.chat]), [.showHomeWindow, .close(.chat), .wait(milliseconds: 700), .present(thread)])
  }

  func testTheCallScreenInFrontStaysAndIsPresentedAgain() {
    XCTAssertEqual(go(.call(via: .eleven), up: [.call]), [.showHomeWindow, .present(.call(via: .eleven))])
    // Under another cover it is not in front: it closes and comes back.
    XCTAssertEqual(
      go(.call(via: nil), up: [.cockpit, .call]),
      [.showHomeWindow, .close(.cockpit), .close(.call), .wait(milliseconds: 700), .present(.call(via: nil))])
  }

  func testHomeClosesWhatIsUp() {
    XCTAssertEqual(
      go(.home, up: [.breathe]), [.showHomeWindow, .close(.breathe), .wait(milliseconds: 700), .present(.home)])
  }

  func testTheSupermixMovesNothing() {
    XCTAssertEqual(go(.supermix, up: [.timer, .chat]), [.present(.supermix)])
    XCTAssertEqual(go(.supermix, up: [], ownWindow: true), [.present(.supermix)])
  }

  func testAScreenInAWindowOfItsOwnLeavesTheHomeWindowAlone() {
    XCTAssertEqual(go(.cockpit, up: [.timer], ownWindow: true), [.present(.cockpit)])
    XCTAssertEqual(go(.chat(thread: "t"), up: [], ownWindow: true), [.present(.chat(thread: "t"))])
  }

  /// #808 next step: the wait is a task nothing cancels, so a second link inside it does not replace the first.
  /// The second sees the stack the first already emptied and presents at once; the first's present still comes
  /// after its wait, and both are asked for. This pins what the steps are today; the fix is one routing task that a
  /// newer `go` cancels, and then this test changes.
  func testTwoLinksInsideTheWaitEachPresent() {
    var up: Set<Screen> = [.timer]
    var presented: [AppRoute] = []
    /// Runs steps as AppModel does, up to a wait; what is left is what its task would do later.
    func carryOut(_ steps: [Step]) -> [Step] {
      for (index, step) in steps.enumerated() {
        switch step {
        case .showHomeWindow: break
        case .close(let screen): up.remove(screen)
        case .present(let route):
          presented.append(route)
          if let screen = Screen(route: route) { up.insert(screen) }
        case .wait: return Array(steps[(index + 1)...])
        }
      }
      return []
    }
    let firstLater = carryOut(go(.places, up: up))
    XCTAssertEqual(firstLater, [.present(.places)])
    XCTAssertEqual(up, [])
    let secondLater = carryOut(go(.cockpit, up: up))
    XCTAssertEqual(secondLater, [], "nothing is up any more, so the second link does not wait")
    XCTAssertEqual(presented, [.cockpit])
    _ = carryOut(firstLater)  // 700 ms after the first link
    XCTAssertEqual(presented, [.cockpit, .places], "the first link's screen is still asked for, over the second's")
    XCTAssertEqual(up, [.cockpit, .places])
  }
}
