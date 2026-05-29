import Foundation

public struct PlaybackEvent: Hashable, Sendable {
    public let noteIDs: [NoteID]
    public let onset: MusicalTime
    public let nominalDuration: MusicalTime
    public let midiPitches: [Int]
    public let midiPitchDurations: [Int: MusicalTime]
    public let measureID: MeasureID
    public let staffIDs: [StaffID]
    public let isTiedContinuation: Bool
    public let expression: PlaybackExpression

    init(
        noteIDs: [NoteID],
        onset: MusicalTime,
        nominalDuration: MusicalTime,
        midiPitches: [Int],
        midiPitchDurations: [Int: MusicalTime] = [:],
        measureID: MeasureID,
        staffIDs: [StaffID],
        isTiedContinuation: Bool,
        expression: PlaybackExpression = .neutral
    ) {
        self.noteIDs = noteIDs
        self.onset = onset
        self.nominalDuration = nominalDuration
        self.midiPitches = midiPitches
        self.midiPitchDurations = midiPitchDurations
        self.measureID = measureID
        self.staffIDs = staffIDs
        self.isTiedContinuation = isTiedContinuation
        self.expression = expression
    }
}

public struct PlaybackExpression: Hashable, Sendable {
    public let gateScale: Double
    public let velocityScale: Double
    public let durationScale: Double
    public let maxDurationExtraSeconds: Double
    public let articulationKinds: [ScoreArticulationKind]
    public let dynamicMark: DynamicMark?

    public init(
        gateScale: Double = 1.0,
        velocityScale: Double = 1.0,
        durationScale: Double = 1.0,
        maxDurationExtraSeconds: Double = 0.0,
        articulationKinds: [ScoreArticulationKind] = [],
        dynamicMark: DynamicMark? = nil
    ) {
        self.gateScale = gateScale.isFinite ? min(max(gateScale, 0.20), 1.15) : 1.0
        self.velocityScale = velocityScale.isFinite ? min(max(velocityScale, 0.20), 1.60) : 1.0
        self.durationScale = durationScale.isFinite ? min(max(durationScale, 1.0), 2.0) : 1.0
        self.maxDurationExtraSeconds = maxDurationExtraSeconds.isFinite ? min(max(maxDurationExtraSeconds, 0), 2.0) : 0.0
        self.articulationKinds = Array(Set(articulationKinds)).sorted { $0.rawValue < $1.rawValue }
        self.dynamicMark = dynamicMark
    }

    public static let neutral = PlaybackExpression()
}

public struct PlaybackOptions: Hashable, Codable, Sendable {
    public var includeRests: Bool
    public var tempoOverride: Double?
    public var expandRepeats: Bool

    public init(includeRests: Bool = false, tempoOverride: Double? = nil, expandRepeats: Bool = true) {
        self.includeRests = includeRests
        self.tempoOverride = tempoOverride
        self.expandRepeats = expandRepeats
    }

    public static let `default` = PlaybackOptions()

    public var effectiveTempo: Double {
        tempoOverride ?? 120
    }
}

public struct PlaybackMetadata: Hashable, Sendable {
    public let tempoEvents: [TempoEvent]
    public let timeSignatureEvents: [TimeSignatureEvent]
    public let repeatBarlines: [RepeatBarline]
    public let diagnostics: [RendererDiagnostic]

    init(
        tempoEvents: [TempoEvent],
        timeSignatureEvents: [TimeSignatureEvent] = [],
        repeatBarlines: [RepeatBarline],
        diagnostics: [RendererDiagnostic]
    ) {
        self.tempoEvents = tempoEvents
        self.timeSignatureEvents = timeSignatureEvents
        self.repeatBarlines = repeatBarlines
        self.diagnostics = diagnostics
    }
}

public struct TimeSignatureEvent: Hashable, Sendable {
    public let measureID: MeasureID
    public let timeSignature: TimeSignature

    public init(measureID: MeasureID, timeSignature: TimeSignature) {
        self.measureID = measureID
        self.timeSignature = timeSignature
    }
}

struct PlaybackSequenceBuilder: Sendable {
    init() {}

    func build(score: ScoreDocument, options: PlaybackOptions = .default) -> [PlaybackEvent] {
        let records = eventRecords(score: score, options: options)
        guard options.expandRepeats else {
            return records.map(\.event)
        }
        return expandedEvents(records: records, score: score)
    }

