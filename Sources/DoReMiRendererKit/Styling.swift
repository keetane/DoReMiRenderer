public struct ScoreColor: Hashable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = ScoreColor(red: 0, green: 0, blue: 0)
    public static let white = ScoreColor(red: 1, green: 1, blue: 1)
    public static let clear = ScoreColor(red: 0, green: 0, blue: 0, alpha: 0)
}

public struct ScaleColorPalette: Hashable, Codable, Sendable {
    public var c: ScoreColor
    public var d: ScoreColor
    public var e: ScoreColor
    public var f: ScoreColor
    public var g: ScoreColor
    public var a: ScoreColor
    public var b: ScoreColor

    public init(
        c: ScoreColor,
        d: ScoreColor,
        e: ScoreColor,
        f: ScoreColor,
        g: ScoreColor,
        a: ScoreColor,
        b: ScoreColor
    ) {
        self.c = c
        self.d = d
        self.e = e
        self.f = f
        self.g = g
        self.a = a
        self.b = b
    }

    public func color(for pitch: Pitch) -> ScoreColor {
        color(for: pitch.pitchClass)
    }

    public func color(for pitchClass: PitchClass) -> ScoreColor {
        switch pitchClass {
        case .c: c
        case .d: d
        case .e: e
        case .f: f
        case .g: g
        case .a: a
        case .b: b
        }
    }
}

public struct ColorPolicy: Hashable, Codable, Sendable {
    public var ignoreAccidentalForPitchClassColor: Bool
    public var useKeyAwareColor: Bool
    public var useAccidentalAwareColor: Bool
    public var useVoiceAwareColor: Bool

    public init(
        ignoreAccidentalForPitchClassColor: Bool,
        useKeyAwareColor: Bool,
        useAccidentalAwareColor: Bool,
        useVoiceAwareColor: Bool
    ) {
        self.ignoreAccidentalForPitchClassColor = ignoreAccidentalForPitchClassColor
        self.useKeyAwareColor = useKeyAwareColor
        self.useAccidentalAwareColor = useAccidentalAwareColor
        self.useVoiceAwareColor = useVoiceAwareColor
    }

    public static let mvp0Default = ColorPolicy(
        ignoreAccidentalForPitchClassColor: true,
        useKeyAwareColor: false,
        useAccidentalAwareColor: false,
        useVoiceAwareColor: false
    )
}

public protocol NoteColorRule: Sendable {
    func color(for note: ScoreNote, layout: NoteLayout?, context: ColorContext) -> ScoreColor
}

public protocol StaffLineColorRule: Sendable {
    func color(for staffLine: StaffLineLayout, context: ColorContext) -> ScoreColor
}

public protocol LedgerLineColorRule: Sendable {
    func color(for ledgerLine: LedgerLineLayout, note: ScoreNote?, context: ColorContext) -> ScoreColor
}

public protocol AccidentalColorRule: Sendable {
    func color(for accidental: ElementLayout, note: ScoreNote?, context: ColorContext) -> ScoreColor
}

public struct ColorContext: Sendable {
    public let score: ScoreDocument
    public let layout: ScoreLayout
    public let measureID: MeasureID?
    public let staffID: StaffID?
    public let voiceID: VoiceID?
    public let clef: Clef?
    public let keySignature: KeySignature?
    public let timeSignature: TimeSignature?
    public let selection: ScoreSelection?
    public let currentNoteIDs: Set<NoteID>
    public let userPalette: ScaleColorPalette?
    public let colorPolicy: ColorPolicy

    public init(
        score: ScoreDocument,
        layout: ScoreLayout,
        measureID: MeasureID? = nil,
        staffID: StaffID? = nil,
        voiceID: VoiceID? = nil,
        clef: Clef? = nil,
        keySignature: KeySignature? = nil,
        timeSignature: TimeSignature? = nil,
        selection: ScoreSelection? = nil,
        currentNoteIDs: Set<NoteID> = [],
        userPalette: ScaleColorPalette? = nil,
        colorPolicy: ColorPolicy = .mvp0Default
    ) {
        self.score = score
        self.layout = layout
        self.measureID = measureID
        self.staffID = staffID
        self.voiceID = voiceID
        self.clef = clef
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.selection = selection
        self.currentNoteIDs = currentNoteIDs
        self.userPalette = userPalette
        self.colorPolicy = colorPolicy
    }
}

public struct ScoreSelection: Hashable, Codable, Sendable {
    public let selectedNoteIDs: Set<NoteID>
    public let selectedElementIDs: Set<ScoreElementID>

    public init(selectedNoteIDs: Set<NoteID> = [], selectedElementIDs: Set<ScoreElementID> = []) {
        self.selectedNoteIDs = selectedNoteIDs
        self.selectedElementIDs = selectedElementIDs
    }
}

