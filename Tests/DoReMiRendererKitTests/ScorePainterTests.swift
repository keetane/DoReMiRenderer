import CoreGraphics
import Testing
@testable import DoReMiRendererKit

@Test func coreGraphicsTextDrawingCancelsUIKitYFlipForSMuFLGlyphs() throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try #require(CGContext(
        data: nil,
        width: 32,
        height: 32,
        bitsPerComponent: 8,
        bytesPerRow: 32 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))

    context.translateBy(x: 0, y: 32)
    context.scaleBy(x: 1, y: -1)

    let normal = CoreGraphicsScoreDrawingContext.coreTextDrawingScale(
        context: context,
        mirroredHorizontally: false,
        mirroredVertically: false
    )
    let mirroredDownStem = CoreGraphicsScoreDrawingContext.coreTextDrawingScale(
        context: context,
        mirroredHorizontally: false,
        mirroredVertically: true
    )

    #expect(normal.x == 1)
    #expect(normal.y == -1)
    #expect(mirroredDownStem.x == 1)
    #expect(mirroredDownStem.y == 1)
}

@Test func scorePainterConsumesLayoutElementsWithoutMutatingLayout() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let noteIDs = Set(layout.noteByID.keys)
    let elementIDs = Set(layout.elementByID.keys)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(
        layout: layout,
        score: score,
        style: renderingStyle(),
        currentNoteIDs: [NoteID(rawValue: "n0")],
        into: &context
    )

    #expect(context.commands.contains { $0.kind == .fillRect })
    #expect(context.commands.filter { $0.kind == .strokeLine }.count >= layout.staffLines.count)
    #expect(context.commands.contains { $0.kind == .fillEllipse })
    #expect(context.commands.contains { $0.kind == .drawText })
    #expect(Set(layout.noteByID.keys) == noteIDs)
    #expect(Set(layout.elementByID.keys) == elementIDs)
}

@Test func scorePainterDrawsEvenMeasureNumbersWhenEnabled() throws {
    let staffID = StaffID(rawValue: "1")
    let measures = (1...4).map { number in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(number)"),
            number: "\(number)",
            notes: [
                ScoreNote(
                    id: NoteID(rawValue: "m\(number).n0"),
                    pitch: Pitch(step: .c, octave: 4),
                    onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                    duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                    voiceID: VoiceID(rawValue: "1"),
                    staffID: staffID
                ),
            ],
            clef: number == 1 ? Clef(kind: .treble) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(measureSpacing: 8))
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(
        layout: layout,
        score: score,
        style: ScoreStyle(measureNumberDisplayMode: .evenMeasures),
        into: &context
    )

    #expect(!context.commands.contains { $0.kind == .drawText && $0.text == "1" })
    #expect(!context.commands.contains { $0.kind == .drawText && $0.text == "3" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "2" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "4" })

    let secondMeasure = try #require(layout.measures.first { $0.measureID == MeasureID(partIndex: 0, measureNumber: "2") })
    let bottomStaffMaxY = try #require(layout.staves.filter { $0.systemIndex == secondMeasure.systemIndex }.map(\.frame.maxY).max())
    let secondNumberPoint = try #require(context.commands.first { $0.kind == .drawText && $0.text == "2" }?.point)
    #expect(secondNumberPoint.y > bottomStaffMaxY)
}

@Test func scorePainterDrawsArticulationsDynamicsAndHairpins() throws {
    let staffID = StaffID(rawValue: "1")
    let measure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: [
            ScoreNote(
                id: NoteID(rawValue: "n0"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID,
                articulations: [.staccato]
            ),
            ScoreNote(
                id: NoteID(rawValue: "n1"),
                pitch: Pitch(step: .d, octave: 4),
                onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID,
                articulations: [.accent]
            ),
        ],
        clef: Clef(kind: .treble),
        directions: [
            ScoreDirection(kind: .dynamic(.mf), onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4), staffID: staffID, placement: .below),
            ScoreDirection(kind: .wedge(.crescendo), onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4), staffID: staffID, placement: .below),
            ScoreDirection(kind: .wedge(.stop), onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4), staffID: staffID, placement: .below),
        ]
    )
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: [measure])])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: ScoreStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .fillEllipse })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == ">" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "mf" })
    #expect(context.commands.filter { $0.kind == .strokeLine }.count > layout.staffLines.count)
}

