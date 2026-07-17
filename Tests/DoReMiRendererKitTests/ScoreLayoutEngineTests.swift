import CoreGraphics
import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func noteheadCenterIsDeterministic() throws {
    let score = makeScore(notes: [
        makeNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        makeNote(id: "n1", pitch: Pitch(step: .e, octave: 4), onsetTicks: 4),
    ])
    let options = LayoutOptions(pageWidth: 640, staffSpace: 12)

    let first = try ScoreLayoutEngine().layout(score: score, options: options)
    let second = try ScoreLayoutEngine().layout(score: score, options: options)

    #expect(first.noteLayout(for: NoteID(rawValue: "n0"))?.noteheadCenter == second.noteLayout(for: NoteID(rawValue: "n0"))?.noteheadCenter)
    #expect(first.noteLayout(for: NoteID(rawValue: "n1"))?.noteheadCenter == second.noteLayout(for: NoteID(rawValue: "n1"))?.noteheadCenter)
}

@Test func chordTonesShareXCoordinate() throws {
    let score = makeScore(notes: [
        makeNote(id: "root", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        makeNote(id: "third", pitch: Pitch(step: .e, octave: 4), onsetTicks: 0, isChordTone: true, chordOrdinal: 1),
        makeNote(id: "next", pitch: Pitch(step: .g, octave: 4), onsetTicks: 4),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    let root = try #require(layout.noteLayout(for: NoteID(rawValue: "root")))
    let third = try #require(layout.noteLayout(for: NoteID(rawValue: "third")))
    let next = try #require(layout.noteLayout(for: NoteID(rawValue: "next")))

    #expect(root.noteheadCenter.x == third.noteheadCenter.x)
    #expect(root.noteheadCenter.x != next.noteheadCenter.x)
}

@Test func midMeasureClefChangeIsDrawnAtOnsetAndAffectsFollowingNotes() throws {
    let staff2 = StaffID(rawValue: "2")
    let beforeID = NoteID(rawValue: "before-clef-change")
    let afterID = NoteID(rawValue: "after-clef-change")
    let changeOnset = MusicalTime(ticks: 3, ticksPerQuarterNote: 1)
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(
                        id: beforeID.rawValue,
                        pitch: Pitch(step: .c, octave: 3),
                        onsetTicks: 0,
                        durationTicks: 12,
                        staffID: staff2
                    ),
                    makeNote(
                        id: afterID.rawValue,
                        pitch: Pitch(step: .e, octave: 4),
                        onsetTicks: 12,
                        durationTicks: 4,
                        staffID: staff2
                    ),
                ],
                clefsByStaff: [staff2: Clef(kind: .bass)],
                effectiveClefsByStaff: [staff2: Clef(kind: .bass)],
                clefChanges: [
                    ClefChange(staffID: staff2, clef: Clef(kind: .treble), onset: changeOnset),
                ],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 720, staffSpace: 10))
    let before = try #require(layout.noteLayout(for: beforeID))
    let after = try #require(layout.noteLayout(for: afterID))
    let clefChange = try #require(layout.elements.first {
        $0.kind == .clef && $0.staffID == staff2 && $0.id.rawValue.contains("clefChange")
    })

    #expect(before.clef == Clef(kind: .bass))
    #expect(after.clef == Clef(kind: .treble))
    #expect(clefChange.clef == Clef(kind: .treble))
    #expect(before.noteheadCenter.x < clefChange.frame.midX)
    #expect(clefChange.frame.maxX < after.noteheadFrame.minX)
}

@Test func restsReceiveStableLayoutElements() throws {
    let restID = NoteID(rawValue: "rest")
    let score = makeScore(notes: [
        makeNote(id: "rest", pitch: nil, onsetTicks: 0),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let restLayout = try #require(layout.noteLayout(for: restID))
    let restElement = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "rest.rest")))

    #expect(restLayout.pitch == nil)
    #expect(restElement.kind == .rest)
    #expect(restElement.noteID == restID)
}

@Test func displayTransposeMovesPitchWithoutChangingNoteID() throws {
    let noteID = NoteID(rawValue: "written-c")
    let score = makeScore(notes: [
        makeNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ])

    let written = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 12))
    let transposed = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(staffSpace: 12, displayTransposeSemitones: 2)
    )

    #expect(written.noteLayout(for: noteID)?.pitch == Pitch(step: .c, octave: 4))
    #expect(transposed.noteLayout(for: noteID)?.pitch == Pitch(step: .d, octave: 4))
    #expect(transposed.noteLayout(for: noteID)?.noteID == noteID)
    #expect(written.noteLayout(for: noteID)?.noteheadCenter.y != transposed.noteLayout(for: noteID)?.noteheadCenter.y)
}

@Test func displayTransposeUpdatesKeySignatureAndAccidentalElements() throws {
    let noteID = NoteID(rawValue: "sharp-note")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4, alter: 1), onsetTicks: 0, accidental: "sharp"),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 0, mode: "major")
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(staffSpace: 12, displayTransposeSemitones: 2)
    )

    #expect(layout.noteLayout(for: noteID)?.pitch == Pitch(step: .d, octave: 4, alter: 1))
    #expect(layout.elements.contains { $0.kind == .keySignature && $0.keySignature?.fifths == 2 })
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).accidental"))?.accidental == "sharp")
}

@Test func wholeRestIsCenteredWithinMeasure() throws {
    let score = makeScore(notes: [
        makeNote(id: "whole-rest", pitch: nil, onsetTicks: 0, durationTicks: 16, noteValueKind: .whole),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let measure = try #require(layout.measures.first)
    let rest = try #require(layout.noteLayout(for: NoteID(rawValue: "whole-rest")))

    #expect(abs(rest.noteheadCenter.x - measure.frame.midX) < 0.001)
}

@Test func normalMeasureWidthUsesReadableMinimum() throws {
    let targetMeasureID = MeasureID(partIndex: 0, measureNumber: "2")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "intro-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    makeNote(id: "intro-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
                    makeNote(id: "intro-c", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8),
                    makeNote(id: "intro-d", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
            Measure(
                id: targetMeasureID,
                number: "2",
                notes: [
                    makeNote(id: "single-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ]
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "3"),
                number: "3",
                notes: [
                    makeNote(id: "outro-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0),
                    makeNote(id: "outro-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 4),
                    makeNote(id: "outro-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 8),
                    makeNote(id: "outro-d", pitch: Pitch(step: .f, octave: 5), onsetTicks: 12),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let measure = try #require(layout.measures.first { $0.measureID == targetMeasureID })

    #expect(measure.frame.width >= 220)
}

@Test func firstMeasurePickupUsesRatioMinimumInsteadOfShrinkingToContent() throws {
    let pickupMeasure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "1"),
        number: "1",
        notes: [
            makeNote(id: "pickup", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 4),
        ],
        clef: Clef(kind: .treble),
        timeSignature: TimeSignature(beats: 4, beatType: 4)
    )
    let normalMeasure = Measure(
        id: MeasureID(partIndex: 0, measureNumber: "2"),
        number: "2",
        notes: [
            makeNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
            makeNote(id: "n1", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
            makeNote(id: "n2", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 4),
            makeNote(id: "n3", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12, durationTicks: 4),
        ]
    )
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [pickupMeasure, normalMeasure]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let first = try #require(layout.measures.first { $0.measureID == pickupMeasure.id })
    let second = try #require(layout.measures.first { $0.measureID == normalMeasure.id })

    #expect(first.frame.width >= 180)
    #expect(first.frame.width >= 220 * 0.75)
    #expect(second.frame.width >= 220)
}

@Test func firstMeasurePickupDetectionUsesTimeSignatureDuration() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "pickup-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "pickup-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 3, beatType: 4)
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "2"),
                number: "2",
                notes: [
                    makeNote(id: "full-a", pitch: Pitch(step: .e, octave: 4), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "full-b", pitch: Pitch(step: .f, octave: 4), onsetTicks: 4, durationTicks: 4),
                    makeNote(id: "full-c", pitch: Pitch(step: .g, octave: 4), onsetTicks: 8, durationTicks: 4),
                ],
                timeSignature: TimeSignature(beats: 3, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let first = try #require(layout.measures.first { $0.measureID.rawValue == "0.1" })
    let second = try #require(layout.measures.first { $0.measureID.rawValue == "0.2" })

    #expect(first.frame.width >= 180)
    #expect(second.frame.width >= 220)
}

@Test func systemJustificationDistributesExtraWidthAndPartiallyWidensFinalSystem() throws {
    let measures = (1...7).map { number in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(number)"),
            number: "\(number)",
            notes: [
                makeNote(id: "m\(number)-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                makeNote(id: "m\(number)-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
                makeNote(id: "m\(number)-c", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 4),
                makeNote(id: "m\(number)-d", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12, durationTicks: 4),
            ],
            clef: nil,
            timeSignature: nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 1100,
            pageHeight: 842,
            staffSpace: 10,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let finalSystemIndex = try #require(layout.measures.map(\.systemIndex).max())
    let nonFinalSystems = layout.measures.filter { $0.systemIndex < finalSystemIndex }
    let finalSystem = layout.measures.filter { $0.systemIndex == finalSystemIndex }

    #expect(!nonFinalSystems.isEmpty)
    #expect(nonFinalSystems.contains { $0.frame.width > 220 })
    #expect(finalSystem.contains { $0.frame.width > 260 })
    let finalSystemFrame = try #require(layout.systems.first { $0.index == finalSystemIndex })
    let finalSystemOccupiedWidth = (finalSystem.map(\.frame.maxX).max() ?? 0) - (finalSystem.map(\.frame.minX).min() ?? 0)
    #expect(finalSystemOccupiedWidth < finalSystemFrame.frame.width)
}

@Test func finalSingleMeasureSystemWidensButDoesNotStretchToFullLine() throws {
    let measures = (1...5).map { number in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(number)"),
            number: "\(number)",
            notes: [
                makeNote(id: "single-final-\(number)-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                makeNote(id: "single-final-\(number)-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
                makeNote(id: "single-final-\(number)-c", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 4),
                makeNote(id: "single-final-\(number)-d", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12, durationTicks: 4),
            ],
            clef: nil,
            timeSignature: nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 10,
            displayMode: .print,
            showPageMargins: true,
            maximumMeasuresPerSystem: 4
        )
    )
    let finalSystemIndex = try #require(layout.measures.map(\.systemIndex).max())
    let finalMeasure = try #require(layout.measures.first { $0.systemIndex == finalSystemIndex })

    #expect(layout.measures.filter { $0.systemIndex == finalSystemIndex }.count == 1)
    #expect(finalMeasure.frame.width > 300)
    let finalSystem = try #require(layout.systems.first { $0.index == finalSystemIndex })
    #expect(finalMeasure.frame.width < finalSystem.frame.width * 0.65)
}

@Test func finalIncompleteMeasureUsesPickupRatioMinimum() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "full-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "full-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
                    makeNote(id: "full-c", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 4),
                    makeNote(id: "full-d", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12, durationTicks: 4),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "2"),
                number: "2",
                notes: [
                    makeNote(id: "final-short", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 4),
                ],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let final = try #require(layout.measures.first { $0.measureID.rawValue == "0.2" })

    #expect(final.frame.width >= 180)
    #expect(final.frame.width < 220)
}

@Test func middleShortMeasureKeepsNormalMinimumInsteadOfPickupTreatment() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "full-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "full-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4, durationTicks: 4),
                    makeNote(id: "full-c", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 4),
                    makeNote(id: "full-d", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12, durationTicks: 4),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "2"),
                number: "2",
                notes: [
                    makeNote(id: "middle-short", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 4),
                ],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "3"),
                number: "3",
                notes: [
                    makeNote(id: "final-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "final-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 4, durationTicks: 4),
                    makeNote(id: "final-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 8, durationTicks: 4),
                    makeNote(id: "final-d", pitch: Pitch(step: .f, octave: 5), onsetTicks: 12, durationTicks: 4),
                ],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let middle = try #require(layout.measures.first { $0.measureID.rawValue == "0.2" })

    #expect(middle.frame.width >= 220)
}

@Test func chordPickupDurationIsNotDoubleCountedForWidth() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "root", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4),
                    makeNote(id: "third", pitch: Pitch(step: .e, octave: 4), onsetTicks: 0, durationTicks: 4, isChordTone: true, chordOrdinal: 1),
                    makeNote(id: "fifth", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 4, isChordTone: true, chordOrdinal: 2),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let measure = try #require(layout.measures.first)

    #expect(measure.frame.width >= 180)
    #expect(measure.frame.width < 250)
}

@Test func dottedRestDotStaysCloseToRestGlyph() throws {
    let score = makeScore(notes: [
        makeNote(id: "dotted-rest", pitch: nil, onsetTicks: 0, durationTicks: 6, noteValueKind: .eighth, dotCount: 1),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let restElement = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "dotted-rest.rest")))
    let dotElement = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "dotted-rest.dot.0")))

    #expect(dotElement.frame.minX > restElement.frame.maxX - restElement.frame.width * 0.08)
    #expect(dotElement.frame.minX - restElement.frame.maxX < restElement.frame.width * 0.02)
    #expect(abs(dotElement.frame.midY - restElement.frame.midY) < restElement.frame.height * 0.1)
}