public struct NoteVisualStyle: Hashable, Codable, Sendable {
    public let fillColor: ScoreColor?
    public let strokeColor: ScoreColor?

    public init(fillColor: ScoreColor? = nil, strokeColor: ScoreColor? = nil) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
    }
}

public struct StaffLineVisualStyle: Hashable, Codable, Sendable {
    public let strokeColor: ScoreColor?

    public init(strokeColor: ScoreColor? = nil) {
        self.strokeColor = strokeColor
    }
}

public enum NoteColorStyle: Sendable {
    case monochrome(ScoreColor)
    case pitchClass(ScaleColorPalette)
    case rule(any NoteColorRule)
    case custom([NoteID: NoteVisualStyle])
}

public enum StaffLineColorStyle: Sendable {
    case monochrome(ScoreColor)
    case pitchClass(defaultPalette: ScaleColorPalette, clefOverrides: [ClefKind: ScaleColorPalette])
    case rule(any StaffLineColorRule)
    case custom([ScoreElementID: StaffLineVisualStyle])
}

public enum LedgerLineColorStyle: Sendable {
    case defaultInk
    case matchNotePitch
    case matchStaffPitch
    case rule(any LedgerLineColorRule)
}

public enum AccidentalColorStyle: Sendable {
    case defaultInk
    case matchNotePitch
    case rule(any AccidentalColorRule)
}

public struct HighlightStyle: Hashable, Codable, Sendable {
    public let color: ScoreColor

    public init(color: ScoreColor) {
        self.color = color
    }
}

public struct GlyphStyle: Hashable, Codable, Sendable {
    public let color: ScoreColor

    public init(color: ScoreColor) {
        self.color = color
    }
}

public enum MeasureNumberDisplayMode: String, Hashable, Codable, Sendable {
    case hidden
    case evenMeasures
}

public struct ScoreStyle: Sendable {
    public var backgroundColor: ScoreColor
    public var defaultInkColor: ScoreColor
    public var staffLineStyle: StaffLineColorStyle
    public var noteColorStyle: NoteColorStyle
    public var ledgerLineStyle: LedgerLineColorStyle
    public var accidentalStyle: AccidentalColorStyle
    public var highlightStyle: HighlightStyle
    public var glyphStyle: GlyphStyle
    public var measureNumberDisplayMode: MeasureNumberDisplayMode
    public var colorResolver: ScoreColorResolver

    public init(
        backgroundColor: ScoreColor = .white,
        defaultInkColor: ScoreColor = .black,
        staffLineStyle: StaffLineColorStyle = .monochrome(.black),
        noteColorStyle: NoteColorStyle = .monochrome(.black),
        ledgerLineStyle: LedgerLineColorStyle = .defaultInk,
        accidentalStyle: AccidentalColorStyle = .defaultInk,
        highlightStyle: HighlightStyle = HighlightStyle(color: ScoreColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.35)),
        glyphStyle: GlyphStyle = GlyphStyle(color: .black),
        measureNumberDisplayMode: MeasureNumberDisplayMode = .hidden,
        colorResolver: ScoreColorResolver = ScoreColorResolver()
    ) {
        self.backgroundColor = backgroundColor
        self.defaultInkColor = defaultInkColor
        self.staffLineStyle = staffLineStyle
        self.noteColorStyle = noteColorStyle
        self.ledgerLineStyle = ledgerLineStyle
        self.accidentalStyle = accidentalStyle
        self.highlightStyle = highlightStyle
        self.glyphStyle = glyphStyle
        self.measureNumberDisplayMode = measureNumberDisplayMode
        self.colorResolver = colorResolver
    }
}

public struct ScoreColorResolver: Sendable {
    public init() {}

