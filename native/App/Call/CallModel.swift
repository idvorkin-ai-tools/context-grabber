//  The app's one call: owned by AppModel so it outlives the call screen, the lock and the background. Wires
//  ContextCore's CallSession to the socket, the audio engine and the clock; narrates every `call_*` event into the
//  session log and this launch's call log; remembers the backend and the voice; after a troubled call, files the
//  call's log as a BugKit automatic report, which the Mac's listener turns into an issue (story 248).

import AVFoundation
import BugKit
import ContextCore
import Security
import SwiftUI
import UIKit

@MainActor
final class CallModel: ObservableObject {
  @Published private(set) var snapshot = CallSnapshot()
  @Published private(set) var level = 0.0
  @Published private(set) var route = ""
  /// Bumped on every call event, so an open Diagnostics fold redraws.
  @Published private(set) var logVersion = 0
  @Published var backend = CallBackend.default {
    didSet { database.setSetting(Self.backendKey, backend.rawValue) }
  }
  @Published var voice = CallVoice.default {
    didSet { database.setSetting(Self.voiceKey, voice.rawValue) }
  }

  let events = CallEventLog()
  let bridgeURL: String
  private let log: SessionLog
  private let database: AppDatabase
  // Made at the end of init: its callbacks capture self.
  // swiftlint:disable:next implicitly_unwrapped_optional
  private var session: CallSession!
  /// BugKit's automatic report, set by AppModel once its reporter exists: (reason, context, files).
  var autoReport: ((String, [String: JSONValue], [URL]) -> Void)?
  /// One stable reason, so BugKit's ten-minute window holds across calls and relaunches.
  static let troubleReason = "call_trouble"

  /// The same keys as the React Native app's settings table, so the cutover keeps the picks.
  private static let backendKey = "call_backend"
  private static let voiceKey = "call_voice"
  /// What the gist (story 094, gone from this app) left behind: the token in the Keychain and the uploads' list.
  private static let gistToken = "gist_token"
  private static let gistUploads = "gist_uploads"
  static let cockpitURL = "https://c-5004.squeaker-teeth.ts.net"

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    bridgeURL =
      environment["GRABBER_CALL"].flatMap { $0.isEmpty ? nil : $0 }
      ?? CallProtocol.bridgeURL(cockpit: Self.cockpitURL) ?? ""
    backend = database.setting(Self.backendKey).flatMap(CallBackend.init(rawValue:)) ?? .default
    voice = database.setting(Self.voiceKey).flatMap(CallVoice.init(rawValue:)) ?? .default
    forgetGist()

    let audio: CallAudio
    if environment["GRABBER_CALL_AUDIO"] == "synthetic" {
      audio = SyntheticCallAudio { [weak self] type, fields in self?.event(type, fields) }
    } else {
      audio = CallAudioEngine { [weak self] type, fields in
        nonisolated(unsafe) let fields = fields
        DispatchQueue.main.async { self?.event(type, fields) }
      }
    }
    let deps = CallSessionDeps(
      connect: { url in
        guard let u = URL(string: url) else { throw CallAudioError("not a bridge address: \(url)") }
        return BridgeWebSocket(url: u)
      },
      audio: audio, scheduler: MainScheduler(),
      log: { [weak self] type, fields in self?.event(type, fields) },
      diagnostics: { [weak self] in self?.diagnosticsText() ?? "" },
      build: "\(BuildInfo.sha) (\(BuildInfo.branch))")
    session = CallSession(deps: deps, url: bridgeURL)
    session.onChange = { [weak self] snap in self?.onChange(snap) }
    session.onLevel = { [weak self] level in self?.level = level }
    route = CallAudioEngine.describeRoute()
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.route = CallAudioEngine.describeRoute() }
    }
  }

  // MARK: - the call

  /// Runs just before a call takes the audio session: the eulogy song pauses (#197).
  var willStart: (() -> Void)?

  func start(from source: String) {
    willStart?()
    log.event("ui", ["action": "call", "from": source, "backend": backend.rawValue, "voice": voice.rawValue])
    session.start(backend, voice: voice)
  }

  func hangUp(from source: String) {
    log.event("ui", ["action": "hang_up", "from": source])
    session.stop()
  }

  func restart() {
    log.event("ui", ["action": "restart_call"])
    session.restart()
  }

  func toggleMute() { session.setMuted(!snapshot.muted) }

  /// The status line: `calling Larry… · ElevenLabs · Igor`, `live · 1:17 · ElevenLabs`, `ended — stopped`.
  func status(now: Date) -> String {
    let b = snapshot.backend ?? backend
    let label = CallVoice.hasPick(b) ? "\(b.label) · \(snapshot.voice.label)" : b.label
    switch snapshot.state {
    case .connecting: return "calling Larry… · \(label)"
    case .live:
      let s = max(0, Int((now.timeIntervalSince1970 * 1000 - (snapshot.startedAt ?? 0)) / 1000))
      return "live · \(s / 60):\(String(format: "%02d", s % 60)) · \(label)"
    case .ended: return "ended — \(CallProtocol.endingText(snapshot.endedReason))"
    case .idle: return ""
    }
  }

  private func onChange(_ snap: CallSnapshot) {
    let was = snapshot.state
    snapshot = snap
    route = CallAudioEngine.describeRoute()
    if snap.state == .ended, was != .ended { onEnded() }
  }

  /// After a troubled call, on its own: the call's log as a BugKit automatic report (story 248). The trigger is what
  /// the log says; BugKit keeps it to one per ten minutes and the log within 5 MB.
  private func onEnded() {
    guard CallEventLog.hadTrouble(events.currentCall), let autoReport else { return }
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("call-log.txt")
    do {
      try Data(diagnosticsText().utf8).write(to: file, options: .atomic)
    } catch {
      log.event("error", ["where": "call_report", "message": "\(error)"])
      return
    }
    autoReport(
      Self.troubleReason,
      [
        "ended": .string(snapshot.endedReason ?? ""), "problem": .string(snapshot.problem ?? ""),
        "backend": .string(snapshot.backend?.rawValue ?? ""), "voice": .string(snapshot.voice.rawValue),
      ],
      [file])
  }

  /// The gist is gone (2026-10-11): its token leaves the Keychain and its list of uploads leaves the settings, once.
  private func forgetGist() {
    let token: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.idvorkin.grabbernative",
      kSecAttrAccount as String: Self.gistToken,
    ]
    if SecItemDelete(token as CFDictionary) == errSecSuccess { log.event("call_gist", ["action": "token_removed"]) }
    if let list = database.setting(Self.gistUploads), !list.isEmpty { database.setSetting(Self.gistUploads, "") }
  }

  // MARK: - the log

  private func event(_ type: String, _ fields: [String: Any]) {
    log.event(type, fields)
    events.add(type, t: Int(Date().timeIntervalSince(log.startedAt) * 1000), fields: fields)
    logVersion += 1
  }

  private func header() -> [(String, String)] {
    [
      ("build", "\(BuildInfo.sha) (\(BuildInfo.branch))"), ("state", snapshot.state.rawValue),
      ("backend", snapshot.backend?.rawValue ?? ""), ("voice", snapshot.voice.rawValue),
      ("ended", snapshot.endedReason ?? ""), ("problem", snapshot.problem ?? ""), ("route", route),
      ("bridge", bridgeURL), ("session log", log.url.lastPathComponent),
    ]
  }

  func diagnosticsText() -> String { events.render(header: header()) }

  func copyDiagnostics() {
    UIPasteboard.general.string = diagnosticsText()
    log.event("ui", ["action": "copy_diagnostics", "events": events.events.count])
  }
}
