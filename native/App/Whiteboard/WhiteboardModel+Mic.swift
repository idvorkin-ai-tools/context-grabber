//  The mic and dictation: what Igor says to the board.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import AVFoundation
import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  func makeDictation() -> NoteDictation {
    let dictation = NoteDictation(
      logger: log.bugLogger, hostMicrophoneBusy: { [weak self] in self?.callLive() ?? false })
    dictation.$listening.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated {
        self?.micOn = on
        self?.hearing(on ? "listening" : nil)
      }
    }
    .store(in: &dictationWatches)
    // Story 1103: a microphone plugged in, paired or pulled while the mic is open changes what it hears.
    NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, self.micOn else { return }
          self.hearing("route_change")
        }
      }
      .store(in: &dictationWatches)
    dictation.$starting.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micStarting = on }
    }
    .store(in: &dictationWatches)
    dictation.$processing.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micFinishing = on }
    }
    .store(in: &dictationWatches)
    dictation.$problem.combineLatest(dictation.$problemState).sink { [weak self] message, state in
      MainActor.assumeIsolated {
        guard let self, let message else { return }
        self.micProblem(message, state)
      }
    }
    .store(in: &dictationWatches)
    return dictation
  }

  private func micProblem(_ message: String, _ state: [String: JSONValue]) {
    let extra = state.merging(["board": .string(board.id), "call_live": .bool(callLive())]) { _, new in new }
    problem = .grabber(message, context: "WhiteboardView.mic", extra: extra)
  }

  /// Opens the board's mic, or closes it and sends what's still unsent.
  func tapMic() {
    // #824: with Ghosts off the words would reach no one, so the mic (and its hook) doesn't take them.
    if !micOn, !turns.micMayOpen() {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "ghosts_off"])
      return
    }
    if let words = LaunchHooks.current.whiteboard.say {
      speech.heard(words)
      spoke()
      return
    }
    if micOn {
      stopMic(why: "tap")
      return
    }
    guard !dictation.busy, !micOpening else { return }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live"])
      micProblem("A call with Larry is using the microphone. End it to talk to the board.", [:])
      return
    }
    if problem?.context == "WhiteboardView.mic" { problem = nil }
    log.event("whiteboard", ["action": "mic_on", "board": board.id])
    openMic(listing: true)
  }

  /// Opens the mic on the picked microphone. Story 1103: with `listing`, the connected microphones are read first, so
  /// one plugged in or paired since the last opening is in the picker (reading them waits while a call holds the mic).
  private func openMic(listing: Bool) {
    micOpening = true
    Task { [weak self] in
      guard let self else { return }
      if listing {
        await dictation.refreshMicrophones()
        log.event(
          "whiteboard",
          [
            "action": "mic_inputs", "board": board.id, "count": dictation.microphones.count,
            "automatic": dictation.selectedMicrophoneID == nil,
          ])
      }
      // Closed meanwhile (the board left, a call, Ghosts off): it doesn't open.
      guard micOpening else { return }
      micOpening = false
      let refused = !turns.micMayOpen() ? "ghosts_off" : callLive() ? "call_live" : nil
      if let refused {
        log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": refused, "opening": true])
        return
      }
      speech = WhiteboardSpeech()
      lastSaid.micOpened()
      dictation.toggle(note: "") { [weak self] text in self?.heard(text) }
    }
  }

  /// Story 1103: what the open mic hears, by name (with Automatic, the system's pick), or nil once it closes.
  private func hearing(_ why: String?) {
    guard let why else {
      micHears = nil
      return
    }
    let input = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName
    guard input != micHears else { return }
    micHears = input
    log.event(
      "whiteboard",
      [
        "action": "mic_hears", "board": board.id, "input": input ?? "none", "why": why,
        "automatic": dictation.selectedMicrophoneID == nil,
      ])
  }

  /// Story 1103 (#1139): another microphone picked in the note's line. Closed, the next opening uses it; open, the mic
  /// closes (its words so far still go) and opens again on it.
  func pickMicrophone(_ id: String?) {
    guard id != dictation.selectedMicrophoneID, !micOpening else { return }
    let open = micOn
    log.event("whiteboard", ["action": "mic_picked", "board": board.id, "automatic": id == nil, "mic_open": open])
    guard open else {
      dictation.selectMicrophone(id)
      return
    }
    silenceTask?.cancel()
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": "switch_mic"])
    micOpening = true
    Task {
      await dictation.finish(why: "switch_mic")
      spoke()
      dictation.selectMicrophone(id)
      guard micOpening else { return }
      log.event(
        "whiteboard",
        ["action": "mic_on", "board": board.id, "why": "switch_mic", "picked": dictation.selectedMicrophoneID == id])
      openMic(listing: false)
    }
  }

  /// A call taking the microphone, the board closing or the app leaving: the mic stops, and its last words still go.
  func stopMic(why: String) {
    // Story 1103: an opening on its way doesn't happen.
    let opening = micOpening
    micOpening = false
    guard micOn || micStarting else {
      if opening { log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": why, "opening": true]) }
      return
    }
    silenceTask?.cancel()
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": why])
    Task {
      await dictation.finish(why: why)
      spoke()
    }
  }

  private func heard(_ text: String) {
    speech.heard(text)
    lastSaid.heard(text)
    silenceTask?.cancel()
    silenceTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.spoke()
    }
  }

  /// He stopped talking: the new words go now, or with the next turn if one is on its way. With Ghosts off nothing is
  /// asked, and they aren't kept for later.
  private func spoke() {
    guard let words = speech.takeNew() else { return }
    let went = turns.spoke(words)
    log.event("whiteboard", ["action": "spoke", "board": board.id, "chars": words.count, "went": went.rawValue])
    guard went == .now else { return }
    // This turn's picture has the strokes a waiting pause would ask about.
    cancelPause()
    Task { await turn(.claude) }
  }
}
