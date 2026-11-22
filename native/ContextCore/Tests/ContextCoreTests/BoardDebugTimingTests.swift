import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Story 1112 (bead context-grabber-7zmj): the build, the picture's own timings and the mic's, for the Cockpit's board
/// debug page.
final class BoardDebugTimingTests: XCTestCase {
  // MARK: The mic's clock

  func testWordsAfterTheMicClosedCarryEveryGap() throws {
    var clock = BoardMicClock()
    clock.opened(t: 1000)
    clock.heard(t: 1400)
    clock.heard(t: 1900)
    clock.closed(t: 5000)
    let timing = try XCTUnwrap(clock.taken(t: 5600, chars: 12))
    XCTAssertEqual(timing.gaps, ["to_words_ms": 400, "on_to_off_ms": 4000, "off_to_text_ms": 600])
    let events = clock.sent(t: 6100)
    XCTAssertEqual(
      events, [.mic(BoardMicTiming(on: 1000, since: 1000, words: 1400, off: 5000, text: 5600, sent: 6100, chars: 12))])
    XCTAssertEqual(
      events[0].wire as NSDictionary,
      [
        "type": "mic", "t": 1000, "words_t": 1400, "off_t": 5000, "text_t": 5600, "sent_t": 6100, "chars": 12,
        "to_words_ms": 400, "on_to_off_ms": 4000, "off_to_text_ms": 600, "text_to_sent_ms": 500,
      ] as NSDictionary)
    XCTAssertEqual(clock.sent(t: 7000), [], "sent once")
    XCTAssertNil(clock.taken(t: 8000, chars: 3), "the mic closed: nothing more is timed until it opens")
  }

  func testWordsWithTheMicStillOpenAreTimedFromTheWordsBefore() throws {
    var clock = BoardMicClock()
    clock.opened(t: 0)
    clock.heard(t: 300)
    let first = try XCTUnwrap(clock.taken(t: 2000, chars: 5))
    XCTAssertNil(first.off)
    XCTAssertEqual(first.gaps, ["to_words_ms": 300])
    clock.heard(t: 2500)
    clock.closed(t: 4000)
    let second = try XCTUnwrap(clock.taken(t: 4200, chars: 7))
    XCTAssertEqual(second.since, 2000)
    XCTAssertEqual(second.gaps, ["to_words_ms": 500, "on_to_off_ms": 4000, "off_to_text_ms": 200])
    XCTAssertEqual(clock.sent(t: 5000).count, 2)
  }

  func testDroppedWordsAndNoMicAreNotTimed() {
    var clock = BoardMicClock()
    XCTAssertNil(clock.taken(t: 10, chars: 3), "a launch hook's words, no mic")
    clock.opened(t: 0)
    clock.closed(t: 100)
    XCTAssertNotNil(clock.taken(t: 200, chars: 3, kept: false))
    XCTAssertEqual(clock.sent(t: 300), [], "Ghosts off dropped them")
  }

  func testOnlyTheNewestWait() {
    var clock = BoardMicClock()
    clock.opened(t: 0)
    for i in 0..<(BoardMicClock.cap + 5) { clock.taken(t: Int64(i + 1), chars: 1) }
    XCTAssertEqual(clock.waiting.count, BoardMicClock.cap)
    XCTAssertEqual(clock.waiting.first?.text, 6)
  }

  // MARK: What goes to the Cockpit

  /// The board's message as the Cockpit gets it: the build beside the picture's fields, and its `post` and `mic` events
  /// among the rest.
  func testThePicturesMessageCarriesItsBuildAndTimings() throws {
    var picture = WhiteboardPicture(
      board: "b1", title: "Plan", rect: CGRect(x: 0, y: 0, width: 100, height: 50), scale: 2, pictureID: "p1",
      report: BoardTurnReport(
        rev: 3,
        events: [
          .pen(down: true, idleMs: 0, t: 900),
          .mic(BoardMicTiming(on: 1000, since: 1000, words: 1400, off: 5000, text: 5600, sent: 6100, chars: 12)),
        ]))
    picture.build = "abc1234 main"
    picture.report?.events.append(
      .post(
        BoardPostTiming(
          t: 6500, build: "abc1234 main", from: "button", renderMs: 40, encodeMs: 25, strokesMs: 120, uploadMs: 230,
          bytes: 81_000)))
    let item = InboxItem(id: "p1", kind: .image, sharedAt: 6500, note: "Your turn", thread: "t9", whiteboard: picture)
    let request = try ChatSend.messageRequest(item, attachment: "r", cockpit: "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["build"] as? String, "abc1234 main")
    XCTAssertEqual(body["rev"] as? Int, 3)
    let events = try XCTUnwrap(body["events"] as? [[String: Any]])
    XCTAssertEqual(events.map { $0["type"] as? String }, ["pen", "mic", "post"])
    XCTAssertEqual(
      events[2] as NSDictionary,
      [
        "type": "post", "t": 6500, "build": "abc1234 main", "from": "button", "render_ms": 40, "encode_ms": 25,
        "strokes_ms": 120, "upload_ms": 230, "bytes": 81_000,
      ] as NSDictionary)
  }

  func testAPictureWithNoBuildSendsNone() throws {
    let picture = WhiteboardPicture(
      board: "b1", title: "Plan", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1, pictureID: "p1")
    XCTAssertNil(picture.wire["build"])
  }

  func testTheBuildKeptThroughTheOutbox() throws {
    var picture = WhiteboardPicture(
      board: "b1", title: "Plan", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1, pictureID: "p1")
    picture.build = "abc1234 main"
    let back = try JSONDecoder().decode(WhiteboardPicture.self, from: JSONEncoder().encode(picture))
    XCTAssertEqual(back.build, "abc1234 main")
    let old = try JSONDecoder().decode(
      WhiteboardPicture.self,
      from: Data(#"{"board":"b1","picture_id":"p1","title":"t","frame":{"x":0,"y":0,"w":1,"h":1,"scale":1}}"#.utf8))
    XCTAssertNil(old.build, "a picture queued before the build was kept still reads")
  }

  func testEventsSentBetweenTurnsNameTheBuild() throws {
    let request = try BoardEventsSend.request(
      board: "b1", report: BoardTurnReport(rev: 1), cockpit: "https://c.example", build: "abc1234 main")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["build"] as? String, "abc1234 main")
    XCTAssertEqual(body["board"] as? String, "b1")
  }
}
