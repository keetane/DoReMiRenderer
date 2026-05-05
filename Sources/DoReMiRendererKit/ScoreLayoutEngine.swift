import CoreGraphics

public enum DisplayMode: Hashable, Codable, Sendable {
    case print
    case horizontal
    case verticalPractice
}

public struct LayoutOptions: Sendable {
    public var pageWidth: CGFloat
    public var pageHeight: CGFloat?
    public var staffSpace: CGFloat
    public var systemSpacing: CGFloat
    public var measureSpacing: CGFloat
    public var displayMode: DisplayMode
    public var showPageMargins: Bool
    public var unsupportedFeaturePolicy: UnsupportedFeaturePolicy

    public init(
        pageWidth: CGFloat = 800,
        pageHeight: CGFloat? = nil,
        staffSpace: CGFloat = 10,
        systemSpacing: CGFloat = 72,
        measureSpacing: CGFloat = 28,
        displayMode: DisplayMode = .print,
        showPageMargins: Bool = false,
        unsupportedFeaturePolicy: UnsupportedFeaturePolicy = .ignoreWithWarning
    ) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.staffSpace = staffSpace
        self.systemSpacing = systemSpacing
        self.measureSpacing = measureSpacing
        self.displayMode = displayMode
        self.showPageMargins = showPageMargins
        self.unsupportedFeaturePolicy = unsupportedFeaturePolicy
    }

    public static let `default` = LayoutOptions()
}

public enum LayoutError: Error, Equatable, Sendable {
    case unsupportedDisplayMode(DisplayMode)
}

public struct ScoreLayoutResult: Sendable {
    public let layout: ScoreLayout
    public let diagnostics: [RendererDiagnostic]

    init(layout: ScoreLayout, diagnostics: [RendererDiagnostic]) {
        self.layout = layout
        self.diagnostics = diagnostics
    }
}

struct ScoreLayoutEngine: Sendable {
    init() {}

    func layout(score: ScoreDocument, options: LayoutOptions = .default) throws -> ScoreLayout {
        try layoutWithDiagnostics(score: score, options: options).layout
    }

