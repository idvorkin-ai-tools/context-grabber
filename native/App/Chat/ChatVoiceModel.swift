//  Speaking a message in Chat (#448, chat spec "Speaking a message", story 303): the thread's mic is BugKit's
//  NoteDictation, the problem report's Apple dictation (Igor, 2026-10-26: "All right, use that."). The words stream
//  into that thread's bar as he speaks, after what was typed, never sent. A live call owns the microphone: the button
//  stands down, and a call that starts mid-recording stops it. A recording stops itself at ChatVoice.limit.

import BugKit
import Combine
import ContextCore
import Foundation

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

  /// The whole draft for one thread's bar — what was typed, then the words so far — taken once (the id tells a
  /// repeat apart).
  struct Words: Equatable {
    let id: Int
    let thread: String
    let text: String
  }

  @Published private(set) var callLive = false
  /// A short line under the bar: a call has the mic, a call took it, the five-minute stop.
  @Published private(set) var notice: String?
  @Published private(set) var words: Words?
  /// The thread the last tap was in: its words, `notice` and `problem` show in that thread's bar only.
  @Published private(set) var thread = ""

  private let log: SessionLog
  private lazy var dictation = NoteDictation(
    logger: log.bugLogger, hostMicrophoneBusy: { [weak self] in self?.callLive ?? false })
  private var since: Date?
  private var spoken = 0
  private var capTimer: Task<Void, Never>?
  private var watches: Set<AnyCancellable> = []

  init(log: SessionLog, callLive: AnyPublisher<Bool, Never>) {
    self.log = log
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
  }

  var phase: Phase {
    if dictation.listening { return .recording(since: since ?? Date()) }
    if dictation.starting { return .starting }
    if dictation.processing { return .finishing }
    return .idle
  }

  /// What the dictation could not do (a permission off, the recognizer stopping, an interruption), copyable.
  var problem: BugProblem? {
    guard let message = dictation.problem else { return nil }
    var extra = dictation.problemState
    extra["thread"] = .string(thread)
    extra["call_live"] = .bool(callLive)
    return .grabber(message, context: "ChatThreadView.voice", extra: extra)
  }

  // MARK: - which microphone (the problem report's pick, shared through NoteDictation's saved choice)

  var microphones: [BugMicrophone] { dictation.microphones }
  var selectedMicrophoneID: String? { dictation.selectedMicrophoneID }
  var microphoneName: String { dictation.selectedMicrophoneName }
  /// No pick while recording or while a call owns the session (listing inputs reconfigures it).
  var canPickMicrophone: Bool { !dictation.busy && !callLive }

  func findMicrophones() {
    guard canPickMicrophone else { return }
    Task {
      await dictation.refreshMicrophones()
      log.event("chat_voice", ["action": "microphones", "count": dictation.microphones.count])
    }
  }

  func selectMicrophone(_ id: String?) {
    guard canPickMicrophone else { return }
    dictation.selectMicrophone(id)
    log.event("chat_voice", ["action": "microphone_picked", "automatic": id == nil])
  }

  // MARK: - the button

  static let callHasMic = "A call with Larry is using the microphone. End it to speak a message."
  static let callTookMic = "A call started, so the recording stopped. The words so far are in the message."

  /// Starts dictating into `draft` (the bar's text now), or stops a recording.
  func tap(thread: String, draft: String) {
    if dictation.listening {
      Task { await dictation.finish(why: "tap") }
      return
    }
    guard !dictation.busy else { return }
    self.thread = thread
    notice = nil
    guard !callLive else {
      notice = Self.callHasMic
      log.event("chat_voice", ["action": "refused", "why": "call_live"])
      return
    }
    dictation.toggle(note: draft) { [weak self] text in self?.heard(text, thread: thread) }
  }

  /// Leaving the thread mid-recording stops it, so no words land in a bar that is gone.
  func cancel(thread: String, why: String) {
    guard self.thread == thread, dictation.busy else { return }
    drop(why: why)
  }

  /// The words spoken for this thread, once: the bar takes them as they come, or on its return if it was away.
  func take(thread: String) -> String? {
    guard let words, words.thread == thread else { return nil }
    self.words = nil
    return words.text
  }

  private func heard(_ text: String, thread: String) {
    spoken += 1
    words = Words(id: spoken, thread: thread, text: text)
  }

  private func listeningChanged(_ listening: Bool) {
    capTimer?.cancel()
    capTimer = nil
    if listening {
      let started = Date()
      since = started
      log.event("chat_voice", ["action": "record_start", "thread": thread])
      capTimer = Task { [weak self] in
        try? await Task.sleep(for: .seconds(ChatVoice.limit))
        guard !Task.isCancelled else { return }
        await self?.capped(since: started)
      }
    } else if let started = since {
      since = nil
      let seconds = (Date().timeIntervalSince(started) * 10).rounded() / 10
      log.event("chat_voice", ["action": "record_stop", "thread": thread, "seconds": seconds])
    }
  }

  /// The five-minute limit: stopped exactly as a tap on stop would, the words settling into the draft, never sent.
  private func capped(since started: Date) async {
    guard dictation.listening, since == started else { return }
    log.event("chat_voice", ["action": "capped", "thread": thread, "seconds": ChatVoice.limit])
    notice = ChatVoice.cappedLine
    await dictation.finish(why: "capped")
  }

  // MARK: - the call owns the mic

  /// A call is about to start (CallModel.willStart, before it touches the session): stop dictating now, so the
  /// dictation's session restore cannot land after the call has set `.playAndRecord` / `.voiceChat`.
  func yieldToCall() {
    guard dictation.busy else { return }
    drop(why: "call_started")
    notice = Self.callTookMic
  }

  private func callChanged(_ live: Bool) {
    callLive = live
    if !live, notice == Self.callHasMic || notice == Self.callTookMic { notice = nil }
    if live, dictation.busy {
      drop(why: "call_started")
      notice = Self.callTookMic
    }
  }

  private func drop(why: String) {
    dictation.stop(why: why)
    log.event("chat_voice", ["action": "dropped", "thread": thread, "why": why])
  }
}
