import XCTest

@testable import ContextCore

/// #802: the audio floor's rule table, one test per rule, named for the line it was transcribed from (as of
/// 7e64571e). These pin what the app did before the table existed, gaps included: a failing test here is a change in
/// behaviour, which needs a story first.
final class AudioFloorTests: XCTestCase {
  private let everyone = Set(AudioUser.allCases)

  private func decide(_ ask: AudioAsk, _ holding: Set<AudioUser>) -> [AudioDecision] {
    AudioFloor.decide(ask, holding: holding)
  }

  // MARK: the timer gives way (story 191)

  /// AppModel.swift:767 openCall.
  func testCallScreenOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.callScreenOpens, [.timer]), [.yield(.timer, to: "call")])
  }

  /// AppModel.swift:503 openBreathe.
  func testBreatheOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.breatheOpens, [.timer]), [.yield(.timer, to: "breathe")])
  }

  /// AppModel.swift:644 playEulogySong (34902620).
  func testSongTilePausesTheTimer() {
    XCTAssertEqual(decide(.songOpens, [.timer]), [.yield(.timer, to: "eulogy_song")])
  }

  /// AppModel.swift:718 openCockpit (34902620).
  func testCockpitOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.cockpitOpens, [.timer]), [.yield(.timer, to: "cockpit")])
  }

  /// AppModel.swift:644 then EulogySong.swift:47: the tile's yield comes before the play's own check, so during a
  /// call the song's tile pauses a running workout and then the song waits.
  func testSongTileDuringACallStillPausesTheTimerThenTheSongWaits() {
    XCTAssertEqual(decide(.songOpens, [.timer, .call]), [.yield(.timer, to: "eulogy_song")])
    XCTAssertEqual(decide(.songPlays, [.timer, .call]), [.refuse(by: .call)])
  }

  // MARK: a call takes the session

  /// AppModel.swift:184 and :186 call.willStart: the song (#197), then chat's dictation (#448), in that order.
  func testCallStartingPausesTheSongThenStopsChatDictation() {
    XCTAssertEqual(
      decide(.callStarts, [.song, .chatVoice]), [.yield(.song, to: "call"), .yield(.chatVoice, to: "call")])
  }

  /// ChatVoiceModel.swift:207 callChanged and WhiteboardView.swift:1133: each watches the call for itself.
  func testCallGoingLiveStopsChatDictationAndTheWhiteboardMic() {
    XCTAssertEqual(
      decide(.callWentLive, [.chatVoice, .whiteboardMic]),
      [.yield(.chatVoice, to: "call"), .yield(.whiteboardMic, to: "call")])
  }

  // MARK: a live call refuses

  /// AppModel.swift:82 song.heldBy, EulogySong.swift:47 (#197); the same answer guards EulogySong.swift:122.
  func testSongWaitsForACall() {
    XCTAssertEqual(decide(.songPlays, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.songPlays, []), [])
    XCTAssertEqual(AudioUser.call.rawValue, "call", "the song's play_held line logs it as `by`")
  }

  /// AppModel.swift:566 mayTheCardSpeak (#219): silent, and the song is left alone.
  func testCardIsSilentDuringACall() {
    XCTAssertEqual(decide(.cardSpeaks, [.call, .song]), [.refuse(by: .call)])
  }

  /// AppModel.swift:567 mayTheCardSpeak (#219).
  func testCardSpeakingPausesTheSong() {
    XCTAssertEqual(decide(.cardSpeaks, [.song]), [.yield(.song, to: "card")])
  }

  /// ChatVoiceModel.swift:132 tap (#448).
  func testChatDictationRefusedDuringACall() {
    XCTAssertEqual(decide(.chatVoiceTap, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.chatVoiceTap, []), [])
  }

  /// WhiteboardView.swift:526 tapMic.
  func testWhiteboardMicRefusedDuringACall() {
    XCTAssertEqual(decide(.whiteboardMicTap, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.whiteboardMicTap, []), [])
  }

  /// AppModel.swift:454 microphoneBusy: a call (#239), or a chat recording (#559).
  func testReportDictationRefusedByACallOrAChatRecording() {
    XCTAssertEqual(decide(.reportDictation, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.reportDictation, [.chatVoice]), [.refuse(by: .chatVoice)])
    XCTAssertEqual(decide(.reportDictation, [.call, .chatVoice]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.reportDictation, [.timer, .song, .breathe]), [])
  }

  /// AppModel.swift:694 resetAudio, DiagnosticsView.swift:472 (story 149).
  func testResetAudioRefusedDuringACall() {
    XCTAssertEqual(decide(.audioReset, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.audioReset, everyone.subtracting([.call])), [])
  }

  // MARK: today's gaps

  /// #802 open question for Igor: should the timer/breathing refuse during a call?
  /// Today nothing checks: GymAudio.swift:187 and BreatheAudio.swift:189 set `.playback` on the session a live call
  /// holds as `.playAndRecord` / `.voiceChat`, and the call is not told.
  func testTimerStartAndBreathingDuringACallAreNotArbitrated() {
    XCTAssertEqual(decide(.timerStarts, [.call]), [])
    XCTAssertEqual(decide(.breatheStarts, [.call]), [])
    XCTAssertEqual(decide(.breatheOpens, [.call]), [.yield(.timer, to: "breathe")])
    XCTAssertEqual(decide(.timerStarts, everyone), [])
    XCTAssertEqual(decide(.breatheStarts, everyone), [])
  }

  /// Nothing else gives way either: a call starting leaves a workout started since, or a breathing session, alone;
  /// the song plays over breathing and the Cockpit.
  func testPairsWithNoRuleCoexist() {
    XCTAssertFalse(decide(.callStarts, everyone).contains(.yield(.timer, to: "call")))
    XCTAssertFalse(decide(.callStarts, everyone).contains(.yield(.breathe, to: "call")))
    XCTAssertEqual(decide(.songPlays, everyone.subtracting([.call])), [])
  }

  // MARK: the whole table

  /// Every ask with everyone holding: a rule added, dropped or reordered shows here.
  func testEveryAskWithEveryoneHolding() {
    let expected: [AudioAsk: [AudioDecision]] = [
      .callScreenOpens: [.yield(.timer, to: "call")],
      .callStarts: [.yield(.song, to: "call"), .yield(.chatVoice, to: "call")],
      .callWentLive: [.yield(.chatVoice, to: "call"), .yield(.whiteboardMic, to: "call")],
      .timerStarts: [],
      .breatheOpens: [.yield(.timer, to: "breathe")],
      .breatheStarts: [],
      .songOpens: [.yield(.timer, to: "eulogy_song")],
      .songPlays: [.refuse(by: .call)],
      .cardSpeaks: [.refuse(by: .call)],
      .chatVoiceTap: [.refuse(by: .call)],
      .reportDictation: [.refuse(by: .call)],
      .whiteboardMicTap: [.refuse(by: .call)],
      .cockpitOpens: [.yield(.timer, to: "cockpit")],
      .audioReset: [.refuse(by: .call)],
    ]
    XCTAssertEqual(Set(expected.keys), Set(AudioAsk.allCases))
    for ask in AudioAsk.allCases {
      XCTAssertEqual(decide(ask, everyone), expected[ask], ask.rawValue)
    }
    XCTAssertEqual(AudioFloor.rules.count, 16)
    XCTAssertTrue(AudioFloor.rules.allSatisfy { !$0.source.isEmpty })
  }

  /// A yield is asked of the holder whoever has the session: GymTimerModel.yield, EulogySongPlayer.yield and
  /// ChatVoiceModel.yieldToCall each return at once when they are not sounding, as the pairwise lines relied on.
  func testYieldsAreAskedWhetherOrNotTheHolderIsKnownToHold() {
    XCTAssertEqual(decide(.breatheOpens, []), [.yield(.timer, to: "breathe")])
    XCTAssertEqual(decide(.callStarts, []), [.yield(.song, to: "call"), .yield(.chatVoice, to: "call")])
  }

  /// AppModel answers `isHolding` for these two only (AppModel.swift:454 read `call.snapshot.isActive ||
  /// chatVoice.recording`), and the second is not read when the first is true or when the ask has no rule for it.
  func testOnlyRefusingHoldersAreAskedAboutInOrder() {
    XCTAssertEqual(AudioFloor.refusers, [.call, .chatVoice])
    var asked: [AudioUser] = []
    _ = AudioFloor.decide(.reportDictation) {
      asked.append($0)
      return true
    }
    XCTAssertEqual(asked, [.call])
    asked = []
    _ = AudioFloor.decide(.reportDictation) {
      asked.append($0)
      return false
    }
    XCTAssertEqual(asked, [.call, .chatVoice])
    for ask in AudioAsk.allCases where ask != .reportDictation {
      asked = []
      _ = AudioFloor.decide(ask) {
        asked.append($0)
        return false
      }
      XCTAssertTrue(asked.allSatisfy { $0 == .call }, ask.rawValue)
    }
  }

  /// The asks AppModel never makes: their classes check for themselves, as before the table.
  func testRulesTheirOwnClassesEnforce() {
    let own = Set(AudioFloor.rules.filter { $0.enforcedBy == .itsOwnClass }.map(\.ask))
    XCTAssertEqual(own, [.callWentLive, .chatVoiceTap, .whiteboardMicTap])
    let appModel = Set(AudioFloor.rules.filter { $0.enforcedBy == .appModel }.map(\.ask))
    XCTAssertTrue(own.isDisjoint(with: appModel))
  }
}
