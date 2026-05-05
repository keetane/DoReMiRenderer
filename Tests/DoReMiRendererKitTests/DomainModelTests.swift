import Testing
@testable import DoReMiRendererKit

@Test func noteIDIncludesStaffAndOrdinalSoGrandStaffNotesDoNotCollide() {
    let onset = MusicalTime(ticks: 0, ticksPerQuarterNote: 4)
    let voice = VoiceID(rawValue: "1")

    let upperStaffID = NoteID(
        documentIndex: 0,
        partIndex: 0,
        measureIndex: 0,
        xmlNoteOrdinal: 0,
        voiceID: voice,
        staffID: StaffID(rawValue: "1"),
        onset: onset,
        chordOrdinal: 0
    )
    let lowerStaffID = NoteID(
        documentIndex: 0,
        partIndex: 0,
        measureIndex: 0,
        xmlNoteOrdinal: 1,
        voiceID: voice,
        staffID: StaffID(rawValue: "2"),
        onset: onset,
        chordOrdinal: 0
    )

    #expect(upperStaffID != lowerStaffID)
}

@Test func noteIDGenerationIsGloballyUniqueForLongStableInput() {
    let ids = (0..<128).map { ordinal in
        NoteID(
            documentIndex: 0,
            partIndex: ordinal % 2,
            measureIndex: ordinal / 4,
            xmlNoteOrdinal: ordinal,
            voiceID: VoiceID(rawValue: String(ordinal % 3)),
            staffID: StaffID(rawValue: String((ordinal % 2) + 1)),
            onset: MusicalTime(ticks: ordinal * 2, ticksPerQuarterNote: 4),
            chordOrdinal: ordinal % 4
        )
    }

    #expect(Set(ids).count == ids.count)
}

@Test func noteIDGenerationIsDeterministicForSameInputs() {
    func makeIDs() -> [NoteID] {
        (0..<32).map { ordinal in
            NoteID(
                documentIndex: 0,
                partIndex: 0,
                measureIndex: ordinal / 4,
                xmlNoteOrdinal: ordinal,
                voiceID: VoiceID(rawValue: "1"),
                staffID: StaffID(rawValue: "1"),
                onset: MusicalTime(ticks: ordinal, ticksPerQuarterNote: 4),
                chordOrdinal: 0
            )
        }
    }

    #expect(makeIDs() == makeIDs())
}

@Test func musicalTimeSupportsComparisonAndArithmeticAcrossDivisions() {
    let quarterAtFour = MusicalTime(ticks: 4, ticksPerQuarterNote: 4)
    let eighthAtEight = MusicalTime(ticks: 4, ticksPerQuarterNote: 8)
    let result = quarterAtFour + eighthAtEight

    #expect(eighthAtEight < quarterAtFour)
    #expect(result == MusicalTime(ticks: 12, ticksPerQuarterNote: 8))
    #expect(result - eighthAtEight == MusicalTime(ticks: 8, ticksPerQuarterNote: 8))
}

@Test func musicalTimeEqualityAndHashingUseMusicalValue() {
    let halfAtTwo = MusicalTime(ticks: 1, ticksPerQuarterNote: 2)
    let halfAtFour = MusicalTime(ticks: 2, ticksPerQuarterNote: 4)

    #expect(halfAtTwo == halfAtFour)
    #expect(Set([halfAtTwo, halfAtFour]).count == 1)
}

@Test func scaleColorPaletteIgnoresAccidentalsForPitchClassInMVP0() {
    let palette = defaultEducationalPalette

    #expect(palette.color(for: Pitch(step: .c, octave: 4)) == palette.c)
    #expect(palette.color(for: Pitch(step: .c, octave: 4, alter: 1)) == palette.c)
    #expect(palette.color(for: Pitch(step: .c, octave: 4, alter: -1)) == palette.c)
}

@Test func pitchClassNoteColorRuleUsesBasicPitchClass() {
    let note = ScoreNote(
        id: NoteID(rawValue: "n0"),
        pitch: Pitch(step: .g, octave: 4, alter: 1),
        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: StaffID(rawValue: "1")
    )
    let context = ColorContext(score: ScoreDocument(parts: []), layout: ScoreLayout())

    #expect(PitchClassNoteColorRule(palette: defaultEducationalPalette).color(for: note, layout: nil, context: context) == defaultEducationalPalette.g)
}

@Test func clefAwareStaffLineRuleUsesTrebleAndBassLinePitchClasses() {
    let rule = ClefAwareStaffLineColorRule(defaultPalette: defaultEducationalPalette)
    let context = ColorContext(score: ScoreDocument(parts: []), layout: ScoreLayout())
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")

    let trebleBottom = StaffLineLayout(
        id: ScoreElementID(rawValue: "treble.line.0"),
        staffID: staffID,
        measureID: measureID,
        lineIndex: 0,
        clefKind: .treble
    )
    let bassTop = StaffLineLayout(
        id: ScoreElementID(rawValue: "bass.line.4"),
        staffID: staffID,
        measureID: measureID,
        lineIndex: 4,
        clefKind: .bass
    )

    #expect(rule.color(for: trebleBottom, context: context) == defaultEducationalPalette.e)
    #expect(rule.color(for: bassTop, context: context) == defaultEducationalPalette.a)
}