    func layoutWithDiagnostics(score: ScoreDocument, options: LayoutOptions = .default) throws -> ScoreLayoutResult {
        var diagnostics: [RendererDiagnostic] = []
        switch options.displayMode {
        case .print:
            break
        case .horizontal, .verticalPractice:
            if options.unsupportedFeaturePolicy == .fail {
                throw LayoutError.unsupportedDisplayMode(options.displayMode)
            }
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "unsupported.displayMode",
                message: "\(options.displayMode) display mode is not supported in Phase 3; falling back to print layout.",
                location: nil
            ))
        }

        let metrics = LayoutMetrics(options: options)
        var systems: [SystemLayout] = []
        var staves: [StaffLayout] = []
        var measures: [MeasureLayout] = []
        var elements: [ElementLayout] = []
        var noteByID: [NoteID: NoteLayout] = [:]
        var staffLines: [StaffLineLayout] = []
        var ledgerLines: [LedgerLineLayout] = []
        var annotationMaxY: CGFloat = 0

        let staffIDs = orderedStaffIDs(in: score)
        let staffIndexByID = Dictionary(uniqueKeysWithValues: staffIDs.enumerated().map { ($0.element, $0.offset) })
        let contentWidth = max(metrics.minimumMeasureWidth, options.pageWidth - metrics.leftMargin - metrics.rightMargin)
        let systemTop = metrics.topMargin
        let systemHeight = CGFloat(max(staffIDs.count, 1) - 1) * metrics.staffGap + metrics.staffHeight

        systems.append(
            SystemLayout(
                index: 0,
                frame: CGRect(x: metrics.leftMargin, y: systemTop, width: contentWidth, height: systemHeight),
                staffIDs: staffIDs
            )
        )

        for (staffIndex, staffID) in staffIDs.enumerated() {
            let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndex)
            staves.append(
                StaffLayout(
                    staffID: staffID,
                    systemIndex: 0,
                    frame: CGRect(
                        x: metrics.leftMargin,
                        y: middleY - 2 * options.staffSpace,
                        width: contentWidth,
                        height: metrics.staffHeight
                    ),
                    middleLineY: middleY
                )
            )
        }

        var measureX = metrics.leftMargin
        let flatMeasures = score.parts.enumerated().flatMap { partIndex, part in
            part.measures.enumerated().map { measureIndex, measure in
                (partIndex: partIndex, measureIndex: measureIndex, measure: measure)
            }
        }
        diagnostics.append(contentsOf: complexVoiceDiagnostics(in: flatMeasures.map(\.measure)))

        for item in flatMeasures {
            let measureWidth = width(for: item.measure, options: options, metrics: metrics)
            let measureFrame = CGRect(x: measureX, y: systemTop, width: measureWidth, height: systemHeight)
            let measureLayout = MeasureLayout(
                measureID: item.measure.id,
                systemIndex: 0,
                frame: measureFrame,
                partIndex: item.partIndex,
                measureIndex: item.measureIndex
            )
            measures.append(measureLayout)

            for staffID in staffIDs {
                let clef = clef(for: staffID, in: item.measure)
                let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndexByID[staffID] ?? 0)
                for lineIndex in 0..<5 {
                    let y = middleY + CGFloat(2 - lineIndex) * options.staffSpace
                    let id = ScoreElementID(rawValue: "\(staffID.rawValue).\(item.measure.id.rawValue).staffLine.\(lineIndex)")
                    let frame = CGRect(x: measureX, y: y - metrics.staffLineHitHalfWidth, width: measureWidth, height: metrics.staffLineHitHalfWidth * 2)
                    let staffLine = StaffLineLayout(
                        id: id,
                        staffID: staffID,
                        measureID: item.measure.id,
                        lineIndex: lineIndex,
                        clefKind: clef.kind,
                        pitchClassHint: staffLinePitchClass(clefKind: clef.kind, lineIndex: lineIndex),
                        start: CGPoint(x: measureX, y: y),
                        end: CGPoint(x: measureX + measureWidth, y: y),
                        frame: frame
                    )
                    staffLines.append(staffLine)
                    elements.append(
                        ElementLayout(
                            id: id,
                            kind: .staffLine,
                            measureID: item.measure.id,
                            staffID: staffID,
                            clef: clef,
                            pitchClassHint: staffLine.pitchClassHint,
                            frame: frame,
                            staffLine: staffLine
                        )
                    )
                }
            }

            for staffID in staffIDs {
                let clef = clef(for: staffID, in: item.measure)
                let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndexByID[staffID] ?? 0)
                for keyElement in keySignatureElements(
                    keySignature: item.measure.keySignature,
                    measure: item.measure,
                    staffID: staffID,
                    clef: clef,
                    middleY: middleY,
                    measureX: measureX,
                    metrics: metrics
                ) {
                    elements.append(keyElement)
                }
            }

            let onsetX = xCoordinatesByOnset(for: item.measure, measureX: measureX, measureWidth: measureWidth, metrics: metrics)
            for note in item.measure.notes {
                let clef = clef(for: note.staffID, in: item.measure)
                let staffIndex = staffIndexByID[note.staffID] ?? 0
                let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndex)
                let position = note.pitch.map { staffPosition(pitch: $0, clef: clef) }
                let center = CGPoint(
                    x: onsetX[note.onset] ?? (measureX + metrics.noteInset),
                    y: middleY - CGFloat(position?.stepsFromMiddleLine ?? 0) * options.staffSpace / 2
                )
                let noteFrame = CGRect(
                    x: center.x - metrics.noteheadSize.width / 2,
                    y: center.y - metrics.noteheadSize.height / 2,
                    width: metrics.noteheadSize.width,
                    height: metrics.noteheadSize.height
                )
                let noteElementKind: ScoreElementKind = note.pitch == nil ? .rest : .notehead
                let noteElementID = ScoreElementID(rawValue: "\(note.id.rawValue).\(noteElementKind == .rest ? "rest" : "notehead")")
                let noteLayout = NoteLayout(
                    noteID: note.id,
                    measureID: item.measure.id,
                    staffID: note.staffID,
                    voiceID: note.voiceID,
                    clef: clef,
                    pitch: note.pitch,
                    staffPosition: position,
                    noteheadElementID: noteElementID,
                    noteheadCenter: center,
                    noteheadFrame: noteFrame
                )
                noteByID[note.id] = noteLayout
                elements.append(
                    ElementLayout(
                        id: noteElementID,
                        kind: noteElementKind,
                        noteID: note.id,
                        measureID: item.measure.id,
                        staffID: note.staffID,
                        voiceID: note.voiceID,
                        clef: clef,
                        keySignature: item.measure.keySignature,
                        timeSignature: item.measure.timeSignature,
                        pitchClassHint: note.pitch?.pitchClass,
                        frame: noteFrame,
                        noteLayout: noteLayout
                    )
                )

                guard let pitch = note.pitch, let position else {
                    continue
                }

                let stemElementID = ScoreElementID(rawValue: "\(note.id.rawValue).stem")
                let stemFrame = CGRect(
                    x: noteFrame.maxX - max(1, noteFrame.width * 0.1),
                    y: center.y - noteFrame.height * 3.2,
                    width: max(2, noteFrame.width * 0.2),
                    height: noteFrame.height * 3.2
                )
                elements.append(
                    ElementLayout(
                        id: stemElementID,
                        kind: .stem,
                        noteID: note.id,
                        measureID: item.measure.id,
                        staffID: note.staffID,
                        voiceID: note.voiceID,
                        clef: clef,
                        keySignature: item.measure.keySignature,
                        timeSignature: item.measure.timeSignature,
                        pitchClassHint: pitch.pitchClass,
                        frame: stemFrame,
                        noteLayout: noteLayout
                    )
                )

                if note.accidental != nil {
                    let accidentalElementID = ScoreElementID(rawValue: "\(note.id.rawValue).accidental")
                    let accidentalFrame = CGRect(
                        x: noteFrame.minX - noteFrame.width * 1.6,
                        y: noteFrame.minY - noteFrame.height * 0.25,
                        width: noteFrame.width,
                        height: noteFrame.height * 1.5
                    )
                    elements.append(
                        ElementLayout(
                            id: accidentalElementID,
                            kind: .accidental,
                            noteID: note.id,
                            measureID: item.measure.id,
                            staffID: note.staffID,
                            voiceID: note.voiceID,
                            clef: clef,
                            keySignature: item.measure.keySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: pitch.pitchClass,
                            frame: accidentalFrame,
                            noteLayout: noteLayout,
                            accidental: note.accidental
                        )
                    )
                }

                for (lyricIndex, lyric) in note.lyrics.enumerated() where !lyric.text.isEmpty {
                    let annotation = annotationLayout(
                        id: ScoreElementID(rawValue: "\(note.id.rawValue).lyric.\(lyricIndex)"),
                        noteID: note.id,
                        text: lyric.text,
                        center: center,
                        measure: item.measure,
                        staffID: note.staffID,
                        kind: .lyric,
                        index: lyricIndex,
                        metrics: metrics
                    )
                    annotationMaxY = max(annotation.frame.maxY, annotationMaxY)
                    elements.append(
                        ElementLayout(
                            id: annotation.id,
                            kind: .lyric,
                            noteID: note.id,
                            measureID: item.measure.id,
                            staffID: note.staffID,
                            voiceID: note.voiceID,
                            clef: clef,
                            keySignature: item.measure.keySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: pitch.pitchClass,
                            frame: annotation.frame,
                            noteLayout: noteLayout,
                            annotation: annotation
                        )
                    )
                }

                for (fingeringIndex, fingering) in note.fingerings.enumerated() where !fingering.text.isEmpty {
                    let annotation = fingeringLayout(
                        id: ScoreElementID(rawValue: "\(note.id.rawValue).fingering.\(fingeringIndex)"),
                        noteID: note.id,
                        text: fingering.text,
                        center: center,
                        measure: item.measure,
                        staffID: note.staffID,
                        metrics: metrics
                    )
                    annotationMaxY = max(annotation.frame.maxY, annotationMaxY)
                    elements.append(
                        ElementLayout(
                            id: annotation.id,
                            kind: .fingering,
                            noteID: note.id,
                            measureID: item.measure.id,
                            staffID: note.staffID,
                            voiceID: note.voiceID,
                            clef: clef,
                            keySignature: item.measure.keySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: pitch.pitchClass,
                            frame: annotation.frame,
                            noteLayout: noteLayout,
                            annotation: annotation
                        )
                    )
                }

                let noteLedgerLines = ledgerLinesForNote(
                    note,
                    pitch: pitch,
                    position: position,
                    center: center,
                    measure: item.measure,
                    clef: clef,
                    metrics: metrics
                )
                ledgerLines.append(contentsOf: noteLedgerLines)
                for ledgerLine in noteLedgerLines {
                    elements.append(
                        ElementLayout(
                            id: ledgerLine.id,
                            kind: .ledgerLine,
                            noteID: note.id,
                            measureID: item.measure.id,
                            staffID: note.staffID,
                            voiceID: note.voiceID,
                            clef: clef,
                            keySignature: item.measure.keySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: ledgerLine.pitchClassHint,
                            frame: ledgerLine.frame,
                            ledgerLine: ledgerLine
                        )
                    )
                }
            }

            measureX += measureWidth + options.measureSpacing
        }

        let elementByID = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
        let contentHeight = max(systemTop + systemHeight + metrics.bottomMargin, annotationMaxY + metrics.bottomMargin, options.pageHeight ?? 0)
        let canvasWidth = max(options.pageWidth, measureX + metrics.rightMargin - options.measureSpacing)

        let layout = ScoreLayout(
            canvasSize: CGSize(width: canvasWidth, height: contentHeight),
            systems: systems,
            staves: staves,
            measures: measures,
            elements: elements,
            staffLines: staffLines,
            ledgerLines: ledgerLines,
            noteByID: noteByID,
            elementByID: elementByID
        )
        return ScoreLayoutResult(layout: layout, diagnostics: diagnostics)
    }
}

