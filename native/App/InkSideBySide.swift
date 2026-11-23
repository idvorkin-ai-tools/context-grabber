//  Ink side by side (story 1209, bead context-grabber-vabk; spec docs/superpowers/specs/2026-11-22-ink-side-by-side-design.md):
//  a debug screen, the app's own PencilKit ink on the left and the Cockpit's /ink web board on the right, each with
//  how long a pen-down takes to reach the next frame. An A/B tool only: the board's own drawing is untouched.
//
//  Both halves measure the same span on their own clock: the pen's own timestamp, to the start of the first frame
//  after it. Native: UITouch.timestamp to CACurrentMediaTime() at the first CADisplayLink tick (both are seconds of
//  system uptime). Web: the pointer event's timeStamp to performance.now() in the first requestAnimationFrame after
//  it (both on the page's performance clock). Neither sees the pixels; the spec says what that misses.

import BugKit
import ContextCore
import PencilKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import WebKit

@MainActor
final class InkSideBySideModel: ObservableObject {
  @Published private(set) var native = InkLatency(side: .native)
  @Published private(set) var web = InkLatency(side: .web)
  @Published private(set) var clears = 0
  @Published var webProblem: BugProblem?
  let log: SessionLog
  let webURL: URL?

  init(log: SessionLog) {
    self.log = log
    // Always Igor's real Cockpit: the web board is the thing being compared, never a stand-in page.
    webURL = InkLatency.webBoardURL(cockpit: ChatCockpit.pageAddress(override: nil))
  }

  func record(_ side: InkLatency.Side, ms: Double) {
    let fields: [String: Any]
    switch side {
    case .native:
      let outcome = native.add(ms)
      fields = native.logFields(ms: ms, outcome: outcome)
    case .web:
      let outcome = web.add(ms)
      fields = web.logFields(ms: ms, outcome: outcome)
    }
    log.event("ink_side_by_side", fields)
  }

  func clear() {
    clears += 1
    log.event("ink_side_by_side", ["action": "clear", "side": InkLatency.Side.native.rawValue])
  }

  func webFailed(_ error: Error, url: URL?) {
    let ns = error as NSError
    // A navigation the page itself replaced is not a failure.
    if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
    log.event(
      "ink_side_by_side",
      ["action": "web_failed", "error": ns.localizedDescription, "code": ns.code, "url": url?.absoluteString ?? ""])
    webProblem = BugProblem(
      message: "The web board didn't load: \(ns.localizedDescription)", context: "InkSideBySide.webBoard",
      build: "\(BuildInfo.sha) \(BuildInfo.branch)",
      extra: [
        "url": .string(url?.absoluteString ?? "none"), "domain": .string(ns.domain), "code": .int(ns.code),
      ],
      autoFile: false)
  }
}

struct InkSideBySideView: View {
  @StateObject private var model: InkSideBySideModel

  init(log: SessionLog) {
    _model = StateObject(wrappedValue: InkSideBySideModel(log: log))
  }

  var body: some View {
    HStack(spacing: 0) {
      half(title: "iPad ink (PencilKit)", readout: model.native.readout, side: .native) {
        NativeInkCanvas(model: model)
      }
      Divider()
      half(title: "Web board (/ink)", readout: model.web.readout, side: .web) {
        ZStack(alignment: .top) {
          WebInkBoard(model: model)
          if let problem = model.webProblem {
            BugProblemView(problem: problem, logger: model.log.bugLogger).padding()
              .accessibilityIdentifier("ink-web-problem")
          }
        }
      }
    }
    .navigationTitle("Ink side by side")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Clear") { model.clear() }.accessibilityIdentifier("ink-native-clear")
      }
    }
    .onAppear {
      model.log.event("ink_side_by_side", ["action": "open", "web": model.webURL?.absoluteString ?? "none"])
    }
  }

  private func half<Content: View>(
    title: String, readout: String, side: InkLatency.Side, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(title).font(.footnote.weight(.semibold))
        Spacer()
        Text(readout).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
          .accessibilityIdentifier("ink-\(side.rawValue)-readout")
      }
      .padding(.horizontal, 10).padding(.vertical, 6)
      .background(.bar)
      content()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// The left half: a plain PencilKit canvas with a black pen, Pencil or finger, measured from each pen-down.