@Test func dottedNoteDotStaysCloseToNotehead() throws {
    let score = makeScore(notes: [
        makeNote(id: "dotted-note", pitch: Pitch(step: .f, octave: 4), onsetTicks: 0, durationTicks: 3, noteValueKind: .eighth, dotCount: 1),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let note = try #require(layout.noteLayout(for: NoteID(rawValue: "dotted-note")))
    let dotElement = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "dotted-note.dot.0")))

    #expect(dotElement.frame.minX > note.noteheadFrame.maxX)
    #expect(dotElement.frame.minX - note.noteheadFrame.maxX < note.noteheadFrame.width * 0.25)
    #expect(abs(dotElement.frame.midY - note.noteheadFrame.midY) < note.noteheadFrame.height * 0.1)
}

@Test func noteValueKindsCreateExpectedLayoutElements() throws {
    let score = makeScore(notes: [
        makeNote(id: "whole", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 16, noteValueKind: .whole),
        makeNote(id: "half", pitch: Pitch(step: .d, octave: 4), onsetTicks: 16, durationTicks: 8, noteValueKind: .half),
        makeNote(id: "quarter", pitch: Pitch(step: .e, octave: 4), onsetTicks: 24, durationTicks: 4, noteValueKind: .quarter),
        makeNote(id: "eighth", pitch: Pitch(step: .f, octave: 4), onsetTicks: 28, durationTicks: 2, noteValueKind: .eighth, dotCount: 1),
        makeNote(id: "rest", pitch: nil, onsetTicks: 30, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.noteLayout(for: NoteID(rawValue: "whole"))?.noteValueKind == .whole)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "whole.stem")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "half.stem"))?.kind == .stem)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "quarter.stem"))?.kind == .stem)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.stem"))?.kind == .stem)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth.dot.0"))?.kind == .dot)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "rest.rest"))?.noteLayout?.noteValueKind == .eighth)
}

@Test func s6TieSlurBeamAndTupletElementsAreGeneratedFromDomainModel() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = makeScore(
        notes: [
            makeNote(id: "beam-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 1, noteValueKind: .sixteenth),
            makeNote(id: "beam-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 1, durationTicks: 1, noteValueKind: .sixteenth),
            makeNote(id: "beam-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 2, durationTicks: 1, noteValueKind: .sixteenth),
            makeNote(id: "tie-start", pitch: Pitch(step: .g, octave: 4), onsetTicks: 8, durationTicks: 4, ties: [.start]),
            makeNote(id: "tie-stop", pitch: Pitch(step: .g, octave: 4), onsetTicks: 12, durationTicks: 4, ties: [.stop]),
            makeNote(id: "slur-start", pitch: Pitch(step: .e, octave: 4), onsetTicks: 16, durationTicks: 2, noteValueKind: .eighth, slurs: [.start]),
            makeNote(id: "slur-middle", pitch: Pitch(step: .f, octave: 4), onsetTicks: 18, durationTicks: 2, noteValueKind: .eighth),
            makeNote(id: "slur-stop", pitch: Pitch(step: .g, octave: 4), onsetTicks: 20, durationTicks: 2, noteValueKind: .eighth, slurs: [.stop]),
            makeNote(id: "trip-a", pitch: Pitch(step: .a, octave: 4), onsetTicks: 24, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: .start, actualNotes: 3, normalNotes: 2)),
            makeNote(id: "trip-b", pitch: Pitch(step: .b, octave: 4), onsetTicks: 26, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: nil, actualNotes: 3, normalNotes: 2)),
            makeNote(id: "trip-c", pitch: Pitch(step: .c, octave: 5), onsetTicks: 28, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: .stop, actualNotes: 3, normalNotes: 2)),
        ],
        measureID: measureID
    )

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == .beam })
    #expect(layout.elements.contains { $0.kind == .tie && $0.curve?.kind == .tie })
    #expect(layout.elements.contains { $0.kind == .slur && $0.curve?.kind == .slur })
    #expect(layout.elements.contains { $0.kind == .tuplet && $0.tuplet?.number == "3" })
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "beam-a.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "beam-b.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "beam-c.flag")) == nil)
    #expect(layout.noteLayout(for: NoteID(rawValue: "tie-start"))?.staffID == staffID)
}

@Test func tupletBracketClearsTheBeamAndLeavesRoomForItsNumeral() throws {
    let score = makeScore(notes: [
        makeNote(id: "triplet-a", pitch: Pitch(step: .e, octave: 5), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: .start, actualNotes: 3, normalNotes: 2)),
        makeNote(id: "triplet-b", pitch: Pitch(step: .f, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: nil, actualNotes: 3, normalNotes: 2)),
        makeNote(id: "triplet-c", pitch: Pitch(step: .g, octave: 5), onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth, tuplet: TupletInfo(kind: .stop, actualNotes: 3, normalNotes: 2)),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)
    let tuplet = try #require(layout.elements.first { $0.kind == .tuplet }?.tuplet)

    let beamTop = min(beam.primary.start.y, beam.primary.end.y) - beam.thickness / 2
    #expect(tuplet.frame.maxY < beamTop)
    #expect(tuplet.frame.height >= 5)
}

@Test func restAndSingleEighthBreakBeamGroups() throws {
    let score = makeScore(notes: [
        makeNote(id: "first-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "first-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "rest", pitch: nil, onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "single", pitch: Pitch(step: .e, octave: 5), onsetTicks: 6, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "quarter", pitch: Pitch(step: .f, octave: 5), onsetTicks: 8, durationTicks: 4, noteValueKind: .quarter),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.filter { $0.kind == .beam }.count == 1)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "first-a.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "first-b.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "single.flag"))?.kind == .flag)
}

@Test func tieAndSlurCurvesUseOppositeStemSideOrientation() throws {
    let score = makeScore(notes: [
        makeNote(id: "tie-a", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 4, ties: [.start]),
        makeNote(id: "tie-b", pitch: Pitch(step: .g, octave: 4), onsetTicks: 4, durationTicks: 4, ties: [.stop]),
        makeNote(id: "slur-a", pitch: Pitch(step: .e, octave: 5), onsetTicks: 8, durationTicks: 4, slurs: [.start]),
        makeNote(id: "slur-b", pitch: Pitch(step: .f, octave: 5), onsetTicks: 12, durationTicks: 4),
        makeNote(id: "slur-c", pitch: Pitch(step: .g, octave: 5), onsetTicks: 16, durationTicks: 4, slurs: [.stop]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let tie = try #require(layout.elements.first { $0.kind == .tie }?.curve)
    let slur = try #require(layout.elements.first { $0.kind == .slur }?.curve)
    let tieStart = try #require(layout.noteLayout(for: NoteID(rawValue: "tie-a")))
    let slurStart = try #require(layout.noteLayout(for: NoteID(rawValue: "slur-a")))

    #expect(tieStart.staffPosition?.stepsFromMiddleLine ?? 0 < 0)
    #expect(tie.control.y > tieStart.noteheadCenter.y)
    #expect(slurStart.staffPosition?.stepsFromMiddleLine ?? 0 > 0)
    #expect(slur.control.y < slurStart.noteheadCenter.y)
    #expect(abs(slur.control.y - slur.start.y) > abs(tie.control.y - tie.start.y))
}

@Test func beamLayoutStartsAndEndsAtStemTipsAndSupportsSecondaryBeam() throws {
    let score = makeScore(notes: [
        makeNote(id: "sixteenth-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "sixteenth-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 1, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "eighth-a", pitch: Pitch(step: .e, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beamElement = try #require(layout.elements.first { $0.kind == .beam })
    let beam = try #require(beamElement.beam)
    let firstStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "sixteenth-a.stem")))
    let lastStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "eighth-a.stem")))
    let firstNote = try #require(layout.noteLayout(for: NoteID(rawValue: "sixteenth-a")))
    let lastNote = try #require(layout.noteLayout(for: NoteID(rawValue: "eighth-a")))
    let firstDrawsDown = firstStem.frame.midY > firstNote.noteheadCenter.y
    let lastDrawsDown = lastStem.frame.midY > lastNote.noteheadCenter.y

    #expect(beam.primary.start == CGPoint(x: firstStem.frame.midX, y: firstDrawsDown ? firstStem.frame.maxY : firstStem.frame.minY))
    #expect(beam.primary.end == CGPoint(x: lastStem.frame.midX, y: lastDrawsDown ? lastStem.frame.maxY : lastStem.frame.minY))
    #expect(beam.secondarySegments.count == 1)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "sixteenth-a.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "sixteenth-b.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "eighth-a.flag")) == nil)
}

@Test func intermediateBeamedStemTipsMeetSlopedPrimaryBeam() throws {
    let score = makeScore(notes: [
        makeNote(id: "beam-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "beam-b", pitch: Pitch(step: .g, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "beam-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)

    for noteID in beam.noteIDs {
        let stem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).stem")))
        let note = try #require(layout.noteLayout(for: noteID))
        let tipY = stemTipY(stem: stem, note: note)
        let beamY = primaryBeamY(beam, at: stem.frame.midX)

        #expect(abs(tipY - beamY) < 0.001)
    }
}

@Test func steepBeamsKeepReadableMinimumStemLength() throws {
    let score = makeScore(notes: [
        makeNote(
            id: "steep-a",
            pitch: Pitch(step: .c, octave: 5),
            onsetTicks: 0,
            durationTicks: 2,
            noteValueKind: .eighth,
            beams: [MusicXMLBeam(number: 1, value: .begin)]
        ),
        makeNote(
            id: "steep-b",
            pitch: Pitch(step: .g, octave: 5),
            onsetTicks: 2,
            durationTicks: 2,
            noteValueKind: .eighth,
            beams: [MusicXMLBeam(number: 1, value: .continue)]
        ),
        makeNote(
            id: "steep-c",
            pitch: Pitch(step: .e, octave: 5),
            onsetTicks: 4,
            durationTicks: 2,
            noteValueKind: .eighth,
            beams: [MusicXMLBeam(number: 1, value: .end)]
        ),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)

    for noteID in beam.noteIDs {
        let stem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).stem")))
        let note = try #require(layout.noteLayout(for: noteID))

        #expect(stemLength(stem: stem, note: note) >= 23.9)
    }
}

@Test func beamedNotesShareStemDirectionAcrossTheWholeBeamGroup() throws {
    let score = makeScore(notes: [
        makeNote(id: "chord-low", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "chord-high", pitch: Pitch(step: .c, octave: 6), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth, isChordTone: true, chordOrdinal: 1),
        makeNote(id: "next-low", pitch: Pitch(step: .d, octave: 4), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)
    let noteIDs = [NoteID(rawValue: "chord-low"), NoteID(rawValue: "chord-high"), NoteID(rawValue: "next-low")]
    let drawsDown = try noteIDs.map { noteID -> Bool in
        let stem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).stem")))
        let note = try #require(layout.noteLayout(for: noteID))
        return stem.frame.midY > note.noteheadCenter.y
    }

    #expect(beam.noteIDs == noteIDs)
    #expect(Set(drawsDown).count == 1)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "chord-low.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "next-low.flag")) == nil)
}

@Test func singleSixteenthAtEndOfMixedBeamUsesBackwardSecondaryHook() throws {
    let score = makeScore(notes: [
        makeNote(id: "eighth-a", pitch: Pitch(step: .g, octave: 4), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "sixteenth-a", pitch: Pitch(step: .g, octave: 4), onsetTicks: 2, durationTicks: 1, noteValueKind: .sixteenth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)
    let secondary = try #require(beam.secondarySegments.first)
    let sixteenthStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "sixteenth-a.stem")))

    #expect(secondary.start.x == sixteenthStem.frame.midX)
    #expect(secondary.end.x < secondary.start.x)
}

@Test func beamGroupsStayWithinBeatBoundaries() throws {
    let score = makeScore(notes: [
        makeNote(id: "beat1-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "beat1-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "beat2-a", pitch: Pitch(step: .e, octave: 5), onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "beat2-b", pitch: Pitch(step: .f, octave: 5), onsetTicks: 6, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beams = layout.elements.compactMap(\.beam)

    #expect(beams.count == 2)
    #expect(beams[0].noteIDs == [NoteID(rawValue: "beat1-a"), NoteID(rawValue: "beat1-b")])
    #expect(beams[1].noteIDs == [NoteID(rawValue: "beat2-a"), NoteID(rawValue: "beat2-b")])
}

@Test func complexPitchContourKeepsShortNotesFlaggedInsteadOfBeamed() throws {
    let score = makeScore(notes: [
        makeNote(id: "zig-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "zig-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 1, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "zig-c", pitch: Pitch(step: .c, octave: 5), onsetTicks: 2, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "zig-d", pitch: Pitch(step: .d, octave: 5), onsetTicks: 3, durationTicks: 1, noteValueKind: .sixteenth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == .beam } == false)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "zig-a.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "zig-b.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "zig-c.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "zig-d.flag"))?.kind == .flag)
}

@Test func explicitMusicXMLBeamsOverrideAutoContourFiltering() throws {
    let score = makeScore(notes: [
        makeNote(
            id: "explicit-zig-a",
            pitch: Pitch(step: .c, octave: 5),
            onsetTicks: 0,
            durationTicks: 1,
            noteValueKind: .sixteenth,
            beams: [MusicXMLBeam(number: 1, value: .begin), MusicXMLBeam(number: 2, value: .begin)]
        ),
        makeNote(
            id: "explicit-zig-b",
            pitch: Pitch(step: .d, octave: 5),
            onsetTicks: 1,
            durationTicks: 1,
            noteValueKind: .sixteenth,
            beams: [MusicXMLBeam(number: 1, value: .continue), MusicXMLBeam(number: 2, value: .continue)]
        ),
        makeNote(
            id: "explicit-zig-c",
            pitch: Pitch(step: .c, octave: 5),
            onsetTicks: 2,
            durationTicks: 1,
            noteValueKind: .sixteenth,
            beams: [MusicXMLBeam(number: 1, value: .continue), MusicXMLBeam(number: 2, value: .continue)]
        ),
        makeNote(
            id: "explicit-zig-d",
            pitch: Pitch(step: .d, octave: 5),
            onsetTicks: 3,
            durationTicks: 1,
            noteValueKind: .sixteenth,
            beams: [MusicXMLBeam(number: 1, value: .end), MusicXMLBeam(number: 2, value: .end)]
        ),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let beam = try #require(layout.elements.first { $0.kind == .beam }?.beam)

    #expect(beam.noteIDs == [
        NoteID(rawValue: "explicit-zig-a"),
        NoteID(rawValue: "explicit-zig-b"),
        NoteID(rawValue: "explicit-zig-c"),
        NoteID(rawValue: "explicit-zig-d"),
    ])
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "explicit-zig-a.flag")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "explicit-zig-d.flag")) == nil)
}

@Test func explicitMusicXMLBeamsStillSplitAcrossNaturalStemDirectionChanges() throws {
    let score = makeScore(notes: [
        makeNote(
            id: "low-upstem",
            pitch: Pitch(step: .c, octave: 4),
            onsetTicks: 0,
            durationTicks: 2,
            noteValueKind: .eighth,
            beams: [MusicXMLBeam(number: 1, value: .begin)]
        ),
        makeNote(
            id: "high-downstem",
            pitch: Pitch(step: .b, octave: 4),
            onsetTicks: 2,
            durationTicks: 2,
            noteValueKind: .eighth,
            beams: [MusicXMLBeam(number: 1, value: .end)]
        ),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == .beam } == false)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "low-upstem.flag"))?.kind == .flag)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "high-downstem.flag"))?.kind == .flag)
}