public struct ScoreLayout: Sendable {
    public let canvasSize: CGSize
    public let systems: [SystemLayout]
    public let staves: [StaffLayout]
    public let measures: [MeasureLayout]
    public let elements: [ElementLayout]
    public let staffLines: [StaffLineLayout]
    public let ledgerLines: [LedgerLineLayout]
    public let noteByID: [NoteID: NoteLayout]
    public let elementByID: [ScoreElementID: ElementLayout]

    init(
        canvasSize: CGSize = .zero,
        systems: [SystemLayout] = [],
        staves: [StaffLayout] = [],
        measures: [MeasureLayout] = [],
        elements: [ElementLayout] = [],
        staffLines: [StaffLineLayout] = [],
        ledgerLines: [LedgerLineLayout] = [],
        noteByID: [NoteID: NoteLayout] = [:],
        elementByID: [ScoreElementID: ElementLayout] = [:]
    ) {
        self.canvasSize = canvasSize
        self.systems = systems
        self.staves = staves
        self.measures = measures
        self.elements = elements
        self.staffLines = staffLines
        self.ledgerLines = ledgerLines
        self.noteByID = noteByID
        self.elementByID = elementByID
    }

    public func noteLayout(for id: NoteID) -> NoteLayout? {
        noteByID[id]
    }

