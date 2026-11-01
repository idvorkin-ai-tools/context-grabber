//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347): PencilKit's canvas and the system tool
//  picker on a board far bigger than the screen, saved a moment after each stroke, and sent to Larry as a new chat
//  thread holding its picture (the Inbox's image path, so it waits in the outbox when the network is away). A board
//  another device draws opens to look at only.

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
  let board: BoardEntry
  /// Drawn here, or only looked at (a board from another device, story 347).
  let editable: Bool
  private(set) var drawing: PKDrawing
  private let store: WhiteboardStore
  private let log: SessionLog
  private let inbox: InboxModel
  private var saveTask: Task<Void, Never>?
  private var dirty = false
  private var saveFailing = false

  init(board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel) {
    self.board = board
    self.store = store
    self.log = log
    self.inbox = inbox
    editable = store.editable(board)
    var loaded = PKDrawing()
    do {
      loaded = try store.drawing(board.id)
    } catch {
      log.event("error", ["where": "whiteboard_load", "message": "\(error)", "board": board.id])
      problem = .grabber(
        "This board could not be read: \(error.localizedDescription)", context: "WhiteboardView.load",
        extra: ["board": .string(board.id)])
    }
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    log.event(
      "whiteboard",
      ["action": "open", "board": board.id, "strokes": loaded.strokes.count, "editable": store.editable(board)])
  }

  func changed(_ new: PKDrawing) {
    guard editable else { return }
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

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
    saveTask?.cancel()
    guard editable else { return }
    if dirty {
      save()
      log.event("whiteboard", ["action": "close", "board": board.id, "strokes": drawing.strokes.count])
    }
    store.closed(board.id, empty: drawing.strokes.isEmpty)
  }

  // ponytail: serialised on the main thread; a board big enough to stutter here moves it to a background task.
  private func save() {
    guard dirty else { return }
    do {
      try store.save(drawing, board: board.id)
      dirty = false
      saveFailing = false
    } catch {
      if !saveFailing {
        log.event("error", ["where": "whiteboard_save", "message": "\(error)", "strokes": drawing.strokes.count])
      }
      saveFailing = true
      problem = .grabber(
        "The board could not be saved: \(error.localizedDescription)", context: "WhiteboardView.save",
        extra: ["strokes": .int(drawing.strokes.count)])
    }
  }

  /// Story 343: the whole drawing, dark ink on white whatever the iPad's mode, as a new thread with Larry, titled
  /// with the board's name.
  func send() {
    guard sent == nil, let (rect, scale) = WhiteboardFrame.export(drawing.bounds) else { return }
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
    draft.text = store.index.board(board.id)?.title ?? board.title
    do {
      try inbox.add(&draft)
      if problem?.context == "WhiteboardView.send" { problem = nil }
      sent = "Sent to Larry: his reply shows in Chat"
      log.event(
        "whiteboard",
        [
          "action": "send", "board": board.id, "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
        ])
    } catch {
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}

/// One board, pushed from the list: drawn on here, or looked at when another device draws it.
struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  @Environment(\.scenePhase) private var scenePhase
  private let logger: BugLogger

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(wrappedValue: WhiteboardModel(board: board, store: store, log: app.log, inbox: app.inbox))
    logger = app.bugLogger
  }

  var body: some View {
    VStack(spacing: 0) {
      if let note {
        Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
          .padding(.vertical, 4)
      }
      if let problem = model.problem {
        BugProblemView(problem: problem, logger: logger).padding(.horizontal)
      }
      BoardCanvas(model: model).ignoresSafeArea(edges: .bottom)
    }
    .navigationTitle(model.board.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          model.send()
        } label: {
          Label("Send to Larry", systemImage: "paperplane")
        }
        .disabled(model.isEmpty || model.sent != nil)
        .accessibilityIdentifier("whiteboard-send")
      }
    }
    .accessibilityIdentifier("whiteboard")
    .onDisappear { model.close() }
    .onChange(of: scenePhase) { _, phase in if phase == .background { model.close() } }
  }

  private var note: String? {
    model.sent ?? (model.editable ? nil : "Drawn on \(model.board.deviceName): look only")
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
    if model.editable {
      canvas.toolPicker = context.coordinator.picker
    } else {
      // Story 347: pan and pinch only.
      canvas.drawingGestureRecognizer.isEnabled = false
    }
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