    func metadata(score: ScoreDocument) -> PlaybackMetadata {
        let measures = score.parts.flatMap(\.measures)
        let repeats = measures.flatMap(\.repeatBarlines)
        return PlaybackMetadata(
            tempoEvents: measures.flatMap(\.tempoEvents),
            timeSignatureEvents: measures.compactMap { measure in
                measure.timeSignature.map {
                    TimeSignatureEvent(measureID: measure.id, timeSignature: $0)
                }
            },
            repeatBarlines: repeats,
            diagnostics: RepeatExpansionPlanner.diagnostics(score: score)
        )
    }

    private func eventRecords(score: ScoreDocument, options: PlaybackOptions) -> [PlaybackEventRecord] {
        let allEntries = orderedEntries(score: score, options: options)
        let grouped = Dictionary(grouping: allEntries) { entry in
            PlaybackGroupKey(
                measureIndex: entry.measureIndex,
                measureID: canonicalMeasureID(for: entry.measure.id),
                onset: entry.note.onset
            )
        }

        return grouped
            .map { key, entries in
                PlaybackEventRecord(
                    key: key,
                    event: makeEvent(key: key, entries: entries, allEntries: allEntries)
                )
            }
            .sorted { lhs, rhs in
                lhs.key < rhs.key
            }
    }

    private func expandedEvents(records: [PlaybackEventRecord], score: ScoreDocument) -> [PlaybackEvent] {
        guard score.parts.contains(where: { part in
            part.measures.contains {
                !$0.repeatBarlines.isEmpty || !$0.repeatEndings.isEmpty || !$0.playbackJumpMarkers.isEmpty
            }
        }) else {
            return records.map(\.event)
        }

        let recordsByMeasure = Dictionary(grouping: records) { record in
            record.key.measureIndex
        }

        var expanded: [PlaybackEvent] = []
        let primaryMeasures = score.parts.first?.measures ?? []
        let measureOrder = RepeatExpansionPlanner.expandedMeasureOrder(for: primaryMeasures)
        for measureIndex in measureOrder {
            expanded.append(contentsOf: recordsByMeasure[measureIndex, default: []].map(\.event))
        }
        return expanded
    }

    private func orderedEntries(score: ScoreDocument, options: PlaybackOptions) -> [PlaybackEntry] {
        var entries: [PlaybackEntry] = []
        for (partIndex, part) in score.parts.enumerated() {
            for (measureIndex, measure) in part.measures.enumerated() {
                for (noteIndex, note) in measure.notes.enumerated() {
                    if note.isGrace {
                        continue
                    }
                    if note.pitch == nil && !options.includeRests {
                        continue
                    }
                    entries.append(PlaybackEntry(
                        partIndex: partIndex,
                        measureIndex: measureIndex,
                        noteIndex: noteIndex,
                        measure: measure,
                        note: note
                    ))
                }
            }
        }
        return entries.sorted()
    }

    private func makeEvent(
        key: PlaybackGroupKey,
        entries: [PlaybackEntry],
        allEntries: [PlaybackEntry]
    ) -> PlaybackEvent {
        let orderedEntries = entries.sorted()
        let notes = orderedEntries.map(\.note)
        let pitchedNotes = notes.filter { $0.pitch != nil }
        // Tie starts carry their immediate stop-only continuation as sustained playback time.
        let attackEntries = orderedEntries.filter { $0.note.pitch != nil && !isTieStopOnly($0.note) }
        let attackNotes = attackEntries.map(\.note)
        let durationSource = attackNotes.isEmpty ? notes : attackNotes
        let duration = durationSource.map(\.duration).max() ?? MusicalTime(ticks: 0, ticksPerQuarterNote: key.onset.ticksPerQuarterNote)
        let midiPitches = attackNotes.compactMap { note in
            note.pitch.map(midiPitch(for:))
        }
        let midiPitchDurations = attackEntries.reduce(into: [Int: MusicalTime]()) { result, entry in
            let note = entry.note
            guard let pitch = note.pitch else {
                return
            }
            let midiPitch = midiPitch(for: pitch)
            let duration = tiedPlaybackDuration(for: entry, in: allEntries)
            if let existing = result[midiPitch] {
                result[midiPitch] = max(existing, duration)
            } else {
                result[midiPitch] = duration
            }
        }
        let staffIDs = Array(Set(notes.map(\.staffID))).sorted { $0.rawValue < $1.rawValue }
        let isTiedContinuation = !pitchedNotes.isEmpty && pitchedNotes.allSatisfy(isTieStopOnly)
        let expression = playbackExpression(
            notes: attackNotes.isEmpty ? notes : attackNotes,
            measure: orderedEntries.first?.measure,
            measureIndex: key.measureIndex,
            allEntries: allEntries,
            onset: key.onset
        )

        return PlaybackEvent(
            noteIDs: notes.map(\.id),
            onset: key.onset,
            nominalDuration: duration,
            midiPitches: midiPitches,
            midiPitchDurations: midiPitchDurations,
            measureID: key.measureID,
            staffIDs: staffIDs,
            isTiedContinuation: isTiedContinuation,
            expression: expression
        )
    }

