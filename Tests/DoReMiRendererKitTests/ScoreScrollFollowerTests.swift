import CoreGraphics
import SwiftUI
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

@Test func scoreCanvasFollowHeuristicsResumeAfterNilAndScrollFarNotes() {
    let noteFrame = CGRect(x: 100, y: 900, width: 20, height: 16)
    let noteCenter = CGPoint(x: 110, y: 908)
    let viewport = CGSize(width: 300, height: 200)

    #expect(ScoreCanvasFollowHeuristics.shouldScroll(
        noteFrame: noteFrame,
        noteCenter: noteCenter,
        lastFollowCenter: nil,
        viewportSize: viewport,
        margin: 48
    ))

    #expect(ScoreCanvasFollowHeuristics.shouldScroll(
        noteFrame: CGRect(x: 310, y: 900, width: 20, height: 16),
        noteCenter: CGPoint(x: 320, y: 908),
        lastFollowCenter: noteCenter,
        viewportSize: viewport,
        margin: 48
    ))
}

@Test func scoreCanvasFollowHeuristicsDoesNotScrollNearbyVisibleNotes() {
    let lastCenter = CGPoint(x: 110, y: 908)

    #expect(!ScoreCanvasFollowHeuristics.shouldScroll(
        noteFrame: CGRect(x: 132, y: 912, width: 20, height: 16),
        noteCenter: CGPoint(x: 142, y: 920),
        lastFollowCenter: lastCenter,
        viewportSize: CGSize(width: 300, height: 200),
        margin: 24
    ))
}

@Test func scoreCanvasFollowHeuristicsUsesMeasuredViewportFrameVisibility() {
    let viewport = CGSize(width: 300, height: 200)

    #expect(ScoreCanvasFollowHeuristics.isFrameVisible(
        CGRect(x: 80, y: 60, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ))
    #expect(!ScoreCanvasFollowHeuristics.isFrameVisible(
        CGRect(x: 4, y: 60, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ))
    #expect(!ScoreCanvasFollowHeuristics.isFrameVisible(
        CGRect(x: 80, y: 185, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ))
}

@Test func scoreCanvasFollowHeuristicsChoosesEdgeAnchorsFromMeasuredBounds() {
    let viewport = CGSize(width: 300, height: 200)

    #expect(ScoreCanvasFollowHeuristics.scrollAnchor(
        for: CGRect(x: 90, y: 190, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ) == UnitPoint(x: 0.5, y: 1))

    #expect(ScoreCanvasFollowHeuristics.scrollAnchor(
        for: CGRect(x: 2, y: 80, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ) == UnitPoint(x: 0, y: 0.5))

    #expect(ScoreCanvasFollowHeuristics.scrollAnchor(
        for: CGRect(x: 120, y: 2, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ) == UnitPoint(x: 0.5, y: 0))

    #expect(ScoreCanvasFollowHeuristics.scrollAnchor(
        for: CGRect(x: 120, y: 80, width: 20, height: 16),
        viewportSize: viewport,
        margin: 24
    ) == .center)
}

@Test func scoreCanvasFollowHeuristicsKeepsEvaluatingAfterInitialFollow() {
    let viewport = CGSize(width: 300, height: 200)
    let firstVisibleFrame = CGRect(x: 120, y: 90, width: 20, height: 16)
    let laterOffscreenFrame = CGRect(x: 120, y: 220, width: 20, height: 16)

    #expect(ScoreCanvasFollowHeuristics.isFrameVisible(
        firstVisibleFrame,
        viewportSize: viewport,
        margin: 24
    ))
    #expect(!ScoreCanvasFollowHeuristics.isFrameVisible(
        laterOffscreenFrame,
        viewportSize: viewport,
        margin: 24
    ))
    #expect(ScoreCanvasFollowHeuristics.scrollAnchor(
        for: laterOffscreenFrame,
        viewportSize: viewport,
        margin: 24
    ) == UnitPoint(x: 0.5, y: 1))
}

@Test func scoreCanvasFollowHeuristicsFollowsFarCurrentNotesAfterInitialFollow() {
    let viewport = CGSize(width: 700, height: 520)
    let initialCenter = CGPoint(x: 180, y: 260)
    let nearbyCenter = CGPoint(x: 260, y: 264)
    let laterSystemCenter = CGPoint(x: 760, y: 264)

    #expect(!ScoreCanvasFollowHeuristics.hasMovedBeyondFollowDistance(
        noteCenter: nearbyCenter,
        lastFollowCenter: initialCenter,
        viewportSize: viewport,
        scale: 1,
        margin: 48
    ))
    #expect(ScoreCanvasFollowHeuristics.hasMovedBeyondFollowDistance(
        noteCenter: laterSystemCenter,
        lastFollowCenter: initialCenter,
        viewportSize: viewport,
        scale: 1,
        margin: 48
    ))
    #expect(ScoreCanvasFollowHeuristics.scrollAnchorForLayoutMovement(
        noteCenter: laterSystemCenter,
        lastFollowCenter: initialCenter
    ).x > 0.5)
}

@Test func scoreCanvasFollowHeuristicsUsesScaleForFollowDistance() {
    let viewport = CGSize(width: 700, height: 520)
    let initialCenter = CGPoint(x: 180, y: 260)
    let zoomedFarCenter = CGPoint(x: 390, y: 260)

    #expect(!ScoreCanvasFollowHeuristics.hasMovedBeyondFollowDistance(
        noteCenter: zoomedFarCenter,
        lastFollowCenter: initialCenter,
        viewportSize: viewport,
        scale: 1,
        margin: 48
    ))
    #expect(ScoreCanvasFollowHeuristics.hasMovedBeyondFollowDistance(
        noteCenter: zoomedFarCenter,
        lastFollowCenter: initialCenter,
        viewportSize: viewport,
        scale: 2,
        margin: 48
    ))
}

