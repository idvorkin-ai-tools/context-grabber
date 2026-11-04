//  A Mac has no Live Activity and ActivityKit doesn't compile for one (#638, story 585). The Mac build leaves out the
//  real controller and the card's attributes (native/project.yml); the timer and breathing feed this as they would a
//  phone's, and the window is all there is.

#if targetEnvironment(macCatalyst)
  import ContextCore

  @MainActor
  final class LiveActivityController {
    init(log: SessionLog) {}
    func endLeftovers() {}
    func sync(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?) {}
    func end(_ kind: LiveActivityKind, reason: String) {}
  }
#endif