    private func playbackExpression(
        notes: [ScoreNote],
        measure: Measure?,
        measureIndex: Int,
        allEntries: [PlaybackEntry],
        onset: MusicalTime
    ) -> PlaybackExpression {
        let articulations = notes.flatMap(\.articulations)
        var gateScale = 1.0
        var velocityScale = 1.0
        var durationScale = 1.0
        var maxDurationExtraSeconds = 0.0

        if articulations.contains(.staccato) {
            gateScale = min(gateScale, 0.42)
        } else if articulations.contains(.marcato) {
            gateScale = min(gateScale, 0.82)
        } else if articulations.contains(.tenuto) {
            gateScale = max(gateScale, 1.10)
        }

        if articulations.contains(.accent) {
            velocityScale *= 1.20
        }
        if articulations.contains(.marcato) {
            velocityScale *= 1.25
        }
        if articulations.contains(.fermata) {
            durationScale = 1.5
            maxDurationExtraSeconds = 1.0
        }

        let activeDynamic = activeDynamicMark(in: measure, at: onset)
        if let activeDynamic {
            velocityScale *= activeDynamic.velocityScale
        }
        if let wedgeScale = activeWedgeVelocityScale(
            measureIndex: measureIndex,
            onset: onset,
            allEntries: allEntries
        ) ?? activeWedgeVelocityScale(in: measure, at: onset) {
            velocityScale *= wedgeScale
        }

        return PlaybackExpression(
            gateScale: gateScale,
            velocityScale: velocityScale,
            durationScale: durationScale,
            maxDurationExtraSeconds: maxDurationExtraSeconds,
            articulationKinds: articulations,
            dynamicMark: activeDynamic
        )
    }

    private func activeDynamicMark(in measure: Measure?, at onset: MusicalTime) -> DynamicMark? {
        measure?.directions
            .filter { direction in
                if case .dynamic = direction.kind {
                    return direction.onset <= onset
                }
                return false
            }
            .max { $0.onset < $1.onset }
            .flatMap { direction -> DynamicMark? in
                if case .dynamic(let mark) = direction.kind {
                    return mark
                }
                return nil
            }
    }

    private func activeWedgeVelocityScale(in measure: Measure?, at onset: MusicalTime) -> Double? {
        guard let directions = measure?.directions.sorted(by: { $0.onset < $1.onset }) else {
            return nil
        }
        var activeStart: ScoreDirection?
        for direction in directions {
            switch direction.kind {
            case .wedge(.crescendo), .wedge(.diminuendo):
                if direction.onset <= onset {
                    activeStart = direction
                }
            case .wedge(.stop):
                guard let start = activeStart, start.onset <= onset, onset <= direction.onset else {
                    activeStart = nil
                    continue
                }
                let startValue = musicalTimeDouble(start.onset)
                let endValue = musicalTimeDouble(direction.onset)
                let currentValue = musicalTimeDouble(onset)
                guard endValue > startValue else {
                    return nil
                }
                let progress = min(max((currentValue - startValue) / (endValue - startValue), 0), 1)
                if case .wedge(.crescendo) = start.kind {
                    return 0.70 + progress * 0.60
                }
                return 1.30 - progress * 0.60
            default:
                break
            }
        }
        return nil
    }

