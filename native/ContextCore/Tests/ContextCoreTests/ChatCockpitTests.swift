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

  // MARK: A Mac build (#680, stories 582-583)

  func testAMacBuildWithNoAddressReachesTheRealCockpitOnEveryRoute() {
    XCTAssertEqual(ChatCockpit.address(override: nil, simulator: false), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.pageAddress(override: nil), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.pageAddress(override: ""), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: nil, mac: true), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: "", mac: true), CockpitPage.url)
  }

  func testATestLaunchOnAMacNamedNowhereReachesNothingOnEveryRoute() {
    XCTAssertEqual(ChatCockpit.address(override: ChatCockpit.nowhere, simulator: false), ChatCockpit.nowhere)
    XCTAssertEqual(ChatCockpit.pageAddress(override: ChatCockpit.nowhere), ChatCockpit.nowhere)
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: ChatCockpit.nowhere, mac: true), ChatCockpit.nowhere)
  }

  func testAMacBuildGoesWhereItIsPointed() {
    XCTAssertEqual(ChatCockpit.pageAddress(override: "http://127.0.0.1:8797"), "http://127.0.0.1:8797")
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: "http://127.0.0.1:8797", mac: true), "http://127.0.0.1:8797")
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: CockpitPage.url, mac: true), CockpitPage.url)
  }

  func testAPhoneAndASimulatorKeepThePageAndTheCallOnTheRealCockpit() {
    XCTAssertEqual(ChatCockpit.pageAddress(override: nil), CockpitPage.url)
    XCTAssertEqual(ChatCockpit.pageAddress(override: "http://localhost:8797"), "http://localhost:8797")
    XCTAssertEqual(ChatCockpit.callAddress(chatOverride: "http://localhost:8797", mac: false), CockpitPage.url)
  }

  func testTheMacsReasonNamesTheMac() {
    XCTAssertTrue(ChatCockpit.noAddress(mac: true).hasPrefix("This Mac build has no Cockpit address"))
    XCTAssertTrue(ChatCockpit.noAddress(mac: false).hasPrefix("This simulator has no Cockpit address"))
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

  // MARK: A Mac's two outboxes (#680, story 588)

  private func send(_ outbox: InboxStore, to cockpit: String, asked: Asked) async -> InboxSender.Report {
    let sender = InboxSender(store: outbox, cockpit: cockpit) { request in
      await asked.add(request.url?.absoluteString)
      let url = try XCTUnwrap(request.url)
      let ok = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      return (Data(#"{"ok": true, "thread": "t"}"#.utf8), ok)
    }
    return await sender.sendWaiting(log: { _, _ in })
  }

  func testAMessageATestLaunchHeldNeverGoesToTheRealCockpitOnAPlainLaunch() async throws {
    let held = InboxStore.mac(base: dir, cockpit: ChatCockpit.nowhere)
    try held.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "test", thread: "t"))
    let asked = Asked()
    let plain = ChatCockpit.address(override: nil, simulator: false)
    let report = await send(InboxStore.mac(base: dir, cockpit: plain), to: plain, asked: asked)
    let requests = await asked.count
    XCTAssertEqual(requests, 0)
    XCTAssertEqual(report.sent, [])
    XCTAssertEqual(held.waitingCount, 1, "it still waits for a test launch")
  }

  func testAMessageATestLaunchHeldGoesOnceToTheStandInALaterTestLaunchNames() async throws {
    let held = InboxStore.mac(base: dir, cockpit: ChatCockpit.nowhere)
    try held.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "test", thread: "t"))
    let asked = Asked()
    let standIn = "http://127.0.0.1:8797"
    let first = await send(InboxStore.mac(base: dir, cockpit: standIn), to: standIn, asked: asked)
    let second = await send(InboxStore.mac(base: dir, cockpit: standIn), to: standIn, asked: asked)
    let urls = await asked.urls
    XCTAssertEqual(first.sent, ["a"])
    XCTAssertEqual(second.sent, [])
    XCTAssertEqual(urls, ["http://127.0.0.1:8797/chat/t"])
  }

  func testARealMessageWaitingNeverGoesToAStandInAndGoesOnTheNextPlainLaunch() async throws {
    let real = InboxStore.mac(base: dir, cockpit: CockpitPage.url)
    try real.add(InboxItem(id: "a", kind: .text, sharedAt: 1, text: "real", thread: "t"))
    let asked = Asked()
    let standIn = "http://127.0.0.1:8797"
    let toStandIn = await send(InboxStore.mac(base: dir, cockpit: standIn), to: standIn, asked: asked)
    let requests = await asked.count
    XCTAssertEqual(toStandIn.sent, [])
    XCTAssertEqual(requests, 0)
    XCTAssertEqual(real.waitingCount, 1, "not marked sent")
    let plain = await send(InboxStore.mac(base: dir, cockpit: CockpitPage.url), to: CockpitPage.url, asked: asked)
    let urls = await asked.urls
    XCTAssertEqual(plain.sent, ["a"])
    XCTAssertEqual(urls, ["\(CockpitPage.url)/chat/t"])
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
