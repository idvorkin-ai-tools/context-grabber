//  Story 306 (#592) on the simulator: a white picture opened full size, against the fake Cockpit
//  (scripts/native/test-chat-ui.sh starts it), shows Done on a dark badge and closes with Done or a swipe down.

import XCTest

final class ChatImageUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func openPicture() throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_CHAT_IMAGE"] = "open"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.592"
    app.launch()
    XCTAssertTrue(app.buttons["chat-image-done"].waitForExistence(timeout: 20), app.debugDescription)
    return app
  }

  /// How bright the screen is at a point, 0 to 255; white and the black badge are greys, so one channel will do.
  private func brightness(at point: CGPoint, in shot: XCUIScreenshot) throws -> UInt8 {
    let image = shot.image
    let cg = try XCTUnwrap(image.cgImage)
    var pixel: [UInt8] = [0, 0, 0, 255]
    let context = try XCTUnwrap(
      CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let x = point.x * image.scale
    let y = point.y * image.scale
    context.draw(
      cg, in: CGRect(x: -x, y: y + 1 - CGFloat(cg.height), width: CGFloat(cg.width), height: CGFloat(cg.height)))
    return pixel[0]
  }

  func testDoneShowsOverAWhitePictureAndCloses() throws {
    let app = try openPicture()
    let done = app.buttons["chat-image-done"]
    XCTAssertTrue(done.isHittable, app.debugDescription)

    // Beside the badge is the white picture (once it has loaded), and inside the badge, left of the word, it is dark.
    let frame = done.frame
    let beside = CGPoint(x: frame.minX - 4, y: frame.midY)
    let inside = CGPoint(x: frame.minX + 8, y: frame.midY)
    let deadline = Date().addingTimeInterval(10)
    var shot = XCUIScreen.main.screenshot()
    while try brightness(at: beside, in: shot) < 240, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.5)
      shot = XCUIScreen.main.screenshot()
    }
    add(XCTAttachment(screenshot: shot))
    XCTAssertGreaterThan(try brightness(at: beside, in: shot), 240, "the picture is white beside Done")
    XCTAssertLessThan(try brightness(at: inside, in: shot), 140, "Done has a dark badge over the white")

    done.tap()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), app.debugDescription)
  }

  func testASwipeDownClosesAndASwipeUpDoesNot() throws {
    let app = try openPicture()
    let done = app.buttons["chat-image-done"]
    app.swipeUp()
    XCTAssertFalse(done.waitForNonExistence(timeout: 2), "only a swipe down closes it")
    app.swipeDown()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), app.debugDescription)
  }
}
