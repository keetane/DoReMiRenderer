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

    @Test func restMissingAndOutOfRangeDoNotHighlight() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let highlighted = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [NoteID(rawValue: "missing")],
            range: 72...84
        )

        #expect(highlighted.isEmpty)
    }
}
