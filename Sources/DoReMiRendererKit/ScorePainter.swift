import CoreGraphics
import CoreText
import Foundation

protocol ScoreDrawingContext {
    mutating func fill(_ rect: CGRect, color: ScoreColor)
    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat)
    mutating func fillEllipse(in rect: CGRect, color: ScoreColor)
    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat)
    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat)
}

struct ScorePainter: Sendable {
    init() {}

    func draw<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument = ScoreDocument(parts: []),
        style: ScoreStyle,
        selection: ScoreSelection? = nil,
        currentNoteIDs: Set<NoteID> = [],
        into context: inout Context
    ) {
        var effectiveSelection = selection ?? ScoreSelection()
        if !currentNoteIDs.isEmpty {
            effectiveSelection = ScoreSelection(
                selectedNoteIDs: effectiveSelection.selectedNoteIDs.union(currentNoteIDs),
                selectedElementIDs: effectiveSelection.selectedElementIDs
            )
        }

        context.fill(CGRect(origin: .zero, size: layout.canvasSize), color: style.backgroundColor)
        drawStaffLines(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawLedgerLines(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawNoteHighlights(layout: layout, noteIDs: effectiveSelection.selectedNoteIDs, style: style, into: &context)
        drawKeySignatures(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawNotesAndRests(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawAccidentals(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawTextAnnotations(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
    }

    private func drawStaffLines<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .staffLine {
            guard let staffLine = element.staffLine else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            context.strokeLine(
                from: staffLine.start,
                to: staffLine.end,
                color: resolved.strokeColor ?? style.defaultInkColor,
                lineWidth: CGFloat(resolved.lineWidth ?? 1)
            )
        }
    }

    private func drawLedgerLines<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .ledgerLine {
            guard let ledgerLine = element.ledgerLine else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            context.strokeLine(
                from: ledgerLine.start,
                to: ledgerLine.end,
                color: resolved.strokeColor ?? style.defaultInkColor,
                lineWidth: CGFloat(resolved.lineWidth ?? 1)
            )
        }
    }

    private func drawNoteHighlights<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        noteIDs: Set<NoteID>,
        style: ScoreStyle,
        into context: inout Context
    ) {
        for noteID in noteIDs {
            guard let noteLayout = layout.noteLayout(for: noteID) else {
                continue
            }
            context.fillEllipse(in: noteLayout.noteheadFrame.insetBy(dx: -4, dy: -4), color: style.highlightStyle.color)
        }
    }

    private func drawNotesAndRests<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .notehead || element.kind == .rest {
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            switch element.kind {
            case .notehead:
                drawNotehead(element: element, resolved: resolved, style: style, into: &context)
                drawStem(element: element, style: style, into: &context)
            case .rest:
                drawRest(element: element, resolved: resolved, style: style, into: &context)
            default:
                break
            }
        }
    }

    private func drawNotehead<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        let fillColor = resolved.fillColor ?? style.defaultInkColor
        context.fillEllipse(in: element.frame, color: fillColor)
        if let strokeColor = resolved.strokeColor {
            context.strokeEllipse(in: element.frame, color: strokeColor, lineWidth: CGFloat(resolved.lineWidth ?? 1))
        }
    }

    private func drawStem<Context: ScoreDrawingContext>(
        element: ElementLayout,
        style: ScoreStyle,
        into context: inout Context
    ) {
        guard let noteLayout = element.noteLayout else {
            return
        }
        let frame = noteLayout.noteheadFrame
        let start = CGPoint(x: frame.maxX, y: noteLayout.noteheadCenter.y)
        let end = CGPoint(x: frame.maxX, y: noteLayout.noteheadCenter.y - frame.height * 3.2)
        context.strokeLine(from: start, to: end, color: style.defaultInkColor, lineWidth: max(1, frame.width * 0.08))
    }

    private func drawRest<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
        let frame = element.frame
        let midY = frame.midY
        context.strokeLine(from: CGPoint(x: frame.minX, y: midY), to: CGPoint(x: frame.maxX, y: midY), color: color, lineWidth: max(1, frame.height * 0.18))
        context.strokeLine(from: CGPoint(x: frame.midX, y: frame.minY), to: CGPoint(x: frame.midX, y: frame.maxY), color: color, lineWidth: max(1, frame.width * 0.08))
    }

    private func drawAccidentals<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .accidental {
            guard let accidental = element.accidental else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            context.drawText(
                accidentalSymbol(for: accidental),
                at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                color: resolved.fillColor ?? resolved.strokeColor ?? style.defaultInkColor,
                size: max(10, element.frame.height * 0.9)
            )
        }
    }

    private func drawKeySignatures<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .keySignature {
            guard let accidental = element.accidental else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            context.drawText(
                accidentalSymbol(for: accidental),
                at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                color: resolved.fillColor ?? resolved.strokeColor ?? style.glyphStyle.color,
                size: max(10, element.frame.height * 0.9)
            )
        }
    }

    private func drawTextAnnotations<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .lyric || element.kind == .fingering {
            guard let annotation = element.annotation else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            context.drawText(
                annotation.text,
                at: annotation.origin,
                color: resolved.fillColor ?? resolved.strokeColor ?? style.glyphStyle.color,
                size: element.kind == .fingering ? max(8, annotation.frame.height * 0.8) : max(9, annotation.frame.height * 0.75)
            )
        }
    }

    private func accidentalSymbol(for accidental: String) -> String {
        switch accidental {
        case "sharp":
            return "#"
        case "flat":
            return "b"
        case "natural":
            return "n"
        case "double-sharp":
            return "x"
        case "flat-flat":
            return "bb"
        default:
            return accidental
        }
    }
}

final class CoreGraphicsScoreDrawingContext: ScoreDrawingContext {
    private let context: CGContext

    init(_ context: CGContext) {
        self.context = context
    }

    func fill(_ rect: CGRect, color: ScoreColor) {
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    func fillEllipse(in rect: CGRect, color: ScoreColor) {
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
    }

    func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: rect)
    }

    func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color.cgColor,
            .font: CTFontCreateWithName("Helvetica" as CFString, size, nil),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        context.saveGState()
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

extension ScoreColor {
    var cgColor: CGColor {
        CGColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}
