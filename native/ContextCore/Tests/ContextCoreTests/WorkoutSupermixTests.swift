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

  func testTheLinksScreenDescribesTheDirectLinkNotTheShortcut() throws {
    let supermix = try XCTUnwrap(AppLink.catalog.first { AppLink.parse($0.link).route == .supermix })
    XCTAssertEqual(supermix.link, "grabbernative://supermix")
    XCTAssertEqual(supermix.summary, "Workout Supermix: opens your mix in YouTube Music")
    XCTAssertFalse(supermix.summary.localizedCaseInsensitiveContains("shortcut"))
  }
}
