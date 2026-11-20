import Foundation
import XCTest

@testable import ContextCore

/// Story 157: the share extension and the app agree on one folder in the App Group, apart from the Inbox.
final class ShareReportsTests: XCTestCase {
  func testTheReportsFolderIsItsOwnFolderOfTheGroup() {
    let container = URL(fileURLWithPath: "/tmp/group.com.idvorkin.grabbernative", isDirectory: true)
    let folder = ShareReports.folder(in: container)
    XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, container.standardizedFileURL)
    XCTAssertEqual(folder.lastPathComponent, "BugKit-share")
    XCTAssertNotEqual(folder.lastPathComponent, "Inbox")
  }
}
