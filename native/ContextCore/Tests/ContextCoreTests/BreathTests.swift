import XCTest

@testable import ContextCore

final class BreathPlanTests: XCTestCase {
  func testTheSessionIsTheWholeCyclesClosestToTheTimeChosen() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.cycles, 9)
    XCTAssertEqual(plan.totalSeconds, 288)
    XCTAssertEqual(plan.summary, "9 cycles · ends at 4 min 48 s")
    XCTAssertEqual(plan.doneText, "4 min 48 s · 9 cycles")
  }

  func testChangingBreathLengthChangesTheSummary() {
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 5).summary, "5 cycles · ends at 5 min 0 s")
  }

  func testNeverLessThanOneCycleAtAnySetting() {
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 2).cycles, 2)
    for breath in BreathPlan.breathRange {
      for session in BreathPlan.sessionRange {
        XCTAssertGreaterThanOrEqual(BreathPlan(breathSeconds: breath, sessionMinutes: session).cycles, 1)
      }
    }
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 10).cycles, 30)
    XCTAssertEqual(BreathPlan.sessionRange, 2...15)
  }

  func testTheLongestSessionIsFifteenMinutes() {
    XCTAssertEqual(BreathPlan(breathSeconds: 8, sessionMinutes: 15).summary, "28 cycles · ends at 14 min 56 s")
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).cycles, 45)
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).totalSeconds, 900)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 15).cycles, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).moment(at: 0).timeLeftText, "15:00 left")
  }

  func testTheSlidersStopAtTheirEnds() {
    XCTAssertEqual(BreathPlan(breathSeconds: 1, sessionMinutes: 5).breathSeconds, 5)
    XCTAssertEqual(BreathPlan(breathSeconds: 99, sessionMinutes: 5).breathSeconds, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 99).cycles, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 0).cycles, 2)
    XCTAssertEqual(BreathPlan(breathSeconds: 8, cycles: 1).summary, "1 cycle · ends at 0 min 32 s")
  }

  func testEachSideOfTheBoxLastsTheBreathLength() {
    let plan = BreathPlan(breathSeconds: 10, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 9.99).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 10).phase, .holdFull)
    XCTAssertEqual(plan.moment(at: 20).phase, .exhale)
    XCTAssertEqual(plan.moment(at: 30).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 40).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 40).cycle, 2)
  }

  func testTheRingDrawsOnTheInhaleStaysOnTheHoldAndUndrawsOnTheExhale() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).ring, 0)
    XCTAssertEqual(plan.moment(at: 4).ring, 0.5, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 12).ring, 1)
    XCTAssertEqual(plan.moment(at: 20).ring, 0.5, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 28).ring, 0)
    XCTAssertEqual(plan.moment(at: 12).phaseProgress, 0.5, accuracy: 1e-9)  // the hold bar, halfway
  }

  func testTheCircleGrowsFromNinetyToAHundredPercentAndBackEased() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).scale, 0.9, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 4).scale, 0.95, accuracy: 1e-9)
    XCTAssertLessThan(plan.moment(at: 1).scale, 0.9 + 0.1 / 8)  // slow at the start: eased, not linear
    XCTAssertEqual(plan.moment(at: 10).scale, 1)
    XCTAssertEqual(plan.moment(at: 20).scale, 0.95, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 30).scale, 0.9, accuracy: 1e-9)
  }

  /// #281: the time and the cycles left, counting the one under way.
  func testLeftCountsTimeAndCycles() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)  // 9 cycles of 32 s
    XCTAssertEqual(plan.cycles, 9)
    XCTAssertEqual(plan.moment(at: 0).leftText, "4:48 left · 9 cycles")
    XCTAssertEqual(plan.moment(at: 17).leftText, "4:31 left · 9 cycles")
    XCTAssertEqual(plan.moment(at: 70).leftText, "3:38 left · 7 cycles")
    XCTAssertEqual(plan.moment(at: 287.5).leftText, "0:01 left · 1 cycle")
    XCTAssertEqual(plan.moment(at: 400).leftText, "0:00 left · 0 cycles")
  }

  func testTimeLeftCountsDown() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 17).timeLeftText, "4:31 left")
    XCTAssertEqual(plan.moment(at: 0).timeLeftText, "4:48 left")
    XCTAssertEqual(plan.moment(at: 287.5).timeLeftText, "0:01 left")
  }

  func testTheSessionEndsAfterTheLastHold() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertFalse(plan.moment(at: 287.99).done)
    XCTAssertEqual(plan.moment(at: 287.99).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 287.99).cycle, 9)
    XCTAssertTrue(plan.moment(at: 288).done)
    XCTAssertEqual(plan.moment(at: 500).secondsLeft, 0)
  }

  func testTheWordsOnScreenAndTheCueLabels() {
    XCTAssertEqual(BreathPhase.allCases.map(\.word), ["Inhale", "Hold", "Exhale", "Hold"])
    XCTAssertEqual(BreathCue.allCases.map(\.label), ["Voice", "Tone", "Off"])
  }
}

