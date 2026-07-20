import CoreGraphics
import CoreText
import Foundation

protocol ScoreDrawingContext {
    mutating func fill(_ rect: CGRect, color: ScoreColor)
    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat)
    mutating func fillEllipse(in rect: CGRect, color: ScoreColor)
    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat)
    mutating func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat)
    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?)
    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?, mirroredHorizontally: Bool, mirroredVertically: Bool)
}

extension ScoreDrawingContext {
    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat) {
        drawText(text, at: point, color: color, size: size, fontName: nil)
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?, mirroredHorizontally: Bool, mirroredVertically: Bool) {
        drawText(text, at: point, color: color, size: size, fontName: fontName)
    }

    mutating func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        strokeLine(from: start, to: control, color: color, lineWidth: lineWidth)
        strokeLine(from: control, to: end, color: color, lineWidth: lineWidth)
    }
}

struct ScorePainter: Sendable {
    private let smuflFontName: String?
    private let visibleRect: CGRect?
    private let smuflSizePolicy = SMuFLGlyphSizePolicy()
    private let repeatTextFontName = "Georgia-Italic"

    init(smuflFontName: String? = SMuFLFont.registeredFontName(), visibleRect: CGRect? = nil) {
        self.smuflFontName = smuflFontName
        self.visibleRect = visibleRect
    }

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
        let effectiveSelection = selection ?? ScoreSelection()