@Test func beamedShortNotesUseRhythmicSpacingInsteadOfUniformMeasureSpread() throws {
    let score = makeScore(notes: [
        makeNote(id: "eighth-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "eighth-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "eighth-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "quarter-a", pitch: Pitch(step: .f, octave: 5), onsetTicks: 8, durationTicks: 4, noteValueKind: .quarter),
        makeNote(id: "quarter-b", pitch: Pitch(step: .g, octave: 5), onsetTicks: 12, durationTicks: 4, noteValueKind: .quarter),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 640, staffSpace: 10))
    let eighthA = try #require(layout.noteLayout(for: NoteID(rawValue: "eighth-a")))
    let eighthB = try #require(layout.noteLayout(for: NoteID(rawValue: "eighth-b")))
    let eighthC = try #require(layout.noteLayout(for: NoteID(rawValue: "eighth-c")))
    let quarterA = try #require(layout.noteLayout(for: NoteID(rawValue: "quarter-a")))
    let quarterB = try #require(layout.noteLayout(for: NoteID(rawValue: "quarter-b")))

    let firstEighthGap = eighthB.noteheadCenter.x - eighthA.noteheadCenter.x
    let secondEighthGap = eighthC.noteheadCenter.x - eighthB.noteheadCenter.x
    let quarterGap = quarterB.noteheadCenter.x - quarterA.noteheadCenter.x

    #expect(abs(firstEighthGap - secondEighthGap) < 0.001)
    #expect(firstEighthGap < quarterGap)
    #expect(abs((firstEighthGap * 2) - quarterGap) < 0.001)
}

@Test func compactShortNoteGroupIsPositionedInsideNormalizedMeasure() throws {
    let score = makeScore(notes: [
        makeNote(id: "sixteenth-a", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "sixteenth-b", pitch: Pitch(step: .d, octave: 5), onsetTicks: 1, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "sixteenth-c", pitch: Pitch(step: .e, octave: 5), onsetTicks: 2, durationTicks: 1, noteValueKind: .sixteenth),
        makeNote(id: "sixteenth-d", pitch: Pitch(step: .f, octave: 5), onsetTicks: 3, durationTicks: 1, noteValueKind: .sixteenth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 640, staffSpace: 10))
    let measure = try #require(layout.measures.first)
    let first = try #require(layout.noteLayout(for: NoteID(rawValue: "sixteenth-a")))
    let second = try #require(layout.noteLayout(for: NoteID(rawValue: "sixteenth-b")))
    let third = try #require(layout.noteLayout(for: NoteID(rawValue: "sixteenth-c")))
    let fourth = try #require(layout.noteLayout(for: NoteID(rawValue: "sixteenth-d")))

    let leadingSpace = first.noteheadCenter.x - measure.frame.minX
    let trailingSpace = measure.frame.maxX - fourth.noteheadCenter.x
    let firstGap = second.noteheadCenter.x - first.noteheadCenter.x
    let secondGap = third.noteheadCenter.x - second.noteheadCenter.x
    let thirdGap = fourth.noteheadCenter.x - third.noteheadCenter.x

    #expect(leadingSpace > 30)
    #expect(leadingSpace < 75)
    #expect(trailingSpace > 30)
    #expect(firstGap >= 24)
    #expect(abs(firstGap - secondGap) < 0.001)
    #expect(abs(secondGap - thirdGap) < 0.001)
}

@Test func furEliseLikeSixteenthFlowKeepsReadableRhythmicGaps() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "e5-a", pitch: Pitch(step: .e, octave: 5), onsetTicks: 0, durationTicks: 1, noteValueKind: .sixteenth),
                    makeNote(id: "ds5", pitch: Pitch(step: .d, octave: 5, alter: 1), onsetTicks: 1, durationTicks: 1, noteValueKind: .sixteenth, accidental: "sharp"),
                    makeNote(id: "e5-b", pitch: Pitch(step: .e, octave: 5), onsetTicks: 2, durationTicks: 1, noteValueKind: .sixteenth),
                    makeNote(id: "b4", pitch: Pitch(step: .b, octave: 4), onsetTicks: 3, durationTicks: 1, noteValueKind: .sixteenth),
                    makeNote(id: "d5", pitch: Pitch(step: .d, octave: 5), onsetTicks: 4, durationTicks: 1, noteValueKind: .sixteenth, accidental: "natural"),
                    makeNote(id: "c5", pitch: Pitch(step: .c, octave: 5), onsetTicks: 5, durationTicks: 1, noteValueKind: .sixteenth),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 640, staffSpace: 10))
    let measure = try #require(layout.measures.first)
    let noteIDs = ["e5-a", "ds5", "e5-b", "b4", "d5", "c5"].map(NoteID.init(rawValue:))
    let xs = try noteIDs.map { try #require(layout.noteLayout(for: $0)).noteheadCenter.x }
    let gaps = zip(xs.dropFirst(), xs).map { $0.0 - $0.1 }

    #expect(gaps.allSatisfy { $0 >= 24 })
    #expect(xs[0] - measure.frame.minX < 90)
    #expect(measure.frame.maxX - xs[xs.count - 1] > 25)
    #expect(xs[xs.count - 1] - xs[0] < measure.frame.width * 0.75)
}

@Test func furEliseMeasureOneUsesExplicitMusicXMLBeamPairs() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let beams = layout.elements.compactMap { element -> BeamLayout? in
        guard element.kind == .beam, element.measureID == measureID else {
            return nil
        }
        return element.beam
    }

    #expect(beams.count == 3)
    #expect(beams.allSatisfy { $0.noteIDs.count == 2 })
}

@Test func furEliseBeamedStemTipsMeetPrimaryBeam() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let beams = layout.elements.compactMap(\.beam)

    #expect(beams.isEmpty == false)
    for beam in beams {
        for noteID in beam.noteIDs {
            let stem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).stem")))
            let note = try #require(layout.noteLayout(for: noteID))
            let tipY = stemTipY(stem: stem, note: note)
            let beamY = primaryBeamY(beam, at: stem.frame.midX)

            #expect(abs(tipY - beamY) < 0.001)
        }
    }
}

@Test func furEliseBeamedStemsKeepReadableMinimumLength() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let beams = layout.elements.compactMap(\.beam)

    #expect(beams.isEmpty == false)
    for beam in beams {
        for noteID in beam.noteIDs {
            let stem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "\(noteID.rawValue).stem")))
            let note = try #require(layout.noteLayout(for: noteID))

            #expect(stemLength(stem: stem, note: note) >= 19.1)
        }
    }
}

