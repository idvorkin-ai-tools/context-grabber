//  A board on paper: what covers it, for the log (#1140, story 1102). On the iPad a popover drawn by another process sat
//  over the whole board, every tap brought up Paste · Select All, and the log heard no touch; this says what came over
//  the board, when, and how long it stayed, before anything is changed.

import UIKit

extension PaperBoardController {
  /// Once a second while the board's controller lives, a look at what sits over its window; a line only on a change.
  func watchCovers() {
    let watch = BoardCoverWatch(board: model.board.id, log: log)
    Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard let self else { return }
        watch.look(in: view.window)
      }
    }
  }
}

/// What covers a window, and the line that says when it changed.
@MainActor
final class BoardCoverWatch {
  struct Cover: Equatable {
    var covers: [String] = []
    var style = ""
    var presentation = ""
    var frame: [Int] = []
    var source = ""
    var sourceRect: [Int] = []
    var remote = false
    var editMenu: [Int] = []
    var responder = ""
  }

  private let board: String
  private let log: SessionLog
  private var last = Cover()
  private var since = Date()

  init(board: String, log: SessionLog) {
    self.board = board
    self.log = log
  }

  func look(in window: UIWindow?) {
    guard let window else { return }
    let now = Self.cover(of: window)
    guard now != last else { return }
    log.event(
      "whiteboard",
      [
        "action": "board_cover", "board": board, "covers": now.covers, "style": now.style,
        "presentation": now.presentation, "frame": now.frame, "source": now.source, "source_rect": now.sourceRect,
        "remote": now.remote, "edit_menu": now.editMenu, "responder": now.responder,
        "was_ms": Int(Date().timeIntervalSince(since) * 1_000),
      ])
    last = now
    since = Date()
  }

  static func cover(of window: UIWindow) -> Cover {
    var cover = Cover()
    var chain: [UIViewController] = []
    var next = window.rootViewController?.presentedViewController
    while let shown = next {
      chain.append(shown)
      next = shown.presentedViewController
    }
    cover.covers = chain.map(name)
    if let top = chain.last {
      cover.style = style(top.modalPresentationStyle)
      cover.presentation = top.presentationController.map(name) ?? ""
      if top.isViewLoaded { cover.frame = ints(top.view.convert(top.view.bounds, to: window)) }
      if top.modalPresentationStyle == .popover, let popover = top.popoverPresentationController {
        cover.source = popover.sourceView.map(describe) ?? popover.sourceItem.map { name($0) } ?? ""
        if let view = popover.sourceView { cover.sourceRect = ints(view.convert(popover.sourceRect, to: window)) }
      }
      cover.remote = top.isViewLoaded && drawnElsewhere(top.view)
    }
    if let menu = window.subviews.first(where: { name($0).contains("EditMenu") && !$0.isHidden }),
      let list = menu.subviews.first(where: { !$0.isHidden && $0.alpha > 0 })
    {
      cover.editMenu = ints(list.convert(list.bounds, to: window))
    }
    cover.responder = FirstResponder.now().map(describe) ?? ""
    return cover
  }

  /// A view hosting another process's scene: touches on it go to that process, never through the app's window.
  private static func drawnElsewhere(_ view: UIView) -> Bool {
    var looks = [(view, 0)]
    var seen = 0
    while let (here, depth) = looks.popLast(), seen < 300 {
      seen += 1
      let kind = name(here)
      if kind.contains("SceneHosting") || kind.contains("RemoteView") || kind.contains("LayerHost") { return true }
      if depth < 10 { looks += here.subviews.map { ($0, depth + 1) } }
    }
    return false
  }

  private static func describe(_ responder: UIResponder) -> String {
    guard let view = responder as? UIView, let id = view.accessibilityIdentifier, !id.isEmpty else {
      return name(responder)
    }
    return "\(name(view)) \(id)"
  }

  private static func name(_ thing: Any) -> String { String(describing: type(of: thing)) }

  private static func ints(_ rect: CGRect) -> [Int] {
    [rect.minX, rect.minY, rect.width, rect.height].map { Int($0.rounded()) }
  }

  private static func style(_ style: UIModalPresentationStyle) -> String {
    switch style {
    case .fullScreen: "full_screen"
    case .pageSheet: "page_sheet"
    case .formSheet: "form_sheet"
    case .currentContext: "current_context"
    case .custom: "custom"
    case .overFullScreen: "over_full_screen"
    case .overCurrentContext: "over_current_context"
    case .popover: "popover"
    case .none: "none"
    case .automatic: "automatic"
    @unknown default: "other \(style.rawValue)"
    }
  }
}

/// The first responder, found by asking it to answer: UIKit has no public way to read it.
@MainActor
private enum FirstResponder {
  static weak var found: UIResponder?

  static func now() -> UIResponder? {
    found = nil
    UIApplication.shared.sendAction(#selector(UIResponder.boardCoverNoteFirstResponder), to: nil, from: nil, for: nil)
    return found
  }
}

extension UIResponder {
  @objc fileprivate func boardCoverNoteFirstResponder() { FirstResponder.found = self }
}