    private func activeWedgeVelocityScale(
        measureIndex: Int,
        onset: MusicalTime,
        allEntries: [PlaybackEntry]
    ) -> Double? {
        let measures = Dictionary(grouping: allEntries, by: \.measureIndex)
            .compactMapValues { entries in entries.first?.measure }
        guard !measures.isEmpty else {
            return nil
        }
        let orderedMeasureIndices = measures.keys.sorted()
        var measureStartQuarters: [Int: Double] = [:]
        var runningQuarters = 0.0
        for index in orderedMeasureIndices {
            measureStartQuarters[index] = runningQuarters
            if let measure = measures[index] {
                runningQuarters += max(0.0, measureDurationQuarters(measure))
            }
        }
        guard let currentMeasureStart = measureStartQuarters[measureIndex] else {
            return nil
        }
        let currentQuarters = currentMeasureStart + musicalTimeDouble(onset)
        var pending: [PlaybackWedgeAnchor] = []
        for index in orderedMeasureIndices {
            guard let measure = measures[index],
                  let measureStart = measureStartQuarters[index]
            else {
                continue
            }
            for direction in measure.directions.sorted(by: { $0.onset < $1.onset }) {
                let absoluteQuarters = measureStart + musicalTimeDouble(direction.onset)
                switch direction.kind {
                case .wedge(.crescendo), .wedge(.diminuendo):
                    pending.append(PlaybackWedgeAnchor(
                        direction: direction,
                        measureIndex: index,
                        startQuarters: absoluteQuarters
                    ))
                case .wedge(.stop):
                    guard let pendingIndex = pending.lastIndex(where: { $0.direction.staffID == direction.staffID }) else {
                        continue
                    }
                    let start = pending.remove(at: pendingIndex)
                    guard start.startQuarters <= currentQuarters,
                          currentQuarters <= absoluteQuarters,
                          absoluteQuarters > start.startQuarters
                    else {
                        continue
                    }
                    let progress = min(max((currentQuarters - start.startQuarters) / (absoluteQuarters - start.startQuarters), 0), 1)
                    if case .wedge(.crescendo) = start.direction.kind {
                        return 0.70 + progress * 0.60
                    }
                    return 1.30 - progress * 0.60
                default:
                    break
                }
            }
        }
        return nil
    }

    private func measureDurationQuarters(_ measure: Measure) -> Double {
        let noteDuration = measure.notes
            .filter { !$0.isGrace }
            .map { musicalTimeDouble($0.onset + $0.duration) }
            .max() ?? 0
        if noteDuration > 0 {
            return noteDuration
        }
        if let timeSignature = measure.timeSignature {
            return Double(timeSignature.beats) * (4.0 / Double(timeSignature.beatType))
        }
        return 4.0
    }

    private func midiPitch(for pitch: Pitch) -> Int {
        let semitone: Int
        switch pitch.step {
        case .c: semitone = 0
        case .d: semitone = 2
        case .e: semitone = 4
        case .f: semitone = 5
        case .g: semitone = 7
        case .a: semitone = 9
        case .b: semitone = 11
        }
        return (pitch.octave + 1) * 12 + semitone + pitch.alter
    }

    private func isTieStopOnly(_ note: ScoreNote) -> Bool {
        note.ties.contains(.stop) && !note.ties.contains(.start)
    }

    private func tiedPlaybackDuration(for entry: PlaybackEntry, in allEntries: [PlaybackEntry]) -> MusicalTime {
        let note = entry.note
        guard note.ties.contains(.start), let pitch = note.pitch else {
            return note.duration
        }

        let orderedEntries = allEntries.sorted()
        guard let startIndex = orderedEntries.firstIndex(where: { $0.note.id == note.id }) else {
            return note.duration
        }

        var duration = note.duration
        for continuationEntry in orderedEntries.suffix(from: orderedEntries.index(after: startIndex)) {
            let continuation = continuationEntry.note
            guard continuationEntry.partIndex == entry.partIndex,
                  continuation.pitch == pitch,
                  continuation.staffID == note.staffID,
                  continuation.voiceID == note.voiceID,
                  isTieStopOnly(continuation)
            else {
                continue
            }
            duration = duration + continuation.duration
            break
        }
        return duration
    }

    private func canonicalMeasureID(for measureID: MeasureID) -> MeasureID {
        let pieces = measureID.rawValue.split(separator: ".", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else {
            return measureID
        }
        return MeasureID(partIndex: 0, measureNumber: pieces[1])
    }
}

private func musicalTimeDouble(_ time: MusicalTime) -> Double {
    Double(time.ticks) / Double(max(1, time.ticksPerQuarterNote))
}

private struct RepeatExpansionPlanner {
    private static let maxJumpCount = 16
    private static let maxRepeatPasses = 4

    static func expandedMeasureOrder(for measures: [Measure]) -> [Int] {
        plan(for: measures).order
    }

    static func diagnostics(score: ScoreDocument) -> [RendererDiagnostic] {
        score.parts.flatMap { part in
            plan(for: part.measures).diagnostics
        }
    }