@Test func furEliseMeasureThirteenPlacesStaffTwoClefChangeBeforeLastNote() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let measure = try #require(score.parts.first?.measures.first { $0.number == "13" })
    let staff2 = StaffID(rawValue: "2")
    let change = try #require(measure.clefChanges.first { $0.staffID == staff2 })

    #expect(change.clef == Clef(kind: .treble))
    #expect(change.onset > MusicalTime(ticks: 0, ticksPerQuarterNote: 1))

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let clefElement = try #require(layout.elements.first {
        $0.kind == .clef
            && $0.measureID == measure.id
            && $0.staffID == staff2
            && $0.id.rawValue.contains("clefChange")
    })
    let notesAfterChange = measure.notes.filter {
        $0.staffID == staff2 && $0.pitch != nil && $0.onset >= change.onset
    }
    let firstAfterChange = try #require(notesAfterChange.min { $0.onset < $1.onset })
    let afterLayout = try #require(layout.noteLayout(for: firstAfterChange.id))
    let measureLayout = try #require(layout.measures.first { $0.measureID == measure.id })
    let nextMeasureLayout = try #require(layout.measures.first {
        $0.partIndex == measureLayout.partIndex && $0.measureIndex == measureLayout.measureIndex + 1
    })
    let overflowSensitiveKinds: Set<ScoreElementKind> = [
        .notehead,
        .rest,
        .stem,
        .flag,
        .beam,
        .accidental,
        .dot,
        .ledgerLine,
        .clef,
        .timeSignature,
        .keySignature,
    ]
    let measureElements = layout.elements.filter {
        $0.measureID == measure.id && overflowSensitiveKinds.contains($0.kind)
    }
    let maxContentX = try #require(measureElements.map(\.frame.maxX).max())

    #expect(afterLayout.clef == Clef(kind: .treble))
    #expect(clefElement.frame.maxX < afterLayout.noteheadFrame.minX)
    #expect(afterLayout.noteheadFrame.maxX <= measureLayout.frame.maxX)
    #expect(clefElement.frame.maxX < nextMeasureLayout.frame.minX)
    #expect(afterLayout.noteheadFrame.maxX < nextMeasureLayout.frame.minX)
    #expect(maxContentX <= measureLayout.frame.maxX + 0.5)
}

@Test func smuflReadableGlyphFramesRemainInsideCanvasBounds() throws {
    let score = makeScore(notes: [
        makeNote(id: "sharp-eighth", pitch: Pitch(step: .f, octave: 5, alter: 1), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth, accidental: "sharp"),
        makeNote(id: "rest", pitch: nil, onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "low-eighth", pitch: Pitch(step: .c, octave: 3), onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 320, staffSpace: 10))
    let notehead = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "sharp-eighth.notehead")))
    let accidental = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "sharp-eighth.accidental")))
    let flag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "sharp-eighth.flag")))
    let rest = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "rest.rest")))

    #expect(abs(notehead.frame.width - 13.5) < 0.001)
    #expect(abs(notehead.frame.height - 9.5) < 0.001)
    #expect(accidental.frame.height > notehead.frame.height)
    #expect(accidental.frame.width >= notehead.frame.width * 0.85)
    #expect(flag.frame.height >= notehead.frame.height * 1.8)
    #expect(rest.frame == layout.noteLayout(for: NoteID(rawValue: "rest"))?.noteheadFrame)
    #expect(notehead.frame.minX - accidental.frame.maxX <= notehead.frame.width * 0.45)

    for frame in [notehead.frame, accidental.frame, flag.frame, rest.frame] {
        #expect(frame.minY >= 0)
        #expect(frame.maxY <= layout.canvasSize.height)
        #expect(frame.maxX <= layout.canvasSize.width)
    }
}

@Test func flagFramesAttachToStemEndsForUpAndDownStems() throws {
    let score = makeScore(notes: [
        makeNote(id: "up-eighth", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "down-eighth", pitch: Pitch(step: .b, octave: 4), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let upStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "up-eighth.stem")))
    let upFlag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "up-eighth.flag")))
    let downStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "down-eighth.stem")))
    let downFlag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "down-eighth.flag")))

    #expect(abs(upFlag.frame.minX - upStem.frame.midX) < 0.001)
    #expect(abs(upFlag.frame.minY - upStem.frame.minY) < 0.001)
    #expect(abs(downFlag.frame.maxX - downStem.frame.midX) < 0.001)
    #expect(abs(downFlag.frame.maxY - downStem.frame.maxY) < 0.001)
    #expect(upStem.frame.height <= layout.noteLayout(for: NoteID(rawValue: "up-eighth"))!.noteheadFrame.height * 2.3)
    #expect(downStem.frame.height <= layout.noteLayout(for: NoteID(rawValue: "down-eighth"))!.noteheadFrame.height * 2.3)
}

@Test func stemsAlignWithTheOuterEdgesOfTheirNoteheads() throws {
    let score = makeScore(notes: [
        makeNote(id: "up-quarter", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4, noteValueKind: .quarter),
        makeNote(id: "down-quarter", pitch: Pitch(step: .b, octave: 4), onsetTicks: 4, durationTicks: 4, noteValueKind: .quarter),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let upNote = try #require(layout.noteLayout(for: NoteID(rawValue: "up-quarter")))
    let downNote = try #require(layout.noteLayout(for: NoteID(rawValue: "down-quarter")))
    let upStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "up-quarter.stem")))
    let downStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "down-quarter.stem")))

    #expect(abs(upStem.frame.midX - upNote.noteheadFrame.maxX) < 0.001)
    #expect(abs(downStem.frame.midX - downNote.noteheadFrame.minX) < 0.001)
}

@Test func stemDirectionUsesMiddleLineRuleForMVP() throws {
    let score = makeScore(notes: [
        makeNote(id: "below", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, durationTicks: 4, noteValueKind: .quarter),
        makeNote(id: "middle", pitch: Pitch(step: .b, octave: 4), onsetTicks: 4, durationTicks: 4, noteValueKind: .quarter),
        makeNote(id: "whole", pitch: Pitch(step: .c, octave: 4), onsetTicks: 8, durationTicks: 16, noteValueKind: .whole),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let belowNote = try #require(layout.noteLayout(for: NoteID(rawValue: "below")))
    let middleNote = try #require(layout.noteLayout(for: NoteID(rawValue: "middle")))
    let belowStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "below.stem")))
    let middleStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "middle.stem")))

    #expect(belowStem.frame.midY < belowNote.noteheadCenter.y)
    #expect(middleStem.frame.midY > middleNote.noteheadCenter.y)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "whole.stem")) == nil)
}

@Test func chordTonesShareStemDirectionForSameOnsetStaffAndVoice() throws {
    let score = makeScore(notes: [
        makeNote(id: "low-root", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, noteValueKind: .quarter),
        makeNote(id: "high-third", pitch: Pitch(step: .e, octave: 5), onsetTicks: 0, noteValueKind: .quarter, isChordTone: true, chordOrdinal: 1),
        makeNote(id: "upper-root", pitch: Pitch(step: .c, octave: 5), onsetTicks: 4, noteValueKind: .eighth),
        makeNote(id: "upper-third", pitch: Pitch(step: .e, octave: 5), onsetTicks: 4, noteValueKind: .eighth, isChordTone: true, chordOrdinal: 1),
        makeNote(id: "whole-root", pitch: Pitch(step: .c, octave: 4), onsetTicks: 8, durationTicks: 16, noteValueKind: .whole),
        makeNote(id: "whole-third", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8, durationTicks: 16, noteValueKind: .whole, isChordTone: true, chordOrdinal: 1),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    let lowRoot = try #require(layout.noteLayout(for: NoteID(rawValue: "low-root")))
    let highThird = try #require(layout.noteLayout(for: NoteID(rawValue: "high-third")))
    let lowRootStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "low-root.stem")))
    let highThirdStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "high-third.stem")))
    #expect(lowRootStem.frame.midY < lowRoot.noteheadCenter.y)
    #expect(highThirdStem.frame.midY < highThird.noteheadCenter.y)

    let upperRoot = try #require(layout.noteLayout(for: NoteID(rawValue: "upper-root")))
    let upperThird = try #require(layout.noteLayout(for: NoteID(rawValue: "upper-third")))
    let upperRootStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "upper-root.stem")))
    let upperThirdStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "upper-third.stem")))
    let upperRootFlag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "upper-root.flag")))
    let upperThirdFlag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "upper-third.flag")))
    #expect(upperRootStem.frame.midY > upperRoot.noteheadCenter.y)
    #expect(upperThirdStem.frame.midY > upperThird.noteheadCenter.y)
    #expect(upperRootFlag.frame.midY > upperRoot.noteheadCenter.y)
    #expect(upperThirdFlag.frame.midY > upperThird.noteheadCenter.y)

    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "whole-root.stem")) == nil)
    #expect(layout.elementLayout(for: ScoreElementID(rawValue: "whole-third.stem")) == nil)
    #expect(layout.noteLayout(for: NoteID(rawValue: "low-root"))?.noteID == NoteID(rawValue: "low-root"))
    #expect(layout.noteLayout(for: NoteID(rawValue: "high-third"))?.noteID == NoteID(rawValue: "high-third"))
}

@Test func canvasSizeIncludesRenderedElementBoundsAndSafePadding() throws {
    let score = makeScore(notes: [
        makeNote(id: "high-eighth", pitch: Pitch(step: .c, octave: 6), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "low-eighth", pitch: Pitch(step: .c, octave: 3), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "rest", pitch: nil, onsetTicks: 4, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(pageWidth: 320, staffSpace: 12))

    for element in layout.elements {
        #expect(element.frame.minY >= 0)
        #expect(element.frame.maxY <= layout.canvasSize.height)
        #expect(element.frame.maxX <= layout.canvasSize.width)
    }
    for ledgerLine in layout.ledgerLines {
        #expect(ledgerLine.frame.minY >= 0)
        #expect(ledgerLine.frame.maxY <= layout.canvasSize.height)
    }
    for noteLayout in layout.noteByID.values {
        #expect(noteLayout.noteheadFrame.minY >= 0)
        #expect(noteLayout.noteheadFrame.maxY <= layout.canvasSize.height)
        #expect(noteLayout.noteheadFrame.maxX <= layout.canvasSize.width)
    }
    #expect(layout.canvasSize.height > layout.staves[0].frame.maxY)
    #expect(layout.canvasSize.height >= (layout.elements.map(\.frame.maxY).max() ?? 0))
}

@Test func canvasOriginShiftsDownWhenHighNotationWouldRenderAboveZero() throws {
    let score = makeScore(notes: [
        makeNote(id: "extreme-high", pitch: Pitch(step: .c, octave: 8), onsetTicks: 0, durationTicks: 2, noteValueKind: .eighth),
        makeNote(id: "low", pitch: Pitch(step: .c, octave: 3), onsetTicks: 2, durationTicks: 2, noteValueKind: .eighth),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 320, staffSpace: 12, showPageMargins: false)
    )
    let highNote = try #require(layout.noteLayout(for: NoteID(rawValue: "extreme-high")))
    let highStem = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "extreme-high.stem")))
    let highFlag = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "extreme-high.flag")))

    #expect(highNote.noteheadFrame.minY >= 0)
    #expect(highStem.frame.minY >= 0)
    #expect(highFlag.frame.minY >= 0)
    #expect(layout.ledgerLines.allSatisfy { $0.frame.minY >= 0 })
    #expect(layout.elements.allSatisfy { $0.frame.minY >= 0 })
    #expect(layout.canvasSize.height >= (layout.elements.map { $0.frame.maxY }.max() ?? 0))
}

