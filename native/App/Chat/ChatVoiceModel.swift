//  Speaking a message in Chat (#448, chat spec "Speaking a message", story 303): the mic button's recorder, Deepgram
//  with the key from this phone's Keychain, and the words handed back to the thread's bar, never sent. A live call
//  owns the microphone: the button stands down, and a call that starts mid-recording drops the recording.

import AVFoundation
import BugKit
import Combine
import ContextCore
import Foundation
import Security

/// The Deepgram key, in the Keychain on this device only (the ledger key's pattern, ThinkACardUI's KeychainLedgerKey).
struct DeepgramKey {
  private let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.idvorkin.grabbernative.deepgram",
    kSecAttrAccount as String: "DEEPGRAM_API_KEY",
  ]

  func read() -> String? {
    var item: CFTypeRef?
    var lookup = query
    lookup[kSecReturnData as String] = true
    guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
      let key = String(data: data, encoding: .utf8), !key.isEmpty
    else { return nil }
    return key
  }

  /// An empty key removes it. Throws the Keychain's status when it refuses.
  func write(_ key: String) throws {
    SecItemDelete(query as CFDictionary)
    let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return }
    var item = query
    item[kSecValueData as String] = Data(key.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil)
    if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
  }
}

@MainActor
final class ChatVoiceModel: ObservableObject {
  enum Phase: Equatable {
    case idle
    case recording(since: Date)
    case transcribing
  }

  /// Words for one thread's bar, taken once (the id tells a repeat apart).
  struct Words: Equatable {
    let id: Int
    let thread: String
    let text: String
  }

  @Published private(set) var phase = Phase.idle
  @Published private(set) var hasKey: Bool
  @Published private(set) var callLive = false
  /// A short line under the bar: no key, no microphone, nothing heard, a call took the mic.
  @Published private(set) var notice: String?
  /// A failure, copyable, with the state it happened in.
  @Published private(set) var problem: BugProblem?
  @Published private(set) var words: Words?

  private let log: SessionLog
  private let keychain = DeepgramKey()
  private var recorder: AVAudioRecorder?
  /// The thread the recording is for: its words go to that bar only.
  private var thread = ""
  private var spoken = 0
  /// Between the tap and the recorder running (the permission prompt): a second tap starts nothing.
  private var starting = false
  /// The session as it was before recording, put back after, so the next sound plays as it did.
  private var before: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
  private var callWatch: AnyCancellable?
  private let file = FileManager.default.temporaryDirectory.appendingPathComponent("chat-voice.m4a")