@Test func scorePainterUsesAboveAndBelowFermataGlyphsForFlaggedNotes() throws {
    let staffID = StaffID(rawValue: "1")
    let measure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: [
            ScoreNote(
                id: NoteID(rawValue: "up-stem-fermata"),
                pitch: Pitch(step: .c, octave: 4),
                onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                noteValueKind: .eighth,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID,
                articulations: [.fermata]
            ),
            ScoreNote(
                id: NoteID(rawValue: "down-stem-fermata"),
                pitch: Pitch(step: .a, octave: 5),
                onset: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                noteValueKind: .eighth,
                voiceID: VoiceID(rawValue: "1"),
                staffID: staffID,
                articulations: [.fermata]
            ),
        ],
        clef: Clef(kind: .treble)
    )
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: [measure])])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: ScoreStyle(), into: &context)

    let upStemFermata = try #require(layout.elements.first { $0.noteID == NoteID(rawValue: "up-stem-fermata") && $0.articulation?.kind == .fermata }?.articulation)
    let downStemFermata = try #require(layout.elements.first { $0.noteID == NoteID(rawValue: "down-stem-fermata") && $0.articulation?.kind == .fermata }?.articulation)
    #expect(upStemFermata.placement == .below)
    #expect(downStemFermata.placement == .above)
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "\u{1D111}" && $0.point == upStemFermata.point })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "\u{1D110}" && $0.point == downStemFermata.point })
    #expect(!context.commands.contains { $0.kind == .drawText && $0.text == "\u{1D110}" && $0.point == upStemFermata.point })
}

@Test func scorePainterUsesResolvedNoteAndStaffColors() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .fillEllipse && $0.color == defaultEducationalPalette.c })
    #expect(context.commands.contains { $0.kind == .strokeLine && $0.color == defaultEducationalPalette.e })
}

@Test func scorePainterKeepsStemInkWhenNoteColorIsOnAndHighlighted() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let stemElement = try #require(layout.elements.first { $0.kind == .stem })
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(
        layout: layout,
        score: score,
        style: renderingStyle(),
        currentNoteIDs: stemElement.noteID.map { [$0] } ?? [],
        into: &context
    )

    let stemCommand = try #require(context.commands.first {
        $0.kind == .strokeLine
            && $0.lineStart?.x == stemElement.frame.midX
            && $0.lineEnd?.x == stemElement.frame.midX
            && abs(($0.lineStart?.y ?? 0) - ($0.lineEnd?.y ?? 0)) > 1
    })
    #expect(stemCommand.color == .black)
}

@Test func scorePainterKeepsFlagInkWhenNoteColorIsOnAndHighlighted() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let noteID = NoteID(rawValue: "eighth")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: noteID,
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(
        layout: layout,
        score: score,
        style: renderingStyle(),
        currentNoteIDs: [noteID],
        into: &context
    )

    let flagCommand = try #require(context.commands.first {
        $0.kind == .drawText
            && $0.text == SMuFLGlyph.flagEighthUp.string
            && $0.fontName == "Bravura"
    })
    #expect(flagCommand.color == .black)
}

@Test func scorePainterDrawsNoteheadsAfterStems() throws {
    let score = durationRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let stemElement = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "quarter.stem")))
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    let stemIndex = try #require(context.commands.firstIndex {
        $0.kind == .strokeLine
            && $0.lineStart?.x == stemElement.frame.midX
            && $0.lineEnd?.x == stemElement.frame.midX
            && abs(($0.lineStart?.y ?? 0) - ($0.lineEnd?.y ?? 0)) > 1
    })
    let quarterNoteheadIndex = try #require(context.commands.firstIndex {
        $0.kind == .fillEllipse && $0.color == defaultEducationalPalette.e
    })
    #expect(quarterNoteheadIndex > stemIndex)
}

@Test func scorePainterDrawsContinuationHighlightDistinctFromCurrentHighlight() throws {
    let score = durationRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(
        layout: layout,
        score: score,
        style: renderingStyle(),
        currentNoteIDs: [NoteID(rawValue: "quarter")],
        continuationNoteIDs: [NoteID(rawValue: "half")],
        into: &context
    )

    let highlightColor = ScoreStyle().highlightStyle.color
    #expect(context.commands.contains {
        $0.kind == .fillRect
            && $0.color.red == 0.08
            && $0.color.green == 0.72
            && $0.color.blue == 1
            && $0.color.alpha == 0.78
    })
    #expect(!context.commands.contains { $0.kind == .fillEllipse && $0.color == highlightColor })
    #expect(context.commands.contains {
        $0.kind == .strokeEllipse
            && $0.color.red == highlightColor.red
            && $0.color.green == highlightColor.green
            && $0.color.blue == highlightColor.blue
            && $0.color.alpha <= highlightColor.alpha
    })
}