@Test func structuralNotationElementsAreGeneratedFromDomainModel() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, staffID: staffID),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                repeatBarlines: [
                    RepeatBarline(direction: .forward),
                    RepeatBarline(direction: .backward),
                ],
                measureRepeat: MeasureRepeat(count: 1)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == ScoreElementKind.clef && $0.clef?.kind == .treble })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.timeSignature && $0.timeSignature == TimeSignature(beats: 4, beatType: 4) })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.keySignature && $0.keySignature?.fifths == 1 })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.barline && $0.repeatBarline?.direction == .forward })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.barline && $0.repeatBarline?.direction == .backward })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.measureRepeat && $0.measureRepeat?.count == 1 })

    let clef = try #require(layout.elements.first { $0.kind == .clef })
    let key = try #require(layout.elements.first { $0.kind == .keySignature })
    let time = try #require(layout.elements.first { $0.kind == .timeSignature })
    let forwardRepeat = try #require(layout.elements.first { $0.kind == .barline && $0.repeatBarline?.direction == .forward })
    let backwardRepeat = try #require(layout.elements.first { $0.kind == .barline && $0.repeatBarline?.direction == .backward })
    let measureRepeat = try #require(layout.elements.first { $0.kind == .measureRepeat })
    let firstNote = try #require(layout.noteLayout(for: NoteID(rawValue: "n0")))
    #expect(clef.frame.maxX < key.frame.minX)
    #expect(key.frame.maxX < time.frame.minX)
    #expect(time.frame.maxX < forwardRepeat.frame.minX)
    #expect(forwardRepeat.frame.maxX < firstNote.noteheadFrame.minX)
    #expect(backwardRepeat.frame.midX > firstNote.noteheadFrame.midX)
    #expect(measureRepeat.frame.midX > clef.frame.minX)
    #expect(measureRepeat.frame.midX < backwardRepeat.frame.midX)
    #expect(time.frame.maxX < firstNote.noteheadFrame.minX)
}

@Test func layoutUsesRepeatStructureFromNonPrimaryPart() throws {
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "right", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [makeNote(id: "right-m1", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble)
            ),
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "2"),
                number: "2",
                notes: [makeNote(id: "right-m2", pitch: Pitch(step: .d, octave: 5), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble)
            ),
        ]),
        ScorePart(id: "left", measures: [
            Measure(
                id: MeasureID(partIndex: 1, measureNumber: "1"),
                number: "1",
                notes: [makeNote(id: "left-m1", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .bass),
                repeatBarlines: [RepeatBarline(direction: .forward)]
            ),
            Measure(
                id: MeasureID(partIndex: 1, measureNumber: "2"),
                number: "2",
                notes: [makeNote(id: "left-m2", pitch: Pitch(step: .d, octave: 3), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .bass),
                repeatBarlines: [RepeatBarline(direction: .backward)]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == .barline && $0.measureID?.rawValue == "0.1" && $0.repeatBarline?.direction == .forward })
    #expect(layout.elements.contains { $0.kind == .barline && $0.measureID?.rawValue == "0.2" && $0.repeatBarline?.direction == .backward })
}

@Test func prefixOrderPlacesKeySignatureBeforeTimeSignatureWithoutOverlap() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(id: "upper", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: StaffID(rawValue: "1")),
                    makeNote(id: "lower", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: StaffID(rawValue: "2")),
                ],
                clefsByStaff: [
                    StaffID(rawValue: "1"): Clef(kind: .treble),
                    StaffID(rawValue: "2"): Clef(kind: .bass),
                ],
                keySignature: KeySignature(fifths: -5, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    for staffID in [StaffID(rawValue: "1"), StaffID(rawValue: "2")] {
        let clef = try #require(layout.elements.first { $0.kind == .clef && $0.staffID == staffID })
        let time = try #require(layout.elements.first { $0.kind == .timeSignature && $0.staffID == staffID })
        let keyElements = layout.elements
            .filter { $0.kind == .keySignature && $0.staffID == staffID }
            .sorted { $0.frame.minX < $1.frame.minX }
        let firstKey = try #require(keyElements.first)
        let lastKey = try #require(keyElements.last)
        let note = try #require(layout.noteByID.values.first { $0.staffID == staffID })

        #expect(clef.frame.maxX < firstKey.frame.minX)
        #expect(lastKey.frame.maxX < time.frame.minX)
        #expect(time.frame.maxX < note.noteheadFrame.minX)
        for pair in zip(keyElements, keyElements.dropFirst()) {
            #expect(pair.1.frame.midX - pair.0.frame.midX <= 8)
        }
    }
}

@Test func displayTransposeKeySignatureUsesStandardPrefixSpacing() throws {
    let noteID = NoteID(rawValue: "display-note")
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [makeNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 0, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(displayTransposeSemitones: 2)
    )
    let time = try #require(layout.elements.first { $0.kind == .timeSignature })
    let key = try #require(layout.elements.first { $0.kind == .keySignature })
    let note = try #require(layout.noteLayout(for: noteID))

    #expect(key.keySignature?.fifths == 2)
    #expect(key.frame.maxX < time.frame.minX)
    #expect(time.frame.maxX < note.noteheadFrame.minX)
}

@Test func prefixOrderWithoutKeySignaturePlacesTimeAfterClef() throws {
    let noteID = NoteID(rawValue: "no-key-note")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [makeNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let clef = try #require(layout.elements.first { $0.kind == .clef })
    let time = try #require(layout.elements.first { $0.kind == .timeSignature })
    let note = try #require(layout.noteLayout(for: noteID))

    #expect(clef.frame.maxX < time.frame.minX)
    #expect(abs(time.frame.height - ((7.6 / 0.88) * 3.95 * 0.88)) < 0.001)
    #expect(time.frame.maxX < note.noteheadFrame.minX)
}

@Test func prefixOrderWithoutTimeSignaturePlacesKeyAfterClef() throws {
    let noteID = NoteID(rawValue: "no-time-note")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [makeNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 2, mode: "major")
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let clef = try #require(layout.elements.first { $0.kind == .clef })
    let keyElements = layout.elements
        .filter { $0.kind == .keySignature }
        .sorted { $0.frame.minX < $1.frame.minX }
    let firstKey = try #require(keyElements.first)
    let lastKey = try #require(keyElements.last)
    let note = try #require(layout.noteLayout(for: noteID))

    #expect(clef.frame.maxX < firstKey.frame.minX)
    #expect(lastKey.frame.maxX < note.noteheadFrame.minX)
}

@Test func prefixElementsIncreaseMeasureWidthInsteadOfCompressingNotes() throws {
    let prefixedID = MeasureID(partIndex: 0, measureNumber: "1")
    let plainID = MeasureID(partIndex: 0, measureNumber: "2")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: prefixedID,
                number: "1",
                notes: [
                    makeNote(id: "prefixed-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    makeNote(id: "prefixed-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 2, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
            Measure(
                id: plainID,
                number: "2",
                notes: [
                    makeNote(id: "plain-a", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    makeNote(id: "plain-b", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 900, staffSpace: 10, displayMode: .horizontal)
    )
    let prefixed = try #require(layout.measures.first { $0.measureID == prefixedID })
    let plain = try #require(layout.measures.first { $0.measureID == plainID })
    let prefixedFirstNote = try #require(layout.noteByID[NoteID(rawValue: "prefixed-a")])
    let plainFirstNote = try #require(layout.noteByID[NoteID(rawValue: "plain-a")])

    #expect(prefixed.frame.width - plain.frame.width > 50)
    #expect(prefixedFirstNote.noteheadCenter.x - prefixed.frame.minX > plainFirstNote.noteheadCenter.x - plain.frame.minX)
}

@Test func repeatEndingLayoutElementsAreGeneratedAboveStaff() throws {
    let measure1 = MeasureID(partIndex: 0, measureNumber: "1")
    let measure2 = MeasureID(partIndex: 0, measureNumber: "2")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measure1,
                number: "1",
                notes: [makeNote(id: "first-ending-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble),
                repeatBarlines: [RepeatBarline(direction: .backward)],
                repeatEndings: [
                    RepeatEnding(numbers: [1], kind: .start),
                    RepeatEnding(numbers: [1], kind: .stop),
                ]
            ),
            Measure(
                id: measure2,
                number: "2",
                notes: [makeNote(id: "second-ending-note", pitch: Pitch(step: .d, octave: 4), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble),
                repeatEndings: [
                    RepeatEnding(numbers: [2], kind: .start),
                    RepeatEnding(numbers: [2], kind: .stop),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let firstEnding = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "0.1.repeatEnding.1.start")))
    let secondEnding = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "0.2.repeatEnding.2.start")))
    let staff = try #require(layout.staves.first)

    #expect(firstEnding.kind == .repeatEnding)
    #expect(firstEnding.repeatEnding?.label == "1.")
    #expect(firstEnding.repeatEnding?.startsHere == true)
    #expect(firstEnding.repeatEnding?.stopsHere == true)
    #expect(firstEnding.repeatEnding?.startHookEnd == nil)
    #expect(firstEnding.repeatEnding?.endHookEnd != nil)
    #expect(secondEnding.repeatEnding?.label == "2.")
    #expect(firstEnding.frame.maxY < staff.frame.minY + staff.frame.height * 0.05)
    #expect(firstEnding.frame.minY >= 0)
    #expect(firstEnding.frame.maxX <= layout.canvasSize.width)
    #expect(firstEnding.repeatEnding?.lineStart.x ?? 0 < firstEnding.repeatEnding?.lineEnd.x ?? 0)
    #expect((firstEnding.repeatEnding?.lineStart.y ?? 0) < (firstEnding.repeatEnding?.labelPoint.y ?? 0))
}

@Test func furEliseRepeatEndingHooksMatchOpenBracketEdges() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            systemSpacing: 48,
            measureSpacing: 0,
            displayMode: .print,
            showPageMargins: true
        )
    )

    let firstEnding = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "0.8.repeatEnding.1.start"))?.repeatEnding)
    let secondEnding = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "0.9.repeatEnding.2.start"))?.repeatEnding)

    #expect(firstEnding.label == "1.")
    #expect(firstEnding.startHookEnd == nil)
    #expect(firstEnding.endHookEnd != nil)
    #expect(secondEnding.label == "2.")
    #expect(secondEnding.startHookEnd != nil)
    #expect(secondEnding.endHookEnd == nil)
}

@Test func furEliseRepeatEndingsAvoidSystemPrefixSymbols() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            systemSpacing: 48,
            measureSpacing: 0,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let prefixKinds: Set<ScoreElementKind> = [.clef, .keySignature, .timeSignature]

    for id in [
        ScoreElementID(rawValue: "0.8.repeatEnding.1.start"),
        ScoreElementID(rawValue: "0.9.repeatEnding.2.start"),
    ] {
        let ending = try #require(layout.elementLayout(for: id))
        let measureID = try #require(ending.measureID)
        let prefixEndX = layout.elements
            .filter { $0.measureID == measureID && prefixKinds.contains($0.kind) }
            .map(\.frame.maxX)
            .max()
        guard let prefixEndX else { continue }
        #expect((ending.repeatEnding?.lineStart.x ?? 0) - prefixEndX >= 4)
        #expect((ending.repeatEnding?.labelPoint.x ?? 0) - prefixEndX >= 4)
    }
}

@Test func furEliseSystemPrefixLeavesReadableSpaceBeforeFirstNote() throws {
    let sampleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Apps/DoReMiPalette/DoReMiPalette/Resources/Samples/Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl")
    let score = try DoReMiRenderer().parse(input: .mxlData(Data(contentsOf: sampleURL)))
    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 8,
            systemSpacing: 48,
            measureSpacing: 0,
            displayMode: .print,
            showPageMargins: true
        )
    )
    let prefixKinds: Set<ScoreElementKind> = [.clef, .keySignature, .timeSignature]
    var checkedPrefixGroups = 0

    for measure in layout.measures {
        let staffIDs = Set(layout.elements.compactMap { element -> StaffID? in
            guard element.measureID == measure.measureID,
                  prefixKinds.contains(element.kind),
                  !element.id.rawValue.contains("clefChange")
            else {
                return nil
            }
            return element.staffID
        })

        for staffID in staffIDs {
            let prefixElements = layout.elements
                .filter {
                    $0.measureID == measure.measureID
                        && $0.staffID == staffID
                        && prefixKinds.contains($0.kind)
                        && !$0.id.rawValue.contains("clefChange")
                }
            let prefixMaxX = prefixElements
                .map(\.frame.maxX)
                .max()
            let firstNoteMinX = layout.noteByID.values
                .filter { $0.measureID == measure.measureID && $0.staffID == staffID }
                .map(\.noteheadFrame.minX)
                .min()
            guard let prefixMaxX, let firstNoteMinX else {
                continue
            }
            checkedPrefixGroups += 1
            let requiredGap: CGFloat = prefixElements.contains { $0.kind == .timeSignature } ? 6 : 3
            #expect(firstNoteMinX - prefixMaxX >= requiredGap)
        }
    }

    #expect(checkedPrefixGroups > 0)
}

