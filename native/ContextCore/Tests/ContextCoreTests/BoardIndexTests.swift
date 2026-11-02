import XCTest

@testable import ContextCore

final class BoardIndexTests: XCTestCase {
  let utc = TimeZone(identifier: "UTC") ?? .current
  let nov1 = Date(timeIntervalSince1970: 1_793_534_400)

  func testNewBoardsAreNamedForTheDayAndNumberedAfterTheFirst() {
    var index = BoardIndex()
    XCTAssertEqual(
      index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1")
    XCTAssertEqual(
      index.add(id: "b", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1 (2)")
    XCTAssertEqual(
      index.add(id: "c", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1 (3)")
  }

  func testTheListIsNewestChangeFirst() {
    var index = BoardIndex()
    index.add(id: "old", at: nov1, device: "ipad", deviceName: "iPad")
    index.add(id: "new", at: nov1.addingTimeInterval(60), device: "ipad", deviceName: "iPad")
    index.drew("old", strokes: 3, at: Int64(nov1.timeIntervalSince1970 * 1000) + 120_000)
    XCTAssertEqual(index.sorted.map(\.id), ["old", "new"], "drawing on a board brings it to the top")
  }

  func testOnlyTheDrawingDeviceEdits() {
    var index = BoardIndex()
    let board = index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    XCTAssertTrue(BoardIndex.editable(board, on: "ipad"))
    XCTAssertFalse(BoardIndex.editable(board, on: "phone"))
  }

  func testOwnBoardsWaitForUploadUntilICloudTakesThatVersion() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.drew("a", strokes: 2, at: 2_000_000_000_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad").map(\.id), ["a"])
    index.uploaded("a", at: 2_000_000_000_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad"), [])
    index.drew("a", strokes: 3, at: 2_000_000_001_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad").map(\.id), ["a"], "a later stroke goes up again")
    XCTAssertEqual(index.pendingUploads(device: "phone"), [], "never another device's board")
  }

  func testThePhoneTakesTheIPadsBoardsAndTheirChanges() {
    var phone = BoardIndex()
    let ipadBoard = BoardEntry(
      id: "a", title: "Board, Nov 1", created: 1, updated: 10, strokes: 4, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(phone.merge(cloud: [ipadBoard], device: "phone").fetch, ["a"])
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.merge(cloud: [ipadBoard], device: "phone").fetch, [], "nothing new, nothing fetched")
    var drawnOn = ipadBoard
    drawnOn.updated = 20
    drawnOn.strokes = 6
    XCTAssertEqual(phone.merge(cloud: [drawnOn], device: "phone").fetch, ["a"])
    XCTAssertEqual(phone.board("a")?.strokes, 6)
  }

  func testABoardItsDeviceDeletedLeavesTheOtherDevices() {
    var phone = BoardIndex()
    let ipadBoard = BoardEntry(
      id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [ipadBoard], device: "phone")
    XCTAssertEqual(phone.merge(cloud: [], device: "phone").dropped, ["a"])
    XCTAssertNil(phone.board("a"))
  }

  func testThisDevicesOwnBoardsAreNeverTakenFromICloud() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 5, at: 3_000_000_000_000)
    let stale = BoardEntry(
      id: "a", title: "A", created: 1, updated: 4_000_000_000_000, strokes: 1, device: "ipad", deviceName: "iPad")
    let result = ipad.merge(cloud: [stale], device: "ipad")
    XCTAssertEqual(result.fetch, [])
    XCTAssertEqual(ipad.board("a")?.strokes, 5)
    XCTAssertEqual(ipad.merge(cloud: [], device: "ipad").dropped, [], "an own board not yet uploaded stays")
  }

  func testADeleteWaitsForICloudAndIsNotUndoneByIt() {
    var ipad = BoardIndex()
    ipad.add(id: "never-up", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.remove("never-up")
    XCTAssertEqual(ipad.deleted, [], "a board iCloud never had needs no delete there")
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.uploaded("a", at: 1)
    ipad.remove("a")
    XCTAssertEqual(ipad.deleted, ["a"])
    let cloudCopy = BoardEntry(
      id: "a", title: "A", created: 1, updated: 1, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = ipad.merge(cloud: [cloudCopy], device: "ipad")
    XCTAssertNil(ipad.board("a"))
    ipad.deletedInCloud("a")
    XCTAssertEqual(ipad.deleted, [])
  }

  func testABoardDeletedWhileItsFirstUploadRunsStaysDeleted() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 3, at: 3_000_000_000_000)
    ipad.remove("a")
    XCTAssertEqual(ipad.deleted, ["a"], "the upload in flight may land, so iCloud is told to delete it")
    ipad.uploaded("a", at: 3_000_000_000_000)
    let landed = BoardEntry(
      id: "a", title: "A", created: 1, updated: 3_000_000_000_000, strokes: 3, device: "ipad", deviceName: "iPad")
    _ = ipad.merge(cloud: [landed], device: "ipad")
    XCTAssertNil(ipad.board("a"))
  }

  func testRenameIsTrimmedAndCountsAsAChange() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.rename("a", to: "  Energy week  ", at: 5_000_000_000_000)
    XCTAssertEqual(index.board("a")?.title, "Energy week")
    XCTAssertEqual(index.board("a")?.updated, 5_000_000_000_000)
    index.rename("a", to: "   ", at: 6_000_000_000_000)
    XCTAssertEqual(index.board("a")?.title, "Energy week", "a blank name is ignored")
  }

  func testTheIndexRoundTripsThroughJSON() throws {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    let back = try JSONDecoder().decode(BoardIndex.self, from: JSONEncoder().encode(index))
    XCTAssertEqual(back, index)
  }

  func testAFailedFetchIsAskedForAgainUntilItLands() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, ["a"])
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, ["a"], "the download failed: asked again")
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, [])
  }