@Test func scorePainterDrawsAccidentalsFromLayoutElements() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let accidentalElement = try #require(layout.elements.first { $0.kind == .accidental })
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(accidentalElement.accidental == "natural")
    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "n"
            && $0.point == CGPoint(x: accidentalElement.frame.midX, y: accidentalElement.frame.midY)
    })
}

@Test func scorePainterColorsNoteAccidentalsFromMatchingDisplayedNotePitch() throws {
    let score = accidentalRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let accidentalElement = try #require(layout.elements.first { $0.kind == .accidental })
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "#"
            && $0.point == CGPoint(x: accidentalElement.frame.midX, y: accidentalElement.frame.midY)
            && $0.color == defaultEducationalPalette.f
    })
}

@Test func scorePainterKeepsAccidentalInkWhenNoteColorIsOff() throws {
    let score = accidentalRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let accidentalElement = try #require(layout.elements.first { $0.kind == .accidental })
    let style = ScoreStyle(
        defaultInkColor: .black,
        noteColorStyle: .monochrome(.black),
        accidentalStyle: .defaultInk
    )
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: style, into: &context)

    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "#"
            && $0.point == CGPoint(x: accidentalElement.frame.midX, y: accidentalElement.frame.midY)
            && $0.color == .black
    })
}

@Test func scorePainterColorsDisplayTransposedAccidentalsFromDisplayedPitch() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "n0"),
                        pitch: Pitch(step: .c, octave: 4, alter: 1),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: StaffID(rawValue: "1"),
                        accidental: "sharp"
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 0, mode: "major")
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(displayTransposeSemitones: 2)
    )
    let accidentalElement = try #require(layout.elements.first { $0.kind == .accidental })
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(accidentalElement.pitchClassHint == .d)
    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "#"
            && $0.point == CGPoint(x: accidentalElement.frame.midX, y: accidentalElement.frame.midY)
            && $0.color == defaultEducationalPalette.d
    })
}

@Test func scorePainterColorsKeySignatureAccidentalsByPitchClassWhenNoteColorIsOn() throws {
    let score = keySignatureRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let keyElement = try #require(layout.elements.first { $0.kind == .keySignature && $0.pitchClassHint == .f })
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "#"
            && $0.point == CGPoint(x: keyElement.frame.midX, y: keyElement.frame.midY)
            && $0.color == defaultEducationalPalette.f
    })
}

@Test func scorePainterDifferentiatesCommonNoteValues() throws {
    let score = durationRenderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(layout.noteLayout(for: NoteID(rawValue: "whole"))?.duration == MusicalTime(ticks: 16, ticksPerQuarterNote: 4))
    #expect(layout.noteLayout(for: NoteID(rawValue: "half"))?.duration == MusicalTime(ticks: 8, ticksPerQuarterNote: 4))
    #expect(layout.noteLayout(for: NoteID(rawValue: "quarter"))?.duration == MusicalTime(ticks: 4, ticksPerQuarterNote: 4))
    #expect(layout.noteLayout(for: NoteID(rawValue: "eighth"))?.duration == MusicalTime(ticks: 2, ticksPerQuarterNote: 4))
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "whole.stem")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.dot.0"))?.kind == .dot)
    #expect(context.commands.filter { $0.kind == .strokeEllipse }.count >= 2)
    #expect(context.commands.contains { $0.kind == .fillEllipse && $0.color == defaultEducationalPalette.e })
    #expect(context.commands.contains { $0.kind == .fillEllipse && $0.color == defaultEducationalPalette.f })
    #expect(context.commands.filter { $0.kind == .strokeLine }.count > layout.staffLines.count + 3)
}

@Test func scorePainterDrawsStemDirectionFromLayoutFrames() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "below"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "middle"),
                        pitch: Pitch(step: .b, octave: 4),
                        onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    let belowNote = try #require(layout.noteLayout(for: NoteID(rawValue: "below")))
    let middleNote = try #require(layout.noteLayout(for: NoteID(rawValue: "middle")))
    let belowStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "below.stem")))
    let middleStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "middle.stem")))
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains {
        $0.kind == .strokeLine
            && $0.lineStart?.y == belowStem.frame.maxY
            && $0.lineEnd?.y == belowStem.frame.minY
            && ($0.lineEnd?.y ?? .zero) < belowNote.noteheadCenter.y
    })
    #expect(context.commands.contains {
        $0.kind == .strokeLine
            && $0.lineStart?.y == middleStem.frame.minY
            && $0.lineEnd?.y == middleStem.frame.maxY
            && ($0.lineEnd?.y ?? .zero) > middleNote.noteheadCenter.y
    })
}

