//  #414, story 255: the two-week grid's calendar, staged edits, summaries and dated unmarks.

import XCTest

@testable import ContextCore

final class CheckFortnightTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
  }

  func testFourteenDaysAcrossMonthAndClockChange() {
    for today in ["2026-11-03", "2026-03-10"] {
      let grid = CheckFortnight(.journal, today: today, marked: [], calendar: calendar)
      XCTAssertEqual(grid.days.count, 14)
      XCTAssertEqual(Set(grid.days.map(\.day)).count, 14)
      XCTAssertEqual(grid.days.map(\.daysAgo), Array((0..<14).reversed()))
      XCTAssertEqual(grid.days.last?.day, today)
      XCTAssertEqual(grid.days.last?.tag, "today")
      XCTAssertEqual(grid.days[12].tag, "yest.")
      XCTAssertEqual(grid.days[11].tag, "")
    }
    let grid = CheckFortnight(.meditation, today: "2026-11-03", marked: ["2026-11-01"], calendar: calendar)
    XCTAssertEqual(grid.days.first?.day, "2026-10-21")
    XCTAssertEqual(grid.days[11].weekday, "S")
    XCTAssertEqual(grid.days[11].number, "1")
    XCTAssertEqual(grid.days[11].accessibilityLabel, "Sunday November 1, done")
    XCTAssertEqual(grid.days.last?.accessibilityLabel, "Tuesday November 3, not done")
    XCTAssertEqual(grid.headline, "1 of the last 14 days")
    XCTAssertEqual(grid.subline, "Last done 2 days ago")
  }

  func testSummaryAndDiffFollowEditsAndTogglingBackClearsChanges() {
    var grid = CheckFortnight(.gym, today: "2026-10-20", marked: ["2026-10-19", "2026-10-06"])
    XCTAssertEqual(grid.subline, "Last done yesterday")
    grid.toggle(12)
    XCTAssertEqual(grid.headline, "0 of the last 14 days")
    XCTAssertEqual(grid.subline, "Last done not in two weeks · 1 change to save")
    grid.toggle(13)
    XCTAssertEqual(grid.subline, "Last done today · 2 changes to save")
    XCTAssertEqual(grid.changes.map(\.daysAgo), [1, 0])
    XCTAssertEqual(grid.changes.map(\.done), [false, true])
    grid.toggle(12)
    grid.toggle(13)
    XCTAssertTrue(grid.changes.isEmpty)
    XCTAssertFalse(grid.days[12].changed)
    XCTAssertEqual(grid.subline, "Last done yesterday")
    grid.toggle(-1)
    grid.toggle(14)
    XCTAssertTrue(grid.changes.isEmpty)
  }

  func testAutomaticEvidenceStaysAsOnTodaysStrip() {
    var grid = CheckFortnight(.gym, today: "2026-10-20", marked: [], automatic: ["2026-10-19"])
    XCTAssertTrue(grid.days[12].done)
    grid.toggle(12)
    XCTAssertTrue(grid.days[12].done)
    XCTAssertTrue(grid.changes.isEmpty)
  }

  func testStagingWritesNothingAndSaveUnmarksPeerWithLatestChange() throws {
    let strip = try DailyStrip(db: SQLiteDatabase())
    let peer = StripRow(day: "2026-10-19", item: .journal, value: 1, updatedAt: 1000)
    try strip.mergePeer("ipad", month: "2026-10", rows: [peer])
    var grid = CheckFortnight(.journal, today: "2026-10-20", marked: try strip.days(.journal))
    grid.toggle(12)
    grid.toggle(11)
    XCTAssertEqual(try strip.value(.journal, day: "2026-10-19"), 1)
    XCTAssertEqual(try strip.value(.journal, day: "2026-10-18"), 0)
    try strip.save(grid, at: Date(timeIntervalSince1970: 2))
    XCTAssertEqual(try strip.value(.journal, day: "2026-10-19"), 0)
    XCTAssertEqual(try strip.value(.journal, day: "2026-10-18"), 1)
    XCTAssertEqual(try strip.ownRows().count, 2, "only changed days written")
    XCTAssertEqual(DailyStrip.daysSince(try strip.days(.journal), today: "2026-10-20"), 2)
    let ipad = try DailyStrip(db: SQLiteDatabase())
    try ipad.set(.journal, day: "2026-10-19", value: 1, at: Date(timeIntervalSince1970: 1))
    try ipad.mergePeer("phone", month: "2026-10", rows: strip.ownRows())
    XCTAssertEqual(try ipad.value(.journal, day: "2026-10-19"), 0)
  }

  func testSaveFailureRollsBackEveryDay() throws {
    let db = try SQLiteDatabase()
    let strip = try DailyStrip(db: db)
    var grid = CheckFortnight(.journal, today: "2026-10-20", marked: [])
    grid.toggle(12)
    grid.toggle(13)
    try db.execute(
      """
      CREATE TRIGGER fail_today BEFORE INSERT ON daily_strip WHEN NEW.date_key = '2026-10-20'
      BEGIN SELECT RAISE(ABORT, 'test failure'); END;
      """)
    XCTAssertThrowsError(try strip.save(grid))
    XCTAssertTrue(try strip.ownRows().isEmpty)
    XCTAssertEqual(grid.changes.count, 2, "edits remain available for retry")
  }
}