  func testOwnBoardsTheListLostComeBackFromICloud() {
    var ipad = BoardIndex()
    let lost = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 3, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(ipad.merge(cloud: [lost], device: "ipad").fetch, ["a"])
    XCTAssertEqual(ipad.board("a")?.uploaded, 10, "iCloud already has it, so nothing goes back up")
    XCTAssertEqual(ipad.pendingUploads(device: "ipad"), [])
    ipad.fetched("a", at: 10)
    XCTAssertEqual(ipad.merge(cloud: [lost], device: "ipad").fetch, [])
    XCTAssertTrue(BoardIndex.editable(ipad.board("a") ?? lost, on: "ipad"), "drawn here again")
  }

  func testABoardICloudHoldsButCannotReadIsNotDropped() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [board], device: "phone")
    let result = phone.merge(cloud: [], device: "phone", unread: ["a"])
    XCTAssertEqual(result.dropped, [])
    XCTAssertEqual(result.fetch, [])
    XCTAssertNotNil(phone.board("a"))
  }

  func testABoardIsCurrentOnlyOnceItsLatestDrawingArrived() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [board], device: "phone")
    XCTAssertEqual(phone.board("a")?.current, false, "listed, but its download hasn't landed")
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.board("a")?.current, true)
    var drawnOn = board
    drawnOn.updated = 20
    _ = phone.merge(cloud: [drawnOn], device: "phone")
    XCTAssertEqual(phone.board("a")?.current, false, "iCloud has newer ink than the copy here")
    var ipad = BoardIndex()
    ipad.add(id: "b", at: nov1, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(ipad.board("b")?.current, true, "a board drawn here is always current")
    ipad.drew("b", strokes: 2, at: 2_000_000_000_000)
    XCTAssertEqual(ipad.board("b")?.current, true)
  }

  func testOwnBoardsDrawnHereNeverNeedAFetch() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 2, at: 2_000_000_000_000)
    ipad.rename("a", to: "B", at: 2_000_000_001_000)
    ipad.uploaded("a", at: 2_000_000_001_000)
    let cloudCopy = ipad.board("a")!
    XCTAssertEqual(ipad.merge(cloud: [cloudCopy], device: "ipad").fetch, [])
  }
}
