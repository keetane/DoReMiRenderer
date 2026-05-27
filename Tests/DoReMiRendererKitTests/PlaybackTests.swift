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

@Test func playbackMergesMultiplePartsByMeasureAndOnset() {
    let score = multiPartPlaybackScore(
        part1Notes: [
            playbackNote(id: "p1-m1-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
            playbackNote(id: "p1-m1-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
        ],
        part2Notes: [
            playbackNote(id: "p2-m1-a", pitch: Pitch(step: .e, octave: 3), onsetTicks: 0),
            playbackNote(id: "p2-m1-b", pitch: Pitch(step: .f, octave: 3), onsetTicks: 4),
        ]
    )

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].measureID == MeasureID(partIndex: 0, measureNumber: "1"))
    #expect(events[0].noteIDs == [NoteID(rawValue: "p1-m1-a"), NoteID(rawValue: "p2-m1-a")])
    #expect(events[0].midiPitches == [60, 52])
    #expect(events[1].noteIDs == [NoteID(rawValue: "p1-m1-b"), NoteID(rawValue: "p2-m1-b")])
    #expect(events[1].midiPitches == [62, 53])
}

@Test func playbackOrdersInterleavedMultiplePartOnsetsByMusicalTime() {
    let score = multiPartPlaybackScore(
        part1Notes: [
            playbackNote(id: "p1-first", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
            playbackNote(id: "p1-third", pitch: Pitch(step: .g, octave: 4), onsetTicks: 8),
        ],
        part2Notes: [
            playbackNote(id: "p2-second", pitch: Pitch(step: .e, octave: 3), onsetTicks: 4),
        ]
    )

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.map(\.noteIDs) == [
        [NoteID(rawValue: "p1-first")],
        [NoteID(rawValue: "p2-second")],
        [NoteID(rawValue: "p1-third")],
    ])
    #expect(events.map(\.onset) == [
        MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
    ])
}

@Test func playbackTieDurationDoesNotCrossPartBoundaries() {
    let score = multiPartPlaybackScore(
        part1Notes: [
            playbackNote(id: "p1-tie-start", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, ties: [.start]),
        ],
        part2Notes: [
            playbackNote(id: "p2-tie-stop", pitch: Pitch(step: .c, octave: 4), onsetTicks: 4, ties: [.stop]),
        ]
    )

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].noteIDs == [NoteID(rawValue: "p1-tie-start")])
    #expect(events[0].midiPitchDurations[60] == MusicalTime(ticks: 4, ticksPerQuarterNote: 4))
    #expect(events[1].noteIDs == [NoteID(rawValue: "p2-tie-stop")])
    #expect(events[1].isTiedContinuation)
}

@Test func playbackMarksTieStopOnlyAsContinuation() {
    let score = playbackScore(notes: [
        playbackNote(id: "tie-start", pitch: Pitch(step: .f, octave: 4), onsetTicks: 0, ties: [.start]),
        playbackNote(id: "tie-stop", pitch: Pitch(step: .f, octave: 4), onsetTicks: 4, ties: [.stop]),
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.count == 2)
    #expect(events[0].isTiedContinuation == false)
    #expect(events[0].midiPitchDurations[65] == MusicalTime(ticks: 8, ticksPerQuarterNote: 4))
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

@Test func playbackExpandsSimpleStartEndRepeat() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [],
        [RepeatBarline(direction: .forward)],
        [RepeatBarline(direction: .backward)],
        [],
    ])

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.2", "0.3", "0.4"])
    #expect(events.map { $0.noteIDs.first?.rawValue } == ["m1", "m2", "m3", "m2", "m3", "m4"])
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m2")] }.count == 2)
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m3")] }.count == 2)
}

@Test func playbackRepeatExpansionCanBeDisabled() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [],
        [RepeatBarline(direction: .forward)],
        [RepeatBarline(direction: .backward)],
        [],
    ])

    let events = PlaybackSequenceBuilder().build(
        score: score,
        options: PlaybackOptions(expandRepeats: false)
    )

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4"])
}

