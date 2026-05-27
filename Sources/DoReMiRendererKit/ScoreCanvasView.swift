import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ScoreCanvasView: View {
    public let layout: ScoreLayout
    public let score: ScoreDocument
    public let style: ScoreStyle
    public let selection: ScoreSelection?
    public let currentNoteIDs: Set<NoteID>
    public let continuationNoteIDs: Set<NoteID>
    public let followNoteIDs: Set<NoteID>?
    public let scale: CGFloat
    public let contentOffset: CGPoint
    public let viewportSize: CGSize
    public let scrollAxes: Axis.Set
    public let followsCurrentNote: Bool
    public let scrollFollowMargin: CGFloat
    public let staticRenderKey: String?
    public let onTap: ((HitTestResult) -> Void)?

    @State private var lastScrollFollowCenter: CGPoint?
    @State private var lastScrollFollowScale: CGFloat = 1
    @State private var pendingScrollFollowTask: Task<Void, Never>?

    public init(
        layout: ScoreLayout,
        score: ScoreDocument = ScoreDocument(parts: []),
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteID: NoteID? = nil,
        continuationNoteIDs: Set<NoteID> = [],
        followNoteIDs: Set<NoteID>? = nil,
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        staticRenderKey: String? = nil,
        onTap: ((HitTestResult) -> Void)? = nil
    ) {
        self.init(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            currentNoteIDs: currentNoteID.map { [$0] } ?? [],
            continuationNoteIDs: continuationNoteIDs,
            followNoteIDs: followNoteIDs,
            scale: scale,
            contentOffset: contentOffset,
            viewportSize: viewportSize,
            scrollAxes: scrollAxes,
            followsCurrentNote: followsCurrentNote,
            scrollFollowMargin: scrollFollowMargin,
            staticRenderKey: staticRenderKey,
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
        followNoteIDs: Set<NoteID>? = nil,
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        staticRenderKey: String? = nil,
        onTap: ((HitTestResult) -> Void)? = nil
    ) {
        self.layout = layout
        self.score = score
        self.style = style
        self.selection = selection
        self.currentNoteIDs = currentNoteIDs
        self.continuationNoteIDs = continuationNoteIDs
        self.followNoteIDs = followNoteIDs
        self.scale = max(scale, ScoreViewportTransform.minimumScale)
        self.contentOffset = contentOffset
        self.viewportSize = viewportSize
        self.scrollAxes = scrollAxes
        self.followsCurrentNote = followsCurrentNote
        self.scrollFollowMargin = max(0, scrollFollowMargin)
        self.staticRenderKey = staticRenderKey
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
                    .onAppear {
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
                    }
                    .onChange(of: currentFollowNoteID) { _, _ in
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: followNoteIDs) { _, _ in
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: currentNoteIDs) { _, _ in
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: continuationNoteIDs) { _, _ in
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: scale) { _, _ in
                        lastScrollFollowCenter = nil
                        lastScrollFollowScale = scale
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
                    }
                    .onChange(of: layout.canvasSize) { _, _ in
                        lastScrollFollowCenter = nil
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size), force: true)
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
        ZStack(alignment: .topLeading) {
            ScoreStaticCanvasLayer(
                layout: layout,
                score: score,
                style: style,
                selection: nil,
                scale: scale,
                padding: 0,
                contentSize: transform.scaledContentSize,
                renderKey: staticCanvasRenderKey
            )
            .equatable()
            highlightOverlay(padding: 0)
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
            measureFollowAnchors
            currentFollowAnchors
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
        ZStack(alignment: .topLeading) {
            ScoreStaticCanvasLayer(
                layout: layout,
                score: score,
                style: style,
                selection: nil,
                scale: scale,
                padding: scrollContentPadding,
                contentSize: scrollableContentSize,
                renderKey: staticCanvasRenderKey
            )
            .equatable()
            highlightOverlay(padding: scrollContentPadding)
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

    private var staticCanvasRenderKey: String {
        var hasher = Hasher()
        hasher.combine(Int(layout.canvasSize.width.rounded()))
        hasher.combine(Int(layout.canvasSize.height.rounded()))
        hasher.combine(layout.systems.count)
        hasher.combine(layout.staves.count)
        hasher.combine(layout.measures.count)
        hasher.combine(layout.elements.count)
        hasher.combine(layout.staffLines.count)
        hasher.combine(layout.ledgerLines.count)
        hasher.combine(layout.noteByID.count)
        for measure in layout.measures.prefix(12) {
            hasher.combine(measure.measureID)
            hasher.combine(Int(measure.frame.minX.rounded()))
            hasher.combine(Int(measure.frame.width.rounded()))
        }
        for measure in layout.measures.suffix(12) {
            hasher.combine(measure.measureID)
            hasher.combine(Int(measure.frame.minX.rounded()))
            hasher.combine(Int(measure.frame.width.rounded()))
        }
        for element in layout.elements.prefix(24) {
            hasher.combine(element.id)
            hasher.combine(element.kind)
            hasher.combine(Int(element.frame.minX.rounded()))
            hasher.combine(Int(element.frame.minY.rounded()))
        }
        for element in layout.elements.suffix(24) {
            hasher.combine(element.id)
            hasher.combine(element.kind)
            hasher.combine(Int(element.frame.minX.rounded()))
            hasher.combine(Int(element.frame.minY.rounded()))
        }
        if let staticRenderKey {
            hasher.combine(staticRenderKey)
        } else {
            hasher.combine(String(reflecting: style.backgroundColor))
            hasher.combine(String(reflecting: style.defaultInkColor))
            hasher.combine(String(reflecting: style.staffLineStyle))
            hasher.combine(String(reflecting: style.noteColorStyle))
            hasher.combine(String(reflecting: style.ledgerLineStyle))
            hasher.combine(String(reflecting: style.accidentalStyle))
            hasher.combine(String(reflecting: style.glyphStyle))
            hasher.combine(String(reflecting: style.measureNumberDisplayMode))
        }
        return String(hasher.finalize())
    }

    private func highlightOverlay(padding: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(continuationHighlightRects(padding: padding), id: \.id) { highlight in
                Ellipse()
                    .fill(Color(scoreColor: highlight.fillColor))
                    .overlay(
                        Ellipse()
                            .stroke(Color(scoreColor: highlight.strokeColor), lineWidth: highlight.strokeWidth)
                    )
                    .frame(width: highlight.frame.width, height: highlight.frame.height)
                    .position(x: highlight.frame.midX, y: highlight.frame.midY)
            }
            ForEach(currentHighlightBarRects(padding: padding), id: \.id) { highlight in
                Rectangle()
                    .fill(Color(scoreColor: highlight.color))
                    .frame(width: highlight.frame.width, height: highlight.frame.height)
                    .position(x: highlight.frame.midX, y: highlight.frame.midY)
            }
        }
        .frame(width: padding == 0 ? transform.scaledContentSize.width : scrollableContentSize.width,
               height: padding == 0 ? transform.scaledContentSize.height : scrollableContentSize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct CurrentHighlightBar {
        let id: String
        let frame: CGRect
        let color: ScoreColor
    }

    private struct ContinuationHighlight {
        let id: NoteID
        let frame: CGRect
        let fillColor: ScoreColor
        let strokeColor: ScoreColor
        let strokeWidth: CGFloat
    }

    private func currentHighlightBarRects(padding: CGFloat) -> [CurrentHighlightBar] {
        let color = ScoreColor(red: 0.08, green: 0.72, blue: 1, alpha: 0.78)
        var drawnBarKeys: Set<String> = []
        var bars: [CurrentHighlightBar] = []
        for noteID in currentNoteIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
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
            let scaledFrame = CGRect(
                x: padding + x * scale,
                y: padding + y * scale,
                width: width * scale,
                height: height * scale
            )
            bars.append(CurrentHighlightBar(id: barKey, frame: scaledFrame, color: color))
        }
        return bars
    }

    private func continuationHighlightRects(padding: CGFloat) -> [ContinuationHighlight] {
        let base = style.highlightStyle.color
        let fill = ScoreColor(red: base.red, green: base.green, blue: base.blue, alpha: min(base.alpha, 0.14))
        let stroke = ScoreColor(red: base.red, green: base.green, blue: base.blue, alpha: min(max(base.alpha, 0.28), 0.42))
        return continuationNoteIDs
            .subtracting(currentNoteIDs)
            .sorted(by: { $0.rawValue < $1.rawValue })
            .compactMap { noteID in
                guard let noteLayout = layout.noteLayout(for: noteID) else {
                    return nil
                }
                let frame = noteLayout.noteheadFrame.insetBy(dx: -6, dy: -6)
                let scaledFrame = CGRect(
                    x: padding + frame.minX * scale,
                    y: padding + frame.minY * scale,
                    width: frame.width * scale,
                    height: frame.height * scale
                )
                return ContinuationHighlight(
                    id: noteID,
                    frame: scaledFrame,
                    fillColor: fill,
                    strokeColor: stroke,
                    strokeWidth: 1.5
                )
            }
    }

    @ViewBuilder
    private var measureFollowAnchors: some View {
        ForEach(layout.measures, id: \.measureID) { measure in
            let anchor = measureFollowAnchorPoint(for: measure)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: anchor.y)
                    .frame(height: anchor.y)
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: anchor.x)
                        .frame(width: anchor.x)
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(ScoreCanvasMeasureScrollAnchor(measureID: measure.measureID))
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

    private func measureFollowAnchorPoint(for measure: MeasureLayout) -> CGPoint {
        let firstNoteInMeasure = layout.noteByID.values
            .filter { $0.measureID == measure.measureID }
            .min { lhs, rhs in
                if lhs.noteheadFrame.minX == rhs.noteheadFrame.minX {
                    return lhs.noteheadFrame.minY < rhs.noteheadFrame.minY
                }
                return lhs.noteheadFrame.minX < rhs.noteheadFrame.minX
            }
        let layoutX: CGFloat
        let layoutY: CGFloat
        if let firstNoteInMeasure {
            layoutX = ScoreCanvasFollowHeuristics.measureLeadingX(for: firstNoteInMeasure, in: layout)
            layoutY = firstNoteInMeasure.noteheadFrame.minY
        } else {
            layoutX = measure.frame.minX
            layoutY = measure.frame.minY
        }
        return CGPoint(
            x: scrollContentPadding + layoutX * scale,
            y: scrollContentPadding + layoutY * scale
        )
    }

    @ViewBuilder
    private var currentFollowAnchors: some View {
        if let noteID = currentFollowNoteID,
           let noteLayout = layout.noteByID[noteID] {
            followAnchor(
                noteID: noteID,
                noteLayout: noteLayout,
                kind: .notehead,
                x: noteLayout.noteheadFrame.minX,
                y: noteLayout.noteheadFrame.minY
            )
            followAnchor(
                noteID: noteID,
                noteLayout: noteLayout,
                kind: .measureLeading,
                x: ScoreCanvasFollowHeuristics.measureLeadingX(for: noteLayout, in: layout),
                y: noteLayout.noteheadFrame.minY
            )
        }
    }

    private func followAnchor(
        noteID: NoteID,
        noteLayout: NoteLayout,
        kind: ScoreCanvasScrollAnchor.Kind,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Color.clear
            .frame(
                width: max(1, noteLayout.noteheadFrame.width * scale),
                height: max(1, noteLayout.noteheadFrame.height * scale)
            )
            .position(
                x: scrollContentPadding + x * scale + max(1, noteLayout.noteheadFrame.width * scale) / 2,
                y: scrollContentPadding + y * scale + max(1, noteLayout.noteheadFrame.height * scale) / 2
            )
            .id(ScoreCanvasScrollAnchor(noteID: noteID, kind: kind))
            .allowsHitTesting(false)
    }

    private var currentFollowNoteID: NoteID? {
        guard followsCurrentNote else {
            return nil
        }
        if let followNoteIDs,
           let follow = followNoteIDs.sorted(by: { $0.rawValue < $1.rawValue }).first {
            return follow
        }
        if let attack = currentNoteIDs.sorted(by: { $0.rawValue < $1.rawValue }).first {
            return attack
        }
        return continuationNoteIDs.sorted { $0.rawValue < $1.rawValue }.first
    }

    private func effectiveViewportSize(_ geometrySize: CGSize) -> CGSize {
        viewportSize == .zero ? geometrySize : viewportSize
    }

    private func scheduleScrollToCurrentNote(
        with proxy: ScrollViewProxy,
        viewportSize: CGSize,
        force: Bool = false
    ) {
        pendingScrollFollowTask?.cancel()
        pendingScrollFollowTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            scrollToCurrentNote(with: proxy, viewportSize: viewportSize, force: force)
        }
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
        let currentFrame = ScoreCanvasFollowHeuristics.frame(
            for: noteLayout,
            scale: scale,
            padding: scrollContentPadding
        )
        if !force,
           ScoreCanvasFollowHeuristics.isFrameVisible(
               currentFrame,
               viewportSize: viewportSize,
               margin: scrollFollowMargin
           ),
           !movedBeyondLastFollow {
            return
        }
        let measuredAnchor = ScoreCanvasFollowHeuristics.scrollAnchor(
            for: currentFrame,
            viewportSize: viewportSize,
            margin: scrollFollowMargin
        )
        scrollAnchor = measuredAnchor == .center && movedBeyondLastFollow ? scrollAnchor : measuredAnchor

        lastScrollFollowCenter = noteLayout.noteheadCenter
        lastScrollFollowScale = scale
        let measureLeadingAnchor = UnitPoint(x: 0, y: scrollAnchor.y)
        let animation: Animation? = force ? .easeInOut(duration: 0.16) : nil
        if let measureID = noteLayout.measureID {
            let targetAnchor = ScoreCanvasMeasureScrollAnchor(measureID: measureID)
            if let animation {
                withAnimation(animation) {
                    proxy.scrollTo(targetAnchor, anchor: measureLeadingAnchor)
                }
            } else {
                proxy.scrollTo(targetAnchor, anchor: measureLeadingAnchor)
            }
            return
        }
        let targetAnchor = ScoreCanvasScrollAnchor(noteID: noteID, kind: .measureLeading)
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

private struct ScoreCanvasMeasureScrollAnchor: Hashable {
    let measureID: MeasureID
}

private enum ScoreCanvasScrollCoordinateSpace {
    static let name = "DoReMiRendererKit.ScoreCanvasView.scroll"
}

private struct ScoreStaticCanvasLayer: View, Equatable {
    let layout: ScoreLayout
    let score: ScoreDocument
    let style: ScoreStyle
    let selection: ScoreSelection?
    let scale: CGFloat
    let padding: CGFloat
    let contentSize: CGSize
    let renderKey: String

    nonisolated static func == (lhs: ScoreStaticCanvasLayer, rhs: ScoreStaticCanvasLayer) -> Bool {
        lhs.renderKey == rhs.renderKey
            && lhs.scale == rhs.scale
            && lhs.padding == rhs.padding
            && lhs.contentSize == rhs.contentSize
    }

    var body: some View {
#if canImport(UIKit)
        if Self.usesPlatformStaticCanvas {
            ScoreStaticCanvasRepresentable(
                layout: layout,
                score: score,
                style: style,
                selection: selection,
                scale: scale,
                padding: padding,
                contentSize: contentSize,
                renderKey: renderKey
            )
        } else {
            swiftUICanvasLayer
        }
#else
        swiftUICanvasLayer
#endif
    }

    private var swiftUICanvasLayer: some View {
        Canvas { context, _ in
            context.translateBy(x: padding, y: padding)
            context.scaleBy(x: scale, y: scale)
            var drawingContext = SwiftUICanvasScoreDrawingContext(context: context)
            ScorePainter().draw(
                layout: layout,
                score: score,
                style: style,
                selection: selection,
                currentNoteIDs: [],
                continuationNoteIDs: [],
                into: &drawingContext
            )
            context = drawingContext.context
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .accessibilityHidden(true)
    }

    private static var usesPlatformStaticCanvas: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }
}

#if canImport(UIKit)
private struct ScoreStaticCanvasRepresentable: UIViewRepresentable {
    let layout: ScoreLayout
    let score: ScoreDocument
    let style: ScoreStyle
    let selection: ScoreSelection?
    let scale: CGFloat
    let padding: CGFloat
    let contentSize: CGSize
    let renderKey: String

    func makeUIView(context: Context) -> ScoreStaticCanvasUIView {
        let view = ScoreStaticCanvasUIView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.update(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            scale: scale,
            padding: padding,
            contentSize: contentSize,
            renderKey: renderKey
        )
        return view
    }

    func updateUIView(_ uiView: ScoreStaticCanvasUIView, context: Context) {
        uiView.update(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            scale: scale,
            padding: padding,
            contentSize: contentSize,
            renderKey: renderKey
        )
    }
}

private final class ScoreStaticCanvasUIView: UIView {
    private var layout = ScoreLayout()
    private var score = ScoreDocument(parts: [])
    private var style = ScoreStyle()
    private var selection: ScoreSelection?
    private var scoreScale: CGFloat = 1
    private var padding: CGFloat = 0
    private var contentSize: CGSize = .zero
    private var renderKey = ""

    func update(
        layout: ScoreLayout,
        score: ScoreDocument,
        style: ScoreStyle,
        selection: ScoreSelection?,
        scale: CGFloat,
        padding: CGFloat,
        contentSize: CGSize,
        renderKey: String
    ) {
        let needsRedraw = self.renderKey != renderKey
            || self.scoreScale != scale
            || self.padding != padding
            || self.contentSize != contentSize
        self.layout = layout
        self.score = score
        self.style = style
        self.selection = selection
        self.scoreScale = scale
        self.padding = padding
        self.contentSize = contentSize
        self.renderKey = renderKey
        if needsRedraw {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let cgContext = UIGraphicsGetCurrentContext() else {
            return
        }
        cgContext.clip(to: rect)
        let safeScale = max(scoreScale, ScoreViewportTransform.minimumScale)
        let visibleRect = CGRect(
            x: (rect.minX - padding) / safeScale,
            y: (rect.minY - padding) / safeScale,
            width: rect.width / safeScale,
            height: rect.height / safeScale
        )
        cgContext.translateBy(x: padding, y: padding)
        cgContext.scaleBy(x: safeScale, y: safeScale)
        var drawingContext = CoreGraphicsScoreDrawingContext(cgContext)
        ScorePainter(visibleRect: visibleRect).draw(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            currentNoteIDs: [],
            continuationNoteIDs: [],
            into: &drawingContext
        )
    }
}
#endif

private struct ScoreCanvasHighlightPainter: Sendable {
    func draw<Context: ScoreDrawingContext>(
        layout: ScoreLayout,
        style: ScoreStyle,
        currentNoteIDs: Set<NoteID>,
        continuationNoteIDs: Set<NoteID>,
        into context: inout Context
    ) {
        drawContinuationNoteHighlights(
            layout: layout,
            noteIDs: continuationNoteIDs.subtracting(currentNoteIDs),
            style: style,
            into: &context
        )
        drawCurrentNoteBars(layout: layout, noteIDs: currentNoteIDs, into: &context)
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

    static func frame(for noteLayout: NoteLayout, scale: CGFloat, padding: CGFloat) -> CGRect {
        let effectiveScale = max(scale, ScoreViewportTransform.minimumScale)
        return CGRect(
            x: padding + noteLayout.noteheadFrame.minX * effectiveScale,
            y: padding + noteLayout.noteheadFrame.minY * effectiveScale,
            width: max(1, noteLayout.noteheadFrame.width * effectiveScale),
            height: max(1, noteLayout.noteheadFrame.height * effectiveScale)
        )
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
