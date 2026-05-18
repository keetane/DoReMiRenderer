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
    public var displayTransposeSemitones: Int

    public init(
        pageWidth: CGFloat = 800,
        pageHeight: CGFloat? = nil,
        staffSpace: CGFloat = 10,
        systemSpacing: CGFloat = 72,
        measureSpacing: CGFloat = 28,
        displayMode: DisplayMode = .print,
        showPageMargins: Bool = false,
        unsupportedFeaturePolicy: UnsupportedFeaturePolicy = .ignoreWithWarning,
        displayTransposeSemitones: Int = 0
    ) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.staffSpace = staffSpace
        self.systemSpacing = systemSpacing
        self.measureSpacing = measureSpacing
        self.displayMode = displayMode
        self.showPageMargins = showPageMargins
        self.unsupportedFeaturePolicy = unsupportedFeaturePolicy
        self.displayTransposeSemitones = max(-12, min(12, displayTransposeSemitones))
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
        case .print, .horizontal:
            break
        case .verticalPractice:
            if options.unsupportedFeaturePolicy == .fail {
                throw LayoutError.unsupportedDisplayMode(options.displayMode)
            }
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "unsupported.displayMode",
                message: "\(options.displayMode) display mode is not supported; falling back to print layout.",
                location: nil
            ))
        }
        if options.displayTransposeSemitones != 0 {
            diagnostics.append(RendererDiagnostic(
                severity: .info,
                code: "display.transpose.mvp",
                message: "Score layout uses MVP display transpose of \(options.displayTransposeSemitones) semitones; original NoteID and playback events are preserved.",
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
        let systemHeight = CGFloat(max(staffIDs.count, 1) - 1) * metrics.staffGap + metrics.staffHeight
        let shouldWrapSystems = options.displayMode == .print

        func appendSystem(index: Int, top: CGFloat) {
            systems.append(
                SystemLayout(
                    index: index,
                    frame: CGRect(x: metrics.leftMargin, y: top, width: contentWidth, height: systemHeight),
                    staffIDs: staffIDs
                )
            )

            for (staffIndex, staffID) in staffIDs.enumerated() {
                let middleY = metrics.staffMiddleY(systemTop: top, staffIndex: staffIndex)
                staves.append(
                    StaffLayout(
                        staffID: staffID,
                        systemIndex: index,
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
        }

        var currentSystemIndex = 0
        var systemTop = metrics.topMargin
        appendSystem(index: currentSystemIndex, top: systemTop)

        var measureX = metrics.leftMargin
        let flatMeasures = score.parts.enumerated().flatMap { partIndex, part in
            part.measures.enumerated().map { measureIndex, measure in
                (partIndex: partIndex, measureIndex: measureIndex, measure: measure)
            }
        }
        diagnostics.append(contentsOf: complexVoiceDiagnostics(in: flatMeasures.map(\.measure)))

        for item in flatMeasures {
            let measureWidth = width(for: item.measure, options: options, metrics: metrics)
            if shouldWrapSystems,
               measureX > metrics.leftMargin,
               measureX + measureWidth > metrics.leftMargin + contentWidth {
                currentSystemIndex += 1
                systemTop += systemHeight + options.systemSpacing
                measureX = metrics.leftMargin
                appendSystem(index: currentSystemIndex, top: systemTop)
            }
            let measureFrame = CGRect(x: measureX, y: systemTop, width: measureWidth, height: systemHeight)
            let measureLayout = MeasureLayout(
                measureID: item.measure.id,
                systemIndex: currentSystemIndex,
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
                let displayedKeySignature = displayKeySignature(for: item.measure.keySignature, options: options)
                elements.append(contentsOf: prefixElements(
                    measure: item.measure,
                    staffID: staffID,
                    clef: clef,
                    displayedKeySignature: displayedKeySignature,
                    middleY: middleY,
                    measureX: measureX,
                    metrics: metrics
                ))
                for keyElement in keySignatureElements(
                    keySignature: displayedKeySignature,
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
            elements.append(contentsOf: measureRepeatElements(
                measure: item.measure,
                staffIDs: staffIDs,
                staffIndexByID: staffIndexByID,
                measureX: measureX,
                measureWidth: measureWidth,
                systemTop: systemTop,
                metrics: metrics
            ))

            let onsetX = xCoordinatesByOnset(
                for: item.measure,
                measureX: measureX,
                measureWidth: measureWidth,
                metrics: metrics,
                displayedKeySignature: displayKeySignature(for: item.measure.keySignature, options: options)
            )
            let chordStemDirections = chordStemDirections(for: item.measure)
            let beamGroups = beamGroups(for: item.measure)
            let beamedNoteIDs = Set(beamGroups.flatMap(\.noteIDs))
            for note in item.measure.notes {
                let clef = clef(for: note.staffID, in: item.measure)
                let staffIndex = staffIndexByID[note.staffID] ?? 0
                let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndex)
                let displayedPitch = displayPitch(for: note.pitch, options: options)
                let displayedKeySignature = displayKeySignature(for: item.measure.keySignature, options: options)
                let position = displayedPitch.map { staffPosition(pitch: $0, clef: clef) }
                let noteCenterX = wholeRestCenterX(
                    for: note,
                    measureX: measureX,
                    measureWidth: measureWidth,
                    fallbackX: onsetX[note.onset] ?? (measureX + metrics.noteInset)
                )
                let center = CGPoint(
                    x: noteCenterX,
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
                    pitch: displayedPitch,
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
                        keySignature: displayedKeySignature,
                        timeSignature: item.measure.timeSignature,
                        pitchClassHint: displayedPitch?.pitchClass,
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

                guard let pitch = displayedPitch, let position else {
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
                            keySignature: displayedKeySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: pitch.pitchClass,
                            frame: stemFrame,
                            noteLayout: noteLayout
                        )
                    )

                    if note.noteValueKind.flagCount > 0 && !beamedNoteIDs.contains(note.id) {
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
                                keySignature: displayedKeySignature,
                                timeSignature: item.measure.timeSignature,
                                pitchClassHint: pitch.pitchClass,
                                frame: flagFrame,
                                noteLayout: noteLayout
                            )
                        )
                    }
                }

                if let accidental = displayAccidental(for: note, displayPitch: pitch, options: options) {
                    let accidentalElementID = ScoreElementID(rawValue: "\(note.id.rawValue).accidental")
                    let accidentalHeight = noteFrame.height * 1.55
                    let accidentalWidth = noteFrame.width * 0.95
                    let accidentalFrame = CGRect(
                        x: noteFrame.minX - noteFrame.width * 0.60,
                        y: noteFrame.midY - accidentalHeight / 2,
                        width: accidentalWidth,
                        height: accidentalHeight
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
                            keySignature: displayedKeySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: pitch.pitchClass,
                            frame: accidentalFrame,
                            noteLayout: noteLayout,
                            accidental: accidental
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
                            keySignature: displayedKeySignature,
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
                            keySignature: displayedKeySignature,
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
                            keySignature: displayedKeySignature,
                            timeSignature: item.measure.timeSignature,
                            pitchClassHint: ledgerLine.pitchClassHint,
                            frame: ledgerLine.frame,
                            ledgerLine: ledgerLine
                        )
                    )
                }
            }

            elements.append(contentsOf: beamElements(
                groups: beamGroups,
                measure: item.measure,
                noteByID: noteByID,
                elements: elements,
                metrics: metrics
            ))
            elements.append(contentsOf: tieAndSlurElements(
                measure: item.measure,
                noteByID: noteByID,
                metrics: metrics
            ))
            elements.append(contentsOf: tupletElements(
                measure: item.measure,
                noteByID: noteByID,
                elements: elements,
                metrics: metrics
            ))

            elements.append(contentsOf: barlineElements(
                measure: item.measure,
                staffIDs: staffIDs,
                staffIndexByID: staffIndexByID,
                measureX: measureX,
                measureWidth: measureWidth,
                forwardRepeatX: forwardRepeatX(
                    for: item.measure,
                    measureX: measureX,
                    elements: elements,
                    noteByID: noteByID,
                    metrics: metrics
                ),
                systemTop: systemTop,
                metrics: metrics
            ))
            elements.append(contentsOf: repeatEndingElements(
                measure: item.measure,
                staffIDs: staffIDs,
                staffIndexByID: staffIndexByID,
                measureX: measureX,
                measureWidth: measureWidth,
                systemTop: systemTop,
                metrics: metrics
            ))
            elements.append(contentsOf: playbackJumpMarkerElements(
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

    private func displayPitch(for pitch: Pitch?, options: LayoutOptions) -> Pitch? {
        guard let pitch, options.displayTransposeSemitones != 0 else {
            return pitch
        }
        return transposePitch(pitch, by: options.displayTransposeSemitones)
    }

    private func displayAccidental(for note: ScoreNote, displayPitch: Pitch, options: LayoutOptions) -> String? {
        guard options.displayTransposeSemitones != 0 else {
            return note.accidental
        }
        switch displayPitch.alter {
        case 1:
            return "sharp"
        case -1:
            return "flat"
        case 0:
            return note.accidental == "natural" ? "natural" : nil
        default:
            return displayPitch.alter > 0 ? "sharp" : "flat"
        }
    }

    private func displayKeySignature(for keySignature: KeySignature?, options: LayoutOptions) -> KeySignature? {
        guard options.displayTransposeSemitones != 0, let keySignature else {
            return keySignature
        }
        let mode = keySignature.mode?.lowercased() == "minor" ? "minor" : "major"
        let tonic = tonicPitchClass(fifths: keySignature.fifths, mode: mode)
        let transposed = normalizedPitchClass(tonic + options.displayTransposeSemitones)
        return KeySignature(fifths: fifths(forTonicPitchClass: transposed, mode: mode), mode: keySignature.mode)
    }

    private func transposePitch(_ pitch: Pitch, by semitones: Int) -> Pitch {
        let midi = midiNumber(for: pitch) + semitones
        return pitchFromMIDINumber(min(max(midi, 0), 127), preferFlats: pitch.alter < 0)
    }

    private func midiNumber(for pitch: Pitch) -> Int {
        let base: Int
        switch pitch.step {
        case .c: base = 0
        case .d: base = 2
        case .e: base = 4
        case .f: base = 5
        case .g: base = 7
        case .a: base = 9
        case .b: base = 11
        }
        return (pitch.octave + 1) * 12 + base + pitch.alter
    }

    private func pitchFromMIDINumber(_ midi: Int, preferFlats: Bool) -> Pitch {
        let octave = midi / 12 - 1
        let pitchClass = normalizedPitchClass(midi)
        if preferFlats {
            switch pitchClass {
            case 1: return Pitch(step: .d, octave: octave, alter: -1)
            case 3: return Pitch(step: .e, octave: octave, alter: -1)
            case 6: return Pitch(step: .g, octave: octave, alter: -1)
            case 8: return Pitch(step: .a, octave: octave, alter: -1)
            case 10: return Pitch(step: .b, octave: octave, alter: -1)
            default: break
            }
        }
        switch pitchClass {
        case 0: return Pitch(step: .c, octave: octave)
        case 1: return Pitch(step: .c, octave: octave, alter: 1)
        case 2: return Pitch(step: .d, octave: octave)
        case 3: return Pitch(step: .d, octave: octave, alter: 1)
        case 4: return Pitch(step: .e, octave: octave)
        case 5: return Pitch(step: .f, octave: octave)
        case 6: return Pitch(step: .f, octave: octave, alter: 1)
        case 7: return Pitch(step: .g, octave: octave)
        case 8: return Pitch(step: .g, octave: octave, alter: 1)
        case 9: return Pitch(step: .a, octave: octave)
        case 10: return Pitch(step: .a, octave: octave, alter: 1)
        default: return Pitch(step: .b, octave: octave)
        }
    }

    private func tonicPitchClass(fifths: Int, mode: String) -> Int {
        let major = normalizedPitchClass(fifths * 7)
        return mode == "minor" ? normalizedPitchClass(major - 3) : major
    }

    private func fifths(forTonicPitchClass pitchClass: Int, mode: String) -> Int {
        let normalized = normalizedPitchClass(mode == "minor" ? pitchClass + 3 : pitchClass)
        let candidates = (-7...7).map { fifths in
            (fifths: fifths, pitchClass: normalizedPitchClass(fifths * 7))
        }.filter {
            $0.pitchClass == normalized
        }
        return candidates.min { abs($0.fifths) < abs($1.fifths) }?.fifths ?? 0
    }

    private func normalizedPitchClass(_ pitchClass: Int) -> Int {
        let value = pitchClass % 12
        return value >= 0 ? value : value + 12
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

    private func beamGroups(for measure: Measure) -> [BeamGroup] {
        let candidates = measure.notes.filter { $0.pitch != nil && $0.noteValueKind.flagCount > 0 }
        let grouped = Dictionary(grouping: candidates) { note in
            BeamGroupKey(measureID: measure.id, staffID: note.staffID, voiceID: note.voiceID)
        }
        return grouped.flatMap { key, notes -> [BeamGroup] in
            let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
            let events = Dictionary(grouping: notes, by: \.onset)
                .map { onset, onsetNotes in
                    BeamEvent(onset: onset, noteIDs: onsetNotes.map(\.id))
                }
                .sorted { $0.onset < $1.onset }
            var result: [BeamGroup] = []
            var current: [BeamEvent] = []
            var currentBeatIndex: Int?
            var previousEnd: MusicalTime?
            var previousNote: ScoreNote?
            let measureStart = measure.notes.map(\.onset).min() ?? MusicalTime(ticks: 0, ticksPerQuarterNote: 4)
            let beatDuration = beamBeatDuration(for: measure, fallbackOnset: measureStart)
            for event in events {
                let representativeNote = notes.first { $0.id == event.noteIDs.first }
                let duration = representativeNote?.duration ?? MusicalTime(ticks: 0, ticksPerQuarterNote: event.onset.ticksPerQuarterNote)
                let eventBeatIndex = beamBeatIndex(onset: event.onset, measureStart: measureStart, beatDuration: beatDuration)
                let eventEnd = event.onset + duration
                let beatStart = beamBeatStart(index: eventBeatIndex, measureStart: measureStart, beatDuration: beatDuration)
                let beatEnd = beatStart + beatDuration
                let crossesBeat = eventEnd > beatEnd
                let leapsTooFar = previousNote.flatMap { previous in
                    representativeNote.map { current in
                        abs(diatonicPitchValue(previous.pitch) - diatonicPitchValue(current.pitch)) > 7
                    }
                } ?? false
                let stemDirectionChanged = previousNote.flatMap { previous in
                    representativeNote.map { current in
                        guard let previousPitch = previous.pitch, let currentPitch = current.pitch else {
                            return false
                        }
                        let previousDirection = stemDirection(for: staffPosition(pitch: previousPitch, clef: clef(for: previous.staffID, in: measure)))
                        let currentDirection = stemDirection(for: staffPosition(pitch: currentPitch, clef: clef(for: current.staffID, in: measure)))
                        return previousDirection != currentDirection
                    }
                } ?? false
                if (currentBeatIndex != nil && currentBeatIndex != eventBeatIndex)
                    || (previousEnd != nil && previousEnd != event.onset)
                    || leapsTooFar
                    || stemDirectionChanged
                    || crossesBeat
                {
                    appendBeamGroupIfAllowed(events: current, key: key, notesByID: notesByID, to: &result)
                    current = []
                    currentBeatIndex = nil
                }
                if !crossesBeat {
                    current.append(event)
                    currentBeatIndex = eventBeatIndex
                }
                previousEnd = event.onset + duration
                previousNote = representativeNote
            }
            appendBeamGroupIfAllowed(events: current, key: key, notesByID: notesByID, to: &result)
            return result
        }
    }

    private func appendBeamGroupIfAllowed(
        events: [BeamEvent],
        key: BeamGroupKey,
        notesByID: [NoteID: ScoreNote],
        to result: inout [BeamGroup]
    ) {
        guard events.count >= 2, beamContourIsSimple(events: events, notesByID: notesByID) else {
            return
        }
        result.append(BeamGroup(key: key, events: events))
    }

    private func beamContourIsSimple(events: [BeamEvent], notesByID: [NoteID: ScoreNote]) -> Bool {
        let values = events.compactMap { event -> Int? in
            guard let firstID = event.noteIDs.first else {
                return nil
            }
            return diatonicPitchValue(notesByID[firstID]?.pitch)
        }
        guard values.count == events.count else {
            return false
        }
        var direction: Int?
        for pair in zip(values, values.dropFirst()) {
            let difference = pair.1 - pair.0
            guard abs(difference) <= 4 else {
                return false
            }
            let sign = difference == 0 ? 0 : (difference > 0 ? 1 : -1)
            if sign == 0 {
                continue
            }
            if let direction, direction != sign {
                return false
            }
            direction = sign
        }
        return true
    }

    private func beamBeatDuration(for measure: Measure, fallbackOnset: MusicalTime) -> MusicalTime {
        let beatType = measure.timeSignature?.beatType ?? 4
        let ticksPerQuarterNote = fallbackOnset.ticksPerQuarterNote
        let ticks = max(1, ticksPerQuarterNote * 4 / max(1, beatType))
        return MusicalTime(ticks: ticks, ticksPerQuarterNote: ticksPerQuarterNote)
    }

    private func beamBeatIndex(onset: MusicalTime, measureStart: MusicalTime, beatDuration: MusicalTime) -> Int {
        let offset = musicalTimeValue(onset - measureStart)
        let beat = musicalTimeValue(beatDuration)
        guard beat > 0 else {
            return 0
        }
        return Int(floor((offset / beat) + 0.0001))
    }

    private func beamBeatStart(index: Int, measureStart: MusicalTime, beatDuration: MusicalTime) -> MusicalTime {
        MusicalTime(ticks: measureStart.ticks + beatDuration.ticks * index, ticksPerQuarterNote: measureStart.ticksPerQuarterNote)
    }

    private func beamElements(
        groups: [BeamGroup],
        measure: Measure,
        noteByID: [NoteID: NoteLayout],
        elements: [ElementLayout],
        metrics: LayoutMetrics
    ) -> [ElementLayout] {
        var stemsByNoteID: [NoteID: ElementLayout] = [:]
        for element in elements where element.kind == .stem {
            if let noteID = element.noteID {
                stemsByNoteID[noteID] = element
            }
        }
        return groups.compactMap { group in
            guard let firstID = group.noteIDs.first,
                  let lastID = group.noteIDs.last,
                  let firstStem = stemsByNoteID[firstID],
                  let lastStem = stemsByNoteID[lastID],
                  let firstLayout = noteByID[firstID]
            else {
                return nil
            }
            let startTip = stemTip(stem: firstStem, noteLayout: firstLayout)
            let endTip = stemTip(stem: lastStem, noteLayout: noteByID[lastID] ?? firstLayout)
            let y1 = startTip.y
            let y2 = endTip.y
            let x1 = startTip.x
            let x2 = endTip.x
            let thickness = max(3, metrics.noteheadSize.height * 0.16)
            let secondarySegments = secondaryBeamSegments(
                group: group,
                noteByID: noteByID,
                stemsByNoteID: stemsByNoteID,
                primaryStart: startTip,
                primaryEnd: endTip,
                thickness: thickness
            )
            let allSegments = [BeamSegmentLayout(start: startTip, end: endTip)] + secondarySegments
            let minX = min(x1, x2)
            let minY = min(y1, y2) - thickness / 2
            let maxX = max(x1, x2)
            let maxY = max(y1, y2) + thickness / 2
            let segmentBounds = allSegments.reduce(CGRect(x: minX, y: minY, width: max(thickness, maxX - minX), height: max(thickness, maxY - minY))) { bounds, segment in
                bounds.union(CGRect(
                    x: min(segment.start.x, segment.end.x),
                    y: min(segment.start.y, segment.end.y) - thickness / 2,
                    width: max(thickness, abs(segment.end.x - segment.start.x)),
                    height: abs(segment.end.y - segment.start.y) + thickness
                ))
            }
            let frame = segmentBounds
            let beam = BeamLayout(
                noteIDs: group.noteIDs,
                primary: BeamSegmentLayout(start: startTip, end: endTip),
                secondarySegments: secondarySegments,
                thickness: thickness
            )
            return ElementLayout(
                id: ScoreElementID(rawValue: "\(measure.id.rawValue).beam.\(firstID.rawValue).\(lastID.rawValue)"),
                kind: .beam,
                noteID: firstID,
                measureID: measure.id,
                staffID: firstLayout.staffID,
                voiceID: firstLayout.voiceID,
                clef: firstLayout.clef,
                frame: frame.insetBy(dx: -thickness / 2, dy: -thickness / 2),
                beam: beam
            )
        }
    }

    private func stemTip(stem: ElementLayout, noteLayout: NoteLayout) -> CGPoint {
        let drawsDown = stem.frame.midY > noteLayout.noteheadCenter.y
        return CGPoint(x: stem.frame.midX, y: drawsDown ? stem.frame.maxY : stem.frame.minY)
    }

    private func secondaryBeamSegments(
        group: BeamGroup,
        noteByID: [NoteID: NoteLayout],
        stemsByNoteID: [NoteID: ElementLayout],
        primaryStart: CGPoint,
        primaryEnd: CGPoint,
        thickness: CGFloat
    ) -> [BeamSegmentLayout] {
        let representativeIDs = group.events.compactMap(\.noteIDs.first)
        let maxFlagCount = representativeIDs
            .map { noteByID[$0]?.noteValueKind.flagCount ?? 0 }
            .max() ?? 0
        guard maxFlagCount >= 2 else {
            return []
        }
        let secondaryOffset: CGFloat = max(thickness * 1.45, (noteByID[representativeIDs.first ?? NoteID(rawValue: "")]?.noteheadFrame.height ?? 16) * 0.34)
        func yOnPrimary(at x: CGFloat) -> CGFloat {
            guard primaryEnd.x != primaryStart.x else { return primaryStart.y }
            let t = (x - primaryStart.x) / (primaryEnd.x - primaryStart.x)
            return primaryStart.y + (primaryEnd.y - primaryStart.y) * t
        }
        var segments: [BeamSegmentLayout] = []
        for beamLevel in 2...maxFlagCount {
            var run: [NoteID] = []
            for id in representativeIDs {
                if (noteByID[id]?.noteValueKind.flagCount ?? 0) >= beamLevel {
                    run.append(id)
                } else {
                    appendSecondaryRun(run, to: &segments, orderedIDs: representativeIDs, noteByID: noteByID, stemsByNoteID: stemsByNoteID, yOnPrimary: yOnPrimary, offset: secondaryOffset * CGFloat(beamLevel - 1))
                    run = []
                }
            }
            appendSecondaryRun(run, to: &segments, orderedIDs: representativeIDs, noteByID: noteByID, stemsByNoteID: stemsByNoteID, yOnPrimary: yOnPrimary, offset: secondaryOffset * CGFloat(beamLevel - 1))
        }
        return segments
    }

    private func appendSecondaryRun(
        _ run: [NoteID],
        to segments: inout [BeamSegmentLayout],
        orderedIDs: [NoteID],
        noteByID: [NoteID: NoteLayout],
        stemsByNoteID: [NoteID: ElementLayout],
        yOnPrimary: (CGFloat) -> CGFloat,
        offset: CGFloat
    ) {
        guard let firstID = run.first,
              let firstStem = stemsByNoteID[firstID],
              let firstLayout = noteByID[firstID]
        else {
            return
        }
        let drawsDown = firstStem.frame.midY > firstLayout.noteheadCenter.y
        let signedOffset = drawsDown ? -offset : offset
        let startX = firstStem.frame.midX
        let endX: CGFloat
        if let lastID = run.dropFirst().last, let lastStem = stemsByNoteID[lastID] {
            endX = lastStem.frame.midX
        } else {
            let hookLength = firstLayout.noteheadFrame.width * 0.95
            let index = orderedIDs.firstIndex(of: firstID)
            if let index, index > orderedIDs.startIndex, let previousStem = stemsByNoteID[orderedIDs[orderedIDs.index(before: index)]] {
                endX = startX + (previousStem.frame.midX < startX ? -hookLength : hookLength)
            } else if let index, orderedIDs.index(after: index) < orderedIDs.endIndex, let nextStem = stemsByNoteID[orderedIDs[orderedIDs.index(after: index)]] {
                endX = startX + (nextStem.frame.midX < startX ? -hookLength : hookLength)
            } else {
                endX = startX + (drawsDown ? -hookLength : hookLength)
            }
        }
        segments.append(BeamSegmentLayout(
            start: CGPoint(x: startX, y: yOnPrimary(startX) + signedOffset),
            end: CGPoint(x: endX, y: yOnPrimary(endX) + signedOffset)
        ))
    }

    private func tieAndSlurElements(
        measure: Measure,
        noteByID: [NoteID: NoteLayout],
        metrics: LayoutMetrics
    ) -> [ElementLayout] {
        let notes = measure.notes.sorted { lhs, rhs in
            if lhs.onset != rhs.onset { return lhs.onset < rhs.onset }
            return lhs.chordOrdinal < rhs.chordOrdinal
        }
        var result: [ElementLayout] = []

        for startNote in notes where startNote.pitch != nil && startNote.ties.contains(.start) {
            if let endNote = notes.first(where: {
                $0.id != startNote.id
                    && $0.pitch == startNote.pitch
                    && $0.staffID == startNote.staffID
                    && $0.voiceID == startNote.voiceID
                    && $0.onset >= startNote.onset
                    && $0.ties.contains(.stop)
            }), let element = curveElement(kind: .tie, measure: measure, startNote: startNote, endNote: endNote, noteByID: noteByID, metrics: metrics) {
                result.append(element)
            }
        }

        var slurStarts: [SlurKey: ScoreNote] = [:]
        for note in notes {
            let key = SlurKey(staffID: note.staffID, voiceID: note.voiceID)
            if note.slurs.contains(.start) {
                slurStarts[key] = note
            }
            if note.slurs.contains(.stop), let start = slurStarts[key], start.id != note.id {
                if let element = curveElement(kind: .slur, measure: measure, startNote: start, endNote: note, noteByID: noteByID, metrics: metrics) {
                    result.append(element)
                }
                slurStarts[key] = nil
            }
        }
        return result
    }

    private func curveElement(
        kind: NotationCurveKind,
        measure: Measure,
        startNote: ScoreNote,
        endNote: ScoreNote,
        noteByID: [NoteID: NoteLayout],
        metrics: LayoutMetrics
    ) -> ElementLayout? {
        guard let startLayout = noteByID[startNote.id],
              let endLayout = noteByID[endNote.id]
        else {
            return nil
        }
        let direction = curveDirection(startLayout: startLayout, endLayout: endLayout)
        let lift = (kind == .tie ? metrics.noteheadSize.height * 0.55 : metrics.noteheadSize.height * 1.25) * direction
        let start = CGPoint(x: startLayout.noteheadFrame.maxX, y: startLayout.noteheadCenter.y + lift * 0.25)
        let end = CGPoint(x: endLayout.noteheadFrame.minX, y: endLayout.noteheadCenter.y + lift * 0.25)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) + lift)
        let minX = min(start.x, end.x, control.x)
        let minY = min(start.y, end.y, control.y)
        let maxX = max(start.x, end.x, control.x)
        let maxY = max(start.y, end.y, control.y)
        let frame = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .insetBy(dx: -metrics.staffLineHitHalfWidth * 2, dy: -metrics.staffLineHitHalfWidth * 2)
        let curve = NotationCurveLayout(kind: kind, startNoteID: startNote.id, endNoteID: endNote.id, start: start, control: control, end: end, frame: frame)
        return ElementLayout(
            id: ScoreElementID(rawValue: "\(measure.id.rawValue).\(kind == .tie ? "tie" : "slur").\(startNote.id.rawValue).\(endNote.id.rawValue)"),
            kind: kind == .tie ? .tie : .slur,
            noteID: startNote.id,
            measureID: measure.id,
            staffID: startLayout.staffID,
            voiceID: startLayout.voiceID,
            clef: startLayout.clef,
            pitchClassHint: startLayout.pitch?.pitchClass,
            frame: frame,
            curve: curve
        )
    }

    private func curveDirection(startLayout: NoteLayout, endLayout: NoteLayout) -> CGFloat {
        if let position = startLayout.staffPosition {
            return stemDirection(for: position) == .up ? 1 : -1
        }
        if startLayout.noteheadCenter.y == endLayout.noteheadCenter.y {
            return 1
        }
        return startLayout.noteheadCenter.y < endLayout.noteheadCenter.y ? -1 : 1
    }

    private func tupletElements(
        measure: Measure,
        noteByID: [NoteID: NoteLayout],
        elements: [ElementLayout],
        metrics: LayoutMetrics
    ) -> [ElementLayout] {
        let candidates = measure.notes.filter { $0.pitch != nil && ($0.hasTimeModification || $0.hasTupletNotation || $0.tuplet != nil) }
        let grouped = Dictionary(grouping: candidates) { note in
            BeamGroupKey(measureID: measure.id, staffID: note.staffID, voiceID: note.voiceID)
        }
        return grouped.compactMap { _, notes in
            let sorted = notes.sorted { $0.onset < $1.onset }
            guard sorted.count >= 3,
                  let first = sorted.first,
                  let last = sorted.last,
                  let firstLayout = noteByID[first.id],
                  let lastLayout = noteByID[last.id]
            else {
                return nil
            }
            let number = "\(first.tuplet?.actualNotes ?? 3)"
            let top = sorted.compactMap { noteByID[$0.id]?.noteheadFrame.minY }.min() ?? firstLayout.noteheadFrame.minY
            let frame = CGRect(
                x: firstLayout.noteheadCenter.x,
                y: top - metrics.noteheadSize.height * 1.65,
                width: max(metrics.noteheadSize.width * 2, lastLayout.noteheadCenter.x - firstLayout.noteheadCenter.x),
                height: metrics.noteheadSize.height * 0.8
            )
            let tuplet = TupletLayout(noteIDs: sorted.map(\.id), number: number, frame: frame)
            return ElementLayout(
                id: ScoreElementID(rawValue: "\(measure.id.rawValue).tuplet.\(first.id.rawValue).\(last.id.rawValue)"),
                kind: .tuplet,
                noteID: first.id,
                measureID: measure.id,
                staffID: firstLayout.staffID,
                voiceID: firstLayout.voiceID,
                clef: firstLayout.clef,
                frame: frame,
                tuplet: tuplet
            )
        }
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
        let length = noteFrame.height * 2.2 + width * 0.25
        switch direction {
        case .up:
            return CGRect(
                x: noteFrame.maxX - width * 1.75,
                y: center.y - length - width * 0.4,
                width: width,
                height: length
            )
        case .down:
            return CGRect(
                x: noteFrame.minX + width * 0.65,
                y: center.y + width * 0.4,
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
                width: noteFrame.width * 1.18,
                height: noteFrame.height * 1.85
            )
        case .down:
            return CGRect(
                x: stemFrame.midX - noteFrame.width * 1.18,
                y: stemFrame.maxY - noteFrame.height * 1.85,
                width: noteFrame.width * 1.18,
                height: noteFrame.height * 1.85
            )
        }
    }

    private func wholeRestCenterX(
        for note: ScoreNote,
        measureX: CGFloat,
        measureWidth: CGFloat,
        fallbackX: CGFloat
    ) -> CGFloat {
        guard note.pitch == nil, note.noteValueKind == .whole else {
            return fallbackX
        }
        return measureX + measureWidth / 2
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
        let firstDotOffset = note.pitch == nil ? -noteFrame.width * 0.06 : noteFrame.width * 0.12
        for index in 0..<note.dotCount {
            let dotFrame = CGRect(
                x: noteFrame.maxX + firstDotOffset + CGFloat(index) * dotSize * 1.8,
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
    public let beam: BeamLayout?
    public let curve: NotationCurveLayout?
    public let tuplet: TupletLayout?
    public let repeatEnding: RepeatEndingLayout?
    public let measureRepeat: MeasureRepeat?
    public let playbackJumpMarker: PlaybackJumpMarkerLayout?

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
        repeatBarline: RepeatBarline? = nil,
        beam: BeamLayout? = nil,
        curve: NotationCurveLayout? = nil,
        tuplet: TupletLayout? = nil,
        repeatEnding: RepeatEndingLayout? = nil,
        measureRepeat: MeasureRepeat? = nil,
        playbackJumpMarker: PlaybackJumpMarkerLayout? = nil
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
        self.beam = beam
        self.curve = curve
        self.tuplet = tuplet
        self.repeatEnding = repeatEnding
        self.measureRepeat = measureRepeat
        self.playbackJumpMarker = playbackJumpMarker
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
            repeatBarline: repeatBarline,
            beam: beam?.offsetBy(dx: dx, dy: dy),
            curve: curve?.offsetBy(dx: dx, dy: dy),
            tuplet: tuplet?.offsetBy(dx: dx, dy: dy),
            repeatEnding: repeatEnding?.offsetBy(dx: dx, dy: dy),
            measureRepeat: measureRepeat,
            playbackJumpMarker: playbackJumpMarker?.offsetBy(dx: dx, dy: dy)
        )
    }
}

public struct BeamSegmentLayout: Sendable {
    public let start: CGPoint
    public let end: CGPoint

    init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> BeamSegmentLayout {
        BeamSegmentLayout(
            start: CGPoint(x: start.x + dx, y: start.y + dy),
            end: CGPoint(x: end.x + dx, y: end.y + dy)
        )
    }
}

public struct BeamLayout: Sendable {
    public let noteIDs: [NoteID]
    public let primary: BeamSegmentLayout
    public let secondarySegments: [BeamSegmentLayout]
    public let thickness: CGFloat

    init(noteIDs: [NoteID], primary: BeamSegmentLayout, secondarySegments: [BeamSegmentLayout] = [], thickness: CGFloat) {
        self.noteIDs = noteIDs
        self.primary = primary
        self.secondarySegments = secondarySegments
        self.thickness = thickness
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> BeamLayout {
        BeamLayout(
            noteIDs: noteIDs,
            primary: primary.offsetBy(dx: dx, dy: dy),
            secondarySegments: secondarySegments.map { $0.offsetBy(dx: dx, dy: dy) },
            thickness: thickness
        )
    }
}

public enum NotationCurveKind: Hashable, Codable, Sendable {
    case tie
    case slur
}

public struct NotationCurveLayout: Sendable {
    public let kind: NotationCurveKind
    public let startNoteID: NoteID
    public let endNoteID: NoteID
    public let start: CGPoint
    public let control: CGPoint
    public let end: CGPoint
    public let frame: CGRect

    init(kind: NotationCurveKind, startNoteID: NoteID, endNoteID: NoteID, start: CGPoint, control: CGPoint, end: CGPoint, frame: CGRect) {
        self.kind = kind
        self.startNoteID = startNoteID
        self.endNoteID = endNoteID
        self.start = start
        self.control = control
        self.end = end
        self.frame = frame
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> NotationCurveLayout {
        NotationCurveLayout(
            kind: kind,
            startNoteID: startNoteID,
            endNoteID: endNoteID,
            start: CGPoint(x: start.x + dx, y: start.y + dy),
            control: CGPoint(x: control.x + dx, y: control.y + dy),
            end: CGPoint(x: end.x + dx, y: end.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
        )
    }
}

public struct TupletLayout: Sendable {
    public let noteIDs: [NoteID]
    public let number: String
    public let frame: CGRect

    init(noteIDs: [NoteID], number: String, frame: CGRect) {
        self.noteIDs = noteIDs
        self.number = number
        self.frame = frame
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> TupletLayout {
        TupletLayout(noteIDs: noteIDs, number: number, frame: frame.offsetBy(dx: dx, dy: dy))
    }
}

public struct RepeatEndingLayout: Sendable {
    public let numbers: [Int]
    public let label: String
    public let kind: RepeatEndingKind
    public let startsHere: Bool
    public let stopsHere: Bool
    public let lineStart: CGPoint
    public let lineEnd: CGPoint
    public let startHookEnd: CGPoint?
    public let endHookEnd: CGPoint?
    public let labelPoint: CGPoint
    public let frame: CGRect

    init(
        numbers: [Int],
        label: String,
        kind: RepeatEndingKind,
        startsHere: Bool,
        stopsHere: Bool,
        lineStart: CGPoint,
        lineEnd: CGPoint,
        startHookEnd: CGPoint?,
        endHookEnd: CGPoint?,
        labelPoint: CGPoint,
        frame: CGRect
    ) {
        self.numbers = numbers
        self.label = label
        self.kind = kind
        self.startsHere = startsHere
        self.stopsHere = stopsHere
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.startHookEnd = startHookEnd
        self.endHookEnd = endHookEnd
        self.labelPoint = labelPoint
        self.frame = frame
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> RepeatEndingLayout {
        RepeatEndingLayout(
            numbers: numbers,
            label: label,
            kind: kind,
            startsHere: startsHere,
            stopsHere: stopsHere,
            lineStart: CGPoint(x: lineStart.x + dx, y: lineStart.y + dy),
            lineEnd: CGPoint(x: lineEnd.x + dx, y: lineEnd.y + dy),
            startHookEnd: startHookEnd.map { CGPoint(x: $0.x + dx, y: $0.y + dy) },
            endHookEnd: endHookEnd.map { CGPoint(x: $0.x + dx, y: $0.y + dy) },
            labelPoint: CGPoint(x: labelPoint.x + dx, y: labelPoint.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
        )
    }
}

public struct PlaybackJumpMarkerLayout: Sendable {
    public let marker: PlaybackJumpMarker
    public let label: String
    public let point: CGPoint
    public let frame: CGRect

    init(marker: PlaybackJumpMarker, label: String, point: CGPoint, frame: CGRect) {
        self.marker = marker
        self.label = label
        self.point = point
        self.frame = frame
    }

    fileprivate func offsetBy(dx: CGFloat, dy: CGFloat) -> PlaybackJumpMarkerLayout {
        PlaybackJumpMarkerLayout(
            marker: marker,
            label: label,
            point: CGPoint(x: point.x + dx, y: point.y + dy),
            frame: frame.offsetBy(dx: dx, dy: dy)
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
        case .half, .quarter, .eighth, .sixteenth, .thirtySecond, .other:
            true
        }
    }

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

private struct BeamGroupKey: Hashable {
    let measureID: MeasureID
    let staffID: StaffID
    let voiceID: VoiceID
}

private struct BeamEvent {
    let onset: MusicalTime
    let noteIDs: [NoteID]
}

private struct BeamGroup {
    let key: BeamGroupKey
    let events: [BeamEvent]

    var noteIDs: [NoteID] {
        events.flatMap(\.noteIDs)
    }
}

private struct SlurKey: Hashable {
    let staffID: StaffID
    let voiceID: VoiceID
}

private func diatonicPitchValue(_ pitch: Pitch?) -> Int {
    guard let pitch else {
        return 0
    }
    let stepIndex: Int = switch pitch.step {
    case .c: 0
    case .d: 1
    case .e: 2
    case .f: 3
    case .g: 4
    case .a: 5
    case .b: 6
    }
    return pitch.octave * 7 + stepIndex
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
        noteheadSize = CGSize(width: options.staffSpace * 1.95, height: options.staffSpace * 1.55)
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
    let spacingUnits = spacingUnitCount(for: measure)
    let onsetWidth = CGFloat(max(spacingUnits, 1)) * options.staffSpace * 5
    return max(metrics.minimumMeasureWidth, onsetWidth + metrics.noteInset * 2)
}

private func spacingUnitCount(for measure: Measure) -> Int {
    let uniqueOnsets = Set(measure.notes.map(\.onset)).count
    guard uniqueOnsets > 1 else {
        return max(uniqueOnsets, 1)
    }

    let measureStart = measure.notes.map(\.onset).min() ?? MusicalTime(ticks: 0, ticksPerQuarterNote: 4)
    let measureEnd = measure.notes
        .map { $0.onset + $0.duration }
        .max() ?? measureStart
    let durationValue = musicalTimeValue(measureEnd - measureStart)
    guard durationValue > 0 else {
        return uniqueOnsets
    }

    // Keep short-note passages on an eighth-note visual grid. Sixteenth onsets
    // should live inside the same beat width as the surrounding eighth-note beam
    // instead of widening the whole measure just because the onset grid is finer.
    let eighthGridUnits = Int(ceil(durationValue * 2))
    let containsShortNotes = measure.notes.contains { $0.noteValueKind.flagCount > 1 }
    if containsShortNotes {
        return max(eighthGridUnits, 1)
    }
    return uniqueOnsets
}

private func xCoordinatesByOnset(
    for measure: Measure,
    measureX: CGFloat,
    measureWidth: CGFloat,
    metrics: LayoutMetrics,
    displayedKeySignature: KeySignature? = nil
) -> [MusicalTime: CGFloat] {
    let onsets = Array(Set(measure.notes.map(\.onset))).sorted()
    guard !onsets.isEmpty else {
        return [:]
    }

    let prefixWidth = keySignaturePrefixWidth(for: displayedKeySignature ?? measure.keySignature, metrics: metrics)
    let timeWidth = timeSignaturePrefixWidth(for: measure, metrics: metrics)
    let clefWidth = clefPrefixWidth(for: measure, metrics: metrics)
    let repeatWidth = forwardRepeatPrefixWidth(for: measure, metrics: metrics)
    let startX = measureX + metrics.noteInset + prefixWidth + timeWidth + clefWidth + repeatWidth

    if onsets.count == 1 {
        return [onsets[0]: startX]
    }

    let usableWidth = max(0, measureWidth - metrics.noteInset * 2 - prefixWidth - timeWidth - clefWidth - repeatWidth)
    let measureStart = onsets.first ?? onsets[0]
    let measureEnd = measure.notes
        .map { $0.onset + $0.duration }
        .max() ?? onsets.last ?? measureStart
    let measureDuration = measureEnd - measureStart
    let measureDurationValue = musicalTimeValue(measureDuration)

    guard measureDurationValue > 0 else {
        let stepWidth = usableWidth / CGFloat(onsets.count - 1)
        return Dictionary(uniqueKeysWithValues: onsets.enumerated().map { index, onset in
            (onset, startX + CGFloat(index) * stepWidth)
        })
    }

    return Dictionary(uniqueKeysWithValues: onsets.map { onset in
        let offset = musicalTimeValue(onset - measureStart) / measureDurationValue
        return (onset, startX + usableWidth * offset)
    })
}

private func musicalTimeValue(_ time: MusicalTime) -> CGFloat {
    CGFloat(time.ticks) / CGFloat(time.ticksPerQuarterNote)
}

private func keySignaturePrefixWidth(for keySignature: KeySignature?, metrics: LayoutMetrics) -> CGFloat {
    guard let keySignature else {
        return 0
    }
    let count = min(abs(keySignature.fifths), 7)
    guard count > 0 else {
        return 0
    }
    return CGFloat(count - 1) * keySignatureAccidentalSpacing(metrics: metrics) + keySignatureAccidentalFrameWidth(metrics: metrics)
}

private func clefPrefixWidth(for measure: Measure, metrics: LayoutMetrics) -> CGFloat {
    (measure.clef == nil && measure.clefsByStaff.isEmpty) ? 0 : metrics.staffSpace * 2.9
}

private func timeSignaturePrefixWidth(for measure: Measure, metrics: LayoutMetrics) -> CGFloat {
    measure.timeSignature == nil ? 0 : metrics.staffSpace * 2.2
}

private func forwardRepeatPrefixWidth(for measure: Measure, metrics: LayoutMetrics) -> CGFloat {
    measure.repeatBarlines.contains { $0.direction == .forward } ? metrics.staffSpace * 1.6 : 0
}

private func keySignatureAccidentalSpacing(metrics: LayoutMetrics) -> CGFloat {
    metrics.staffSpace * 0.65
}

private func keySignatureAccidentalFrameWidth(metrics: LayoutMetrics) -> CGFloat {
    metrics.noteheadSize.width * 0.95
}

private func prefixElements(
    measure: Measure,
    staffID: StaffID,
    clef: Clef,
    displayedKeySignature: KeySignature?,
    middleY: CGFloat,
    measureX: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    var elements: [ElementLayout] = []
    if measure.clef != nil || measure.clefsByStaff[staffID] != nil {
        let clefYOffset: CGFloat = switch clef.kind {
        case .treble:
            metrics.staffSpace * 0.8
        case .bass:
            -metrics.staffSpace * 1.2
        case .alto, .tenor, .unknown:
            0
        }
        let clefScale: CGFloat = clef.kind == .bass ? 0.9 : 1
        let baseClefHeight = metrics.staffSpace * 4.55
        let clefWidth = metrics.staffSpace * 2.0 * clefScale
        let clefHeight = baseClefHeight * clefScale
        let frame = CGRect(
            x: measureX + metrics.staffSpace * 0.65,
            y: middleY - metrics.staffSpace * 2.1 + clefYOffset + (baseClefHeight - clefHeight) / 2,
            width: clefWidth,
            height: clefHeight
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
        let keyWidth = keySignaturePrefixWidth(for: displayedKeySignature, metrics: metrics)
        let keyGap = keyWidth > 0 ? metrics.staffSpace * 0.9 : 0
        let frame = CGRect(
            x: measureX + metrics.staffSpace * 3.85 + keyWidth + keyGap,
            y: middleY - metrics.staffSpace * 1.85,
            width: metrics.staffSpace * 1.85,
            height: metrics.staffSpace * 3.95
        )
        elements.append(ElementLayout(
            id: ScoreElementID(rawValue: "\(staffID.rawValue).\(measure.id.rawValue).timeSignature"),
            kind: .timeSignature,
            measureID: measure.id,
            staffID: staffID,
            clef: clef,
            keySignature: displayedKeySignature,
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
    forwardRepeatX: CGFloat,
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
        let x = repeatBarline.direction == .forward ? forwardRepeatX : rightX
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

private func repeatEndingElements(
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

    let startEndings = measure.repeatEndings.filter { $0.kind == .start && !$0.numbers.isEmpty }
    guard !startEndings.isEmpty else {
        return []
    }

    let topStaffIndex = staffIndexByID[staffIDs.first!] ?? 0
    let topStaffTop = metrics.staffMiddleY(systemTop: systemTop, staffIndex: topStaffIndex) - metrics.staffHeight / 2
    let bracketY = topStaffTop - metrics.staffSpace * 2.1
    let hookLength = metrics.staffSpace * 0.9
    let labelHeight = metrics.staffSpace * 1.05
    let lineStartX = measureX + metrics.staffSpace * 0.35
    let lineEndX = measureX + measureWidth - metrics.staffSpace * 0.35
    let lineStart = CGPoint(x: lineStartX, y: bracketY)
    let lineEnd = CGPoint(x: lineEndX, y: bracketY)

    return startEndings.flatMap { ending in
        ending.numbers.map { number in
            let sameMeasureStop = measure.repeatEndings.contains { candidate in
                candidate.numbers.contains(number)
                    && (candidate.kind == .stop || candidate.kind == .discontinue)
            }
            let label = "\(number)."
            let startHookEnd = CGPoint(x: lineStart.x, y: lineStart.y + hookLength)
            let endHookEnd = sameMeasureStop ? CGPoint(x: lineEnd.x, y: lineEnd.y + hookLength) : nil
            let labelPoint = CGPoint(x: lineStart.x + metrics.staffSpace * 0.75, y: lineStart.y + labelHeight * 0.65)
            let frame = CGRect(
                x: lineStart.x - metrics.staffLineHitHalfWidth * 2,
                y: min(lineStart.y, labelPoint.y - labelHeight) - metrics.staffLineHitHalfWidth * 2,
                width: lineEnd.x - lineStart.x + metrics.staffLineHitHalfWidth * 4,
                height: max(hookLength, labelPoint.y - lineStart.y + labelHeight * 0.35) + metrics.staffLineHitHalfWidth * 4
            )
            let layout = RepeatEndingLayout(
                numbers: [number],
                label: label,
                kind: ending.kind,
                startsHere: true,
                stopsHere: sameMeasureStop,
                lineStart: lineStart,
                lineEnd: lineEnd,
                startHookEnd: startHookEnd,
                endHookEnd: endHookEnd,
                labelPoint: labelPoint,
                frame: frame
            )
            return ElementLayout(
                id: ScoreElementID(rawValue: "\(measure.id.rawValue).repeatEnding.\(number).start"),
                kind: .repeatEnding,
                measureID: measure.id,
                staffID: staffIDs.first,
                frame: frame,
                repeatEnding: layout
            )
        }
    }
}

private func measureRepeatElements(
    measure: Measure,
    staffIDs: [StaffID],
    staffIndexByID: [StaffID: Int],
    measureX: CGFloat,
    measureWidth: CGFloat,
    systemTop: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    guard let measureRepeat = measure.measureRepeat else {
        return []
    }

    return staffIDs.map { staffID in
        let staffIndex = staffIndexByID[staffID] ?? 0
        let middleY = metrics.staffMiddleY(systemTop: systemTop, staffIndex: staffIndex)
        let size = metrics.staffSpace * 3.0
        let frame = CGRect(
            x: measureX + measureWidth / 2 - size / 2,
            y: middleY - size / 2,
            width: size,
            height: size
        )
        return ElementLayout(
            id: ScoreElementID(rawValue: "\(measure.id.rawValue).measureRepeat.\(staffID.rawValue)"),
            kind: .measureRepeat,
            measureID: measure.id,
            staffID: staffID,
            frame: frame,
            measureRepeat: measureRepeat
        )
    }
}

private func playbackJumpMarkerElements(
    measure: Measure,
    staffIDs: [StaffID],
    staffIndexByID: [StaffID: Int],
    measureX: CGFloat,
    measureWidth: CGFloat,
    systemTop: CGFloat,
    metrics: LayoutMetrics
) -> [ElementLayout] {
    guard !measure.playbackJumpMarkers.isEmpty, let topStaffID = staffIDs.first else {
        return []
    }

    let topStaffIndex = staffIndexByID[topStaffID] ?? 0
    let topStaffTop = metrics.staffMiddleY(systemTop: systemTop, staffIndex: topStaffIndex) - metrics.staffHeight / 2
    let markerHeight = metrics.staffSpace * 1.15
    let baseY = topStaffTop - metrics.staffSpace * 1.55
    let baseX = measureX + min(measureWidth * 0.18, metrics.staffSpace * 2.8)

    return measure.playbackJumpMarkers.enumerated().map { index, marker in
        let label = playbackJumpMarkerLabel(for: marker)
        let width = max(metrics.staffSpace * 2.3, CGFloat(label.count) * metrics.staffSpace * 0.48)
        let point = CGPoint(
            x: baseX + CGFloat(index) * (width + metrics.staffSpace * 0.5),
            y: baseY - CGFloat(index / 2) * markerHeight
        )
        let frame = CGRect(
            x: point.x - metrics.staffSpace * 0.25,
            y: point.y - markerHeight * 0.55,
            width: width + metrics.staffSpace * 0.5,
            height: markerHeight
        )
        let layout = PlaybackJumpMarkerLayout(marker: marker, label: label, point: point, frame: frame)
        return ElementLayout(
            id: ScoreElementID(rawValue: "\(measure.id.rawValue).jump.\(index).\(marker.kind.rawValue)"),
            kind: .playbackJumpMarker,
            measureID: measure.id,
            staffID: topStaffID,
            frame: frame,
            playbackJumpMarker: layout
        )
    }
}

private func playbackJumpMarkerLabel(for marker: PlaybackJumpMarker) -> String {
    switch marker.kind {
    case .fine:
        return "Fine"
    case .daCapo:
        return "D.C."
    case .daCapoAlFine:
        return "D.C. al Fine"
    case .daCapoAlCoda:
        return "D.C. al Coda"
    case .dalSegno:
        return "D.S."
    case .dalSegnoAlFine:
        return "D.S. al Fine"
    case .dalSegnoAlCoda:
        return "D.S. al Coda"
    case .segno:
        return "Segno"
    case .coda:
        return "Coda"
    case .toCoda:
        return "To Coda"
    }
}

private func forwardRepeatX(
    for measure: Measure,
    measureX: CGFloat,
    elements: [ElementLayout],
    noteByID: [NoteID: NoteLayout],
    metrics: LayoutMetrics
) -> CGFloat {
    let prefixKinds: Set<ScoreElementKind> = [.clef, .keySignature, .timeSignature]
    let prefixEndX = elements
        .filter { $0.measureID == measure.id && prefixKinds.contains($0.kind) }
        .map(\.frame.maxX)
        .max()

    guard let prefixEndX else {
        return measureX
    }

    let firstNoteMinX = measure.notes
        .compactMap { noteByID[$0.id]?.noteheadFrame.minX }
        .min()
    let desiredX = prefixEndX + metrics.staffSpace * 0.85
    let minimumX = prefixEndX + metrics.staffSpace * 0.45
    let xBeforeFirstNote = firstNoteMinX.map { $0 - metrics.staffSpace * 0.70 } ?? desiredX
    return max(measureX, max(minimumX, min(desiredX, xBeforeFirstNote)))
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
    let firstKeyX = measureX + metrics.staffSpace * 4.0
    return pitches.enumerated().map { index, pitch in
        let position = staffPosition(pitch: pitch, clef: clef)
        let center = CGPoint(
            x: firstKeyX + CGFloat(index) * keySignatureAccidentalSpacing(metrics: metrics),
            y: middleY - CGFloat(position.stepsFromMiddleLine) * metrics.staffSpace / 2
        )
        let frame = CGRect(
            x: center.x - metrics.noteheadSize.width * 0.45,
            y: center.y - metrics.noteheadSize.height * 0.70,
            width: metrics.noteheadSize.width * 0.95,
            height: metrics.noteheadSize.height * 1.6
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
