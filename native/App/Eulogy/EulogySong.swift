//  Story 137 (#177): the eulogy song, played inside the app from the copy it ships with. It plays like music: the
//  session is .playback without mixing, so it pauses what else was playing, carries on with the phone locked
//  (the audio background mode), and the lock screen can pause it.

import AVFoundation
import BugKit
import MediaPlayer
import SwiftUI

@MainActor
final class EulogySongPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
  static let title = "How Igor wants to live"

  @Published private(set) var isPlaying = false
  @Published private(set) var elapsed: TimeInterval = 0
  @Published private(set) var duration: TimeInterval = 0
  /// What went wrong, copyable with its operation and the player's and session's state (#201).
  @Published private(set) var failure: BugProblem?
  /// Why the song is not playing although asked to: a live call (#197).
  @Published private(set) var waiting: String?
  /// Who holds the audio, if anyone: while it answers, the song neither plays nor touches the session.
  var heldBy: () -> String? = { nil }

  private let log: SessionLog
  private var player: AVAudioPlayer?
  private var ticker: Timer?
  private var remoteWired = false
  /// The hardware sample rate the player was prepared against: a player prepared on the car's 16 kHz hands-free
  /// line and played on a 48 kHz route ran three times too fast (#370).
  private var preparedRate: Double = 0
  /// Where the song and the wall clock were when it last started or moved, to catch its clock running away (#370).
  private var anchor: (song: TimeInterval, wall: Date)?
  private var driftLogged = false

  /// For the copyable problem's `copy_error` line.
  var bugLogger: BugLogger { log.bugLogger }

  init(log: SessionLog) {
    self.log = log
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
  }

  func play(from source: String) {
    if let holder = heldBy() {
      waiting = "The song waits until the call ends."
      log.event("eulogy_song", ["action": "play_held", "from": source, "by": holder])
      return
    }
    waiting = nil
    // The session first, so the player is prepared against the route the song plays on (#370).
    var sessionError = ""
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      sessionError = "\(error)"
      log.event("eulogy_song", ["action": "session", "ok": false, "message": sessionError])
    }
    reloadIfTheRateMoved()
    // No song to play: let the session go, so the music it paused comes back (Codex on #371).
    guard let player = loaded() else {
      release()
      return
    }
    var ok = player.play()
    var how = "play"
    if !ok {
      // A paused player can refuse; re-preparing it at the same place is the retry, and a fresh one the last.
      let at = player.currentTime
      log.event(
        "eulogy_song",
        [
          "action": "play_refused", "at": rounded(at), "prepared": player.prepareToPlay(),
          "other_audio": AVAudioSession.sharedInstance().isOtherAudioPlaying,
          "category": AVAudioSession.sharedInstance().category.rawValue,
        ])
      ok = player.play()
      how = "re_prepared"
      if !ok {
        self.player = nil
        if let fresh = loaded() {
          fresh.currentTime = at
          ok = fresh.play()
          how = "fresh_player"
        }
      }
    }
    let current = self.player ?? player
    var fields = audioFields()
    fields.merge(["action": "play", "from": source, "at": rounded(current.currentTime), "ok": ok, "how": how]) { $1 }
    log.event("eulogy_song", fields)
    failure =
      ok
      ? nil
      : problem(
        "The song would not start.", "EulogySong.play",
        ["from": source, "tries": how, "session_error": sessionError.isEmpty ? "none" : sessionError])
    sync()
    if !ok { release() }
  }

  func pause(from source: String) {
    guard let player, player.isPlaying else { return }
    player.pause()
    log.event("eulogy_song", ["action": "pause", "from": source, "at": rounded(player.currentTime)])
    sync()
  }

  /// A call is starting: pause where the song is, before the call takes the session.
  func yield(to holder: String) {
    guard let player, player.isPlaying else { return }
    player.pause()
    log.event("eulogy_song", ["action": "pause", "from": holder, "at": rounded(player.currentTime)])
    sync()
  }

  /// Lets the session go only when nothing else holds it: a call's session is the call's.
  private func release() {
    guard heldBy() == nil else { return }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func toggle(from source: String) {
    if isPlaying { pause(from: source) } else { play(from: source) }
  }

  /// Started and not back at the start: what the home screen's small player shows for (#195).
  var isStarted: Bool { isPlaying || elapsed > 0 }

  /// The scrubber let go: the song carries on from there, playing or paused as it was.
  func seek(to time: TimeInterval, from source: String) {
    guard let player = loaded() else { return }
    let was = player.currentTime
    player.currentTime = min(max(time, 0), player.duration)
    log.event(
      "eulogy_song", ["action": "seek", "from": source, "was": rounded(was), "at": rounded(player.currentTime)])
    sync()
  }

  func restart(from source: String) {
    guard let player = loaded() else { return }
    log.event("eulogy_song", ["action": "restart", "from": source, "was": rounded(player.currentTime)])
    player.currentTime = 0
    play(from: source)
  }

  /// The small player's ✕: stopped and back at the start, so it goes away.
  func stop(from source: String) {
    guard let player else { return }
    log.event("eulogy_song", ["action": "stop", "from": source, "at": rounded(player.currentTime)])
    player.stop()
    player.currentTime = 0
    sync()
    release()
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in
      player.currentTime = 0
      self.log.event("eulogy_song", ["action": "finished", "ok": flag])
      self.sync()
      self.release()
    }
  }

  @objc nonisolated private func interrupted(_ note: Notification) {
    let began =
      (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
    Task { @MainActor in
      guard let player = self.player else { return }
      self.log.event(
        "eulogy_song", ["action": began ? "interrupted" : "interruption_ended", "at": self.rounded(player.currentTime)])
      self.sync()
    }
  }

  private func loaded() -> AVAudioPlayer? {
    if let player { return player }
    // GRABBER_SONG=missing: the simulator's way to see the failure on screen (#201).
    let name = ProcessInfo.processInfo.environment["GRABBER_SONG"] == "missing" ? "no-such-song" : "eulogy-song"
    guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
      failure = problem("The song is missing from this build.", "EulogySong.load", ["file": "eulogy-song.mp3"])
      log.event("eulogy_song", ["action": "load", "ok": false, "message": "eulogy-song.mp3 not in the bundle"])
      return nil
    }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      player.prepareToPlay()
      self.player = player
      preparedRate = AVAudioSession.sharedInstance().sampleRate
      duration = player.duration
      failure = nil
      var fields = audioFields()
      fields.merge(["action": "load", "ok": true, "duration_s": rounded(player.duration)]) { $1 }
      log.event("eulogy_song", fields)
      wireRemote()
      return player
    } catch {
      failure = problem("The song would not load.", "EulogySong.load", ["error": "\(error)"])
      log.event("eulogy_song", ["action": "load", "ok": false, "message": "\(error)"])
      return nil
    }
  }

  /// A player prepared at another hardware sample rate is replaced by a fresh one at the same place (#370).
  private func reloadIfTheRateMoved() {
    guard let old = player else { return }
    let now = AVAudioSession.sharedInstance().sampleRate
    guard now != preparedRate else { return }
    let at = old.currentTime
    old.stop()
    player = nil
    log.event(
      "eulogy_song",
      ["action": "reload", "reason": "sample_rate", "was_hz": preparedRate, "now_hz": now, "at": rounded(at)])
    loaded()?.currentTime = at
  }

  /// What the song goes out through and at what rate, for the load and play events (#370).
  private func audioFields() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    return [
      "sample_rate_hz": session.sampleRate,
      "prepared_hz": preparedRate,
      "category": session.category.rawValue,
      "mode": session.mode.rawValue,
      "outputs": session.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(
        separator: ", "),
    ]
  }

  /// The failure on screen with the state around it: where the song was and what the audio session held.
  private func problem(_ message: String, _ context: String, _ extra: [String: String]) -> BugProblem {
    let session = AVAudioSession.sharedInstance()
    var state = extra.mapValues(JSONValue.string)
    state["at_s"] = .double(rounded(player?.currentTime ?? 0))
    state["duration_s"] = .double(rounded(player?.duration ?? 0))
    state["category"] = .string(session.category.rawValue)
    state["mode"] = .string(session.mode.rawValue)
    state["other_audio"] = .bool(session.isOtherAudioPlaying)
    state["outputs"] = .string(
      session.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", "))
    return .grabber(message, context: context, extra: state)
  }

  /// The lock screen and Control Center: the title, where it is, and play/pause.
  private func wireRemote() {
    guard !remoteWired else { return }
    remoteWired = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.play(from: "lock_screen") }
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.pause(from: "lock_screen") }
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      let at = event.positionTime
      Task { @MainActor in self?.seek(to: at, from: "lock_screen") }
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in self?.toggle(from: "lock_screen") }
      return .success
    }
  }

  private func sync() {
    guard let player else { return }
    isPlaying = player.isPlaying
    elapsed = player.currentTime
    anchor = player.isPlaying ? (player.currentTime, Date()) : nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: Self.title,
      MPMediaItemPropertyArtist: "Igor",
      MPMediaItemPropertyPlaybackDuration: player.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
      MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
    ]
    if isPlaying, ticker == nil {
      // .common so the clock keeps moving while a scroll is tracking.
      let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tick() }
      }
      RunLoop.main.add(timer, forMode: .common)
      ticker = timer
    } else if !isPlaying {
      ticker?.invalidate()
      ticker = nil
    }
  }

  private func tick() {
    guard let player else { return }
    elapsed = player.currentTime
    if player.isPlaying != isPlaying { sync() }
    checkDrift(player)
  }

  /// Once per launch, the song's clock against the wall clock after five seconds of playing: 1.0 is on time (#370).
  private func checkDrift(_ player: AVAudioPlayer) {
    guard !driftLogged, player.isPlaying, let anchor else { return }
    let wall = Date().timeIntervalSince(anchor.wall)
    guard wall >= 5 else { return }
    let ratio = (player.currentTime - anchor.song) / wall
    guard ratio > 1.2 || ratio < 0.8 else { return }
    driftLogged = true
    var fields = audioFields()
    fields.merge([
      "action": "rate_drift", "ratio": (ratio * 100).rounded() / 100, "wall_s": rounded(wall),
      "at": rounded(player.currentTime),
    ]) { $1 }
    log.event("eulogy_song", fields)
  }

  private nonisolated func rounded(_ t: TimeInterval) -> Double { (t * 10).rounded() / 10 }
}