@Test func repeatAnnotationsAvoidClefKeyAndTimePrefix() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [makeNote(id: "prefixed-repeat-note", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 3, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4),
                repeatBarlines: [RepeatBarline(direction: .forward)],
                repeatEndings: [RepeatEnding(numbers: [1], kind: .start)],
                playbackJumpMarkers: [PlaybackJumpMarker(kind: .segno, text: "Segno")]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let prefixKinds: Set<ScoreElementKind> = [.clef, .keySignature, .timeSignature]
    let prefixFrames = layout.elements
        .filter { element in
            element.measureID == measureID && prefixKinds.contains(element.kind)
        }
        .map { element in element.frame }
    let prefixEndX = try #require(prefixFrames.map { frame in frame.maxX }.max())
    let repeatStart = try #require(layout.elements.first { element in
        element.measureID == measureID
            && element.kind == .barline
            && element.repeatBarline?.direction == .forward
    })
    let ending = try #require(layout.elements.first { element in
        element.measureID == measureID && element.kind == .repeatEnding
    })
    let marker = try #require(layout.elements.first { element in
        element.measureID == measureID && element.kind == .playbackJumpMarker
    })

    #expect(repeatStart.frame.minX > prefixEndX)
    #expect((ending.repeatEnding?.lineStart.x ?? 0) > prefixEndX)
    #expect(ending.frame.minX > prefixEndX)
    #expect((marker.playbackJumpMarker?.point.x ?? 0) > prefixEndX)
    #expect(marker.frame.minX > prefixEndX)
}

@Test func prefixWithoutTimeSignatureKeepsNotesCloserThanFullSystemPrefix() throws {
    let noTimeID = MeasureID(partIndex: 0, measureNumber: "1")
    let withTimeID = MeasureID(partIndex: 0, measureNumber: "2")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: noTimeID,
                number: "1",
                notes: [
                    makeNote(id: "no-time-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1, mode: "major")
            ),
            Measure(
                id: withTimeID,
                number: "2",
                notes: [
                    makeNote(id: "with-time-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble),
                keySignature: KeySignature(fifths: 1, mode: "major"),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 900, staffSpace: 10, displayMode: .horizontal)
    )
    let prefixKinds: Set<ScoreElementKind> = [.clef, .keySignature, .timeSignature]

    func firstNoteGap(measureID: MeasureID, noteID: String) throws -> CGFloat {
        let prefixMaxX = try #require(layout.elements
            .filter { $0.measureID == measureID && prefixKinds.contains($0.kind) }
            .map(\.frame.maxX)
            .max())
        let note = try #require(layout.noteByID[NoteID(rawValue: noteID)])
        return note.noteheadFrame.minX - prefixMaxX
    }

    let noTimeGap = try firstNoteGap(measureID: noTimeID, noteID: "no-time-note")
    _ = try firstNoteGap(measureID: withTimeID, noteID: "with-time-note")

    #expect(noTimeGap >= 3)
    #expect(noTimeGap <= 6)
}

@Test func clefOnlyPrefixKeepsReadableSpaceBeforeFirstNote() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(id: "clef-only-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 900, staffSpace: 10, displayMode: .horizontal)
    )
    let clef = try #require(layout.elements.first { $0.measureID == measureID && $0.kind == .clef })
    let note = try #require(layout.noteByID[NoteID(rawValue: "clef-only-note")])
    let gap = note.noteheadFrame.minX - clef.frame.maxX

    #expect(gap >= 8)
    #expect(gap <= 12)
}

@Test func playbackJumpMarkerLayoutElementsAreGeneratedAboveStaff() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [makeNote(id: "jump-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble),
                playbackJumpMarkers: [
                    PlaybackJumpMarker(kind: .dalSegnoAlCoda, text: "D.S. al Coda"),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let marker = try #require(layout.elements.first { $0.kind == .playbackJumpMarker })
    let staff = try #require(layout.staves.first)

    #expect(marker.playbackJumpMarker?.label == "D.S. al Coda")
    #expect(marker.frame.maxY < staff.frame.minY)
    #expect(marker.frame.minY >= 0)
    #expect(marker.frame.maxX <= layout.canvasSize.width)
}

@Test func noteByIDAndElementByIDIncludeNoteheadsAndLedgerLines() throws {
    let score = makeScore(notes: [
        makeNote(id: "low-c", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let noteLayout = try #require(layout.noteLayout(for: NoteID(rawValue: "low-c")))
    let noteheadID = try #require(noteLayout.noteheadElementID)
    let noteheadElement = try #require(layout.elementLayout(for: noteheadID))

    #expect(noteheadElement.kind == .notehead)
    #expect(noteheadElement.noteID == NoteID(rawValue: "low-c"))
    #expect(noteheadElement.pitchClassHint == .c)
    #expect(layout.elements.contains { $0.id == noteheadID })
    #expect(layout.ledgerLines.count == 1)
    #expect(layout.elementLayout(for: layout.ledgerLines[0].id)?.kind == .ledgerLine)
}

@Test func multipleLedgerLinesUseEachLedgerLinePitchClassHint() throws {
    let score = makeScore(notes: [
        makeNote(id: "high-c", pitch: Pitch(step: .c, octave: 6), onsetTicks: 0),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let ledgerLines = layout.ledgerLines
        .filter { $0.noteID == NoteID(rawValue: "high-c") }
        .sorted { $0.lineStepFromMiddle < $1.lineStepFromMiddle }

    #expect(ledgerLines.map(\.lineStepFromMiddle) == [6, 8])
    #expect(ledgerLines.compactMap(\.pitchClassHint) == [.a, .c])
    #expect(ledgerLines.compactMap { layout.elementLayout(for: $0.id)?.pitchClassHint } == [.a, .c])
}

@Test func staffSpecificClefsAffectGrandStaffVerticalPlacement() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let upperID = NoteID(rawValue: "upper")
    let lowerID = NoteID(rawValue: "lower")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(id: upperID.rawValue, pitch: Pitch(step: .b, octave: 4), onsetTicks: 0, staffID: StaffID(rawValue: "1")),
                    makeNote(id: lowerID.rawValue, pitch: Pitch(step: .d, octave: 3), onsetTicks: 0, staffID: StaffID(rawValue: "2")),
                ],
                clef: Clef(kind: .treble),
                clefsByStaff: [
                    StaffID(rawValue: "1"): Clef(kind: .treble),
                    StaffID(rawValue: "2"): Clef(kind: .bass),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let upper = try #require(layout.noteLayout(for: upperID))
    let lower = try #require(layout.noteLayout(for: lowerID))

    #expect(upper.staffPosition?.stepsFromMiddleLine == 0)
    #expect(lower.staffPosition?.stepsFromMiddleLine == 0)
}

@Test func grandStaffUpperAndLowerStavesHaveAdditionalSeparation() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [
                    makeNote(id: "upper", pitch: Pitch(step: .b, octave: 4), onsetTicks: 0, staffID: StaffID(rawValue: "1")),
                    makeNote(id: "lower", pitch: Pitch(step: .d, octave: 3), onsetTicks: 0, staffID: StaffID(rawValue: "2")),
                ],
                clef: Clef(kind: .treble),
                clefsByStaff: [
                    StaffID(rawValue: "1"): Clef(kind: .treble),
                    StaffID(rawValue: "2"): Clef(kind: .bass),
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let upperStaff = try #require(layout.staves.first { $0.staffID == StaffID(rawValue: "1") })
    let lowerStaff = try #require(layout.staves.first { $0.staffID == StaffID(rawValue: "2") })

    #expect(abs((lowerStaff.frame.minY - upperStaff.frame.maxY) - 100) < 0.001)

    let a4Layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let a4UpperStaff = try #require(a4Layout.staves.first { $0.staffID == StaffID(rawValue: "1") })
    let a4LowerStaff = try #require(a4Layout.staves.first { $0.staffID == StaffID(rawValue: "2") })

    #expect(abs((a4LowerStaff.frame.minY - a4UpperStaff.frame.maxY) - 36) < 0.001)
}

@Test func staffLineElementsHaveStableIDsAndPitchClassHints() throws {
    let trebleMeasureID = MeasureID(partIndex: 0, measureNumber: "1")
    let bassMeasureID = MeasureID(partIndex: 0, measureNumber: "2")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: trebleMeasureID,
                number: "1",
                notes: [makeNote(id: "treble-note", pitch: Pitch(step: .b, octave: 4), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble)
            ),
            Measure(
                id: bassMeasureID,
                number: "2",
                notes: [makeNote(id: "bass-note", pitch: Pitch(step: .d, octave: 3), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .bass)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)
    let trebleBottom = try #require(layout.staffLines.first { $0.measureID == trebleMeasureID && $0.lineIndex == 0 })
    let bassTop = try #require(layout.staffLines.first { $0.measureID == bassMeasureID && $0.lineIndex == 4 })

    #expect(trebleBottom.id == ScoreElementID(rawValue: "1.0.1.staffLine.0"))
    #expect(trebleBottom.pitchClassHint == .e)
    #expect(layout.elementLayout(for: trebleBottom.id)?.kind == .staffLine)
    #expect(bassTop.id == ScoreElementID(rawValue: "1.0.2.staffLine.4"))
    #expect(bassTop.pitchClassHint == .a)
    #expect(layout.elementLayout(for: bassTop.id)?.pitchClassHint == .a)
}

@Test func staffLineSpacingAndClefFrameUseTightNotationScale() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: measureID,
                number: "1",
                notes: [makeNote(id: "c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, staffID: staffID)],
                clef: Clef(kind: .treble)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(staffSpace: 10))
    let lines = layout.staffLines
        .filter { $0.measureID == measureID && $0.staffID == staffID }
        .sorted { $0.lineIndex < $1.lineIndex }
    let first = try #require(lines.first)
    let second = try #require(lines.dropFirst().first)
    let clef = try #require(layout.elements.first { $0.kind == .clef && $0.clef?.kind == .treble })
    let notehead = try #require(layout.elementLayout(for: ScoreElementID(rawValue: "c4.notehead")))

    #expect(abs((first.start.y - second.start.y) - 7.6) < 0.001)
    #expect(abs(notehead.frame.height - 9.5) < 0.001)
    #expect(abs(clef.frame.minX - (24 + (7.6 / 0.88) * 0.65 + 3)) < 0.001)
    #expect(clef.frame.height < 45.5)
    #expect(clef.frame.height > 34)
}

@Test func trebleAndBassClefsProduceDifferentYForSamePitch() throws {
    let treble = try ScoreLayoutEngine().layout(
        score: makeScore(notes: [makeNote(id: "c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)], clef: Clef(kind: .treble)),
        options: LayoutOptions(staffSpace: 10)
    )
    let bass = try ScoreLayoutEngine().layout(
        score: makeScore(notes: [makeNote(id: "c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)], clef: Clef(kind: .bass)),
        options: LayoutOptions(staffSpace: 10)
    )

    let trebleCenter = try #require(treble.noteLayout(for: NoteID(rawValue: "c4"))?.noteheadCenter)
    let bassCenter = try #require(bass.noteLayout(for: NoteID(rawValue: "c4"))?.noteheadCenter)

    #expect(trebleCenter.y > bassCenter.y)
}

@Test func clefFramesUseVisualVerticalOffsetsForTrebleAndBass() throws {
    let treble = try ScoreLayoutEngine().layout(
        score: makeScore(notes: [makeNote(id: "treble-c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)], clef: Clef(kind: .treble)),
        options: LayoutOptions(staffSpace: 10)
    )
    let bass = try ScoreLayoutEngine().layout(
        score: makeScore(notes: [makeNote(id: "bass-c4", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0)], clef: Clef(kind: .bass)),
        options: LayoutOptions(staffSpace: 10)
    )

    let trebleClef = try #require(treble.elements.first { $0.kind == .clef && $0.clef?.kind == .treble })
    let trebleStaff = try #require(treble.staves.first)
    let bassClef = try #require(bass.elements.first { $0.kind == .clef && $0.clef?.kind == .bass })
    let bassStaff = try #require(bass.staves.first)

    #expect(abs((trebleClef.frame.midY - trebleStaff.middleLineY) - 0.75) < 0.001)
    #expect(abs((bassClef.frame.midY - bassStaff.middleLineY) - (-3.25)) < 0.001)
}

@Test func styleAndColorRuleChangesDoNotAffectLayoutIDs() throws {
    let score = makeScore(notes: [
        makeNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        makeNote(id: "n1", pitch: Pitch(step: .g, octave: 4), onsetTicks: 4),
    ])
    let layout = try ScoreLayoutEngine().layout(score: score)
    let noteIDsBefore = Set(layout.noteByID.keys)
    let elementIDsBefore = Set(layout.elementByID.keys)
    let styles = [
        ScoreStyle(staffLineStyle: .monochrome(.black), noteColorStyle: .monochrome(.black)),
        ScoreStyle(
            staffLineStyle: .rule(ClefAwareStaffLineColorRule(defaultPalette: defaultEducationalPalette)),
            noteColorStyle: .rule(PitchClassNoteColorRule(palette: defaultEducationalPalette))
        ),
    ]

    for style in styles {
        _ = layout.elements.map {
            style.colorResolver.resolvedStyle(for: $0, score: score, layout: layout, style: style, selection: nil as ScoreSelection?)
        }
    }

    #expect(Set(layout.noteByID.keys) == noteIDsBefore)
    #expect(Set(layout.elementByID.keys) == elementIDsBefore)
}

@Test func unsupportedDisplayModeReturnsDiagnosticWhenPolicyAllowsFallback() throws {
    let score = makeScore(notes: [
        makeNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ])
    let options = LayoutOptions(displayMode: .verticalPractice, unsupportedFeaturePolicy: .ignoreWithWarning)

    let result = try ScoreLayoutEngine().layoutWithDiagnostics(score: score, options: options)

    #expect(!result.layout.noteByID.isEmpty)
    #expect(result.diagnostics.contains { $0.severity == .warning && $0.code == "unsupported.displayMode" })
}

@Test func printDisplayModeWrapsMeasuresAcrossSystemsButHorizontalKeepsSingleSystem() throws {
    let measures = (0..<10).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index + 1)"),
            number: "\(index + 1)",
            notes: [
                makeNote(
                    id: "n\(index)",
                    pitch: Pitch(step: .c, octave: 4),
                    onsetTicks: 0,
                    durationTicks: 4
                ),
            ],
            clef: index == 0 ? Clef(kind: .treble) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let printLayout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 320, staffSpace: 10, displayMode: .print)
    )
    let horizontalLayout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 320, staffSpace: 10, displayMode: .horizontal)
    )

    #expect(printLayout.systems.count > 1)
    #expect(Set(horizontalLayout.measures.map(\.systemIndex)) == [0])
    #expect(printLayout.canvasSize.width <= horizontalLayout.canvasSize.width)
    #expect(printLayout.canvasSize.height > horizontalLayout.canvasSize.height)
}

@Test func a4PrintLayoutKeepsFixedWidthAndCapsSystemsAtFourMeasures() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: (0..<12).map { index in
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "\(index + 1)"),
                number: "\(index + 1)",
                notes: [
                    makeNote(id: "a4-\(index)-0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    makeNote(id: "a4-\(index)-1", pitch: Pitch(step: .d, octave: 4), onsetTicks: 4),
                    makeNote(id: "a4-\(index)-2", pitch: Pitch(step: .e, octave: 4), onsetTicks: 8),
                    makeNote(id: "a4-\(index)-3", pitch: Pitch(step: .f, octave: 4), onsetTicks: 12),
                ],
                clef: index == 0 ? Clef(kind: .treble) : nil,
                timeSignature: index == 0 ? TimeSignature(beats: 4, beatType: 4) : nil
            )
        }),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let measuresBySystem = Dictionary(grouping: layout.measures, by: \.systemIndex).mapValues(\.count)

    #expect(layout.canvasSize.width == 595)
    #expect(measuresBySystem.values.allSatisfy { $0 <= 4 })
    #expect(measuresBySystem.values.contains(4))
    #expect(abs((layout.measures.map(\.frame.minX).min() ?? 0) - 24) < 0.001)
    #expect(abs((layout.systems.first?.frame.width ?? 0) - 547) < 0.001)
}

@Test func a4PrintLayoutUsesPublicationPageMargins() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "margin-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let firstSystem = try #require(layout.systems.first)
    let firstStaff = try #require(layout.staves.first)

    #expect(layout.canvasSize == CGSize(width: 595, height: 842))
    #expect(abs(firstSystem.frame.minX - 24) < 0.001)
    #expect(abs(firstSystem.frame.width - 547) < 0.001)
    #expect(abs(firstStaff.frame.minX - 24) < 0.001)
    #expect(abs(firstStaff.frame.width - 547) < 0.001)
    #expect(firstSystem.frame.minY >= 36)
}

@Test func a4PrintLayoutReducesMeasuresPerSystemForDenseMeasures() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: (0..<6).map { measureIndex in
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "\(measureIndex + 1)"),
                number: "\(measureIndex + 1)",
                notes: (0..<8).map { noteIndex in
                    makeNote(
                        id: "dense-\(measureIndex)-\(noteIndex)",
                        pitch: Pitch(step: .c, octave: 4),
                        onsetTicks: noteIndex * 2,
                        durationTicks: 2,
                        noteValueKind: .eighth
                    )
                },
                clef: measureIndex == 0 ? Clef(kind: .treble) : nil,
                timeSignature: measureIndex == 0 ? TimeSignature(beats: 4, beatType: 4) : nil
            )
        }),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let measuresBySystem = Dictionary(grouping: layout.measures, by: \.systemIndex).mapValues(\.count)

    #expect(layout.canvasSize.width == 595)
    #expect(measuresBySystem.values.allSatisfy { $0 <= 3 })
    #expect(measuresBySystem.values.contains { $0 < 4 })
}

@Test func a4PrintLayoutCentersTitleAboveFirstSystem() throws {
    let score = ScoreDocument(
        parts: [
            ScorePart(id: "p1", measures: [
                Measure(
                    id: MeasureID(partIndex: 0, measureNumber: "1"),
                    number: "1",
                    notes: [
                        makeNote(id: "title-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    ],
                    clef: Clef(kind: .treble),
                    timeSignature: TimeSignature(beats: 4, beatType: 4)
                ),
            ]),
        ],
        title: "Ode to Joy"
    )

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let title = try #require(layout.title)
    let firstSystem = try #require(layout.systems.first)

    #expect(title.text == "Ode to Joy")
    #expect(title.fontName == "TimesNewRomanPS-BoldMT")
    #expect(abs(title.fontSize - 22.8) < 0.001)
    #expect(abs(title.frame.midX - 595 / 2) < 0.001)
    #expect(firstSystem.frame.minY - title.frame.maxY >= 50)
}

@Test func a4PrintLayoutCreatesSDKPagesWithSixSystemTarget() throws {
    let measures = (1...28).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "page-note-\(index)", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
            ],
            clef: index == 1 ? Clef(kind: .treble) : nil,
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)], title: "Paged Score")

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 8,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    ))

    #expect(!layout.pages.isEmpty)
    #expect(layout.pages.allSatisfy { $0.frame.width == 595 && $0.frame.height == 842 })
    #expect(layout.pages.dropLast().allSatisfy { $0.systemIndices.count <= 6 })
    #expect(layout.canvasSize.height >= CGFloat(layout.pages.count) * 842)
    for page in layout.pages {
        for systemIndex in page.systemIndices {
            let system = try #require(layout.systems.first { $0.index == systemIndex })
            #expect(page.frame.contains(CGPoint(x: system.frame.minX, y: system.frame.minY)))
            #expect(page.frame.contains(CGPoint(x: system.frame.maxX, y: system.frame.maxY)))
        }
    }
}