    private static func plan(for measures: [Measure]) -> (order: [Int], diagnostics: [RendererDiagnostic]) {
        if let jumpPlan = jumpOnlyPlan(for: measures) {
            return jumpPlan
        }

        var order: [Int] = []
        var diagnostics: [RendererDiagnostic] = []
        var repeatStartIndex: Int?
        var nestedRepeatReported = false
        let hasEndings = measures.contains { !$0.repeatEndings.isEmpty }

        diagnostics.append(contentsOf: repeatEndingDiagnostics(for: measures))
        diagnostics.append(contentsOf: jumpDiagnostics(for: measures))

        var measureIndex = 0
        while measureIndex < measures.count {
            let measure = measures[measureIndex]
            order.append(measureIndex)

            for repeatBarline in measure.repeatBarlines where repeatBarline.direction == .forward {
                if repeatStartIndex != nil && !nestedRepeatReported {
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.nestedUnsupported",
                        message: "Nested or overlapping repeat starts are not expanded by the repeat playback MVP.",
                        location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
                    ))
                    nestedRepeatReported = true
                    if hasEndings {
                        diagnostics.append(RendererDiagnostic(
                            severity: .warning,
                            code: "repeat.endingNestedUnsupported",
                            message: "Nested repeats with endings are not expanded by the advanced repeat playback MVP.",
                            location: MusicXMLLocation(elementName: "ending", measureNumber: measure.number)
                        ))
                    }
                } else {
                    repeatStartIndex = measureIndex
                }

                if let times = repeatBarline.times, times != 2 {
                    diagnostics.append(unsupportedRepeatCountDiagnostic(times: times, measure: measure))
                }
            }

            for repeatBarline in measure.repeatBarlines where repeatBarline.direction == .backward {
                let repeatPasses = repeatPassCount(for: repeatBarline, measure: measure, diagnostics: &diagnostics)

                let startIndex: Int
                if let repeatStartIndex {
                    startIndex = repeatStartIndex
                } else {
                    startIndex = 0
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.startMissingFallback",
                        message: "Backward repeat without a forward repeat start falls back to repeating from the beginning.",
                        location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
                    ))
                }