    public func elementLayout(for id: ScoreElementID) -> ElementLayout? {
        elementByID[id]
    }

}

public struct SystemLayout: Sendable {
    public let index: Int
    public let frame: CGRect
    public let staffIDs: [StaffID]

    init(index: Int, frame: CGRect = .zero, staffIDs: [StaffID] = []) {
        self.index = index
        self.frame = frame
        self.staffIDs = staffIDs
    }
}

public struct StaffLayout: Sendable {
    public let staffID: StaffID
    public let systemIndex: Int
    public let frame: CGRect
    public let middleLineY: CGFloat

    init(staffID: StaffID, systemIndex: Int, frame: CGRect = .zero, middleLineY: CGFloat = 0) {
        self.staffID = staffID
        self.systemIndex = systemIndex
        self.frame = frame
        self.middleLineY = middleLineY
    }
}

public struct MeasureLayout: Sendable {
    public let measureID: MeasureID
    public let systemIndex: Int
    public let frame: CGRect
    public let partIndex: Int
    public let measureIndex: Int

    init(
        measureID: MeasureID,
        systemIndex: Int,
        frame: CGRect = .zero,
        partIndex: Int = 0,
        measureIndex: Int = 0
    ) {
        self.measureID = measureID
        self.systemIndex = systemIndex
        self.frame = frame
        self.partIndex = partIndex
        self.measureIndex = measureIndex
    }
}

