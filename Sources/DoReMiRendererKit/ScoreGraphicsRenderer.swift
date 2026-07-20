import CoreGraphics

public struct ScoreGraphicsRenderer: Sendable {
    public init() {}

    public func draw(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteIDs: Set<NoteID> = [],
        continuationNoteIDs: Set<NoteID> = [],
        in context: CGContext
    ) {
        var drawingContext = CoreGraphicsScoreDrawingContext(context)
        ScorePainter(notationScale: layout.notationScale).draw(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            currentNoteIDs: currentNoteIDs,
            continuationNoteIDs: continuationNoteIDs,
            into: &drawingContext
        )
    }
}