  init(log: SessionLog, callLive: AnyPublisher<Bool, Never>) {
    self.log = log
    hasKey = DeepgramKey().read() != nil
    callWatch = callLive.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] live in
      MainActor.assumeIsolated { self?.callChanged(live) }
    }
  }

  // MARK: - the key (Settings → Voice in Chat)

  /// Saves (or, empty, removes) the key; nil on success, else what to show. Never logs the key.
  func saveKey(_ key: String) -> String? {
    do {
      try keychain.write(key)
      hasKey = keychain.read() != nil
      log.event("chat_voice", ["action": hasKey ? "key_saved" : "key_removed"])
      if hasKey, notice == Self.noKey { notice = nil }
      return nil
    } catch {
      log.event("chat_voice", ["action": "key_failed", "message": error.localizedDescription])
      return "The key could not be kept in the Keychain: \(error.localizedDescription)"
    }
  }

  // MARK: - the button

  static let noKey = "Add your Deepgram key in Settings → Voice in Chat to speak a message."
  static let callHasMic = "A call with Larry is using the microphone. End it to speak a message."

  func tap(thread: String) {
    switch phase {
    case .idle:
      guard !starting else { return }
      starting = true
      Task {
        await start(thread: thread)
        starting = false
      }
    case .recording: stop()
    case .transcribing: break
    }
  }

  /// Leaving the thread mid-recording drops it, so no words land in a bar that is gone.
  func cancel(thread: String, why: String) {
    guard self.thread == thread, case .recording = phase else { return }
    drop(why: why)
  }

  /// The words spoken for this thread, once: the bar takes them as they come, or on its return if it was away.
  func take(thread: String) -> String? {
    guard let words, words.thread == thread else { return nil }
    self.words = nil
    return words.text
  }

  private func start(thread: String) async {
    problem = nil
    notice = nil
    self.thread = thread
    guard !callLive else { return refuse(Self.callHasMic, why: "call_live") }
    guard hasKey else { return refuse(Self.noKey, why: "no_key") }
    guard await AVAudioApplication.requestRecordPermission() else {
      return refuse(
        "The microphone is off for Grabber Native. Allow it in the phone's Settings → Grabber Native.",
        why: "no_microphone")
    }
    // The call may have started while the permission was asked.
    guard !callLive, phase == .idle else { return }
    let session = AVAudioSession.sharedInstance()
    before = (session.category, session.mode, session.categoryOptions)
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
      try session.setActive(true)
      try? FileManager.default.removeItem(at: file)
      let recorder = try AVAudioRecorder(
        url: file,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
      guard recorder.record() else { throw ChatVoice.Failure(status: 0, message: "the recorder would not start") }
      self.recorder = recorder
      phase = .recording(since: Date())
      log.event("chat_voice", ["action": "record_start", "thread": thread, "route": CallAudioEngine.describeRoute()])
    } catch {
      release()
      fail("The microphone could not start: \(error.localizedDescription)", stage: "record_start", status: 0)
    }
  }

  private func stop() {
    guard case .recording(let since) = phase, let recorder else { return }
    let seconds = Date().timeIntervalSince(since)
    recorder.stop()
    self.recorder = nil
    release()
    let audio = (try? Data(contentsOf: file)) ?? Data()
    try? FileManager.default.removeItem(at: file)
    log.event(
      "chat_voice",
      ["action": "record_stop", "thread": thread, "seconds": (seconds * 10).rounded() / 10, "bytes": audio.count])
    guard !audio.isEmpty else {
      phase = .idle
      return fail("The recording came out empty.", stage: "record_stop", status: 0, seconds: seconds)
    }
    guard let key = keychain.read() else {
      phase = .idle
      hasKey = false
      return refuse(Self.noKey, why: "no_key")
    }
    phase = .transcribing
    let thread = thread
    Task { [weak self] in await self?.transcribe(audio, key: key, thread: thread, seconds: seconds) }
  }

  private func transcribe(_ audio: Data, key: String, thread: String, seconds: Double) async {
    let began = Date()
    defer { phase = .idle }
    do {
      let (body, response) = try await URLSession.shared.data(for: ChatVoice.request(audio: audio, key: key))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      let text = try ChatVoice.transcript(status: status, body: body)
      log.event(
        "chat_voice",
        [
          "action": "transcribed", "thread": thread, "status": status, "chars": text.count,
          "ms": Int(Date().timeIntervalSince(began) * 1000),
        ])
      guard !text.isEmpty else {
        notice = "Nothing heard. The message is as it was."
        return
      }
      spoken += 1
      words = Words(id: spoken, thread: thread, text: text)
    } catch let failure as ChatVoice.Failure {
      fail(failure.message, stage: "transcribe", status: failure.status, seconds: seconds, bytes: audio.count)
    } catch {
      fail(
        "The recording could not reach Deepgram: \(error.localizedDescription)", stage: "transcribe", status: 0,
        seconds: seconds, bytes: audio.count)
    }
  }

  // MARK: - the call owns the mic

  private func callChanged(_ live: Bool) {
    callLive = live
    if live, case .recording = phase {
      drop(why: "call_started")
      notice = "A call started, so the recording was dropped. The message is as it was."
    }
  }

  private func drop(why: String) {
    recorder?.stop()
    recorder = nil
    try? FileManager.default.removeItem(at: file)
    // A call that took the session keeps it: only a recording that still holds it lets go.
    if why != "call_started" { release() }
    phase = .idle
    log.event("chat_voice", ["action": "dropped", "thread": thread, "why": why])
  }

  /// Gives the session back, so paused music may resume.
  private func release() {
    defer { before = nil }
    guard !callLive else { return }
    let session = AVAudioSession.sharedInstance()
    try? session.setActive(false, options: .notifyOthersOnDeactivation)
    if let (category, mode, options) = before { try? session.setCategory(category, mode: mode, options: options) }
  }

  private func refuse(_ line: String, why: String) {
    notice = line
    log.event("chat_voice", ["action": "refused", "why": why])
  }

  private func fail(_ message: String, stage: String, status: Int, seconds: Double = 0, bytes: Int = 0) {
    log.event(
      "chat_voice",
      ["action": "failed", "thread": thread, "stage": stage, "status": status, "message": message, "bytes": bytes])
    problem = .grabber(
      message, context: "ChatThreadView.voice",
      extra: [
        "thread": .string(thread), "stage": .string(stage), "status": .int(status),
        "seconds": .double((seconds * 10).rounded() / 10), "bytes": .int(bytes), "has_key": .bool(hasKey),
      ])
  }

  func dismissProblem() {
    problem = nil
    notice = nil
  }
}