        context.fill(CGRect(origin: .zero, size: layout.canvasSize), color: style.backgroundColor)
        drawScoreTitle(layout: layout, style: style, into: &context)
        drawStaffLines(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawLedgerLines(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawContinuationNoteHighlights(layout: layout, noteIDs: secondaryNoteIDs, style: style, into: &context)
        drawCurrentNoteBars(layout: layout, noteIDs: currentNoteIDs, into: &context)
        drawNoteHighlights(layout: layout, noteIDs: effectiveSelection.selectedNoteIDs, style: style, into: &context)
        drawStructuralSymbols(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawKeySignatures(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawCurves(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawNotesAndRests(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawTuplets(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawAccidentals(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawTextAnnotations(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawExpressionMarks(layout: layout, score: score, style: style, selection: effectiveSelection, into: &context)
        drawMeasureNumbers(layout: layout, style: style, into: &context)
    }

    private func drawScoreTitle<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        style: ScoreStyle,
        into context: inout Context
    ) {
        guard let title = layout.title, isVisible(title.frame) else {
            return
        }
        context.drawText(
            title.text,
            at: CGPoint(x: title.frame.midX, y: title.frame.midY),
            color: style.defaultInkColor,
            size: title.fontSize,
            fontName: title.fontName
        )
    }

    private func drawMeasureNumbers<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        style: ScoreStyle,
        into context: inout Context
    ) {
        guard style.measureNumberDisplayMode != .hidden else {
            return
        }
        let staffSpace = layout.staves.first.map { max(1, $0.frame.height / 4) } ?? 10
        let fontSize: CGFloat = max(7, min(11, staffSpace * 1.15))
        for measure in layout.measures where shouldDrawMeasureNumber(
            measure,
            in: layout,
            displayMode: style.measureNumberDisplayMode
        ) && isVisible(measure.frame) {
            let bottomStaffFrame = bottomStaffFrame(for: measure, in: layout) ?? measure.frame
            let point = CGPoint(
                x: measure.frame.minX + fontSize * 0.45,
                y: bottomStaffFrame.maxY + fontSize * 1.15
            )
            context.drawText(
                measureNumberText(for: measure),
                at: point,
                color: style.defaultInkColor,
                size: fontSize,
                fontName: nil
            )
        }
    }

    private func bottomStaffFrame(for measure: MeasureLayout, in layout: ScoreLayout) -> CGRect? {
        layout.staves
            .filter { $0.systemIndex == measure.systemIndex }
            .max { lhs, rhs in
                if lhs.frame.maxY != rhs.frame.maxY {
                    return lhs.frame.maxY < rhs.frame.maxY
                }
                return lhs.staffID.rawValue < rhs.staffID.rawValue
            }?
            .frame
    }

    private func shouldDrawMeasureNumber(
        _ measure: MeasureLayout,
        in layout: ScoreLayout,
        displayMode: MeasureNumberDisplayMode
    ) -> Bool {
        if displayMode == .systemLeading {
            let primaryMeasures = layout.measures.filter {
                $0.systemIndex == measure.systemIndex && $0.partIndex == 0
            }
            guard measure.partIndex == 0,
                  let leadingX = primaryMeasures.map(\.frame.minX).min()
            else {
                return false
            }
            return abs(measure.frame.minX - leadingX) < 0.5
        }
        guard let number = Int(measureNumberText(for: measure).trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return number % 2 == 0
    }

    private func measureNumberText(for measure: MeasureLayout) -> String {
        measure.measureID.rawValue.split(separator: ".", maxSplits: 1).last.map(String.init) ?? measure.measureID.rawValue
    }

    private func drawStructuralSymbols<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where isVisible(element.frame) && (element.kind == .clef
            || element.kind == .timeSignature
            || element.kind == .barline
            || element.kind == .repeatEnding
            || element.kind == .measureRepeat
            || element.kind == .playbackJumpMarker) {
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
                let glyph: SMuFLGlyph = element.clef?.kind == .bass ? .bassClef : .trebleClef
                if !drawSMuFLGlyph(
                    element.clef?.kind == .bass ? .bassClef : .trebleClef,
                    at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                    color: color,
                    size: smuflSizePolicy.clefSize(for: element.frame),
                    into: &context
                ) {
                    context.drawText(glyph.fallback, at: CGPoint(x: element.frame.midX, y: element.frame.midY), color: color, size: smuflSizePolicy.clefSize(for: element.frame))
                }
            case .timeSignature:
                drawTimeSignature(element: element, color: color, into: &context)
            case .barline:
                drawBarline(element: element, layout: layout, color: color, into: &context)
            case .repeatEnding:
                drawRepeatEnding(element: element, color: color, into: &context)
            case .measureRepeat:
                drawMeasureRepeat(element: element, color: color, into: &context)
            case .playbackJumpMarker:
                drawPlaybackJumpMarker(element: element, color: color, into: &context)
            default:
                break
            }
        }
    }

    private func drawBarline<Context: ScoreDrawingContext>(
        element: ElementLayout,
        layout: ScoreLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        let frame = element.frame
        if let repeatBarline = element.repeatBarline {
            let staffFrames = repeatStaffFrames(for: element, in: layout)
            let lineFrame = repeatLineFrame(for: frame, staffFrames: staffFrames)
            let staffSpace = max(1, staffFrames.first.map { $0.height / 4 } ?? frame.height / 4)
            let thickLineWidth = max(2, staffSpace * 0.30)
            let thinLineWidth = max(1, staffSpace * 0.12)
            // Keep a fixed four-point separation between the repeat's thick
            // and thin strokes so both remain distinct in the Web reader and
            // its exported print plan.
            let lineGap: CGFloat = 4
            let thickInset = thickLineWidth / 2
            let thickX = repeatBarline.direction == .forward ? frame.minX + thickInset : frame.maxX - thickInset
            let thinX = repeatBarline.direction == .forward ? thickX + lineGap : thickX - lineGap
            context.strokeLine(from: CGPoint(x: thickX, y: lineFrame.minY), to: CGPoint(x: thickX, y: lineFrame.maxY), color: color, lineWidth: thickLineWidth)
            context.strokeLine(from: CGPoint(x: thinX, y: lineFrame.minY), to: CGPoint(x: thinX, y: lineFrame.maxY), color: color, lineWidth: thinLineWidth)
            let dotGap = max(staffSpace * 0.7, 5)
            let dotX = repeatBarline.direction == .forward ? thinX + dotGap : thinX - dotGap
            for staffFrame in staffFrames {
                let staffSpace = max(1, staffFrame.height / 4)
                let dotSize = max(3, staffSpace * 0.5)
                let glyphSize = smuflSizePolicy.repeatDotSize(for: staffFrame)
                for dotY in [staffFrame.midY - staffSpace * 0.5, staffFrame.midY + staffSpace * 0.5] {
                    if !drawSMuFLGlyph(
                        .repeatDot,
                        at: CGPoint(x: dotX, y: dotY),
                        color: color,
                        size: glyphSize,
                        into: &context
                    ) {
                        context.fillEllipse(in: CGRect(x: dotX - dotSize / 2, y: dotY - dotSize / 2, width: dotSize, height: dotSize), color: color)
                    }
                }
            }
        } else {
            drawStyledBarline(
                style: element.barlineStyle ?? .regular,
                frame: frame,
                anchor: styledBarlineAnchor(for: element, in: layout),
                staffFrames: repeatStaffFrames(for: element, in: layout),
                color: color,
                into: &context
            )
        }
    }

    private func drawStyledBarline<Context: ScoreDrawingContext>(
        style: BarlineStyle,
        frame: CGRect,
        anchor: StyledBarlineAnchor,
        staffFrames: [CGRect],
        color: ScoreColor,
        into context: inout Context
    ) {
        guard style != .none else { return }
        let staffSpace = max(1, staffFrames.first.map { $0.height / 4 } ?? frame.height / 8)
        let thinWidth = max(1, staffSpace * 0.12)
        let heavyWidth = max(3, staffSpace * 0.48)
        let gap = max(3, staffSpace * 0.55)
        let primaryX = anchor.primaryX(fallback: frame.midX)
        let pairXs = anchor.pairXs(gap: gap, fallback: frame.midX)
        func stroke(_ x: CGFloat, width: CGFloat) {
            context.strokeLine(from: CGPoint(x: x, y: frame.minY), to: CGPoint(x: x, y: frame.maxY), color: color, lineWidth: width)
        }
        switch style {
        case .regular:
            stroke(primaryX, width: thinWidth)
        case .heavy:
            stroke(primaryX, width: heavyWidth)
        case .lightLight:
            stroke(pairXs.left, width: thinWidth)
            stroke(pairXs.right, width: thinWidth)
        case .lightHeavy:
            stroke(pairXs.left, width: thinWidth)
            stroke(pairXs.right, width: heavyWidth)
        case .heavyLight:
            stroke(pairXs.left, width: heavyWidth)
            stroke(pairXs.right, width: thinWidth)
        case .heavyHeavy:
            stroke(pairXs.left, width: heavyWidth)
            stroke(pairXs.right, width: heavyWidth)
        case .dotted, .dashed, .tick, .short:
            stroke(primaryX, width: thinWidth)
        case .none:
            break
        }
    }

    private enum StyledBarlineAnchor {
        case centered
        case leftBoundary(CGFloat)
        case rightBoundary(CGFloat)

        func primaryX(fallback: CGFloat) -> CGFloat {
            switch self {
            case .centered:
                return fallback
            case .leftBoundary(let x), .rightBoundary(let x):
                return x
            }
        }

        func pairXs(gap: CGFloat, fallback: CGFloat) -> (left: CGFloat, right: CGFloat) {
            switch self {
            case .centered:
                return (fallback - gap / 2, fallback + gap / 2)
            case .leftBoundary(let x):
                return (x, x + gap)
            case .rightBoundary(let x):
                return (x - gap, x)
            }
        }
    }

    private func styledBarlineAnchor(for element: ElementLayout, in layout: ScoreLayout) -> StyledBarlineAnchor {
        guard let measureID = element.measureID,
              let measure = layout.measures.first(where: { $0.measureID == measureID }) else {
            return .centered
        }
        let tolerance = max(2, element.frame.width * 2)
        if abs(element.frame.midX - measure.frame.minX) <= tolerance {
            return .leftBoundary(measure.frame.minX)
        }
        if abs(element.frame.midX - measure.frame.maxX) <= tolerance {
            return .rightBoundary(measure.frame.maxX)
        }
        return .centered
    }

    private func repeatStaffFrames(for element: ElementLayout, in layout: ScoreLayout) -> [CGRect] {
        if let measureID = element.measureID,
           let measure = layout.measures.first(where: { $0.measureID == measureID }) {
            let systemStaves = layout.staves
                .filter { $0.systemIndex == measure.systemIndex }
                .sorted { lhs, rhs in
                    if lhs.frame.minY != rhs.frame.minY {
                        return lhs.frame.minY < rhs.frame.minY
                    }
                    return lhs.staffID.rawValue < rhs.staffID.rawValue
                }
            if !systemStaves.isEmpty {
                return systemStaves.map(\.frame)
            }
        }

        let intersectingStaves = layout.staves
            .filter { $0.frame.intersects(element.frame.insetBy(dx: -1, dy: 0)) }
            .sorted { $0.frame.minY < $1.frame.minY }
        return intersectingStaves.isEmpty ? [element.frame] : intersectingStaves.map(\.frame)
    }

    private func repeatLineFrame(for frame: CGRect, staffFrames: [CGRect]) -> CGRect {
        guard let first = staffFrames.first else {
            return frame
        }
        let minY = staffFrames.reduce(first.minY) { min($0, $1.minY) }
        let maxY = staffFrames.reduce(first.maxY) { max($0, $1.maxY) }
        return CGRect(x: frame.minX, y: min(frame.minY, minY), width: frame.width, height: max(frame.maxY, maxY) - min(frame.minY, minY))
    }

    private func drawRepeatEnding<Context: ScoreDrawingContext>(
        element: ElementLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        guard let repeatEnding = element.repeatEnding else {
            return
        }
        let lineWidth: CGFloat = max(1.2, element.frame.height * 0.045)
        context.strokeLine(from: repeatEnding.lineStart, to: repeatEnding.lineEnd, color: color, lineWidth: lineWidth)
        if let startHookEnd = repeatEnding.startHookEnd {
            context.strokeLine(from: repeatEnding.lineStart, to: startHookEnd, color: color, lineWidth: lineWidth)
        }
        if let endHookEnd = repeatEnding.endHookEnd {
            context.strokeLine(from: repeatEnding.lineEnd, to: endHookEnd, color: color, lineWidth: lineWidth)
        }
        context.drawText(
            repeatEnding.label,
            at: repeatEnding.labelPoint,
            color: color,
            size: repeatTextSize(for: element),
            fontName: repeatTextFontName
        )
    }

    private func drawMeasureRepeat<Context: ScoreDrawingContext>(
        element: ElementLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        let point = CGPoint(x: element.frame.midX, y: element.frame.midY)
        let size = max(28, element.frame.height * 1.05)
        if !drawSMuFLGlyph(.repeatOneBar, at: point, color: color, size: size, into: &context) {
            context.drawText(SMuFLGlyph.repeatOneBar.fallback, at: point, color: color, size: size, fontName: nil)
        }
    }

    private func drawPlaybackJumpMarker<Context: ScoreDrawingContext>(
        element: ElementLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        guard let marker = element.playbackJumpMarker else {
            return
        }
        let textSize = repeatTextSize(for: element)
        let symbolSize = repeatSymbolSize(for: element)
        switch marker.marker.kind {
        case .segno:
            if !drawSMuFLGlyph(.segno, at: marker.point, color: color, size: symbolSize, into: &context) {
                context.drawText(SMuFLGlyph.segno.fallback, at: marker.point, color: color, size: symbolSize, fontName: nil)
            }
            return
        case .coda:
            if !drawSMuFLGlyph(.coda, at: marker.point, color: color, size: symbolSize, into: &context) {
                context.drawText(SMuFLGlyph.coda.fallback, at: marker.point, color: color, size: symbolSize, fontName: nil)
            }
            return
        case .toCoda:
            let textPoint = CGPoint(x: marker.point.x, y: marker.point.y)
            context.drawText("To", at: textPoint, color: color, size: textSize, fontName: repeatTextFontName)
            let glyphPoint = CGPoint(x: marker.point.x + textSize * 1.05, y: marker.point.y)
            if !drawSMuFLGlyph(.coda, at: glyphPoint, color: color, size: symbolSize * 0.9, into: &context) {
                context.drawText(SMuFLGlyph.coda.fallback, at: glyphPoint, color: color, size: symbolSize * 0.9, fontName: nil)
            }
            return
        default:
            break
        }
        context.drawText(
            marker.label,
            at: marker.point,
            color: color,
            size: textSize,
            fontName: repeatTextFontName
        )
    }

    private func repeatTextSize(for element: ElementLayout) -> CGFloat {
        max(9, element.frame.height * 0.72)
    }

    private func repeatSymbolSize(for element: ElementLayout) -> CGFloat {
        max(13, element.frame.height * 1.05)
    }

    private func drawStaffLines<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .staffLine && isVisible(element.frame) {
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
        for element in layout.elements where element.kind == .ledgerLine && isVisible(element.frame) {
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

    private func drawCurrentNoteBars<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        noteIDs: Set<NoteID>,
        into context: inout Context
    ) {
        let color = ScoreColor(red: 0.08, green: 0.72, blue: 1, alpha: 0.78)
        var drawnBarKeys: Set<String> = []
        for noteID in noteIDs {
            guard let noteLayout = layout.noteLayout(for: noteID) else {
                continue
            }
            let staffFrame = noteLayout.staffID.flatMap { staffID in
                layout.staves
                    .filter { $0.staffID == staffID }
                    .min {
                        abs($0.middleLineY - noteLayout.noteheadCenter.y) < abs($1.middleLineY - noteLayout.noteheadCenter.y)
                    }?
                    .frame
            }
            let referenceFrame = staffFrame ?? noteLayout.noteheadFrame
            let width = max(3, noteLayout.noteheadFrame.width * 0.16)
            let x = noteLayout.noteheadFrame.minX - noteLayout.noteheadFrame.width * 0.05
            let y = referenceFrame.minY - width
            let height = referenceFrame.height + width * 2
            let barKey = [
                noteLayout.staffID?.rawValue ?? "staff",
                String(Int(x.rounded())),
                String(Int(y.rounded())),
                String(Int(height.rounded())),
            ].joined(separator: ".")
            guard drawnBarKeys.insert(barKey).inserted else {
                continue
            }
            context.fill(CGRect(x: x, y: y, width: width, height: height), color: color)
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
        let drawingOrder: [[ScoreElementKind]] = [
            [.rest],
            [.stem, .beam, .flag],
            [.notehead],
            [.dot],
        ]
        for kinds in drawingOrder {
            for element in layout.elements where kinds.contains(element.kind) && isVisible(element.frame) {
                drawNoteOrRestElement(
                    element,
                    layout: layout,
                    score: score,
                    style: style,
                    selection: selection,
                    into: &context
                )
            }
        }
    }

    private func drawNoteOrRestElement<Context: ScoreDrawingContext>(
        _ element: ElementLayout,
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
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
            case .beam:
                drawBeam(element: element, resolved: resolved, style: style, into: &context)
            case .flag:
                drawFlag(element: element, resolved: resolved, style: style, into: &context)
            case .dot:
                drawDot(element: element, resolved: resolved, style: style, into: &context)
            default:
                break
            }
    }

    private func drawCurves<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where isVisible(element.frame) && (element.kind == .tie || element.kind == .slur) {
            guard let curve = element.curve else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(for: element, score: score, layout: layout, style: style, selection: selection)
            let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
            let lineWidth: CGFloat = curve.kind == .tie ? 1.6 : 1.3
            context.strokeQuadCurve(from: curve.start, control: curve.control, to: curve.end, color: color, lineWidth: lineWidth)
        }
    }

    private func drawTuplets<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where element.kind == .tuplet && isVisible(element.frame) {
            guard let tuplet = element.tuplet else {
                continue
            }
            let resolved = style.colorResolver.resolvedStyle(for: element, score: score, layout: layout, style: style, selection: selection)
            let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
            let left = CGPoint(x: tuplet.frame.minX, y: tuplet.frame.midY)
            let right = CGPoint(x: tuplet.frame.maxX, y: tuplet.frame.midY)
            let tick: CGFloat = max(4, tuplet.frame.height * 0.35)
            let numberSize = max(10, tuplet.frame.height * 0.75)
            // Leave a text-sized opening in the bracket. The previous fixed gap
            // allowed the bracket to pass through the numeral at A4 staff sizes.
            let numberClearance = max(numberSize * 0.45, tuplet.frame.height * 0.65)
            context.strokeLine(from: CGPoint(x: left.x, y: left.y + tick), to: left, color: color, lineWidth: 1)
            context.strokeLine(from: left, to: CGPoint(x: tuplet.frame.midX - numberClearance, y: tuplet.frame.midY), color: color, lineWidth: 1)
            context.strokeLine(from: CGPoint(x: tuplet.frame.midX + numberClearance, y: tuplet.frame.midY), to: right, color: color, lineWidth: 1)
            context.strokeLine(from: right, to: CGPoint(x: right.x, y: right.y + tick), color: color, lineWidth: 1)
            context.drawText(tuplet.number, at: CGPoint(x: tuplet.frame.midX, y: tuplet.frame.midY), color: color, size: numberSize, fontName: nil)
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
        if drawSMuFLGlyph(
            .notehead(for: noteValue),
            at: CGPoint(x: element.frame.midX, y: element.frame.midY),
            color: fillColor,
            size: smuflSizePolicy.noteheadSize(for: element.frame, noteValue: noteValue),
            into: &context
        ) {
            return
        }

        switch noteValue {
        case .whole, .half:
            context.fillEllipse(in: element.frame, color: style.backgroundColor)
            context.strokeEllipse(in: element.frame, color: fillColor, lineWidth: max(0.9, element.frame.width * 0.09))
        case .quarter, .eighth, .sixteenth, .thirtySecond, .other:
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
        let startY = drawsDown ? element.frame.minY : element.frame.maxY
        let start = CGPoint(x: element.frame.midX, y: startY)
        let endY = drawsDown ? element.frame.maxY : element.frame.minY
        let end = CGPoint(x: element.frame.midX, y: endY)
        context.strokeLine(from: start, to: end, color: color, lineWidth: max(0.9, noteLayout.noteheadFrame.width * 0.085))
    }

    private func drawBeam<Context: ScoreDrawingContext>(
        element: ElementLayout,
        resolved: ResolvedVisualStyle,
        style: ScoreStyle,
        into context: inout Context
    ) {
        let color = resolved.strokeColor ?? resolved.fillColor ?? style.defaultInkColor
        if let beam = element.beam {
            context.strokeLine(from: beam.primary.start, to: beam.primary.end, color: color, lineWidth: beam.thickness)
            for segment in beam.secondarySegments {
                context.strokeLine(from: segment.start, to: segment.end, color: color, lineWidth: beam.thickness)
            }
        } else {
            let thickness = min(6, max(3, element.frame.height * 0.18))
            let frame = CGRect(
                x: element.frame.minX,
                y: element.frame.minY,
                width: element.frame.width,
                height: thickness
            )
            context.fill(frame, color: color)
        }
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
        let lineWidth = max(0.9, noteLayout.noteheadFrame.width * 0.085)
        let drawsDown = element.frame.midY > noteLayout.noteheadCenter.y
        if let glyph = flagGlyph(for: noteLayout.noteValueKind),
           drawSMuFLGlyph(
               glyph,
               at: flagGlyphAnchor(element: element, noteLayout: noteLayout, drawsDown: drawsDown),
               color: color,
               size: smuflSizePolicy.flagSize(for: element.frame),
               mirroredHorizontally: false,
               mirroredVertically: drawsDown,
               into: &context
           ) {
            return
        }

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
        let noteValue = element.noteLayout?.noteValueKind ?? .quarter
        if drawSMuFLGlyph(
            .rest(for: noteValue),
            at: CGPoint(x: frame.midX, y: frame.midY),
            color: color,
            size: smuflSizePolicy.restSize(for: frame, noteValue: noteValue),
            into: &context
        ) {
            return
        }

        switch noteValue {
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
        case .eighth, .sixteenth, .thirtySecond, .other:
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
        for element in layout.elements where element.kind == .accidental && isVisible(element.frame) {
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
                accidentalGlyphString(for: accidental),
                at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                color: resolved.fillColor ?? resolved.strokeColor ?? style.defaultInkColor,
                size: smuflSizePolicy.accidentalSize(for: element.frame),
                fontName: accidentalGlyphFontName(for: accidental)
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
        for element in layout.elements where element.kind == .keySignature && isVisible(element.frame) {
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
                accidentalGlyphString(for: accidental),
                at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                color: resolved.fillColor ?? resolved.strokeColor ?? style.glyphStyle.color,
                size: smuflSizePolicy.keySignatureAccidentalSize(for: element.frame),
                fontName: accidentalGlyphFontName(for: accidental)
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
        for element in layout.elements where isVisible(element.frame) && (element.kind == .lyric || element.kind == .fingering) {
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

    private func drawExpressionMarks<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection,
        into context: inout Context
    ) {
        for element in layout.elements where isVisible(element.frame) && (element.kind == .articulation || element.kind == .dynamic || element.kind == .hairpin || element.kind == .pedal) {
            let resolved = style.colorResolver.resolvedStyle(
                for: element,
                score: score,
                layout: layout,
                style: style,
                selection: selection
            )
            let color = resolved.fillColor ?? resolved.strokeColor ?? style.defaultInkColor
            switch element.kind {
            case .articulation:
                guard let articulation = element.articulation else { continue }
                drawArticulation(articulation, color: color, into: &context)
            case .dynamic:
                guard let dynamic = element.dynamic else { continue }
                let size = max(9, dynamic.frame.height * 0.75)
                context.drawText(
                    dynamic.mark.rawValue,
                    at: dynamic.origin,
                    color: color,
                    size: size,
                    fontName: "Georgia-Italic"
                )
            case .hairpin:
                guard let hairpin = element.hairpin else { continue }
                context.strokeLine(from: hairpin.start, to: hairpin.upperEnd, color: color, lineWidth: max(0.9, hairpin.frame.height * 0.12))
                context.strokeLine(from: hairpin.start, to: hairpin.lowerEnd, color: color, lineWidth: max(0.9, hairpin.frame.height * 0.12))
            case .pedal:
                guard let pedal = element.pedal else { continue }
                context.drawText(
                    pedal.label,
                    at: pedal.origin,
                    color: color,
                    size: max(9, pedal.frame.height * 0.92),
                    fontName: "Georgia-Italic"
                )
            default:
                break
            }
        }
    }

    private func drawArticulation<Context: ScoreDrawingContext>(
        _ articulation: ArticulationLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        let size = min(articulation.frame.width, articulation.frame.height)
        switch articulation.kind {
        case .staccato:
            let dotSize = max(2, size * 0.38)
            context.fillEllipse(
                in: CGRect(
                    x: articulation.point.x - dotSize / 2,
                    y: articulation.point.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                ),
                color: color
            )
        case .tenuto:
            let halfWidth = max(3, size * 0.45)
            context.strokeLine(
                from: CGPoint(x: articulation.point.x - halfWidth, y: articulation.point.y),
                to: CGPoint(x: articulation.point.x + halfWidth, y: articulation.point.y),
                color: color,
                lineWidth: max(0.9, size * 0.13)
            )
        case .accent:
            context.drawText(">", at: articulation.point, color: color, size: max(9, size), fontName: "Georgia-Italic")
        case .marcato:
            context.drawText("^", at: articulation.point, color: color, size: max(9, size), fontName: "Georgia-Italic")
        case .fermata:
            let glyph = articulation.placement == .below ? "\u{1D111}" : "\u{1D110}"
            context.drawText(glyph, at: articulation.point, color: color, size: max(10, size * 1.05), fontName: smuflFontName)
        }
    }

    @discardableResult
    private func drawSMuFLGlyph<Context: ScoreDrawingContext>(
        _ glyph: SMuFLGlyph,
        at point: CGPoint,
        color: ScoreColor,
        size: CGFloat,
        mirroredHorizontally: Bool = false,
        mirroredVertically: Bool = false,
        into context: inout Context
    ) -> Bool {
        guard let smuflFontName else {
            return false
        }
        context.drawText(glyph.string, at: point, color: color, size: size, fontName: smuflFontName, mirroredHorizontally: mirroredHorizontally, mirroredVertically: mirroredVertically)
        return true
    }

    private func drawTimeSignature<Context: ScoreDrawingContext>(
        element: ElementLayout,
        color: ScoreColor,
        into context: inout Context
    ) {
        guard let timeSignature = element.timeSignature else {
            return
        }

        let size = element.timeSignatureFontSize ?? smuflSizePolicy.timeSignatureSize(for: element.frame)
        let digitInset = element.timeSignatureDigitInset
        if smuflFontName != nil {
            let beats = smuflDigits(timeSignature.beats)
            let beatType = smuflDigits(timeSignature.beatType)
            context.drawText(
                beats,
                at: CGPoint(x: element.frame.midX, y: element.frame.minY + element.frame.height * 0.23 + digitInset),
                color: color,
                size: size,
                fontName: smuflFontName
            )
            context.drawText(
                beatType,
                at: CGPoint(x: element.frame.midX, y: element.frame.minY + element.frame.height * 0.72 - digitInset),
                color: color,
                size: size,
                fontName: smuflFontName
            )
            return
        }

        guard digitInset > 0 else {
            context.drawText(
                "\(timeSignature.beats)\n\(timeSignature.beatType)",
                at: CGPoint(x: element.frame.midX, y: element.frame.midY),
                color: color,
                size: size
            )
            return
        }

        context.drawText(
            "\(timeSignature.beats)",
            at: CGPoint(x: element.frame.midX, y: element.frame.minY + element.frame.height * 0.23 + digitInset),
            color: color,
            size: size
        )
        context.drawText(
            "\(timeSignature.beatType)",
            at: CGPoint(x: element.frame.midX, y: element.frame.minY + element.frame.height * 0.72 - digitInset),
            color: color,
            size: size
        )
    }

    private func isVisible(_ frame: CGRect, padding: CGFloat = 72) -> Bool {
        guard let visibleRect else {
            return true
        }
        return frame.intersects(visibleRect.insetBy(dx: -padding, dy: -padding))
    }

    private func smuflDigits(_ value: Int) -> String {
        String(value).compactMap { character -> String? in
            guard let digit = character.wholeNumberValue else {
                return nil
            }
            return SMuFLGlyph.timeSignatureDigit(digit).string
        }
        .joined()
    }

    private func accidentalGlyphString(for accidental: String) -> String {
        guard let glyph = SMuFLGlyph.accidental(for: accidental), smuflFontName != nil else {
            return accidentalSymbol(for: accidental)
        }
        return glyph.string
    }

    private func accidentalGlyphFontName(for accidental: String) -> String? {
        SMuFLGlyph.accidental(for: accidental) == nil ? nil : smuflFontName
    }

    private func flagGlyph(for noteValue: NoteValueKind) -> SMuFLGlyph? {
        switch noteValue {
        case .eighth:
            .flagEighthUp
        case .sixteenth:
            .flagSixteenthUp
        case .thirtySecond:
            .flagThirtySecondUp
        case .whole, .half, .quarter, .other:
            nil
        }
    }

    private func flagGlyphAnchor(
        element: ElementLayout,
        noteLayout: NoteLayout,
        drawsDown: Bool
    ) -> CGPoint {
        let stemEndY = drawsDown ? element.frame.maxY : element.frame.minY
        // Flag frames are defined with their connecting edge on the stem: minX for
        // up-stems and maxX for down-stems. Preserve that attachment even though
        // stem geometry itself now aligns to the notehead's outer edge.
        let stemX = drawsDown ? element.frame.maxX : element.frame.minX
        // ScoreDrawingContext draws SMuFL glyphs centered on this point. The small x
        // offset places the visual leading edge of the flag on the stem instead of
        // placing the glyph center on the stem, which makes the flag look detached.
        let visualStemEdgeOffset = noteLayout.noteheadFrame.width * 0.2
        let verticalAdjustment = noteLayout.noteheadFrame.height * 0.97 * (drawsDown ? -1 : 1)
        return CGPoint(
            x: stemX + visualStemEdgeOffset,
            y: stemEndY + verticalAdjustment
        )
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
        case .thirtySecond:
            3
        case .whole, .half, .quarter, .other:
            0
        }
    }
}

final class CoreGraphicsScoreDrawingContext: ScoreDrawingContext {
    private let context: CGContext
    private var textLineCache: [TextLineCacheKey: CachedTextLine] = [:]

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

    func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: start)
        context.addQuadCurve(to: end, control: control)
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

    func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?) {
        drawText(
            text,
            at: point,
            color: color,
            size: size,
            fontName: fontName,
            mirroredHorizontally: false,
            mirroredVertically: false
        )
    }

    func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?, mirroredHorizontally: Bool, mirroredVertically: Bool) {
        let key = TextLineCacheKey(text: text, color: color, size: size, fontName: fontName)
        let cached = cachedTextLine(for: key)
        let line = cached.line
        let bounds = cached.bounds
        context.saveGState()
        context.textMatrix = .identity
        let textScale = Self.coreTextDrawingScale(
            context: context,
            mirroredHorizontally: mirroredHorizontally,
            mirroredVertically: mirroredVertically
        )
        context.translateBy(x: point.x, y: point.y)
        context.scaleBy(x: textScale.x, y: textScale.y)
        context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    static func coreTextDrawingScale(
        context: CGContext,
        mirroredHorizontally: Bool,
        mirroredVertically: Bool
    ) -> CGPoint {
        let contextYScale: CGFloat = context.ctm.d < 0 ? -1 : 1
        return CGPoint(
            x: mirroredHorizontally ? -1 : 1,
            y: contextYScale * (mirroredVertically ? -1 : 1)
        )
    }

    private func cachedTextLine(for key: TextLineCacheKey) -> CachedTextLine {
        if let cached = textLineCache[key] {
            return cached
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: key.color.cgColor,
            .font: CTFontCreateWithName((key.fontName ?? "Helvetica") as CFString, key.size, nil),
        ]
        let attributed = NSAttributedString(string: key.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let cached = CachedTextLine(
            line: line,
            bounds: CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        )
        textLineCache[key] = cached
        return cached
    }

    private struct TextLineCacheKey: Hashable {
        let text: String
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
        let size: CGFloat
        let fontName: String?

        init(text: String, color: ScoreColor, size: CGFloat, fontName: String?) {
            self.text = text
            self.red = Int((color.red * 255).rounded())
            self.green = Int((color.green * 255).rounded())
            self.blue = Int((color.blue * 255).rounded())
            self.alpha = Int((color.alpha * 255).rounded())
            self.size = (size * 10).rounded() / 10
            self.fontName = fontName
        }

        var color: ScoreColor {
            ScoreColor(
                red: Double(red) / 255,
                green: Double(green) / 255,
                blue: Double(blue) / 255,
                alpha: Double(alpha) / 255
            )
        }
    }

    private struct CachedTextLine {
        let line: CTLine
        let bounds: CGRect
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