@Test func scorePainterDrawsStructuralNotationElementsFromLayout() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "n0"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                repeatBarlines: [
                    RepeatBarline(direction: .forward),
                    RepeatBarline(direction: .backward),
                ]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "𝄞" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "4\n4" })
    #expect(context.commands.filter { $0.kind == .strokeLine }.count > layout.staffLines.count + 4)
    #expect(context.commands.filter { $0.kind == .fillEllipse }.count >= 3)
}

@Test func scorePainterDrawsPlaybackJumpMarkersFromLayout() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "n0"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                playbackJumpMarkers: [
                    PlaybackJumpMarker(kind: .daCapoAlCoda, text: "D.C. al Coda"),
                ]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    let markerElement = try #require(layout.elements.first { $0.kind == .playbackJumpMarker })
    let marker = try #require(markerElement.playbackJumpMarker)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(marker.label == "D.C. al Coda")
    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "D.C. al Coda"
            && $0.point == marker.point
            && $0.fontName == "Georgia-Italic"
            && $0.size == max(16, markerElement.frame.height * 1.2)
    })
}

@Test func scorePainterUsesSMuFLSymbolsForSegnoAndCodaMarkers() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "n0"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                playbackJumpMarkers: [
                    PlaybackJumpMarker(kind: .segno, text: "Segno"),
                    PlaybackJumpMarker(kind: .toCoda, text: "To Coda"),
                    PlaybackJumpMarker(kind: .coda, text: "Coda"),
                ]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.segno.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "To" && $0.fontName == "Georgia-Italic" })
    #expect(context.commands.filter { $0.kind == .drawText && $0.text == SMuFLGlyph.coda.string && $0.fontName == "Bravura" }.count >= 2)
}

@Test func smuflGlyphMapReturnsExpectedCoreGlyphs() {
    #expect(SMuFLGlyph.trebleClef.string == String(UnicodeScalar(0xE050)!))
    #expect(SMuFLGlyph.bassClef.string == String(UnicodeScalar(0xE062)!))
    #expect(SMuFLGlyph.accidentalSharp.string == String(UnicodeScalar(0xE262)!))
    #expect(SMuFLGlyph.restQuarter.string == String(UnicodeScalar(0xE4E5)!))
    #expect(SMuFLGlyph.noteheadBlack.string == String(UnicodeScalar(0xE0A4)!))
    #expect(SMuFLGlyph.flagEighthUp.string == String(UnicodeScalar(0xE240)!))
    #expect(SMuFLGlyph.segno.string == String(UnicodeScalar(0xE047)!))
    #expect(SMuFLGlyph.coda.string == String(UnicodeScalar(0xE048)!))
}

@Test func smuflFontResourceRegistersForRendering() {
    #expect(SMuFLFont.registerIfNeeded())
    #expect(SMuFLFont.registeredFontName() == "Bravura")
}

@Test func scorePainterUsesSMuFLGlyphsWhenFontIsAvailable() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "eighth"),
                        pitch: Pitch(step: .f, octave: 4, alter: 1),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "rest"),
                        pitch: nil,
                        onset: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                repeatBarlines: [RepeatBarline(direction: .backward)]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.trebleClef.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.accidentalSharp.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.restEighth.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.noteheadBlack.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.flagEighthUp.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.repeatDot.string && $0.fontName == "Bravura" })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == SMuFLGlyph.timeSignatureDigit(4).string && $0.fontName == "Bravura" })
}

@Test func scoreGraphicsRendererDrawsIntoCGContextForPrintExport() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let width = max(1, Int(ceil(layout.canvasSize.width)))
    let height = max(1, Int(ceil(layout.canvasSize.height)))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))

    ScoreGraphicsRenderer().draw(
        layout: layout,
        score: score,
        style: ScoreStyle(),
        in: context
    )

    #expect(context.makeImage() != nil)
}

