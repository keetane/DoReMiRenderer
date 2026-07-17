import CoreGraphics
import Foundation

/// A platform-neutral point used by the browser Canvas bridge.
public struct ScoreWebPoint: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

/// A platform-neutral rectangle used by the browser Canvas bridge.
public struct ScoreWebRect: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.init(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }
}

/// Canvas primitive kinds understood by `Examples/WebCanvasViewer/score-canvas.js`.
public enum ScoreWebRenderCommandKind: String, Codable, Sendable {
    case fillRect
    case strokeLine
    case fillEllipse
    case strokeEllipse
    case strokeQuadraticCurve
    case drawText
}

/// Semantic font roles understood by browser consumers.
///
/// Browser targets do not have the same PostScript font registrations as Apple
/// platforms. Exporting a role keeps the score's typography deterministic while
/// preserving `fontName` for diagnostics and native tooling.
public enum ScoreWebFontRole: String, Codable, Sendable {
    case smufl
    case serif
    case serifItalic
    case serifBold
    case sansSerif

    init(fontName: String?) {
        switch fontName {
        case "Bravura":
            self = .smufl
        case "Georgia-Italic":
            self = .serifItalic
        case "TimesNewRomanPS-BoldMT":
            self = .serifBold
        case nil:
            self = .sansSerif
        default:
            self = .serif
        }
    }
}

/// One browser-safe drawing command. Coordinates are in the unchanged `ScoreLayout` space.
public struct ScoreWebRenderCommand: Hashable, Codable, Sendable {
    public let kind: ScoreWebRenderCommandKind
    public let color: ScoreColor
    public let rect: ScoreWebRect?
    public let start: ScoreWebPoint?
    public let control: ScoreWebPoint?
    public let end: ScoreWebPoint?
    public let lineWidth: Double?
    public let text: String?
    public let point: ScoreWebPoint?
    public let fontName: String?
    /// Cross-platform font category for browser renderers. `fontName` remains
    /// available for diagnostics but can be an Apple-specific PostScript name.
    public let fontRole: ScoreWebFontRole?
    public let fontSize: Double?
    public let mirroredHorizontally: Bool
    public let mirroredVertically: Bool

    init(
        kind: ScoreWebRenderCommandKind,
        color: ScoreColor,
        rect: ScoreWebRect? = nil,
        start: ScoreWebPoint? = nil,
        control: ScoreWebPoint? = nil,
        end: ScoreWebPoint? = nil,
        lineWidth: Double? = nil,
        text: String? = nil,
        point: ScoreWebPoint? = nil,
        fontName: String? = nil,
        fontRole: ScoreWebFontRole? = nil,
        fontSize: Double? = nil,
        mirroredHorizontally: Bool = false,
        mirroredVertically: Bool = false
    ) {
        self.kind = kind
        self.color = color
        self.rect = rect
        self.start = start
        self.control = control
        self.end = end
        self.lineWidth = lineWidth
        self.text = text
        self.point = point
        self.fontName = fontName
        self.fontRole = fontRole
        self.fontSize = fontSize
        self.mirroredHorizontally = mirroredHorizontally
        self.mirroredVertically = mirroredVertically
    }
}

/// Stable browser-side note anchor for selection, playback, and accessibility overlays.
public struct ScoreWebNoteAnchor: Hashable, Codable, Sendable {
    public let noteID: NoteID
    public let measureID: MeasureID?
    public let staffID: StaffID?
    public let center: ScoreWebPoint
    public let frame: ScoreWebRect

    init(layout: NoteLayout) {
        noteID = layout.noteID
        measureID = layout.measureID
        staffID = layout.staffID
        center = ScoreWebPoint(layout.noteheadCenter)
        frame = ScoreWebRect(layout.noteheadFrame)
    }
}

/// JSON transport produced by the SDK for browser Canvas rendering.
public struct ScoreWebRenderPlan: Hashable, Codable, Sendable {
    public static let formatVersion = 2

    public let formatVersion: Int
    public let canvas: ScoreWebRect
    public let commands: [ScoreWebRenderCommand]
    public let noteAnchors: [ScoreWebNoteAnchor]

    init(canvas: ScoreWebRect, commands: [ScoreWebRenderCommand], noteAnchors: [ScoreWebNoteAnchor]) {
        formatVersion = Self.formatVersion
        self.canvas = canvas
        self.commands = commands
        self.noteAnchors = noteAnchors
    }
}

