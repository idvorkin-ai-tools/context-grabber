import Foundation
import XCTest

@testable import ContextCore

/// A board's meaning in its own file beside the drawing (bead context-grabber-cc75, story 1106): written after the
/// drawing in one save, moved once from UserDefaults, gone with the board.
final class BoardMeaningTests: XCTestCase {
  private var dir: URL!
  private var defaults: UserDefaults!

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("board-meaning-\(UUID().uuidString)")
    defaults = try XCTUnwrap(UserDefaults(suiteName: "BoardMeaningTests-\(UUID().uuidString)"))
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: dir)
  }

  /// A real disk that notes every write and can refuse one kind of file.
  private final class TestDisk: BoardDisk {
    let disk = FileBoardDisk()
    var refuse: String?
    var changes: [String] = []
    func exists(_ url: URL) -> Bool { disk.exists(url) }
    func read(_ url: URL) throws -> Data { try disk.read(url) }
    func write(_ data: Data, to url: URL) throws {
      changes.append("write \(url.lastPathComponent)")
      if let refuse, url.lastPathComponent.hasSuffix(refuse) { throw CocoaError(.fileWriteOutOfSpace) }
      try disk.write(data, to: url)
    }
    func remove(_ url: URL) throws {
      changes.append("remove \(url.lastPathComponent)")
      try disk.remove(url)
    }
    func move(_ url: URL, to target: URL) throws {
      changes.append("move \(url.lastPathComponent)")
      try disk.move(url, to: target)
    }
    func makeDirectory(_ url: URL) throws { try disk.makeDirectory(url) }
  }

  private func keeping(_ disk: TestDisk = TestDisk()) -> BoardKeeping {
    let keeping = BoardKeeping(dir: dir, disk: disk)
    _ = keeping.readIndex()
    return keeping
  }

  private func sample() throws -> BoardMeaning {
    var meaning = BoardMeaning()
    var applier = BoardOpApplier(rev: 7)
    applier.changed()
    meaning.take(applier)
    meaning.handled = ["m1", "m2"]
    meaning.texts = [BoardText(id: "t1", t: 99, text: "Plan", font: .plain, size: 18, color: "#ba39e6")]
    meaning.strokeIDs.moved(from: ["old"], to: ["new"])
    meaning.strokeMeta.set(try XCTUnwrap(BoardMeta(["group": "g"])), for: "a")
    meaning.headers = [BoardHeader(id: "h1", ids: ["s1"])]
    meaning.questions = WhiteboardQuestions(cards: [WhiteboardQuestion(id: "c1", ask: "a1", x: 80.5, y: 120)])
    return meaning
  }

  // MARK: The file

  func testTheMeaningReadsBackAsItWasWritten() throws {
    let meaning = try sample()
    let back = try JSONDecoder().decode(BoardMeaning.self, from: JSONEncoder().encode(meaning))
    XCTAssertEqual(back, meaning)
    XCTAssertEqual(back.applier.rev, 8)
    XCTAssertEqual(back.applier.handled, ["m1", "m2"])
  }

  func testAFileMissingPartsOrCarryingNewOnesStillReads() throws {
    let back = try JSONDecoder().decode(BoardMeaning.self, from: Data(#"{"rev": 3, "later": true}"#.utf8))
    XCTAssertEqual(back.rev, 3)
    XCTAssertEqual(back.texts, [])
    XCTAssertEqual(back.questions, WhiteboardQuestions())
    XCTAssertNil(back.inkBytes)
  }

  func testTheDrawingIsWrittenFirstThenItsMeaning() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    var meaning = try sample()
    meaning.inkBytes = 3
    _ = try keeping.save(Data("ink".utf8), meaning: meaning, board: "b1")
    XCTAssertEqual(disk.changes, ["write b1.drawing", "write b1.meaning.json"])
    XCTAssertEqual(try keeping.meaning("b1"), meaning)
  }

  func testADrawingThatFailsToSaveWritesNoMeaning() throws {
    let disk = TestDisk()
    disk.refuse = ".drawing"
    var keeping = keeping(disk)
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1"))
    XCTAssertNil(try keeping.meaning("b1"), "the meaning never runs ahead of the ink")
  }

  func testAMeaningThatFailsToSaveFailsTheSave() throws {
    let disk = TestDisk()
    disk.refuse = ".meaning.json"
    var keeping = keeping(disk)
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1"))
  }

  func testTheDrawingsSizeAsReadIsKnown() throws {
    var keeping = keeping()
    _ = try keeping.save(Data("ink12".utf8), board: "b1")
    XCTAssertNil(keeping.drawingBytes("b1"))
    _ = try keeping.drawing("b1") { $0 }
    XCTAssertEqual(keeping.drawingBytes("b1"), 5)
  }

  func testAnUnreadableMeaningIsSetAside() throws {
    let keeping = keeping()
    let url = try XCTUnwrap(keeping.meaningURL("b1"))
    try Data("not json".utf8).write(to: url)
    XCTAssertThrowsError(try keeping.meaning("b1"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("unreadable").path))
    XCTAssertNil(try keeping.meaning("b1"))
  }

  func testADeleteTakesTheMeaningToo() throws {
    var keeping = keeping()
    _ = try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1")
    keeping.removeFiles("b1")
    XCTAssertNil(try keeping.meaning("b1"))
  }

  // MARK: The move from UserDefaults

  private func legacy() throws -> BoardOpLedger {
    let ledger = BoardOpLedger(defaults: defaults)
    let meaning = try sample()
    ledger.save(meaning.applier, board: "b1")
    ledger.setTexts(meaning.texts, board: "b1")
    ledger.setStrokeIDs(meaning.strokeIDs, board: "b1")
    ledger.setStrokeMeta(meaning.strokeMeta, board: "b1")
    ledger.setHeaders(meaning.headers, board: "b1")
    defaults.set(try JSONEncoder().encode(meaning.questions), forKey: "whiteboard_questions_b1")
    return ledger
  }

  func testTheOldKeysMoveIntoTheFileOnceAndGo() throws {
    let ledger = try legacy()
    let keeping = keeping()
    let moved = try XCTUnwrap(keeping.migrateMeaning("b1", from: ledger)).get()
    XCTAssertEqual(moved, try sample())
    XCTAssertEqual(try keeping.meaning("b1"), try sample())
    XCTAssertNil(ledger.meaning(board: "b1"), "every old key is gone")
    XCTAssertTrue(BoardDeviceKeys.keys(of: "b1", in: defaults).isEmpty)
    XCTAssertNil(keeping.migrateMeaning("b1", from: ledger), "once")
  }

  func testABoardWithNoOldKeysHasNothingToMove() {
    XCTAssertNil(keeping().migrateMeaning("b1", from: BoardOpLedger(defaults: defaults)))
  }

  func testAFileAlreadyThereIsNeverOverwritten() throws {
    let ledger = try legacy()
    let keeping = keeping()
    var newer = BoardMeaning()
    newer.rev = 42
    try keeping.saveMeaning(newer, board: "b1")
    XCTAssertNil(keeping.migrateMeaning("b1", from: ledger))
    XCTAssertEqual(try keeping.meaning("b1")?.rev, 42)
    XCTAssertNil(ledger.meaning(board: "b1"), "the stale keys go")
  }

  func testAMoveThatFailsKeepsTheKeys() throws {
    let ledger = try legacy()
    let disk = TestDisk()
    disk.refuse = ".meaning.json"
    guard case .failure? = keeping(disk).migrateMeaning("b1", from: ledger) else { return XCTFail("should fail") }
    XCTAssertEqual(ledger.meaning(board: "b1"), try sample(), "tried again next launch")
  }

  // MARK: The open board's ledger

  func testEachChangeIsToldAndTheSaveRemembered() throws {
    let ledger = BoardMeaningLedger(board: "b1", meaning: BoardMeaning())
    var told = 0
    ledger.onChange = { told += 1 }
    XCTAssertFalse(ledger.unsaved)
    ledger.setHeaders([], board: "b1")
    XCTAssertEqual(told, 0, "no change, nothing told")
    var applier = ledger.applier(board: "b1")
    applier.changed()
    ledger.save(applier, board: "b1")
    ledger.setTexts(try sample().texts, board: "b1")
    ledger.setQuestions(try sample().questions, board: "b1")
    XCTAssertEqual(told, 3)
    XCTAssertTrue(ledger.unsaved)
    var written = ledger.meaning
    written.inkBytes = 12
    ledger.wrote(written)
    XCTAssertFalse(ledger.unsaved)
    XCTAssertEqual(ledger.meaning.inkBytes, 12)
    XCTAssertEqual(ledger.applier(board: "b1").rev, 1)
  }

  func testOnlyTheMeaningParkedOnTheApplierIsKept() {
    let ledger = BoardMeaningLedger(board: "b1", meaning: BoardMeaning())
    var told = 0
    ledger.onChange = { told += 1 }
    var applier = ledger.applier(board: "b1")
    applier.touched(["a"])
    applier.closed()
    ledger.save(applier, board: "b1")
    XCTAssertEqual(told, 0, "touches and the batch in flight live only on this run")
  }

  // MARK: A delete forgets the device's keys

  func testADeleteForgetsEveryKeyOfThatBoardOnly() {
    for key in ["whiteboard_thread_b1", "whiteboard_paper_y_b1", "whiteboard_labels_b1", "whiteboard_thread_b2"] {
      defaults.set("x", forKey: key)
    }
    defaults.set("x", forKey: "other_b1")
    XCTAssertEqual(BoardDeviceKeys.forget("b1", in: defaults), 3)
    XCTAssertNil(defaults.object(forKey: "whiteboard_thread_b1"))
    XCTAssertNotNil(defaults.object(forKey: "whiteboard_thread_b2"))
    XCTAssertNotNil(defaults.object(forKey: "other_b1"))
  }
}
