import DoReMiRendererKit
import Testing
@testable import DoReMiPalette

@Suite("Keyboard pitch mapping")
struct KeyboardPitchMapperTests {
    @Test func mapsPitchToMIDINumber() {
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .a, octave: 0)) == 21)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .c, octave: 4)) == 60)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .c, octave: 4, alter: 1)) == 61)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .d, octave: 4, alter: -1)) == 61)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .b, octave: 3, alter: 1)) == 60)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .c, octave: 4, alter: -1)) == 59)
    }

    @Test func naturalPitchClassesMapToExpectedWhiteKeys() {
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .c, octave: 4)) == 60)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .d, octave: 4)) == 62)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .e, octave: 4)) == 64)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .f, octave: 4)) == 65)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .g, octave: 4)) == 67)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .a, octave: 4)) == 69)
        #expect(KeyboardPitchMapper.midiNumber(for: Pitch(step: .b, octave: 4)) == 71)
    }

    @Test func classifiesBlackKeys() {
        #expect(!KeyboardPitchMapper.isBlackKey(midi: 60))
        #expect(KeyboardPitchMapper.isBlackKey(midi: 61))
        #expect(KeyboardPitchMapper.isBlackKey(midi: 63))
        #expect(!KeyboardPitchMapper.isBlackKey(midi: 64))
    }

    @Test func highlightedKeysUseLayoutPitchLookup() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let highlighted = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [firstNoteID],
            range: 36...84
        )

        #expect(highlighted == [60])
    }

    @Test func changingCurrentNoteIDChangesHighlightedKey() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let secondNoteID = try #require(loaded.playbackEvents.dropFirst().first?.noteIDs.first)

        let firstHighlight = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [firstNoteID],
            range: 36...84
        )
        let secondHighlight = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [secondNoteID],
            range: 36...84
        )

        #expect(firstHighlight == [60])
        #expect(secondHighlight == [62])
    }

    @Test func chordHighlightsAllCurrentNoteIDsInMVP() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.chordMusicXML, sourceName: "chord.musicxml")
        let noteIDs = Set(try #require(loaded.playbackEvents.first?.noteIDs))

        let highlighted = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: noteIDs,
            range: 36...84
        )

        #expect(highlighted == [60, 64])
    }

    @Test func classifiedHighlightStateKeepsAttackAndContinuationPitchesSeparate() throws {
        let loaded = try PaletteScoreLoader().load(
            data: PaletteScoreLoaderTests.mixedTieContinuationAndAttackMusicXML,
            sourceName: "mixed-tie.musicxml"
        )
        let mixedEvent = try #require(loaded.playbackEvents.first {
            $0.midiPitches == [69] && $0.noteIDs.count > $0.midiPitches.count
        })

        let highlight = CurrentNoteHighlightState.make(event: mixedEvent, layout: loaded.layout)

        #expect(highlight.attackMIDIPitches == [69])
        #expect(highlight.continuationMIDIPitches.contains(48))
        #expect(highlight.continuationMIDIPitches.intersection(highlight.attackMIDIPitches).isEmpty)
    }

    @Test func classifiedHighlightStateTreatsDuplicatePitchAsAttackPriority() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.chordMusicXML, sourceName: "chord.musicxml")
        let event = try #require(loaded.playbackEvents.first)
        let highlight = CurrentNoteHighlightState.make(event: event, layout: loaded.layout)

        #expect(highlight.attackMIDIPitches == [60, 64])
        #expect(highlight.continuationMIDIPitches.isEmpty)
    }

    @Test func currentNoteVisibilityCanSuppressScoreAndKeyboardHighlights() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let event = try #require(loaded.playbackEvents.first)
        let highlight = CurrentNoteHighlightState.make(event: event, layout: loaded.layout)

        #expect(!highlight.attackNoteIDs.isEmpty)
        #expect(!highlight.attackMIDIPitches.isEmpty)

        let hidden = highlight.visible(if: false)

        #expect(hidden.attackNoteIDs.isEmpty)
        #expect(hidden.continuationNoteIDs.isEmpty)
        #expect(hidden.attackMIDIPitches.isEmpty)
        #expect(hidden.continuationMIDIPitches.isEmpty)
        #expect(hidden.scoreFollowNoteIDs.isEmpty)
        #expect(hidden.isRest)
    }

    @Test func restMissingAndOutOfRangeDoNotHighlight() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let highlighted = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [NoteID(rawValue: "missing")],
            range: 72...84
        )

        #expect(highlighted.isEmpty)
    }

    @Test func practiceNoteNamesMapToSolfege() {
        #expect(PracticeNoteNameFormatter.englishName(for: Pitch(step: .c, octave: 4)) == "C4")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .c, octave: 4)) == "ド")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .d, octave: 4)) == "レ")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .e, octave: 4)) == "ミ")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .f, octave: 4)) == "ファ")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .g, octave: 4)) == "ソ")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .a, octave: 4)) == "ラ")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .b, octave: 4)) == "シ")
    }

    @Test func practiceNoteNamesIncludeAccidentalsAndChords() throws {
        #expect(PracticeNoteNameFormatter.englishName(for: Pitch(step: .c, octave: 4, alter: 1)) == "C#4")
        #expect(PracticeNoteNameFormatter.solfegeName(for: Pitch(step: .d, octave: 4, alter: -1)) == "レb")

        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.chordMusicXML, sourceName: "chord.musicxml")
        let noteIDs = Set(try #require(loaded.playbackEvents.first?.noteIDs))
        let display = PracticeNoteNameFormatter.display(layout: loaded.layout, noteIDs: noteIDs)

        #expect(display.summary.contains("Chord:"))
        #expect(display.englishName.contains("C4"))
        #expect(display.englishName.contains("E4"))
    }

    @Test func practiceRestDisplayIsStable() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let display = PracticeNoteNameFormatter.display(
            layout: loaded.layout,
            noteIDs: []
        )

        #expect(display == .rest)
        #expect(display.summary == "休符")
    }
}