@Test func scorePainterDrawsRepeatDotsPerStaffInGrandStaff() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let upperStaffID = StaffID(rawValue: "1")
    let lowerStaffID = StaffID(rawValue: "2")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "upper"),
                        pitch: Pitch(step: .c, octave: 5),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: upperStaffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "lower"),
                        pitch: Pitch(step: .c, octave: 3),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: lowerStaffID
                    ),
                ],
                clefsByStaff: [
                    upperStaffID: Clef(kind: .treble),
                    lowerStaffID: Clef(kind: .bass),
                ],
                repeatBarlines: [RepeatBarline(direction: .backward)]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    let repeatDots = context.commands.filter {
        $0.kind == .drawText
            && $0.text == SMuFLGlyph.repeatDot.string
            && $0.fontName == "Bravura"
    }
    #expect(repeatDots.count == 4)

    let dotYs = repeatDots.compactMap { $0.point?.y }.sorted()
    let expectedYs = layout.staves.flatMap { staff -> [CGFloat] in
        let staffSpace = staff.frame.height / 4
        return [staff.frame.midY - staffSpace * 0.5, staff.frame.midY + staffSpace * 0.5]
    }.sorted()
    #expect(dotYs.count == expectedYs.count)
    for (actual, expected) in zip(dotYs, expectedYs) {
        #expect(abs(actual - expected) < 0.1)
    }

    let repeatElement = try #require(layout.elements.first { $0.kind == .barline && $0.repeatBarline != nil })
    let thickRepeatLines = context.commands.filter {
        $0.kind == .strokeLine
            && $0.lineWidth == 6
            && ($0.lineStart?.x ?? -1) >= repeatElement.frame.minX - 0.1
            && ($0.lineStart?.x ?? -1) <= repeatElement.frame.maxX + 0.1
    }
    let thickRepeatLine = try #require(thickRepeatLines.first)
    #expect(thickRepeatLines.count == 1)
    #expect(abs((thickRepeatLine.lineStart?.y ?? 0) - repeatElement.frame.minY) < 0.1)
    #expect(abs((thickRepeatLine.lineEnd?.y ?? 0) - repeatElement.frame.maxY) < 0.1)
}

@Test func scorePainterDrawsRepeatEndingBracketAndNumber() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "ending-note"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                repeatBarlines: [RepeatBarline(direction: .backward)],
                repeatEndings: [
                    RepeatEnding(numbers: [1], kind: .start),
                    RepeatEnding(numbers: [1], kind: .stop),
                ]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let endingElement = try #require(layout.elements.first { $0.kind == .repeatEnding })
    let ending = try #require(endingElement.repeatEnding)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains {
        $0.kind == .strokeLine
            && $0.lineStart == ending.lineStart
            && $0.lineEnd == ending.lineEnd
    })
    #expect(context.commands.contains {
        $0.kind == .strokeLine
            && $0.lineStart == ending.lineStart
            && $0.lineEnd == ending.startHookEnd
    })
    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "1."
            && $0.point == ending.labelPoint
            && $0.fontName == "Georgia-Italic"
            && $0.size == max(16, endingElement.frame.height * 1.2)
    })
}

@Test func scorePainterUsesMeasureSystemStavesForRepeatDotsWhenRepeatFrameMissesAStaff() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "10")
    let repeatElement = ElementLayout(
        id: ScoreElementID(rawValue: "repeat.backward"),
        kind: .barline,
        measureID: measureID,
        frame: CGRect(x: 320, y: 40, width: 8, height: 40),
        repeatBarline: RepeatBarline(direction: .backward)
    )
    let layout = ScoreLayout(
        canvasSize: CGSize(width: 420, height: 180),
        staves: [
            StaffLayout(staffID: StaffID(rawValue: "1"), systemIndex: 0, frame: CGRect(x: 20, y: 40, width: 360, height: 40), middleLineY: 60),
            StaffLayout(staffID: StaffID(rawValue: "2"), systemIndex: 0, frame: CGRect(x: 20, y: 120, width: 360, height: 40), middleLineY: 140),
        ],
        measures: [
            MeasureLayout(measureID: measureID, systemIndex: 0, frame: CGRect(x: 20, y: 40, width: 360, height: 120)),
        ],
        elements: [repeatElement],
        elementByID: [repeatElement.id: repeatElement]
    )
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, style: renderingStyle(), into: &context)

    let repeatDots = context.commands.filter {
        $0.kind == .drawText
            && $0.text == SMuFLGlyph.repeatDot.string
            && $0.fontName == "Bravura"
    }
    #expect(repeatDots.count == 4)

    let thickRepeatLine = try #require(context.commands.first { $0.kind == .strokeLine && $0.lineWidth == 6 })
    #expect(abs((thickRepeatLine.lineStart?.y ?? 0) - 40) < 0.1)
    #expect(abs((thickRepeatLine.lineEnd?.y ?? 0) - 160) < 0.1)
}

