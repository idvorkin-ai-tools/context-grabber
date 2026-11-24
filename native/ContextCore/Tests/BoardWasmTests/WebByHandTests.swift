import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Story 1295 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 20): `bw_room_by_hand` and
/// `bw_fold_picture` answer what the app's own room by hand and Larry's picture of a folded board decide, on the
/// Cockpit's recorded boards and on seeded ones.
final class WebByHandTests: XCTestCase {
  private func boards() throws -> [WebBoard] {
    try WebBoard.recorded() + (UInt64(1)...30).map { try WebBoard.seeded($0) }
  }

  func testRoomByHandOpensAndClosesAsTheAppsDoes() throws {
    var (opened, closed, clamped) = (0, 0, 0)
    for (i, board) in try boards().enumerated() {
      var rng = Seeded(UInt64(i + 11))
      let ink = BoardOps.shownBoxes(strokes: board.strokes, texts: board.texts, groups: board.groups)
      let bottom = ink.reduce(CGFloat(0)) { max($0, $1.maxY) }
      for _ in 0..<40 {
        let y = CGFloat(rng.int(0...Int(bottom) + 80))
        let dy = CGFloat(rng.int(-200...200))
        let got = WebByHand.room(ink, y: y, dy: dy)
        let cut = BoardRoom.cut(ink, at: y)
        let want = BoardRoom.byHand(ink, at: y, dy: dy)
        let push: Any = want.map { ["cut": Double($0.cut), "dy": Double($0.dy)] } ?? NSNull()
        let expected: [String: Any] = [
          "push": push, "cut": Double(cut), "closable": Double(BoardRoom.closable(ink, at: cut)),
        ]
        XCTAssert(sameJSON(got, expected), "\(board.name) y \(y) dy \(dy): \(got) vs \(expected)")
        guard let want else { continue }
        if want.dy > 0 { opened += 1 } else { closed += 1 }
        // Closing never takes more than the blank paper there: the rigid push.
        if dy < 0, -want.dy < (-dy / BoardRoom.line).rounded() * BoardRoom.line { clamped += 1 }
        XCTAssertLessThanOrEqual(-want.dy, BoardRoom.closable(ink, at: cut), board.name)
      }
    }
    XCTAssertGreaterThan(opened, 100)
    XCTAssertGreaterThan(closed, 20)
    XCTAssertGreaterThan(clamped, 10)
  }

  func testTheFoldPictureIsTheAppsPictureByName() throws {
    var pictures = 0
    for var board in try boards() {
      let unfolded = try board.web()
      XCTAssert(sameJSON(WebByHand.foldPicture(unfolded.outline), ["picture": NSNull()]), board.name)
      guard let header = board.headers.first, board.fold(header.id) else { continue }
      let app = try XCTUnwrap(board.app.foldPicture(), board.name)
      let web = try board.web()
      let got = try XCTUnwrap(WebByHand.foldPicture(web.outline)["picture"] as? [String: Any], board.name)
      let name = { (place: Int) in WebBoard.webName(board.strokes[place].ids[0]) }
      var offsets: [String: Any] = [:]
      for (place, offset) in app.offsets where offset.dx != 0 || offset.dy != 0 {
        offsets[name(place)] = [Double(offset.dx), Double(offset.dy)]
      }
      XCTAssert(
        sameJSONToAMillionth(got["offsets"] as Any, offsets), "\(board.name): \(got["offsets"] ?? "") vs \(offsets)")
      XCTAssertEqual(got["shown"] as? [String], app.shown.map(name).sorted(), board.name)
      XCTAssert(
        sameJSONToAMillionth(
          got["bands"] as Any,
          app.bands.map { ["header": $0.header, "top": Double($0.top), "bottom": Double($0.bottom)] }),
        board.name)
      XCTAssert(
        sameJSONToAMillionth(
          got["map"] as Any, app.map.steps.map { ["header": $0.header, "y": Double($0.top), "h": Double($0.slide)] }),
        board.name)
      XCTAssert(
        sameJSONToAMillionth(
          got["folded_marks"] as Any, app.foldedMarks.map { ["header": $0.header, "y": Double($0.y)] }),
        board.name)
      XCTAssertEqual(
        (got["open_labels"] as? [[String: Any]])?.map { $0["header"] as? String }, app.openLabels.map(\.header))
      pictures += 1
    }
    XCTAssertGreaterThan(pictures, 5)
  }
}