public struct NoteLayout: Sendable {
    public let noteID: NoteID
    public let measureID: MeasureID?
    public let staffID: StaffID?
    public let voiceID: VoiceID?
    public let clef: Clef?
    public let pitch: Pitch?
    public let staffPosition: StaffPosition?
    public let noteheadElementID: ScoreElementID?
    public let noteheadCenter: CGPoint
    public let noteheadFrame: CGRect

    init(
        noteID: NoteID,
        measureID: MeasureID? = nil,
        staffID: StaffID? = nil,
        voiceID: VoiceID? = nil,
        clef: Clef? = nil,
        pitch: Pitch? = nil,
        staffPosition: StaffPosition? = nil,
        noteheadElementID: ScoreElementID? = nil,
        noteheadCenter: CGPoint = .zero,
        noteheadFrame: CGRect = .zero
    ) {
        self.noteID = noteID
        self.measureID = measureID
        self.staffID = staffID
        self.voiceID = voiceID
        self.clef = clef
        self.pitch = pitch
        self.staffPosition = staffPosition
        self.noteheadElementID = noteheadElementID
        self.noteheadCenter = noteheadCenter
        self.noteheadFrame = noteheadFrame
    }
}

public struct ElementLayout: Sendable {
    public let id: ScoreElementID
    public let kind: ScoreElementKind
    public let noteID: NoteID?
    public let measureID: MeasureID?
    public let staffID: StaffID?
    public let voiceID: VoiceID?
    public let clef: Clef?
    public let keySignature: KeySignature?
    public let timeSignature: TimeSignature?
    public let pitchClassHint: PitchClass?
    public let frame: CGRect
    public let noteLayout: NoteLayout?
    public let staffLine: StaffLineLayout?
    public let ledgerLine: LedgerLineLayout?
    public let accidental: String?
    public let annotation: TextAnnotationLayout?

    init(
        id: ScoreElementID,
        kind: ScoreElementKind,
        noteID: NoteID? = nil,
        measureID: MeasureID? = nil,
        staffID: StaffID? = nil,
        voiceID: VoiceID? = nil,
        clef: Clef? = nil,
        keySignature: KeySignature? = nil,
        timeSignature: TimeSignature? = nil,
        pitchClassHint: PitchClass? = nil,
        frame: CGRect = .zero,
        noteLayout: NoteLayout? = nil,
        staffLine: StaffLineLayout? = nil,
        ledgerLine: LedgerLineLayout? = nil,
        accidental: String? = nil,
        annotation: TextAnnotationLayout? = nil
    ) {
        self.id = id
        self.kind = kind
        self.noteID = noteID
        self.measureID = measureID
        self.staffID = staffID
        self.voiceID = voiceID
        self.clef = clef
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.pitchClassHint = pitchClassHint
        self.frame = frame
        self.noteLayout = noteLayout
        self.staffLine = staffLine
        self.ledgerLine = ledgerLine
        self.accidental = accidental
        self.annotation = annotation
    }
}

public struct TextAnnotationLayout: Sendable {
    public let id: ScoreElementID
    public let noteID: NoteID
    public let text: String
    public let origin: CGPoint
    public let frame: CGRect

    init(id: ScoreElementID, noteID: NoteID, text: String, origin: CGPoint = .zero, frame: CGRect = .zero) {
        self.id = id
        self.noteID = noteID
        self.text = text
        self.origin = origin
        self.frame = frame
    }
}

public struct StaffLineLayout: Sendable {
    public let id: ScoreElementID
    public let staffID: StaffID
    public let measureID: MeasureID
    public let lineIndex: Int
    public let clefKind: ClefKind
    public let pitchClassHint: PitchClass?
    public let start: CGPoint
    public let end: CGPoint
    public let frame: CGRect

    init(
        id: ScoreElementID,
        staffID: StaffID,
        measureID: MeasureID,
        lineIndex: Int,
        clefKind: ClefKind,
        pitchClassHint: PitchClass? = nil,
        start: CGPoint = .zero,
        end: CGPoint = .zero,
        frame: CGRect = .zero
    ) {
        self.id = id
        self.staffID = staffID
        self.measureID = measureID
        self.lineIndex = lineIndex
        self.clefKind = clefKind
        self.pitchClassHint = pitchClassHint
        self.start = start
        self.end = end
        self.frame = frame
    }
}

