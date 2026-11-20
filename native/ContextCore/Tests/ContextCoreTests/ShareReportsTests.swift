import Foundation
import XCTest

@testable import ContextCore

/// Story 157: the share extension and the app agree on one folder in the App Group, apart from the Inbox.
final class ShareReportsTests: XCTestCase {
  private var container: URL!

  override func setUpWithError() throws {
    container = FileManager.default.temporaryDirectory.appendingPathComponent(
      "share-reports-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: container)
  }

  func testTheReportsFolderIsAFolderOfTheGroupApartFromTheInbox() {
    let folder = ShareReports.folder(in: container)
    XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, container.standardizedFileURL)
    let inboxes = [
      InboxStore.mac(base: container, cockpit: CockpitPage.url).directory,
      InboxStore.mac(base: container, cockpit: "http://test.invalid").directory,
    ].map(\.standardizedFileURL)
    XCTAssertFalse(inboxes.contains(folder.standardizedFileURL))
    let taking = container.appendingPathComponent(folder.lastPathComponent + ".taking-1", isDirectory: true)
    XCTAssertFalse(inboxes.contains(taking.standardizedFileURL))
  }

  func testTakingTheReportsFolderLeavesTheInboxAlone() throws {
    let inbox = InboxStore.mac(base: container, cockpit: CockpitPage.url)
    try inbox.add(InboxItem(kind: .text, sharedAt: 1, text: "kept"))
    let folder = ShareReports.folder(in: container)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: folder.appendingPathComponent("index.json"))
    let taking = container.appendingPathComponent(folder.lastPathComponent + ".taking-1", isDirectory: true)
    try FileManager.default.moveItem(at: folder, to: taking)
    try FileManager.default.removeItem(at: taking)
    XCTAssertEqual(inbox.items().items.map(\.text), ["kept"])
  }
}