final class BreathRunTests: XCTestCase {
  /// Looks every 50 ms from `from` to `to`, collecting effects with the second they fell in.
  private func look(_ run: inout BreathRun, from: Double, to: Double) -> [String] {
    var out: [String] = []
    var now = from
    while now <= to + 0.001 {
      for effect in run.tick(now: now) {
        switch effect {
        case .phase(let phase, let cycle, _): out.append("\(Int(now - from + 0.001)):\(phase.word)#\(cycle)")
        case .finished: out.append("\(Int(now - from + 0.001)):done")
        }
      }
      now += 0.05
    }
    return out
  }

  func testEveryPhaseIsCalledOnItsSecondAndTheSessionFinishesOnce() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 2))
    run.start(now: 100)
    XCTAssertEqual(
      look(&run, from: 100, to: 45 + 100),
      [
        "0:Inhale#1", "5:Hold#1", "10:Exhale#1", "15:Hold#1", "20:Inhale#2", "25:Hold#2", "30:Exhale#2",
        "35:Hold#2", "40:done",
      ])
    XCTAssertTrue(run.isFinished)
    XCTAssertFalse(run.isRunning)
    XCTAssertEqual(run.tick(now: 999), [])
    XCTAssertTrue(run.moment(now: 999).done)
  }

  /// #204: an uneven box's cues are on time, so their lateness is what the look was late by, never the side's length.
  func testAnUnevenBoxReportsTheTrueLateness() {
    for (inS, outS) in [(4, 8), (8, 4)] {
      var run = BreathRun(plan: BreathPlan(inSeconds: inS, outSeconds: outS, sessionMinutes: 1))
      run.start(now: 0)
      var t = 0
      for index in 0..<8 {
        // Exactly on the step's start, and once a quarter of a second late.
        let late = index % 2 == 0 ? 0.0 : 0.25
        let effects = run.tick(now: Double(t) + late)
        guard case .phase(_, _, let lateMs)? = effects.first else {
          return XCTFail("\(inS)/\(outS) step \(index): \(effects)")
        }
        XCTAssertEqual(lateMs, Int(late * 1000), "\(inS)/\(outS) step \(index)")
        t += index % 4 < 2 ? inS : outS
      }
    }
  }

  /// Story 242: a finished session is saved whole; one left early, the breathing done if a minute or more; the
  /// lead-in and pauses never count.
  func testWhatHealthGetsForASession() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 10, sessionMinutes: 2), leadIn: 2)
    run.start(now: 1000)
    XCTAssertNil(run.mindfulSpan(now: 1000 + 2 + 40), "40 s breathed is under a minute")
    run.pause(now: 1000 + 2 + 60)
    XCTAssertEqual(
      run.mindfulSpan(now: 1200), TimeSpan(start: 1_140_000, end: 1_200_000), "a paused minute is a minute")
    run.start(now: 1300)
    XCTAssertEqual(
      run.mindfulSpan(now: 1330), TimeSpan(start: 1_240_000, end: 1_330_000), "90 s breathed, the pause left out")
    let total = Double(run.plan.totalSeconds)
    XCTAssertEqual(
      run.mindfulSpan(now: 5000), TimeSpan(start: (5000 - total) * 1000, end: 5_000_000), "never more than the session")
  }

  func testAThirtyCycleSessionDoesNotDrift() {
    // The brief's bar: 10 minutes at 5 s, under 0.5 s of total drift. Looks land every 50 ms, so no cue is
    // more than 50 ms late and lateness never accumulates.
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, sessionMinutes: 10))
    run.start(now: 0)
    var worst = 0
    var finishedAt = -1.0
    var now = 0.0
    while now < 601 {
      for effect in run.tick(now: now) {
        switch effect {
        case .phase(_, _, let lateMs): worst = max(worst, lateMs)
        case .finished(let lateMs):
          worst = max(worst, lateMs)
          finishedAt = now
        }
      }
      now += 0.05
    }
    XCTAssertLessThanOrEqual(worst, 51)
    XCTAssertEqual(finishedAt, 600, accuracy: 0.051)
  }

  func testPauseFreezesEverythingAndResumeContinuesMidPhaseWithNoJump() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 8, sessionMinutes: 5))
    run.start(now: 0)
    _ = run.tick(now: 0)
    run.pause(now: 4)  // halfway through the inhale
    XCTAssertTrue(run.isPaused)
    let frozen = run.moment(now: 4)
    XCTAssertEqual(run.moment(now: 500), frozen)
    XCTAssertEqual(run.tick(now: 500), [])
    XCTAssertEqual(frozen.ring, 0.5, accuracy: 1e-9)
    run.start(now: 1000)
    XCTAssertEqual(run.moment(now: 1000), frozen)
    XCTAssertEqual(run.tick(now: 1000.05), [])  // the inhale is not announced again
    XCTAssertEqual(run.tick(now: 1004), [.phase(.holdFull, cycle: 1, lateMs: 0)])
    // Still ends on time: 288 s of breathing in all.
    XCTAssertEqual(run.tick(now: 1000 + 284), [.finished(lateMs: 0)])
  }

  func testTheLeadInIsQuietAndTheFirstInhaleFollowsIt() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 1), leadIn: 2)
    run.start(now: 0)
    XCTAssertEqual(run.tick(now: 1.9), [])
    XCTAssertEqual(run.moment(now: 1).ring, 0)
    XCTAssertEqual(run.moment(now: 1).timeLeftText, "0:20 left")
    XCTAssertEqual(run.tick(now: 2), [.phase(.inhale, cycle: 1, lateMs: 0)])
    XCTAssertEqual(run.tick(now: 22), [.finished(lateMs: 0)])
  }

  func testALookAfterALongGapReportsOnlyWhereTheSessionIsNow() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 3))
    run.start(now: 0)
    _ = run.tick(now: 0)
    XCTAssertEqual(run.tick(now: 27), [.phase(.holdFull, cycle: 2, lateMs: 2000)])
  }
}