@Test func a4PrintLayoutReservesFirstPageTitleSlotAndPlacesFiveSystems() throws {
    let measures = (1...48).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "title-page-\(index)", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
            ],
            clef: index == 1 ? Clef(kind: .treble) : nil,
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)], title: "Title Slot Score")

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 5.2,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    ))
    let firstPage = try #require(layout.pages.first)
    let secondPage = try #require(layout.pages.dropFirst().first)
    let firstSystem = try #require(firstPage.systemIndices.first.flatMap { systemIndex in
        layout.systems.first { $0.index == systemIndex }
    })

    #expect(firstPage.systemIndices.count == 5)
    #expect(secondPage.systemIndices.count == 6)
    #expect(firstSystem.frame.minY > firstPage.frame.minY + 135)
}

@Test func a4PrintLayoutKeepsSixGrandStaffSystemsInsidePageContentFrame() throws {
    let trebleStaff = StaffID(rawValue: "1")
    let bassStaff = StaffID(rawValue: "2")
    let measures = (1...24).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "a4-grand-\(index)-treble", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: trebleStaff),
                makeNote(id: "a4-grand-\(index)-bass", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: bassStaff),
            ],
            clefsByStaff: index == 1 ? [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ] : [:],
            effectiveClefsByStaff: [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ],
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 5.2,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    ))
    let firstPage = try #require(layout.pages.first)

    #expect(firstPage.systemIndices.count == 6)
    for systemIndex in firstPage.systemIndices {
        let contentFrame = try #require(renderedContentFrame(forSystemIndex: systemIndex, in: layout))
        #expect(contentFrame.minY >= firstPage.contentFrame.minY - 0.5)
        #expect(contentFrame.maxY <= firstPage.contentFrame.maxY + 0.5)
    }
}

@Test func a4PrintLayoutKeepsTallGrandStaffSystemsInsidePageContentFrame() throws {
    let trebleStaff = StaffID(rawValue: "1")
    let bassStaff = StaffID(rawValue: "2")
    let measures = (1...32).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "a4-tall-\(index)-treble", pitch: Pitch(step: .c, octave: 7), onsetTicks: 0, staffID: trebleStaff),
                makeNote(id: "a4-tall-\(index)-bass", pitch: Pitch(step: .c, octave: 1), onsetTicks: 0, staffID: bassStaff),
            ],
            clefsByStaff: index == 1 ? [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ] : [:],
            effectiveClefsByStaff: [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ],
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 5.2,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    ))
    let firstPage = try #require(layout.pages.first)

    #expect(firstPage.systemIndices.count >= 1)
    #expect(firstPage.systemIndices.count <= 6)
    for systemIndex in firstPage.systemIndices {
        let contentFrame = try #require(renderedContentFrame(forSystemIndex: systemIndex, in: layout))
        #expect(contentFrame.minY >= firstPage.contentFrame.minY - 0.5)
        #expect(contentFrame.maxY <= firstPage.contentFrame.maxY + 0.5)
    }
}

@Test func a4PrintLayoutKeepsGrandStaffGapsStableWhenPageHasFewerThanSixSystems() throws {
    let trebleStaff = StaffID(rawValue: "1")
    let bassStaff = StaffID(rawValue: "2")
    let measures = (1...16).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "a4-four-\(index)-treble", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: trebleStaff),
                makeNote(id: "a4-four-\(index)-bass", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: bassStaff),
            ],
            clefsByStaff: index == 1 ? [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ] : [:],
            effectiveClefsByStaff: [
                trebleStaff: Clef(kind: .treble),
                bassStaff: Clef(kind: .bass),
            ],
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 5.2,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    ))
    let firstPage = try #require(layout.pages.first)
    let frames = try firstPage.systemIndices.map { systemIndex in
        try #require(renderedContentFrame(forSystemIndex: systemIndex, in: layout))
    }
    let gaps = zip(frames, frames.dropFirst()).map { first, second in
        second.minY - first.maxY
    }

    #expect(firstPage.systemIndices.count == 4)
    #expect(gaps.allSatisfy { $0 >= 36 && $0 <= 44 })
}