@Test func playbackRepeatEndWithoutStartFallsBackToBeginningAndWarns() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [],
        [],
        [RepeatBarline(direction: .backward)],
        [],
    ])
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.1", "0.2", "0.3", "0.4"])
    #expect(metadata.diagnostics.contains { $0.code == "repeat.startMissingFallback" })
}

@Test func playbackRepeatStartWithoutEndWarnsWithoutExpansion() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [],
        [RepeatBarline(direction: .forward)],
        [],
        [],
    ])
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4"])
    #expect(metadata.diagnostics.contains { $0.code == "repeat.startWithoutEndUnsupported" })
}

@Test func playbackRepeatCountThreeUsesThreePasses() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [RepeatBarline(direction: .forward)],
        [RepeatBarline(direction: .backward, times: 3)],
        [],
        [],
    ])
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.1", "0.2", "0.1", "0.2", "0.3", "0.4"])
    #expect(!metadata.diagnostics.contains { $0.code == "repeat.countUnsupported" })
}

@Test func playbackNestedRepeatEmitsDiagnostic() {
    let score = repeatPlaybackScore(measureRepeatBarlines: [
        [RepeatBarline(direction: .forward)],
        [RepeatBarline(direction: .forward)],
        [RepeatBarline(direction: .backward)],
        [],
    ])

    let metadata = PlaybackSequenceBuilder().metadata(score: score)

    #expect(metadata.diagnostics.contains { $0.code == "repeat.nestedUnsupported" })
}

@Test func playbackExpandsFirstAndSecondEndingsInExpectedOrder() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [
            [],
            [RepeatBarline(direction: .forward)],
            [],
            [RepeatBarline(direction: .backward)],
            [],
            [],
        ],
        measureRepeatEndings: [
            [],
            [],
            [],
            [RepeatEnding(numbers: [1], kind: .start), RepeatEnding(numbers: [1], kind: .stop)],
            [RepeatEnding(numbers: [2], kind: .start), RepeatEnding(numbers: [2], kind: .stop)],
            [],
        ]
    )

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3", "0.5", "0.6"])
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m2")] }.count == 2)
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m3")] }.count == 2)
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m4")] }.count == 1)
    #expect(events.filter { $0.noteIDs == [NoteID(rawValue: "m5")] }.count == 1)
}

@Test func playbackEndingWithoutRepeatEmitsDiagnostic() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], []],
        measureRepeatEndings: [
            [],
            [RepeatEnding(numbers: [1], kind: .start)],
            [],
        ]
    )

    let metadata = PlaybackSequenceBuilder().metadata(score: score)

    #expect(metadata.diagnostics.contains { $0.code == "repeat.endingWithoutRepeat" })
}

@Test func playbackMissingSecondEndingEmitsDiagnosticAndUsesSimpleRepeatFallback() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [
            [RepeatBarline(direction: .forward)],
            [RepeatBarline(direction: .backward)],
            [],
        ],
        measureRepeatEndings: [
            [],
            [RepeatEnding(numbers: [1], kind: .start), RepeatEnding(numbers: [1], kind: .stop)],
            [],
        ]
    )
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.1", "0.2", "0.3"])
    #expect(metadata.diagnostics.contains { $0.code == "repeat.endingSecondMissing" })
}

@Test func playbackRepeatEndingBeyondSecondEmitsDiagnostic() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [
            [RepeatBarline(direction: .forward)],
            [RepeatBarline(direction: .backward)],
            [],
        ],
        measureRepeatEndings: [
            [],
            [RepeatEnding(numbers: [3], kind: .start)],
            [],
        ]
    )

    let metadata = PlaybackSequenceBuilder().metadata(score: score)

    #expect(metadata.diagnostics.contains { $0.code == "repeat.endingNumberUnsupported" })
}

@Test func playbackDaCapoAlFineExpandsBasicJumpOnlySequence() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], [], []],
        measureJumpMarkers: [
            [PlaybackJumpMarker(kind: .fine, text: "Fine")],
            [],
            [],
            [PlaybackJumpMarker(kind: .daCapoAlFine, text: "D.C. al Fine")],
        ]
    )

    let events = PlaybackSequenceBuilder().build(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4", "0.1"])
}

