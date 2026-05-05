import CoreGraphics
import Testing
@testable import DoReMiRendererKit

@Test func viewportTransformIdentityMapsViewPointToLayoutPoint() {
    let transform = ScoreViewportTransform(scale: 1, contentOffset: .zero)

    #expect(transform.layoutPoint(fromViewPoint: CGPoint(x: 200, y: 100)) == CGPoint(x: 200, y: 100))
    #expect(transform.viewPoint(fromLayoutPoint: CGPoint(x: 200, y: 100)) == CGPoint(x: 200, y: 100))
}

@Test func viewportTransformScaleMapsViewPointToLayoutPoint() {
    let transform = ScoreViewportTransform(scale: 2, contentOffset: .zero)

    #expect(transform.layoutPoint(fromViewPoint: CGPoint(x: 200, y: 100)) == CGPoint(x: 100, y: 50))
}

@Test func viewportTransformScaleAndOffsetMapViewPointToLayoutPoint() {
    let transform = ScoreViewportTransform(scale: 2, contentOffset: CGPoint(x: 40, y: 20))

    #expect(transform.layoutPoint(fromViewPoint: CGPoint(x: 200, y: 100)) == CGPoint(x: 120, y: 60))
}

@Test func viewportTransformRoundTripsWithinTolerance() {
    let transform = ScoreViewportTransform(
        scale: 1.5,
        contentOffset: CGPoint(x: 31, y: 17),
        viewportSize: CGSize(width: 320, height: 240),
        contentSize: CGSize(width: 900, height: 400)
    )
    let layoutPoint = CGPoint(x: 123.5, y: 77.25)
    let roundTrip = transform.layoutPoint(fromViewPoint: transform.viewPoint(fromLayoutPoint: layoutPoint))

    #expect(abs(roundTrip.x - layoutPoint.x) < 0.0001)
    #expect(abs(roundTrip.y - layoutPoint.y) < 0.0001)
}

@Test func viewportTransformClampsNonPositiveScale() {
    let zero = ScoreViewportTransform(scale: 0)
    let negative = ScoreViewportTransform(scale: -2)

    #expect(zero.scale == ScoreViewportTransform.minimumScale)
    #expect(negative.scale == ScoreViewportTransform.minimumScale)
}

@Test func zoomedViewPointHitTestsNotehead() throws {
    let noteID = NoteID(rawValue: "zoomed")
    let layout = try ScoreLayoutEngine().layout(score: transformScore(notes: [
        transformNote(id: noteID.rawValue, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
    ]))
    let noteLayout = try #require(layout.noteLayout(for: noteID))
    let transform = ScoreViewportTransform(scale: 2, contentSize: layout.canvasSize)
    let viewPoint = transform.viewPoint(fromLayoutPoint: noteLayout.noteheadCenter)

    let result = layout.hitTest(point: transform.layoutPoint(fromViewPoint: viewPoint), radius: 18 / transform.scale)

    #expect(result.nearestNoteID == noteID)
}

@Test func offsetViewPointHitTestsNotehead() throws {
    let noteID = NoteID(rawValue: "scrolled")
    let layout = try ScoreLayoutEngine().layout(score: transformScore(notes: [
        transformNote(id: noteID.rawValue, pitch: Pitch(step: .e, octave: 4), onsetTicks: 0),
    ]))
    let noteLayout = try #require(layout.noteLayout(for: noteID))
    let transform = ScoreViewportTransform(
        scale: 2,
        contentOffset: CGPoint(x: 80, y: 40),
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )
    let viewPoint = transform.viewPoint(fromLayoutPoint: noteLayout.noteheadCenter)

    let result = layout.hitTest(point: transform.layoutPoint(fromViewPoint: viewPoint), radius: 18 / transform.scale)

    #expect(result.nearestNoteID == noteID)
}

private func transformScore(notes: [ScoreNote]) -> ScoreDocument {
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

private func transformNote(id: String, pitch: Pitch?, onsetTicks: Int) -> ScoreNote {
    ScoreNote(
        id: NoteID(rawValue: id),
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: StaffID(rawValue: "1")
    )
}

