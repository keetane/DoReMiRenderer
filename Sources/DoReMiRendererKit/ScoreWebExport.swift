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
    /// Sounding MIDI value when the anchor is pitched. This lets browser UI
    /// components such as the keyboard share the same note identity without
    /// reparsing MusicXML or deriving layout coordinates.
    public let midiNumber: Int?
    /// Diatonic pitch class before accidental alteration. Palette colouring
    /// follows the score spelling (for example B-flat remains in the B colour
    /// family) while MIDI remains available for keyboard placement.
    public let colorPitchClass: Int?
    /// The SDK system containing this note. Browser playback uses this only to
    /// decide when a grand-staff-level scroll is necessary; it never derives
    /// its own score geometry.
    public let systemIndex: Int?

    init(layout: NoteLayout, systemIndex: Int?) {
        noteID = layout.noteID
        measureID = layout.measureID
        staffID = layout.staffID
        center = ScoreWebPoint(layout.noteheadCenter)
        frame = ScoreWebRect(layout.noteheadFrame)
        midiNumber = layout.pitch.map(Self.midiNumber(for:))
        colorPitchClass = layout.pitch.map { Self.naturalPitchClass(for: $0.step) }
        self.systemIndex = systemIndex
    }

    private static func midiNumber(for pitch: Pitch) -> Int {
        (pitch.octave + 1) * 12 + naturalPitchClass(for: pitch.step) + pitch.alter
    }

    static func naturalPitchClass(for step: PitchStep) -> Int {
        let naturalSemitones: [PitchStep: Int] = [
            .c: 0, .d: 2, .e: 4, .f: 5, .g: 7, .a: 9, .b: 11
        ]
        return naturalSemitones[step] ?? 0
    }
}

/// Semantic ledger-line metadata for browser palette overlays. A ledger line
/// belongs to the written note that requires it, so its colour follows that
/// note's spelling rather than the staff position it crosses.
public struct ScoreWebLedgerLine: Hashable, Codable, Sendable {
    public let start: ScoreWebPoint
    public let end: ScoreWebPoint
    public let noteID: NoteID?
    public let colorPitchClass: Int?

    init(layout: LedgerLineLayout, note: NoteLayout?) {
        start = ScoreWebPoint(layout.start)
        end = ScoreWebPoint(layout.end)
        noteID = layout.noteID
        colorPitchClass = note?.pitch.map { ScoreWebNoteAnchor.naturalPitchClass(for: $0.step) }
    }
}

/// The bounds of one SDK-laid-out system. This lets browser consumers render a
/// current-position guide across the complete grand staff instead of attaching
/// a marker to an individual notehead.
public struct ScoreWebSystemGuide: Hashable, Codable, Sendable {
    public let index: Int
    public let frame: ScoreWebRect

    init(layout: SystemLayout) {
        index = layout.index
        frame = ScoreWebRect(layout.frame)
    }
}

/// Initial score key information for scale-aware browser palette controls.
/// It is copied from the parsed domain model; browser consumers do not infer a
/// key from accidentals or Canvas commands.
public struct ScoreWebKeySignature: Hashable, Codable, Sendable {
    public let fifths: Int
    public let mode: String?

    init(_ keySignature: KeySignature) {
        fifths = keySignature.fifths
        mode = keySignature.mode
    }
}

/// Semantic staff-line metadata for browser colour overlays. Coordinates are
/// copied directly from `ScoreLayout`; browsers do not infer clefs or staff
/// pitches from drawing commands.
public struct ScoreWebStaffLine: Hashable, Codable, Sendable {
    public let start: ScoreWebPoint
    public let end: ScoreWebPoint
    public let pitchClass: PitchClass?

    init(layout: StaffLineLayout) {
        start = ScoreWebPoint(layout.start)
        end = ScoreWebPoint(layout.end)
        pitchClass = layout.pitchClassHint
    }
}

/// One scheduled browser playback event. Times are calculated by the SDK from
/// the expanded `PlaybackEvent` sequence so a browser never needs to infer
/// rhythm from Canvas commands or reparse MusicXML.
public struct ScoreWebPlaybackEvent: Hashable, Codable, Sendable {
    public let noteIDs: [NoteID]
    public let measureID: MeasureID
    public let measureNumber: String
    public let startSeconds: Double
    public let intervalSeconds: Double
    public let soundDurationSeconds: Double
    /// Source tempo used when this event's exported seconds were calculated.
    /// Browser transports use this to present real BPM controls rather than a
    /// relative percentage without inferring tempo from layout coordinates.
    public let tempoBPM: Double?
    /// Per-pitch sound windows copied from the app runtime's gate policy.
    /// Chords with unequal written durations retain their individual releases.
    public let midiSoundDurationSeconds: [Int: Double]?
    public let midiPitches: [Int]
    public let velocityScale: Double

