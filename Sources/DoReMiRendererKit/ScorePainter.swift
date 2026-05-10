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
        continuationNoteIDs: Set<NoteID> = [],
        into context: inout Context
    ) {
        let secondaryNoteIDs = continuationNoteIDs.subtracting(currentNoteIDs)
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
        drawContinuationNoteHighlights(layout: layout, noteIDs: secondaryNoteIDs, style: style, into: &context)
        drawNoteHighlights(layout: layout, noteIDs: effectiveSelection.selectedNoteIDs, style: style, into: &context)
        drawStructuralSymbols(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawKeySignatures(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawNotesAndRests(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawAccidentals(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawTextAnnotations(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
    }

    private func drawStructuralSymbols<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .clef || element.kind == .timeSignature || element.kind == .barline {
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            let color = resolved.fillColor ?? resolved.strokeColor ?? style.defaultInkColor
            switch element.kind {
            case .clef:
                let glyph = element.clef?.kind == .bass ? "𝄢" : "𝄞"
                context.drawText(glyph, at: CGPoint(x: element.frame.midX, y: element.frame.midY), color: color, size: max(18, element.frame.height * 0.62))
            case .timeSignature:
                let text = element.timeSignature.map { "\($0.beats)\n\($0.beatType)" } ?? ""
                context.drawText(text, at: CGPoint(x: element.frame.midX, y: element.frame.midY), color: color, size: max(10, element.frame.height * 0.34))
            case .barline:
                drawBarline(element: element, color: color, into: &context)
            default:
                break
            }
        }
    }

    private func drawBarline<Context: ScoreDrawingContext>(
        element: ElementLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        let frame = element.frame
        if let repeatBarline = element.repeatBarline {
            let x1 = repeatBarline.direction == .forward ? frame.minX : frame.maxX
            let x2 = repeatBarline.direction == .forward ? frame.minX + frame.width * 0.45 : frame.maxX - frame.width * 0.45
            context.strokeLine(from: CGPoint(x: x1, y: frame.minY), to: CGPoint(x: x1, y: frame.maxY), color: color, lineWidth: 2)
            context.strokeLine(from: CGPoint(x: x2, y: frame.minY), to: CGPoint(x: x2, y: frame.maxY), color: color, lineWidth: 1)
            let dotX = repeatBarline.direction == .forward ? frame.maxX : frame.minX
            let dotSize = max(3, frame.width * 0.25)
            context.fillEllipse(in: CGRect(x: dotX - dotSize / 2, y: frame.midY - frame.height * 0.12, width: dotSize, height: dotSize), color: color)
            context.fillEllipse(in: CGRect(x: dotX - dotSize / 2, y: frame.midY + frame.height * 0.12, width: dotSize, height: dotSize), color: color)
        } else {
            context.strokeLine(from: CGPoint(x: frame.midX, y: frame.minY), to: CGPoint(x: frame.midX, y: frame.maxY), color: color, lineWidth: 1)
        }
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

    private func drawContinuationNoteHighlights<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        noteIDs: Set<NoteID>,
        style: ScoreStyle,
        into context: inout Context
    ) {
        let base = style.highlightStyle.color
        let fill = ScoreColor(red: base.red, green: base.green, blue: base.blue, alpha: min(base.alpha, 0.14))
        let stroke = ScoreColor(red: base.red, green: base.green, blue: base.blue, alpha: min(max(base.alpha, 0.28), 0.42))
        for noteID in noteIDs {
            guard let noteLayout = layout.noteLayout(for: noteID) else {
                continue
            }
            let frame = noteLayout.noteheadFrame.insetBy(dx: -6, dy: -6)
            context.fillEllipse(in: frame, color: fill)
            context.strokeEllipse(in: frame, color: stroke, lineWidth: 1.5)
        }
    }

    private func drawNotesAndRests<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .notehead
            || element.kind == .rest
            || element.kind == .stem
            || element.kind == .flag
            || element.kind == .dot {
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
            case .rest:
                drawRest(element: element, resolved: resolved, style: style, into: &context)
            case .stem:
                drawStem(element: element, resolved: resolved, style: style, into: &context)
            case .flag:
                drawFlag(element: element, resolved: resolved, style: style, into: &context)
            case .dot:
                drawDot(element: element, resolved: resolved, style: style, into: &context)
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
        let noteValue = element.noteLayout?.noteValueKind ?? .quarter
        switch noteValue {
        case .whole, .half:
            context.fillEllipse(in: element.frame, color: style.backgroundColor)
            context.strokeEllipse(in: element.frame, color: fillColor, lineWidth: max(1.2, element.frame.width * 0.12))
        case .quarter, .eighth, .sixteenth, .other:
            context.fillEllipse(in: element.frame, color: fillColor)
            if let strokeColor = resolved.strokeColor {
                context.strokeEllipse(in: element.frame, color: strokeColor, lineWidth: CGFloat(resolved.lineWidth ?? 1))
            }
        }
    }

    private func drawStem<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        guard let noteLayout = element.noteLayout else {
            return
        }
        let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
        let drawsDown = element.frame.midY > noteLayout.noteheadCenter.y
        let start = CGPoint(x: element.frame.midX, y: noteLayout.noteheadCenter.y)
        let endY = drawsDown ? element.frame.maxY : element.frame.minY
        let end = CGPoint(x: element.frame.midX, y: endY)
        context.strokeLine(from: start, to: end, color: color, lineWidth: max(1, noteLayout.noteheadFrame.width * 0.08))
    }

    private func drawFlag<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        guard let noteLayout = element.noteLayout else {
            return
        }
        let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
        let lineWidth = max(1, noteLayout.noteheadFrame.width * 0.08)
        let drawsDown = element.frame.midY > noteLayout.noteheadCenter.y
        for flagIndex in 0..<noteLayout.noteValueKind.flagCount {
            let yOffset = CGFloat(flagIndex) * noteLayout.noteheadFrame.height * 0.42
            let start: CGPoint
            let flagMid: CGPoint
            let flagEnd: CGPoint
            if drawsDown {
                start = CGPoint(x: element.frame.maxX, y: element.frame.maxY - yOffset)
                flagMid = CGPoint(x: element.frame.minX + element.frame.width * 0.25, y: element.frame.maxY - element.frame.height * 0.45 - yOffset)
                flagEnd = CGPoint(x: element.frame.minX + element.frame.width * 0.55, y: element.frame.maxY - element.frame.height * 0.82 - yOffset)
            } else {
                start = CGPoint(x: element.frame.minX, y: element.frame.minY + yOffset)
                flagMid = CGPoint(x: element.frame.minX + element.frame.width * 0.75, y: element.frame.minY + element.frame.height * 0.45 + yOffset)
                flagEnd = CGPoint(x: element.frame.minX + element.frame.width * 0.45, y: element.frame.minY + element.frame.height * 0.82 + yOffset)
            }
            context.strokeLine(from: start, to: flagMid, color: color, lineWidth: lineWidth)
            context.strokeLine(from: flagMid, to: flagEnd, color: color, lineWidth: lineWidth)
        }
    }

    private func drawDot<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        context.fillEllipse(in: element.frame, color: resolved.fillColor ?? resolved.strokeColor ?? style.defaultInkColor)
    }

    private func drawRest<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
        let frame = element.frame
        switch element.noteLayout?.noteValueKind ?? .quarter {
        case .whole:
            let restRect = CGRect(x: frame.minX, y: frame.midY, width: frame.width, height: max(2, frame.height * 0.22))
            context.fill(restRect, color: color)
        case .half:
            let restRect = CGRect(x: frame.minX, y: frame.midY - frame.height * 0.22, width: frame.width, height: max(2, frame.height * 0.22))
            context.fill(restRect, color: color)
        case .quarter:
            context.strokeLine(from: CGPoint(x: frame.midX, y: frame.minY), to: CGPoint(x: frame.minX, y: frame.midY), color: color, lineWidth: max(1, frame.width * 0.1))
            context.strokeLine(from: CGPoint(x: frame.minX, y: frame.midY), to: CGPoint(x: frame.maxX, y: frame.midY), color: color, lineWidth: max(1, frame.width * 0.1))
            context.strokeLine(from: CGPoint(x: frame.maxX, y: frame.midY), to: CGPoint(x: frame.midX, y: frame.maxY), color: color, lineWidth: max(1, frame.width * 0.1))
        case .eighth, .sixteenth, .other:
            context.fillEllipse(in: CGRect(x: frame.minX, y: frame.midY, width: frame.width * 0.35, height: frame.height * 0.35), color: color)
            context.strokeLine(from: CGPoint(x: frame.midX, y: frame.minY), to: CGPoint(x: frame.midX, y: frame.maxY), color: color, lineWidth: max(1, frame.width * 0.08))
            context.strokeLine(from: CGPoint(x: frame.midX, y: frame.minY), to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * 0.35), color: color, lineWidth: max(1, frame.width * 0.08))
        }
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

private extension NoteValueKind {
    var flagCount: Int {
        switch self {
        case .eighth:
            1
        case .sixteenth:
            2
        case .whole, .half, .quarter, .other:
            0
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