private struct NativeInkCanvas: UIViewRepresentable {
  @ObservedObject var model: InkSideBySideModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.drawingPolicy = .anyInput
    canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
    canvas.backgroundColor = .white
    canvas.isOpaque = true
    canvas.accessibilityIdentifier = "ink-native-canvas"
    let watcher = PenDownWatcher(target: nil, action: nil)
    watcher.onDown = { [weak coordinator = context.coordinator] stamp in coordinator?.penDown(at: stamp) }
    canvas.addGestureRecognizer(watcher)
    context.coordinator.clears = model.clears
    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    guard context.coordinator.clears != model.clears else { return }
    context.coordinator.clears = model.clears
    canvas.drawing = PKDrawing()
  }

  @MainActor
  final class Coordinator {
    let model: InkSideBySideModel
    var clears = 0
    init(model: InkSideBySideModel) { self.model = model }

    /// `stamp` is the touch's own timestamp; the first display-link tick after it is the next frame.
    func penDown(at stamp: TimeInterval) {
      NextFrame.after { [weak self] now in self?.model.record(.native, ms: (now - stamp) * 1000) }
    }
  }
}

/// Sees every touch go down on the canvas, then steps aside at once, so PencilKit's own drawing never waits on it.
private final class PenDownWatcher: UIGestureRecognizer {
  var onDown: ((TimeInterval) -> Void)?

  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    if let first = touches.min(by: { $0.timestamp < $1.timestamp }) { onDown?(first.timestamp) }
    state = .failed
  }
}

/// One CADisplayLink tick, then gone: calls back with CACurrentMediaTime() at the start of the next frame.
@MainActor
private final class NextFrame {
  private var link: CADisplayLink?
  private let done: (TimeInterval) -> Void
  private static var live: [ObjectIdentifier: NextFrame] = [:]

  private init(done: @escaping (TimeInterval) -> Void) { self.done = done }

  static func after(_ done: @escaping (TimeInterval) -> Void) {
    let frame = NextFrame(done: done)
    live[ObjectIdentifier(frame)] = frame
    let link = CADisplayLink(target: frame, selector: #selector(tick))
    frame.link = link
    link.add(to: .main, forMode: .common)
  }

  @objc private func tick() {
    let now = CACurrentMediaTime()
    link?.invalidate()
    link = nil
    Self.live[ObjectIdentifier(self)] = nil
    done(now)
  }
}

/// The right half: the Cockpit's /ink page on its scratch board, with a probe that times each pointer-down.
private struct WebInkBoard: UIViewRepresentable {
  @ObservedObject var model: InkSideBySideModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> WKWebView {
    let controller = WKUserContentController()
    controller.addUserScript(
      WKUserScript(source: InkLatency.webProbeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    controller.add(WeakMessages(context.coordinator), name: InkLatency.messageHandler)
    let config = WKWebViewConfiguration()
    config.userContentController = controller
    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = context.coordinator
    web.accessibilityIdentifier = "ink-web-board"
    #if DEBUG
      web.isInspectable = true
    #endif
    if let url = model.webURL {
      web.load(URLRequest(url: url))
    } else {
      model.webFailed(URLError(.badURL), url: nil)
    }
    return web
  }

  func updateUIView(_ web: WKWebView, context: Context) {}

  static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
    web.configuration.userContentController.removeScriptMessageHandler(forName: InkLatency.messageHandler)
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate {
    let model: InkSideBySideModel
    init(model: InkSideBySideModel) { self.model = model }

    func received(_ body: Any) {
      guard let dict = body as? [String: Any], let ms = (dict["ms"] as? NSNumber)?.doubleValue else { return }
      model.record(.web, ms: ms)
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      model.webProblem = nil
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      model.webFailed(error, url: webView.url ?? model.webURL)
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      model.webFailed(error, url: webView.url ?? model.webURL)
    }
  }
}

/// The content controller keeps its handler alive; this keeps only a weak hold on the coordinator.
private final class WeakMessages: NSObject, WKScriptMessageHandler {
  private weak var coordinator: WebInkBoard.Coordinator?
  init(_ coordinator: WebInkBoard.Coordinator) { self.coordinator = coordinator }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    let body = message.body
    MainActor.assumeIsolated { coordinator?.received(body) }
  }
}
