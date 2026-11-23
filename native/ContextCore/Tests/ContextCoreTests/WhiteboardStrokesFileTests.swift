import Foundation
import XCTest

@testable import ContextCore

/// The strokes file a board's picture waits beside in the outbox (stories 424, 1176), read from files written by hand
/// in `Fixtures/strokes-file`, never from the paired writer, so a change to the format shows here
/// (bead context-grabber-fffb).
final class WhiteboardStrokesFileTests: XCTestCase {
  private static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Fixtures/strokes-file")

  private func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: Self.dir.appendingPathComponent(name))
  }

  private func json(_ data: Data) throws -> NSObject {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSObject)
  }

  // A board with nothing folded: the strokes alone, as a list, as before story 1176.
  func testAListIsTheStrokesWithNoFolds() throws {
    let file = try XCTUnwrap(WhiteboardStrokes.file(try fixture("list.json")))
    XCTAssertEqual(file.strokes.map { $0["id"] as? String }, ["s1", "s2"])
    XCTAssertEqual(file.strokes[1]["hidden"] as? Bool, true)
    XCTAssertEqual(file.strokes[0]["points"] as? [[Double]], [[10, 20], [14.5, 22], [30, 25.5]])
    XCTAssertTrue(file.folds.isEmpty)
  }

  // A board with folded sections: the strokes and the folds beside them, each as written.
  func testTheWrappedFormCarriesItsFolds() throws {
    let file = try XCTUnwrap(WhiteboardStrokes.file(try fixture("wrapped.json")))
    XCTAssertEqual(file.strokes.map { $0["id"] as? String }, ["s1", "s2"])
    XCTAssertEqual(file.folds.map { $0["header"] as? String }, ["h1", "h2"])
    XCTAssertEqual(file.folds[1]["y"] as? Double, 300)
    XCTAssertEqual(file.folds[1]["h"] as? Double, 40.5)
  }

  // An empty folds list is still the wrapped form, so it reads as no folds.
  func testTheWrappedFormMayHaveNoFoldsListed() throws {
    let file = try XCTUnwrap(WhiteboardStrokes.file(try fixture("wrapped-empty-folds.json")))
    XCTAssertEqual(file.strokes.count, 1)
    XCTAssertTrue(file.folds.isEmpty)
  }

  // The wrapped form names both lists. One without folds, with null folds, or with folds that aren't a list was never
  // written; reading it as "nothing folded" would send a folded picture's strokes as if unfolded, so it's unreadable.
  func testAWrappedFileWithoutItsFoldsListIsUnreadable() throws {
    for name in [
      "wrapped-missing-folds.json", "wrapped-null-folds.json", "wrapped-folds-not-a-list.json",
      "wrapped-missing-strokes.json",
    ] {
      XCTAssertNil(WhiteboardStrokes.file(try fixture(name)), name)
    }
    XCTAssertNil(WhiteboardStrokes.file(Data("not json".utf8)))
    XCTAssertNil(WhiteboardStrokes.file(Data("{}".utf8)))
  }

  // The writer makes exactly the shapes above: a list with nothing folded, else both lists. Compared as JSON, since
  // key order isn't part of the format.
  func testTheWriterMakesTheShapesTheFixturesHold() throws {
    let list = try json(try fixture("list.json"))
    let strokes = try XCTUnwrap(list as? [[String: Any]])
    XCTAssertEqual(try json(try WhiteboardStrokes.file(strokes: strokes, folds: [])), list)

    let wrapped = try json(try fixture("wrapped.json"))
    let parts = try XCTUnwrap(wrapped as? [String: Any])
    let written = try WhiteboardStrokes.file(
      strokes: try XCTUnwrap(parts["strokes"] as? [[String: Any]]),
      folds: try XCTUnwrap(parts["folds"] as? [[String: Any]]))
    XCTAssertEqual(try json(written), wrapped)
  }
}