@Test func a4PrintLayoutHonorsManualPageBreakBeforeMeasure() throws {
    let measures = (1...12).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index)"),
            number: "\(index)",
            notes: [
                makeNote(id: "manual-page-note-\(index)", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
            ],
            clef: index == 1 ? Clef(kind: .treble) : nil,
            timeSignature: index == 1 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)], title: "Manual Page Break")

    let layout = try ScoreLayoutEngine().layout(score: score, options: LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 8,
        systemSpacing: 120,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true,
        manualPageBreakBeforeMeasureIDs: [MeasureID(partIndex: 0, measureNumber: "9")]
    ))
    let measure9 = try #require(layout.measures.first { $0.measureID == MeasureID(partIndex: 0, measureNumber: "9") })
    let pageForMeasure9 = try #require(layout.pages.first { $0.systemIndices.contains(measure9.systemIndex) })

    #expect(layout.pages.count >= 2)
    #expect(pageForMeasure9.index == 1)
}

@Test func horizontalLayoutOmitsCanvasTitleForFixedAppHeader() throws {
    let score = ScoreDocument(
        parts: [
            ScorePart(id: "p1", measures: [
                Measure(
                    id: MeasureID(partIndex: 0, measureNumber: "1"),
                    number: "1",
                    notes: [
                        makeNote(id: "horizontal-title-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                    ],
                    clef: Clef(kind: .treble),
                    timeSignature: TimeSignature(beats: 4, beatType: 4)
                ),
            ]),
        ],
        title: "Ode to Joy"
    )

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 980, staffSpace: 16, displayMode: .horizontal)
    )
    let firstSystem = try #require(layout.systems.first)

    #expect(layout.title == nil)
    #expect(firstSystem.frame.minY >= 0)
}

@Test func a4PrintLayoutDoesNotUsePartNameAsScoreTitle() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", name: "Piano", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "part-title-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())

    #expect(layout.title == nil)
}

@Test func horizontalLayoutDoesNotUsePartNameAsScoreTitle() throws {
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", name: "Piano", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "horizontal-part-title-note", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(
        score: score,
        options: LayoutOptions(pageWidth: 980, staffSpace: 16, displayMode: .horizontal)
    )

    #expect(layout.title == nil)
}

@Test func multiPartPianoDuetMeasuresStackPartsInsteadOfAppendingPartAfterPart() throws {
    let upperStaff = StaffID(rawValue: "1")
    let lowerStaff = StaffID(rawValue: "2")
    let score = ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(
                id: MeasureID(partIndex: 0, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "p1-treble", pitch: Pitch(step: .c, octave: 5), onsetTicks: 0, staffID: upperStaff),
                    makeNote(id: "p1-bass", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: lowerStaff),
                ],
                clefsByStaff: [upperStaff: Clef(kind: .treble), lowerStaff: Clef(kind: .bass)],
                effectiveClefsByStaff: [upperStaff: Clef(kind: .treble), lowerStaff: Clef(kind: .bass)],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
        ScorePart(id: "p2", measures: [
            Measure(
                id: MeasureID(partIndex: 1, measureNumber: "1"),
                number: "1",
                notes: [
                    makeNote(id: "p2-treble", pitch: Pitch(step: .e, octave: 5), onsetTicks: 0, staffID: upperStaff),
                    makeNote(id: "p2-bass", pitch: Pitch(step: .e, octave: 3), onsetTicks: 0, staffID: lowerStaff),
                ],
                clefsByStaff: [upperStaff: Clef(kind: .treble), lowerStaff: Clef(kind: .bass)],
                effectiveClefsByStaff: [upperStaff: Clef(kind: .treble), lowerStaff: Clef(kind: .bass)],
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let firstMeasureLayouts = layout.measures.filter { $0.measureIndex == 0 }
    let staffIDs = Set(layout.staves.filter { $0.systemIndex == 0 }.map(\.staffID))
    let p1Treble = try #require(layout.noteLayout(for: NoteID(rawValue: "p1-treble")))
    let p2Treble = try #require(layout.noteLayout(for: NoteID(rawValue: "p2-treble")))

    #expect(firstMeasureLayouts.count == 1)
    #expect(staffIDs == [
        StaffID(rawValue: "1"),
        StaffID(rawValue: "2"),
        StaffID(rawValue: "3"),
        StaffID(rawValue: "4"),
    ])
    #expect(p1Treble.staffID == StaffID(rawValue: "1"))
    #expect(p2Treble.staffID == StaffID(rawValue: "3"))
    #expect(abs(p1Treble.noteheadCenter.x - p2Treble.noteheadCenter.x) < 0.001)
    #expect(p2Treble.noteheadCenter.y > p1Treble.noteheadCenter.y)
}

@Test func a4PrintLayoutRepeatsClefsKeySignatureAndLeftBarlineAtSystemStarts() throws {
    let staff1 = StaffID(rawValue: "1")
    let staff2 = StaffID(rawValue: "2")
    let measures = (0..<5).map { index in
        Measure(
            id: MeasureID(partIndex: 0, measureNumber: "\(index + 1)"),
            number: "\(index + 1)",
            notes: [
                makeNote(id: "repeat-prefix-\(index)-treble", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0, staffID: staff1),
                makeNote(id: "repeat-prefix-\(index)-bass", pitch: Pitch(step: .c, octave: 3), onsetTicks: 0, staffID: staff2),
            ],
            clefsByStaff: index == 0 ? [
                staff1: Clef(kind: .treble),
                staff2: Clef(kind: .bass),
            ] : [:],
            keySignature: index == 0 ? KeySignature(fifths: 1, mode: "major") : nil,
            timeSignature: index == 0 ? TimeSignature(beats: 4, beatType: 4) : nil
        )
    }
    let score = ScoreDocument(parts: [ScorePart(id: "p1", measures: measures)])

    let layout = try ScoreLayoutEngine().layout(score: score, options: a4PrintOptions())
    let repeatedMeasureID = MeasureID(partIndex: 0, measureNumber: "5")
    let repeatedMeasure = try #require(layout.measures.first { $0.measureID == repeatedMeasureID })

    #expect(repeatedMeasure.systemIndex > 0)
    #expect(layout.elements.contains {
        $0.measureID == repeatedMeasureID && $0.kind == .clef && $0.staffID == staff1 && $0.clef?.kind == .treble
    })
    #expect(layout.elements.contains {
        $0.measureID == repeatedMeasureID && $0.kind == .clef && $0.staffID == staff2 && $0.clef?.kind == .bass
    })
    #expect(layout.elements.contains {
        $0.measureID == repeatedMeasureID && $0.kind == .keySignature && $0.staffID == staff1 && $0.keySignature?.fifths == 1
    })
    #expect(layout.elements.contains {
        $0.measureID == repeatedMeasureID && $0.kind == .keySignature && $0.staffID == staff2 && $0.keySignature?.fifths == 1
    })
    #expect(layout.elements.contains {
        $0.id.rawValue == "\(repeatedMeasureID.rawValue).barline.left"
            && abs($0.frame.midX - repeatedMeasure.frame.minX) < 0.001
    })
}

@Test func unsupportedDisplayModeThrowsWhenPolicyIsFail() throws {
    let score = makeScore(notes: [])
    let options = LayoutOptions(displayMode: .verticalPractice, unsupportedFeaturePolicy: .fail)

    do {
        _ = try ScoreLayoutEngine().layout(score: score, options: options)
        Issue.record("Expected unsupported display mode to fail")
    } catch LayoutError.unsupportedDisplayMode(let mode) {
        #expect(mode == .verticalPractice)
    }
}

private func a4PrintOptions() -> LayoutOptions {
    LayoutOptions(
        pageWidth: 595,
        pageHeight: 842,
        staffSpace: 8,
        systemSpacing: 48,
        measureSpacing: 0,
        displayMode: .print,
        showPageMargins: true
    )
}

private func primaryBeamY(_ beam: BeamLayout, at x: CGFloat) -> CGFloat {
    let start = beam.primary.start
    let end = beam.primary.end
    guard abs(end.x - start.x) > 0.001 else {
        return start.y
    }
    let t = (x - start.x) / (end.x - start.x)
    return start.y + (end.y - start.y) * t
}

private func stemTipY(stem: ElementLayout, note: NoteLayout) -> CGFloat {
    let drawsDown = stem.frame.midY > note.noteheadCenter.y
    return drawsDown ? stem.frame.maxY : stem.frame.minY
}

private func stemLength(stem: ElementLayout, note: NoteLayout) -> CGFloat {
    let drawsDown = stem.frame.midY > note.noteheadCenter.y
    let noteSideY = drawsDown ? stem.frame.minY : stem.frame.maxY
    let tipY = stemTipY(stem: stem, note: note)
    return drawsDown ? tipY - noteSideY : noteSideY - tipY
}

private func renderedContentFrame(forSystemIndex systemIndex: Int, in layout: ScoreLayout) -> CGRect? {
    let systemMeasureIDs = Set(layout.measures.filter { $0.systemIndex == systemIndex }.map(\.measureID))
    guard !systemMeasureIDs.isEmpty else { return nil }

    var frame = CGRect.null
    func include(_ candidate: CGRect) {
        guard !candidate.isNull,
              !candidate.isEmpty,
              candidate.minY.isFinite,
              candidate.maxY.isFinite else { return }
        frame = frame.union(candidate)
    }

    for staff in layout.staves where staff.systemIndex == systemIndex {
        include(staff.frame)
    }
    for staffLine in layout.staffLines where systemMeasureIDs.contains(staffLine.measureID) {
        include(staffLine.frame)
    }
    for element in layout.elements where element.measureID.map(systemMeasureIDs.contains) ?? false {
        include(element.frame)
    }
    for ledgerLine in layout.ledgerLines {
        let belongsToSystem = ledgerLine.measureID.map(systemMeasureIDs.contains)
            ?? ledgerLine.noteID.flatMap { layout.noteByID[$0]?.measureID }.map(systemMeasureIDs.contains)
            ?? false
        if belongsToSystem {
            include(ledgerLine.frame)
        }
    }
    for note in layout.noteByID.values where note.measureID.map(systemMeasureIDs.contains) ?? false {
        include(note.noteheadFrame)
    }

    return frame.isNull || frame.isEmpty ? nil : frame
}

private func makeScore(
    notes: [ScoreNote],
    clef: Clef = Clef(kind: .treble),
    measureID: MeasureID = MeasureID(partIndex: 0, measureNumber: "1")
) -> ScoreDocument {
    ScoreDocument(parts: [
        ScorePart(id: "p1", measures: [
            Measure(id: measureID, number: "1", notes: notes, clef: clef),
        ]),
    ])
}

private func makeNote(
    id: String,
    pitch: Pitch?,
    onsetTicks: Int,
    durationTicks: Int = 4,
    noteValueKind: NoteValueKind = .quarter,
    dotCount: Int = 0,
    accidental: String? = nil,
    ties: [MusicXMLTieKind] = [],
    slurs: [MusicXMLSlurKind] = [],
    beams: [MusicXMLBeam] = [],
    tuplet: TupletInfo? = nil,
    staffID: StaffID = StaffID(rawValue: "1"),
    isChordTone: Bool = false,
    chordOrdinal: Int = 0
) -> ScoreNote {
    ScoreNote(
        id: NoteID(rawValue: id),
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: durationTicks, ticksPerQuarterNote: 4),
        noteValueKind: noteValueKind,
        dotCount: dotCount,
        voiceID: VoiceID(rawValue: "1"),
        staffID: staffID,
        isChordTone: isChordTone,
        chordOrdinal: chordOrdinal,
        accidental: accidental,
        ties: ties,
        slurs: slurs,
        beams: beams,
        hasTimeModification: tuplet != nil,
        hasTupletNotation: tuplet?.kind != nil,
        tuplet: tuplet
    )
}
