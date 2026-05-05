import Foundation

public struct PlaybackEvent: Hashable, Sendable {
    public let noteIDs: [NoteID]
    public let onset: MusicalTime
    public let nominalDuration: MusicalTime
    public let midiPitches: [Int]
    public let measureID: MeasureID
    public let staffIDs: [StaffID]
    public let isTiedContinuation: Bool

    init(
        noteIDs: [NoteID],
        onset: MusicalTime,
        nominalDuration: MusicalTime,
        midiPitches: [Int],
        measureID: MeasureID,
        staffIDs: [StaffID],
        isTiedContinuation: Bool
    ) {
        self.noteIDs = noteIDs
        self.onset = onset
        self.nominalDuration = nominalDuration
        self.midiPitches = midiPitches
        self.measureID = measureID
        self.staffIDs = staffIDs
        self.isTiedContinuation = isTiedContinuation
    }
}

public struct PlaybackOptions: Hashable, Codable, Sendable {
    public var includeRests: Bool
    public var tempoOverride: Double?

    public init(includeRests: Bool = false, tempoOverride: Double? = nil) {
        self.includeRests = includeRests
        self.tempoOverride = tempoOverride
    }

    public static let `default` = PlaybackOptions()

    public var effectiveTempo: Double {
        tempoOverride ?? 120
    }
}

public struct PlaybackMetadata: Hashable, Sendable {
    public let tempoEvents: [TempoEvent]
    public let repeatBarlines: [RepeatBarline]
    public let diagnostics: [RendererDiagnostic]

    init(
        tempoEvents: [TempoEvent],
        repeatBarlines: [RepeatBarline],
        diagnostics: [RendererDiagnostic]
    ) {
        self.tempoEvents = tempoEvents
        self.repeatBarlines = repeatBarlines
        self.diagnostics = diagnostics
    }
}

struct PlaybackSequenceBuilder: Sendable {
    init() {}

    func build(score: ScoreDocument, options: PlaybackOptions = .default) -> [PlaybackEvent] {
        let entries = orderedEntries(score: score, options: options)
        let grouped = Dictionary(grouping: entries) { entry in
            PlaybackGroupKey(
                partIndex: entry.partIndex,
                measureIndex: entry.measureIndex,
                measureID: entry.measure.id,
                onset: entry.note.onset
            )
        }

        return grouped
            .map { key, entries in makeEvent(key: key, entries: entries) }
            .sorted { lhs, rhs in
                guard let leftKey = groupedKey(for: lhs, in: grouped),
                      let rightKey = groupedKey(for: rhs, in: grouped)
                else {
                    return lhs.onset < rhs.onset
                }
                return leftKey < rightKey
            }
    }

    func metadata(score: ScoreDocument) -> PlaybackMetadata {
        let measures = score.parts.flatMap(\.measures)
        let repeats = measures.flatMap(\.repeatBarlines)
        let diagnostics = repeats.isEmpty ? [] : [
            RendererDiagnostic(
                severity: .warning,
                code: "repeat.playbackExpansionUnsupported",
                message: "Repeat barlines are parsed as metadata, but playback event expansion is not supported in Phase 11F."
            ),
        ]
        return PlaybackMetadata(
            tempoEvents: measures.flatMap(\.tempoEvents),
            repeatBarlines: repeats,
            diagnostics: diagnostics
        )
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

    private func makeEvent(key: PlaybackGroupKey, entries: [PlaybackEntry]) -> PlaybackEvent {
        let orderedEntries = entries.sorted()
        let notes = orderedEntries.map(\.note)
        let pitchedNotes = notes.filter { $0.pitch != nil }
        // MVP0 identifies tie continuations, but does not merge full tie-chain durations yet.
        let duration = notes.map(\.duration).max() ?? MusicalTime(ticks: 0, ticksPerQuarterNote: key.onset.ticksPerQuarterNote)
        let midiPitches = pitchedNotes.compactMap { note in
            note.pitch.map(midiPitch(for:))
        }
        let staffIDs = Array(Set(notes.map(\.staffID))).sorted { $0.rawValue < $1.rawValue }
        let isTiedContinuation = !pitchedNotes.isEmpty && pitchedNotes.allSatisfy(isTieStopOnly)

        return PlaybackEvent(
            noteIDs: notes.map(\.id),
            onset: key.onset,
            nominalDuration: duration,
            midiPitches: midiPitches,
            measureID: key.measureID,
            staffIDs: staffIDs,
            isTiedContinuation: isTiedContinuation
        )
    }

    private func groupedKey(
        for event: PlaybackEvent,
        in grouped: [PlaybackGroupKey: [PlaybackEntry]]
    ) -> PlaybackGroupKey? {
        grouped.first { key, entries in
            key.measureID == event.measureID
                && key.onset == event.onset
                && Set(entries.map(\.note.id)) == Set(event.noteIDs)
        }?.key
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

private struct PlaybackGroupKey: Hashable, Comparable {
    let partIndex: Int
    let measureIndex: Int
    let measureID: MeasureID
    let onset: MusicalTime

    static func < (lhs: PlaybackGroupKey, rhs: PlaybackGroupKey) -> Bool {
        if lhs.partIndex != rhs.partIndex {
            return lhs.partIndex < rhs.partIndex
        }
        if lhs.measureIndex != rhs.measureIndex {
            return lhs.measureIndex < rhs.measureIndex
        }
        return lhs.onset < rhs.onset
    }
}