    public func resolvedStyle(
        for element: ElementLayout,
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle,
        selection: ScoreSelection?
    ) -> ResolvedVisualStyle {
        let currentNoteIDs = selection?.selectedNoteIDs ?? []
        let context = ColorContext(
            score: score,
            layout: layout,
            measureID: element.measureID,
            staffID: element.staffID,
            voiceID: element.voiceID,
            clef: element.clef,
            keySignature: element.keySignature,
            timeSignature: element.timeSignature,
            selection: selection,
            currentNoteIDs: currentNoteIDs
        )

        if let noteID = element.noteID,
           currentNoteIDs.contains(noteID),
           element.kind != .accidental,
           element.kind != .stem,
           element.kind != .flag {
            return ResolvedVisualStyle(
                fillColor: style.highlightStyle.color,
                strokeColor: style.highlightStyle.color,
                lineWidth: nil,
                opacity: style.highlightStyle.color.alpha
            )
        }

        switch element.kind {
        case .notehead:
            let color = resolvedNoteColor(for: element, score: score, layout: layout, style: style, context: context)
            return ResolvedVisualStyle(fillColor: color, strokeColor: color, lineWidth: nil, opacity: color.alpha)
        case .rest:
            return ResolvedVisualStyle(fillColor: style.defaultInkColor, strokeColor: style.defaultInkColor, lineWidth: nil, opacity: style.defaultInkColor.alpha)
        case .stem, .flag:
            return ResolvedVisualStyle(fillColor: style.defaultInkColor, strokeColor: style.defaultInkColor, lineWidth: nil, opacity: style.defaultInkColor.alpha)
        case .dot:
            let color = resolvedNoteColor(for: element, score: score, layout: layout, style: style, context: context)
            return ResolvedVisualStyle(fillColor: color, strokeColor: color, lineWidth: nil, opacity: color.alpha)
        case .staffLine:
            let color = resolvedStaffLineColor(for: element, style: style, context: context)
            return ResolvedVisualStyle(fillColor: nil, strokeColor: color, lineWidth: 1, opacity: color.alpha)
        case .ledgerLine:
            let color = resolvedLedgerLineColor(for: element, score: score, layout: layout, style: style, context: context)
            return ResolvedVisualStyle(fillColor: nil, strokeColor: color, lineWidth: 1, opacity: color.alpha)
        case .accidental:
            let color = resolvedAccidentalColor(for: element, score: score, layout: layout, style: style, context: context)
            return ResolvedVisualStyle(fillColor: color, strokeColor: color, lineWidth: nil, opacity: color.alpha)
        case .keySignature:
            let color = resolvedKeySignatureColor(for: element, style: style)
            return ResolvedVisualStyle(fillColor: color, strokeColor: color, lineWidth: nil, opacity: color.alpha)
        default:
            return ResolvedVisualStyle(
                fillColor: style.defaultInkColor,
                strokeColor: style.defaultInkColor,
                lineWidth: nil,
                opacity: style.defaultInkColor.alpha
            )
        }
    }

    private func resolvedNoteColor(
        for element: ElementLayout,
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle,
        context: ColorContext
    ) -> ScoreColor {
        switch style.noteColorStyle {
        case .monochrome(let color):
            return color
        case .pitchClass(let palette):
            guard let pitch = element.noteLayout?.pitch else {
                return style.defaultInkColor
            }
            return palette.color(for: pitch)
        case .rule(let rule):
            guard let note = score.note(for: element.noteID) else {
                return style.defaultInkColor
            }
            return rule.color(for: note, layout: element.noteID.flatMap { layout.noteLayout(for: $0) }, context: context)
        case .custom(let styles):
            guard let noteID = element.noteID, let visualStyle = styles[noteID] else {
                return style.defaultInkColor
            }
            return visualStyle.fillColor ?? visualStyle.strokeColor ?? style.defaultInkColor
        }
    }

    private func resolvedStaffLineColor(
        for element: ElementLayout,
        style: ScoreStyle,
        context: ColorContext
    ) -> ScoreColor {
        switch style.staffLineStyle {
        case .monochrome(let color):
            return color
        case .pitchClass(let defaultPalette, let clefOverrides):
            guard let staffLine = element.staffLine else {
                return style.defaultInkColor
            }
            return ClefAwareStaffLineColorRule(defaultPalette: defaultPalette, clefOverrides: clefOverrides)
                .color(for: staffLine, context: context)
        case .rule(let rule):
            guard let staffLine = element.staffLine else {
                return style.defaultInkColor
            }
            return rule.color(for: staffLine, context: context)
        case .custom(let styles):
            return styles[element.id]?.strokeColor ?? style.defaultInkColor
        }
    }

    private func resolvedLedgerLineColor(
        for element: ElementLayout,
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle,
        context: ColorContext
    ) -> ScoreColor {
        switch style.ledgerLineStyle {
        case .defaultInk:
            return style.defaultInkColor
        case .matchNotePitch, .matchStaffPitch:
            let noteElement = element.noteID
                .flatMap { layout.noteLayout(for: $0)?.noteheadElementID }
                .flatMap { layout.elementLayout(for: $0) }
            return noteElement.map {
                resolvedNoteColor(for: $0, score: score, layout: layout, style: style, context: context)
            } ?? style.defaultInkColor
        case .rule(let rule):
            return rule.color(for: element.ledgerLine ?? LedgerLineLayout(id: element.id), note: score.note(for: element.noteID), context: context)
        }
    }

    private func resolvedAccidentalColor(
        for element: ElementLayout,
        score: ScoreDocument,
        layout: ScoreLayout,
        style: ScoreStyle,
        context: ColorContext
    ) -> ScoreColor {
        switch style.accidentalStyle {
        case .defaultInk:
            return style.defaultInkColor
        case .matchNotePitch:
            if let noteElement = element.noteID
                .flatMap({ layout.noteLayout(for: $0)?.noteheadElementID })
                .flatMap({ layout.elementLayout(for: $0) }) {
                return resolvedNoteColor(for: noteElement, score: score, layout: layout, style: style, context: context)
            }
            return style.defaultInkColor
        case .rule(let rule):
            return rule.color(for: element, note: score.note(for: element.noteID), context: context)
        }
    }

