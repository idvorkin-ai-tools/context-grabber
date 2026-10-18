import XCTest

@testable import ContextCore

/// Story 139 (#372): the Workout Supermix opens Igor's mix straight in YouTube Music, and the Links screen says so.
final class WorkoutSupermixTests: XCTestCase {
  func testTheLinkIsTheWatchLinkIgorGaveAsIs() throws {
    // Igor's link from #372, without the &si= he dropped: a watch link, not a playlist.
    XCTAssertEqual(WorkoutSupermix.link.absoluteString, "https://music.youtube.com/watch?v=SsLFxyVjVqQ")
    let parts = try XCTUnwrap(URLComponents(url: WorkoutSupermix.link, resolvingAgainstBaseURL: false))
    XCTAssertEqual(parts.scheme, "https", "a universal link, not shortcuts://")
    XCTAssertEqual(parts.host, "music.youtube.com")
    XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "v", value: "SsLFxyVjVqQ")], "no si, no list")
  }

  // Story 221 (#383): the press-and-hold menu, in Igor's order, each a YouTube Music universal link.
  func testTheMenuOffersWorkoutLikedAndFeelGoodAsYouTubeMusicLinks() throws {
    XCTAssertEqual(
      WorkoutSupermix.Mix.allCases.map(\.title), ["Workout Supermix", "Liked music", "Feel Good Supermix"])
    XCTAssertEqual(WorkoutSupermix.Mix.workout.link, WorkoutSupermix.link, "a tap and the menu's first open the same")
    for mix in WorkoutSupermix.Mix.allCases {
      let parts = try XCTUnwrap(URLComponents(url: mix.link, resolvingAgainstBaseURL: false))
      XCTAssertEqual(parts.scheme, "https", mix.title)
      XCTAssertEqual(parts.host, "music.youtube.com", mix.title)
    }
    XCTAssertEqual(WorkoutSupermix.Mix.liked.link.query, "list=LM")
    XCTAssertEqual(
      WorkoutSupermix.Mix.feelGood.link.query, "list=RDTMAK5uy_nuKPeaybq-IRcrMnaR-5TIfvKxB7fVJu0", "no feature=share")
  }

  func testTheLinksScreenDescribesTheDirectLinkNotTheShortcut() throws {
    let supermix = try XCTUnwrap(AppLink.catalog.first { AppLink.parse($0.link).route == .supermix })
    XCTAssertEqual(supermix.link, "grabbernative://supermix")
    XCTAssertEqual(supermix.summary, "Workout Supermix: opens your mix in YouTube Music")
    XCTAssertFalse(supermix.summary.localizedCaseInsensitiveContains("shortcut"))
  }
}