final class BreathToneTests: XCTestCase {
  func testEachPhaseHasItsTone() {
    XCTAssertEqual(BreathPhase.allCases.map(BreathTone.tone(for:)), [.rising, .tick, .falling, .tick])
  }

  func testEveryToneIsShortQuietAtItsEdgesAndNeverClips() {
    for tone in BreathTone.allCases {
      let samples = tone.samples()
      XCTAssertEqual(Double(samples.count) / BreathTone.sampleRate, tone.seconds, accuracy: 0.001, tone.rawValue)
      XCTAssertLessThanOrEqual(tone.seconds, 1.6)
      XCTAssertLessThan(abs(samples.first ?? 1), 0.01, tone.rawValue)
      XCTAssertLessThan(abs(samples.last ?? 1), 0.02, tone.rawValue)
      XCTAssertLessThan(samples.map(abs).max() ?? 1, 0.5, tone.rawValue)
      XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.1, tone.rawValue)
    }
  }

  func testTheWavIsAMonoSixteenBitFileOfTheRightLength() {
    let wav = BreathTone.tick.wav()
    XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
    XCTAssertEqual(String(decoding: wav[8..<16], as: UTF8.self), "WAVEfmt ")
    XCTAssertEqual(wav.count, 44 + BreathTone.tick.samples().count * 2)
    XCTAssertEqual(wav[22], 1)  // one channel
    XCTAssertEqual(wav[34], 16)  // bits per sample
  }

  /// Story 241: Custom's in and its hold last In, out and its hold last Out.
  func testCustomBoxHasItsOwnInAndOut() {
    let plan = BreathPlan(inSeconds: 4, outSeconds: 8, sessionMinutes: 2)
    XCTAssertEqual(plan.cycleSeconds, 24)
    XCTAssertEqual(plan.cycles, 5)
    XCTAssertEqual(plan.moment(at: 0).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 4.5).phase, .holdFull)
    XCTAssertEqual(plan.moment(at: 8.5).phase, .exhale)
    XCTAssertEqual(plan.moment(at: 16.5).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 24.5).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 24.5).cycle, 2)
    XCTAssertEqual(plan.moment(at: 12).phaseProgress, 0.5, accuracy: 1e-9)
    XCTAssertEqual(plan.stepEnd(2), 16)
    XCTAssertEqual(plan.side(3), 8)
    XCTAssertFalse(plan.isEven)
    XCTAssertEqual(ActivityLog.breathName(plan), "Box breathing · 4/8 s · 5 cycles")
  }

  /// #200: a fresh install chooses 12 s, then Custom, and moves only In to 4. Reopened, Custom is still 4/8: the
  /// side never touched keeps its length instead of following the preset.
  func testCustomKeepsItsUntouchedSideAcrossAReopen() {
    var settings: [String: String] = [:]
    func reopen() -> BreathSetup {
      let (setup, seeds) = BreathSetup.restore { settings[$0] }
      for seed in seeds { settings[seed.key] = seed.value }
      return setup
    }
    XCTAssertEqual(reopen(), BreathSetup(preset: 8, customIn: 8, customOut: 8))
    settings[BreathSetup.breathKey] = "12"  // the 12 s preset
    settings[BreathSetup.customKey] = "1"  // then Custom
    settings[BreathSetup.customInKey] = "4"  // In moved; Out untouched
    XCTAssertEqual(reopen(), BreathSetup(preset: nil, customIn: 4, customOut: 8))
  }

  /// The old slider's length: its preset when it is one, else Custom at that length both ways.
  func testTheOldSliderLengthCarriesOver() {
    XCTAssertEqual(
      BreathSetup.restore { $0 == BreathSetup.breathKey ? "10" : nil }.setup,
      BreathSetup(preset: 10, customIn: 10, customOut: 10))
    XCTAssertEqual(
      BreathSetup.restore { $0 == BreathSetup.breathKey ? "6" : nil }.setup,
      BreathSetup(preset: nil, customIn: 6, customOut: 6))
  }

  func testCustomIsClampedAndPresetsAreEven() {
    let plan = BreathPlan(inSeconds: 1, outSeconds: 99, sessionMinutes: 5)
    XCTAssertEqual([plan.inSeconds, plan.outSeconds], [3, 15])
    XCTAssertEqual(BreathPlan.presets, [8, 10, 12, 15])
    XCTAssertTrue(BreathPlan(breathSeconds: 12, sessionMinutes: 5).isEven)
  }

  // MARK: - #289, the 4·4·6·2 pattern

  func testThePatternHasFourSidesOfTheirOwn() {
    let plan = BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 5)
    XCTAssertEqual((0..<4).map(plan.side), [4, 4, 6, 2])
    XCTAssertEqual(plan.cycleSeconds, 16)
    XCTAssertEqual(plan.cycles, 19, "300 s over 16 s cycles, the closest whole number")
    XCTAssertEqual((0..<4).map(plan.stepEnd), [4, 8, 14, 16])
    XCTAssertFalse(plan.isEven)
    XCTAssertFalse(plan.isBox)
    XCTAssertEqual(plan.pattern, .fourFourSixTwo)
    XCTAssertEqual(BreathPattern.fourFourSixTwo.label, "4\u{00B7}4\u{00B7}6\u{00B7}2")
    XCTAssertEqual(BreathPattern.fourFourSixTwo.sentence, "In 4, hold 4, out 6, hold 2.")
  }

  /// #289: an uneven pattern's shape as four arcs around the circle, from the top, clockwise.
  func testAnUnevenPatternIsFourArcsSizedByItsSteps() {
    let arcs = BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 5).arcs
    XCTAssertEqual(arcs.count, 4)
    let gap = BreathPlan.arcGap
    let spans = arcs.map { $0.end - $0.start + gap }
    for (span, share) in zip(spans, [0.25, 0.25, 0.375, 0.125]) { XCTAssertEqual(span, share, accuracy: 1e-9) }
    XCTAssertEqual(arcs[0].start, gap / 2, accuracy: 1e-9, "starts at the top, half a gap in")
    for i in 1..<4 { XCTAssertEqual(arcs[i].start - arcs[i - 1].end, gap, accuracy: 1e-9) }
    XCTAssertEqual(arcs[3].end, 1 - gap / 2, accuracy: 1e-9)
    XCTAssertEqual(BreathPlan(pattern: .fourFourSixTwoX2, sessionMinutes: 5).arcs, arcs, "×2 has the same shape")
    XCTAssertTrue(BreathPlan(breathSeconds: 8, sessionMinutes: 5).arcs.isEmpty, "an even box has no track")
  }

  /// Story 249: the same shape at two seconds a count.
  func testTheDoubledPatternIsTheSameShapeAtHalfThePace() {
    let slow = BreathPattern.fourFourSixTwoX2
    let plan = BreathPlan(pattern: slow, sessionMinutes: 5)
    XCTAssertEqual((0..<4).map(plan.side), [8, 8, 12, 4])
    XCTAssertEqual(plan.cycleSeconds, 32)
    XCTAssertEqual(plan.cycles, 9, "300 s over 32 s cycles, the closest whole number")
    XCTAssertEqual(plan.pattern, slow, "the plan knows it is the doubled pattern, not a new one")
    XCTAssertEqual(slow.label, "4\u{00B7}4\u{00B7}6\u{00B7}2 \u{00D7}2")
    XCTAssertEqual(slow.key, "4-4-6-2-x2")
    XCTAssertEqual(slow.sentence, "In 8, hold 8, out 12, hold 4.")
    XCTAssertEqual(BreathPattern.named("4-4-6-2-x2"), slow)
    XCTAssertEqual(BreathPattern.named("4-4-6-2"), .fourFourSixTwo)
    XCTAssertEqual(BreathPattern.all, [.fourFourSixTwo, slow, .fourFourSixTwoX3])
    XCTAssertEqual(
      ActivityLog.breathName(plan), "Breathing \u{00B7} 4\u{00B7}4\u{00B7}6\u{00B7}2 \u{00D7}2 \u{00B7} 9 cycles")
  }

  /// Story 280 (#394): the same shape at three seconds a count.
  func testTheTripledPatternIsTheSameShapeAtAThirdOfThePace() {
    let slower = BreathPattern.fourFourSixTwoX3
    let plan = BreathPlan(pattern: slower, sessionMinutes: 10)
    XCTAssertEqual((0..<4).map(plan.side), [12, 12, 18, 6])
    XCTAssertEqual(plan.cycleSeconds, 48)
    XCTAssertEqual(plan.cycles, 13, "600 s over 48 s cycles is 12.5, rounded up")
    XCTAssertEqual(plan.pattern, slower, "the plan knows it is the tripled pattern")
    XCTAssertEqual(slower.label, "4\u{00B7}4\u{00B7}6\u{00B7}2 \u{00D7}3")
    XCTAssertEqual(BreathPattern.named("4-4-6-2-x3"), slower)
    XCTAssertEqual(slower.sentence, "In 12, hold 12, out 18, hold 6.")
    XCTAssertEqual(plan.arcs, BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 10).arcs, "the same shape")
    XCTAssertEqual(
      ActivityLog.breathName(plan), "Breathing \u{00B7} 4\u{00B7}4\u{00B7}6\u{00B7}2 \u{00D7}3 \u{00B7} 13 cycles")
  }

  func testThePatternsPhasesFallOnTheirOwnSeconds() {
    let plan = BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 2)
    XCTAssertEqual(plan.moment(at: 3.9).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 4.0).phase, .holdFull)
    XCTAssertEqual(plan.moment(at: 8.0).phase, .exhale)
    XCTAssertEqual(plan.moment(at: 13.9).phase, .exhale)
    XCTAssertEqual(plan.moment(at: 14.0).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 16.0).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 16.0).cycle, 2)
    XCTAssertEqual(plan.moment(at: 11.0).phaseProgress, 0.5, accuracy: 1e-9, "3 s into a 6 s exhale")
  }

  func testEveryStepOfThePatternIsCalledOnTime() {
    var run = BreathRun(plan: BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 2))
    run.start(now: 0)
    var t = 0
    for index in 0..<8 {
      let effects = run.tick(now: Double(t))
      guard case .phase(let phase, _, let lateMs)? = effects.first else { return XCTFail("step \(index): \(effects)") }
      XCTAssertEqual(phase.rawValue, index % 4)
      XCTAssertEqual(lateMs, 0, "step \(index)")
      t += [4, 4, 6, 2][index % 4]
    }
  }

  func testThePatternIsRememberedAndNamed() {
    let restored = BreathSetup.restore {
      switch $0 {
      case BreathSetup.breathKey: "12"
      case BreathSetup.patternKey: "4-4-6-2"
      default: nil
      }
    }.setup
    XCTAssertEqual(restored.pattern, .fourFourSixTwo)
    XCTAssertNil(restored.preset, "the pattern wins while chosen")
    XCTAssertNil(BreathSetup.restore { $0 == BreathSetup.patternKey ? "" : nil }.setup.pattern, "cleared by a preset")
    XCTAssertEqual(
      ActivityLog.breathName(BreathPlan(pattern: .fourFourSixTwo, sessionMinutes: 5)),
      "Breathing \u{00B7} 4\u{00B7}4\u{00B7}6\u{00B7}2 \u{00B7} 19 cycles")
    XCTAssertNil(BreathPlan(inSeconds: 4, outSeconds: 8, sessionMinutes: 1).pattern, "Custom is still a box")
  }
}