@Test func scorePainterDrawsOneBarMeasureRepeatGlyph() throws {
    let measureElement = ElementLayout(
        id: ScoreElementID(rawValue: "measureRepeat"),
        kind: .measureRepeat,
        measureID: MeasureID(partIndex: 0, measureNumber: "1"),
        staffID: StaffID(rawValue: "1"),
        frame: CGRect(x: 80, y: 40, width: 30, height: 30),
        measureRepeat: MeasureRepeat(count: 1)
    )
    let layout = ScoreLayout(
        canvasSize: CGSize(width: 180, height: 120),
        elements: [measureElement],
        elementByID: [measureElement.id: measureElement]
    )
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, style: renderingStyle(), into: &context)

    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == SMuFLGlyph.repeatOneBar.fallback
            && $0.point == CGPoint(x: measureElement.frame.midX, y: measureElement.frame.midY)
    })
}

@Test func scorePainterDrawsS6CurvesBeamsAndTupletsFromLayoutElements() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "beam-a"),
                        pitch: Pitch(step: .c, octave: 5),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "beam-b"),
                        pitch: Pitch(step: .d, octave: 5),
                        onset: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "tie-start"),
                        pitch: Pitch(step: .g, octave: 4),
                        onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        ties: [.start]
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "tie-stop"),
                        pitch: Pitch(step: .g, octave: 4),
                        onset: MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        ties: [.stop]
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "slur-start"),
                        pitch: Pitch(step: .e, octave: 4),
                        onset: MusicalTime(ticks: 12, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        slurs: [.start]
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "slur-stop"),
                        pitch: Pitch(step: .f, octave: 4),
                        onset: MusicalTime(ticks: 14, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        slurs: [.stop]
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "trip-a"),
                        pitch: Pitch(step: .a, octave: 4),
                        onset: MusicalTime(ticks: 16, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        hasTimeModification: true,
                        hasTupletNotation: true,
                        tuplet: TupletInfo(kind: .start, actualNotes: 3, normalNotes: 2)
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "trip-b"),
                        pitch: Pitch(step: .b, octave: 4),
                        onset: MusicalTime(ticks: 18, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        hasTimeModification: true,
                        hasTupletNotation: true,
                        tuplet: TupletInfo(kind: nil, actualNotes: 3, normalNotes: 2)
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "trip-c"),
                        pitch: Pitch(step: .c, octave: 5),
                        onset: MusicalTime(ticks: 20, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        hasTimeModification: true,
                        hasTupletNotation: true,
                        tuplet: TupletInfo(kind: .stop, actualNotes: 3, normalNotes: 2)
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(layout.elements.contains { $0.kind == .beam })
    #expect(layout.elements.contains { $0.kind == .tie })
    #expect(layout.elements.contains { $0.kind == .slur })
    #expect(layout.elements.contains { $0.kind == .tuplet })
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)
    #expect(context.commands.contains {
        $0.kind == .strokeLine
            && $0.lineStart == beam.primary.start
            && $0.lineEnd == beam.primary.end
            && $0.color == ScoreStyle().defaultInkColor
    })
    #expect(context.commands.filter { $0.kind == .strokeCurve }.count >= 2)
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "3" })
}

@Test func scorePainterAnchorsSMuFLFlagNearStemEnd() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "eighth"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: StaffID(rawValue: "1")
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let flag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.flag")))
    let stemEnd = CGPoint(x: flag.frame.minX, y: flag.frame.minY)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    let flagCommand = try #require(context.commands.first { $0.text == SMuFLGlyph.flagEighthUp.string && $0.fontName == "Bravura" })
    let point = try #require(flagCommand.point)
    #expect(point.x > stemEnd.x)
    #expect(point.x - stemEnd.x <= flag.frame.width * 0.25)
    #expect(abs(point.y - (stemEnd.y + 15)) < 0.001)
}

