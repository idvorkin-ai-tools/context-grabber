//  The Board Lab (story 1501, plan docs/superpowers/plans/2026-11-22-board-lab-plan.md): the app's own board, with its
//  own AppModel, in a window that is only the boards list. No home window and no scene-phase work (the launch grabs,
//  the foreground refreshes), so a whiteboard UI test that launches it waits less. The launch hooks are the app's
//  (docs/TESTING.md); `GRABBER_LAB_SESSION=<name>` also asks the fake Cockpit to play that recorded session (story 1174)
//  on the first board message.

import ContextCore
import SwiftUI

@main
struct BoardLabApp: App {
  @StateObject private var model: AppModel

  init() {
    let model = AppModel()
    _model = StateObject(wrappedValue: model)
    if LaunchHooks.current.noAnimations { UIView.setAnimationsEnabled(false) }
    BoardLabSession.play(LaunchHooks.environment, log: model.log)
  }

  var body: some Scene {
    WindowGroup {
      WhiteboardListView(app: model, onDone: {})
        .bugReporting(model.reporter)
    }
  }
}

/// `GRABBER_LAB_SESSION`: the fake Cockpit plays that recorded session on the first board message (story 1174).
enum BoardLabSession {
  static func play(_ env: [String: String], log: SessionLog) {
    guard let name = env["GRABBER_LAB_SESSION"], !name.isEmpty,
      let cockpit = env["GRABBER_CHAT_URL"].flatMap(URL.init(string:))
    else { return }
    var request = URLRequest(url: cockpit.appendingPathComponent("fake/session"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": name, "thread": "first"])
    URLSession.shared.dataTask(with: request) { _, response, error in
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      log.event(
        "board_lab", ["action": "session", "name": name, "status": status, "error": error.map { "\($0)" } ?? ""])
    }.resume()
  }
}
