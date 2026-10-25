import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import ContextCore

/// Stories 038 and 039 (#305): the Inbox on disk, and each item to Larry's inbox per cockpit#63.
final class InboxTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  // MARK: The Inbox (story 038)

  func testItemsListNewestFirstAndWaitingGoesOldestFirst() throws {
    try store.add(InboxItem(id: "a", kind: .link, sharedAt: 1_000, url: "https://example.com/x", note: "read"))
    try store.add(InboxItem(id: "b", kind: .text, sharedAt: 3_000, text: "hello"))
    try store.add(InboxItem(id: "c", kind: .image, sharedAt: 2_000), image: Data([1, 2, 3]), imageExtension: "heic")
    XCTAssertEqual(store.items().items.map(\.id), ["b", "c", "a"])
    XCTAssertEqual(store.waiting().map(\.id), ["a", "c", "b"])
    XCTAssertEqual(store.waitingCount, 3)
    XCTAssertEqual(store.items().items.last?.site, "example.com")
    XCTAssertEqual(store.image(of: store.items().items[1]), Data([1, 2, 3]))
  }

  func testSentAndRefusedLeaveTheCountAndDeleteTakesTheImageToo() throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "x"))
    let photo = try store.add(InboxItem(id: "b", kind: .image, sharedAt: 2), image: Data([9]))
    try store.add(InboxItem(id: "c", kind: .text, sharedAt: 3, text: "y"))
    try store.markSent("a", at: 10)
    try store.markRefused("c", reason: "too big")
    XCTAssertEqual(store.waitingCount, 1)
    XCTAssertEqual(store.items().items.map(\.status), [.refused, .waiting, .sent])
    try store.delete(photo)
    XCTAssertEqual(store.waitingCount, 0)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(), ["a.json", "c.json"])
  }

  func testAnEmptyNoteIsNoNoteAndABrokenFileIsNamedNotFatal() throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "x", note: ""))
    try Data("{".utf8).write(to: dir.appendingPathComponent("broken.json"))
    let read = store.items()
    XCTAssertEqual(read.items.map(\.id), ["a"])
    XCTAssertNil(read.items[0].note)
    XCTAssertEqual(read.unreadable, ["broken.json"])
  }

  // MARK: The request and the answer (story 039, cockpit#63)

  // MARK: Images (story 039: a HEIC photo arrives as a JPEG)

  func testAHEICBecomesAJPEGAndAJPEGGoesAsItIs() throws {
    let heic = try Self.image(.heic)
    let sent = try XCTUnwrap(InboxSend.sendable(heic))
    XCTAssertEqual(InboxSend.mime(of: sent), "image/jpeg")
    let jpeg = try Self.image(.jpeg)
    XCTAssertEqual(InboxSend.sendable(jpeg), jpeg)
    XCTAssertNil(InboxSend.sendable(Data("not an image".utf8)))
  }

  func testAnImageOverTheCapIsMadeSmallerToFit() throws {
    let jpeg = try Self.image(.jpeg, side: 1500)
    let cap = jpeg.count / 3
    let sent = try XCTUnwrap(InboxSend.sendable(jpeg, maxBytes: cap))
    XCTAssertLessThanOrEqual(sent.count, cap)
    XCTAssertEqual(InboxSend.mime(of: sent), "image/jpeg")
  }

  // MARK: The sender (story 039)

  func testTheSenderSendsOldestFirstRecordsEachAnswerAndStopsWhenUnreachable() async throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "one"))
    try store.add(InboxItem(id: "b", kind: .text, sharedAt: 2, text: "two"))
    try store.add(InboxItem(id: "c", kind: .text, sharedAt: 3, text: "three"))
    try store.add(InboxItem(id: "d", kind: .text, sharedAt: 4, text: "four"))
    let seen = Seen()
    let sender = InboxSender(store: store, cockpit: "https://cockpit.test") { request in
      let id = try XCTUnwrap(
        (JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])?["id"] as? String)
      await seen.add(id)
      let status = ["a": 200, "b": 415, "c": 503][id] ?? 200
      let body = status == 200 ? #"{"ok": true, "thread": "t"}"# : #"{"ok": false, "reason": "nope"}"#
      return (
        Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      )
    }
    var lines: [[String: Any]] = []
    let report = await sender.sendWaiting(
      now: { Date(timeIntervalSince1970: 5) }, log: { _, fields in lines.append(fields) })
    let order = await seen.ids
    XCTAssertEqual(order, ["a", "b", "c"], "oldest first, and d waits after the 503")
    XCTAssertEqual(report, InboxSender.Report(sent: ["a"], refused: ["b"], retry: "nope"))
    XCTAssertEqual(store.items().items.map(\.status), [.waiting, .waiting, .refused, .sent])
    XCTAssertEqual(store.items().items.last?.sentAt, 5_000)
    XCTAssertEqual(lines.compactMap { $0["action"] as? String }, ["sent", "refused", "failed"])
    XCTAssertFalse(lines.contains { $0.values.contains { "\($0)".contains("one") } }, "no content in the log")
  }

  func testAnUnreadableImageIsRefusedWithoutAskingTheCockpit() async throws {
    try store.add(InboxItem(id: "p", kind: .image, sharedAt: 1), image: Data("junk".utf8))
    let sender = InboxSender(store: store, cockpit: "https://cockpit.test") { _ in
      XCTFail("nothing sent")
      throw URLError(.badURL)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.refused, ["p"])
    XCTAssertEqual(store.items().items.first?.status, .refused)
  }

  // #406, story 269: a transport failure keeps the item on disk, still counted, for the network-back send.
  func testAFailedSendStaysWaitingAndCanBeSentLater() async throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "one"))
    let failed = InboxSender(store: store, cockpit: "https://cockpit.test") { _ in
      throw URLError(.notConnectedToInternet)
    }
    var actions: [String] = []
    let report = await failed.sendWaiting { _, fields in
      if let action = fields["action"] as? String { actions.append(action) }
    }
    XCTAssertNotNil(report.retry)
    XCTAssertEqual(actions, ["failed"])
    XCTAssertEqual(store.item("a")?.status, .waiting)
    XCTAssertEqual(store.item("a")?.text, "one")
    XCTAssertNil(store.item("a")?.sentAt)
    XCTAssertEqual(store.waitingCount, 1)

    let requests = Seen()
    let online = InboxSender(store: store, cockpit: "https://cockpit.test") { request in
      await requests.add("a")
      return (
        Data(#"{"ok": true, "thread": "t"}"#.utf8),
        try XCTUnwrap(
          HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil))
      )
    }
    let sent = await online.sendWaiting { _, _ in }
    XCTAssertEqual(sent.sent, ["a"])
    XCTAssertEqual(store.item("a")?.status, .sent)
    XCTAssertNotNil(store.item("a")?.sentAt)
    XCTAssertEqual(store.waitingCount, 0)
    let again = await online.sendWaiting { _, _ in }
    XCTAssertTrue(again.sent.isEmpty)
    let sentRequests = await requests.ids
    XCTAssertEqual(sentRequests, ["a"], "an item that reached Larry is not sent again")
  }

  // Local review: an item deleted while an earlier one was being sent never goes.
  func testAnItemDeletedWhileTheSendIsOutIsNotSent() async throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "one"))
    let later = try store.add(InboxItem(id: "b", kind: .text, sharedAt: 2, text: "private"))
    let seen = Seen()
    let store = self.store
    let sender = InboxSender(store: store, cockpit: "https://cockpit.test") { request in
      let id = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])?["id"] as? String
      await seen.add(id ?? "?")
      if id == "a" { try store.delete(later) }  // Igor swipes b away while a is out
      return (
        Data(#"{"ok": true, "thread": "t"}"#.utf8),
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      )
    }
    let report = await sender.sendWaiting { _, _ in }
    let order = await seen.ids
    XCTAssertEqual(order, ["a"])
    XCTAssertEqual(report.sent, ["a"])
  }

  func testAThumbnailIsBoundedWhateverThePhotosSize() throws {
    let big = try Self.image(.jpeg, side: 1500)
    let thumb = try XCTUnwrap(InboxSend.thumbnail(big, maxPixels: 200))
    XCTAssertLessThanOrEqual(max(thumb.width, thumb.height), 200)
    XCTAssertNil(InboxSend.thumbnail(Data("no".utf8)))
  }

  func testASimulatorFixtureIsNeverSent() async throws {
    try store.add(InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: 1, text: "test"))
    let sender = InboxSender(store: store, cockpit: "https://cockpit.test") { _ in
      XCTFail("a fixture reached the Cockpit")
      throw URLError(.badURL)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report, InboxSender.Report())
    XCTAssertEqual(store.waitingCount, 1, "it still shows as waiting on the simulator")
  }

  private actor Seen {
    var ids: [String] = []
    func add(_ id: String) { ids.append(id) }
  }

  /// A noisy picture, so JPEG cannot squash it to nothing.
  static func image(_ type: UTType, side: Int = 400) throws -> Data {
    let ctx = try XCTUnwrap(
      CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    var rng = SystemRandomNumberGenerator()
    for y in stride(from: 0, to: side, by: 4) {
      for x in stride(from: 0, to: side, by: 4) {
        ctx.setFillColor(
          red: .random(in: 0...1, using: &rng), green: .random(in: 0...1, using: &rng),
          blue: .random(in: 0...1, using: &rng), alpha: 1)
        ctx.fill(CGRect(x: x, y: y, width: 4, height: 4))
      }
    }
    let out = NSMutableData()
    let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(dest, try XCTUnwrap(ctx.makeImage()), nil)
    XCTAssertTrue(CGImageDestinationFinalize(dest))
    return out as Data
  }
}
