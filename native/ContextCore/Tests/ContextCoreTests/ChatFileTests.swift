import UniformTypeIdentifiers
import XCTest

@testable import ContextCore

/// #633, stories 480–494: a document on a chat message, against the Cockpit as it is today (pictures only) and as it
/// would be once it takes files.
final class ChatFileTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir.appendingPathComponent("inbox")) }
  private let cockpit = "https://cockpit.test"
  private let pdf = Data("%PDF-1.7 a small document".utf8)
  /// What the real Cockpit answers a PDF with today (attachments.py).
  private let picturesOnly = #"{"ok": false, "error": "not an image Cockpit accepts (png, jpeg, gif or webp)"}"#

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("chat-file-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  private func file(_ name: String, _ data: Data) throws -> URL {
    let url = dir.appendingPathComponent(name)
    try data.write(to: url)
    return url
  }

  private func saved(note: String = "", thread: String? = nil, name: String = "report.pdf") throws -> InboxItem {
    var draft = InboxDraft()
    draft.text = note
    draft.file = ChatFile(name: name, data: pdf)
    return try draft.save(to: store, at: 1, thread: thread)
  }

  // MARK: The pick (stories 480, 483, 493, 494)

  func testAPDFIsADocumentAndAPictureGoesAsAPicture() throws {
    XCTAssertEqual(
      try ChatFile.read(file("report.pdf", pdf)), .file(ChatFile(name: "report.pdf", data: pdf)))
    let png = try InboxTests.image(.png, side: 8)
    XCTAssertEqual(try ChatFile.read(file("shot.png", png)), .image(png))
    // Named like a picture but not one: it stays a document rather than failing later.
    let notPicture = Data("hello".utf8)
    XCTAssertEqual(
      try ChatFile.read(file("fake.png", notPicture)), .file(ChatFile(name: "fake.png", data: notPicture)))
  }

  func testTooBigEmptyAndUnreadableEachSaySoNamingTheFile() throws {
    XCTAssertThrowsError(try ChatFile.read(file("big.pdf", Data(count: 11)), maxBytes: 10)) {
      XCTAssertEqual($0 as? ChatFile.Problem, .tooBig(name: "big.pdf", bytes: 11, limit: 10))
    }
    XCTAssertThrowsError(try ChatFile.read(file("empty.pdf", Data()))) {
      XCTAssertEqual($0 as? ChatFile.Problem, .empty(name: "empty.pdf"))
      XCTAssertTrue($0.localizedDescription.contains("empty.pdf"))
    }
    XCTAssertThrowsError(try ChatFile.read(dir.appendingPathComponent("gone.pdf"))) {
      guard case .unreadable(let name, _)? = $0 as? ChatFile.Problem else { return XCTFail("\($0)") }
      XCTAssertEqual(name, "gone.pdf")
    }
    let big = ChatFile.Problem.tooBig(name: "big.pdf", bytes: 12_000_000, limit: ChatFile.maxBytes)
    XCTAssertTrue(try XCTUnwrap(big.errorDescription).contains("big.pdf"))
  }

  /// Story 493's limit is 10 MB: the cap is 10 MiB, so a decimal size would call it 10.5 MB.
  func testTheTooBigProblemStatesTheCapAsTenMB() {
    let over = ChatFile.Problem.tooBig(name: "over.pdf", bytes: 12 * 1024 * 1024, limit: ChatFile.maxBytes)
    XCTAssertEqual(over.errorDescription, "over.pdf is 12 MB, over the 10 MB the Cockpit takes, so it can't go.")
    XCTAssertEqual(ChatFile(name: "cap.pdf", data: Data(count: ChatFile.maxBytes)).size, "10 MB")
  }

  func testAProblemLogsItsCaseAndTypeNeverTheName() throws {
    let tooBig = ChatFile.Problem.tooBig(name: "private-scan.PDF", bytes: 11, limit: 10).logFields
    XCTAssertEqual(tooBig["problem"] as? String, "too_big")
    XCTAssertEqual(tooBig["file_type"] as? String, "pdf")
    XCTAssertEqual(tooBig["bytes"] as? Int, 11)
    XCTAssertEqual(tooBig["limit"] as? Int, 10)
    XCTAssertEqual(ChatFile.Problem.empty(name: "private-scan.pdf").logFields["problem"] as? String, "empty")
    let unreadable = ChatFile.Problem.unreadable(name: "private-scan.pdf", reason: "private-scan.pdf is locked")
    XCTAssertEqual(unreadable.logFields["problem"] as? String, "unreadable")
    for problem in [ChatFile.Problem.empty(name: "private-scan.pdf"), unreadable] {
      XCTAssertFalse("\(problem.logFields)".contains("private-scan"))
    }
    let line = SessionLogLine.encode(type: "chat", t: 0, fields: ["action": "file_picked", "file_type": "pdf"])
    let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: line) as? [String: Any])
    XCTAssertEqual(decoded["file_type"] as? String, "pdf", "a field the log's own type would not overwrite")
  }

  // MARK: The draft and the store (stories 480, 485, 486, 490)

  func testAFileAloneIsAMessageItsNameThenTheWordsAndTheTitle() throws {
    var draft = InboxDraft()
    draft.file = ChatFile(name: "report.pdf", data: pdf)
    XCTAssertTrue(draft.canAdd)
    XCTAssertEqual(draft.byteCount, pdf.count)
    let alone = try draft.save(to: store, at: 1)
    XCTAssertEqual(draft, InboxDraft())
    XCTAssertEqual(alone.kind, .file)
    XCTAssertEqual(store.file(of: alone), pdf)
    XCTAssertEqual(store.imageBytes(of: alone), pdf.count)
    XCTAssertEqual(ChatSend.text(for: alone), "report.pdf")
    XCTAssertEqual(ChatSend.title(for: alone), "report.pdf")
    let noted = try saved(note: "  page 3 please ")
    XCTAssertEqual(ChatSend.text(for: noted), "report.pdf\n\npage 3 please")
    XCTAssertEqual(ChatSend.title(for: noted), "page 3 please")
  }

  func testAPickedJSONIsNotReadAsAnInboxItem() throws {
    let item = try saved(name: "data.json")
    XCTAssertEqual(item.attachedFile, "\(item.id).file")
    let read = store.items()
    XCTAssertEqual(read.items.map(\.id), [item.id])
    XCTAssertEqual(read.unreadable, [])
  }

  func testDeleteTakesTheFileToo() throws {
    let item = try saved()
    try store.delete(item)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.directory.path), [])
  }

  // MARK: The Cockpit as it is: pictures only (stories 484, 487, 491, 492)

  func testARefusedFileSaysWhyStaysAndNoMessageGoesWithoutIt() async throws {
    let item = try saved(note: "look")
    let seen = Paths()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await seen.add(request)
      return ChatTests.answer(request, 400, self.picturesOnly)
    }
    let lines = Lines()
    let report = await sender.sendWaiting { _, fields in lines.add(fields) }
    XCTAssertEqual(report.refused, [item.id])
    let requests = await seen.all
    XCTAssertEqual(requests.map { $0.url?.path }, ["/attachments"])
    XCTAssertEqual(requests[0].httpBody, pdf)
    XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Content-Type"), "application/pdf")

    let kept = try XCTUnwrap(store.item(item.id))
    XCTAssertEqual(kept.status, .refused)
    XCTAssertEqual(store.file(of: kept), pdf, "the file is not lost")
    XCTAssertTrue(kept.canSendAgain)
    let problem = ChatSend.refusal(of: kept)
    XCTAssertTrue(problem.contains("report.pdf"))
    XCTAssertTrue(problem.contains("not an image Cockpit accepts"))
    XCTAssertTrue(problem.contains("Send again"))

    let line = try XCTUnwrap(lines.all.first)
    XCTAssertEqual(line["file_type"] as? String, "pdf")
    XCTAssertFalse("\(line)".contains("report"), "the log holds the type, never the name")
  }

  func testARefusedPictureOrTextStaysWrongForGood() throws {
    var text = try store.add(InboxItem(id: "t", kind: .text, sharedAt: 1, text: "x"))
    try store.markRefused(text.id, reason: "no")
    text = try XCTUnwrap(store.item("t"))
    XCTAssertFalse(text.canSendAgain)
    XCTAssertEqual(ChatSend.refusal(of: text), "Larry refused it: no")
    XCTAssertEqual(ChatSend.refusal(of: text, answeredBy: "idvorkin"), "idvorkin refused it: no")
  }

  func testAFileThePhoneCantReadSaysSoAndOffersNoSendAgain() async throws {
    let item = try saved()
    let bytes = store.directory.appendingPathComponent(try XCTUnwrap(item.attachedFile))
    try FileManager.default.removeItem(at: bytes)
    let sender = InboxSender(store: store, cockpit: cockpit) { _ in
      XCTFail("no request goes without the file")
      throw URLError(.badServerResponse)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.refused, [item.id])
    let gone = try XCTUnwrap(store.item(item.id))
    XCTAssertFalse(gone.canSendAgain)
    let problem = ChatSend.refusal(of: gone)
    XCTAssertTrue(problem.contains("report.pdf"))
    XCTAssertTrue(problem.contains("could not be read from this phone"))
    XCTAssertFalse(problem.contains("Send again"))
    XCTAssertFalse(problem.contains("Cockpit"), "no request reached it")
  }

  func testANewChatsBarSaysWhereARefusedFileStays() async throws {
    let item = try saved()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      ChatTests.answer(request, 400, self.picturesOnly)
    }
    _ = await sender.sendWaiting { _, _ in }
    let line = ChatSend.afterRefusal(of: store.item(item.id))
    XCTAssertTrue(line.contains("Not sent yet"))
    XCTAssertTrue(line.contains("separate chat"))
    var text = try store.add(InboxItem(id: "t", kind: .text, sharedAt: 1, text: "x"))
    try store.markRefused(text.id, reason: "no")
    text = try XCTUnwrap(store.item("t"))
    XCTAssertEqual(
      ChatSend.afterRefusal(of: text), "Larry refused your first message, so the next one starts the chat again.")
  }

  func testSendingAgainTooSoonIsRefusedAgainAndStaysKept() async throws {
    let item = try saved(note: "look", thread: "igor2-88g.9")
    let seen = Paths()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await seen.add(request)
      return ChatTests.answer(request, 400, self.picturesOnly)
    }
    _ = await sender.sendWaiting { _, _ in }
    let first = ChatSend.refusal(of: try XCTUnwrap(store.item(item.id)))
    try store.sendAgain(item.id)
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.refused, [item.id])
    let kept = try XCTUnwrap(store.item(item.id))
    XCTAssertEqual(ChatSend.refusal(of: kept), first)
    XCTAssertTrue(kept.canSendAgain)
    XCTAssertEqual(store.file(of: kept), pdf)
    let requests = await seen.all
    XCTAssertEqual(requests.map { $0.url?.path }, ["/attachments", "/attachments"], "no message goes without it")
  }

  func testAnUnreachableCockpitKeepsItWaiting() async throws {
    let item = try saved()
    let sender = InboxSender(store: store, cockpit: cockpit) { _ in throw URLError(.timedOut) }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertTrue(report.unreachable)
    XCTAssertEqual(store.item(item.id)?.status, .waiting)
    XCTAssertEqual(report.retry?.hasPrefix("file upload:"), true)
  }

  // MARK: The Cockpit once it takes files (stories 486, 488)

  func testSendAgainGoesOnceTheCockpitTakesFilesAsTheSameMessage() async throws {
    let item = try saved(note: "look", thread: "igor2-88g.9")
    let refuse = InboxSender(store: store, cockpit: cockpit) { request in
      ChatTests.answer(request, 400, self.picturesOnly)
    }
    _ = await refuse.sendWaiting { _, _ in }

    try store.sendAgain(item.id)
    XCTAssertEqual(store.item(item.id)?.status, .waiting)
    let seen = Paths()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await seen.add(request)
      if request.url?.path == "/attachments" {
        return ChatTests.answer(request, 200, #"{"ok": true, "ref": "2026-11-03/0123456789abcdef.pdf"}"#)
      }
      return ChatTests.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.9"}"#)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, [item.id])
    let requests = await seen.all
    XCTAssertEqual(requests.map { $0.url?.path }, ["/attachments", "/chat/igor2-88g.9"])
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: XCTUnwrap(requests[1].httpBody)) as? [String: Any])
    XCTAssertEqual(body["id"] as? String, item.id)
    XCTAssertEqual(body["text"] as? String, "report.pdf\n\nlook")
    XCTAssertEqual(body["attachments"] as? [String], ["2026-11-03/0123456789abcdef.pdf"])
  }

  private actor Paths {
    var all: [URLRequest] = []
    func add(_ request: URLRequest) { all.append(request) }
  }

  private final class Lines: @unchecked Sendable {
    var all: [[String: Any]] = []
    func add(_ fields: [String: Any]) { all.append(fields) }
  }
}
