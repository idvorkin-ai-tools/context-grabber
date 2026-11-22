//  Speaking a message in Chat (#448, chat spec "Speaking a message", story 303): the thread's mic is BugKit's
//  NoteDictation, the problem report's Apple dictation (Igor, 2026-10-26: "All right, use that."). The words stream
//  into that thread's bar as he speaks, after what was typed, never sent. Who has the microphone is the floor's
//  (`MicFloor`, spec 2026-11-10-microphone-floor-design.md): a tap asks it first, and a call taking it stops the
//  recording through `yieldToCall`. A recording stops itself at ChatVoice.limit.

import AVFoundation
import BugKit
import Combine
import ContextCore
import Foundation
import Security
import UIKit

@MainActor
final class ChatVoiceModel: ObservableObject {
  enum Phase: Equatable {
    case idle
    /// Asking for permission or bringing the recognizer up.
    case starting
    case recording(since: Date)
    /// Stopped; the last words settling.
    case finishing
  }

  @Published private(set) var callLive = false
  /// A short line under the bar: a call has the mic, a call took it, the five-minute stop.
  @Published private(set) var notice: String?
  /// The whole draft for one thread's bar — what was typed, then the words so far — taken once, by that thread only.
  @Published private(set) var words = ChatVoiceWords()
  /// The thread the last tap was in: its words, `notice` and `problem` show in that thread's bar only.
  @Published private(set) var thread = ""

  private let log: SessionLog
  /// The floor, asked at a tap: nil lets the recording start, otherwise who has the microphone. AppModel sets it.
  var askMic: @MainActor () -> AudioUser? = { nil }
  /// Who else has the microphone, without asking for it: what the recognizer checks again as it starts and before
  /// it lists the microphones. AppModel sets it.
  var micHeldElsewhere: @MainActor () -> AudioUser? = { nil }
  private lazy var dictation = NoteDictation(
    logger: log.bugLogger, hostMicrophoneBusy: { [weak self] in self?.micHeldElsewhere() != nil })
  /// Each recording's start, stop and five-minute timer (ContextCore, host-tested).
  private var clock = ChatVoiceClock()
  /// The saved microphone is named once per launch, the first time a picker shows (story 303).
  private var namedSavedMicrophone = false
  private var capTimer: Task<Void, Never>?
  private var watches: Set<AnyCancellable> = []
  private nonisolated(unsafe) var routeObserver: NSObjectProtocol?

