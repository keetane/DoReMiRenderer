import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum ScoreCanvasFollowPlacement: Sendable, Hashable {
    case center
    case horizontalSmooth
    case topAligned
}

public struct ScoreCanvasView: View {
    public let layout: ScoreLayout
    public let score: ScoreDocument
    public let style: ScoreStyle
    public let selection: ScoreSelection?
    public let currentNoteIDs: Set<NoteID>
    public let continuationNoteIDs: Set<NoteID>
    public let followNoteIDs: Set<NoteID>?
    public let nextFollowNoteIDs: Set<NoteID>
    public let continuousFollowNoteIDs: [NoteID]
    public let scale: CGFloat
    public let contentOffset: CGPoint
    public let viewportSize: CGSize
    public let scrollAxes: Axis.Set
    public let followsCurrentNote: Bool
    public let scrollFollowMargin: CGFloat
    public let followPlacement: ScoreCanvasFollowPlacement
    public let followAnimationDuration: TimeInterval?
    public let continuousFollowPlaybackDuration: TimeInterval?
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
        nextFollowNoteIDs: Set<NoteID> = [],
        continuousFollowNoteIDs: [NoteID] = [],
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        followPlacement: ScoreCanvasFollowPlacement = .center,
        followAnimationDuration: TimeInterval? = nil,
        continuousFollowPlaybackDuration: TimeInterval? = nil,
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
            nextFollowNoteIDs: nextFollowNoteIDs,
            continuousFollowNoteIDs: continuousFollowNoteIDs,
            scale: scale,
            contentOffset: contentOffset,
            viewportSize: viewportSize,
            scrollAxes: scrollAxes,
            followsCurrentNote: followsCurrentNote,
            scrollFollowMargin: scrollFollowMargin,
            followPlacement: followPlacement,
            followAnimationDuration: followAnimationDuration,
            continuousFollowPlaybackDuration: continuousFollowPlaybackDuration,
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
        nextFollowNoteIDs: Set<NoteID> = [],
        continuousFollowNoteIDs: [NoteID] = [],
        scale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero,
        scrollAxes: Axis.Set = [],
        followsCurrentNote: Bool = false,
        scrollFollowMargin: CGFloat = 48,
        followPlacement: ScoreCanvasFollowPlacement = .center,
        followAnimationDuration: TimeInterval? = nil,
        continuousFollowPlaybackDuration: TimeInterval? = nil,
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
        self.nextFollowNoteIDs = nextFollowNoteIDs
        self.continuousFollowNoteIDs = continuousFollowNoteIDs
        self.scale = max(scale, ScoreViewportTransform.minimumScale)
        self.contentOffset = contentOffset
        self.viewportSize = viewportSize
        self.scrollAxes = scrollAxes
        self.followsCurrentNote = followsCurrentNote
        self.scrollFollowMargin = max(0, scrollFollowMargin)
        self.followPlacement = followPlacement
        self.followAnimationDuration = followAnimationDuration
        self.continuousFollowPlaybackDuration = continuousFollowPlaybackDuration
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
                    .defaultScrollAnchor(.topLeading)
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
                    .onChange(of: nextFollowNoteIDs) { _, _ in
                        scheduleScrollToCurrentNote(with: proxy, viewportSize: effectiveViewportSize(geometry.size))
                    }
                    .onChange(of: continuousFollowNoteIDs) { _, _ in
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
#if canImport(UIKit)
            scrollFollowDriver
#endif
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
            layoutY = followPlacement == .topAligned
                ? ScoreCanvasFollowHeuristics.measureTopY(for: measure, in: layout)
                : firstNoteInMeasure.noteheadFrame.minY
        } else {
            layoutX = measure.frame.minX
            layoutY = followPlacement == .topAligned
                ? ScoreCanvasFollowHeuristics.measureTopY(for: measure, in: layout)
                : measure.frame.minY
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

    private var nextFollowNoteID: NoteID? {
        guard followsCurrentNote else {
            return nil
        }
        return nextFollowNoteIDs.sorted(by: { $0.rawValue < $1.rawValue }).first
    }

#if canImport(UIKit)
    private var scrollFollowDriver: some View {
        ScoreCanvasScrollFollowDriver(
            layout: layout,
            currentNoteID: currentFollowNoteID,
            nextNoteID: nextFollowNoteID,
            continuousNoteIDs: continuousFollowNoteIDs,
            followAnimationDuration: followAnimationDuration,
            continuousFollowPlaybackDuration: continuousFollowPlaybackDuration,
            scale: scale,
            padding: scrollContentPadding,
            contentSize: scrollableContentSize,
            placement: followPlacement
        )
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
#endif

    private func effectiveViewportSize(_ geometrySize: CGSize) -> CGSize {
        viewportSize == .zero ? geometrySize : viewportSize
    }

    private func scheduleScrollToCurrentNote(
        with proxy: ScrollViewProxy,
        viewportSize: CGSize,
        force: Bool = false
    ) {
#if canImport(UIKit)
        // UIKit-backed scrolling drives exact content offsets for smooth playback follow.
        return
#else
        pendingScrollFollowTask?.cancel()
        pendingScrollFollowTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            scrollToCurrentNote(with: proxy, viewportSize: viewportSize, force: force)
        }
#endif
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
        let usesSmoothHorizontalFollow = followPlacement == .horizontalSmooth
        let movedBeyondSmoothHorizontalFollow = usesSmoothHorizontalFollow
            ? ScoreCanvasFollowHeuristics.hasMovedBeyondSmoothHorizontalFollowDistance(
                noteCenter: noteLayout.noteheadCenter,
                lastFollowCenter: lastScrollFollowCenter,
                viewportSize: viewportSize,
                scale: scale,
                margin: scrollFollowMargin
            )
            : false
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
           !movedBeyondLastFollow,
           !movedBeyondSmoothHorizontalFollow {
            return
        }
        let measuredAnchor = ScoreCanvasFollowHeuristics.scrollAnchor(
            for: currentFrame,
            viewportSize: viewportSize,
            margin: scrollFollowMargin
        )
        scrollAnchor = ScoreCanvasFollowHeuristics.resolvedScrollAnchor(
            measuredAnchor: measuredAnchor,
            movementAnchor: scrollAnchor,
            movedBeyondLastFollow: movedBeyondLastFollow,
            placement: followPlacement
        )

        lastScrollFollowCenter = noteLayout.noteheadCenter
        lastScrollFollowScale = scale
        if usesSmoothHorizontalFollow {
            let targetAnchor = ScoreCanvasScrollAnchor(noteID: noteID, kind: .notehead)
            let noteAnchor = UnitPoint(x: 0.42, y: scrollAnchor.y)
            let animation: Animation = force ? .easeInOut(duration: 0.16) : .easeInOut(duration: 0.18)
            withAnimation(animation) {
                proxy.scrollTo(targetAnchor, anchor: noteAnchor)
            }
            return
        }
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

#if canImport(UIKit)
private struct ScoreCanvasScrollFollowDriver: UIViewRepresentable {
    let layout: ScoreLayout
    let currentNoteID: NoteID?
    let nextNoteID: NoteID?
    let continuousNoteIDs: [NoteID]
    let followAnimationDuration: TimeInterval?
    let continuousFollowPlaybackDuration: TimeInterval?
    let scale: CGFloat
    let padding: CGFloat
    let contentSize: CGSize
    let placement: ScoreCanvasFollowPlacement

    func makeUIView(context _: Context) -> ScoreCanvasScrollFollowDriverView {
        ScoreCanvasScrollFollowDriverView()
    }

    func updateUIView(_ uiView: ScoreCanvasScrollFollowDriverView, context _: Context) {
        uiView.configure(
            layout: layout,
            currentNoteID: currentNoteID,
            nextNoteID: nextNoteID,
            continuousNoteIDs: continuousNoteIDs,
            followAnimationDuration: followAnimationDuration,
            continuousFollowPlaybackDuration: continuousFollowPlaybackDuration,
            scale: scale,
            padding: padding,
            contentSize: contentSize,
            placement: placement
        )
    }
}

private final class ScoreCanvasScrollFollowDriverView: UIView {
    private struct Configuration {
        let layout: ScoreLayout
        let currentNoteID: NoteID?
        let nextNoteID: NoteID?
        let continuousNoteIDs: [NoteID]
        let followAnimationDuration: TimeInterval?
        let continuousFollowPlaybackDuration: TimeInterval?
        let scale: CGFloat
        let padding: CGFloat
        let contentSize: CGSize
        let placement: ScoreCanvasFollowPlacement
    }

    private var configuration: Configuration?
    private weak var trackedScrollView: UIScrollView?
    private var lastAppliedTarget: CGPoint?
    private var lastAppliedNoteID: NoteID?
    private var lastAppliedScale: CGFloat = 1
    private var lastAppliedContentSize: CGSize = .zero
    private var lastNoteChangeTime: TimeInterval?
    private var smoothedNoteChangeInterval: TimeInterval?
    private var continuousDisplayLink: CADisplayLink?
    private var lastContinuousTick: CFTimeInterval?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            continuousDisplayLink?.invalidate()
            continuousDisplayLink = nil
            lastContinuousTick = nil
        }
        requestFollow()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        requestFollow()
    }

    func configure(
        layout: ScoreLayout,
        currentNoteID: NoteID?,
        nextNoteID: NoteID?,
        continuousNoteIDs: [NoteID],
        followAnimationDuration: TimeInterval?,
        continuousFollowPlaybackDuration: TimeInterval?,
        scale: CGFloat,
        padding: CGFloat,
        contentSize: CGSize,
        placement: ScoreCanvasFollowPlacement
    ) {
        configuration = Configuration(
            layout: layout,
            currentNoteID: currentNoteID,
            nextNoteID: nextNoteID,
            continuousNoteIDs: continuousNoteIDs,
            followAnimationDuration: followAnimationDuration,
            continuousFollowPlaybackDuration: continuousFollowPlaybackDuration,
            scale: scale,
            padding: padding,
            contentSize: contentSize,
            placement: placement
        )
        updateContinuousFollowDisplayLink()
        requestFollow()
    }

    private func requestFollow() {
        DispatchQueue.main.async { [weak self] in
            self?.followCurrentNoteIfNeeded()
        }
    }

    private func followCurrentNoteIfNeeded() {
        guard let configuration,
              let noteID = configuration.currentNoteID,
              let noteLayout = configuration.layout.noteLayout(for: noteID),
              let scrollView = enclosingScrollView(),
              scrollView.bounds.width > 0,
              scrollView.bounds.height > 0 else {
            return
        }

        let viewportSize = scrollView.bounds.size
        let current = scrollView.contentOffset
        guard !isContinuousFollowActive(configuration) else {
            return
        }
        let targetNoteLayout = configuration.placement == .horizontalSmooth
            ? (nextTargetNoteLayout(from: configuration) ?? noteLayout)
            : noteLayout
        let target = ScoreCanvasFollowHeuristics.targetContentOffset(
            for: targetNoteLayout,
            in: configuration.layout,
            viewportSize: viewportSize,
            contentSize: configuration.contentSize,
            scale: configuration.scale,
            padding: configuration.padding,
            currentContentOffset: current,
            placement: configuration.placement
        )

        let moved = hypot(target.x - current.x, target.y - current.y)
        let targetChanged = lastAppliedTarget.map { hypot(target.x - $0.x, target.y - $0.y) > 0.5 } ?? true
        let noteChanged = lastAppliedNoteID != noteID
        let inputChanged = noteChanged
            || lastAppliedScale != configuration.scale
            || lastAppliedContentSize != configuration.contentSize
        guard moved > 0.5, targetChanged || inputChanged else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if noteChanged {
            if let lastNoteChangeTime {
                let interval = now - lastNoteChangeTime
                if interval >= 0.06, interval <= 2.5 {
                    if let smoothedNoteChangeInterval {
                        self.smoothedNoteChangeInterval = smoothedNoteChangeInterval * 0.65 + interval * 0.35
                    } else {
                        smoothedNoteChangeInterval = interval
                    }
                }
            }
            lastNoteChangeTime = now
        }

        trackedScrollView = scrollView
        lastAppliedTarget = target
        lastAppliedNoteID = noteID
        lastAppliedScale = configuration.scale
        lastAppliedContentSize = configuration.contentSize

        let animationDuration = resolvedAnimationDuration(for: configuration, movedDistance: moved)
        let animationCurve: UIView.AnimationOptions = configuration.followAnimationDuration == nil
            ? .curveEaseOut
            : .curveLinear
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, animationCurve]
        ) {
            scrollView.contentOffset = target
        }
    }

    private func nextTargetNoteLayout(from configuration: Configuration) -> NoteLayout? {
        guard let nextNoteID = configuration.nextNoteID,
              nextNoteID != configuration.currentNoteID else {
            return nil
        }
        return configuration.layout.noteLayout(for: nextNoteID)
    }

    private func continuousTargetNoteLayout(from configuration: Configuration, currentOffset: CGPoint, viewportSize: CGSize) -> NoteLayout? {
        let layouts = configuration.continuousNoteIDs.compactMap { configuration.layout.noteLayout(for: $0) }
        guard !layouts.isEmpty else {
            return nextTargetNoteLayout(from: configuration)
        }
        if configuration.placement == .horizontalSmooth {
            let targetMinimumX = currentOffset.x + viewportSize.width * 0.6
            return layouts.last(where: {
                ScoreCanvasFollowHeuristics.targetContentOffset(
                    for: $0,
                    in: configuration.layout,
                    viewportSize: viewportSize,
                    contentSize: configuration.contentSize,
                    scale: configuration.scale,
                    padding: configuration.padding,
                    currentContentOffset: currentOffset,
                    placement: configuration.placement
                ).x >= targetMinimumX
            }) ?? layouts.last
        }
        return layouts.first
    }

    private func resolvedAnimationDuration(for configuration: Configuration, movedDistance: CGFloat) -> TimeInterval {
        if configuration.followAnimationDuration != nil {
            return ScoreCanvasFollowHeuristics.continuousFollowAnimationDuration(distance: movedDistance)
        }
        if configuration.placement == .horizontalSmooth {
            return ScoreCanvasFollowHeuristics.horizontalSmoothAnimationDuration(noteInterval: smoothedNoteChangeInterval)
        }
        return 0.22
    }

    private func isContinuousFollowActive(_ configuration: Configuration) -> Bool {
        guard configuration.followAnimationDuration != nil,
              configuration.continuousFollowPlaybackDuration != nil,
              configuration.currentNoteID != nil else {
            return false
        }
        return true
    }

    private func updateContinuousFollowDisplayLink() {
        guard let configuration, isContinuousFollowActive(configuration) else {
            continuousDisplayLink?.invalidate()
            continuousDisplayLink = nil
            lastContinuousTick = nil
            return
        }
        guard continuousDisplayLink == nil else {
            return
        }
        let displayLink = CADisplayLink(target: self, selector: #selector(handleContinuousFollowTick(_:)))
        displayLink.add(to: .main, forMode: .common)
        continuousDisplayLink = displayLink
        lastContinuousTick = nil
    }

    @objc private func handleContinuousFollowTick(_ displayLink: CADisplayLink) {
        guard let configuration,
              isContinuousFollowActive(configuration),
              let scrollView = enclosingScrollView(),
              scrollView.bounds.width > 0,
              scrollView.bounds.height > 0,
              let targetNoteLayout = continuousTargetNoteLayout(
                from: configuration,
                currentOffset: scrollView.contentOffset,
                viewportSize: scrollView.bounds.size
              ) else {
            updateContinuousFollowDisplayLink()
            return
        }

        let timestamp = displayLink.timestamp
        let previousTimestamp = lastContinuousTick ?? timestamp
        lastContinuousTick = timestamp
        let deltaTime = min(max(timestamp - previousTimestamp, 0), 0.08)
        guard deltaTime > 0 else {
            return
        }

        let viewportSize = scrollView.bounds.size
        let current = scrollView.contentOffset
        let target = ScoreCanvasFollowHeuristics.targetContentOffset(
            for: targetNoteLayout,
            in: configuration.layout,
            viewportSize: viewportSize,
            contentSize: configuration.contentSize,
            scale: configuration.scale,
            padding: configuration.padding,
            currentContentOffset: current,
            placement: configuration.placement
        )
        let speed = ScoreCanvasFollowHeuristics.continuousFollowSpeed(
            contentSize: configuration.contentSize,
            viewportSize: viewportSize,
            playbackDuration: configuration.continuousFollowPlaybackDuration
        )
        guard speed > 0 else {
            return
        }

        let vector = CGPoint(x: target.x - current.x, y: target.y - current.y)
        let distance = hypot(vector.x, vector.y)
        guard distance > 0.5 else {
            return
        }

        let step = min(distance, speed * CGFloat(deltaTime))
        let nextOffset = CGPoint(
            x: current.x + vector.x / distance * step,
            y: current.y + vector.y / distance * step
        )
        scrollView.setContentOffset(nextOffset, animated: false)
    }

    private func enclosingScrollView() -> UIScrollView? {
        if let trackedScrollView {
            return trackedScrollView
        }
        var view: UIView? = self
        while let current = view?.superview {
            if let scrollView = current as? UIScrollView {
                trackedScrollView = scrollView
                return scrollView
            }
            view = current
        }
        return nil
    }
}
#endif

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

    static func measureTopY(for measure: MeasureLayout, in layout: ScoreLayout) -> CGFloat {
        layout.systems.first(where: { $0.index == measure.systemIndex })?.frame.minY ?? measure.frame.minY
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

    static func targetContentOffset(
        for noteLayout: NoteLayout,
        in layout: ScoreLayout,
        viewportSize: CGSize,
        contentSize: CGSize,
        scale: CGFloat,
        padding: CGFloat,
        currentContentOffset: CGPoint = .zero,
        placement: ScoreCanvasFollowPlacement
    ) -> CGPoint {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return .zero
        }

        let effectiveScale = max(scale, ScoreViewportTransform.minimumScale)
        let noteFrame = frame(for: noteLayout, scale: effectiveScale, padding: padding)
        let maxOffset = CGPoint(
            x: max(0, contentSize.width - viewportSize.width),
            y: max(0, contentSize.height - viewportSize.height)
        )

        let rawOffset: CGPoint
        switch placement {
        case .horizontalSmooth:
            rawOffset = CGPoint(
                x: noteFrame.midX - viewportSize.width * 0.42,
                y: currentContentOffset.y
            )
        case .topAligned:
            let layoutY: CGFloat
            if let measureID = noteLayout.measureID,
               let measure = layout.measures.first(where: { $0.measureID == measureID }) {
                layoutY = measureTopY(for: measure, in: layout)
            } else {
                layoutY = noteLayout.noteheadFrame.minY
            }
            rawOffset = CGPoint(
                x: noteFrame.midX - viewportSize.width * 0.5,
                y: padding + layoutY * effectiveScale - viewportSize.height * 0.12
            )
        case .center:
            rawOffset = CGPoint(
                x: noteFrame.midX - viewportSize.width * 0.5,
                y: noteFrame.midY - viewportSize.height * 0.5
            )
        }

        if placement == .horizontalSmooth {
            return CGPoint(
                x: rawOffset.x.clamped(to: 0...maxOffset.x),
                y: rawOffset.y
            )
        }
        return CGPoint(
            x: rawOffset.x.clamped(to: 0...maxOffset.x),
            y: rawOffset.y.clamped(to: 0...maxOffset.y)
        )
    }

    static func horizontalSmoothAnimationDuration(noteInterval: TimeInterval?) -> TimeInterval {
        let interval = noteInterval ?? 0.36
        return (interval * 0.95).clamped(to: 0.16...1.1)
    }

    static func continuousFollowAnimationDuration(distance: CGFloat) -> TimeInterval {
        let pointsPerSecond: CGFloat = 220
        guard distance.isFinite, distance > 0, pointsPerSecond > 0 else {
            return horizontalSmoothAnimationDuration(noteInterval: nil)
        }
        return TimeInterval(distance / pointsPerSecond).clamped(to: 0.22...5.5)
    }

    static func continuousFollowSpeed(
        contentSize: CGSize,
        viewportSize: CGSize,
        playbackDuration: TimeInterval?
    ) -> CGFloat {
        guard let playbackDuration,
              playbackDuration.isFinite,
              playbackDuration > 0,
              contentSize.width.isFinite,
              viewportSize.width.isFinite else {
            return 0
        }
        let scrollableWidth = max(0, contentSize.width - viewportSize.width)
        guard scrollableWidth > 0 else {
            return 0
        }
        return (scrollableWidth / CGFloat(playbackDuration)).clamped(to: 36...220)
    }

    static func resolvedScrollAnchor(
        measuredAnchor: UnitPoint,
        movementAnchor: UnitPoint,
        movedBeyondLastFollow: Bool,
        placement: ScoreCanvasFollowPlacement
    ) -> UnitPoint {
        let resolvedAnchor = measuredAnchor == .center && movedBeyondLastFollow ? movementAnchor : measuredAnchor
        switch placement {
        case .center, .horizontalSmooth:
            return resolvedAnchor
        case .topAligned:
            return UnitPoint(x: resolvedAnchor.x, y: 0.12)
        }
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

    static func hasMovedBeyondSmoothHorizontalFollowDistance(
        noteCenter: CGPoint,
        lastFollowCenter: CGPoint?,
        viewportSize: CGSize,
        scale: CGFloat,
        margin: CGFloat
    ) -> Bool {
        guard let lastFollowCenter,
              viewportSize.width > 0 else {
            return true
        }
        let effectiveScale = max(scale, ScoreViewportTransform.minimumScale)
        let dx = abs(noteCenter.x - lastFollowCenter.x) * effectiveScale
        let safeMargin = max(margin, 0)
        let horizontalThreshold = max(40, min(viewportSize.width * 0.18, safeMargin * 1.5))
        return dx > horizontalThreshold
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
