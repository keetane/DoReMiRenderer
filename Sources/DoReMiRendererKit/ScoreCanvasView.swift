import SwiftUI

public struct ScoreCanvasView: View {
    public let layout: ScoreLayout
    public let score: ScoreDocument
    public let style: ScoreStyle
    public let selection: ScoreSelection?
    public let currentNoteIDs: Set<NoteID>
    public let scale: CGFloat
    public let contentOffset: CGPoint
    public let viewportSize: CGSize
    public let scrollAxes: Axis.Set
    public let followsCurrentNote: Bool
    public let scrollFollowMargin: CGFloat
    public let onTap: ((HitTestResult) -> Void)?

    public init(
        layout: ScoreLayout,
        score: ScoreDocument = ScoreDocument(parts: []),
        style: ScoreStyle = ScoreStyle(),
        selection: ScoreSelection? = nil,
        currentNoteID: NoteID? = nil,
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
            ScrollViewReader { proxy in
                ScrollView(scrollAxes) {
                    scrollableCanvasContent
                }
                .onAppear {
                    scrollToCurrentNote(with: proxy)
                }
                .onChange(of: currentFollowNoteID) { _, _ in
                    scrollToCurrentNote(with: proxy)
                }
                .onChange(of: scale) { _, _ in
                    scrollToCurrentNote(with: proxy)
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
            canvasContent
            currentNoteAnchors
        }
        .frame(width: transform.scaledContentSize.width, height: transform.scaledContentSize.height)
    }

    @ViewBuilder
    private var currentNoteAnchors: some View {
        ForEach(currentNoteIDs.sorted { $0.rawValue < $1.rawValue }, id: \.self) { noteID in
            if let noteLayout = layout.noteByID[noteID] {
                Color.clear
                    .frame(width: 1, height: 1)
                    .position(
                        x: noteLayout.noteheadCenter.x * scale,
                        y: noteLayout.noteheadCenter.y * scale
                    )
                    .allowsHitTesting(false)
                    .id(ScoreCanvasScrollAnchor(noteID: noteID))
            }
        }
    }

    private var currentFollowNoteID: NoteID? {
        guard followsCurrentNote else {
            return nil
        }
        return currentNoteIDs.sorted { $0.rawValue < $1.rawValue }.first
    }

    private func scrollToCurrentNote(with proxy: ScrollViewProxy) {
        guard let noteID = currentFollowNoteID else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(ScoreCanvasScrollAnchor(noteID: noteID), anchor: .center)
            }
        }
    }
}

private struct ScoreCanvasScrollAnchor: Hashable {
    let noteID: NoteID
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

    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {
        context.fill(Path(ellipseIn: rect), with: .color(Color(scoreColor: color)))
    }

    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        context.stroke(Path(ellipseIn: rect), with: .color(Color(scoreColor: color)), lineWidth: lineWidth)
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat) {
        context.draw(
            Text(text).font(.system(size: size)).foregroundStyle(Color(scoreColor: color)),
            at: point,
            anchor: .center
        )
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
