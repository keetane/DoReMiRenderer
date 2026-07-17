import Foundation
import Testing
@testable import DoReMiRendererKit

@Test func webRenderPlanPreservesSDKLayoutCoordinatesAndStableNoteIDs() throws {
    let measureID = MeasureID(partIndex: 0, measureNumber: "1")
    let staffID = StaffID(rawValue: "1")
    let noteID = NoteID(rawValue: "web-note")
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
                        duration: MusicalTime(ticks: 4, ticksPerQuarterNote: 4),
                        noteValueKind: .quarter,
                        voiceID: VoiceID(rawValue: "1"),
                        staffID: staffID
                    ),
                ],
                clef: Clef(kind: .treble),
                timeSignature: TimeSignature(beats: 4, beatType: 4)
            ),
        ]),
    ])
    let renderer = DoReMiRenderer()
    let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: 960))
    let plan = renderer.makeWebRenderPlan(score: score, layout: layout)

    #expect(plan.formatVersion == ScoreWebRenderPlan.formatVersion)
    #expect(plan.canvas.width == Double(layout.canvasSize.width))
    #expect(plan.canvas.height == Double(layout.canvasSize.height))
    #expect(plan.commands.contains { $0.kind == .strokeLine })
    #expect(plan.commands.contains { $0.kind == .drawText && $0.fontName == "Bravura" })
    #expect(plan.commands.contains { $0.kind == .drawText && $0.fontRole == .smufl })
    #expect(ScoreWebFontRole(fontName: "TimesNewRomanPS-BoldMT") == .serifBold)
    #expect(ScoreWebFontRole(fontName: "Georgia-Italic") == .serifItalic)
    #expect(ScoreWebFontRole(fontName: nil) == .sansSerif)
    let anchor = try #require(plan.noteAnchors.first { $0.noteID == noteID })
    let expectedNote = try #require(layout.noteLayout(for: noteID))
    #expect(anchor.center.x == Double(expectedNote.noteheadCenter.x))
    #expect(anchor.center.y == Double(expectedNote.noteheadCenter.y))

    let encoded = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(ScoreWebRenderPlan.self, from: encoded)
    #expect(decoded == plan)
}

@Test func responsiveWebLayoutProfileClampsSmallContainersAndCapsMeasuresPerSystem() {
    let profile = ScoreWebLayoutProfile(
        staffSpace: 8,
        systemSpacing: 52,
        measureSpacing: 12,
        maximumMeasuresPerSystem: 4
    )
    let options = profile.layoutOptions(containerWidth: 240)

    #expect(options.pageWidth == 320)
    #expect(options.staffSpace == 8)
    #expect(options.systemSpacing == 52)
    #expect(options.measureSpacing == 12)
    #expect(options.maximumMeasuresPerSystem == 4)
    #expect(options.displayMode == .print)
    #expect(!options.showPageMargins)
}
