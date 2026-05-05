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
    staffID: StaffID = StaffID(rawValue: "1"),
    isChordTone: Bool = false,
    chordOrdinal: Int = 0
) -> ScoreNote {
    ScoreNote(
        id: NoteID(rawValue: id),
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: staffID,
        isChordTone: isChordTone,
        chordOrdinal: chordOrdinal
    )
}
