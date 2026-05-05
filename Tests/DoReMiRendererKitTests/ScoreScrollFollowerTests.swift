import CoreGraphics
import Testing
@testable import DoReMiRendererKit

@Test func scrollFollowerReturnsNilForMissingNoteID() {
    let follower = ScoreScrollFollower()
    let layout = scrollLayout(noteID: NoteID(rawValue: "known"))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    #expect(follower.target(for: NoteID(rawValue: "missing"), in: layout, transform: transform) == nil)
}

@Test func scrollFollowerReturnsTargetForExistingOffscreenNoteID() throws {
    let noteID = NoteID(rawValue: "target")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 900, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = try #require(ScoreScrollFollower().target(for: noteID, in: layout, transform: transform))

    #expect(target.noteID == noteID)
    #expect(target.layoutFrame == CGRect(x: 100, y: 900, width: 20, height: 16))
}

@Test func scrollFollowerClampsNegativeOffsetToZero() throws {
    let noteID = NoteID(rawValue: "top")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: -40, y: -20, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = try #require(ScoreScrollFollower(margin: 0).target(for: noteID, in: layout, transform: transform))

    #expect(target.targetContentOffset.x == 0)
    #expect(target.targetContentOffset.y == 0)
}

@Test func scrollFollowerClampsOffsetToContentBounds() throws {
    let noteID = NoteID(rawValue: "bottom")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 950, y: 1950, width: 40, height: 40))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = try #require(ScoreScrollFollower(margin: 0).target(for: noteID, in: layout, transform: transform))

    #expect(target.targetContentOffset.x == 700)
    #expect(target.targetContentOffset.y == 1800)
}

@Test func scrollFollowerUsesScaleOneCenteredOffset() throws {
    let noteID = NoteID(rawValue: "scale1")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 900, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = try #require(ScoreScrollFollower(margin: 0).target(for: noteID, in: layout, transform: transform))

    #expect(target.targetContentOffset == CGPoint(x: 0, y: 808))
}

@Test func scrollFollowerUsesScaleTwoCenteredOffset() throws {
    let noteID = NoteID(rawValue: "scale2")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 900, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 2,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = try #require(ScoreScrollFollower(margin: 0).target(for: noteID, in: layout, transform: transform))

    #expect(target.targetContentOffset == CGPoint(x: 70, y: 1716))
}

@Test func scrollFollowerReturnsNilWhenNoteIsInsideViewportMargin() {
    let noteID = NoteID(rawValue: "visible")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 80, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )

    let target = ScoreScrollFollower(margin: 20).target(for: noteID, in: layout, transform: transform)

    #expect(target == nil)
}

@Test func scrollFollowerTargetsPlaybackNextNote() throws {
    let renderer = DoReMiRenderer()
    let firstID = NoteID(rawValue: "first")
    let secondID = NoteID(rawValue: "second")
    let score = scrollScore(notes: [
        scrollNote(id: firstID, pitch: Pitch(step: .c, octave: 4), onsetTicks: 0),
        scrollNote(id: secondID, pitch: Pitch(step: .e, octave: 4), onsetTicks: 4),
    ])
    let events = renderer.makePlaybackSequence(score: score)
    let layout = try renderer.layout(score: score, options: LayoutOptions(pageWidth: 980, staffSpace: 16))
    let nextNoteID = try #require(events.dropFirst().first?.noteIDs.first)
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 40, height: 40),
        contentSize: layout.canvasSize
    )

    let target = ScoreScrollFollower(margin: 0).target(for: nextNoteID, in: layout, transform: transform)

    #expect(nextNoteID == secondID)
    #expect(target?.noteID == secondID)
}

@Test func scrollFollowerTargetsTappedNearestNoteID() throws {
    let noteID = NoteID(rawValue: "tap")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 900, width: 20, height: 16))
    let result = layout.hitTest(point: CGPoint(x: 110, y: 908), radius: 12)
    let nearestNoteID = try #require(result.nearestNoteID)
    let transform = ScoreViewportTransform(
        scale: 1,
        viewportSize: CGSize(width: 80, height: 80),
        contentSize: layout.canvasSize
    )

    let target = ScoreScrollFollower(margin: 0).target(for: nearestNoteID, in: layout, transform: transform)

    #expect(target?.noteID == noteID)
}

@Test func scrollFollowerTargetsZoomedTappedNearestNoteID() throws {
    let noteID = NoteID(rawValue: "zoomTap")
    let layout = scrollLayout(noteID: noteID, noteheadFrame: CGRect(x: 100, y: 900, width: 20, height: 16))
    let transform = ScoreViewportTransform(
        scale: 2,
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: layout.canvasSize
    )
    let viewPoint = transform.viewPoint(fromLayoutPoint: CGPoint(x: 110, y: 908))
    let layoutPoint = transform.layoutPoint(fromViewPoint: viewPoint)
    let result = layout.hitTest(point: layoutPoint, radius: 18 / transform.scale)
    let nearestNoteID = try #require(result.nearestNoteID)

    let target = try #require(ScoreScrollFollower(margin: 0).target(for: nearestNoteID, in: layout, transform: transform))

    #expect(target.noteID == noteID)
    #expect(target.targetContentOffset == CGPoint(x: 70, y: 1716))
}

private func scrollLayout(
    noteID: NoteID,
    noteheadFrame: CGRect = CGRect(x: 100, y: 900, width: 20, height: 16)
) -> ScoreLayout {
    let noteLayout = NoteLayout(
        noteID: noteID,
        measureID: MeasureID(partIndex: 0, measureNumber: "1"),
        staffID: StaffID(rawValue: "1"),
        voiceID: VoiceID(rawValue: "1"),
        pitch: Pitch(step: .c, octave: 4),
        noteheadElementID: ScoreElementID(rawValue: "\(noteID.rawValue).notehead"),
        noteheadCenter: CGPoint(x: noteheadFrame.midX, y: noteheadFrame.midY),
        noteheadFrame: noteheadFrame
    )
    let element = ElementLayout(
        id: ScoreElementID(rawValue: "\(noteID.rawValue).notehead"),
        kind: .notehead,
        noteID: noteID,
        frame: noteheadFrame,
        noteLayout: noteLayout
    )
    return ScoreLayout(
        canvasSize: CGSize(width: 1_000, height: 2_000),
        elements: [element],
        noteByID: [noteID: noteLayout],
        elementByID: [element.id: element]
    )
}

private func scrollScore(notes: [ScoreNote]) -> ScoreDocument {
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

private func scrollNote(id: NoteID, pitch: Pitch?, onsetTicks: Int) -> ScoreNote {
    ScoreNote(
        id: id,
        pitch: pitch,
        onset: MusicalTime(ticks: onsetTicks, ticksPerQuarterNote: 4),
        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
        voiceID: VoiceID(rawValue: "1"),
        staffID: StaffID(rawValue: "1")
    )
}