public struct LedgerLineLayout: Sendable {
    public let id: ScoreElementID
    public let noteID: NoteID?
    public let measureID: MeasureID?
    public let staffID: StaffID?
    public let pitchClassHint: PitchClass?
    public let lineStepFromMiddle: Int
    public let start: CGPoint
    public let end: CGPoint
    public let frame: CGRect

    init(
        id: ScoreElementID,
        noteID: NoteID? = nil,
        measureID: MeasureID? = nil,
        staffID: StaffID? = nil,
        pitchClassHint: PitchClass? = nil,
        lineStepFromMiddle: Int = 0,
        start: CGPoint = .zero,
        end: CGPoint = .zero,
        frame: CGRect = .zero
    ) {
        self.id = id
        self.noteID = noteID
        self.measureID = measureID
        self.staffID = staffID
        self.pitchClassHint = pitchClassHint
        self.lineStepFromMiddle = lineStepFromMiddle
        self.start = start
        self.end = end
        self.frame = frame
    }
}

private struct LayoutMetrics {
    let leftMargin: CGFloat
    let rightMargin: CGFloat
    let topMargin: CGFloat
    let bottomMargin: CGFloat
    let staffHeight: CGFloat
    let staffGap: CGFloat
    let noteheadSize: CGSize
    let noteInset: CGFloat
    let minimumMeasureWidth: CGFloat
    let staffLineHitHalfWidth: CGFloat
    let ledgerLineWidth: CGFloat
    let staffSpace: CGFloat

    init(options: LayoutOptions) {
        leftMargin = options.showPageMargins ? 48 : 24
        rightMargin = options.showPageMargins ? 48 : 24
        topMargin = options.showPageMargins ? 48 : 32
        bottomMargin = options.showPageMargins ? 48 : 32
        staffHeight = options.staffSpace * 4
        staffGap = max(options.systemSpacing, options.staffSpace * 8)
        noteheadSize = CGSize(width: options.staffSpace * 1.35, height: options.staffSpace)
        noteInset = options.staffSpace * 3
        minimumMeasureWidth = options.staffSpace * 12
        staffLineHitHalfWidth = max(1, options.staffSpace * 0.08)
        ledgerLineWidth = options.staffSpace * 2.1
        staffSpace = options.staffSpace
    }

    func staffMiddleY(systemTop: CGFloat, staffIndex: Int) -> CGFloat {
        systemTop + 2 * staffHeight / 4 + CGFloat(staffIndex) * staffGap
    }
}

private func orderedStaffIDs(in score: ScoreDocument) -> [StaffID] {
    var ids: [StaffID] = []
    for part in score.parts {
        for measure in part.measures {
            for note in measure.notes where !ids.contains(note.staffID) {
                ids.append(note.staffID)
            }
        }
    }
    return ids.isEmpty ? [StaffID(rawValue: "1")] : ids.sorted { $0.rawValue.localizedStandardCompare($1.rawValue) == .orderedAscending }
}

private func clef(for staffID: StaffID, in measure: Measure) -> Clef {
    if let clef = measure.clefsByStaff[staffID] {
        return clef
    }
    if let clef = measure.clef {
        return clef
    }
    return staffID.rawValue == "2" ? Clef(kind: .bass) : Clef(kind: .treble)
}

private func width(for measure: Measure, options: LayoutOptions, metrics: LayoutMetrics) -> CGFloat {
    let uniqueOnsets = Set(measure.notes.map(\.onset)).count
    let onsetWidth = CGFloat(max(uniqueOnsets, 1)) * options.staffSpace * 5
    return max(metrics.minimumMeasureWidth, onsetWidth + metrics.noteInset * 2)
}

