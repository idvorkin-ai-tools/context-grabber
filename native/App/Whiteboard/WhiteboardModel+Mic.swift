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
        // Story 1112: a mic that stops by itself is closed too.
        if !on { self?.micClock.closed(t: Self.micNowMs) }
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
    guard !dictation.busy, !micOpening else {
      // Story 926: a tap while Find microphones reads them does nothing; the log says why.
      if dictation.refreshingMicrophones {
        log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "listing"])
      }
      return
    }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live"])
      micProblem("A call with Larry is using the microphone. End it to talk to the board.", [:])
      return
    }
    if problem?.context == "WhiteboardView.mic" { problem = nil }
    log.event("whiteboard", ["action": "mic_on", "board": board.id])
    micClock.opened(t: Self.micNowMs)
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
    guard id != dictation.selectedMicrophoneID, !micOpening, !dictation.refreshingMicrophones else { return }
    let open = micOn
    log.event("whiteboard", ["action": "mic_picked", "board": board.id, "automatic": id == nil, "mic_open": open])
    guard open else {
      dictation.selectMicrophone(id)
      return
    }
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": "switch_mic"])
    micClock.closed(t: Self.micNowMs)
    micOpening = true
    Task {
      await dictation.finish(why: "switch_mic")
      // Story 1281: listening goes on, so what was heard waits for the next picture instead of going now.
      gatherSpoken(why: "switch_mic")
      dictation.selectMicrophone(id)
      guard micOpening else { return }
      log.event(
        "whiteboard",
        ["action": "mic_on", "board": board.id, "why": "switch_mic", "picked": dictation.selectedMicrophoneID == id])
      micClock.opened(t: Self.micNowMs)
      openMic(listing: false)
    }
  }

  /// Stories 1103, 926: the microphone rows, in the note's line and under Talk's long press, from what the dictation
  /// has read and the kept pick.
  var micMenu: BoardMicMenu {
    dictation.boardMicMenu(micOpen: micOn || micStarting, busy: dictation.busy || micOpening)
  }

  /// Story 926: *Find microphones* under Talk's long press, with the mic closed, reads the connected ones so the next
  /// long press lists them. Never while a call holds the microphone (reading them reconfigures the audio session).
  func findMicrophones() {
    guard micMenu.canFind else { return }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live", "finding": true])
      return
    }
    Task { [weak self] in
      guard let self else { return }
      await dictation.refreshMicrophones()
      log.event(
        "whiteboard",
        [
          "action": "mic_inputs", "board": board.id, "count": dictation.microphones.count,
          "automatic": dictation.selectedMicrophoneID == nil, "why": callLive() ? "find_skipped" : "find",
        ])
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
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": why])
    micClock.closed(t: Self.micNowMs)
    Task {
      await dictation.finish(why: why)
      spoke()
    }
  }

  /// Story 1281: the mic listens continuously and silence never sends. What it hears shows live in the note and waits
  /// for the next picture (the Pencil's pause, *Send to Larry*, closing the mic). A callback that only repeats them
  /// changes nothing.
  private func heard(_ text: String) {
    let changed = speech.heard(text)
    lastSaid.heard(text)
    guard changed else { return }
    micClock.heard(t: Self.micNowMs)
  }

  /// Story 1281: the words heard and not yet taken join the ones waiting for the next picture, asking nothing. `why`
  /// is what took them: `pause`, `send`, `switch_mic`. On a Larry board's *Send* (`toLarry`) they wait with his turn,
  /// so the tap sends them even when he already has the drawing.
  func gatherSpoken(why: String, toLarry: Bool = false) {
    var words = speech.takeNew()
    if toLarry {
      let waiting = turns.takeSaid()
      let both = [waiting, words].compactMap { $0 }.joined(separator: " ")
      words = both.isEmpty ? nil : both
      larry.heard(words)
    } else if let new = words, !turns.heard(new) {
      logSpoke(new, went: "ghosts_off", end: why)
      return
    }
    guard let words else { return }
    logSpoke(words, went: "waiting", end: why)
  }

  /// The words are taken by `why` (story 1112: the mic's timing goes with the next picture unless they were dropped).
  private func logSpoke(_ words: String, went: String, end: String) {
    var event: [String: Any] = [
      "action": "spoke", "board": board.id, "chars": words.count, "went": went, "end": end,
    ]
    let timing = micClock.taken(t: Self.micNowMs, chars: words.count, kept: went != "ghosts_off")
    event.merge(timing?.gaps ?? [:]) { $1 }
    log.event("whiteboard", event)
  }

  /// Closing the mic (or the say hook): the new words and those already waiting go now, or with the next turn if one
  /// is on its way. Discards them if the pause switch is off.
  private func spoke() {
    let words = speech.takeNew()
    let went = turns.spoke(words)
    if let words { logSpoke(words, went: went.rawValue, end: "closed") }
    guard went == .now else { return }
    // This turn's picture has the strokes a waiting pause would ask about.
    cancelPause()
    Task { await turn(.claude) }
  }
}

extension NoteDictation {
  /// Stories 1103, 926: the board's microphone rows from what this dictation has read and its kept pick.
  func boardMicMenu(micOpen: Bool, busy: Bool) -> BoardMicMenu {
    BoardMicMenu(
      microphones: microphones.map { BoardMicMenu.Microphone(id: $0.id, name: $0.name) }, picked: selectedMicrophoneID,
      savedName: selectedMicrophoneName, micOpen: micOpen, busy: busy)
  }
}
