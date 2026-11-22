//  The mic and dictation: what Igor says to the board.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

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
      MainActor.assumeIsolated { self?.micOn = on }
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
    guard !dictation.busy else { return }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live"])
      micProblem("A call with Larry is using the microphone. End it to talk to the board.", [:])
      return
    }
    if problem?.context == "WhiteboardView.mic" { problem = nil }
    speech = WhiteboardSpeech()
    lastSaid.micOpened()
    log.event("whiteboard", ["action": "mic_on", "board": board.id])
    dictation.toggle(note: "") { [weak self] text in self?.heard(text) }
  }

  /// A call taking the microphone, the board closing or the app leaving: the mic stops, and its last words still go.
  func stopMic(why: String) {
    guard micOn || micStarting else { return }
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