private func xCoordinatesByOnset(
    for measure: Measure,
    measureX: CGFloat,
    measureWidth: CGFloat,
    metrics: LayoutMetrics
) -> [MusicalTime: CGFloat] {
    let onsets = Array(Set(measure.notes.map(\.onset))).sorted()
    guard !onsets.isEmpty else {
        return [:]
    }

    let prefixWidth = keySignaturePrefixWidth(for: measure.keySignature, metrics: metrics)
    let startX = measureX + metrics.noteInset + prefixWidth

    if onsets.count == 1 {
        return [onsets[0]: startX]
    }

    let usableWidth = max(0, measureWidth - metrics.noteInset * 2 - prefixWidth)
    let stepWidth = usableWidth / CGFloat(onsets.count - 1)
    return Dictionary(uniqueKeysWithValues: onsets.enumerated().map { index, onset in
        (onset, startX + CGFloat(index) * stepWidth)
    })
}

private func keySignaturePrefixWidth(for keySignature: KeySignature?, metrics: LayoutMetrics) -> CGFloat {
    guard let keySignature else {
        return 0
    }
    return CGFloat(min(abs(keySignature.fifths), 7)) * metrics.staffSpace * 1.15
}

private func keySignatureElements(
    keySignature: KeySignature?,
    measure: Measure,
    staffID: StaffID,
    clef: Clef,
    middleY: CGFloat,
    measureX: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    guard let keySignature, keySignature.fifths != 0 else {
        return []
    }

    let accidental = keySignature.fifths > 0 ? "sharp" : "flat"
    let pitches = keySignaturePitches(fifths: keySignature.fifths, clef: clef)
    return pitches.enumerated().map { index, pitch in
        let position = staffPosition(pitch: pitch, clef: clef)
        let center = CGPoint(
            x: measureX + metrics.staffSpace * 2.0 + CGFloat(index) * metrics.staffSpace * 1.15,
            y: middleY - CGFloat(position.stepsFromMiddleLine) * metrics.staffSpace / 2
        )
        let frame = CGRect(
            x: center.x - metrics.noteheadSize.width * 0.45,
            y: center.y - metrics.noteheadSize.height * 0.75,
            width: metrics.noteheadSize.width * 0.9,
            height: metrics.noteheadSize.height * 1.5
        )
        return ElementLayout(
            id: ScoreElementID(rawValue: "\(staffID.rawValue).\(measure.id.rawValue).keySignature.\(index)"),
            kind: .keySignature,
            measureID: measure.id,
            staffID: staffID,
            clef: clef,
            keySignature: keySignature,
            pitchClassHint: pitch.pitchClass,
            frame: frame,
            accidental: accidental
        )
    }
}

private func keySignaturePitches(fifths: Int, clef: Clef) -> [Pitch] {
    let count = min(abs(fifths), 7)
    if fifths > 0 {
        let treble = [
            Pitch(step: .f, octave: 5), Pitch(step: .c, octave: 5), Pitch(step: .g, octave: 5),
            Pitch(step: .d, octave: 5), Pitch(step: .a, octave: 4), Pitch(step: .e, octave: 5),
            Pitch(step: .b, octave: 4),
        ]
        let bass = [
            Pitch(step: .f, octave: 3), Pitch(step: .c, octave: 3), Pitch(step: .g, octave: 3),
            Pitch(step: .d, octave: 3), Pitch(step: .a, octave: 2), Pitch(step: .e, octave: 3),
            Pitch(step: .b, octave: 2),
        ]
        return Array((clef.kind == .bass ? bass : treble).prefix(count))
    }

    let treble = [
        Pitch(step: .b, octave: 4), Pitch(step: .e, octave: 5), Pitch(step: .a, octave: 4),
        Pitch(step: .d, octave: 5), Pitch(step: .g, octave: 4), Pitch(step: .c, octave: 5),
        Pitch(step: .f, octave: 4),
    ]
    let bass = [
        Pitch(step: .b, octave: 2), Pitch(step: .e, octave: 3), Pitch(step: .a, octave: 2),
        Pitch(step: .d, octave: 3), Pitch(step: .g, octave: 2), Pitch(step: .c, octave: 3),
        Pitch(step: .f, octave: 2),
    ]
    return Array((clef.kind == .bass ? bass : treble).prefix(count))
}

