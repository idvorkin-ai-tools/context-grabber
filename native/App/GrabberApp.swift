//  Grabber Native: the Swift-native Context Grabber, built beside the React Native app until it can replace it
//  (docs/superpowers/specs/2026-10-04-swift-native-app-design.md).

import BugKit
import SwiftUI

@main
struct GrabberApp: App {
  @StateObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var wasActive = false

  init() {
    _model = StateObject(wrappedValue: AppModel())  // installs BugKit's crash capture before anything else it builds
  }

  var body: some Scene {
    WindowGroup {
      DiagnosticsView(model: model)
        .bugReporting(model.reporter)
        .onOpenURL { model.open(url: $0) }
        .onChange(of: scenePhase) { _, phase in
          // The first activation is the launch, which pruned already; every later one is a foreground.
          if phase == .active {
            if wasActive {
              model.foreground()
            } else {
              model.tracker.foreground(); model.usage.resume(reason: "launch")
              model.mirror.refresh(reason: "launch")  // #355: the Today card current, in the background
              model.archive.launch()  // story 262: the next slots asked for, and a run if one is due
            }
            wasActive = true
          } else if phase == .background {
            model.usage.pause()
          }
        }
    }
  }
}