@Test func scorePainterAnchorsDownStemSMuFLFlagNearStemEnd() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "down-eighth"),
                        pitch: Pitch(step: .b, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: StaffID(rawValue: "1")
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let flag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "down-eighth.flag")))
    let stemEnd = CGPoint(x: flag.frame.maxX, y: flag.frame.maxY)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    let flagCommand = try #require(context.commands.first {
        $0.text == SMuFLGlyph.flagEighthUp.string && $0.fontName == "Bravura" && !$0.mirroredHorizontally && $0.mirroredVertically
    })
    let point = try #require(flagCommand.point)
    #expect(point.x > stemEnd.x)
    #expect(point.x - stemEnd.x <= flag.frame.width * 0.25)
    #expect(abs(point.y - (stemEnd.y - 15)) < 0.001)
}

@Test func smuflGlyphSizePolicyKeepsLearningGlyphsReadable() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "eighth"),
                        pitch: Pitch(step: .f, octave: 4, alter: 1),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "rest"),
                        pitch: nil,
                        onset: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                repeatBarlines: [RepeatBarline(direction: .backward)]
            ),
        ]),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: "Bravura").draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    let notehead = try #require(context.commands.first { $0.text == SMuFLGlyph.noteheadBlack.string && $0.fontName == "Bravura" })
    let accidentalSize = context.commands
        .filter { $0.text == SMuFLGlyph.accidentalSharp.string && $0.fontName == "Bravura" }
        .compactMap(\.size)
        .max() ?? 0
    let rest = try #require(context.commands.first { $0.text == SMuFLGlyph.restEighth.string && $0.fontName == "Bravura" })
    let flag = try #require(context.commands.first { $0.text == SMuFLGlyph.flagEighthUp.string && $0.fontName == "Bravura" })
    let timeDigit = try #require(context.commands.first { $0.text == SMuFLGlyph.timeSignatureDigit(4).string && $0.fontName == "Bravura" })
    let clef = try #require(context.commands.first { $0.text == SMuFLGlyph.trebleClef.string && $0.fontName == "Bravura" })

    #expect((notehead.size ?? 0) >= 38)
    #expect(accidentalSize >= 22)
    #expect(accidentalSize <= 36)
    #expect((rest.size ?? 0) >= 38)
    #expect((flag.size ?? 0) >= 24)
    #expect((timeDigit.size ?? 0) >= 20)
    #expect((clef.size ?? 0) >= 34)
}

@Test func smuflNoteheadSizesStayConsistentAcrossCommonValues() {
    let policy = SMuFLGlyphSizePolicy()
    let frame = CGRect(x: 0, y: 0, width: 19.5, height: 15.5)
    let whole = policy.noteheadSize(for: frame, noteValue: .whole)
    let half = policy.noteheadSize(for: frame, noteValue: .half)
    let black = policy.noteheadSize(for: frame, noteValue: .quarter)

    #expect(abs(whole - half) <= 1)
    #expect(abs(black - half) <= 1)
    #expect(abs(black - whole) <= 1)
}

@Test func smuflRestSizesStayReadableAcrossCommonValues() {
    let policy = SMuFLGlyphSizePolicy()
    let frame = CGRect(x: 0, y: 0, width: 20.5, height: 16.2)
    let whole = policy.restSize(for: frame, noteValue: .whole)
    let quarter = policy.restSize(for: frame, noteValue: .quarter)
    let eighth = policy.restSize(for: frame, noteValue: .eighth)

    #expect(whole >= 34)
    #expect(quarter >= 38)
    #expect(eighth >= 38)
    #expect(abs(quarter - eighth) <= 1)
}

@Test func scorePainterFallsBackWhenSMuFLFontIsUnavailable() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "𝄞" && $0.fontName == nil })
    #expect(context.commands.contains { $0.kind == .drawText && $0.text == "n" && $0.fontName == nil })
}

@Test func colorStyleChangesDoNotChangeLayoutIdentity() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let noteCount = layout.noteByID.count
    let elementCount = layout.elementByID.count
    let noteIDs = Set(layout.noteByID.keys)
    let styles = [
        ScoreStyle(
            staffLineStyle: .monochrome(.black),
            noteColorStyle: .monochrome(.black),
            ledgerLineStyle: .defaultInk
        ),
        renderingStyle(),
        ScoreStyle(
            staffLineStyle: .rule(ClefAwareStaffLineColorRule(defaultPalette: defaultEducationalPalette)),
            noteColorStyle: .rule(PitchClassNoteColorRule(palette: defaultEducationalPalette)),
            ledgerLineStyle: .rule(MatchNoteLedgerLineColorRule())
        ),
    ]

    for style in styles {
        var context = RecordingDrawingContext()
        ScorePainter(smuflFontName: nil).draw(layout: layout, score: score, style: style, into: &context)
        #expect(layout.noteByID.count == noteCount)
        #expect(layout.elementByID.count == elementCount)
        #expect(Set(layout.noteByID.keys) == noteIDs)
    }
}

