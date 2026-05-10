import Testing
@testable import DoReMiRendererKit

@Test func playbackEventsAreSortedByOnset() {
    let score = playbackScore(notes: [
        playbackNote(id: "late", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8),
        playbackNote(id: "early", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        playbackNote(id: "middle", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.map(\.noteIDs) == [
        [NoteID(rawValue: "early")],
        [NoteID(rawValue: "middle")],
        [NoteID(rawValue: "late")],
    ])
    #expect(events.map(\.onset) == [
        MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
    ])
}

@Test func playbackGroupsChordTonesAtSameOnsetIntoOneEvent() {
    let score = playbackScore(notes: [
        playbackNote(id: "root", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        playbackNote(id: "third", pitch: Pitch(step: .e, octave: 4), onsetTicks: 0, isChordTone: true, chordOrdinal: 1),
        playbackNote(id: "next", pitch: Pitch(step: .g, octave: 4), onsetTicks: 4),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].noteIDs == [NoteID(rawValue: "root"), NoteID(rawValue: "third")])
    #expect(events[0].midiPitches == [60, 64])
    #expect(events[1].noteIDs == [NoteID(rawValue: "next")])
}

@Test func playbackExcludesRestsByDefault() {
    let score = playbackScore(notes: [
        playbackNote(id: "note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        playbackNote(id: "rest", pitch: nil, onsetTicks: 4),
    ])

    let events = PlaybackSequenceBuilder().build(score: score, options: .default)

    #expect(events.map(\.noteIDs) == [[NoteID(rawValue: "note")]])
}

@Test func playbackIncludesRestsWhenOptionIsEnabled() {
    let score = playbackScore(notes: [
        playbackNote(id: "note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        playbackNote(id: "rest", pitch: nil, onsetTicks: 4),
    ])

    let events = PlaybackSequenceBuilder().build(score: score, options: PlaybackOptions(includeRests: true))

    #expect(events.map(\.noteIDs) == [
        [NoteID(rawValue: "note")],
        [NoteID(rawValue: "rest")],
    ])
    #expect(events[1].midiPitches.isEmpty)
    #expect(events[1].staffIDs == [StaffID(rawValue: "1")])
}

@Test func playbackMixedRestAndAttackUsesAttackDuration() {
    let score = playbackScore(notes: [
        playbackNote(id: "half-note", pitch: Pitch(step: .e, octave: 5), onsetTicks: 0, durationTicks: 16),
        playbackNote(id: "whole-rest", pitch: nil, onsetTicks: 0, durationTicks: 32),
        playbackNote(id: "later-rest", pitch: nil, onsetTicks: 16, durationTicks: 16),
    ])

    let events = PlaybackSequenceBuilder().build(score: score, options: PlaybackOptions(includeRests: true))

    #expect(events.count == 2)
    #expect(events[0].noteIDs == [NoteID(rawValue: "half-note"), NoteID(rawValue: "whole-rest")])
    #expect(events[0].nominalDuration == MusicalTime(ticks: 16, ticksPerQuarterNote: 4))
    #expect(events[0].midiPitchDurations[76] == MusicalTime(ticks: 16, ticksPerQuarterNote: 4))
    #expect(events[1].midiPitches.isEmpty)
}

@Test func playbackMixedPitchDurationsAreRetainedPerMIDIPitch() {
    let score = playbackScore(notes: [
        playbackNote(id: "quarter-c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 8),
        playbackNote(id: "whole-c2", pitch: Pitch(step: .c, octave: 2), onsetTicks: 0, durationTicks: 32),
        playbackNote(id: "next-c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 8, durationTicks: 8),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].midiPitches == [60, 36])
    #expect(events[0].nominalDuration == MusicalTime(ticks: 32, ticksPerQuarterNote: 4))
    #expect(events[0].midiPitchDurations[60] == MusicalTime(ticks: 8, ticksPerQuarterNote: 4))
    #expect(events[0].midiPitchDurations[36] == MusicalTime(ticks: 32, ticksPerQuarterNote: 4))
}

@Test func playbackMarksTieStopOnlyAsContinuation() {
    let score = playbackScore(notes: [
        playbackNote(id: "tie-start", pitch: Pitch(step: .f, octave: 4), onsetTicks: 0, ties: [.start]),
        playbackNote(id: "tie-stop", pitch: Pitch(step: .f, octave: 4), onsetTicks: 4, ties: [.stop]),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].isTiedContinuation == false)
    #expect(events[1].isTiedContinuation == true)
    #expect(events[1].midiPitches.isEmpty)
}

@Test func playbackExcludesTieStopOnlyPitchFromMixedOnsetAttack() {
    let score = playbackScore(notes: [
        playbackNote(id: "held-start", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, ties: [.start]),
        playbackNote(id: "held-stop", pitch: Pitch(step: .c, octave: 3), onsetTicks: 4, ties: [.stop]),
        playbackNote(id: "new-attack", pitch: Pitch(step: .a, octave: 4), onsetTicks: 4),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[1].noteIDs == [NoteID(rawValue: "held-stop"), NoteID(rawValue: "new-attack")])
    #expect(events[1].midiPitches == [69])
    #expect(events[1].isTiedContinuation == false)
}

@Test func doReMiRendererFacadeBuildsPlaybackSequence() {
    let score = playbackScore(notes: [
        playbackNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ])

    let events = DoReMiRenderer().makePlaybackSequence(score: score)

    #expect(events.count == 1)
    #expect(events[0].noteIDs == [NoteID(rawValue: "n0")])
    #expect(events[0].midiPitches == [60])
}

@Test func colorRuleChangesDoNotChangePlaybackEvents() throws {
    let score = playbackScore(notes: [
        playbackNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        playbackNote(id: "n1", pitch: Pitch(step: .e, octave: 4), onsetTicks: 0, isChordTone: true, chordOrdinal: 1),
        playbackNote(id: "n2", pitch: Pitch(step: .g, octave: 4), onsetTicks: 4),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    let builder = PlaybackSequenceBuilder()
    let baseline = builder.build(score: score)
    let styles = [
        ScoreStyle(staffLineStyle: .monochrome(.black), noteColorStyle: .monochrome(.black)),
        ScoreStyle(
            staffLineStyle: .rule(ClefAwareStaffLineColorRule(defaultPalette: defaultEducationalPalette)),
            noteColorStyle: .rule(PitchClassNoteColorRule(palette: defaultEducationalPalette))
        ),
        ScoreStyle(
            staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
            noteColorStyle: .pitchClass(defaultEducationalPalette)
        ),
    ]

    for style in styles {
        _ = layout.elements.map {
            style.colorResolver.resolvedStyle(
                for: $0,
                score: score,
                layout: layout,
                style: style,
                selection: nil as ScoreSelection?
            )
        }
        #expect(builder.build(score: score) == baseline)
    }
}

private func playbackScore(notes: [ScoreNote]) -> ScoreDocument {
    ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: notes,
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
}

private func playbackNote(
    id: String,
    pitch: Pitch?,
    onsetTicks: Int,
    durationTicks: Int = 4,
    isChordTone: Bool = false,
    chordOrdinal: Int = 0,
    ties: [MusicXMLTieKind] = []
) -> ScoreNote {
    ScoreNote(
        id: NoteID(rawValue: id),
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: durationTicks, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: StaffID(rawValue: "1"),
        isChordTone: isChordTone,
        chordOrdinal: chordOrdinal,
        ties: ties
    )
}
