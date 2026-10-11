//  #219: Think of a card is Think a Card Trainer's own screen, shared. The home row opens it with the ask started:
//  a card up, a small count, then a new card. A tap on the middle switches the card; Done goes home. The simulator
//  has no sound, so the spoken card is the phone's to check. Screenshots stay local (they show cards, not positions).

import XCTest

final class CardUITests: XCTestCase {
  // #229: the trainer speaks the card in lower case ("two of spades").
  private let cardName = NSPredicate(format: "label MATCHES[c] %@", ".* of (spades|hearts|diamonds|clubs)")

  func testTheTrainersScreenAsksThenDeals() throws {
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-think_a_card"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()

    let card = app.descendants(matching: .any).matching(cardName).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
    // The ask started from the row: the count's digit is up beside the card. The rank is a digit too (a two shows
    // "2"), so the count is the small one.
    let count = app.staticTexts.matching(NSPredicate(format: "label IN {'3', '2', '1'}"))
    let counting = NSPredicate { _, _ in count.allElementsBoundByIndex.contains { $0.exists && $0.frame.height < 100 } }
    expectation(for: counting, evaluatedWith: count)
    waitForExpectations(timeout: 3)
    shot("card-asking")
    let asked = card.label
    // Three beats, then the new card and no count.
    let dealt = NSPredicate { _, _ in !count.allElementsBoundByIndex.contains { $0.exists && $0.frame.height < 100 } }
    expectation(for: dealt, evaluatedWith: count)
    waitForExpectations(timeout: 8)
    XCTAssertNotEqual(card.label, asked, "the ask dealt a new card")
    shot("card-dealt")

    // A tap on the middle third switches the card.
    let before = card.label
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let switched = NSPredicate(format: "label != %@", before)
    expectation(for: switched, evaluatedWith: card)
    waitForExpectations(timeout: 5)

    app.buttons["card-done"].tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5), "back home")
  }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