private func durationRenderingScore() -> ScoreDocument {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    return ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "whole"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 16, ticksPerQuarterNote: 4),
                        noteValueKind: .whole,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "half"),
                        pitch: Pitch(step: .d, octave: 4),
                        onset: MusicalTime(ticks: 16, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 8, ticksPerQuarterNote: 4),
                        noteValueKind: .half,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "quarter"),
                        pitch: Pitch(step: .e, octave: 4),
                        onset: MusicalTime(ticks: 24, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "eighth"),
                        pitch: Pitch(step: .f, octave: 4),
                        onset: MusicalTime(ticks: 28, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 2, ticksPerQuarterNote: 4),
                        noteValueKind: .eighth,
                        dotCount: 1,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
}

private func renderingScore() -> ScoreDocument {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    return ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "n0"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        accidental: "natural"
                    ),
                    ScoreNote(
                        id: NoteID(rawValue: "r0"),
                        pitch: nil,
                        onset: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
}

private func accidentalRenderingScore() -> ScoreDocument {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    return ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "sharp-note"),
                        pitch: Pitch(step: .f, octave: 4, alter: 1),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID,
                        accidental: "sharp"
                    ),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])
}

private func keySignatureRenderingScore() -> ScoreDocument {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    return ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    ScoreNote(
                        id: NoteID(rawValue: "note"),
                        pitch: Pitch(step: .c, octave: 4),
                        onset: MusicalTime(ticks: 0, ticksPerQuarterNote: 4),
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])
}

private func renderingStyle() -> ScoreStyle {
    ScoreStyle(
        staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
        noteColorStyle: .pitchClass(defaultEducationalPalette),
        ledgerLineStyle: .matchNotePitch,
        accidentalStyle: .matchNotePitch
    )
}

private struct RecordingDrawingContext: ScoreDrawingContext {
    enum CommandKind {
        case fillRect
        case strokeLine
        case fillEllipse
        case strokeEllipse
        case strokeCurve
        case drawText
    }

    struct Command {
        let kind: CommandKind
        let color: ScoreColor
        let text: String?
        let fontName: String?
        let size: CGFloat?
        let point: CGPoint?
        let lineStart: CGPoint?
        let lineEnd: CGPoint?
        let mirroredHorizontally: Bool
        let mirroredVertically: Bool
        let lineWidth: CGFloat?
    }

    var commands: [Command] = []

    mutating func fill(_ rect: CGRect, color: ScoreColor) {
        commands.append(Command(kind: .fillRect, color: color, text: nil, fontName: nil, size: nil, point: nil, lineStart: nil, lineEnd: nil, mirroredHorizontally: false, mirroredVertically: false, lineWidth: nil))
    }

    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(Command(kind: .strokeLine, color: color, text: nil, fontName: nil, size: nil, point: nil, lineStart: start, lineEnd: end, mirroredHorizontally: false, mirroredVertically: false, lineWidth: lineWidth))
    }

    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {
        commands.append(Command(kind: .fillEllipse, color: color, text: nil, fontName: nil, size: nil, point: nil, lineStart: nil, lineEnd: nil, mirroredHorizontally: false, mirroredVertically: false, lineWidth: nil))
    }

    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(Command(kind: .strokeEllipse, color: color, text: nil, fontName: nil, size: nil, point: nil, lineStart: nil, lineEnd: nil, mirroredHorizontally: false, mirroredVertically: false, lineWidth: lineWidth))
    }

    mutating func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(Command(kind: .strokeCurve, color: color, text: nil, fontName: nil, size: nil, point: control, lineStart: start, lineEnd: end, mirroredHorizontally: false, mirroredVertically: false, lineWidth: lineWidth))
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?) {
        commands.append(Command(kind: .drawText, color: color, text: text, fontName: fontName, size: size, point: point, lineStart: nil, lineEnd: nil, mirroredHorizontally: false, mirroredVertically: false, lineWidth: nil))
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?, mirroredHorizontally: Bool, mirroredVertically: Bool) {
        commands.append(Command(kind: .drawText, color: color, text: text, fontName: fontName, size: size, point: point, lineStart: nil, lineEnd: nil, mirroredHorizontally: mirroredHorizontally, mirroredVertically: mirroredVertically, lineWidth: nil))
    }
}
