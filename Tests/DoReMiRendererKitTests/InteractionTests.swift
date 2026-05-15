import CoreGraphics
import Testing
@testable import DoReMiRendererKit

@Test func noteheadCenterHitTestReturnsTargetNoteID() throws {
    let noteID = NoteID(rawValue: "n0")
    let layout = try ScoreLayoutEngine().layout(score: interactionScore(notes: [
        interactionNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ]))
    let noteLayout = try #require(layout.noteLayout(for: noteID))

    let result = layout.hitTest(point: noteLayout.noteheadCenter, radius: 8)

    #expect(result.elements.first?.kind == .notehead)
    #expect(result.elements.first?.noteID == noteID)
    #expect(result.nearestNoteID == noteID)
}

@Test func accidentalHitTestCanResolveNearestNoteID() throws {
    let noteID = NoteID(rawValue: "sharp")
    let layout = try ScoreLayoutEngine().layout(score: interactionScore(notes: [
        interactionNote(id: noteID.rawValue, pitch: Pitch(step: .f, octave: 4, alter: 1), onsetTicks: 0, accidental: "sharp"),
    ]))
    let accidental = try #require(layout.elements.first { $0.kind == .accidental && $0.noteID == noteID })

    let result = layout.hitTest(point: accidental.frame.center, radius: 4)

    #expect(result.elements.contains { $0.kind == .accidental && $0.noteID == noteID })
    #expect(result.nearestNoteID == noteID)
}

@Test func staffLineHitTestReturnsStaffLineElement() throws {
    let layout = try ScoreLayoutEngine().layout(score: interactionScore(notes: []))
    let staffLine = try #require(layout.staffLines.first)

    let result = layout.hitTest(point: staffLine.frame.center, radius: 2)

    #expect(result.elements.first?.kind == .staffLine)
    #expect(result.elements.first?.id == staffLine.id)
    #expect(result.nearestNoteID == nil)
}

@Test func blankHitTestReturnsNoElementsAndNoNearestNote() throws {
    let layout = try ScoreLayoutEngine().layout(score: interactionScore(notes: [
        interactionNote(id: "n0", pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ]))

    let result = layout.hitTest(point: CGPoint(x: -100, y: -100), radius: 8)

    #expect(result.elements.isEmpty)
    #expect(result.nearestNoteID == nil)
}

@Test func nearestNoteIDChoosesClosestNoteheadInsideRadius() {
    let firstID = NoteID(rawValue: "first")
    let secondID = NoteID(rawValue: "second")
    let first = NoteLayout(
        noteID: firstID,
        pitch: Pitch(step: .c, octave: 4),
        noteheadElementID: ScoreElementID(rawValue: "first.notehead"),
        noteheadCenter: CGPoint(x: 100, y: 100),
        noteheadFrame: CGRect(x: 94, y: 95, width: 12, height: 10)
    )
    let second = NoteLayout(
        noteID: secondID,
        pitch: Pitch(step: .d, octave: 4),
        noteheadElementID: ScoreElementID(rawValue: "second.notehead"),
        noteheadCenter: CGPoint(x: 110, y: 100),
        noteheadFrame: CGRect(x: 104, y: 95, width: 12, height: 10)
    )
    let elements = [
        ElementLayout(id: ScoreElementID(rawValue: "first.notehead"), kind: .notehead, noteID: firstID, frame: first.noteheadFrame, noteLayout: first),
        ElementLayout(id: ScoreElementID(rawValue: "second.notehead"), kind: .notehead, noteID: secondID, frame: second.noteheadFrame, noteLayout: second),
    ]
    let layout = ScoreLayout(
        elements: elements,
        noteByID: [firstID: first, secondID: second],
        elementByID: Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
    )

    let result = layout.hitTest(point: CGPoint(x: 108, y: 100), radius: 12)

    #expect(result.nearestNoteID == secondID)
}

private func interactionScore(notes: [ScoreNote]) -> ScoreDocument {
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

private func interactionNote(
    id: String,
    pitch: Pitch?,
    onsetTicks: Int,
    accidental: String? = nil
) -> ScoreNote {
    ScoreNote(
        id: NoteID(rawValue: id),
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: StaffID(rawValue: "1"),
        accidental: accidental
    )
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
