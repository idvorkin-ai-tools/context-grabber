//  A call held for the app (#582, story 829): iOS refuses to start the call's microphone while the app is not in
//  front, so a refusal then is not a failure to heal. The call waits, asks Igor to open Grabber, and starts the mic
//  the moment the app is in front; after five minutes it ends as a hang-up does.
//
//  Spec: "A microphone refused because the app is not in front waits for it" in
//  docs/superpowers/specs/2026-08-28-native-call-screen-design.md.

/// What the session asks of the app's notification: one post per call, removed when the hold ends.
public enum CallHoldNotice: Equatable, Sendable { case post, remove }

public enum CallHold {
  /// How long a held call waits for the app.
  public static let ceilingMs = 5 * 60_000.0
  /// The screen's line while held.
  public static let waiting = "Open Grabber to start the mic"
  public static let notificationTitle = "Larry's call is waiting"
  public static let notificationBody = "Open Grabber to start the mic."
  /// The ending after the ceiling: an ordinary hang-up's, not a failure.
  public static let timedOut = "the mic never started: Grabber was not opened within 5 minutes"

  /// A refused mic start holds when the app is not in front ("background", "inactive"); in front it is a real audio
  /// failure and gets the reset and the redial.
  public static func holds(appState: String) -> Bool { appState != "active" }

  public enum Comeback: Equatable, Sendable { case startMic, timedOut }

  /// The app came forward: start the mic, unless the ceiling passed while the app was away (a suspended app's
  /// timer fires late, so this reads the clock rather than trusting the timer).
  public static func comeback(heldAt: Double, now: Double) -> Comeback {
    now - heldAt >= ceilingMs ? .timedOut : .startMic
  }

  /// A `call_audio` refusal logged with the app not in front, which a held call answers by waiting: not trouble.
  static func isBackgroundRefusal(_ event: CallEvent) -> Bool {
    guard event.type == "call_audio", event.fields["ok"] as? Bool == false,
      let state = event.fields["app_state"] as? String
    else { return false }
    return holds(appState: state)
  }
}
