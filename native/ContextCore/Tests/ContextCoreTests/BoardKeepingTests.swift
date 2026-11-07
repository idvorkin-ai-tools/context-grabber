import Foundation
import XCTest

@testable import ContextCore

/// The whiteboard store's keeping rules on a real temporary folder, through a disk that can be made full and that
/// records what it was asked to change. The decode is handed in, so no PencilKit: the bytes are the drawing.
final class BoardKeepingTests: XCTestCase {
  private var dir: URL!
  private let aDate = Date(timeIntervalSince1970: 1_800_000_000)

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("board-keeping-\(UUID().uuidString)")
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: dir)
  }

  /// A real disk that fills on request and notes every write, move and removal.
  private final class TestDisk: BoardDisk {
    let disk = FileBoardDisk()
    var full = false
    var changes: [String] = []
    func exists(_ url: URL) -> Bool { disk.exists(url) }
    func read(_ url: URL) throws -> Data { try disk.read(url) }
    func write(_ data: Data, to url: URL) throws {
      changes.append("write \(url.lastPathComponent)")
      try (full ? FullDisk(over: disk) : disk as any BoardDisk).write(data, to: url)
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

  private struct Unreadable: Error {}
  private func decode(_ data: Data) throws -> String {
    guard let text = String(data: data, encoding: .utf8), text.hasPrefix("ink") else { throw Unreadable() }
    return text
  }

  /// A keeping whose list has been read once, as the store's is on launch: the boards folder exists.
  private func keeping(_ disk: TestDisk = TestDisk()) -> BoardKeeping {
    let keeping = BoardKeeping(dir: dir, disk: disk)
    _ = keeping.readIndex()
    return keeping
  }

  private func put(_ text: String, at url: URL?) throws {
    try Data(text.utf8).write(to: XCTUnwrap(url))
  }

  // MARK: Stories 347, 348: a board's drawing on disk

  func testASavedDrawingIsReadBackAndABoardWithNoneReadsAsNone() throws {
    var keeping = keeping()
    XCTAssertNil(try keeping.drawing("a", decode: decode), "a new board has no drawing yet")
    XCTAssertFalse(try keeping.save(Data("ink: one stroke".utf8), board: "a"))
    XCTAssertEqual(try keeping.drawing("a", decode: decode), "ink: one stroke")
    XCTAssertEqual(keeping.drawingURL("a")?.lastPathComponent, "a.drawing")
    XCTAssertEqual(keeping.pictureURL("a")?.lastPathComponent, "a.png")
  }

  func testAnUnreadableDrawingIsSetAsideAndTheErrorGoesUp() throws {
    let keeping = keeping()
    let url = try XCTUnwrap(keeping.drawingURL("a"))
    try put("not a drawing", at: url)
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode))
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "so the next save doesn't write over it")
    XCTAssertEqual(
      try String(contentsOf: url.appendingPathExtension("unreadable"), encoding: .utf8), "not a drawing",
      "kept aside")
  }

  func testABuildWithNowhereToKeepBoardsSavesNothing() {
    var keeping = BoardKeeping(dir: nil, disk: TestDisk())
    XCTAssertNil(keeping.drawingURL("a"))
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), board: "a"))
    XCTAssertNil(try keeping.drawing("a", decode: decode))
    XCTAssertEqual(keeping.readIndex().index, BoardIndex())
    XCTAssertNoThrow(try keeping.writeIndex(BoardIndex()))
  }

  // MARK: Stories 599, 612: a failed save

  func testAFullDiskFailsTheSaveAsAFullDiskWouldAndKeepsTheOldDrawing() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    XCTAssertFalse(try keeping.save(Data("ink: before".utf8), board: "a"))
    disk.full = true
    XCTAssertThrowsError(try keeping.save(Data("ink: after".utf8), board: "a")) { error in
      XCTAssertEqual((error as? CocoaError)?.code, .fileWriteOutOfSpace)
    }
    XCTAssertEqual(try keeping.drawing("a", decode: decode), "ink: before", "the last good save is still there")
    XCTAssertNoThrow(try keeping.writeIndex(BoardIndex()), "only drawings fail: the list still saves")
  }

  func testABoardThatClosedUnsavedStaysSoUntilThatBoardSaves() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    disk.full = true
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), board: "a"))
    keeping.closedUnsaved("a")
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), board: "a"))
    XCTAssertEqual(keeping.unsavedBoard, "a", "a save that fails again leaves the list's problem up")
    disk.full = false
    XCTAssertFalse(try keeping.save(Data("ink".utf8), board: "b"), "another board's save says nothing of this one")
    XCTAssertEqual(keeping.unsavedBoard, "a")
    XCTAssertTrue(try keeping.save(Data("ink".utf8), board: "a"), "its own save takes the list's problem away")
    XCTAssertNil(keeping.unsavedBoard)
    XCTAssertFalse(try keeping.save(Data("ink".utf8), board: "a"), "and only once")
  }

  // MARK: Stories 344, 604: a new board closed without a stroke

  func testANewBoardOfThisDeviceClosedWithoutAStrokeIsDropped() {
    var index = BoardIndex()
    let fresh = index.add(id: "a", at: aDate, device: "ipad", deviceName: "iPad")
    let onPaper = index.add(id: "p", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    XCTAssertTrue(BoardKeeping.dropsOnClose(fresh, empty: true, device: "ipad"))
    XCTAssertTrue(BoardKeeping.dropsOnClose(onPaper, empty: true, device: "ipad"), "on paper too")
    XCTAssertFalse(BoardKeeping.dropsOnClose(fresh, empty: false, device: "ipad"), "a stroke keeps it")
  }

  func testABoardThatWasEverChangedOrIsAnotherDevicesStays() {
    var index = BoardIndex()
    index.add(id: "drawn", at: aDate, device: "ipad", deviceName: "iPad")
    index.drew("drawn", strokes: 0, at: Int64(aDate.timeIntervalSince1970 * 1000) + 5)
    index.add(id: "named", at: aDate, device: "ipad", deviceName: "iPad")
    index.rename("named", to: "Plans", at: Int64(aDate.timeIntervalSince1970 * 1000) + 5)
    let other = index.add(id: "other", at: aDate, device: "iphone", deviceName: "iPhone")
    XCTAssertFalse(BoardKeeping.dropsOnClose(index.board("drawn"), empty: true, device: "ipad"), "drawn, then cleared")
    XCTAssertFalse(BoardKeeping.dropsOnClose(index.board("named"), empty: true, device: "ipad"), "renamed")
    XCTAssertFalse(BoardKeeping.dropsOnClose(other, empty: true, device: "ipad"), "another device's board")
    XCTAssertFalse(BoardKeeping.dropsOnClose(nil, empty: true, device: "ipad"), "a board already gone")
  }

  func testADroppedBoardsFilesGo() throws {
    let keeping = keeping()
    try put("ink", at: keeping.drawingURL("a"))
    try put("png", at: keeping.pictureURL("a"))
    keeping.removeFiles("a")
    XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(keeping.drawingURL("a")).path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(keeping.pictureURL("a")).path))
    keeping.removeFiles("a")  // Files already gone are what was asked for.
  }

  // MARK: Stories 590, 595, 602, 607, 651: the switch

  func testNewBoardsAreOnPaperUntilTheSwitchIsTurnedOff() {
    XCTAssertTrue(BoardKeeping.newBoardsOnPaper(stored: nil), "on until it's turned off")
    XCTAssertFalse(BoardKeeping.newBoardsOnPaper(stored: false))
    XCTAssertTrue(BoardKeeping.newBoardsOnPaper(stored: true), "turned back on")
  }

  func testTheSimulatorsHookSetsOrForgetsTheSwitch() {
    XCTAssertEqual(BoardKeeping.switchHook("on"), .set(true))
    XCTAssertEqual(BoardKeeping.switchHook("off"), .set(false))
    XCTAssertEqual(BoardKeeping.switchHook("untouched"), .forget)
    XCTAssertNil(BoardKeeping.switchHook(nil))
  }

  /// The UI case `testTheSwitchMovesNoBoard`, without its four launches: a board keeps what it was made as through a
  /// relaunch, whichever way the switch goes after.
  func testTheSwitchMovesNoBoardThroughARelaunch() throws {
    let keeping = keeping()
    var index = BoardIndex()
    index.add(
      id: "old", at: aDate, device: "ipad", deviceName: "iPad", onPages: BoardKeeping.newBoardsOnPaper(stored: false))
    index.add(
      id: "paper", at: aDate, device: "ipad", deviceName: "iPad", onPages: BoardKeeping.newBoardsOnPaper(stored: true))
    try keeping.writeIndex(index)
    let relaunched = BoardKeeping(dir: dir, disk: TestDisk()).readIndex()
    XCTAssertNil(relaunched.unreadable)
    XCTAssertEqual(relaunched.index.board("old").map { BoardIndex.opensOnPaper($0, on: "ipad") }, false)
    XCTAssertEqual(relaunched.index.board("paper").map { BoardIndex.opensOnPaper($0, on: "ipad") }, true)
  }

  // MARK: The list

  func testTheListIsReadBackAsItWasLeft() throws {
    let keeping = BoardKeeping(dir: dir, disk: TestDisk())
    let first = keeping.readIndex()
    XCTAssertEqual(first.index, BoardIndex(), "no list yet is an empty one")
    XCTAssertNil(first.unreadable)
    XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("boards").path))
    var index = BoardIndex()
    index.add(id: "a", at: aDate, device: "ipad", deviceName: "iPad")
    try keeping.writeIndex(index)
    XCTAssertEqual(keeping.readIndex().index, index)
  }

  func testAListThatCannotBeReadIsSetAsideNeverSavedOver() throws {
    let keeping = keeping()
    let url = dir.appendingPathComponent("index.json")
    try put("{ not a list", at: url)
    let read = keeping.readIndex()
    XCTAssertNotNil(read.unreadable, "the list's problem says why")
    XCTAssertEqual(read.index, BoardIndex())
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    XCTAssertEqual(
      try String(contentsOf: url.appendingPathExtension("unreadable"), encoding: .utf8), "{ not a list")
  }

  // MARK: Stories 435–439, 524–534, 601: the trial on paper's copy

  func testTryOnPaperIsOfferedOnThisDevicesBoardsOnly() {
    var index = BoardIndex()
    let old = index.add(id: "old", at: aDate, device: "ipad", deviceName: "iPad")
    let paper = index.add(id: "paper", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    let other = index.add(id: "other", at: aDate, device: "iphone", deviceName: "iPhone")
    XCTAssertTrue(BoardKeeping.offersTrial(old, on: "ipad"))
    XCTAssertTrue(BoardKeeping.offersTrial(paper, on: "ipad"), "story 601: a board on paper still offers it")
    XCTAssertFalse(BoardKeeping.offersTrial(other, on: "ipad"), "only this device's boards")
  }

  func testTheTrialReadsTheBoardsInkAndChangesNothingOnDisk() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    _ = try keeping.save(Data("ink: one stroke".utf8), board: "a")
    disk.changes = []
    XCTAssertEqual(try keeping.trialInk("a", decode: decode), "ink: one stroke")
    XCTAssertNil(try keeping.trialInk("none", decode: decode), "a board with no ink yet: an empty copy")
    XCTAssertEqual(disk.changes, [], "nothing written, moved or removed")
    XCTAssertEqual(try keeping.drawing("a", decode: decode), "ink: one stroke", "the real board as it was")
  }

  func testAnUnreadableBoardFailsTheTrialAndStaysWhereItIs() throws {
    let disk = TestDisk()
    let keeping = keeping(disk)
    let url = try XCTUnwrap(keeping.drawingURL("a"))
    try put("not a drawing", at: url)
    XCTAssertThrowsError(try keeping.trialInk("a", decode: decode))
    XCTAssertEqual(disk.changes, [])
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not a drawing", "the file is untouched")
  }
}
