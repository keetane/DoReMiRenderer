import SwiftUI

public struct ScoreCanvasView: View {
    public let layout: ScoreLayout
    public let score: ScoreDocument
    public let style: ScoreStyle
    public let selection: ScoreSelection?
    public let currentNoteIDs: Set<NoteID>
    public let continuationNoteIDs: Set<NoteID>
    public let scale: CGFloat
    public let contentOffset: CGPoint
    public let viewportSize: CGSize
    public let scrollAxes: Axis.Set
    public let followsCurrentNote: Bool
    public let scrollFollowMargin: CGFloat
    public let onTap: ((HitTestResult) -> Void)?

    @State private var lastScrollFollowCenter: CGPoint?
    @State private var lastScrollFollowScale: CGFloat = 1
    @State private var measuredNoteFrames: [NoteID: CGRect] = [:]

    public init(
        layout: ScoreLayout,
        score: ScoreDocument = ScoreDocument(parts: []),
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteID: NoteID? = nil,
        continuationNoteIDs: Set<NoteID> = [],
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        onTap: ((HitTestResult) -> Void)? = nil
    ) {
        self.init(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            currentNoteIDs: currentNoteID.map { [$0] } ?? [],
            continuationNoteIDs: continuationNoteIDs,
            scale: scale,
            contentOffset: contentOffset,
            viewportSize: viewportSize,
            scrollAxes: scrollAxes,
            followsCurrentNote: followsCurrentNote,
            scrollFollowMargin: scrollFollowMargin,
            onTap: onTap
        )
    }

    public init(
        layout: ScoreLayout,
        score: ScoreDocument = ScoreDocument(parts: []),
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteIDs: Set<NoteID>,
        continuationNoteIDs: Set<NoteID> = [],
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        onTap: ((HitTestResult) -> Void)? = nil
    ) {
        self.layout = layout
        self.score = score
        self.style = style
        self.selection = selection
        self.currentNoteIDs = currentNoteIDs
        self.continuationNoteIDs = continuationNoteIDs
        self.scale = max(scale, ScoreViewportTransform.minimumScale)
        self.contentOffset = contentOffset
        self.viewportSize = viewportSize
        self.scrollAxes = scrollAxes
        self.followsCurrentNote = followsCurrentNote
        self.scrollFollowMargin = max(0, scrollFollowMargin)
        self.onTap = onTap
    }