/// The sheet *Eulogy song* opens: the title, play/pause, where it is, and the song on Suno.
struct EulogySongView: View {
  @ObservedObject var song: EulogySongPlayer
  let openOnSuno: () -> Void
  /// Where the finger is while dragging; the song moves when it lets go.
  @State private var scrubbing: TimeInterval?

  var body: some View {
    VStack(spacing: 20) {
      Text(EulogySongPlayer.title).font(.title2.bold()).multilineTextAlignment(.center)
      HStack(spacing: 28) {
        Button {
          song.restart(from: "sheet")
        } label: {
          Image(systemName: "backward.end.fill").font(.title)
        }
        .accessibilityIdentifier("eulogy-song-restart")
        .accessibilityLabel("Restart")
        Button {
          song.toggle(from: "sheet")
        } label: {
          Image(systemName: song.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.yellow)
        }
        .accessibilityIdentifier("eulogy-song-toggle")
        .accessibilityLabel(song.isPlaying ? "Pause" : (song.elapsed > 0 ? "Resume" : "Play"))
        // Balances the restart button so play stays centred.
        Image(systemName: "backward.end.fill").font(.title).hidden()
      }
      VStack(spacing: 4) {
        Slider(
          value: Binding(get: { scrubbing ?? song.elapsed }, set: { scrubbing = $0 }),
          in: 0...max(song.duration, 1)
        ) { editing in
          if !editing, let to = scrubbing {
            song.seek(to: to, from: "sheet")
            scrubbing = nil
          }
        }
        .tint(.yellow)
        .accessibilityIdentifier("eulogy-song-scrubber")
        HStack {
          Text(Self.clock(scrubbing ?? song.elapsed)).accessibilityIdentifier("eulogy-song-elapsed")
          Spacer()
          Text(Self.clock(song.duration))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      }
      if let waiting = song.waiting {
        Text(waiting).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("eulogy-song-waiting")
      }
      if let failure = song.failure {
        BugProblemView(problem: failure, logger: song.bugLogger).accessibilityIdentifier("eulogy-song-failure")
      }
      Button("Open on Suno", action: openOnSuno)
        .font(.footnote)
        .accessibilityIdentifier("eulogy-song-suno")
    }
    .padding(24)
    .presentationDetents([.height(340)])
  }

  static func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.down))
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}

/// #195: the song, small, in the home screen's bottom-left corner while it plays or is paused partway.
struct EulogyMiniPlayer: View {
  @ObservedObject var song: EulogySongPlayer
  let open: () -> Void

  var body: some View {
    if song.isStarted {
      HStack(spacing: 10) {
        Button(action: open) {
          HStack(spacing: 6) {
            Image(systemName: "music.note").foregroundStyle(.yellow)
            Text(EulogySongView.clock(song.elapsed)).font(.caption.monospacedDigit())
          }
        }
        .accessibilityIdentifier("eulogy-mini-open")
        .accessibilityLabel("Eulogy song, \(EulogySongView.clock(song.elapsed))")
        Button {
          song.toggle(from: "mini")
        } label: {
          Image(systemName: song.isPlaying ? "pause.fill" : "play.fill")
        }
        .accessibilityIdentifier("eulogy-mini-toggle")
        .accessibilityLabel(song.isPlaying ? "Pause" : "Resume")
        Button {
          song.stop(from: "mini")
        } label: {
          Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("eulogy-mini-stop")
        .accessibilityLabel("Stop")
      }
      .font(.title3)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.regularMaterial, in: Capsule())
      .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
  }
}
