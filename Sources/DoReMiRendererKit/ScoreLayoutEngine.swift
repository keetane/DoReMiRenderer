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
                elements.append(contentsOf: prefixElements(
                    measure: item.measure,
                    staffID: staffID,
                    clef: clef,
                    middleY: middleY,
                    measureX: measureX,
                    metrics: metrics
                ))
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
            let chordStemDirections = chordStemDirections(for: item.measure)
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
                    duration: note.duration,
                    noteValueKind: note.noteValueKind,
                    dotCount: note.dotCount,
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

                appendDotsIfNeeded(
                    for: note,
                    noteLayout: noteLayout,
                    noteFrame: noteFrame,
                    measureID: item.measure.id,
                    clef: clef,
                    elements: &elements
                )

                guard let pitch = note.pitch, let position else {
                    continue
                }

                if note.noteValueKind.drawsStem {
                    let stemElementID = ScoreElementID(rawValue: "\(note.id.rawValue).stem")
                    let stemDirection = chordStemDirections[ChordStemKey(note)] ?? stemDirection(for: position)
                    let stemFrame = stemFrame(
                        direction: stemDirection,
                        noteFrame: noteFrame,
                        noteheadCenter: center
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

                    if note.noteValueKind.flagCount > 0 {
                        let flagElementID = ScoreElementID(rawValue: "\(note.id.rawValue).flag")
                        let flagFrame = flagFrame(
                            direction: stemDirection,
                            stemFrame: stemFrame,
                            noteFrame: noteFrame
                        )
                        elements.append(
                            ElementLayout(
                                id: flagElementID,
                                kind: .flag,
                                noteID: note.id,
                                measureID: item.measure.id,
                                staffID: note.staffID,
                                voiceID: note.voiceID,
                                clef: clef,
                                keySignature: item.measure.keySignature,
                                timeSignature: item.measure.timeSignature,
                                pitchClassHint: pitch.pitchClass,
                                frame: flagFrame,
                                noteLayout: noteLayout
                            )
                        )
                    }
                }

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

            elements.append(contentsOf: barlineElements(
                measure: item.measure,
                staffIDs: staffIDs,
                staffIndexByID: staffIndexByID,
                measureX: measureX,
                measureWidth: measureWidth,
                systemTop: systemTop,
                metrics: metrics
            ))

            measureX += measureWidth + options.measureSpacing
        }

        let renderBoundsPadding: CGFloat = 0
        var renderBounds = drawingBounds(
            elements: elements,
            staffLines: staffLines,
            ledgerLines: ledgerLines,
            noteByID: noteByID,
            padding: renderBoundsPadding
        )
        let originOffset = CGPoint(
            x: max(0, -renderBounds.minX),
            y: max(0, -renderBounds.minY)
        )
        if originOffset != .zero {
            systems = systems.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            staves = staves.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            measures = measures.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            elements = elements.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            staffLines = staffLines.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            ledgerLines = ledgerLines.map { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            noteByID = noteByID.mapValues { $0.offsetBy(dx: originOffset.x, dy: originOffset.y) }
            annotationMaxY += originOffset.y
            renderBounds = drawingBounds(
                elements: elements,
                staffLines: staffLines,
                ledgerLines: ledgerLines,
                noteByID: noteByID,
                padding: renderBoundsPadding
            )
        }
        let elementByID = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
        let contentHeight = max(
            systems.map(\.frame.maxY).max().map { $0 + metrics.bottomMargin } ?? 0,
            annotationMaxY + metrics.bottomMargin,
            renderBounds.maxY + metrics.bottomMargin,
            options.pageHeight ?? 0
        )
        let canvasWidth = max(
            options.pageWidth,
            measureX + metrics.rightMargin - options.measureSpacing,
            renderBounds.maxX + metrics.rightMargin
        )

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

    private func chordStemDirections(for measure: Measure) -> [ChordStemKey: StemDirection] {
        let pitchedNotes = measure.notes.filter { $0.pitch != nil }
        let grouped = Dictionary(grouping: pitchedNotes, by: ChordStemKey.init)
        var directions: [ChordStemKey: StemDirection] = [:]

        for (key, notes) in grouped where notes.count > 1 {
            let steps = notes.compactMap { note -> Int? in
                guard let pitch = note.pitch else {
                    return nil
                }
                return staffPosition(pitch: pitch, clef: clef(for: note.staffID, in: measure)).stepsFromMiddleLine
            }
            guard !steps.isEmpty else {
                continue
            }
            let averageSteps = Double(steps.reduce(0, +)) / Double(steps.count)
            directions[key] = averageSteps < 0 ? .up : .down
        }

        return directions
    }

    private func stemDirection(for position: StaffPosition) -> StemDirection {
        position.stepsFromMiddleLine < 0 ? .up : .down
    }

    private func stemFrame(
        direction: StemDirection,
        noteFrame: CGRect,
        noteheadCenter center: CGPoint
    ) -> CGRect {
        let width = max(2, noteFrame.width * 0.2)
        let length = noteFrame.height * 3.2
        switch direction {
        case .up:
            return CGRect(
                x: noteFrame.maxX - width * 0.55,
                y: center.y - length,
                width: width,
                height: length
            )
        case .down:
            return CGRect(
                x: noteFrame.minX - width * 0.45,
                y: center.y,
                width: width,
                height: length
            )
        }
    }

    private func flagFrame(
        direction: StemDirection,
        stemFrame: CGRect,
        noteFrame: CGRect
    ) -> CGRect {
        switch direction {
        case .up:
            return CGRect(
                x: stemFrame.midX,
                y: stemFrame.minY,
                width: noteFrame.width * 0.9,
                height: noteFrame.height * 1.5
            )
        case .down:
            return CGRect(
                x: stemFrame.midX - noteFrame.width * 0.9,
                y: stemFrame.maxY - noteFrame.height * 1.5,
                width: noteFrame.width * 0.9,
                height: noteFrame.height * 1.5
            )
        }
    }

    private func appendDotsIfNeeded(
        for note: ScoreNote,
        noteLayout: NoteLayout,
        noteFrame: CGRect,
        measureID: MeasureID,
        clef: Clef,
        elements: inout [ElementLayout]
    ) {
        guard note.dotCount > 0 else {
            return
        }

        let dotSize = max(2, noteFrame.height * 0.28)
        for index in 0..<note.dotCount {
            let dotFrame = CGRect(
                x: noteFrame.maxX + noteFrame.width * 0.45 + CGFloat(index) * dotSize * 1.8,
                y: noteFrame.midY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            elements.append(
                ElementLayout(
                    id: ScoreElementID(rawValue: "\(note.id.rawValue).dot.\(index)"),
                    kind: .dot,
                    noteID: note.id,
                    measureID: measureID,
                    staffID: note.staffID,
                    voiceID: note.voiceID,
                    clef: clef,
                    pitchClassHint: note.pitch?.pitchClass,
                    frame: dotFrame,
                    noteLayout: noteLayout
                )
            )
        }
    }

    private func drawingBounds(
        elements: [ElementLayout],
        staffLines: [StaffLineLayout],
        ledgerLines: [LedgerLineLayout],
        noteByID: [NoteID: NoteLayout],
        padding: CGFloat
    ) -> CGRect {
        var bounds = CGRect.null
        for element in elements {
            bounds = bounds.union(element.frame)
        }
        for staffLine in staffLines {
            bounds = bounds.union(staffLine.frame)
        }
        for ledgerLine in ledgerLines {
            bounds = bounds.union(ledgerLine.frame)
        }
        for noteLayout in noteByID.values {
            bounds = bounds.union(noteLayout.noteheadFrame)
        }
        guard !bounds.isNull,
              bounds.origin.x.isFinite,
              bounds.origin.y.isFinite,
              bounds.size.width.isFinite,
              bounds.size.height.isFinite
        else {
            return .zero
        }
        return bounds.insetBy(dx: -padding, dy: -padding)
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> SystemLayout {
        SystemLayout(index: index, frame: frame.offsetBy(dx: dx, dy: dy), staffIDs: staffIDs)
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> StaffLayout {
        StaffLayout(
            staffID: staffID,
            systemIndex: systemIndex,
            frame: frame.offsetBy(dx: dx, dy: dy),
            middleLineY: middleLineY + dy
        )
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> MeasureLayout {
        MeasureLayout(
            measureID: measureID,
            systemIndex: systemIndex,
            frame: frame.offsetBy(dx: dx, dy: dy),
            partIndex: partIndex,
            measureIndex: measureIndex
        )
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
    public let duration: MusicalTime?
    public let noteValueKind: NoteValueKind
    public let dotCount: Int
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
        duration: MusicalTime? = nil,
        noteValueKind: NoteValueKind = .quarter,
        dotCount: Int = 0,
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
        self.duration = duration
        self.noteValueKind = noteValueKind
        self.dotCount = max(0, dotCount)
        self.noteheadElementID = noteheadElementID
        self.noteheadCenter = noteheadCenter
        self.noteheadFrame = noteheadFrame
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> NoteLayout {
        NoteLayout(
            noteID: noteID,
            measureID: measureID,
            staffID: staffID,
            voiceID: voiceID,
            clef: clef,
            pitch: pitch,
            staffPosition: staffPosition,
            duration: duration,
            noteValueKind: noteValueKind,
            dotCount: dotCount,
            noteheadElementID: noteheadElementID,
            noteheadCenter: CGPoint(x: noteheadCenter.x + dx, y: noteheadCenter.y + dy),
            noteheadFrame: noteheadFrame.offsetBy(dx: dx, dy: dy)
        )
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
    public let repeatBarline: RepeatBarline?

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
        annotation: TextAnnotationLayout? = nil,
        repeatBarline: RepeatBarline? = nil
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
        self.repeatBarline = repeatBarline
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> ElementLayout {
        ElementLayout(
            id: id,
            kind: kind,
            noteID: noteID,
            measureID: measureID,
            staffID: staffID,
            voiceID: voiceID,
            clef: clef,
            keySignature: keySignature,
            timeSignature: timeSignature,
            pitchClassHint: pitchClassHint,
            frame: frame.offsetBy(dx: dx, dy: dy),
            noteLayout: noteLayout?.offsetBy(dx: dx, dy: dy),
            staffLine: staffLine?.offsetBy(dx: dx, dy: dy),
            ledgerLine: ledgerLine?.offsetBy(dx: dx, dy: dy),
            accidental: accidental,
            annotation: annotation?.offsetBy(dx: dx, dy: dy),
            repeatBarline: repeatBarline
        )
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> TextAnnotationLayout {
        TextAnnotationLayout(
            id: id,
            noteID: noteID,
            text: text,
            origin: CGPoint(x: origin.x + dx, y: origin.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
        )
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> StaffLineLayout {
        StaffLineLayout(
            id: id,
            staffID: staffID,
            measureID: measureID,
            lineIndex: lineIndex,
            clefKind: clefKind,
            pitchClassHint: pitchClassHint,
            start: CGPoint(x: start.x + dx, y: start.y + dy),
            end: CGPoint(x: end.x + dx, y: end.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
        )
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

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> LedgerLineLayout {
        LedgerLineLayout(
            id: id,
            noteID: noteID,
            measureID: measureID,
            staffID: staffID,
            pitchClassHint: pitchClassHint,
            lineStepFromMiddle: lineStepFromMiddle,
            start: CGPoint(x: start.x + dx, y: start.y + dy),
            end: CGPoint(x: end.x + dx, y: end.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
        )
    }
}

private extension NoteValueKind {
    var drawsStem: Bool {
        switch self {
        case .whole:
            false
        case .half, .quarter, .eighth, .sixteenth, .other:
            true
        }
    }

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

private enum StemDirection {
    case up
    case down
}

private struct ChordStemKey: Hashable {
    let staffID: StaffID
    let voiceID: VoiceID
    let onset: MusicalTime

    init(_ note: ScoreNote) {
        self.staffID = note.staffID
        self.voiceID = note.voiceID
        self.onset = note.onset
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
    let timeWidth: CGFloat = measure.timeSignature == nil ? 0 : metrics.staffSpace * 1.6
    let clefWidth: CGFloat = (measure.clef == nil && measure.clefsByStaff.isEmpty) ? 0 : metrics.staffSpace * 1.6
    let startX = measureX + metrics.noteInset + prefixWidth + timeWidth + clefWidth

    if onsets.count == 1 {
        return [onsets[0]: startX]
    }

    let usableWidth = max(0, measureWidth - metrics.noteInset * 2 - prefixWidth - timeWidth - clefWidth)
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

private func prefixElements(
    measure: Measure,
    staffID: StaffID,
    clef: Clef,
    middleY: CGFloat,
    measureX: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    var elements: [ElementLayout] = []
    if measure.clef != nil || measure.clefsByStaff[staffID] != nil {
        let frame = CGRect(
            x: measureX + metrics.staffSpace * 0.15,
            y: middleY - metrics.staffSpace * 2.1,
            width: metrics.staffSpace * 1.4,
            height: metrics.staffSpace * 4.2
        )
        elements.append(ElementLayout(
            id: ScoreElementID(rawValue: "\(staffID.rawValue).\(measure.id.rawValue).clef"),
            kind: .clef,
            measureID: measure.id,
            staffID: staffID,
            clef: clef,
            frame: frame
        ))
    }

    if let timeSignature = measure.timeSignature {
        let frame = CGRect(
            x: measureX + metrics.staffSpace * 2.0 + keySignaturePrefixWidth(for: measure.keySignature, metrics: metrics),
            y: middleY - metrics.staffSpace * 1.8,
            width: metrics.staffSpace * 1.4,
            height: metrics.staffSpace * 3.6
        )
        elements.append(ElementLayout(
            id: ScoreElementID(rawValue: "\(staffID.rawValue).\(measure.id.rawValue).timeSignature"),
            kind: .timeSignature,
            measureID: measure.id,
            staffID: staffID,
            clef: clef,
            keySignature: measure.keySignature,
            timeSignature: timeSignature,
            frame: frame
        ))
    }

    return elements
}

private func barlineElements(
    measure: Measure,
    staffIDs: [StaffID],
    staffIndexByID: [StaffID: Int],
    measureX: CGFloat,
    measureWidth: CGFloat,
    systemTop: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    guard !staffIDs.isEmpty else {
        return []
    }
    var elements: [ElementLayout] = []
    let rightX = measureX + measureWidth
    let topStaffIndex = staffIndexByID[staffIDs.first!] ?? 0
    let bottomStaffIndex = staffIndexByID[staffIDs.last!] ?? 0
    let top = metrics.staffMiddleY(systemTop: systemTop, staffIndex: topStaffIndex) - metrics.staffHeight / 2
    let bottom = metrics.staffMiddleY(systemTop: systemTop, staffIndex: bottomStaffIndex) + metrics.staffHeight / 2

    elements.append(ElementLayout(
        id: ScoreElementID(rawValue: "\(measure.id.rawValue).barline.right"),
        kind: .barline,
        measureID: measure.id,
        frame: CGRect(x: rightX - metrics.staffLineHitHalfWidth, y: top, width: metrics.staffLineHitHalfWidth * 2, height: bottom - top)
    ))

    for repeatBarline in measure.repeatBarlines {
        let x = repeatBarline.direction == .forward ? measureX : rightX
        elements.append(ElementLayout(
            id: ScoreElementID(rawValue: "\(measure.id.rawValue).repeat.\(repeatBarline.direction.rawValue)"),
            kind: .barline,
            measureID: measure.id,
            frame: CGRect(x: x - metrics.staffSpace * 0.3, y: top, width: metrics.staffSpace * 0.6, height: bottom - top),
            repeatBarline: repeatBarline
        ))
    }
    return elements
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