  init(log: SessionLog, callLive: AnyPublisher<Bool, Never>) {
    self.log = log
    Self.purgeDeepgramKey(log: log)
    // The dictation's own state is this model's: the button and the bar redraw with it.
    dictation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &watches)
    dictation.$listening.removeDuplicates().dropFirst().sink { [weak self] listening in
      MainActor.assumeIsolated { self?.listeningChanged(listening) }
    }
    .store(in: &watches)
    // No hop to the next run loop: the call model publishes on the main actor, and a late stop would restore the
    // session over the call's.
    callLive.removeDuplicates().sink { [weak self] live in
      MainActor.assumeIsolated { self?.callChanged(live) }
    }
    .store(in: &watches)
    // #1165: every route change during a recording, read here on the main queue before BugKit's own observer hops to
    // a Task and stops the recording, so a stop for "the microphone changed" says what changed.
    // ponytail: idvorkin/bug-kit#133 (NoteDictation logs no reason or input when it stops); drop once it ships.
    // On the main queue and read at once: BugKit's observer, registered first, only enqueues its stop as a Task, so
    // this runs while the recording is still live.
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      MainActor.assumeIsolated { self?.routeChanged(note) }
    }
  }

  deinit {
    if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
  }

  /// The Deepgram key the first version of this mic kept (#533) has no use now: gone from the Keychain at launch,
  /// logged only when there was one. Never logs the key.
  private static func purgeDeepgramKey(log: SessionLog) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.idvorkin.grabbernative.deepgram",
    ]
    if SecItemDelete(query as CFDictionary) == errSecSuccess { log.event("chat_voice", ["action": "key_purged"]) }
  }

  var phase: Phase {
    if dictation.listening { return .recording(since: clock.since ?? Date()) }
    if dictation.starting { return .starting }
    if dictation.processing { return .finishing }
    return .idle
  }

  /// What the dictation could not do (a permission off, the recognizer stopping, an interruption), copyable.
  func problem(context: String = "ChatThreadView.voice") -> BugProblem? {
    guard let message = dictation.problem else { return nil }
    var extra = dictation.problemState
    extra["thread"] = .string(thread)
    extra["call_live"] = .bool(callLive)
    return .grabber(message, context: context, extra: extra)
  }

  // MARK: - which microphone (the problem report's pick, shared through NoteDictation's saved choice)

  var microphones: [BugMicrophone] { dictation.microphones }
  var selectedMicrophoneID: String? { dictation.selectedMicrophoneID }
  var microphoneName: String { dictation.selectedMicrophoneName }
  /// #531: the live level while recording, 0...1; observing it redraws only the meter.
  var inputLevel: DictationInputLevel { dictation.level }
  var listening: Bool { dictation.listening }
  /// No pick while recording or while a call owns the session (listing inputs reconfigures it).
  var canPickMicrophone: Bool { !dictation.busy && !callLive }

  func findMicrophones() {
    guard canPickMicrophone else { return }
    Task {
      await dictation.refreshMicrophones()
      // #637: a recording that began first turned this listing away; the next picker on screen names the saved one.
      if dictation.microphones.isEmpty { namedSavedMicrophone = false }
      log.event("chat_voice", ["action": "microphones", "count": dictation.microphones.count])
    }
  }

  /// A picker came on screen: after a relaunch the saved pick is only an id, so list the inputs once to name it.
  func pickerAppeared() {
    guard !namedSavedMicrophone, selectedMicrophoneID != nil, canPickMicrophone else { return }
    namedSavedMicrophone = true
    findMicrophones()
  }

  func selectMicrophone(_ id: String?) {
    guard canPickMicrophone else { return }
    dictation.selectMicrophone(id)
    log.event("chat_voice", ["action": "microphone_picked", "automatic": id == nil])
  }

  // MARK: - the button

  static let callHasMic = "A call with Larry is using the microphone. End it to speak a message."
  static let callTookMic = "A call started, so the recording stopped. The words so far are in the message."
  static let otherHasMic = "Another recording is using the microphone. Speak your message when it stops."

  /// Starts dictating into `draft` (the bar's text now), or stops a recording.
  func tap(thread: String, draft: String) {
    if dictation.listening {
      Task { await dictation.finish(why: "tap") }
      return
    }
    guard !dictation.busy else { return }
    self.thread = thread
    notice = nil
    if let holder = askMic() {
      notice = holder == .call ? Self.callHasMic : Self.otherHasMic
      log.event(
        "chat_voice", ["action": "refused", "why": holder == .call ? "call_live" : "mic_held", "by": holder.rawValue])
      return
    }
    dictation.toggle(note: draft) { [weak self] text in self?.heard(text, thread: thread) }
  }

  /// The voice button's new chat coming on screen (#637): the mic tapped for him, and during a call that tap's own
  /// refusal. A listing of the microphones (this bar's picker just asked for one) gives way rather than eat the tap.
  func startNewChat(thread: String, draft: String) {
    if !callLive, dictation.refreshingMicrophones { dictation.stop(why: "new_chat") }
    tap(thread: thread, draft: draft)
  }

  /// A recording is under way: listing the microphones alone is not one, so a Send then stops nothing.
  var recording: Bool { dictation.starting || dictation.listening || dictation.processing }

  /// Leaving the thread mid-recording stops it, so no words land in a bar that is gone.
  func cancel(thread: String, why: String) {
    guard self.thread == thread, recording else { return }
    drop(why: why)
  }

  /// A Send from this thread's bar (#546): the message took the words heard so far, so the recording stops here and
  /// nothing more comes back into the emptied bar (stop discards the recognizer's late results). A quote does the same
  /// (#629): the bar took the words so far, and a recording going on would write over the quote.
  func sent(thread: String, why: String = "sent") {
    guard self.thread == thread else { return }
    _ = words.take(thread: thread)
    guard recording else { return }
    drop(why: why)
  }

  /// The words spoken for this thread, once: the bar takes them as they come, or on its return if it was away.
  func take(thread: String) -> String? { words.take(thread: thread) }

  private func heard(_ text: String, thread: String) { words.heard(text, thread: thread) }

  private func listeningChanged(_ listening: Bool) {
    switch clock.listening(listening, at: Date()) {
    case .none: return
    case .started(let recording, let capAt):
      log.event("chat_voice", ["action": "record_start", "thread": thread])
      capTimer?.cancel()
      capTimer = Task { [weak self] in
        try? await Task.sleep(for: .seconds(capAt.timeIntervalSinceNow))
        guard !Task.isCancelled else { return }
        await self?.capped(recording: recording)
      }
    case .stopped(let seconds):
      capTimer?.cancel()
      capTimer = nil
      var fields = Self.sessionFields()
      fields["action"] = "record_stop"
      fields["thread"] = thread
      fields["seconds"] = seconds
      log.event("chat_voice", fields)
    }
  }

  /// `route_change` (#1165): only while a recording is starting or under way; never the words.
  private func routeChanged(_ note: Notification) {
    guard dictation.starting || dictation.listening else { return }
    var fields = Self.sessionFields()
    fields["action"] = "route_change"
    fields["thread"] = thread
    let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
    fields["reason"] = AudioRouting.reasonName(raw)
    if let previous = note.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
      fields["before_input"] = previous.inputs.map(Self.port)
      fields["before_output"] = previous.outputs.map(Self.port)
    }
    if let since = clock.since { fields["seconds"] = (Date().timeIntervalSince(since) * 10).rounded() / 10 }
    log.event("chat_voice", fields)
  }

  /// The audio session and the phone as they are now: the live route, what iOS offers, the category, and whether
  /// the app is on screen and the phone unlocked (a locked phone's health data is protected).
  private static func sessionFields() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let app = UIApplication.shared
    let state: String
    switch app.applicationState {
    case .active: state = "active"
    case .inactive: state = "inactive"
    case .background: state = "background"
    @unknown default: state = "unknown"
    }
    return [
      "input": session.currentRoute.inputs.map(port),
      "output": session.currentRoute.outputs.map(port),
      "inputs": (session.availableInputs ?? []).map(port),
      "category": session.category.rawValue.replacingOccurrences(of: "AVAudioSessionCategory", with: ""),
      "app_state": state,
      "protected_data": app.isProtectedDataAvailable,
    ]
  }

  /// A port as `name [type] uid`: the uid is what `dictation_start`'s input names.
  private static func port(_ port: AVAudioSessionPortDescription) -> String {
    "\(port.portName) [\(port.portType.rawValue)] \(port.uid)"
  }

  /// The five-minute limit: stopped exactly as a tap on stop would, the words settling into the draft, never sent.
  private func capped(recording: Int) async {
    guard dictation.listening, clock.shouldCap(recording: recording, at: Date()) else { return }
    log.event("chat_voice", ["action": "capped", "thread": thread, "seconds": ChatVoice.limit])
    notice = ChatVoice.cappedLine
    await dictation.finish(why: "capped")
  }

  // MARK: - the call takes the mic

  /// The floor gave the microphone to a call (CallModel.willStart, before it touches the session, or the call going
  /// live): stop dictating now, so the dictation's session restore cannot land after the call has set
  /// `.playAndRecord` / `.voiceChat`.
  func yieldToCall() {
    guard dictation.busy else { return }
    drop(why: "call_started")
    notice = Self.callTookMic
  }

  /// The button stands down while a call is live; stopping a recording for it is the floor's (`yieldToCall`).
  private func callChanged(_ live: Bool) {
    callLive = live
    if !live, notice == Self.callHasMic || notice == Self.callTookMic { notice = nil }
  }

  private func drop(why: String) {
    dictation.stop(why: why)
    log.event("chat_voice", ["action": "dropped", "thread": thread, "why": why])
  }
}
