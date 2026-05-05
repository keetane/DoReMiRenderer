import CoreGraphics
import Testing
@testable import DoReMiRendererKit

@Test func scorePainterConsumesLayoutElementsWithoutMutatingLayout() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let noteIDs = Set(layout.noteByID.keys)
    let elementIDs = Set(layout.elementByID.keys)
    var context = RecordingDrawingContext()

    ScorePainter().draw(
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

@Test func scorePainterUsesResolvedNoteAndStaffColors() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    var context = RecordingDrawingContext()

    ScorePainter().draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(context.commands.contains { $0.kind == .fillEllipse && $0.color == defaultEducationalPalette.c })
    #expect(context.commands.contains { $0.kind == .strokeLine && $0.color == defaultEducationalPalette.e })
}

@Test func scorePainterDrawsAccidentalsFromLayoutElements() throws {
    let score = renderingScore()
    let layout = try ScoreLayoutEngine().layout(score: score)
    let accidentalElement = try #require(layout.elements.first { $0.kind == .accidental })
    var context = RecordingDrawingContext()

    ScorePainter().draw(layout: layout, score: score, style: renderingStyle(), into: &context)

    #expect(accidentalElement.accidental == "natural")
    #expect(context.commands.contains {
        $0.kind == .drawText
            && $0.text == "n"
            && $0.point == CGPoint(x: accidentalElement.frame.midX, y: accidentalElement.frame.midY)
    })
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
        ScorePainter().draw(layout: layout, score: score, style: style, into: &context)
        #expect(layout.noteByID.count == noteCount)
        #expect(layout.elementByID.count == elementCount)
        #expect(Set(layout.noteByID.keys) == noteIDs)
    }
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
        case drawText
    }

    struct Command {
        let kind: CommandKind
        let color: ScoreColor
        let text: String?
        let point: CGPoint?
    }

    var commands: [Command] = []

    mutating func fill(_ rect: CGRect, color: ScoreColor) {
        commands.append(Command(kind: .fillRect, color: color, text: nil, point: nil))
    }

    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(Command(kind: .strokeLine, color: color, text: nil, point: nil))
    }

    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {
        commands.append(Command(kind: .fillEllipse, color: color, text: nil, point: nil))
    }

    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(Command(kind: .strokeEllipse, color: color, text: nil, point: nil))
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat) {
        commands.append(Command(kind: .drawText, color: color, text: text, point: point))
    }
}
