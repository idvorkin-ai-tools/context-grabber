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
    var moveFails = false
    var picturesFail = false
    var changes: [String] = []
    func exists(_ url: URL) -> Bool { disk.exists(url) }
    func read(_ url: URL) throws -> Data { try disk.read(url) }
    func write(_ data: Data, to url: URL) throws {
      changes.append("write \(url.lastPathComponent)")
      if picturesFail, url.pathExtension == "png" { throw CocoaError(.fileWriteOutOfSpace) }
      try (full ? FullDisk(over: disk) : disk as any BoardDisk).write(data, to: url)
    }
    func remove(_ url: URL) throws {
      changes.append("remove \(url.lastPathComponent)")
      try disk.remove(url)
    }
    func move(_ url: URL, to target: URL) throws {
      changes.append("move \(url.lastPathComponent)")
      if moveFails { throw CocoaError(.fileWriteNoPermission) }
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
    var keeping = keeping()
    let url = try XCTUnwrap(keeping.drawingURL("a"))
    try put("not a drawing", at: url)
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode)) { error in
      XCTAssertEqual((error as? UnreadableDrawing)?.keptAt, url.appendingPathExtension("unreadable"))
      XCTAssertNil((error as? UnreadableDrawing)?.stuck)
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "so the next save doesn't write over it")
    XCTAssertEqual(
      try String(contentsOf: url.appendingPathExtension("unreadable"), encoding: .utf8), "not a drawing",
      "kept aside")
    XCTAssertFalse(keeping.held("a"), "kept aside, the board can be drawn on afresh")
    XCTAssertFalse(try keeping.save(Data("ink: afresh".utf8), board: "a"))
  }

  // MARK: #1042: an unreadable drawing that can't be moved aside

  func testAnUnreadableDrawingThatCannotBeMovedAsideIsLeftAndNeverSavedOver() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    let url = try XCTUnwrap(keeping.drawingURL("a"))
    let aside = url.appendingPathExtension("unreadable")
    try put("not a drawing", at: url)
    try put("an older bad drawing", at: aside)
    disk.moveFails = true
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode)) { error in
      let unreadable = error as? UnreadableDrawing
      XCTAssertNotNil(unreadable, "the error says whether it was moved aside")
      XCTAssertNil(unreadable?.keptAt)
      XCTAssertNotNil(unreadable?.stuck, "and why it couldn't be")
      XCTAssertTrue(unreadable?.reason is Unreadable, "the decode's own reason is kept")
    }
    XCTAssertTrue(keeping.held("a"))
    XCTAssertThrowsError(try keeping.save(Data("ink: drawn after".utf8), board: "a")) { error in
      XCTAssertTrue(error is BoardHeld, "an edit's flush or a close never writes over it")
    }
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not a drawing", "the original is untouched")
    XCTAssertEqual(try String(contentsOf: aside, encoding: .utf8), "an older bad drawing", "and so is the older one")
    XCTAssertFalse(disk.changes.contains { $0.hasPrefix("remove") || $0.hasPrefix("write a.") }, "\(disk.changes)")
    XCTAssertFalse(try keeping.save(Data("ink".utf8), board: "b"), "another board still saves")

    // Reopened after a relaunch, with the disk still refusing: the same, and the bytes still there.
    var relaunched = BoardKeeping(dir: dir, disk: disk)
    XCTAssertThrowsError(try relaunched.drawing("a", decode: decode))
    XCTAssertThrowsError(try relaunched.save(Data("ink".utf8), board: "a"))
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not a drawing")

    // Once the move works it is set aside beside the older one, and the board saves again.
    disk.moveFails = false
    XCTAssertThrowsError(try relaunched.drawing("a", decode: decode)) { error in
      XCTAssertEqual((error as? UnreadableDrawing)?.keptAt?.lastPathComponent, "a.drawing.2.unreadable")
      XCTAssertNil((error as? UnreadableDrawing)?.stuck)
    }
    XCTAssertFalse(relaunched.held("a"))
    XCTAssertEqual(try String(contentsOf: aside, encoding: .utf8), "an older bad drawing")
    XCTAssertEqual(
      try String(
        contentsOf: url.deletingLastPathComponent().appendingPathComponent("a.drawing.2.unreadable"),
        encoding: .utf8), "not a drawing")
    XCTAssertFalse(try relaunched.save(Data("ink: fresh".utf8), board: "a"))
    XCTAssertEqual(try relaunched.drawing("a", decode: decode), "ink: fresh")
  }

  func testAHealthyDrawingAndANewBoardAreNeverHeld() throws {
    let disk = TestDisk()
    disk.moveFails = true
    var keeping = keeping(disk)
    try put("ink: an old board", at: keeping.drawingURL("old"))
    XCTAssertEqual(try keeping.drawing("old", decode: decode), "ink: an old board")
    XCTAssertNil(try keeping.drawing("new", decode: decode), "a new board has nothing to read")
    XCTAssertFalse(keeping.held("old"))
    XCTAssertFalse(keeping.held("new"))
    XCTAssertFalse(try keeping.save(Data("ink: more".utf8), board: "old"))
    XCTAssertFalse(try keeping.save(Data("ink: first".utf8), board: "new"))
  }

  func testADeletedHeldBoardIsNoLongerHeld() throws {
    let disk = TestDisk()
    disk.moveFails = true
    var keeping = keeping(disk)
    try put("not a drawing", at: keeping.drawingURL("a"))
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode))
    keeping.removeFiles("a")
    XCTAssertFalse(keeping.held("a"), "deleting it is what was asked")
  }

  func testTheSimulatorsStuckDiskReadsBadInkAndRefusesTheMove() throws {
    var keeping = BoardKeeping(dir: dir, disk: StuckUnreadableDisk(over: FileBoardDisk()))
    _ = keeping.readIndex()
    XCTAssertFalse(try keeping.save(Data("ink".utf8), board: "a"), "a new board's first save goes through")
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode)) { error in
      XCTAssertNotNil((error as? UnreadableDrawing)?.stuck)
    }
    XCTAssertEqual(try String(contentsOf: XCTUnwrap(keeping.drawingURL("a")), encoding: .utf8), "ink")
  }

  // MARK: #1043: another device's board brought down from iCloud

  /// An asset as CloudKit hands it over: a file of its own, outside the boards folder.
  private func asset(_ text: String) throws -> URL {
    let url = dir.appendingPathComponent("assets/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try put(text, at: url)
    return url
  }

  private func text(_ url: URL?) throws -> String { try String(contentsOf: XCTUnwrap(url), encoding: .utf8) }

  func testAFirstDownloadKeepsTheDrawingAndItsPicture() throws {
    let keeping = keeping()
    let taken = try keeping.takeReplica("a", drawing: asset("ink: v1"), picture: asset("png v1"), decode: decode)
    XCTAssertEqual(taken.drawing, "ink: v1")
    XCTAssertNil(taken.pictureProblem)
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v1")
    XCTAssertEqual(try text(keeping.pictureURL("a")), "png v1")
  }

  func testAFailedRefreshKeepsTheLastGoodReplicaAndARetryBringsTheNewOne() throws {
    let disk = TestDisk()
    let keeping = keeping(disk)
    _ = try keeping.takeReplica("a", drawing: asset("ink: v1"), picture: asset("png v1"), decode: decode)
    disk.full = true
    XCTAssertThrowsError(
      try keeping.takeReplica("a", drawing: asset("ink: v2"), picture: asset("png v2"), decode: decode))
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v1", "the copy failed: the old drawing still shows")
    XCTAssertEqual(try text(keeping.pictureURL("a")), "png v1", "and its picture with it")
    XCTAssertFalse(disk.changes.contains { $0.hasPrefix("remove") }, "nothing was removed first: \(disk.changes)")
    disk.full = false
    let retried = try keeping.takeReplica("a", drawing: asset("ink: v2"), picture: asset("png v2"), decode: decode)
    XCTAssertEqual(retried.drawing, "ink: v2")
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v2", "the next sync brings the right revision")
    XCTAssertEqual(try text(keeping.pictureURL("a")), "png v2")
  }

  func testAnIncomingDrawingThatCannotBeReadOrIsMissingChangesNothing() throws {
    let keeping = keeping()
    _ = try keeping.takeReplica("a", drawing: asset("ink: v1"), picture: asset("png v1"), decode: decode)
    XCTAssertThrowsError(
      try keeping.takeReplica("a", drawing: asset("garbled"), picture: asset("png v2"), decode: decode)
    ) { error in XCTAssertTrue(error is UnreadableReplica, "\(error)") }
    XCTAssertThrowsError(try keeping.takeReplica("a", drawing: nil, picture: asset("png v2"), decode: decode)) {
      error in XCTAssertTrue(error is ReplicaIncomplete, "\(error)")
    }
    let gone = dir.appendingPathComponent("assets/interrupted")
    XCTAssertThrowsError(
      try keeping.takeReplica("a", drawing: gone, picture: nil, decode: decode), "an interrupted one")
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v1")
    XCTAssertEqual(try text(keeping.pictureURL("a")), "png v1")
  }

  func testAFailedFirstDownloadLeavesNoBoardFile() throws {
    let disk = TestDisk()
    let keeping = keeping(disk)
    XCTAssertThrowsError(try keeping.takeReplica("a", drawing: asset("garbled"), picture: nil, decode: decode))
    disk.full = true
    XCTAssertThrowsError(try keeping.takeReplica("a", drawing: asset("ink"), picture: asset("png"), decode: decode))
    XCTAssertFalse(disk.exists(try XCTUnwrap(keeping.drawingURL("a"))), "it waits for the next sync")
    XCTAssertFalse(disk.exists(try XCTUnwrap(keeping.pictureURL("a"))), "no picture of a drawing that isn't here")
  }

  func testAMissingOrFailedPictureStillTakesTheDrawingAndSaysSo() throws {
    let disk = TestDisk()
    let keeping = keeping(disk)
    _ = try keeping.takeReplica("a", drawing: asset("ink: v1"), picture: asset("png v1"), decode: decode)
    let missing = try keeping.takeReplica("a", drawing: asset("ink: v2"), picture: nil, decode: decode)
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v2")
    XCTAssertTrue(missing.pictureProblem is ReplicaIncomplete, "the store draws the picture from the drawing")
    disk.picturesFail = true
    let failed = try keeping.takeReplica("a", drawing: asset("ink: v3"), picture: asset("png v3"), decode: decode)
    XCTAssertEqual(try text(keeping.drawingURL("a")), "ink: v3")
    XCTAssertNotNil(failed.pictureProblem)
  }

  func testAHeldBoardIsNotReplacedFromICloud() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    try put("not a drawing", at: keeping.drawingURL("a"))
    disk.moveFails = true
    XCTAssertThrowsError(try keeping.drawing("a", decode: decode))
    XCTAssertThrowsError(try keeping.takeReplica("a", drawing: asset("ink"), picture: nil, decode: decode)) { error in
      XCTAssertTrue(error is BoardHeld)
    }
    XCTAssertEqual(try text(keeping.drawingURL("a")), "not a drawing")
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
    var keeping = keeping()
    try put("ink", at: keeping.drawingURL("a"))
    try put("png", at: keeping.pictureURL("a"))
    keeping.removeFiles("a")
    XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(keeping.drawingURL("a")).path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(keeping.pictureURL("a")).path))
    keeping.removeFiles("a")  // Files already gone are what was asked for.
  }

  // MARK: Story 658: which boards can be drawn on, through a relaunch

  func testABoardKeepsWhatItWasMadeOnThroughARelaunch() throws {
    let keeping = keeping()
    var index = BoardIndex()
    index.add(id: "old", at: aDate, device: "ipad", deviceName: "iPad")
    index.add(id: "paper", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    try keeping.writeIndex(index)
    let relaunched = BoardKeeping(dir: dir, disk: TestDisk()).readIndex()
    XCTAssertNil(relaunched.unreadable)
    XCTAssertEqual(relaunched.index.board("old").map { BoardIndex.drawable($0, on: "ipad") }, false)
    XCTAssertEqual(relaunched.index.board("paper").map { BoardIndex.drawable($0, on: "ipad") }, true)
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
}