    private func resolvedKeySignatureColor(
        for element: ElementLayout,
        style: ScoreStyle
    ) -> ScoreColor {
        guard case .pitchClass(let palette) = style.noteColorStyle,
              let pitchClass = element.pitchClassHint else {
            return style.defaultInkColor
        }
        return palette.color(for: pitchClass)
    }
}

private extension ScoreDocument {
    func note(for id: NoteID?) -> ScoreNote? {
        guard let id else {
            return nil
        }
        for part in parts {
            for measure in part.measures {
                if let note = measure.notes.first(where: { $0.id == id }) {
                    return note
                }
            }
        }
        return nil
    }
}

private extension NoteColorStyle {
    func color(for note: ScoreNote, fallback: ScoreColor, context: ColorContext) -> ScoreColor {
        switch self {
        case .monochrome(let color):
            return color
        case .pitchClass(let palette):
            guard let pitch = note.pitch else {
                return fallback
            }
            return palette.color(for: pitch)
        case .rule(let rule):
            return rule.color(for: note, layout: context.layout.noteLayout(for: note.id), context: context)
        case .custom(let styles):
            return styles[note.id]?.fillColor ?? styles[note.id]?.strokeColor ?? fallback
        }
    }
}

public struct ResolvedVisualStyle: Hashable, Codable, Sendable {
    public let fillColor: ScoreColor?
    public let strokeColor: ScoreColor?
    public let lineWidth: Double?
    public let opacity: Double

    public init(fillColor: ScoreColor?, strokeColor: ScoreColor?, lineWidth: Double?, opacity: Double) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.opacity = opacity
    }
}

public struct PitchClassNoteColorRule: NoteColorRule {
    public let palette: ScaleColorPalette
    public let policy: ColorPolicy

    public init(palette: ScaleColorPalette, policy: ColorPolicy = .mvp0Default) {
        self.palette = palette
        self.policy = policy
    }

    public func color(for note: ScoreNote, layout: NoteLayout?, context: ColorContext) -> ScoreColor {
        guard let pitch = note.pitch else {
            return .clear
        }
        return palette.color(for: pitch)
    }
}

public struct ClefAwareStaffLineColorRule: StaffLineColorRule {
    public let defaultPalette: ScaleColorPalette
    public let clefOverrides: [ClefKind: ScaleColorPalette]

    public init(defaultPalette: ScaleColorPalette, clefOverrides: [ClefKind: ScaleColorPalette] = [:]) {
        self.defaultPalette = defaultPalette
        self.clefOverrides = clefOverrides
    }

    public func color(for staffLine: StaffLineLayout, context: ColorContext) -> ScoreColor {
        let palette = clefOverrides[staffLine.clefKind] ?? defaultPalette
        return palette.color(for: staffLine.pitchClassHint ?? staffLinePitchClass(clefKind: staffLine.clefKind, lineIndex: staffLine.lineIndex))
    }
}

public struct MatchNoteLedgerLineColorRule: LedgerLineColorRule {
    public init() {}

    public func color(for ledgerLine: LedgerLineLayout, note: ScoreNote?, context: ColorContext) -> ScoreColor {
        guard let pitch = note?.pitch else {
            return .black
        }
        return (context.userPalette ?? defaultEducationalPalette).color(for: pitch)
    }
}

public let defaultEducationalPalette = ScaleColorPalette(
    c: ScoreColor(red: 0.9, green: 0.1, blue: 0.1),
    d: ScoreColor(red: 1.0, green: 0.55, blue: 0.0),
    e: ScoreColor(red: 0.95, green: 0.82, blue: 0.05),
    f: ScoreColor(red: 0.1, green: 0.65, blue: 0.2),
    g: ScoreColor(red: 0.1, green: 0.35, blue: 0.95),
    a: ScoreColor(red: 0.35, green: 0.2, blue: 0.8),
    b: ScoreColor(red: 0.75, green: 0.2, blue: 0.75)
)

public func staffLinePitchClass(clefKind: ClefKind, lineIndex: Int) -> PitchClass {
    switch clefKind {
    case .bass:
        return [.g, .b, .d, .f, .a][clampedStaffLineIndex(lineIndex)]
    case .treble, .alto, .tenor, .unknown:
        return [.e, .g, .b, .d, .f][clampedStaffLineIndex(lineIndex)]
    }
}

private func clampedStaffLineIndex(_ lineIndex: Int) -> Int {
    min(max(lineIndex, 0), 4)
}
