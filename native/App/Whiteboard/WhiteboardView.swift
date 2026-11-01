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
    var failure: String?
    if let file, FileManager.default.fileExists(atPath: file.path) {
      do {
        loaded = try PKDrawing(data: Data(contentsOf: file))
      } catch {
        // Kept aside, never overwritten by the empty board that replaces it.
        let aside = file.appendingPathExtension("unreadable")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: file, to: aside)
        log.event("whiteboard", ["action": "load_failed", "error": "\(error)"])
        failure =
          "The saved board could not be read, so it was set aside and this one is new: \(error.localizedDescription)"
      }
    } else if file == nil {
      failure = "This build has nowhere to keep the board, so what is drawn is lost on close."
    }
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    problem = failure.map { .grabber($0, context: "WhiteboardView.load", extra: [:]) }
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

  /// Leaving the board, by Done or by a link that takes it down: what is drawn is written now, not a second later.
  /// Safe to call twice.
  func close() {
    saveTask?.cancel()
    guard dirty else { return }
    save()
    log.event("whiteboard", ["action": "close", "strokes": drawing.strokes.count])
  }

  // ponytail: serialised on the main thread; a board big enough to stutter here moves it to a background task.
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
  @Environment(\.scenePhase) private var scenePhase
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
    .onDisappear { model.close() }
    .onChange(of: scenePhase) { _, phase in if phase == .background { model.close() } }
  }
}

/// PencilKit's canvas on a board far bigger than the screen.
private struct BoardCanvas: UIViewRepresentable {
  let model: WhiteboardModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> BoardCanvasView {
    let canvas = BoardCanvasView()
    canvas.drawing = model.drawing
    canvas.delegate = context.coordinator
    // The system's own choice: with a Pencil paired, only it draws (palm rejection, a finger moves the board);
    // without one (an iPhone, the simulator), a finger draws.
    canvas.drawingPolicy = .default
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
    guard !opened, bounds.width > 0, bounds.height > 0 else { return }
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
