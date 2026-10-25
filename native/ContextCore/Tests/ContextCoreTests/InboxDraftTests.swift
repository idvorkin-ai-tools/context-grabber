//  #405, stories 262–264: compose into the same store as shares; clear only after a successful save.

import XCTest

@testable import ContextCore

final class InboxDraftTests: XCTestCase {
  func testEmptyDraftCannotBeSaved() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = InboxStore(directory: directory)
    var draft = InboxDraft()
    draft.text = " \n\t "
    draft.image = Data()
    XCTAssertFalse(draft.canAdd)
    XCTAssertThrowsError(try draft.save(to: store, at: 1))
    XCTAssertTrue(store.items().items.isEmpty)
    XCTAssertEqual(draft.text, " \n\t ")
  }

  func testTextSavesAsWaitingWithUTF8ByteSizeAndClearsForAnother() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = InboxStore(directory: directory)
    var draft = InboxDraft()
    draft.text = " \nA thought 🦝\nAnother line\t "
    XCTAssertTrue(draft.canAdd)
    XCTAssertEqual(draft.byteCount, "A thought 🦝\nAnother line".utf8.count)
    let first = try draft.save(to: store, at: 123)
    XCTAssertEqual(first.kind, .text)
    XCTAssertEqual(first.text, "A thought 🦝\nAnother line")
    XCTAssertEqual(first.sharedAt, 123)
    XCTAssertEqual(first.status, .waiting)
    XCTAssertEqual(UUID(uuidString: first.id)?.uuidString.lowercased(), first.id)
    XCTAssertNil(first.note)
    XCTAssertNil(first.imageFile)
    XCTAssertEqual(draft, InboxDraft())
    draft.text = "https://example.com"
    let second = try draft.save(to: store, at: 124)
    XCTAssertNotEqual(first.id, second.id)
    XCTAssertEqual(second.kind, .text, "a typed URL remains a thought")
    XCTAssertEqual(store.waiting().map(\.id), [first.id, second.id])
    XCTAssertEqual(draft, InboxDraft())
  }

  func testImageWithOptionalNoteIsOneItemAndGoesAsAChatMessage() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = InboxStore(directory: directory)
    let png = try InboxTests.image(.png, side: 8)
    var draft = InboxDraft()
    draft.image = png
    draft.text = "  discuss this 🦝  "
    XCTAssertEqual(draft.byteCount, png.count + "discuss this 🦝".utf8.count)
    let item = try draft.save(to: store, at: 1)
    XCTAssertEqual(item.kind, .image)
    XCTAssertNil(item.text)
    XCTAssertEqual(item.note, "discuss this 🦝")
    XCTAssertEqual(item.imageFile, "\(item.id).png")
    XCTAssertEqual(store.image(of: item), png)
    XCTAssertEqual(store.items().items, [item])
    let request = try ChatSend.messageRequest(
      item, attachment: "2026-10-25/0123456789abcdef.png", cockpit: "https://cockpit.test")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["text"] as? String, "discuss this 🦝")
    XCTAssertEqual(body["title"] as? String, "discuss this 🦝")
    XCTAssertEqual(body["attachments"] as? [String], ["2026-10-25/0123456789abcdef.png"])
    XCTAssertEqual(draft, InboxDraft())
    draft.image = png
    draft.text = " \n "
    XCTAssertTrue(draft.canAdd)
    let imageOnly = try draft.save(to: store, at: 2)
    XCTAssertNil(imageOnly.note)
    XCTAssertEqual(store.waitingCount, 2)
  }

  func testPastedPhotoIsKeptAsCopiedWithItsOwnExtension() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = InboxStore(directory: directory)
    let jpeg = try InboxTests.image(.jpeg, side: 8)
    var draft = InboxDraft()
    draft.image = jpeg
    let item = try draft.save(to: store, at: 1)
    XCTAssertEqual(item.imageFile, "\(item.id).jpeg", "a JPEG is not relabelled as a PNG")
    XCTAssertEqual(store.image(of: item), jpeg, "the bytes as copied, EXIF orientation included, not re-encoded")
  }

  func testFailedSavePreservesTextAndImageForRetry() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    // A regular file cannot serve as the Inbox directory, regardless of host permissions.
    try Data([1]).write(to: directory)
    let store = InboxStore(directory: directory)
    var draft = InboxDraft()
    draft.text = "keep this"
    draft.image = try InboxTests.image(.png, side: 8)
    let original = draft
    XCTAssertThrowsError(try draft.save(to: store, at: 1))
    XCTAssertEqual(draft, original)
    try FileManager.default.removeItem(at: directory)
    let item = try draft.save(to: store, at: 2)
    XCTAssertEqual(store.image(of: item), original.image)
    XCTAssertEqual(item.note, original.text)
    XCTAssertEqual(draft, InboxDraft())
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("inbox-draft-\(UUID().uuidString)")
  }
}