    init(
        event: PlaybackEvent,
        measureNumber: String,
        startSeconds: Double,
        intervalSeconds: Double,
        soundDurationSeconds: Double,
        tempoBPM: Double? = nil,
        midiSoundDurationSeconds: [Int: Double]? = nil
    ) {
        noteIDs = event.noteIDs
        measureID = event.measureID
        self.measureNumber = measureNumber
        self.startSeconds = startSeconds
        self.intervalSeconds = intervalSeconds
        self.soundDurationSeconds = soundDurationSeconds
        self.tempoBPM = tempoBPM
        self.midiSoundDurationSeconds = midiSoundDurationSeconds
        midiPitches = event.midiPitches
        velocityScale = event.expression.velocityScale
    }
}

/// A pre-rendered display-transpose alternative. It is intentionally a full
/// SDK layout rather than a browser-side coordinate transform.
public struct ScoreWebTransposeVariant: Hashable, Codable, Sendable {
    public let semitones: Int
    public let plan: ScoreWebRenderPlan

    init(semitones: Int, plan: ScoreWebRenderPlan) {
        self.semitones = semitones
        self.plan = plan
    }
}

/// Browser document transport containing the written score, its SDK-generated
/// display-transpose layouts, and a playback timeline.
public struct ScoreWebRenderBundle: Hashable, Codable, Sendable {
    public static let formatVersion = 1

    public let formatVersion: Int
    public let primaryPlan: ScoreWebRenderPlan
    public let transposeVariants: [ScoreWebTransposeVariant]

    init(primaryPlan: ScoreWebRenderPlan, transposeVariants: [ScoreWebTransposeVariant]) {
        formatVersion = Self.formatVersion
        self.primaryPlan = primaryPlan
        self.transposeVariants = transposeVariants
    }
}

/// JSON transport produced by the SDK for browser Canvas rendering.
public struct ScoreWebRenderPlan: Hashable, Codable, Sendable {
    public static let formatVersion = 6

    public let formatVersion: Int
    public let canvas: ScoreWebRect
    public let commands: [ScoreWebRenderCommand]
    public let noteAnchors: [ScoreWebNoteAnchor]
    /// Optional for backwards-compatible decoding of version 1/2 plans.
    public let staffLines: [ScoreWebStaffLine]?
    /// Optional for backwards-compatible decoding of plans generated before
    /// palette-aware ledger-line colouring was added.
    public let ledgerLines: [ScoreWebLedgerLine]?
    /// Optional for backwards-compatible decoding of plans generated before
    /// browser playback was added.
    public let playbackEvents: [ScoreWebPlaybackEvent]?
    /// Optional for backwards-compatible decoding of plans generated before
    /// system-level browser following was added.
    public let systems: [ScoreWebSystemGuide]?
    /// The first declared key signature, used for the browser palette's scale
    /// mode. Mid-score key changes remain represented by the score commands.
    public let initialKeySignature: ScoreWebKeySignature?

    init(
        canvas: ScoreWebRect,
        commands: [ScoreWebRenderCommand],
        noteAnchors: [ScoreWebNoteAnchor],
        staffLines: [ScoreWebStaffLine]? = nil,
        ledgerLines: [ScoreWebLedgerLine]? = nil,
        playbackEvents: [ScoreWebPlaybackEvent]? = nil,
        systems: [ScoreWebSystemGuide]? = nil,
        initialKeySignature: ScoreWebKeySignature? = nil
    ) {
        formatVersion = Self.formatVersion
        self.canvas = canvas
        self.commands = commands
        self.noteAnchors = noteAnchors
        self.staffLines = staffLines
        self.ledgerLines = ledgerLines
        self.playbackEvents = playbackEvents
        self.systems = systems
        self.initialKeySignature = initialKeySignature
    }
}

/// Responsive layout defaults for browser score readers.
///
/// This profile uses the existing print/wrapped score layout: up to four measures per
/// system, proportional notation derived from `staffSpace`, and no page-only margin
/// reservation. It is an independent DoReMiRenderer profile, not a reproduction of
/// another product's UI or source implementation.
public struct ScoreWebLayoutProfile: Hashable, Codable, Sendable {
    public var staffSpace: Double
    public var systemSpacing: Double
    public var measureSpacing: Double
    /// Optional on the wire so render plans/profile data written before this
    /// spacing control remain decodable. `layoutOptions` supplies the current
    /// responsive default when it is absent.
    public var interStaffWhitespace: Double?
    public var maximumMeasuresPerSystem: Int

