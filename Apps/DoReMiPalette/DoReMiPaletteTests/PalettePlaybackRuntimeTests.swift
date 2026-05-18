import DoReMiRendererKit
import Foundation
import Testing
@testable import DoReMiPalette

@Suite("Palette playback runtime")
struct PalettePlaybackRuntimeTests {
    @Test @MainActor func playPauseStopTransitionsAreStable() throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(
            events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML),
            audioEngine: audio
        )

        runtime.play()
        #expect(runtime.state == .playing)

        runtime.pause()
        #expect(runtime.state == .paused)
        #expect(audio.silenceCount > 0)

        runtime.stop()
        #expect(runtime.state == .stopped)
    }

    @Test @MainActor func resetReturnsToFirstEvent() throws {
        let runtime = PalettePlaybackRuntime(events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML))

        runtime.move(by: 1)
        #expect(runtime.currentEventIndex == 1)

        runtime.reset()

        #expect(runtime.currentEventIndex == 0)
        #expect(runtime.state == .stopped)
    }

    @Test @MainActor func tempoChangesDurationCalculation() throws {
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: 120)
        let defaultDuration = runtime.eventDurationSeconds(for: event)

        runtime.setTempoBPM(240)

        #expect(runtime.eventDurationSeconds(for: event) < defaultDuration)
    }

    @Test @MainActor func metronomeDefaultsOffAndCanBeEnabled() throws {
        let runtime = PalettePlaybackRuntime(events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML))

        #expect(runtime.metronomeEnabled == false)

        runtime.setMetronomeEnabled(true)

        #expect(runtime.metronomeEnabled == true)
    }

    @Test @MainActor func metronomePlaysStrongAndWeakClicksWhenEnabled() throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(
            events: try Self.events(from: Self.longMetronomeMusicXML),
            tempoBPM: 240,
            metronomeEnabled: true,
            audioEngine: audio
        )

        runtime.triggerMetronomeClickForTesting(isStrongBeat: true)
        runtime.triggerMetronomeClickForTesting(isStrongBeat: false)

        #expect(audio.playedPitches.contains([96]))
        #expect(audio.playedPitches.contains([84]))
        #expect(audio.playedVelocities.contains(0.72))
        #expect(audio.playedVelocities.contains(0.46))
    }

    @Test @MainActor func metronomeDoesNotClickWhenDisabled() async throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(
            events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML),
            tempoBPM: 240,
            metronomeEnabled: false,
            audioEngine: audio
        )

        runtime.play()
        try await Task.sleep(nanoseconds: 80_000_000)
        runtime.stop()

        #expect(!audio.playedPitches.contains([96]))
        #expect(!audio.playedPitches.contains([84]))
    }

    @Test @MainActor func enablingMetronomeDuringPlaybackStartsOnNextBeatAndDisablingStops() async throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(
            events: try Self.events(from: Self.longMetronomeMusicXML),
            tempoBPM: 240,
            audioEngine: audio
        )

        runtime.play()
        try await Task.sleep(nanoseconds: 80_000_000)
        runtime.setMetronomeEnabled(true)
        let clickCountImmediatelyAfterEnable = audio.metronomeClickCount
        try await Task.sleep(nanoseconds: 80_000_000)
        let clickCountBeforeNextBeat = audio.metronomeClickCount
        try await Task.sleep(nanoseconds: 200_000_000)
        runtime.setMetronomeEnabled(false)
        let clickCountAfterDisable = audio.metronomeClickCount
        try await Task.sleep(nanoseconds: 300_000_000)
        runtime.stop()

        #expect(clickCountImmediatelyAfterEnable == 0)
        #expect(clickCountBeforeNextBeat == 0)
        #expect(clickCountAfterDisable >= 1)
        #expect(audio.metronomeClickCount == clickCountAfterDisable)
        #expect(audio.playedPitches.contains([84]))
        #expect(!audio.playedPitches.contains([96]))
    }

    @Test @MainActor func metronomeUsesParsedThreeFourTimeSignatureForStrongBeatCycle() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.threeFourMetronomeMusicXML,
            sourceName: "three-four.musicxml"
        )
        let runtime = PalettePlaybackRuntime()
        runtime.configure(events: loaded.playbackEvents, metadata: loaded.playbackMetadata)
        runtime.setTempoBPM(240)

        #expect(loaded.playbackMetadata.timeSignatureEvents.contains {
            $0.timeSignature == TimeSignature(beats: 3, beatType: 4)
        })
        #expect(runtime.metronomeBeatIsStrongForTesting(beatIndex: 0, eventIndex: 0))
        #expect(!runtime.metronomeBeatIsStrongForTesting(beatIndex: 1, eventIndex: 0))
        #expect(!runtime.metronomeBeatIsStrongForTesting(beatIndex: 2, eventIndex: 0))
        #expect(runtime.metronomeBeatIsStrongForTesting(beatIndex: 3, eventIndex: 0))
        #expect(abs(runtime.metronomeIntervalSecondsForTesting(eventIndex: 0) - 0.25) < 0.001)
    }

    @Test @MainActor func metronomeUsesLargeBeatPatternForSixEightByDefault() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.sixEightMetronomeMusicXML,
            sourceName: "six-eight.musicxml"
        )
        let runtime = PalettePlaybackRuntime()
        runtime.configure(events: loaded.playbackEvents, metadata: loaded.playbackMetadata)
        runtime.setTempoBPM(240)

        #expect(loaded.playbackMetadata.timeSignatureEvents.contains {
            $0.timeSignature == TimeSignature(beats: 6, beatType: 8)
        })
        #expect(runtime.metronomeBeatsPerMeasureForTesting(eventIndex: 0) == 2)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 0, eventIndex: 0) == .strong)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 1, eventIndex: 0) == .weak)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 2, eventIndex: 0) == .strong)
        #expect(abs(runtime.metronomeIntervalSecondsForTesting(eventIndex: 0) - 0.375) < 0.001)
    }

    @Test @MainActor func metronomeSubdivisionPatternForSixEightUsesSixClicksWithMediumSecondLargeBeat() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.sixEightMetronomeMusicXML,
            sourceName: "six-eight.musicxml"
        )
        let runtime = PalettePlaybackRuntime()
        runtime.configure(events: loaded.playbackEvents, metadata: loaded.playbackMetadata)
        runtime.setTempoBPM(240)
        runtime.setMetronomeCompoundMode(.subdivision)

        #expect(runtime.metronomeBeatsPerMeasureForTesting(eventIndex: 0) == 6)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 0, eventIndex: 0) == .strong)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 1, eventIndex: 0) == .weak)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 3, eventIndex: 0) == .medium)
        #expect(abs(runtime.metronomeIntervalSecondsForTesting(eventIndex: 0) - 0.125) < 0.001)
    }

    @Test @MainActor func metronomeLargeBeatPatternsCoverNineEightAndTwelveEight() throws {
        let nineEight = try PaletteScoreLoader().load(
            data: Self.compoundMetronomeMusicXML(beats: 9),
            sourceName: "nine-eight.musicxml"
        )
        let twelveEight = try PaletteScoreLoader().load(
            data: Self.compoundMetronomeMusicXML(beats: 12),
            sourceName: "twelve-eight.musicxml"
        )
        let runtime = PalettePlaybackRuntime()

        runtime.configure(events: nineEight.playbackEvents, metadata: nineEight.playbackMetadata)
        #expect(runtime.metronomeBeatsPerMeasureForTesting(eventIndex: 0) == 3)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 0, eventIndex: 0) == .strong)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 1, eventIndex: 0) == .weak)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 2, eventIndex: 0) == .weak)

        runtime.configure(events: twelveEight.playbackEvents, metadata: twelveEight.playbackMetadata)
        #expect(runtime.metronomeBeatsPerMeasureForTesting(eventIndex: 0) == 4)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 0, eventIndex: 0) == .strong)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 2, eventIndex: 0) == .medium)
    }

    @Test @MainActor func unknownMeterFallsBackToSimpleBeatPattern() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.compoundMetronomeMusicXML(beats: 7),
            sourceName: "seven-eight.musicxml"
        )
        let runtime = PalettePlaybackRuntime()
        runtime.configure(events: loaded.playbackEvents, metadata: loaded.playbackMetadata)

        #expect(runtime.metronomeBeatsPerMeasureForTesting(eventIndex: 0) == 7)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 0, eventIndex: 0) == .strong)
        #expect(runtime.metronomeAccentForTesting(beatIndex: 1, eventIndex: 0) == .weak)
    }

    @Test @MainActor func tapTempoAveragesRecentTapsClampsAndResetsAfterLongGap() throws {
        let runtime = PalettePlaybackRuntime()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(runtime.registerTapTempo(at: start) == nil)
        #expect(runtime.registerTapTempo(at: start.addingTimeInterval(0.5)) == 120)
        #expect(abs((runtime.registerTapTempo(at: start.addingTimeInterval(1.1)) ?? 0) - 109.09) < 0.01)
        #expect(runtime.registerTapTempo(at: start.addingTimeInterval(4.0)) == nil)
        #expect(runtime.registerTapTempo(at: start.addingTimeInterval(4.1)) == 240)
    }

    @Test @MainActor func clickSoundStyleChangesGeneratedClickParameters() throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(audioEngine: audio)

        runtime.triggerMetronomeClickForTesting(isStrongBeat: true)
        runtime.setMetronomeClickSoundStyle(.soft)
        runtime.triggerMetronomeClickForTesting(isStrongBeat: true)
        runtime.setMetronomeClickSoundStyle(.wood)
        runtime.triggerMetronomeClickForTesting(isStrongBeat: true)
        runtime.setMetronomeClickSoundStyle(.electronic)
        runtime.triggerMetronomeClickForTesting(isStrongBeat: true)

        #expect(audio.playedPitches == [[96], [88], [76], [108]])
        #expect(audio.playedVelocities[1] < audio.playedVelocities[0])
        #expect(audio.playedDurations.allSatisfy { $0 > 0 && $0 < 0.05 })
    }

    @Test @MainActor func noteGateRatioDefaultsClampsAndShortensSoundOnly() throws {
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: 120)
        let eventDuration = runtime.eventDurationSeconds(for: event)

        #expect(runtime.noteGateRatio == 0.85)
        #expect(runtime.soundDurationSeconds(for: event) == eventDuration * 0.85)

        runtime.setNoteGateRatio(0.1)
        #expect(runtime.noteGateRatio == 0.50)
        #expect(runtime.eventDurationSeconds(for: event) == eventDuration)

        runtime.setNoteGateRatio(2.0)
        #expect(runtime.noteGateRatio == 1.00)
        #expect(runtime.eventDurationSeconds(for: event) == eventDuration)

        runtime.setNoteGateRatio(.nan)
        #expect(runtime.noteGateRatio == 0.85)
        #expect(runtime.eventDurationSeconds(for: event) == eventDuration)
    }

    @Test @MainActor func repeatedSamePitchTriggersSeparateGatedAudioPlays() throws {
        let audio = MockPaletteAudioEngine()
        let events = try Self.events(from: Self.rhythmValuesSampleMusicXML)
            .filter { $0.midiPitches == [60] && Self.quarterNotes(for: $0.nominalDuration) == 1.0 }
        let first = try #require(events.first)
        let second = try #require(events.dropFirst().first)
        let runtime = PalettePlaybackRuntime(events: [first, second], tempoBPM: 120, noteGateRatio: 0.70, audioEngine: audio)
        let expectedSoundDuration = runtime.eventDurationSeconds(for: first) * 0.70

        runtime.triggerAudioForCurrentEvent()
        runtime.move(by: 1)
        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[60], [60]])
        #expect(audio.playedDurations == [expectedSoundDuration, expectedSoundDuration])
        #expect(audio.silenceCount == 0)
    }

    @Test @MainActor func fastShortNotesKeepMinimumAudibleSoundDuration() throws {
        let event = try #require(Self.events(from: Self.sixteenthNotesMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: 240, noteGateRatio: 0.50)
        let eventDuration = runtime.eventDurationSeconds(for: event)
        let soundDuration = runtime.soundDurationSeconds(for: event)

        #expect(soundDuration >= min(eventDuration, 0.06))
        #expect(soundDuration <= eventDuration)
        #expect(soundDuration > eventDuration * 0.50)
    }

    @Test @MainActor func pitchedPlaybackEventsTriggerAudioForEachEvent() throws {
        let audio = MockPaletteAudioEngine()
        let events = try Self.events(from: Self.rhythmValuesSampleMusicXML)
            .filter { !$0.midiPitches.isEmpty && !$0.isTiedContinuation }
            .prefix(6)
        let runtime = PalettePlaybackRuntime(events: Array(events), tempoBPM: 150, audioEngine: audio)

        for index in runtime.events.indices {
            runtime.move(to: index)
            runtime.triggerAudioForCurrentEvent()
        }

        #expect(audio.playedPitches.count == runtime.events.count)
        #expect(audio.playedDurations.allSatisfy { $0.isFinite && $0 > 0 })
    }

    @Test @MainActor func notationCoverageSixthEventD3IsPitchedAudibleAndScheduled() throws {
        let audio = MockPaletteAudioEngine()
        let events = try Self.events(from: Self.notationCoverageSampleMusicXML)
        let d3Event = try #require(events.first { $0.midiPitches == [50] })
        let d3Index = try #require(events.firstIndex(of: d3Event))
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 120, audioEngine: audio)

        #expect(d3Event.midiPitches == [50])
        #expect(d3Event.isTiedContinuation == false)
        #expect(d3Event.noteIDs.isEmpty == false)
        #expect(runtime.soundDurationSeconds(for: d3Event) >= 0.06)
        #expect(SimpleToneAudioEngine.frequency(forMIDIPitch: 50).isFinite)
        #expect(SimpleToneAudioEngine.frequency(forMIDIPitch: 50) > 0)

        for index in 0...d3Index {
            runtime.move(to: index)
            runtime.triggerAudioForCurrentEvent()
        }

        #expect(audio.playedPitches.count >= 1)
        #expect(audio.playedPitches.last == [50])
        #expect(audio.playedDurations.last ?? 0 >= 0.06)
    }

    @Test @MainActor func notationCoverageD3StartsAtItsOnsetBeforeC5WholeCompletes() throws {
        let events = try Self.events(from: Self.notationCoverageSampleMusicXML)
        let c5Whole = try #require(events.first { $0.midiPitches == [72] })
        let d3Event = try #require(events.first { $0.midiPitches == [50] })
        let c5Index = try #require(events.firstIndex(of: c5Whole))
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 120)

        #expect(c5Whole.midiPitches == [72])
        #expect(Self.quarterNotes(for: c5Whole.nominalDuration) >= 1.0)
        #expect(d3Event.midiPitches == [50])
        #expect(d3Event.onset > c5Whole.onset)

        let schedulingInterval = runtime.schedulingIntervalSeconds(from: c5Index)

        #expect(schedulingInterval.isFinite)
        #expect(schedulingInterval > 0)
    }

    @Test @MainActor func canonOpeningUsesFileTempoAndStableEighthScheduling() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("Canon_in_D.mxl"),
            sourceName: "Canon_in_D.mxl"
        )
        let runtime = PalettePlaybackRuntime()
        runtime.configure(events: loaded.playbackEvents, metadata: loaded.playbackMetadata)
        let firstMeasureEvents = loaded.playbackEvents.enumerated().filter {
            $0.element.measureID.rawValue == "0.1"
        }

        #expect(runtime.tempoBPM == 100)
        #expect(firstMeasureEvents.count >= 8)

        let intervals = firstMeasureEvents.prefix(8).map {
            runtime.schedulingIntervalSeconds(from: $0.offset)
        }

        #expect(intervals.allSatisfy { abs($0 - 0.3) < 0.001 })
    }

    @Test @MainActor func s6StandaloneQuintupletAndSeptupletUseTupletPlaybackIntervals() throws {
        let events = try Self.events(from: Self.s6NotationRefinementSampleMusicXML)
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 120)
        let measure12Events = events.enumerated().filter { $0.element.measureID.rawValue == "0.1" }
        let measure13Events = events.enumerated().filter { $0.element.measureID.rawValue == "0.2" }
        let measure12Pitched = measure12Events.filter { !$0.element.midiPitches.isEmpty }
        let measure13Pitched = measure13Events.filter { !$0.element.midiPitches.isEmpty }

        #expect(measure12Pitched.count == 5)
        #expect(measure13Pitched.count == 7)
        #expect(measure12Pitched.allSatisfy { $0.element.staffIDs.contains(StaffID(rawValue: "1")) })
        #expect(measure13Pitched.allSatisfy { $0.element.staffIDs.contains(StaffID(rawValue: "2")) })
        #expect(measure12Pitched.allSatisfy { abs(Self.quarterNotes(for: $0.element.nominalDuration) - 0.4) < 0.0001 })
        #expect(measure13Pitched.allSatisfy { abs(Self.quarterNotes(for: $0.element.nominalDuration) - (2.0 / 7.0)) < 0.0001 })

        let quintupletIntervals = measure12Pitched.dropLast().map { runtime.schedulingIntervalSeconds(from: $0.offset) }
        let septupletIntervals = measure13Pitched.dropLast().map { runtime.schedulingIntervalSeconds(from: $0.offset) }

        #expect(quintupletIntervals.allSatisfy { abs($0 - 0.2) < 0.0001 })
        #expect(septupletIntervals.allSatisfy { abs($0 - (1.0 / 7.0)) < 0.0001 })
    }

    @Test @MainActor func bundledSampleRepeatedC5NotesAreSeparateAttacks() throws {
        let audio = MockPaletteAudioEngine()
        let c5Events = try Self.events(from: Self.phase12SampleMusicXML)
            .filter { $0.midiPitches == [72] }
        let first = try #require(c5Events.first)
        let second = try #require(c5Events.dropFirst().first)
        let runtime = PalettePlaybackRuntime(events: [first, second], tempoBPM: 120, noteGateRatio: 0.85, audioEngine: audio)

        #expect(first.isTiedContinuation == false)
        #expect(second.isTiedContinuation == false)

        runtime.triggerAudioForCurrentEvent()
        runtime.move(by: 1)
        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[72], [72]])
        #expect(audio.silenceCount == 0)
        #expect(audio.playedDurations.count == 2)
        #expect(audio.playedDurations[0] > audio.playedDurations[1])
    }

    @Test func audioVoiceRegistryStopsOverlappingSamePitchBeforeNewAttack() {
        var registry = PaletteAudioVoiceRegistry()

        let firstStopped = registry.prepareToPlay(
            playerIndex: 0,
            pitches: [48, 69],
            duration: 4.0,
            now: 10
        )
        let secondStopped = registry.prepareToPlay(
            playerIndex: 1,
            pitches: [48],
            duration: 0.5,
            now: 11
        )

        #expect(firstStopped.isEmpty)
        #expect(secondStopped == [0])
        #expect(registry.activeVoices[0] == nil)
        #expect(registry.activeVoices[1]?.pitches == [48])
    }

    @Test func audioVoiceRegistryKeepsDifferentOverlappingPitchesActive() {
        var registry = PaletteAudioVoiceRegistry()

        _ = registry.prepareToPlay(playerIndex: 0, pitches: [48], duration: 4.0, now: 10)
        let stopped = registry.prepareToPlay(playerIndex: 1, pitches: [69], duration: 0.5, now: 11)

        #expect(stopped.isEmpty)
        #expect(registry.activeVoices[0]?.pitches == [48])
        #expect(registry.activeVoices[1]?.pitches == [69])
    }

    @Test func audioVoiceRegistryDropsExpiredVoicesBeforePlaying() {
        var registry = PaletteAudioVoiceRegistry()

        _ = registry.prepareToPlay(playerIndex: 0, pitches: [48], duration: 1.0, now: 10)
        let stopped = registry.prepareToPlay(playerIndex: 1, pitches: [69], duration: 0.5, now: 12)

        #expect(stopped == [0])
        #expect(registry.activeVoices[0] == nil)
        #expect(registry.activeVoices[1]?.pitches == [69])
    }

    @Test @MainActor func tempoChangeIsSafeWhileStoppedPausedPlayingAndEmpty() throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(
            events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML),
            audioEngine: audio
        )
        let firstNoteID = runtime.currentNoteID

        runtime.setTempoBPM(90)
        #expect(runtime.state == .stopped)
        #expect(runtime.currentEventIndex == 0)
        #expect(runtime.currentNoteID == firstNoteID)
        #expect(audio.playedPitches.isEmpty)

        runtime.play()
        runtime.pause()
        runtime.setTempoBPM(150)
        #expect(runtime.state == .paused)
        #expect(runtime.currentEventIndex == 0)
        #expect(runtime.currentNoteID == firstNoteID)

        runtime.play()
        let silenceBeforeTempoChange = audio.silenceCount
        runtime.setTempoBPM(60)
        #expect(runtime.state == .playing)
        #expect(runtime.currentEventIndex == 0)
        #expect(runtime.currentNoteID == firstNoteID)
        #expect(audio.silenceCount > silenceBeforeTempoChange)

        runtime.stop()
        runtime.configure(events: [])
        runtime.setTempoBPM(120)
        runtime.play()
        #expect(runtime.state == .stopped)
        #expect(runtime.currentEventIndex == 0)
    }

    @Test @MainActor func tempoClampsInvalidValuesWithoutChangingCurrentEvent() throws {
        let events = try Self.events(from: PaletteScoreLoaderTests.validMusicXML)
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 120)

        runtime.move(by: 1)
        let currentNoteID = runtime.currentNoteID

        runtime.setTempoBPM(0)
        #expect(runtime.tempoBPM == 30)
        #expect(runtime.currentEventIndex == 1)
        #expect(runtime.currentNoteID == currentNoteID)

        runtime.setTempoBPM(-200)
        #expect(runtime.tempoBPM == 30)

        runtime.setTempoBPM(10_000)
        #expect(runtime.tempoBPM == 240)

        runtime.setTempoBPM(.nan)
        #expect(runtime.tempoBPM == 120)

        runtime.setTempoBPM(.infinity)
        #expect(runtime.tempoBPM == 120)
    }

    @Test @MainActor func transportCommandsAroundTempoChangesDoNotCrash() throws {
        let runtime = PalettePlaybackRuntime(events: try Self.events(from: PaletteScoreLoaderTests.validMusicXML))

        runtime.play()
        runtime.setTempoBPM(90)
        runtime.pause()
        runtime.setTempoBPM(150)
        runtime.play()
        runtime.setTempoBPM(60)
        runtime.stop()
        runtime.setTempoBPM(120)
        runtime.reset()

        #expect(runtime.state == .stopped)
        #expect(runtime.currentEventIndex == 0)
        #expect(runtime.currentNoteID != nil)
    }

    @Test @MainActor func tempoMetadataAppliesAtCurrentEventOnset() throws {
        let events = try Self.events(from: PaletteScoreLoaderTests.validMusicXML)
        let metadata = DoReMiRenderer().makePlaybackMetadata(score: Self.score(tempoEvents: [
            TempoEvent(bpm: 60, onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 1), source: .sound),
            TempoEvent(bpm: 120, onset: MusicalTime(ticks: 1, ticksPerQuarterNote: 1), source: .sound),
        ]))
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 90)

        runtime.configure(events: events, metadata: metadata)

        #expect(runtime.tempoBPM == 60)
        #expect(runtime.effectiveTempoBPM == 60)
        #expect(runtime.eventDurationSeconds(for: events[0]) == 1.0)
        #expect(runtime.eventDurationSeconds(for: events[1]) == 0.5)
    }

    @Test @MainActor func configureWithoutTempoMetadataResetsToDefaultTempo() throws {
        let events = try Self.events(from: PaletteScoreLoaderTests.validMusicXML)
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 180)

        runtime.setTempoBPM(200)
        runtime.configure(events: events, metadata: nil)

        #expect(runtime.tempoBPM == 120)
        #expect(runtime.effectiveTempoBPM == 120)
    }

    @Test @MainActor func restEventDoesNotTriggerAudioPlay() throws {
        let audio = MockPaletteAudioEngine()
        let rest = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML, includeRests: true).first {
            $0.midiPitches.isEmpty
        })
        let runtime = PalettePlaybackRuntime(events: [rest], audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches.isEmpty)
        #expect(audio.silenceCount == 0)
    }

    @Test @MainActor func emptySequenceTempoChangeDoesNotPlayAudio() {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(events: [], audioEngine: audio)

        runtime.setTempoBPM(150)
        runtime.play()
        runtime.pause()
        runtime.stop()
        runtime.reset()

        #expect(runtime.state == .stopped)
        #expect(runtime.currentEventIndex == 0)
        #expect(audio.playedPitches.isEmpty)
    }

    @Test @MainActor func invalidDurationDoesNotReachAudioPlay() throws {
        let audio = MockPaletteAudioEngine()
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: .nan, audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedDurations.allSatisfy { $0.isFinite && $0 > 0 })
    }

    @Test @MainActor func chordEventPlaysAllPitchesInMVP() throws {
        let audio = MockPaletteAudioEngine()
        let chord = try #require(Self.events(from: PaletteScoreLoaderTests.chordMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [chord], audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[60, 64]])
    }

    @Test @MainActor func transposeZeroKeepsPlaybackMIDIPitchesUnchanged() throws {
        let audio = MockPaletteAudioEngine()
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], transposeSemitones: 0, audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[60]])
        #expect(runtime.currentMidiPitches == [60])
    }

    @Test @MainActor func transposeAppliesToPlaybackAndChordPitches() throws {
        let audio = MockPaletteAudioEngine()
        let chord = try #require(Self.events(from: PaletteScoreLoaderTests.chordMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [chord], transposeSemitones: 2, audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[62, 66]])
        #expect(runtime.currentMidiPitches == [62, 66])

        runtime.setTransposeSemitones(-2)
        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches.last == [58, 62])
    }

    @Test @MainActor func transposeClampsSettingAndSkipsOutOfRangePitches() throws {
        let runtime = PalettePlaybackRuntime(events: [], transposeSemitones: 200)

        #expect(runtime.transposeSemitones == 12)
        #expect(PalettePlaybackRuntime.transposedMIDIPitch(126, by: runtime.transposeSemitones) == nil)
    }

    @Test @MainActor func notationCoverageLastMeasuresUsePerPitchSoundDurations() throws {
        let events = try Self.events(from: Self.notationCoverageSampleMusicXML, includeRests: true)
        let measureNineFirst = try #require(events.first {
            $0.measureID.rawValue == "0.9" && $0.midiPitches == [76]
        })
        let measureTenFirst = try #require(events.first {
            $0.measureID.rawValue == "0.10" && Set($0.midiPitches) == [60, 36]
        })
        let runtime = PalettePlaybackRuntime(events: [measureNineFirst, measureTenFirst], tempoBPM: 120)

        #expect(Self.quarterNotes(for: measureNineFirst.nominalDuration) >= 1.0)
        #expect(runtime.soundDurationSeconds(for: 76, in: measureNineFirst) == runtime.soundDurationSeconds(for: measureNineFirst))
        #expect(runtime.soundDurationSeconds(for: 60, in: measureTenFirst) < runtime.soundDurationSeconds(for: 36, in: measureTenFirst))
    }

    @Test @MainActor func notationCoverageFinalMeasuresKeepFourBeatScheduling() throws {
        let events = try Self.events(from: Self.notationCoverageSampleMusicXML)
        let runtime = PalettePlaybackRuntime(events: events, tempoBPM: 120)

        let measureNineIntervals = scheduledIntervals(forMeasure: "0.9", events: events, runtime: runtime)
        let measureTenIntervals = scheduledIntervals(forMeasure: "0.10", events: events, runtime: runtime)

        #expect(events.contains { $0.measureID.rawValue == "0.9" && $0.midiPitches.isEmpty })
        #expect(events.contains { $0.measureID.rawValue == "0.10" && $0.midiPitches.isEmpty })
        #expect(measureNineIntervals.reduce(0, +) > 0)
        #expect(measureTenIntervals.reduce(0, +) > 0)
    }

    @Test @MainActor func mixedDurationChordSchedulesSeparateAudioPlays() throws {
        let audio = MockPaletteAudioEngine()
        let event = try #require(Self.events(from: Self.notationCoverageSampleMusicXML, includeRests: true).first {
            $0.measureID.rawValue == "0.10" && Set($0.midiPitches) == [60, 36]
        })
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: 120, audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(Set(audio.playedPitches.map { Set($0) }) == [Set([60]), Set([36])])
        #expect(audio.playedDurations.count == 2)
        #expect((audio.playedDurations.max() ?? 0) > (audio.playedDurations.min() ?? 0))
    }

    @Test @MainActor func tieContinuationDoesNotTriggerNewAttack() throws {
        let audio = MockPaletteAudioEngine()
        let continuation = try #require(Self.events(from: Self.tieStopOnlyMusicXML).first {
            $0.isTiedContinuation
        })
        let runtime = PalettePlaybackRuntime(events: [continuation], audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches.isEmpty)
        #expect(audio.silenceCount == 0)
    }

    @Test @MainActor func tieStartSustainsThroughTieContinuationWithoutGateShortening() throws {
        let audio = MockPaletteAudioEngine()
        let attack = try #require(Self.events(from: Self.tieStopOnlyMusicXML).first {
            $0.midiPitches == [65]
        })
        let runtime = PalettePlaybackRuntime(events: [attack], tempoBPM: 120, noteGateRatio: 0.50, audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(attack.midiPitchDurations[65] == MusicalTime(ticks: 8, ticksPerQuarterNote: 4))
        #expect(audio.playedPitches == [[65]])
        #expect(abs((audio.playedDurations.first ?? 0) - 1.0) < 0.001)
    }

    @Test @MainActor func mixedTieContinuationEventStillPlaysNewAttackPitches() throws {
        let audio = MockPaletteAudioEngine()
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.mixedTieContinuationAndAttackMusicXML).first {
            $0.midiPitches == [69] && $0.noteIDs.count > $0.midiPitches.count
        })
        let runtime = PalettePlaybackRuntime(events: [event], audioEngine: audio)

        runtime.triggerAudioForCurrentEvent()

        #expect(audio.playedPitches == [[69]])
        #expect(audio.playedDurations.first ?? 0 >= 0.06)
        #expect(audio.silenceCount == 0)
    }


    @Test @MainActor func audioStartFailureDoesNotCrashRuntime() throws {
        let audio = MockPaletteAudioEngine(startError: MockAudioError.startFailed)
        let event = try #require(Self.events(from: PaletteScoreLoaderTests.validMusicXML).first)
        let runtime = PalettePlaybackRuntime(events: [event], audioEngine: audio)
        var receivedError: Error?
        runtime.onAudioError = { receivedError = $0 }

        runtime.triggerAudioForCurrentEvent()

        #expect(receivedError != nil)
        #expect(audio.playedPitches.isEmpty)
    }

    @Test @MainActor func sessionPlaybackUpdatesCurrentNoteIDAndKeepsLayoutIdentity() throws {
        let audio = MockPaletteAudioEngine()
        let runtime = PalettePlaybackRuntime(audioEngine: audio)
        let session = PaletteScoreSession(playbackRuntime: runtime)
        try session.load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let noteIDs = Set(try #require(session.loadedScore?.layout.noteByID.keys))
        let first = session.playbackCursor.currentNoteID

        session.movePlaybackStep(by: 1)

        #expect(session.playbackCursor.currentNoteID != first)
        #expect(Set(try #require(session.loadedScore?.layout.noteByID.keys)) == noteIDs)
    }

    @Test @MainActor func sessionTransposeUpdatesKeyboardHighlightWithoutMutatingPlaybackEvents() throws {
        let runtime = PalettePlaybackRuntime()
        let session = PaletteScoreSession(playbackRuntime: runtime)
        try session.load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstEvent = try #require(session.playbackCursor.currentEvent)
        let noteIDs = Set(try #require(session.loadedScore?.layout.noteByID.keys))

        session.setTransposeSemitones(2)

        #expect(session.transposeSemitones == 2)
        #expect(session.currentHighlightState.attackMIDIPitches == [62])
        #expect(session.playbackCursor.currentEvent == firstEvent)
        #expect(Set(try #require(session.loadedScore?.layout.noteByID.keys)) == noteIDs)
    }

    @Test @MainActor func displayTransposeRelayoutsScoreWithoutChangingPlaybackEventIdentity() throws {
        let session = PaletteScoreSession()
        try session.load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstEvent = try #require(session.playbackCursor.currentEvent)
        let firstNoteID = try #require(firstEvent.noteIDs.first)
        let writtenPitch = try #require(session.loadedScore?.layout.noteLayout(for: firstNoteID)?.pitch)

        session.setTransposeSemitones(2)
        session.setDisplayTransposeEnabled(true)

        let displayedPitch = try #require(session.loadedScore?.layout.noteLayout(for: firstNoteID)?.pitch)
        #expect(writtenPitch != displayedPitch)
        #expect(displayedPitch == Pitch(step: .d, octave: 4))
        #expect(session.playbackCursor.currentEvent == firstEvent)
        #expect(session.currentHighlightState.attackMIDIPitches == [62])
    }

    private static func events(from data: Data, includeRests: Bool = false) throws -> [PlaybackEvent] {
        let loaded = try PaletteScoreLoader().load(data: data, sourceName: "unit.musicxml")
        if includeRests {
            return DoReMiRenderer().makePlaybackSequence(
                score: loaded.score,
                options: PlaybackOptions(includeRests: true)
            )
        }
        return loaded.playbackEvents
    }

    private static func appSampleData(_ fileName: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sampleURL = projectRoot
            .appendingPathComponent("DoReMiPalette")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Samples")
            .appendingPathComponent(fileName)
        return try Data(contentsOf: sampleURL)
    }

    @MainActor
    private func scheduledIntervals(
        forMeasure measureID: String,
        events: [PlaybackEvent],
        runtime: PalettePlaybackRuntime
    ) -> [TimeInterval] {
        events.indices.compactMap { index in
            guard events[index].measureID.rawValue == measureID else {
                return nil
            }
            return runtime.schedulingIntervalSeconds(from: index)
        }
    }

    private static var rhythmValuesSampleMusicXML: Data {
        repeatedC4MusicXML
    }

    private static let longMetronomeMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Metronome</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    private static let threeFourMetronomeMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Three Four Metronome</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>3</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note>
        </measure>
        <measure number="2">
          <attributes>
            <time><beats>3</beats><beat-type>4</beat-type></time>
          </attributes>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    private static let sixEightMetronomeMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Six Eight Metronome</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>2</divisions>
            <time><beats>6</beats><beat-type>8</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>6</duration>
            <voice>1</voice>
            <type>half</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    private static func compoundMetronomeMusicXML(beats: Int) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>\(beats) Eight Metronome</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes>
                <divisions>2</divisions>
                <time><beats>\(beats)</beats><beat-type>8</beat-type></time>
                <clef><sign>G</sign><line>2</line></clef>
              </attributes>
              <note>
                <pitch><step>C</step><octave>4</octave></pitch>
                <duration>\(beats)</duration>
                <voice>1</voice>
                <type>whole</type>
              </note>
            </measure>
          </part>
        </score-partwise>
        """.utf8)
    }

    private static var phase12SampleMusicXML: Data {
        repeatedC5MusicXML
    }

    private static var notationCoverageSampleMusicXML: Data {
        runtimeCoverageMusicXML
    }

    private static var s6NotationRefinementSampleMusicXML: Data {
        tupletRuntimeMusicXML
    }

    private static func score(tempoEvents: [TempoEvent]) -> ScoreDocument {
        ScoreDocument(parts: [
            ScorePart(id: "p1", measures: [
                Measure(
                    id: MeasureID(partIndex: 0, measureNumber: "1"),
                    number: "1",
                    notes: [],
                    tempoEvents: tempoEvents
                ),
            ]),
        ])
    }

    private static func quarterNotes(for time: MusicalTime) -> Double {
        Double(time.ticks) / Double(time.ticksPerQuarterNote)
    }

    static let repeatedC4MusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Repeated C4</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>6</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let repeatedC5MusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Repeated C5</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>3</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>half</type></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let runtimeCoverageMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Runtime Coverage</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>6</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>D</step><octave>3</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
        <measure number="9">
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>half</type></note>
          <note><rest/><duration>2</duration><voice>1</voice><type>half</type></note>
        </measure>
        <measure number="10">
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><chord/><pitch><step>C</step><octave>2</octave></pitch><duration>2</duration><voice>1</voice><type>half</type></note>
          <note><rest/><duration>2</duration><voice>1</voice><type>half</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let tupletRuntimeMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Tuplets</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>10</divisions>
            <time><beats>2</beats><beat-type>4</beat-type></time>
            <staves>2</staves>
            <clef number="1"><sign>G</sign><line>2</line></clef>
            <clef number="2"><sign>F</sign><line>4</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>5</actual-notes><normal-notes>2</normal-notes></time-modification><staff>1</staff></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>5</actual-notes><normal-notes>2</normal-notes></time-modification><staff>1</staff></note>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>5</actual-notes><normal-notes>2</normal-notes></time-modification><staff>1</staff></note>
          <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>5</actual-notes><normal-notes>2</normal-notes></time-modification><staff>1</staff></note>
          <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>5</actual-notes><normal-notes>2</normal-notes></time-modification><staff>1</staff></note>
        </measure>
        <measure number="2">
          <attributes><divisions>14</divisions></attributes>
          <note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>D</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>E</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>F</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>G</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>A</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
          <note><pitch><step>B</step><octave>3</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>7</actual-notes><normal-notes>2</normal-notes></time-modification><staff>2</staff></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let tieStopOnlyMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Tie</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note>
            <pitch><step>F</step><octave>4</octave></pitch>
            <duration>1</duration>
            <tie type="start"/>
            <voice>1</voice>
            <type>quarter</type>
          </note>
          <note>
            <pitch><step>F</step><octave>4</octave></pitch>
            <duration>1</duration>
            <tie type="stop"/>
            <voice>1</voice>
            <type>quarter</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let sixteenthNotesMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Short</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>4</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration>
            <voice>1</voice>
            <type>16th</type>
          </note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)
}

private final class MockPaletteAudioEngine: PaletteAudioEngine {
    private let startError: Error?
    private(set) var playedPitches: [[Int]] = []
    private(set) var playedDurations: [TimeInterval] = []
    private(set) var playedVelocities: [Double] = []
    private(set) var silenceCount = 0
    private(set) var lastFailure: Error?

    init(startError: Error? = nil) {
        self.startError = startError
    }

    var metronomeClickCount: Int {
        playedPitches.filter { $0 == [96] || $0 == [84] }.count
    }

    func start() throws {
        if let startError {
            lastFailure = startError
            throw startError
        }
        lastFailure = nil
    }

    func stop() {
        silence()
    }

    func silence() {
        silenceCount += 1
    }

    func play(midiPitches: [Int], duration: TimeInterval, velocity: Double) {
        playedPitches.append(midiPitches)
        playedDurations.append(duration)
        playedVelocities.append(velocity)
    }

    func play(event: PlaybackEvent, tempoBPM: Double, velocity: Double) {
        guard !event.midiPitches.isEmpty else {
            silence()
            return
        }
        play(midiPitches: event.midiPitches, duration: 0.5, velocity: velocity)
    }
}

private enum MockAudioError: Error {
    case startFailed
}

@Suite("Palette playback tempo override")
struct PalettePlaybackTempoOverrideTests {
    @Test @MainActor func manualTempoOverrideWinsOverParsedTempoMetadata() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "tempo.musicxml")
        let event = try #require(loaded.playbackEvents.first)
        let metadata = DoReMiRenderer().makePlaybackMetadata(score: Self.score(tempoEvents: [
            TempoEvent(bpm: 60, onset: event.onset, source: .sound),
        ]))
        let runtime = PalettePlaybackRuntime(events: [event], tempoBPM: 120)

        runtime.configure(events: [event], metadata: metadata)
        let metadataDuration = runtime.eventDurationSeconds(for: event)
        runtime.setTempoBPM(240)
        let manualDuration = runtime.eventDurationSeconds(for: event)

        #expect(manualDuration < metadataDuration)
    }

    @Test @MainActor func sessionLoadReflectsParsedTempoInPickerState() throws {
        let session = PaletteScoreSession()

        try session.load(data: PaletteScoreLoaderTests.tempoMusicXML, sourceName: "tempo.musicxml")

        #expect(session.playbackTempoBPM == 96)
    }

    private static func score(tempoEvents: [TempoEvent]) -> ScoreDocument {
        ScoreDocument(parts: [
            ScorePart(id: "p1", measures: [
                Measure(
                    id: MeasureID(partIndex: 0, measureNumber: "1"),
                    number: "1",
                    notes: [],
                    tempoEvents: tempoEvents
                ),
            ]),
        ])
    }
}