    public var body: some View {
        if scrollAxes.isEmpty {
            canvasContent
        } else {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(scrollAxes) {
                        scrollableCanvasContent
                    }
                    .coordinateSpace(name: ScoreCanvasScrollCoordinateSpace.name)
                    .onPreferenceChange(ScoreCanvasNoteFramePreferenceKey.self) { frames in
                        measuredNoteFrames = frames
                    }
                    .onAppear {
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
                    }
                    .onChange(of: currentFollowNoteID) { _, _ in
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: currentNoteIDs) { _, _ in
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: continuationNoteIDs) { _, _ in
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: scale) { _, _ in
                        lastScrollFollowCenter = nil
                        lastScrollFollowScale = scale
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
                    }
                    .onChange(of: layout.canvasSize) { _, _ in
                        lastScrollFollowCenter = nil
                        scrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
                    }
                }
            }
        }
    }

    private var transform: ScoreViewportTransform {
        ScoreViewportTransform(
            scale: scale,
            contentOffset: contentOffset,
            viewportSize: viewportSize,
            contentSize: layout.canvasSize
        )
    }

    private var canvasContent: some View {
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            var drawingContext = SwiftUICanvasScoreDrawingContext(context: context)
            ScorePainter().draw(
                layout: layout,
                score: score,
                style: style,
                selection: selection,
                currentNoteIDs: currentNoteIDs,
                continuationNoteIDs: continuationNoteIDs,
                into: &drawingContext
            )
            context = drawingContext.context
        }
        .frame(width: transform.scaledContentSize.width, height: transform.scaledContentSize.height)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    let layoutPoint = transform.layoutPoint(fromViewPoint: value.location)
                    onTap?(layout.hitTest(point: layoutPoint, radius: 18 / scale))
                }
        )
    }

    private var scrollableCanvasContent: some View {
        ZStack(alignment: .topLeading) {
            scrollableCanvas
            noteMeasurementAnchors
            measureFollowAnchors
        }
        .frame(width: scrollableContentSize.width, height: scrollableContentSize.height)
    }

    private var scrollContentPadding: CGFloat {
        ScoreCanvasFollowHeuristics.scrollContentPadding(scale: scale, margin: scrollFollowMargin)
    }

    private var scrollableContentSize: CGSize {
        ScoreCanvasFollowHeuristics.scrollableContentSize(
            canvasSize: layout.canvasSize,
            scale: scale,
            margin: scrollFollowMargin
        )
    }

    private var scrollableCanvas: some View {
        Canvas { context, _ in
            context.translateBy(x: scrollContentPadding, y: scrollContentPadding)
            context.scaleBy(x: scale, y: scale)
            var drawingContext = SwiftUICanvasScoreDrawingContext(context: context)
            ScorePainter().draw(
                layout: layout,
                score: score,
                style: style,
                selection: selection,
                currentNoteIDs: currentNoteIDs,
                continuationNoteIDs: continuationNoteIDs,
                into: &drawingContext
            )
            context = drawingContext.context
        }
        .frame(width: scrollableContentSize.width, height: scrollableContentSize.height)
        .contentShape(Rectangle())
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    let localPoint = CGPoint(
                        x: value.location.x - scrollContentPadding,
                        y: value.location.y - scrollContentPadding
                    )
                    let layoutPoint = CGPoint(x: localPoint.x / scale, y: localPoint.y / scale)
                    onTap?(layout.hitTest(point: layoutPoint, radius: 18 / scale))
                }
        )
    }

    @ViewBuilder
    private var noteMeasurementAnchors: some View {
        ForEach(layout.noteByID.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { noteID in
            if let noteLayout = layout.noteByID[noteID] {
                let anchorX = scrollContentPadding + noteLayout.noteheadFrame.minX * scale
                let anchorY = scrollContentPadding + noteLayout.noteheadFrame.minY * scale
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: anchorY)
                        .frame(height: anchorY)
                    HStack(alignment: .top, spacing: 0) {
                        Spacer(minLength: anchorX)
                            .frame(width: anchorX)
                        Color.clear
                            .frame(
                                width: max(1, noteLayout.noteheadFrame.width * scale),
                                height: max(1, noteLayout.noteheadFrame.height * scale)
                            )
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: ScoreCanvasNoteFramePreferenceKey.self,
                                        value: [noteID: proxy.frame(in: .named(ScoreCanvasScrollCoordinateSpace.name))]
                                    )
                                }
                            )
                            .id(ScoreCanvasScrollAnchor(noteID: noteID, kind: .notehead))
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(
                    width: scrollableContentSize.width,
                    height: scrollableContentSize.height,
                    alignment: .topLeading
                )
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var measureFollowAnchors: some View {
        ForEach(layout.noteByID.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { noteID in
            if let noteLayout = layout.noteByID[noteID] {
                let anchorX = scrollContentPadding + ScoreCanvasFollowHeuristics.measureLeadingX(
                    for: noteLayout,
                    in: layout
                ) * scale
                let anchorY = scrollContentPadding + noteLayout.noteheadFrame.minY * scale
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: anchorY)
                        .frame(height: anchorY)
                    HStack(alignment: .top, spacing: 0) {
                        Spacer(minLength: anchorX)
                            .frame(width: anchorX)
                        Color.clear
                            .frame(
                                width: max(1, noteLayout.noteheadFrame.width * scale),
                                height: max(1, noteLayout.noteheadFrame.height * scale)
                            )
                            .id(ScoreCanvasScrollAnchor(noteID: noteID, kind: .measureLeading))
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(
                    width: scrollableContentSize.width,
                    height: scrollableContentSize.height,
                    alignment: .topLeading
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var currentFollowNoteID: NoteID? {
        guard followsCurrentNote else {
            return nil
        }
        if let attack = currentNoteIDs.sorted(by: { $0.rawValue < $1.rawValue }).first {
            return attack
        }
        return continuationNoteIDs.sorted { $0.rawValue < $1.rawValue }.first
    }

    private func effectiveViewportSize(_ geometrySize: CGSize) -> CGSize {
        viewportSize == .zero ? geometrySize : viewportSize
    }

    private func scrollToCurrentNote(with proxy: ScrollViewProxy, viewportSize: CGSize, force: Bool = false) {
        guard let noteID = currentFollowNoteID,
              let noteLayout = layout.noteByID[noteID],
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return
        }
        let movedBeyondLastFollow = ScoreCanvasFollowHeuristics.hasMovedBeyondFollowDistance(
            noteCenter: noteLayout.noteheadCenter,
            lastFollowCenter: lastScrollFollowCenter,
            viewportSize: viewportSize,
            scale: scale,
            margin: scrollFollowMargin
        )
        var scrollAnchor = ScoreCanvasFollowHeuristics.scrollAnchorForLayoutMovement(
            noteCenter: noteLayout.noteheadCenter,
            lastFollowCenter: lastScrollFollowCenter
        )
        if !force,
           let measuredFrame = measuredNoteFrames[noteID],
           ScoreCanvasFollowHeuristics.isFrameVisible(
               measuredFrame,
               viewportSize: viewportSize,
               margin: scrollFollowMargin
           ),
           !movedBeyondLastFollow {
            return
        }
        if let measuredFrame = measuredNoteFrames[noteID] {
            let measuredAnchor = ScoreCanvasFollowHeuristics.scrollAnchor(
                for: measuredFrame,
                viewportSize: viewportSize,
                margin: scrollFollowMargin
            )
            scrollAnchor = measuredAnchor == .center && movedBeyondLastFollow ? scrollAnchor : measuredAnchor
        }

        lastScrollFollowCenter = noteLayout.noteheadCenter
        lastScrollFollowScale = scale
        let targetAnchor = ScoreCanvasScrollAnchor(noteID: noteID, kind: .measureLeading)
        let measureLeadingAnchor = UnitPoint(x: 0, y: scrollAnchor.y)
        let animation: Animation? = force ? .easeInOut(duration: 0.16) : .linear(duration: 0.10)
        if let animation {
            withAnimation(animation) {
                proxy.scrollTo(targetAnchor, anchor: measureLeadingAnchor)
            }
        } else {
            proxy.scrollTo(targetAnchor, anchor: measureLeadingAnchor)
        }
    }
}

private struct ScoreCanvasScrollAnchor: Hashable {
    enum Kind: Hashable {
        case notehead
        case measureLeading
    }

    let noteID: NoteID
    let kind: Kind
}

private enum ScoreCanvasScrollCoordinateSpace {
    static let name = "DoReMiRendererKit.ScoreCanvasView.scroll"
}

private struct ScoreCanvasNoteFramePreferenceKey: PreferenceKey {
    static let defaultValue: [NoteID: CGRect] = [:]

    static func reduce(value: inout [NoteID: CGRect], nextValue: () -> [NoteID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ScoreCanvasFollowHeuristics {
    static func scrollContentPadding(scale: CGFloat, margin: CGFloat) -> CGFloat {
        max(max(margin, 0), 64) * max(scale, ScoreViewportTransform.minimumScale)
    }

    static func scrollableContentSize(canvasSize: CGSize, scale: CGFloat, margin: CGFloat) -> CGSize {
        let effectiveScale = max(scale, ScoreViewportTransform.minimumScale)
        let padding = scrollContentPadding(scale: effectiveScale, margin: margin)
        return CGSize(
            width: max(1, canvasSize.width * effectiveScale + padding * 2),
            height: max(1, canvasSize.height * effectiveScale + padding * 2)
        )
    }

    static func measureLeadingX(for noteLayout: NoteLayout, in layout: ScoreLayout) -> CGFloat {
        guard let measureID = noteLayout.measureID,
              let measure = layout.measures.first(where: { $0.measureID == measureID }) else {
            return noteLayout.noteheadFrame.minX
        }
        return measure.frame.minX
    }

    static func isFrameVisible(_ frame: CGRect, viewportSize: CGSize, margin: CGFloat) -> Bool {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return false
        }
        let safeMarginX = min(max(margin, 0), viewportSize.width * 0.35)
        let safeMarginY = min(max(margin, 0), viewportSize.height * 0.35)
        let safeRect = CGRect(origin: .zero, size: viewportSize).insetBy(dx: safeMarginX, dy: safeMarginY)
        return safeRect.contains(frame)
    }

    static func scrollAnchor(for frame: CGRect, viewportSize: CGSize, margin: CGFloat) -> UnitPoint {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return .center
        }
        let safeMarginX = min(max(margin, 0), viewportSize.width * 0.35)
        let safeMarginY = min(max(margin, 0), viewportSize.height * 0.35)

        let x: CGFloat
        if frame.minX < safeMarginX {
            x = 0
        } else if frame.maxX > viewportSize.width - safeMarginX {
            x = 1
        } else {
            x = 0.5
        }

        let y: CGFloat
        if frame.minY < safeMarginY {
            y = 0
        } else if frame.maxY > viewportSize.height - safeMarginY {
            y = 1
        } else {
            y = 0.5
        }

        return UnitPoint(x: x, y: y)
    }

    static func hasMovedBeyondFollowDistance(
        noteCenter: CGPoint,
        lastFollowCenter: CGPoint?,
        viewportSize: CGSize,
        scale: CGFloat,
        margin: CGFloat
    ) -> Bool {
        guard let lastFollowCenter,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return true
        }
        let effectiveScale = max(scale, ScoreViewportTransform.minimumScale)
        let dx = abs(noteCenter.x - lastFollowCenter.x) * effectiveScale
        let dy = abs(noteCenter.y - lastFollowCenter.y) * effectiveScale
        let safeMargin = max(margin, 0)
        let horizontalThreshold = max(safeMargin * 2, viewportSize.width * 0.42)
        let verticalThreshold = max(safeMargin * 2, viewportSize.height * 0.42)
        return dx > horizontalThreshold || dy > verticalThreshold
    }

    static func scrollAnchorForLayoutMovement(noteCenter: CGPoint, lastFollowCenter: CGPoint?) -> UnitPoint {
        guard let lastFollowCenter else {
            return .center
        }
        let horizontalDelta = noteCenter.x - lastFollowCenter.x
        let verticalDelta = noteCenter.y - lastFollowCenter.y
        let x: CGFloat
        if horizontalDelta > 0 {
            x = 0.72
        } else if horizontalDelta < 0 {
            x = 0.28
        } else {
            x = 0.5
        }
        let y: CGFloat
        if verticalDelta > 0 {
            y = 0.68
        } else if verticalDelta < 0 {
            y = 0.32
        } else {
            y = 0.5
        }
        return UnitPoint(x: x, y: y)
    }

    static func shouldScroll(
        noteFrame: CGRect,
        noteCenter: CGPoint,
        lastFollowCenter: CGPoint?,
        viewportSize: CGSize,
        margin: CGFloat
    ) -> Bool {
        guard let center = lastFollowCenter,
              viewportSize.width > 0,
              viewportSize.height > 0
        else {
            return true
        }

        let safeMarginX = min(max(margin, 0), viewportSize.width * 0.35)
        let safeMarginY = min(max(margin, 0), viewportSize.height * 0.35)
        let comfortRect = CGRect(
            x: center.x - viewportSize.width / 2 + safeMarginX,
            y: center.y - viewportSize.height / 2 + safeMarginY,
            width: max(1, viewportSize.width - safeMarginX * 2),
            height: max(1, viewportSize.height - safeMarginY * 2)
        )
        if !comfortRect.contains(noteFrame) {
            return true
        }

        let horizontalThreshold = max(24, viewportSize.width * 0.28)
        let verticalThreshold = max(18, viewportSize.height * 0.28)
        return abs(noteCenter.x - center.x) > horizontalThreshold ||
            abs(noteCenter.y - center.y) > verticalThreshold
    }
}

internal struct SwiftUICanvasScoreDrawingContext: ScoreDrawingContext {
    var context: GraphicsContext

    mutating func fill(_ rect: CGRect, color: ScoreColor) {
        context.fill(Path(rect), with: .color(Color(scoreColor: color)))
    }

    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(Color(scoreColor: color)), lineWidth: lineWidth)
    }

    mutating func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(path, with: .color(Color(scoreColor: color)), lineWidth: lineWidth)
    }

    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {
        context.fill(Path(ellipseIn: rect), with: .color(Color(scoreColor: color)))
    }

    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        context.stroke(Path(ellipseIn: rect), with: .color(Color(scoreColor: color)), lineWidth: lineWidth)
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?) {
        let font: Font = if let fontName {
            .custom(fontName, size: size)
        } else {
            .system(size: size)
        }
        context.draw(
            Text(text).font(font).foregroundStyle(Color(scoreColor: color)),
            at: point,
            anchor: .center
        )
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?, mirroredHorizontally: Bool, mirroredVertically: Bool) {
        guard mirroredHorizontally || mirroredVertically else {
            drawText(text, at: point, color: color, size: size, fontName: fontName)
            return
        }
        let font: Font = if let fontName {
            .custom(fontName, size: size)
        } else {
            .system(size: size)
        }
        context.translateBy(x: point.x, y: point.y)
        context.scaleBy(x: mirroredHorizontally ? -1 : 1, y: mirroredVertically ? -1 : 1)
        context.draw(
            Text(text).font(font).foregroundStyle(Color(scoreColor: color)),
            at: .zero,
            anchor: .center
        )
        context.scaleBy(x: mirroredHorizontally ? -1 : 1, y: mirroredVertically ? -1 : 1)
        context.translateBy(x: -point.x, y: -point.y)
    }
}

private extension Color {
    init(scoreColor: ScoreColor) {
        self.init(
            .sRGB,
            red: scoreColor.red,
            green: scoreColor.green,
            blue: scoreColor.blue,
            opacity: scoreColor.alpha
        )
    }
}
