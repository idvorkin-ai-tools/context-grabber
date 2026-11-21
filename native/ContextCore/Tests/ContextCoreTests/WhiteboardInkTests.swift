import XCTest

@testable import ContextCore

#if canImport(PencilKit)
  import PencilKit

  /// #1083 (story 1063): a stroke's ink is read without the Swift getter that trapped on the iPad.
  final class WhiteboardInkTests: XCTestCase {
    override func tearDown() {
      WhiteboardInk.onUnknown = nil
      WhiteboardInk.forgetReported()
      super.tearDown()
    }

    /// The safe read must say what the Swift getter says for every ink it knows, or every marker would go to Larry as
    /// something else.
    func testEveryKnownInkReadsAsSwiftNamesIt() {
      var told: [String?] = []
      WhiteboardInk.onUnknown = { raw, _, _ in told.append(raw) }
      var all: [PKInk.InkType] = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon]
      if #available(iOS 26, macOS 26, *) { all.append(.reed) }
      for kind in all {
        let ink = PKDrawing(strokes: [stroke(PKInk(kind, color: .red))]).strokes[0].ink
        XCTAssertEqual(WhiteboardInk.rawType(ink), kind.rawValue)
        XCTAssertEqual(WhiteboardInk.name(ink, at: "test"), kind.rawValue)
        XCTAssertEqual(WhiteboardInk.withAlpha(ink, 0, at: "test").inkType, kind)
      }
      XCTAssertEqual(told, [], "a known ink is never reported")
    }

    /// The iPad's crash: an ink whose kind PencilKit's Swift enum has no case for. Its own name comes back, it is
    /// reported once, and hiding it keeps its colour as the pen.
    func testAnInkOfAnUnknownKindReadsItsOwnNameAndIsReportedOnce() throws {
      let ink = try unknownInk("com.apple.ink.somethingnew")
      var told: [(String?, String, Int)] = []
      WhiteboardInk.onUnknown = { told.append(($0, $1, $2)) }
      XCTAssertEqual(WhiteboardInk.name(ink, at: "strokes", points: 12), "com.apple.ink.somethingnew")
      XCTAssertEqual(WhiteboardInk.name(ink, at: "strokes", points: 12), "com.apple.ink.somethingnew")
      XCTAssertEqual(told.map(\.0), ["com.apple.ink.somethingnew"], "reported once a launch")
      XCTAssertEqual(told.first?.1, "strokes")
      XCTAssertEqual(told.first?.2, 12)
      XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.somethingnew"), "somethingnew")
      let hidden = WhiteboardInk.withAlpha(ink, 0, at: "fold")
      XCTAssertEqual(hidden.inkType, .pen)
      XCTAssertEqual(hidden.color.cgColor.alpha, 0)
    }

    private func stroke(_ ink: PKInk) -> PKStroke {
      let point = PKStrokePoint(
        location: .zero, timeOffset: 0, size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: 0
      )
      return PKStroke(ink: ink, path: PKStrokePath(controlPoints: [point, point], creationDate: Date()))
    }

    /// An ink PencilKit's initialisers won't make (they turn an unknown kind into the pen): its stored kind set behind
    /// its back, as only a test may, then carried through a drawing as the board's strokes are.
    private func unknownInk(_ kind: String) throws -> PKInk {
      let ref = PKInk(.pen, color: .red) as PKInkReference
      ref.setValue(kind, forKey: "identifier")
      let ink = PKDrawing(strokes: [stroke(ref as PKInk)]).strokes[0].ink
      guard WhiteboardInk.rawType(ink) == kind else { throw XCTSkip("this PencilKit keeps its kind elsewhere") }
      return ink
    }
  }
#endif