private func annotationLayout(
    id: ScoreElementID,
    noteID: NoteID,
    text: String,
    center: CGPoint,
    measure: Measure,
    staffID: StaffID,
    kind: ScoreElementKind,
    index: Int,
    metrics: LayoutMetrics
) -> TextAnnotationLayout {
    let width = max(metrics.staffSpace * 2.4, CGFloat(text.count) * metrics.staffSpace * 0.65)
    let height = metrics.staffSpace * 1.5
    let y = center.y + metrics.staffSpace * (4.2 + CGFloat(index) * 1.6)
    let frame = CGRect(x: center.x - width / 2, y: y, width: width, height: height)
    return TextAnnotationLayout(
        id: id,
        noteID: noteID,
        text: text,
        origin: CGPoint(x: frame.minX, y: frame.minY + height * 0.75),
        frame: frame
    )
}

private func fingeringLayout(
    id: ScoreElementID,
    noteID: NoteID,
    text: String,
    center: CGPoint,
    measure: Measure,
    staffID: StaffID,
    metrics: LayoutMetrics
) -> TextAnnotationLayout {
    let width = max(metrics.staffSpace * 1.2, CGFloat(text.count) * metrics.staffSpace * 0.7)
    let height = metrics.staffSpace * 1.3
    let frame = CGRect(
        x: center.x - width / 2,
        y: center.y - metrics.staffSpace * 4.0,
        width: width,
        height: height
    )
    return TextAnnotationLayout(
        id: id,
        noteID: noteID,
        text: text,
        origin: CGPoint(x: frame.minX, y: frame.minY + height * 0.75),
        frame: frame
    )
}

private func ledgerLinesForNote(
    _ note: ScoreNote,
    pitch: Pitch,
    position: StaffPosition,
    center: CGPoint,
    measure: Measure,
    clef: Clef,
    metrics: LayoutMetrics
) -> [LedgerLineLayout] {
    let steps = position.stepsFromMiddleLine
    let ledgerSteps: [Int]
    if steps <= -6 {
        ledgerSteps = Array(stride(from: -6, through: steps, by: -2))
    } else if steps >= 6 {
        ledgerSteps = Array(stride(from: 6, through: steps, by: 2))
    } else {
        ledgerSteps = []
    }

    return ledgerSteps.map { lineStep in
        let y = center.y + CGFloat(steps - lineStep) * metrics.staffSpace / 2
        let start = CGPoint(x: center.x - metrics.ledgerLineWidth / 2, y: y)
        let end = CGPoint(x: center.x + metrics.ledgerLineWidth / 2, y: y)
        let frame = CGRect(x: start.x, y: y - metrics.staffLineHitHalfWidth, width: metrics.ledgerLineWidth, height: metrics.staffLineHitHalfWidth * 2)
        return LedgerLineLayout(
            id: ScoreElementID(rawValue: "\(note.id.rawValue).ledgerLine.\(lineStep)"),
            noteID: note.id,
            measureID: measure.id,
            staffID: note.staffID,
            pitchClassHint: pitch.pitchClass,
            lineStepFromMiddle: lineStep,
            start: start,
            end: end,
            frame: frame
        )
    }
}

private func complexVoiceDiagnostics(in measures: [Measure]) -> [RendererDiagnostic] {
    var diagnostics: [RendererDiagnostic] = []
    for measure in measures {
        let groupedByStaffOnset = Dictionary(grouping: measure.notes) { note in
            "\(note.staffID.rawValue).\(note.onset.ticks).\(note.onset.ticksPerQuarterNote)"
        }
        if groupedByStaffOnset.values.contains(where: { Set($0.map(\.voiceID)).count > 1 }) {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "unsupported.voice.collisionAvoidance",
                message: "Multiple voices share a staff and onset; advanced collision avoidance is not supported in Phase 11F.",
                location: MusicXMLLocation(elementName: "note", measureNumber: measure.number)
            ))
        }

        let groupedByVoice = Dictionary(grouping: measure.notes) { $0.voiceID }
        if groupedByVoice.values.contains(where: { Set($0.map(\.staffID)).count > 1 }) {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "unsupported.crossStaff.notation",
                message: "A voice appears on multiple staves; cross-staff beam/stem notation is not supported in Phase 11F.",
                location: MusicXMLLocation(elementName: "staff", measureNumber: measure.number)
            ))
        }
    }
    return diagnostics
}
