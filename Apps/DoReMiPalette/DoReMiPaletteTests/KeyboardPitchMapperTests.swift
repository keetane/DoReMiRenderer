import DoReMiRendererKit
import Foundation
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

    @Test func keyboardLineNumbersUseC4AsZeroAndIncreaseByStaffLineDistance() {
        #expect(KeyboardLineNumber.number(for: 60) == 0) // C4
        #expect(KeyboardLineNumber.number(for: 64) == 1) // E4
        #expect(KeyboardLineNumber.number(for: 57) == 1) // A3
        #expect(KeyboardLineNumber.number(for: 67) == 2) // G4
        #expect(KeyboardLineNumber.number(for: 53) == 2) // F3
        #expect(KeyboardLineNumber.number(for: 71) == 3) // B4
        #expect(KeyboardLineNumber.number(for: 50) == 3) // D3
        #expect(KeyboardLineNumber.number(for: 72) == nil) // C5 space
        #expect(KeyboardLineNumber.number(for: 48) == nil) // C3 space
        #expect(KeyboardLineNumber.number(for: 62) == nil) // D4 is a space note
        #expect(KeyboardLineNumber.number(for: 61) == nil) // C#4 is not a white-key staff line
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

    @Test func highlightedKeysApplyTransposeWithoutChangingNoteIDs() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let highlighted = KeyboardPitchMapper.highlightedMIDINumbers(
            layout: loaded.layout,
            currentNoteIDs: [firstNoteID],
            range: 36...84,
            transposeSemitones: 2
        )

        #expect(highlighted == [62])
        #expect(loaded.layout.noteLayout(for: firstNoteID)?.noteID == firstNoteID)
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

    @Test func playbackCursorExposesNextPitchedEventForKeyboardPreview() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.threeNoteMusicXML, sourceName: "three-notes.musicxml")
        var cursor = PalettePlaybackCursor(events: loaded.playbackEvents)

        #expect(cursor.currentEvent?.midiPitches == [60])
        #expect(cursor.nextPitchedEvent?.midiPitches == [62])

        cursor.move(by: 1)

        #expect(cursor.currentEvent?.midiPitches == [62])
        #expect(cursor.nextPitchedEvent?.midiPitches == [64])
    }

    @Test func playbackCursorSkipsRestsForNextPitchedEvent() throws {
        let renderer = DoReMiRenderer()
        let score = try renderer.parseMusicXML(data: Self.restBetweenNotesMusicXML)
        let events = renderer.makePlaybackSequence(score: score, options: PlaybackOptions(includeRests: true))
        let firstRestIndex = try #require(events.firstIndex { $0.midiPitches.isEmpty })
        let precedingIndex = max(firstRestIndex - 1, 0)
        let cursor = PalettePlaybackCursor(events: events)
        var moved = cursor
        moved.setIndex(precedingIndex)

        #expect(events[firstRestIndex].midiPitches.isEmpty)
        #expect(moved.nextPitchedEvent?.midiPitches.isEmpty == false)
    }

    private static let threeNoteMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="3.1">
      <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
      <part id="P1"><measure number="1">
        <attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
      </measure></part>
    </score-partwise>
    """.utf8)

    private static let restBetweenNotesMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="3.1">
      <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
      <part id="P1"><measure number="1">
        <attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
        <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
      </measure></part>
    </score-partwise>
    """.utf8)

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

    @Test func classifiedHighlightStateTransposesKeyboardPitchesOnly() throws {
        let loaded = try PaletteScoreLoader().load(
            data: PaletteScoreLoaderTests.mixedTieContinuationAndAttackMusicXML,
            sourceName: "mixed-tie.musicxml"
        )
        let mixedEvent = try #require(loaded.playbackEvents.first {
            $0.midiPitches == [69] && $0.noteIDs.count > $0.midiPitches.count
        })

        let highlight = CurrentNoteHighlightState.make(event: mixedEvent, layout: loaded.layout, transposeSemitones: 2)

        #expect(highlight.attackMIDIPitches == [71])
        #expect(highlight.continuationMIDIPitches.contains(50))
        #expect(!highlight.attackNoteIDs.isEmpty)
        #expect(!highlight.continuationNoteIDs.isEmpty)
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

        #expect(!display.summary.contains("Chord:"))
        #expect(display.englishName.contains("C4"))
        #expect(display.englishName.contains("E4"))
    }

    @Test func practiceNoteNamesIncludeSoundingPitchWhenTransposed() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let display = PracticeNoteNameFormatter.display(
            layout: loaded.layout,
            noteIDs: [firstNoteID],
            transposeSemitones: 2
        )

        #expect(display.englishName == "C4")
        #expect(display.soundingEnglishName == "D4")
        #expect(display.summary.contains("C4"))
        #expect(display.summary.contains("D4"))
        #expect(display.transposeDescription == "+2")
    }

    @Test func keyDisplayShowsWrittenAndSoundingKeys() {
        let cMajor = PaletteKeyDisplay.make(
            keySignature: KeySignature(fifths: 0, mode: "major"),
            transposeSemitones: 2
        )
        let dMajor = PaletteKeyDisplay.make(
            keySignature: KeySignature(fifths: 2, mode: "major"),
            transposeSemitones: -2
        )
        let aMinor = PaletteKeyDisplay.make(
            keySignature: KeySignature(fifths: 0, mode: "minor"),
            transposeSemitones: 2
        )
        let cMajorUpSemitone = PaletteKeyDisplay.make(
            keySignature: KeySignature(fifths: 0, mode: "major"),
            transposeSemitones: 1,
            displayTransposeEnabled: true
        )

        #expect(cMajor.writtenKey == "C major")
        #expect(cMajor.soundingKey == "D major")
        #expect(dMajor.writtenKey == "D major")
        #expect(dMajor.soundingKey == "C major")
        #expect(aMinor.writtenKey == "A minor")
        #expect(aMinor.soundingKey == "B minor")
        #expect(cMajorUpSemitone.displayKey == "Db major")
    }

    @Test func transposeKeyPickerMapsTargetKeysToNearestSemitoneOffset() {
        #expect(PaletteTranspose.selectedTargetPitchClass(writtenPitchClass: 0, transposeSemitones: 2) == 2)
        #expect(PaletteTranspose.semitones(fromWrittenPitchClass: 0, toTargetPitchClass: 2) == 2)
        #expect(PaletteTranspose.semitones(fromWrittenPitchClass: 7, toTargetPitchClass: 2) == -5)
        #expect(PaletteTranspose.semitones(fromWrittenPitchClass: nil, toTargetPitchClass: 11) == -1)
        #expect(PaletteTranspose.keyName(forPitchClass: 1) == "C#/Db")
        #expect(PaletteTranspose.keyName(forPitchClass: -1) == "B")
        #expect(PaletteTranspose.relativeMinorName(forMajorPitchClass: 0) == "Am")
        #expect(PaletteTranspose.relativeMinorName(forMajorPitchClass: 7) == "Em")
        #expect(PaletteTranspose.relativeMinorName(forMajorPitchClass: 5) == "Dm")
    }

    @Test func pitchClassColorStateDefaultsPersistsAndTogglesPitchClasses() {
        let allOn = PalettePitchClassColorState(encodedValue: PalettePitchClassColorState.defaultEncodedValue)
        #expect(allOn.enabledPitchClasses.count == 12)
        #expect(allOn.isEnabled(pitchClass: 0))
        #expect(allOn.isEnabled(pitchClass: 11))

        let cOff = allOn.toggled(0)
        #expect(!cOff.isEnabled(pitchClass: 0))
        #expect(cOff.isEnabled(pitchClass: 1))
        #expect(PalettePitchClassColorState(encodedValue: cOff.encodedValue) == cOff)
        #expect(PalettePitchClassColorState.allOff.enabledPitchClasses.isEmpty)
        #expect(PalettePitchClassColorState.label(for: 10) == "A#")
    }

    @Test func pitchClassColorStateStaffLinePresetEnablesOnlyStaffLineButtonColors() {
        let lineOnly = PalettePitchClassColorState.staffLineOnly

        #expect(lineOnly.isEnabled(midi: 36)) // C2
        #expect(lineOnly.isEnabled(midi: 40)) // E2
        #expect(lineOnly.isEnabled(midi: 43)) // G2
        #expect(lineOnly.isEnabled(midi: 47)) // B2
        #expect(lineOnly.isEnabled(midi: 50)) // D3
        #expect(lineOnly.isEnabled(midi: 53)) // F3
        #expect(lineOnly.isEnabled(midi: 57)) // A3
        #expect(lineOnly.isEnabled(midi: 60)) // C4
        #expect(lineOnly.isEnabled(midi: 64)) // E4
        #expect(lineOnly.isEnabled(midi: 67)) // G4
        #expect(lineOnly.isEnabled(midi: 71)) // B4
        #expect(lineOnly.isEnabled(midi: 74)) // D5
        #expect(lineOnly.isEnabled(midi: 77)) // F5
        #expect(lineOnly.isEnabled(midi: 81)) // A5
        #expect(lineOnly.isEnabled(midi: 84)) // C6
        #expect(!lineOnly.isEnabled(midi: 37))
        #expect(!lineOnly.isEnabled(midi: 38))
        #expect(!lineOnly.isEnabled(midi: 59))
        #expect(!lineOnly.isEnabled(midi: 69))
        #expect(!lineOnly.isEnabled(midi: 83))
        #expect(lineOnly.encodedValue.hasPrefix("midi:"))
        #expect(PalettePitchClassColorState(encodedValue: lineOnly.encodedValue) == lineOnly)
        for pitchClass in PalettePitchClassColorState.paletteButtonPitchClasses {
            #expect(!lineOnly.isEnabledForPaletteButton(pitchClass))
        }
    }

    @Test func staffLinePresetFollowsSelectedKeyScaleSpelling() {
        let lineOnly = PalettePitchClassColorState.staffLineOnly

        #expect(lineOnly.isEnabledForStaffLine(midi: 53, scaleTonicPitchClass: 0)) // F3 in C
        #expect(!lineOnly.isEnabledForStaffLine(midi: 52, scaleTonicPitchClass: 0)) // E3 space in C

        #expect(lineOnly.isEnabledForStaffLine(midi: 54, scaleTonicPitchClass: 7)) // F#3 line in G
        #expect(lineOnly.isEnabledForStaffLine(midi: 53, scaleTonicPitchClass: 7)) // Score staff position F is the F line.
        #expect(!lineOnly.isEnabledForStaffLine(midi: 53, scaleTonicPitchClass: 7, requiresScaleMembership: true)) // Keyboard F natural is outside G major.

        #expect(lineOnly.isEnabledForStaffLine(midi: 46, scaleTonicPitchClass: 5)) // Bb2 line in F
        #expect(lineOnly.isEnabledForStaffLine(midi: 47, scaleTonicPitchClass: 5)) // Score staff position B is part of the line preset.
        #expect(!lineOnly.isEnabledForStaffLine(midi: 47, scaleTonicPitchClass: 5, requiresScaleMembership: true)) // Keyboard B natural is outside F major.
    }

    @Test func keyAwareColorEnablementUsesScaleSpelling() {
        // In F major, chromatic A#/Bb belongs to the B scale degree, not A.
        #expect(KeyboardScaleColor.majorScalePitchClass(midi: 10, tonicPitchClass: 5) == .b)
        #expect(KeyboardScaleColor.enabledPitchClass(midi: 10, scaleTonicPitchClass: 5) == 11)

        let bOff = PalettePitchClassColorState.allOn.toggled(11)
        let aOff = PalettePitchClassColorState.allOn.toggled(9)

        #expect(!bOff.isEnabled(pitchClass: KeyboardScaleColor.enabledPitchClass(midi: 10, scaleTonicPitchClass: 5) ?? 10))
        #expect(aOff.isEnabled(pitchClass: KeyboardScaleColor.enabledPitchClass(midi: 10, scaleTonicPitchClass: 5) ?? 10))
    }

    @Test func paletteStyleDisablesFKeyASharpWhenBScaleDegreeIsOff() throws {
        let rule = PalettePitchClassNoteColorRule(
            palette: defaultEducationalPalette,
            enabledState: PalettePitchClassColorState.allOn.toggled(11),
            disabledColor: .black,
            scaleTonicPitchClass: 5
        )
        let note = ScoreNote(
            id: NoteID(rawValue: "a-sharp"),
            pitch: Pitch(step: .a, octave: 4, alter: 1),
            onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
            duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
            voiceID: VoiceID(rawValue: "1"),
            staffID: StaffID(rawValue: "1")
        )
        let score = ScoreDocument(parts: [])
        let context = ColorContext(score: score, layout: try DoReMiRenderer().layout(score: score))

        #expect(rule.color(for: note, layout: nil, context: context) == .black)
    }

    @Test func paletteStyleStaffLinePresetUsesSameKeyAwareLineLogicAsKeyboard() throws {
        let rule = PalettePitchClassNoteColorRule(
            palette: defaultEducationalPalette,
            enabledState: .staffLineOnly,
            disabledColor: .black,
            scaleTonicPitchClass: 5
        )
        let score = ScoreDocument(parts: [])
        let context = ColorContext(score: score, layout: try DoReMiRenderer().layout(score: score))
        let bFlatLine = ScoreNote(
            id: NoteID(rawValue: "bb-line"),
            pitch: Pitch(step: .b, octave: 2, alter: -1),
            onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
            duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
            voiceID: VoiceID(rawValue: "1"),
            staffID: StaffID(rawValue: "1")
        )
        let bStaffPosition = ScoreNote(
            id: NoteID(rawValue: "b-staff-position"),
            pitch: Pitch(step: .b, octave: 2, alter: 0),
            onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
            duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
            voiceID: VoiceID(rawValue: "1"),
            staffID: StaffID(rawValue: "1")
        )

        #expect(rule.color(for: bFlatLine, layout: nil, context: context) != .black)
        #expect(rule.color(for: bStaffPosition, layout: nil, context: context) == .black)
    }

    @Test func paletteStyleUsesNeutralInkForDisabledPitchClass() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let noteheadID = try #require(loaded.layout.noteLayout(for: firstNoteID)?.noteheadElementID)
        let notehead = try #require(loaded.layout.elementLayout(for: noteheadID))
        let cOff = PalettePitchClassColorState.allOn.toggled(0)
        let style = PaletteStyleFactory.makeStyle(
            noteColorVisible: true,
            staffColorVisible: true,
            paletteKind: .educational,
            pitchClassColorState: cOff
        )

        let resolved = style.colorResolver.resolvedStyle(
            for: notehead,
            score: loaded.score,
            layout: loaded.layout,
            style: style,
            selection: nil
        )

        #expect(resolved.fillColor == .black)
        #expect(resolved.strokeColor == .black)
    }

    @Test func paletteStyleIgnoresPitchClassStateWhenNoteColorIsOff() throws {
        let loaded = try PaletteScoreLoader().load(data: PaletteScoreLoaderTests.validMusicXML, sourceName: "unit.musicxml")
        let firstNoteID = try #require(loaded.playbackEvents.first?.noteIDs.first)
        let noteheadID = try #require(loaded.layout.noteLayout(for: firstNoteID)?.noteheadElementID)
        let notehead = try #require(loaded.layout.elementLayout(for: noteheadID))
        let style = PaletteStyleFactory.makeStyle(
            noteColorVisible: false,
            staffColorVisible: true,
            paletteKind: .educational,
            pitchClassColorState: .allOff
        )

        let resolved = style.colorResolver.resolvedStyle(
            for: notehead,
            score: loaded.score,
            layout: loaded.layout,
            style: style,
            selection: nil
        )

        #expect(resolved.fillColor == .black)
    }

    @Test func palettePreviewScoreCoversC2ThroughC6() throws {
        let loaded = try PaletteScoreLoader().load(
            data: PalettePreviewScore.musicXMLData,
            sourceName: "palette-preview-c2-c6.musicxml"
        )
        let midiNumbers = Set(loaded.layout.noteByID.values.compactMap { noteLayout in
            noteLayout.pitch.map(KeyboardPitchMapper.midiNumber(for:))
        })

        #expect(midiNumbers.contains(36))
        #expect(midiNumbers.contains(60))
        #expect(midiNumbers.contains(84))
        #expect(midiNumbers.count == 49)
        #expect(loaded.layout.canvasSize.width > 0)
        #expect(loaded.layout.canvasSize.height > 0)
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
