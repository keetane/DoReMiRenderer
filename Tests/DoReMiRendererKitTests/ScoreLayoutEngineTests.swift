import CoreGraphics
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
                ]
            ),
        ]),
    ])

    let layout = try ScoreLayoutEngine().layout(score: score)

    #expect(layout.elements.contains { $0.kind == ScoreElementKind.clef && $0.clef?.kind == .treble })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.timeSignature && $0.timeSignature == TimeSignature(beats: 4, beatType: 4) })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.keySignature && $0.keySignature?.fifths == 1 })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.barline && $0.repeatBarline?.direction == .forward })
    #expect(layout.elements.contains { $0.kind == ScoreElementKind.barline && $0.repeatBarline?.direction == .backward })
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
    let options = LayoutOptions(displayMode: .horizontal, unsupportedFeaturePolicy: .ignoreWithWarning)

    let result = try ScoreLayoutEngine().layoutWithDiagnostics(score: score, options: options)

    #expect(!result.layout.noteByID.isEmpty)
    #expect(result.diagnostics.contains { $0.severity == .warning && $0.code == "unsupported.displayMode" })
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
        chordOrdinal: chordOrdinal
    )
}