    public init(
        staffSpace: Double = 12,
        systemSpacing: Double = 82,
        measureSpacing: Double = 0,
        interStaffWhitespace: Double? = 90,
        maximumMeasuresPerSystem: Int = 4
    ) {
        self.staffSpace = max(4, staffSpace)
        self.systemSpacing = max(24, systemSpacing)
        self.measureSpacing = max(0, measureSpacing)
        self.interStaffWhitespace = interStaffWhitespace.map { max(0, $0) }
        self.maximumMeasuresPerSystem = max(1, maximumMeasuresPerSystem)
    }

    public static let responsive = ScoreWebLayoutProfile()

    public func layoutOptions(containerWidth: Double) -> LayoutOptions {
        LayoutOptions(
            // A four-measure reader row is composed in a stable logical width
            // and then scaled by the Canvas to the available browser width.
            pageWidth: CGFloat(max(1_800, containerWidth)),
            staffSpace: CGFloat(staffSpace),
            systemSpacing: CGFloat(systemSpacing),
            measureSpacing: CGFloat(measureSpacing),
            displayMode: .print,
            showPageMargins: false,
            maximumMeasuresPerSystem: maximumMeasuresPerSystem,
            interStaffWhitespace: CGFloat(interStaffWhitespace ?? 90),
            repeatsSystemPrefixAtLineBreaks: true,
            anchorsShortNoteGroupsRhythmically: true,
            usesExpandedExpressionLanes: true,
            // Use compact note spacing without activating print's dense-score
            // system-break guard; the browser can scale the finished canvas.
            usesCompactMeasureSpacing: true,
            justifiesFinalSystem: true,
            fullyJustifiesFinalSystem: true,
            usesDurationSensitiveShortNoteSpacing: true,
            titleScale: 0.82,
            titleGapAboveFirstStaff: 120,
            showsPedalMarkings: false,
            noteheadSizeAdjustment: 2,
            horizontalMarginAdjustment: 20,
            stemAttachmentInset: 2,
            timeSignatureScale: 1.5,
            timeSignatureFontSize: 36,
            // Bring the numerator 1pt lower and denominator 1pt higher than
            // the former Web profile without changing native app layout.
            timeSignatureDigitInset: 4
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
        continuationNoteIDs: Set<NoteID>,
        playbackEvents: [ScoreWebPlaybackEvent]? = nil
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

        let systemIndexByMeasureID = Dictionary(
            layout.measures.map { ($0.measureID, $0.systemIndex) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let anchors = layout.noteByID.values
            .sorted { $0.noteID.rawValue < $1.noteID.rawValue }
            .map { note in
                let systemIndex = note.measureID.flatMap { systemIndexByMeasureID[$0] }
                return ScoreWebNoteAnchor(layout: note, systemIndex: systemIndex)
            }
        let staffLines = layout.staffLines.map(ScoreWebStaffLine.init(layout:))
        let ledgerLines = layout.ledgerLines.map { ledgerLine in
            ScoreWebLedgerLine(
                layout: ledgerLine,
                note: ledgerLine.noteID.flatMap(layout.noteLayout(for:))
            )
        }
        let systems = layout.systems.map(ScoreWebSystemGuide.init(layout:))
        let initialKeySignature = layout.elements
            .first(where: { $0.kind == .keySignature })?
            .keySignature
            .map(ScoreWebKeySignature.init)
            ?? score.parts
                .lazy
                .flatMap(\.measures)
                .compactMap(\.keySignature)
                .first
                .map(ScoreWebKeySignature.init)

        return ScoreWebRenderPlan(
            canvas: ScoreWebRect(x: 0, y: 0, width: Double(layout.canvasSize.width), height: Double(layout.canvasSize.height)),
            commands: context.commands,
            noteAnchors: anchors,
            staffLines: staffLines,
            ledgerLines: ledgerLines,
            playbackEvents: playbackEvents,
            systems: systems,
            initialKeySignature: initialKeySignature
        )
    }
}

struct ScoreWebPlaybackTimelineBuilder {
    func build(score: ScoreDocument) -> [ScoreWebPlaybackEvent] {
        let sequence = PlaybackSequenceBuilder().build(score: score)
        guard !sequence.isEmpty else { return [] }

        let measureNumbers = Dictionary(
            score.parts
                .flatMap(\.measures)
                .map { ($0.id, $0.number) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let metadata = PlaybackSequenceBuilder().metadata(score: score)
        let measureOrder = measureOrderByID(sequence)
        let tempos = metadata.tempoEvents
            .compactMap { event -> (order: Int, onset: MusicalTime, bpm: Double)? in
                guard let measureID = event.measureID, let order = measureOrder[measureID] else { return nil }
                return (order, event.onset, event.bpm)
            }
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.onset < rhs.onset : lhs.order < rhs.order
            }

        var elapsed = 0.0
        return sequence.indices.map { index in
            let event = sequence[index]
            let tempo = tempoBPM(for: event, order: measureOrder[event.measureID] ?? 0, tempos: tempos)
            let interval = schedulingInterval(at: index, in: sequence, tempo: tempo)
            let defaultSoundDuration = soundDuration(for: event.nominalDuration, event: event, tempo: tempo)
            let perPitchSoundDuration = Dictionary(
                uniqueKeysWithValues: event.midiPitches.map { midiPitch in
                    (
                        midiPitch,
                        soundDuration(
                            for: event.midiPitchDurations[midiPitch] ?? event.nominalDuration,
                            event: event,
                            tempo: tempo
                        )
                    )
                }
            )
            defer { elapsed += interval }
            return ScoreWebPlaybackEvent(
                event: event,
                measureNumber: measureNumbers[event.measureID] ?? event.measureID.rawValue,
                startSeconds: elapsed,
                intervalSeconds: interval,
                soundDurationSeconds: defaultSoundDuration,
                tempoBPM: tempo,
                midiSoundDurationSeconds: perPitchSoundDuration
            )
        }
    }

    private func measureOrderByID(_ events: [PlaybackEvent]) -> [MeasureID: Int] {
        var result: [MeasureID: Int] = [:]
        for event in events where result[event.measureID] == nil {
            result[event.measureID] = result.count
        }
        return result
    }

    private func tempoBPM(
        for event: PlaybackEvent,
        order: Int,
        tempos: [(order: Int, onset: MusicalTime, bpm: Double)]
    ) -> Double {
        let bpm = tempos.last { candidate in
            candidate.order < order || (candidate.order == order && candidate.onset <= event.onset)
        }?.bpm ?? 120
        return min(max(bpm.isFinite ? bpm : 120, 20), 320)
    }

    private func schedulingInterval(at index: Int, in events: [PlaybackEvent], tempo: Double) -> Double {
        let event = events[index]
        let nextIndex = index + 1
        let duration: MusicalTime
        if nextIndex < events.count, events[nextIndex].measureID == event.measureID, event.onset < events[nextIndex].onset {
            duration = events[nextIndex].onset - event.onset
        } else {
            let measureEnd = events[index...]
                .prefix { $0.measureID == event.measureID }
                .map { $0.onset + $0.nominalDuration }
                .max() ?? (event.onset + event.nominalDuration)
            duration = event.onset < measureEnd ? measureEnd - event.onset : event.nominalDuration
        }
        let baseSeconds = seconds(for: duration, tempo: tempo)
        let extra = min(baseSeconds * max(0, event.expression.durationScale - 1), event.expression.maxDurationExtraSeconds)
        return min(max(0.01, baseSeconds + extra), 8)
    }

    private func nominalSeconds(for event: PlaybackEvent, tempo: Double) -> Double {
        let baseSeconds = seconds(for: event.nominalDuration, tempo: tempo)
        let extra = min(baseSeconds * max(0, event.expression.durationScale - 1), event.expression.maxDurationExtraSeconds)
        return min(max(0.04, baseSeconds + extra), 8)
    }

    private func soundDuration(
        for duration: MusicalTime,
        event: PlaybackEvent,
        tempo: Double
    ) -> Double {
        let eventDuration = nominalSeconds(for: event, tempo: tempo)
        let pitchDuration = seconds(for: duration, tempo: tempo)
        let extendsBeyondEvent = duration > event.nominalDuration
        let baseSoundWindow = extendsBeyondEvent ? pitchDuration : min(eventDuration, pitchDuration)
        let soundWindow = extendsBeyondEvent
            ? baseSoundWindow
            : expressionExtendedDuration(baseSoundWindow, for: event)
        let gatedDuration = extendsBeyondEvent
            ? soundWindow
            : soundWindow * event.expression.gateScale
        let minimumDuration = min(soundWindow, 0.04)
        let maximumDuration: Double
        if !extendsBeyondEvent, event.expression.gateScale > 1 {
            maximumDuration = min(max(soundWindow, gatedDuration), soundWindow + 0.08)
        } else {
            maximumDuration = soundWindow
        }
        return min(maximumDuration, max(minimumDuration, gatedDuration))
    }

    private func expressionExtendedDuration(_ duration: Double, for event: PlaybackEvent) -> Double {
        guard event.expression.durationScale > 1, duration.isFinite, duration > 0 else {
            return duration
        }
        let extra = min(
            duration * (event.expression.durationScale - 1),
            event.expression.maxDurationExtraSeconds
        )
        return min(max(duration, duration + extra), 9)
    }

    private func seconds(for duration: MusicalTime, tempo: Double) -> Double {
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        return quarters * 60 / tempo
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
