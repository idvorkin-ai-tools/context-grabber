import XCTest

@testable import ContextCore

#if canImport(PencilKit)
  import PencilKit
  #if canImport(UIKit)
    import UIKit
    private typealias UIOrNSColor = UIColor
  #else
    import AppKit
    private typealias UIOrNSColor = NSColor
  #endif

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

    /// Bead context-grabber-3b02: a drawing with an ink this PencilKit can't name is written but refused when read back
    /// ("from a future version"), so a board saved with one wouldn't open. Saved through `savable`, the stroke comes
    /// back as the pen in its own colour and strength, every point where it was.
    func testADrawingWithAnInkThatDoesNotReadBackIsSavedAsThePen() throws {
      let hiddenRed = UIOrNSColor.red.withAlphaComponent(0.4)
      let ref = PKInk(.pen, color: hiddenRed) as PKInkReference
      ref.setValue("com.apple.ink.somethingnew", forKey: "identifier")
      let odd = stroke(ref as PKInk, points: 5)
      guard WhiteboardInk.rawType(odd.ink) == "com.apple.ink.somethingnew" else {
        throw XCTSkip("this PencilKit keeps its kind elsewhere")
      }
      let drawing = PKDrawing(strokes: [stroke(PKInk(.marker, color: .blue)), odd])
      XCTAssertThrowsError(try PKDrawing(data: drawing.dataRepresentation()), "as it is, it doesn't read back")

      let (saved, check) = WhiteboardInk.savable(drawing)
      let read = try PKDrawing(data: saved.dataRepresentation())
      XCTAssertEqual(read.strokes.count, 2)
      XCTAssertEqual(read.strokes[0].ink.inkType, .marker, "a known ink is left as it is")
      XCTAssertEqual(WhiteboardInk.rawType(read.strokes[1].ink), PKInk.InkType.pen.rawValue)
      XCTAssertEqual(read.strokes[1].ink.color.cgColor.alpha, 0.4, accuracy: 0.01, "its strength kept")
      XCTAssertEqual(read.strokes[1].ink.color.cgColor.components?.first ?? 0, 1, accuracy: 0.01, "its colour kept")
      XCTAssertEqual(read.strokes[1].path.count, 5, "every point kept")
      XCTAssertEqual(read.strokes[1].renderBounds, odd.renderBounds, "where it was")
      let kind = ["com.apple.ink.somethingnew"]
      XCTAssertEqual(check, WhiteboardInk.SaveCheck(kinds: kind, unreadable: kind, asPen: 1))
    }

    /// A drawing of inks this PencilKit knows is saved exactly as it is, with nothing to say.
    func testADrawingOfKnownInksIsSavedAsItIs() throws {
      let drawing = PKDrawing(strokes: [stroke(PKInk(.pen, color: .red)), stroke(PKInk(.pencil, color: .green))])
      let (saved, check) = WhiteboardInk.savable(drawing)
      XCTAssertNil(check)
      XCTAssertEqual(saved, drawing)
    }

    private func stroke(_ ink: PKInk, points count: Int) -> PKStroke {
      let points = (0..<count).map { index in
        PKStrokePoint(
          location: CGPoint(x: 10 + 5 * index, y: 20), timeOffset: 0, size: CGSize(width: 2, height: 2), opacity: 1,
          force: 1, azimuth: 0, altitude: 0)
      }
      return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()))
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
