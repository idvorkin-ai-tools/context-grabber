//  Stories 1278, 1275, 1279, 1292, 1293 (#1384) on an iPad simulator, against the fake Cockpit
//  (scripts/native/test-whiteboard-ui.sh starts it): the board's open conversation grows by its grip and pushes the
//  page down; floats as a card at the board's top left that a finger moves and sizes; is kept that way for the next
//  board; and docks back. The bounds are
//  `WhiteboardPanelPlaceTests`, on the host. The Pencil on the card is the iPad's check.

import XCTest

final class WhiteboardConversationPlaceUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  private func launch() throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launch()
    return app
  }

  /// A new board with one stroke, Larry's turn taken so the board has its thread, and the conversation open.
  private func openPanel(_ app: XCUIApplication) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    sleep(1)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    send.tap()
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 15), app.debugDescription)
    let look = app.segmentedControls["whiteboard-conversation-look"]
    if !look.exists { chevron.tap() }
    XCTAssertTrue(look.appears(within: 5), app.debugDescription)
  }

  func testTheConversationResizesFloatsAndDocks() throws {
    var app = try launch()
    openPanel(app)
    addTeardownBlock {
      // Docked, its own height and closed, for the next test: these all outlive the launch.
      let dock = app.buttons["whiteboard-conversation-dock"]
      if dock.exists { dock.tap() }
      let grip = app.descendants(matching: .any)["whiteboard-conversation-grip"].firstMatch
      if grip.exists { grip.doubleTap() }
      let chevron = app.buttons["whiteboard-note-chevron"]
      if app.segmentedControls["whiteboard-conversation-look"].exists, chevron.exists { chevron.tap() }
    }
    let help = app.buttons["whiteboard-help"]
    XCTAssertTrue(help.appears(within: 5), app.debugDescription)
    let window = app.windows.firstMatch.frame

    // Story 1278: the grip, dragged down, grows the panel and the page moves down with it.
    let grip = app.descendants(matching: .any)["whiteboard-conversation-grip"].firstMatch
    XCTAssertTrue(grip.appears(within: 5), app.debugDescription)
    let paperTop = help.frame.minY
    drag(grip, dx: 0, dy: 200)
    sleep(1)
    XCTAssertGreaterThan(help.frame.minY, paperTop + 150, "the page moved down with the panel")
    let grown = help.frame.minY

    // Story 1279: Float makes it a card at the top left, and the page goes back up.
    app.buttons["whiteboard-conversation-float"].tap()
    let card = app.descendants(matching: .any)["whiteboard-conversation-card"].firstMatch
    XCTAssertTrue(card.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(help.frame.minY, grown - 150, "floating, the page is back up")
    XCTAssertLessThan(card.frame.midX, window.midX, "it starts at the left")
    shot(app, "whiteboard-conversation-card")

    // Its top edge moves it.
    let before = card.frame
    let handle = app.descendants(matching: .any)["whiteboard-conversation-card-move"].firstMatch
    drag(handle, dx: 300, dy: 200)
    sleep(1)
    XCTAssertEqual(card.frame.minX, before.minX + 300, accuracy: 30, "moved right with the finger")
    XCTAssertEqual(card.frame.minY, before.minY + 200, accuracy: 30, "moved down with the finger")

    // Its corner sizes it.
    let moved = card.frame
    let corner = app.descendants(matching: .any)["whiteboard-conversation-card-size"].firstMatch
    drag(corner, dx: 120, dy: 100)
    sleep(1)
    XCTAssertGreaterThan(card.frame.width, moved.width + 80, "wider")
    XCTAssertGreaterThan(card.frame.height, moved.height + 60, "taller")
    let sized = card.frame

    // Story 1292: another board, after a relaunch: the card is where it was left.
    app.terminate()
    app = try launch()
    openPanel(app)
    let again = app.descendants(matching: .any)["whiteboard-conversation-card"].firstMatch
    XCTAssertTrue(again.appears(within: 5), app.debugDescription)
    XCTAssertEqual(again.frame.minX, sized.minX, accuracy: 4)
    XCTAssertEqual(again.frame.width, sized.width, accuracy: 4)

    // Story 1293: Dock: above the board again, at the height it was dragged to.
    app.buttons["whiteboard-conversation-dock"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard-conversation-grip"].firstMatch.appears(within: 5))
    XCTAssertFalse(again.exists)
    XCTAssertEqual(app.buttons["whiteboard-help"].frame.minY, grown, accuracy: 30, "docked at its dragged height")

    // Story 1275: a double tap on the grip gives it back its own size.
    app.descendants(matching: .any)["whiteboard-conversation-grip"].firstMatch.doubleTap()
    sleep(1)
    XCTAssertLessThan(app.buttons["whiteboard-help"].frame.minY, grown - 150, "its own size again")
  }

  /// A finger held on `element`, then moved `dx`, `dy` points.
  private func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
    let from = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: dx, dy: dy)))
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }
}
