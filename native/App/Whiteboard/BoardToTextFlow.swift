//  Handwriting to text on paper (spec 2026-11-16-whiteboard-to-text-and-snap-design.md, stories 920–922; the web board's
//  "To text"): To text beside the lasso's ink; a picture of just that ink to the Cockpit; the words it reads take the
//  ink's place as a kept text, one undo. What the request and answer mean, and where the words go, is `BoardToText` in
//  ContextCore.

import BugKit
import ContextCore
import PaperKit
import PencilKit
import SwiftUI

/// Where To text shows, in the board view's points (nil with no ink selected), and whether a picture is out.
@MainActor
final class BoardToTextState: ObservableObject {
  @Published var frame: CGRect?
  @Published var reading = false
}

extension PaperBoardController {
  /// The problem slot's context for a To text that failed.
  static let toTextContext = "WhiteboardView.toText"

  /// The lasso's strokes, by element key and remade as `inkDrawing` remakes them; nil when it holds no ink.
  private var selectedInk: (keys: Set<String>, strokes: [PKStroke])? {
    guard let markup = paper.markup, !paper.selection.isEmpty else { return nil }
    let picked = markup.subelements.strokes.filter { paper.selection.contains($0.elementID) }
    guard !picked.isEmpty else { return nil }
    return (
      Set(picked.map { Self.key($0.elementID) }),
      picked.map {
        PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform, mask: $0.mask, randomSeed: $0.randomSeed)
      }
    )
  }

  /// To text beside the selected ink, where it is on screen now; away with none, on a look-only board, or beside a paste
  /// (which has its own Delete there).
  func showToText() {
    var frame: CGRect?
    if model.editable, pastedFrame == nil, let picked = selectedInk {
      let box = PKDrawing(strokes: picked.strokes).bounds
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    if frame != toText.frame { toText.frame = frame }
  }

  /// Story 920: the selected ink's picture to the Cockpit, and its words in the ink's place when they come.
  func toTextTapped() {
    guard !toText.reading, let picked = selectedInk else { return }
    let ink = PKDrawing(strokes: picked.strokes)
    let box = ink.bounds
    let crop = BoardToText.crop(ink: box)
    let board = model.board.id
    let cockpit = model.cockpitURL
    guard let png = Self.picture(of: ink, crop: crop) else {
      log.event("error", ["where": "whiteboard_to_text", "message": "no picture", "board": board])
      model.show(problem: .grabber("To text couldn't draw the ink's picture", context: Self.toTextContext))
      return
    }
    toText.reading = true
    let color = picked.strokes.first?.ink.color ?? .label
    log.event(
      "whiteboard",
      [
        "action": "to_text", "board": board, "strokes": picked.strokes.count, "png_bytes": png.count,
        "crop": rect(crop),
      ])
    let started = ContinuousClock.now
    Task { @MainActor [weak self] in
      let answer = await Self.read(png: png, board: board, cockpit: cockpit)
      guard let self else { return }
      self.toText.reading = false
      self.toTextAnswered(
        answer, keys: picked.keys, ink: box, color: color, ms: Int(started.duration(to: .now) / .milliseconds(1)))
    }
  }

  private nonisolated static func read(png: Data, board: String, cockpit: String) async -> BoardToText.Answer {
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try BoardToText.request(png: png, board: board, cockpit: cockpit))
      return BoardToText.answer(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      return BoardToText.answer(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  private func toTextAnswered(
    _ answer: BoardToText.Answer, keys: Set<String>, ink: CGRect, color: UIColor, ms: Int
  ) {
    var event: [String: Any] = ["action": "to_text_done", "board": model.board.id, "ms": ms]
    defer { log.event("whiteboard", event) }
    switch answer {
    case .failed(let status, let reason):
      event["action"] = "to_text_failed"
      event["reason"] = reason
      if let status { event["status"] = status }
      var error: [String: Any] = ["where": "whiteboard_to_text", "message": reason, "board": model.board.id]
      if let status { error["status"] = status }
      log.event("error", error)
      var extra: [String: JSONValue] = [
        "board": .string(model.board.id), "cockpit": .string(model.cockpitURL), "strokes": .int(keys.count),
      ]
      if let status { extra["status"] = .int(status) }
      model.show(problem: .grabber("To text failed: \(reason)", context: Self.toTextContext, extra: extra))
      return
    case .noWriting:
      event["outcome"] = "no_writing"
      model.say("No writing found there")
      return
    case .tooLong:
      event["outcome"] = "too_long"
      model.say("Too much writing for one text (500 characters): select less")
      return
    case .text(let words):
      if model.problem?.context == Self.toTextContext { model.show(problem: nil) }
      let here = Set(paper.markup?.subelements.strokes.map { Self.key($0.elementID) } ?? [])
      guard !keys.isDisjoint(with: here) else {
        event["outcome"] = "ink_gone"
        model.say("The ink went while it was being read")
        return
      }
      let lines = BoardToText.lines(words, ink: ink)
      let made = BoardText.time(Date())
      let strokes = lines.flatMap { line in
        WhiteboardModel.strokes(
          WhiteboardTurn.lines(line.shape, frame: .zero, scale: 1), color: color,
          width: WhiteboardTurn.width(line.shape, scale: 1), spacing: 4, made: made.date)
      }
      guard !strokes.isEmpty else {
        event["outcome"] = "no_letters"
        model.say("No writing found there")
        return
      }
      let id = "text-" + UUID().uuidString.prefix(8).lowercased()
      model.keep(
        text: BoardText(
          id: id, t: made.t, text: BoardToText.words(lines), font: .plain, size: Double(lines[0].size),
          color: WhiteboardModel.lightHex(color), glyphs: strokes.count))
      paper.selection = []
      replaceInk(removing: keys, adding: strokes, named: BoardToText.undoName)
      showToText()
      event.merge(
        ["outcome": "text", "text_id": id, "chars": words.count, "lines": lines.count, "glyphs": strokes.count]
      ) { $1 }
    }
  }

  /// Just this ink, cropped to `crop` (board points), on white, `BoardToText.pixelsPerPoint` pixels a point, as a PNG.
  static func picture(of ink: PKDrawing, crop: CGRect) -> Data? {
    let scale = BoardToText.pixelsPerPoint
    var image: UIImage?
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { image = ink.image(from: crop, scale: scale) }
    guard let image else { return nil }
    let size = CGSize(width: (crop.width * scale).rounded(), height: (crop.height * scale).rounded())
    guard size.width > 0, size.height > 0 else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// `GRABBER_WHITEBOARD_AFTER_INK=select`: all the ink selected, as the lasso would leave it, for the simulator, which
  /// can't work the lasso (story 920's UI test).
  func selectAllForTests() {
    guard let markup = paper.markup else { return }
    paper.selection = Set(markup.subelements.strokes.map(\.elementID))
    showToText()
    log.event(
      "whiteboard", ["action": "paper_select_hook", "board": model.board.id, "selected": paper.selection.count])
  }
}

/// Story 920: To text beside the lasso's ink. Over the board, not in it, so it is in no picture.
struct ToTextButton: View {
  let controller: PaperBoardController
  @ObservedObject var state: BoardToTextState
  private static let size = CGSize(width: 128, height: 44)

  var body: some View {
    GeometryReader { geometry in
      if let frame = state.frame {
        let place = WhiteboardMarkChoice.place(
          mark: frame, buttons: Self.size, in: CGRect(origin: .zero, size: geometry.size))
        Button(state.reading ? "Reading…" : "To text", systemImage: "character.textbox") { controller.toTextTapped() }
          .disabled(state.reading)
          .accessibilityIdentifier("whiteboard-to-text")
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.bordered)
          .controlSize(.small)
          .frame(width: Self.size.width, height: Self.size.height)
          .background(.regularMaterial, in: Capsule())
          .position(x: place.midX, y: place.midY)
      }
    }
  }
}
