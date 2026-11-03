import XCTest

@testable import ContextCore

/// #525, stories 507–511: a simulator's chat reaches only the Cockpit it was pointed at.
final class ChatCockpitTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("chat-cockpit-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  // MARK: The decision

  func testASimulatorWithNoAddressGoesNowhereNotToTheRealCockpit() {
    XCTAssertEqual(ChatCockpit.address(override: nil, simulator: true), ChatCockpit.nowhere)
    XCTAssertEqual(ChatCockpit.address(override: "", simulator: true), ChatCockpit.nowhere, "empty counts as unset")
    XCTAssertNotEqual(ChatCockpit.nowhere, CockpitPage.url)
  }

  func testASimulatorGoesWhereItIsPointedEvenTheRealCockpit() {
    XCTAssertEqual(ChatCockpit.address(override: "http://localhost:8797", simulator: true), "http://localhost:8797")
    XCTAssertEqual(ChatCockpit.address(override: CockpitPage.url, simulator: true), CockpitPage.url)
  }

  func testADeviceIsUnchanged() {
    XCTAssertEqual(ChatCockpit.address(override: nil, simulator: false), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.address(override: "", simulator: false), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.address(override: "http://localhost:8797", simulator: false), "http://localhost:8797")
  }

  // MARK: The outbox

  func testLeftoverMessagesStayWaitingAndTheLogSaysWhy() async throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "smoke: a leftover", thread: "igor2-88g.900"))
    try store.add(InboxItem(id: "b", kind: .link, sharedAt: 2, url: "https://example.com/x"))
    let asked = Asked()
    let address = ChatCockpit.address(override: nil, simulator: true)
    let sender = InboxSender(store: store, cockpit: address) { request in
      await asked.add()
      let url = try XCTUnwrap(request.url)
      let ok = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      return (Data(#"{"ok": true, "thread": "t"}"#.utf8), ok)
    }
    var lines: [(String, [String: Any])] = []
    let report = await sender.sendWaiting(log: { lines.append(($0, $1)) })
    let requests = await asked.count
    XCTAssertEqual(requests, 0, "nothing leaves")
    XCTAssertEqual(report, InboxSender.Report(), "not a failure: no retry, no refusal, so no backoff")
    XCTAssertEqual(store.items().items.map(\.status), [.waiting, .waiting])
    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines.first?.0, "inbox")
    XCTAssertEqual(lines.first?.1["action"] as? String, "no_address")
    XCTAssertEqual(lines.first?.1["waiting"] as? Int, 2)
    XCTAssertEqual(lines.first?.1["reason"] as? String, ChatCockpit.noAddress)
  }

  func testAnEmptyOutboxSaysNothing() async {
    let sender = InboxSender(store: store, cockpit: ChatCockpit.nowhere) { _ in throw URLError(.badURL) }
    var lines = 0
    _ = await sender.sendWaiting(log: { _, _ in lines += 1 })
    XCTAssertEqual(lines, 0)
  }

  func testTheSameMessageGoesOnceWhenALaterLaunchNamesAnAddress() async throws {
    try store.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "smoke: a leftover", thread: "igor2-88g.900"))
    let none = InboxSender(store: store, cockpit: ChatCockpit.nowhere) { _ in throw URLError(.badURL) }
    _ = await none.sendWaiting(log: { _, _ in })
    XCTAssertEqual(store.waitingCount, 1)
    let asked = Asked()
    let pointed = InboxSender(store: store, cockpit: "http://localhost:8797") { request in
      await asked.add(request.url?.absoluteString)
      let url = try XCTUnwrap(request.url)
      let ok = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      return (Data(#"{"ok": true, "thread": "igor2-88g.900"}"#.utf8), ok)
    }
    let first = await pointed.sendWaiting(log: { _, _ in })
    let second = await pointed.sendWaiting(log: { _, _ in })
    let urls = await asked.urls
    XCTAssertEqual(first.sent, ["a"])
    XCTAssertEqual(second.sent, [])
    XCTAssertEqual(urls, ["http://localhost:8797/chat/igor2-88g.900"])
  }

  // MARK: The share card

  func testTheShareCardAsksNothingAndSaysWhy() async {
    let asked = Asked()
    let read = await ShareThreads.read(cockpit: ChatCockpit.nowhere) { _ in
      await asked.add()
      throw URLError(.cannotFindHost)
    }
    let requests = await asked.count
    XCTAssertEqual(requests, 0)
    XCTAssertEqual(read, .problem("New chat only: \(ChatCockpit.noAddress)."))
  }
}

private actor Asked {
  private(set) var urls: [String?] = []
  var count: Int { urls.count }
  func add(_ url: String? = nil) { urls.append(url) }
}