@Test func scoreCanvasFollowHeuristicsUsesMeasureLeadingXForFollowAnchor() {
    let noteID = NoteID(rawValue: "measure.note")
    let layout = scrollLayout(
        noteID: noteID,
        noteheadFrame: CGRect(x: 340, y: 900, width: 20, height: 16),
        measureFrame: CGRect(x: 280, y: 80, width: 180, height: 160)
    )
    let noteLayout = layout.noteByID[noteID]!

    #expect(ScoreCanvasFollowHeuristics.measureLeadingX(for: noteLayout, in: layout) == 280)
}

@Test func scoreCanvasFollowHeuristicsUsesSystemTopForTopAlignedMeasureAnchor() {
    let noteID = NoteID(rawValue: "measure.top")
    let layout = scrollLayout(
        noteID: noteID,
        noteheadFrame: CGRect(x: 340, y: 900, width: 20, height: 16),
        measureFrame: CGRect(x: 280, y: 820, width: 180, height: 160),
        systemFrame: CGRect(x: 240, y: 760, width: 520, height: 260)
    )
    let measure = layout.measures[0]

    #expect(ScoreCanvasFollowHeuristics.measureTopY(for: measure, in: layout) == 760)
}

@Test func scoreCanvasFollowHeuristicsFallsBackToNoteXWithoutMeasureLayout() {
    let noteID = NoteID(rawValue: "orphan.note")
    let layout = scrollLayout(
        noteID: noteID,
        noteheadFrame: CGRect(x: 340, y: 900, width: 20, height: 16),
        measureFrame: nil
    )
    let noteLayout = layout.noteByID[noteID]!

    #expect(ScoreCanvasFollowHeuristics.measureLeadingX(for: noteLayout, in: layout) == 340)
}

@Test func scoreCanvasFollowHeuristicsTopAlignedPlacementKeepsFollowNearViewportTop() {
    let measuredAnchor = UnitPoint(x: 0.5, y: 1)
    let movementAnchor = UnitPoint(x: 0.5, y: 0.68)

    let resolved = ScoreCanvasFollowHeuristics.resolvedScrollAnchor(
        measuredAnchor: measuredAnchor,
        movementAnchor: movementAnchor,
        movedBeyondLastFollow: true,
        placement: .topAligned
    )

    #expect(resolved == UnitPoint(x: 0.5, y: 0.12))
}

@Test func scoreCanvasFollowHeuristicsCenterPlacementKeepsExistingMeasuredAnchor() {
    let measuredAnchor = UnitPoint(x: 0.5, y: 1)
    let movementAnchor = UnitPoint(x: 0.5, y: 0.68)

    let resolved = ScoreCanvasFollowHeuristics.resolvedScrollAnchor(
        measuredAnchor: measuredAnchor,
        movementAnchor: movementAnchor,
        movedBeyondLastFollow: true,
        placement: .center
    )

    #expect(resolved == measuredAnchor)
}

@Test func scoreCanvasScrollableContentSizeKeepsPositiveScrollExtentWithInset() {
    let canvasSize = CGSize(width: 500, height: 900)
    let viewportSize = CGSize(width: 300, height: 260)

    let scaleOneSize = ScoreCanvasFollowHeuristics.scrollableContentSize(
        canvasSize: canvasSize,
        scale: 1.0,
        margin: 48
    )
    let scaleTwoSize = ScoreCanvasFollowHeuristics.scrollableContentSize(
        canvasSize: canvasSize,
        scale: 2.0,
        margin: 48
    )

    #expect(scaleOneSize.width > viewportSize.width)
    #expect(scaleOneSize.height > viewportSize.height)
    #expect(scaleTwoSize.width > scaleOneSize.width)
    #expect(scaleTwoSize.height > scaleOneSize.height)
    #expect(scaleOneSize.width > canvasSize.width)
    #expect(scaleOneSize.height > canvasSize.height)
}

@Test func scoreCanvasFollowHeuristicsUsesScaledViewportCoordinates() {
    let lastCenter = CGPoint(x: 110, y: 908)

    #expect(ScoreCanvasFollowHeuristics.shouldScroll(
        noteFrame: CGRect(x: 210, y: 908, width: 20, height: 16),
        noteCenter: CGPoint(x: 220, y: 916),
        lastFollowCenter: lastCenter,
        viewportSize: CGSize(width: 150, height: 100),
        margin: 24
    ))
}

private func scrollLayout(
    noteID: NoteID,
    noteheadFrame: CGRect = CGRect(x: 100, y: 900, width: 20, height: 16),
    measureFrame: CGRect? = CGRect(x: 80, y: 80, width: 200, height: 160),
    systemFrame: CGRect? = nil
) -> ScoreLayout {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let noteLayout = NoteLayout(
        noteID: noteID,
        measureID: measureID,
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
        systems: systemFrame.map { [SystemLayout(index: 0, frame: $0)] } ?? [],
        measures: measureFrame.map {
            [MeasureLayout(measureID: measureID, systemIndex: 0, frame: $0)]
        } ?? [],
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