                if startIndex <= measureIndex {
                    if let nextIndex = appendSecondPassWithEndings(
                        startIndex: startIndex,
                        endIndex: measureIndex,
                        measures: measures,
                        order: &order,
                        diagnostics: &diagnostics
                    ) {
                        if repeatPasses != 2 {
                            diagnostics.append(unsupportedRepeatCountDiagnostic(times: repeatPasses, measure: measure))
                        }
                        repeatStartIndex = nil
                        measureIndex = nextIndex
                        continue
                    } else {
                        for _ in 1..<repeatPasses {
                            order.append(contentsOf: startIndex...measureIndex)
                        }
                    }
                }
                repeatStartIndex = nil
            }

            measureIndex += 1
        }

        if let repeatStartIndex {
            let measure = measures[repeatStartIndex]
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.startWithoutEndUnsupported",
                message: "Forward repeat without a matching backward repeat is displayed but not expanded in playback.",
                location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
            ))
        }

        return (order, diagnostics)
    }

    private static func appendSecondPassWithEndings(
        startIndex: Int,
        endIndex: Int,
        measures: [Measure],
        order: inout [Int],
        diagnostics: inout [RendererDiagnostic]
    ) -> Int? {
        let firstEnding = endingRange(number: 1, measures: measures, lowerBound: startIndex, upperBound: endIndex)
        let secondEnding = endingRange(number: 2, measures: measures, lowerBound: startIndex, upperBound: measures.count - 1)

        guard firstEnding != nil || secondEnding != nil else {
            return nil
        }
        guard let firstEnding else {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.endingFirstMissing",
                message: "Second ending was found without a matching first ending; playback falls back to simple repeat expansion.",
                location: MusicXMLLocation(elementName: "ending", measureNumber: measures[endIndex].number)
            ))
            return nil
        }
        guard let secondEnding else {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.endingSecondMissing",
                message: "First ending was found without a matching second ending; playback falls back to simple repeat expansion.",
                location: MusicXMLLocation(elementName: "ending", measureNumber: measures[firstEnding.lowerBound].number)
            ))
            return nil
        }
        guard firstEnding.upperBound <= endIndex, secondEnding.lowerBound > endIndex else {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.endingAmbiguous",
                message: "Repeat endings are not in the supported first-ending-before-repeat-end and second-ending-after-repeat-end shape.",
                location: MusicXMLLocation(elementName: "ending", measureNumber: measures[endIndex].number)
            ))
            return nil
        }

        for repeatedMeasureIndex in startIndex...endIndex where !firstEnding.contains(repeatedMeasureIndex) {
            order.append(repeatedMeasureIndex)
        }
        order.append(contentsOf: secondEnding)
        return secondEnding.upperBound
    }

    private static func endingRange(
        number: Int,
        measures: [Measure],
        lowerBound: Int,
        upperBound: Int
    ) -> ClosedRange<Int>? {
        guard lowerBound <= upperBound, lowerBound < measures.count else {
            return nil
        }
        let clampedUpper = min(upperBound, measures.count - 1)
        var activeStart: Int?
        var firstMatch: Int?
        for index in lowerBound...clampedUpper {
            let endings = measures[index].repeatEndings.filter { $0.numbers.contains(number) }
            guard !endings.isEmpty else {
                continue
            }
            firstMatch = firstMatch ?? index
            if endings.contains(where: { $0.kind == .start }) {
                activeStart = index
            }
            if endings.contains(where: { $0.kind == .stop || $0.kind == .discontinue }) {
                return (activeStart ?? index)...index
            }
        }
        if let activeStart {
            return activeStart...activeStart
        }
        if let firstMatch {
            return firstMatch...firstMatch
        }
        return nil
    }

    private static func repeatEndingDiagnostics(for measures: [Measure]) -> [RendererDiagnostic] {
        var diagnostics: [RendererDiagnostic] = []
        let hasBackwardRepeat = measures.contains { measure in
            measure.repeatBarlines.contains { $0.direction == .backward }
        }
        for measure in measures {
            for ending in measure.repeatEndings {
                if ending.numbers.isEmpty {
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.endingInvalid",
                        message: "Repeat ending without number is ignored for playback expansion.",
                        location: MusicXMLLocation(elementName: "ending", measureNumber: measure.number)
                    ))
                }
                if ending.numbers.contains(where: { $0 > 2 }) {
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.endingNumberUnsupported",
                        message: "Repeat endings beyond first and second endings are not supported by the advanced repeat playback MVP.",
                        location: MusicXMLLocation(elementName: "ending", measureNumber: measure.number)
                    ))
                }
                if ending.kind == .unknown {
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.endingTypeUnsupported",
                        message: "Repeat ending type is not supported by the advanced repeat playback MVP.",
                        location: MusicXMLLocation(elementName: "ending", measureNumber: measure.number)
                    ))
                }
                if !hasBackwardRepeat {
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "repeat.endingWithoutRepeat",
                        message: "Repeat ending was found without a backward repeat; ending playback expansion will ignore it.",
                        location: MusicXMLLocation(elementName: "ending", measureNumber: measure.number)
                    ))
                }
            }
        }
        return diagnostics
    }

    private static func jumpOnlyPlan(for measures: [Measure]) -> (order: [Int], diagnostics: [RendererDiagnostic])? {
        let containsRepeatStructure = measures.contains { !$0.repeatBarlines.isEmpty || !$0.repeatEndings.isEmpty }
        guard !containsRepeatStructure else {
            return nil
        }
        let instructionKinds: Set<PlaybackJumpMarkerKind> = [
            .daCapoAlFine,
            .dalSegnoAlFine,
            .daCapoAlCoda,
            .dalSegnoAlCoda,
        ]
        let instructions = measures.enumerated().flatMap { index, measure in
            measure.playbackJumpMarkers
                .filter { instructionKinds.contains($0.kind) }
                .map { (index: index, marker: $0) }
        }
        guard let instruction = instructions.first else {
            return nil
        }

        var diagnostics = jumpDiagnostics(for: measures)
        if instructions.count > 1 {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "jump.multipleInstructionsUnsupported",
                message: "Multiple repeat jump instructions were found; jump playback expansion falls back to linear playback.",
                location: MusicXMLLocation(elementName: "words", measureNumber: measures[instruction.index].number)
            ))
            return (Array(measures.indices), diagnostics)
        }

        let order: [Int]?
        switch instruction.marker.kind {
        case .daCapoAlFine:
            order = daCapoAlFineOrder(instructionIndex: instruction.index, measures: measures, diagnostics: &diagnostics)
        case .dalSegnoAlFine:
            order = dalSegnoAlFineOrder(instructionIndex: instruction.index, measures: measures, diagnostics: &diagnostics)
        case .daCapoAlCoda:
            order = daCapoAlCodaOrder(instructionIndex: instruction.index, measures: measures, diagnostics: &diagnostics)
        case .dalSegnoAlCoda:
            order = dalSegnoAlCodaOrder(instructionIndex: instruction.index, measures: measures, diagnostics: &diagnostics)
        case .fine, .daCapo, .dalSegno, .segno, .coda, .toCoda:
            order = nil
        }

        guard let order else {
            return (Array(measures.indices), diagnostics)
        }
        return boundedJumpPlan(order: order, measures: measures, diagnostics: diagnostics)
    }

    private static func daCapoAlFineOrder(
        instructionIndex: Int,
        measures: [Measure],
        diagnostics: inout [RendererDiagnostic]
    ) -> [Int]? {
        guard let fineIndex = firstMarkerIndex(.fine, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.dcFineMissing",
                message: "D.C. al Fine was found without a Fine marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        return Array(0...instructionIndex) + Array(0...fineIndex)
    }

    private static func dalSegnoAlFineOrder(
        instructionIndex: Int,
        measures: [Measure],
        diagnostics: inout [RendererDiagnostic]
    ) -> [Int]? {
        guard let segnoIndex = firstMarkerIndex(.segno, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.dsSegnoMissing",
                message: "D.S. al Fine was found without a Segno marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard let fineIndex = firstMarkerIndex(.fine, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.dsFineMissing",
                message: "D.S. al Fine was found without a Fine marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard segnoIndex <= fineIndex else {
            diagnostics.append(ambiguousJumpDiagnostic(measure: measures[instructionIndex]))
            return nil
        }
        return Array(0...instructionIndex) + Array(segnoIndex...fineIndex)
    }

    private static func daCapoAlCodaOrder(
        instructionIndex: Int,
        measures: [Measure],
        diagnostics: inout [RendererDiagnostic]
    ) -> [Int]? {
        guard let toCodaIndex = firstMarkerIndex(.toCoda, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.toCodaMissing",
                message: "D.C. al Coda was found without a To Coda marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard let codaIndex = firstMarkerIndex(.coda, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.codaMissing",
                message: "D.C. al Coda was found without a Coda marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard toCodaIndex < codaIndex else {
            diagnostics.append(ambiguousJumpDiagnostic(measure: measures[instructionIndex]))
            return nil
        }
        return Array(0...instructionIndex) + Array(0...toCodaIndex) + Array(codaIndex..<measures.count)
    }

    private static func dalSegnoAlCodaOrder(
        instructionIndex: Int,
        measures: [Measure],
        diagnostics: inout [RendererDiagnostic]
    ) -> [Int]? {
        guard let segnoIndex = firstMarkerIndex(.segno, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.dsSegnoMissing",
                message: "D.S. al Coda was found without a Segno marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard let toCodaIndex = firstMarkerIndex(.toCoda, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.toCodaMissing",
                message: "D.S. al Coda was found without a To Coda marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard let codaIndex = firstMarkerIndex(.coda, in: measures) else {
            diagnostics.append(missingJumpMarkerDiagnostic(
                code: "jump.codaMissing",
                message: "D.S. al Coda was found without a Coda marker; jump playback is not expanded.",
                measure: measures[instructionIndex]
            ))
            return nil
        }
        guard segnoIndex <= toCodaIndex, toCodaIndex < codaIndex else {
            diagnostics.append(ambiguousJumpDiagnostic(measure: measures[instructionIndex]))
            return nil
        }
        return Array(0...instructionIndex) + Array(segnoIndex...toCodaIndex) + Array(codaIndex..<measures.count)
    }

    private static func firstMarkerIndex(_ kind: PlaybackJumpMarkerKind, in measures: [Measure]) -> Int? {
        measures.firstIndex { measure in
            measure.playbackJumpMarkers.contains { $0.kind == kind }
        }
    }

    private static func boundedJumpPlan(
        order: [Int],
        measures: [Measure],
        diagnostics: [RendererDiagnostic]
    ) -> (order: [Int], diagnostics: [RendererDiagnostic]) {
        var diagnostics = diagnostics
        let maxExpandedMeasures = max(measures.count * 8, measures.count + maxJumpCount)
        guard order.count <= maxExpandedMeasures else {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "jump.expansionLimitExceeded",
                message: "Jump playback expansion exceeded the safe MVP limit and falls back to linear playback.",
                location: MusicXMLLocation(elementName: "words")
            ))
            return (Array(measures.indices), diagnostics)
        }
        return (order, diagnostics)
    }

    private static func jumpDiagnostics(for measures: [Measure]) -> [RendererDiagnostic] {
        var diagnostics: [RendererDiagnostic] = []
        let containsRepeatStructure = measures.contains { !$0.repeatBarlines.isEmpty || !$0.repeatEndings.isEmpty }
        let markerCounts = Dictionary(grouping: measures.flatMap(\.playbackJumpMarkers), by: \.kind).mapValues(\.count)
        if markerCounts[.segno, default: 0] > 1 {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "jump.multipleSegnoUnsupported",
                message: "Multiple Segno markers are not supported by the jump playback MVP.",
                location: MusicXMLLocation(elementName: "words")
            ))
        }
        if markerCounts[.coda, default: 0] > 1 {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "jump.multipleCodaUnsupported",
                message: "Multiple Coda markers are not supported by the jump playback MVP.",
                location: MusicXMLLocation(elementName: "words")
            ))
        }
        let hasAlCodaInstruction = measures.contains { measure in
            measure.playbackJumpMarkers.contains { marker in
                marker.kind == .daCapoAlCoda || marker.kind == .dalSegnoAlCoda
            }
        }
        for measure in measures {
            for marker in measure.playbackJumpMarkers {
                switch marker.kind {
                case .daCapoAlFine, .dalSegnoAlFine, .daCapoAlCoda, .dalSegnoAlCoda:
                    if containsRepeatStructure {
                        diagnostics.append(RendererDiagnostic(
                            severity: .warning,
                            code: "jump.withRepeatsUnsupported",
                            message: "Jump markers combined with repeats or endings are not expanded by the complete repeat playback MVP.",
                            location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
                        ))
                    }
                case .fine:
                    break
                case .daCapo:
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "jump.daCapoUnsupported",
                        message: "D.C. without Fine is recognized but not expanded by the advanced repeat playback MVP.",
                        location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
                    ))
                case .dalSegno:
                    diagnostics.append(RendererDiagnostic(
                        severity: .warning,
                        code: "jump.dalSegnoUnsupported",
                        message: "D.S. without Fine or Coda is recognized but not expanded by the complete repeat playback MVP.",
                        location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
                    ))
                case .segno:
                    break
                case .coda, .toCoda:
                    if !hasAlCodaInstruction {
                        diagnostics.append(RendererDiagnostic(
                            severity: .warning,
                            code: "jump.codaUnsupported",
                            message: "Coda and To Coda markers are recognized but require D.C. al Coda or D.S. al Coda for playback expansion.",
                            location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
                        ))
                    }
                }
            }
        }
        return diagnostics
    }

    private static func repeatPassCount(
        for repeatBarline: RepeatBarline,
        measure: Measure,
        diagnostics: inout [RendererDiagnostic]
    ) -> Int {
        guard let times = repeatBarline.times else {
            return 2
        }
        if times <= 0 {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.countInvalid",
                message: "Repeat count \(times) is invalid; playback uses the MVP default of two passes.",
                location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
            ))
            return 2
        }
        if times > maxRepeatPasses {
            diagnostics.append(RendererDiagnostic(
                severity: .warning,
                code: "repeat.countClamped",
                message: "Repeat count \(times) exceeds the MVP maximum; playback clamps to \(maxRepeatPasses) passes.",
                location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
            ))
            return maxRepeatPasses
        }
        return times
    }

    private static func unsupportedRepeatCountDiagnostic(times: Int, measure: Measure) -> RendererDiagnostic {
        RendererDiagnostic(
            severity: .warning,
            code: "repeat.countUnsupported",
            message: "Repeat count \(times) is recognized, but first/second ending playback remains limited to two passes.",
            location: MusicXMLLocation(elementName: "repeat", measureNumber: measure.number)
        )
    }

    private static func missingJumpMarkerDiagnostic(code: String, message: String, measure: Measure) -> RendererDiagnostic {
        RendererDiagnostic(
            severity: .warning,
            code: code,
            message: message,
            location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
        )
    }

    private static func ambiguousJumpDiagnostic(measure: Measure) -> RendererDiagnostic {
        RendererDiagnostic(
            severity: .warning,
            code: "jump.ambiguousLayout",
            message: "Jump markers are not in a supported order; playback falls back to linear playback.",
            location: MusicXMLLocation(elementName: "words", measureNumber: measure.number)
        )
    }
}

