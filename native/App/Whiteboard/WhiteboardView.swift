//  The whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343): PencilKit's canvas and the system tool
//  picker on a board far bigger than the screen, saved a moment after each stroke, and sent to Larry as a new chat
//  thread holding its picture (the Inbox's image path, so it waits in the outbox when the network is away).

import BugKit
import ContextCore
import PencilKit
import SwiftUI

@MainActor
final class WhiteboardModel: ObservableObject {
  @Published private(set) var isEmpty: Bool
  /// What the last Send did, shown in the bar until the next stroke.
  @Published private(set) var sent: String?
  @Published private(set) var problem: BugProblem?
  private(set) var drawing: PKDrawing
  private let file: URL?
  private let log: SessionLog
  private let inbox: InboxModel
  private var saveTask: Task<Void, Never>?
  private var dirty = false

  init(log: SessionLog, inbox: InboxModel) {
    self.log = log
    self.inbox = inbox
    file = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("whiteboard", isDirectory: true).appendingPathComponent("board.drawing")
    var loaded = PKDrawing()
    if let file, let data = try? Data(contentsOf: file) {
      do {
        loaded = try PKDrawing(data: data)
      } catch {
        // Kept aside, never overwritten by the empty board that replaces it.
        let aside = file.appendingPathExtension("unreadable")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: file, to: aside)
        log.event("whiteboard", ["action": "load_failed", "bytes": data.count, "error": "\(error)"])
      }
    }
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    log.event("whiteboard", ["action": "open", "strokes": loaded.strokes.count])
  }

  func changed(_ new: PKDrawing) {
    drawing = new
    isEmpty = new.strokes.isEmpty
    sent = nil
    dirty = true
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  /// Leaving the board: what is drawn is written now, not a second later.
  func close() {
    saveTask?.cancel()
    save()
    log.event("whiteboard", ["action": "close", "strokes": drawing.strokes.count])
  }

  private func save() {
    guard dirty, let file else { return }
    do {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try drawing.dataRepresentation().write(to: file, options: .atomic)
      dirty = false
    } catch {
      log.event("whiteboard", ["action": "save_failed", "error": "\(error)"])
      problem = .grabber(
        "The board could not be saved: \(error.localizedDescription)", context: "WhiteboardView.save",
        extra: ["strokes": .int(drawing.strokes.count)])
    }
  }

  /// Story 343: the whole drawing, dark ink on white whatever the iPad's mode, as a new thread with Larry.
  func send() {
    guard let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
    var ink = UIImage()
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { ink = drawing.image(from: rect, scale: scale) }
    let format = UIGraphicsImageRendererFormat()
    format.scale = ink.scale
    format.opaque = true
    let jpeg = UIGraphicsImageRenderer(size: ink.size, format: format).jpegData(withCompressionQuality: 0.85) { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: ink.size))
      ink.draw(at: .zero)
    }
    var draft = InboxDraft()
    draft.image = jpeg
    draft.text = WhiteboardFrame.title(at: Date())
    do {
      try inbox.add(&draft)
      problem = nil
      sent = "Sent to Larry: his reply shows in Chat"
      log.event(
        "whiteboard",
        [
          "action": "send", "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
        ])
    } catch {
      log.event("whiteboard", ["action": "send_failed", "error": "\(error)"])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}

struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  private let logger: BugLogger
  private let onDone: () -> Void

  init(app: AppModel, onDone: @escaping () -> Void) {
    _model = StateObject(wrappedValue: WhiteboardModel(log: app.log, inbox: app.inbox))
    logger = app.bugLogger
    self.onDone = onDone
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button("Done") {
          model.close()
          onDone()
        }
        .accessibilityIdentifier("whiteboard-done")
        Spacer(minLength: 0)
        if let sent = model.sent {
          Text(sent).font(.footnote).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        Spacer(minLength: 0)
        Button {
          model.send()
        } label: {
          Label("Send to Larry", systemImage: "paperplane")
        }
        .disabled(model.isEmpty)
        .accessibilityIdentifier("whiteboard-send")
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      if let problem = model.problem {
        BugProblemView(problem: problem, logger: logger).padding(.horizontal)
      }
      BoardCanvas(model: model).ignoresSafeArea(edges: .bottom)
    }
    .accessibilityIdentifier("whiteboard")
  }
}

/// PencilKit's canvas: the Pencil draws on the iPad and a finger moves the board; on the iPhone a finger draws and
/// two move it.
private struct BoardCanvas: UIViewRepresentable {
  let model: WhiteboardModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> BoardCanvasView {
    let canvas = BoardCanvasView()
    canvas.drawing = model.drawing
    canvas.delegate = context.coordinator
    canvas.drawingPolicy = UIDevice.current.userInterfaceIdiom == .pad ? .pencilOnly : .anyInput
    canvas.backgroundColor = .systemBackground
    canvas.isOpaque = true
    canvas.contentSize = CGSize(width: WhiteboardFrame.side, height: WhiteboardFrame.side)
    canvas.minimumZoomScale = 0.1
    canvas.maximumZoomScale = 3
    canvas.toolPicker = context.coordinator.picker
    return canvas
  }

  func updateUIView(_ canvas: BoardCanvasView, context: Context) {}

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    let model: WhiteboardModel
    /// Held here: the tool picker disappears when nothing keeps it.
    let picker = PKToolPicker()

    init(model: WhiteboardModel) { self.model = model }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      let drawing = canvasView.drawing
      MainActor.assumeIsolated { model.changed(drawing) }
    }
  }
}

final class BoardCanvasView: PKCanvasView {
  fileprivate var toolPicker: PKToolPicker?
  private var opened = false

  /// The first layout knows the screen's size: the view opens centred on the drawing.
  override func layoutSubviews() {
    super.layoutSubviews()
    guard !opened, bounds.width > 0 else { return }
    opened = true
    let drawn = drawing.strokes.isEmpty ? nil : drawing.bounds
    contentOffset = WhiteboardFrame.openingOffset(drawing: drawn, viewport: bounds.size)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let toolPicker else { return }
    toolPicker.addObserver(self)
    toolPicker.setVisible(true, forFirstResponder: self)
    becomeFirstResponder()
  }
}