@Test func playbackUnsupportedJumpMarkersEmitSpecificDiagnostics() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], []],
        measureJumpMarkers: [
            [PlaybackJumpMarker(kind: .segno, text: "Segno")],
            [PlaybackJumpMarker(kind: .dalSegno, text: "D.S.")],
            [PlaybackJumpMarker(kind: .toCoda, text: "To Coda")],
        ]
    )

    let metadata = PlaybackSequenceBuilder().metadata(score: score)

    #expect(metadata.diagnostics.contains { $0.code == "jump.dalSegnoUnsupported" })
    #expect(metadata.diagnostics.contains { $0.code == "jump.codaUnsupported" })
}

@Test func playbackDalSegnoAlFineExpandsBasicJumpOnlySequence() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], [], []],
        measureJumpMarkers: [
            [],
            [PlaybackJumpMarker(kind: .segno, text: "Segno")],
            [PlaybackJumpMarker(kind: .fine, text: "Fine")],
            [PlaybackJumpMarker(kind: .dalSegnoAlFine, text: "D.S. al Fine")],
        ]
    )
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3"])
    #expect(!metadata.diagnostics.contains { $0.code == "jump.dalSegnoUnsupported" })
}

@Test func playbackDaCapoAlCodaExpandsBasicJumpOnlySequence() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], [], [], []],
        measureJumpMarkers: [
            [],
            [PlaybackJumpMarker(kind: .toCoda, text: "To Coda")],
            [PlaybackJumpMarker(kind: .daCapoAlCoda, text: "D.C. al Coda")],
            [PlaybackJumpMarker(kind: .coda, text: "Coda")],
            [],
        ]
    )
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.1", "0.2", "0.4", "0.5"])
    #expect(!metadata.diagnostics.contains { $0.code == "jump.codaUnsupported" })
}

@Test func playbackDalSegnoAlCodaExpandsBasicJumpOnlySequence() {
    let score = repeatPlaybackScore(
        measureRepeatBarlines: [[], [], [], [], [], []],
        measureJumpMarkers: [
            [],
            [PlaybackJumpMarker(kind: .segno, text: "Segno")],
            [PlaybackJumpMarker(kind: .toCoda, text: "To Coda")],
            [PlaybackJumpMarker(kind: .dalSegnoAlCoda, text: "D.S. al Coda")],
            [PlaybackJumpMarker(kind: .coda, text: "Coda")],
            [],
        ]
    )
    let builder = PlaybackSequenceBuilder()

    let events = builder.build(score: score)
    let metadata = builder.metadata(score: score)

    #expect(events.map(\.measureID.rawValue) == ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3", "0.5", "0.6"])
    #expect(!metadata.diagnostics.contains { $0.code == "jump.codaUnsupported" })
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

private func multiPartPlaybackScore(part1Notes: [ScoreNote], part2Notes: [ScoreNote]) -> ScoreDocument {
    ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: part1Notes,
                clef: Clef(kind: .treble)
            ),
        ]),
        ScorePart(id: "p2", measures: [
            Measure(
                id: MeasureID(partIndex: 1, measureNumber: "1"),
                number: "1",
                notes: part2Notes,
                clef: Clef(kind: .bass)
            ),
        ]),
    ])
}

private func repeatPlaybackScore(
    measureRepeatBarlines: [[RepeatBarline]],
    measureRepeatEndings: [[RepeatEnding]]? = nil,
    measureJumpMarkers: [[PlaybackJumpMarker]]? = nil
) -> ScoreDocument {
    let measures = measureRepeatBarlines.enumerated().map { index, repeatBarlines in
        let measureNumber = "\(index + 1)"
        return Measure(
            id: MeasureID(partIndex: 0, measureNumber: measureNumber),
            number: measureNumber,
            notes: [
                playbackNote(
                    id: "m\(measureNumber)",
                    pitch: Pitch(step: .c, octave: 4 + index % 2),
                    onsetTicks: 0
                ),
            ],
            clef: Clef(kind: .treble),
            repeatBarlines: repeatBarlines,
            repeatEndings: measureRepeatEndings?[index] ?? [],
            playbackJumpMarkers: measureJumpMarkers?[index] ?? []
        )
    }
    return ScoreDocument(parts: [
        ScorePart(id: "p1", measures: measures),
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