private struct PlaybackEventRecord {
    let key: PlaybackGroupKey
    let event: PlaybackEvent
}

private struct PlaybackEntry: Comparable {
    let partIndex: Int
    let measureIndex: Int
    let noteIndex: Int
    let measure: Measure
    let note: ScoreNote

    static func < (lhs: PlaybackEntry, rhs: PlaybackEntry) -> Bool {
        if lhs.partIndex != rhs.partIndex {
            return lhs.partIndex < rhs.partIndex
        }
        if lhs.measureIndex != rhs.measureIndex {
            return lhs.measureIndex < rhs.measureIndex
        }
        if lhs.note.onset != rhs.note.onset {
            return lhs.note.onset < rhs.note.onset
        }
        return lhs.noteIndex < rhs.noteIndex
    }
}

private struct PlaybackWedgeAnchor: Sendable {
    let direction: ScoreDirection
    let measureIndex: Int
    let startQuarters: Double
}

private struct PlaybackGroupKey: Hashable, Comparable {
    let measureIndex: Int
    let measureID: MeasureID
    let onset: MusicalTime

    static func < (lhs: PlaybackGroupKey, rhs: PlaybackGroupKey) -> Bool {
        if lhs.measureIndex != rhs.measureIndex {
            return lhs.measureIndex < rhs.measureIndex
        }
        return lhs.onset < rhs.onset
    }
}
