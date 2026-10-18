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

  func testTheRequestCarriesTheContractAndTheCockpitsOrigin() throws {
    let item = InboxItem(
      id: "0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22", kind: .link, sharedAt: 1_792_000_000_000,
      url: "https://example.com/article", note: "read on the plane")
    let request = try InboxSend.request(item, image: nil, cockpit: "https://c-5004.squeaker-teeth.ts.net")
    XCTAssertEqual(request.url?.absoluteString, "https://c-5004.squeaker-teeth.ts.net/inbox")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://c-5004.squeaker-teeth.ts.net")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "no token is set up")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["id"] as? String, item.id)
    XCTAssertEqual(body["kind"] as? String, "link")
    XCTAssertEqual(body["url"] as? String, "https://example.com/article")
    XCTAssertEqual(body["note"] as? String, "read on the plane")
    let sharedAt = try XCTUnwrap(body["shared_at"] as? String)
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    XCTAssertEqual(parser.date(from: sharedAt), Date(timeIntervalSince1970: 1_792_000_000))
    XCTAssertNil(body["image"])
  }

  func testAnImageGoesAsPlainBase64() throws {
    let jpeg = try Self.image(.jpeg)
    let body = InboxSend.body(InboxItem(id: "i", kind: .image, sharedAt: 0), image: jpeg)
    let image = try XCTUnwrap(body["image"] as? [String: String])
    XCTAssertEqual(image["data"], jpeg.base64EncodedString())
    XCTAssertFalse(image["data"]?.hasPrefix("data:") ?? true)
    XCTAssertEqual(image["mime"], "image/jpeg")
  }

  func testEveryAnswerClass() {
    let ok = Data(#"{"ok": true, "id": "a", "received_at": "2026-10-18T04:16:54-07:00"}"#.utf8)
    let dup = Data(#"{"ok": true, "id": "a", "received_at": "x", "duplicate": true, "version": "9"}"#.utf8)
    let bad = Data(#"{"ok": false, "reason": "image over 10 MB", "error": "image over 10 MB"}"#.utf8)
    XCTAssertEqual(InboxSend.outcome(status: 200, body: ok), .sent(duplicate: false))
    XCTAssertEqual(InboxSend.outcome(status: 200, body: dup), .sent(duplicate: true))
    XCTAssertEqual(InboxSend.outcome(status: 413, body: bad), .refused(status: 413, reason: "image over 10 MB"))
    XCTAssertEqual(InboxSend.outcome(status: 403, body: nil), .refused(status: 403, reason: "HTTP 403"))
    XCTAssertEqual(InboxSend.outcome(status: 503, body: Data("down".utf8)), .retry(reason: "HTTP 503"))
    XCTAssertEqual(InboxSend.outcome(status: nil, body: nil, error: "offline"), .retry(reason: "offline"))
  }

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
      let body = status == 200 ? #"{"ok": true}"# : #"{"ok": false, "reason": "nope"}"#
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