/// Responsive layout defaults for browser score readers.
///
/// This profile uses the existing print/wrapped score layout: up to four measures per
/// system, compact reading spacing, and no page-only margin reservation. It is an
/// independent DoReMiRenderer profile, not a reproduction of another product's UI.
public struct ScoreWebLayoutProfile: Hashable, Codable, Sendable {
    public var staffSpace: Double
    public var systemSpacing: Double
    public var measureSpacing: Double
    public var maximumMeasuresPerSystem: Int

    public init(
        staffSpace: Double = 8,
        systemSpacing: Double = 52,
        measureSpacing: Double = 12,
        maximumMeasuresPerSystem: Int = 4
    ) {
        self.staffSpace = max(4, staffSpace)
        self.systemSpacing = max(24, systemSpacing)
        self.measureSpacing = max(0, measureSpacing)
        self.maximumMeasuresPerSystem = max(1, maximumMeasuresPerSystem)
    }

    public static let responsive = ScoreWebLayoutProfile()

    public func layoutOptions(containerWidth: Double) -> LayoutOptions {
        LayoutOptions(
            pageWidth: CGFloat(max(320, containerWidth)),
            staffSpace: CGFloat(staffSpace),
            systemSpacing: CGFloat(systemSpacing),
            measureSpacing: CGFloat(measureSpacing),
            displayMode: .print,
            showPageMargins: false,
            maximumMeasuresPerSystem: maximumMeasuresPerSystem
        )
    }
}

struct ScoreWebRenderPlanBuilder {
    func build(
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle,
        selection: ScoreSelection?,
        currentNoteIDs: Set<NoteID>,
        continuationNoteIDs: Set<NoteID>
    ) -> ScoreWebRenderPlan {
        var context = WebCanvasRecordingContext()
        ScorePainter().draw(
            layout: layout,
            score: score,
            style: style,
            selection: selection,
            currentNoteIDs: currentNoteIDs,
            continuationNoteIDs: continuationNoteIDs,
            into: &context
        )

        let anchors = layout.noteByID.values
            .sorted { $0.noteID.rawValue < $1.noteID.rawValue }
            .map(ScoreWebNoteAnchor.init(layout:))

        return ScoreWebRenderPlan(
            canvas: ScoreWebRect(x: 0, y: 0, width: Double(layout.canvasSize.width), height: Double(layout.canvasSize.height)),
            commands: context.commands,
            noteAnchors: anchors
        )
    }
}

private struct WebCanvasRecordingContext: ScoreDrawingContext {
    var commands: [ScoreWebRenderCommand] = []

    mutating func fill(_ rect: CGRect, color: ScoreColor) {
        commands.append(ScoreWebRenderCommand(kind: .fillRect, color: color, rect: ScoreWebRect(rect)))
    }

    mutating func strokeLine(from start: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(ScoreWebRenderCommand(
            kind: .strokeLine,
            color: color,
            start: ScoreWebPoint(start),
            end: ScoreWebPoint(end),
            lineWidth: Double(lineWidth)
        ))
    }

    mutating func fillEllipse(in rect: CGRect, color: ScoreColor) {
        commands.append(ScoreWebRenderCommand(kind: .fillEllipse, color: color, rect: ScoreWebRect(rect)))
    }

    mutating func strokeEllipse(in rect: CGRect, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(ScoreWebRenderCommand(
            kind: .strokeEllipse,
            color: color,
            rect: ScoreWebRect(rect),
            lineWidth: Double(lineWidth)
        ))
    }

    mutating func strokeQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint, color: ScoreColor, lineWidth: CGFloat) {
        commands.append(ScoreWebRenderCommand(
            kind: .strokeQuadraticCurve,
            color: color,
            start: ScoreWebPoint(start),
            control: ScoreWebPoint(control),
            end: ScoreWebPoint(end),
            lineWidth: Double(lineWidth)
        ))
    }

    mutating func drawText(_ text: String, at point: CGPoint, color: ScoreColor, size: CGFloat, fontName: String?) {
        drawText(text, at: point, color: color, size: size, fontName: fontName, mirroredHorizontally: false, mirroredVertically: false)
    }

    mutating func drawText(
        _ text: String,
        at point: CGPoint,
        color: ScoreColor,
        size: CGFloat,
        fontName: String?,
        mirroredHorizontally: Bool,
        mirroredVertically: Bool
    ) {
        commands.append(ScoreWebRenderCommand(
            kind: .drawText,
            color: color,
            text: text,
            point: ScoreWebPoint(point),
            fontName: fontName,
            fontRole: ScoreWebFontRole(fontName: fontName),
            fontSize: Double(size),
            mirroredHorizontally: mirroredHorizontally,
            mirroredVertically: mirroredVertically
        ))
    }
}
