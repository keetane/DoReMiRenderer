import DoReMiRendererKit
import Foundation

enum PaletteMetronomeCompoundMode: String, CaseIterable, Identifiable {
    case largeBeat
    case subdivision

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .largeBeat:
            "大拍"
        case .subdivision:
            "細分"
        }
    }

    static func fromRawValue(_ rawValue: String) -> PaletteMetronomeCompoundMode {
        PaletteMetronomeCompoundMode(rawValue: rawValue) ?? .largeBeat
    }
}

enum PaletteMetronomeClickSoundStyle: String, CaseIterable, Identifiable {
    case classic
    case soft
    case wood
    case electronic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:
            "Classic"
        case .soft:
            "Soft"
        case .wood:
            "Wood"
        case .electronic:
            "Electronic"
        }
    }

    static func fromRawValue(_ rawValue: String) -> PaletteMetronomeClickSoundStyle {
        PaletteMetronomeClickSoundStyle(rawValue: rawValue) ?? .classic
    }
}

enum PaletteMetronomeAccent: Equatable {
    case strong
    case medium
    case weak
}

@MainActor
final class PalettePlaybackRuntime {
    var onStateChange: ((PalettePlaybackState) -> Void)?
    var onEventIndexChange: ((Int) -> Void)?
    var onAudioError: ((Error) -> Void)?

    private(set) var events: [PlaybackEvent] = []
    private(set) var tempoEvents: [TempoEvent] = []
    private(set) var timeSignatureEvents: [TimeSignatureEvent] = []
    private(set) var state: PalettePlaybackState = .stopped {
        didSet {
            guard state != oldValue else {
                return
            }
            onStateChange?(state)
        }
    }
    private(set) var currentEventIndex = 0
    private(set) var tempoBPM: Double
    private(set) var noteGateRatio: Double
    private(set) var transposeSemitones: Int
    private(set) var metronomeEnabled: Bool
    private(set) var metronomeCompoundMode: PaletteMetronomeCompoundMode
    private(set) var metronomeClickSoundStyle: PaletteMetronomeClickSoundStyle

    private let audioEngine: PaletteAudioEngine
    private var playbackTask: Task<Void, Never>?
    private var metronomeTask: Task<Void, Never>?
    private var metronomeBeatIndex = 0
    private var currentEventStartedAt: Date?
    private var tapTempoDates: [Date] = []
    private var usesManualTempoOverride = false
    private static let defaultTempoBPM: Double = 120
    private static let minimumAudibleDuration: TimeInterval = 0.06
    static let transposeRange = -12...12

    init(
        events: [PlaybackEvent] = [],
        tempoBPM: Double = 120,
        noteGateRatio: Double = 0.85,
        transposeSemitones: Int = 0,
        metronomeEnabled: Bool = false,
        metronomeCompoundMode: PaletteMetronomeCompoundMode = .largeBeat,
        metronomeClickSoundStyle: PaletteMetronomeClickSoundStyle = .classic,
        audioEngine: PaletteAudioEngine = SimpleToneAudioEngine()
    ) {
        self.events = events
        self.tempoBPM = Self.clampedTempo(tempoBPM)
        self.noteGateRatio = Self.clampedGateRatio(noteGateRatio)
        self.transposeSemitones = Self.clampedTranspose(transposeSemitones)
        self.metronomeEnabled = metronomeEnabled
        self.metronomeCompoundMode = metronomeCompoundMode
        self.metronomeClickSoundStyle = metronomeClickSoundStyle
        self.audioEngine = audioEngine
    }

    var currentEvent: PlaybackEvent? {
        events[safe: currentEventIndex]
    }

    var currentNoteID: NoteID? {
        currentEvent?.noteIDs.first
    }

    var currentNoteIDs: Set<NoteID> {
        Set(currentEvent?.noteIDs ?? [])
    }

    var currentMidiPitches: [Int] {
        currentEvent.map(transposedMIDIPitches(for:)) ?? []
    }

    var transportState: PalettePlaybackState {
        state
    }

    var effectiveTempoText: String {
        "\(Int(effectiveTempoBPM.rounded())) BPM"
    }

    var effectiveTempoBPM: Double {
        tempoBPM(for: currentEvent)
    }

    func configure(events: [PlaybackEvent]) {
        configure(events: events, metadata: nil)
    }

    func configure(events: [PlaybackEvent], metadata: PlaybackMetadata?) {
        stop()
        self.events = events
        tempoEvents = metadata?.tempoEvents.sorted { $0.onset < $1.onset } ?? []
        timeSignatureEvents = metadata?.timeSignatureEvents ?? []
        usesManualTempoOverride = false
        tempoBPM = initialTempoBPM(for: events)
        currentEventIndex = 0
        notifyCurrentIndex()
    }

    func setTempoBPM(_ tempo: Double) {
        let clampedTempo = Self.clampedTempo(tempo)
        tempoBPM = clampedTempo
        usesManualTempoOverride = true

        guard state == .playing else {
            return
        }

        // Tempo changes during playback intentionally restart scheduling from
        // the current event. This prevents stale sleep tasks and old audio
        // buffers from continuing after the UI selection changes.
        playbackTask?.cancel()
        playbackTask = nil
        audioEngine.silence()
        currentEventStartedAt = Date()
        restartMetronomeIfNeeded(resetBeat: false)
        notifyCurrentIndex()
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop()
        }
    }

    func setNoteGateRatio(_ ratio: Double) {
        noteGateRatio = Self.clampedGateRatio(ratio)
    }

    func setTransposeSemitones(_ semitones: Int) {
        let clamped = Self.clampedTranspose(semitones)
        guard clamped != transposeSemitones else {
            return
        }
        transposeSemitones = clamped

        guard state == .playing, let event = currentEvent else {
            return
        }
        audioEngine.silence()
        triggerAudio(for: event)
    }

    func setMetronomeEnabled(_ enabled: Bool) {
        guard enabled != metronomeEnabled else {
            return
        }
        metronomeEnabled = enabled
        if enabled, state == .playing {
            startMetronome(resetBeat: false, alignToCurrentPlaybackPosition: true)
        } else if !enabled {
            stopMetronome()
        }
    }

    func setMetronomeCompoundMode(_ mode: PaletteMetronomeCompoundMode) {
        guard mode != metronomeCompoundMode else {
            return
        }
        metronomeCompoundMode = mode
        restartMetronomeIfNeeded(resetBeat: false)
    }

    func setMetronomeClickSoundStyle(_ style: PaletteMetronomeClickSoundStyle) {
        metronomeClickSoundStyle = style
    }

    @discardableResult
    func registerTapTempo(at date: Date = Date()) -> Double? {
        if let last = tapTempoDates.last, date.timeIntervalSince(last) > 2.0 {
            tapTempoDates.removeAll()
        }
        tapTempoDates.append(date)
        if tapTempoDates.count > 5 {
            tapTempoDates.removeFirst(tapTempoDates.count - 5)
        }

        guard tapTempoDates.count >= 2 else {
            return nil
        }
        let intervals = zip(tapTempoDates.dropLast(), tapTempoDates.dropFirst())
            .map { $1.timeIntervalSince($0) }
            .filter { $0.isFinite && $0 > 0 }
        guard !intervals.isEmpty else {
            return nil
        }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard averageInterval > 0 else {
            return nil
        }
        let bpm = Self.clampedTempo(60.0 / averageInterval)
        setTempoBPM(bpm)
        return tempoBPM
    }

#if DEBUG
    func triggerMetronomeClickForTesting(isStrongBeat: Bool) {
        triggerMetronomeClick(accent: isStrongBeat ? .strong : .weak)
    }

    func metronomeBeatIsStrongForTesting(beatIndex: Int, eventIndex: Int) -> Bool {
        guard let event = events[safe: eventIndex] else {
            return beatIndex == 0
        }
        return metronomeAccentForTesting(beatIndex: beatIndex, eventIndex: eventIndex) == .strong
    }

    func metronomeAccentForTesting(beatIndex: Int, eventIndex: Int) -> PaletteMetronomeAccent {
        guard let event = events[safe: eventIndex] else {
            return beatIndex == 0 ? .strong : .weak
        }
        return metronomePattern(for: event).accent(at: beatIndex)
    }

    func metronomeIntervalSecondsForTesting(eventIndex: Int) -> TimeInterval {
        guard let event = events[safe: eventIndex] else {
            return metronomeIntervalSeconds()
        }
        return metronomeIntervalSeconds(for: event)
    }

    func metronomeBeatsPerMeasureForTesting(eventIndex: Int) -> Int {
        guard let event = events[safe: eventIndex] else {
            return 4
        }
        return metronomePattern(for: event).accents.count
    }
#endif

    func play() {
        guard !events.isEmpty else {
            state = .stopped
            notifyCurrentIndex()
            return
        }
        if currentEventIndex >= events.count {
            currentEventIndex = 0
        }
        playbackTask?.cancel()
        audioEngine.silence()
        currentEventStartedAt = Date()
        state = .playing
        startMetronome(resetBeat: currentEventIndex == 0, alignToCurrentPlaybackPosition: true)
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop()
        }
    }

    func pause() {
        guard state == .playing else {
            return
        }
        playbackTask?.cancel()
        playbackTask = nil
        stopMetronome()
        audioEngine.silence()
        currentEventStartedAt = nil
        state = .paused
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        stopMetronome(resetBeat: true)
        audioEngine.silence()
        currentEventStartedAt = nil
        state = .stopped
    }

    func reset() {
        stop()
        currentEventIndex = 0
        notifyCurrentIndex()
    }

    func move(by offset: Int) {
        guard !events.isEmpty else {
            currentEventIndex = 0
            notifyCurrentIndex()
            return
        }
        currentEventIndex = min(max(currentEventIndex + offset, 0), events.count - 1)
        notifyCurrentIndex()
        if state == .playing, let event = currentEvent {
            currentEventStartedAt = Date()
            restartMetronomeIfNeeded(resetBeat: false)
            triggerAudio(for: event)
        }
    }

    func move(to index: Int) {
        guard !events.isEmpty else {
            currentEventIndex = 0
            notifyCurrentIndex()
            return
        }
        currentEventIndex = min(max(index, 0), events.count - 1)
        notifyCurrentIndex()
        if state == .playing, let event = currentEvent {
            currentEventStartedAt = Date()
            restartMetronomeIfNeeded(resetBeat: false)
            triggerAudio(for: event)
        }
    }

    func advanceToNextEvent() {
        guard !events.isEmpty else {
            state = .stopped
            currentEventIndex = 0
            notifyCurrentIndex()
            return
        }
        guard currentEventIndex < events.count - 1 else {
            playbackTask?.cancel()
            playbackTask = nil
            stopMetronome(resetBeat: true)
            audioEngine.silence()
            state = .stopped
            notifyCurrentIndex()
            return
        }
        move(by: 1)
    }

    func select(noteID: NoteID) {
        guard let index = events.firstIndex(where: { $0.noteIDs.contains(noteID) }) else {
            return
        }
        currentEventIndex = index
        notifyCurrentIndex()
        if state == .playing, let event = currentEvent {
            currentEventStartedAt = Date()
            restartMetronomeIfNeeded(resetBeat: false)
            triggerAudio(for: event)
        }
    }

    func eventDurationSeconds(for event: PlaybackEvent) -> TimeInterval {
        let quarters = Double(event.nominalDuration.ticks) / Double(event.nominalDuration.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
            return 0.05
        }
        return min(max(0.05, seconds), 8)
    }

    func soundDurationSeconds(for event: PlaybackEvent) -> TimeInterval {
        soundDurationSeconds(for: event.nominalDuration, in: event)
    }

    func soundDurationSeconds(for midiPitch: Int, in event: PlaybackEvent) -> TimeInterval {
        soundDurationSeconds(for: event.midiPitchDurations[midiPitch] ?? event.nominalDuration, in: event)
    }

    private func soundDurationSeconds(for duration: MusicalTime, in event: PlaybackEvent) -> TimeInterval {
        let eventDuration = eventDurationSeconds(for: event)
        let pitchDuration = durationSeconds(for: duration, event: event)
        let extendsBeyondEvent = duration > event.nominalDuration
        let soundWindow = extendsBeyondEvent ? pitchDuration : min(eventDuration, pitchDuration)
        let gatedDuration = extendsBeyondEvent ? soundWindow : soundWindow * noteGateRatio
        guard eventDuration.isFinite,
              pitchDuration.isFinite,
              soundWindow.isFinite,
              gatedDuration.isFinite,
              eventDuration > 0,
              pitchDuration > 0,
              soundWindow > 0,
              gatedDuration > 0
        else {
            return 0
        }
        let minimumDuration = min(soundWindow, Self.minimumAudibleDuration)
        return min(soundWindow, max(minimumDuration, gatedDuration))
    }

    func schedulingIntervalSeconds(from index: Int) -> TimeInterval {
        guard let event = events[safe: index] else {
            return 0.05
        }
        guard let nextEvent = events[safe: index + 1],
              nextEvent.measureID == event.measureID
        else {
            return remainingMeasureDurationSeconds(from: event)
                ?? eventDurationSeconds(for: event)
        }

        guard event.onset < nextEvent.onset else {
            return 0.01
        }

        let delta = nextEvent.onset - event.onset
        guard let seconds = durationSecondsForScheduling(delta, event: event) else {
            return eventDurationSeconds(for: event)
        }
        return min(max(0.01, seconds), 8)
    }

    func triggerAudioForCurrentEvent() {
        guard let event = currentEvent else {
            audioEngine.silence()
            return
        }
        triggerAudio(for: event)
    }

    func transposedMIDIPitches(for event: PlaybackEvent) -> [Int] {
        event.midiPitches.compactMap { Self.transposedMIDIPitch($0, by: transposeSemitones) }
    }

    private func runPlaybackLoop() async {
        while !Task.isCancelled, state == .playing, currentEventIndex < events.count {
            let event = events[currentEventIndex]
            currentEventStartedAt = Date()
            notifyCurrentIndex()
            let duration = schedulingIntervalSeconds(from: currentEventIndex)
            triggerAudio(for: event)

            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled, state == .playing else {
                return
            }
            if currentEventIndex < events.count - 1 {
                currentEventIndex += 1
            } else {
                stopMetronome(resetBeat: true)
                audioEngine.silence()
                currentEventStartedAt = nil
                state = .stopped
                notifyCurrentIndex()
                return
            }
        }
    }

    private func triggerAudio(for event: PlaybackEvent) {
        guard !event.midiPitches.isEmpty else {
            return
        }
        do {
            try audioEngine.start()
            let playablePitches = event.midiPitches.compactMap { midiPitch -> (pitch: Int, duration: TimeInterval)? in
                guard let transposedPitch = Self.transposedMIDIPitch(midiPitch, by: transposeSemitones) else {
                    return nil
                }
                return (transposedPitch, soundDurationSeconds(for: midiPitch, in: event))
            }
            let groupedPitches = Dictionary(grouping: playablePitches) { item in
                item.duration
            }
            for (duration, pitches) in groupedPitches where duration > 0 {
                audioEngine.play(midiPitches: pitches.map(\.pitch), duration: duration, velocity: 0.8)
            }
        } catch {
            onAudioError?(error)
        }
    }

    private func restartMetronomeIfNeeded(resetBeat: Bool) {
        guard state == .playing, metronomeEnabled else {
            return
        }
        startMetronome(resetBeat: resetBeat, alignToCurrentPlaybackPosition: true)
    }

    private func startMetronome(resetBeat: Bool, alignToCurrentPlaybackPosition: Bool = false) {
        guard metronomeEnabled, state == .playing else {
            return
        }
        metronomeTask?.cancel()
        let plan = alignToCurrentPlaybackPosition
            ? metronomeStartPlan(resetBeat: resetBeat)
            : MetronomeStartPlan(initialDelay: 0, beatIndex: resetBeat ? 0 : metronomeBeatIndex)
        metronomeBeatIndex = plan.beatIndex
        metronomeTask = Task { [weak self] in
            await self?.runMetronomeLoop(initialDelay: plan.initialDelay)
        }
    }

    private func stopMetronome(resetBeat: Bool = false) {
        metronomeTask?.cancel()
        metronomeTask = nil
        if resetBeat {
            metronomeBeatIndex = 0
        }
    }

    private func runMetronomeLoop(initialDelay: TimeInterval = 0) async {
        if initialDelay > 0 {
            do {
                try await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            } catch {
                return
            }
        }
        while !Task.isCancelled, state == .playing, metronomeEnabled {
            triggerMetronomeClick(accent: metronomeAccent(metronomeBeatIndex))
            metronomeBeatIndex += 1
            let interval = metronomeIntervalSeconds()
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }
        }
    }

    private func triggerMetronomeClick(accent: PaletteMetronomeAccent) {
        do {
            try audioEngine.start()
            let click = metronomeClickParameters(accent: accent)
            audioEngine.play(
                midiPitches: [click.midiPitch],
                duration: click.duration,
                velocity: click.velocity
            )
        } catch {
            onAudioError?(error)
        }
    }

    private func metronomeIntervalSeconds() -> TimeInterval {
        let event = currentEvent
        let tempo = tempoBPM(for: event)
        guard tempo.isFinite, tempo > 0 else {
            return 0.5
        }
        let beatSeconds = event.map(metronomeIntervalSeconds(for:)) ?? (60.0 / tempo)
        return min(max(beatSeconds, 0.125), 2.0)
    }

    private func metronomeIntervalSeconds(for event: PlaybackEvent) -> TimeInterval {
        let tempo = tempoBPM(for: event)
        guard tempo.isFinite, tempo > 0 else {
            return 0.5
        }
        let pattern = metronomePattern(for: event)
        let quarters = Double(pattern.ticksPerBeat) / Double(event.onset.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempo
        guard seconds.isFinite, seconds > 0 else {
            return 0.5
        }
        return seconds
    }

    private func metronomeAccent(_ beatIndex: Int) -> PaletteMetronomeAccent {
        guard let event = currentEvent else {
            return beatIndex == 0 ? .strong : .weak
        }
        return metronomePattern(for: event).accent(at: beatIndex)
    }

    private struct MetronomeStartPlan {
        let initialDelay: TimeInterval
        let beatIndex: Int
    }

    private func metronomeStartPlan(resetBeat: Bool) -> MetronomeStartPlan {
        guard let event = currentEvent else {
            return MetronomeStartPlan(initialDelay: 0, beatIndex: resetBeat ? 0 : metronomeBeatIndex)
        }

        let pattern = metronomePattern(for: event)
        let ticksPerBeat = pattern.ticksPerBeat
        guard ticksPerBeat > 0 else {
            return MetronomeStartPlan(initialDelay: 0, beatIndex: resetBeat ? 0 : metronomeBeatIndex)
        }

        let measureStart = events
            .filter { $0.measureID == event.measureID }
            .map(\.onset)
            .min() ?? event.onset
        let onsetInMeasure = event.onset - measureStart
        let elapsedTicks = elapsedTicksInCurrentEvent(for: event)
        let totalTicks = max(0, Double(onsetInMeasure.ticks) + elapsedTicks)
        let ticksIntoBeat = totalTicks.truncatingRemainder(dividingBy: Double(ticksPerBeat))
        let beatsPerMeasure = pattern.accents.count
        let currentBeatIndex = Int(totalTicks / Double(ticksPerBeat)) % beatsPerMeasure

        guard ticksIntoBeat > 0.0001 else {
            return MetronomeStartPlan(initialDelay: 0, beatIndex: currentBeatIndex)
        }

        let ticksUntilNextBeat = Double(ticksPerBeat) - ticksIntoBeat
        let secondsUntilNextBeat = durationSecondsForTicks(
            ticksUntilNextBeat,
            ticksPerQuarterNote: event.onset.ticksPerQuarterNote,
            event: event
        )
            ?? metronomeIntervalSeconds()
        let nextBeatIndex = (currentBeatIndex + 1) % beatsPerMeasure
        return MetronomeStartPlan(
            initialDelay: min(max(secondsUntilNextBeat, 0.01), metronomeIntervalSeconds()),
            beatIndex: nextBeatIndex
        )
    }

    private func metronomeBeatsPerMeasure(for event: PlaybackEvent) -> Int {
        metronomePattern(for: event).accents.count
    }

    private func ticksPerMetronomeBeat(for event: PlaybackEvent, timeSignature: TimeSignature) -> Int {
        metronomePattern(for: event, timeSignature: timeSignature).ticksPerBeat
    }

    private struct MetronomeBeatPattern {
        let accents: [PaletteMetronomeAccent]
        let ticksPerBeat: Int

        func accent(at beatIndex: Int) -> PaletteMetronomeAccent {
            guard !accents.isEmpty else {
                return beatIndex == 0 ? .strong : .weak
            }
            return accents[beatIndex % accents.count]
        }
    }

    private func metronomePattern(for event: PlaybackEvent) -> MetronomeBeatPattern {
        metronomePattern(for: event, timeSignature: timeSignature(for: event))
    }

    private func metronomePattern(for event: PlaybackEvent, timeSignature: TimeSignature) -> MetronomeBeatPattern {
        let beats = max(1, timeSignature.beats)
        let beatType = max(1, timeSignature.beatType)
        let baseTicks = max(1, event.onset.ticksPerQuarterNote * 4 / beatType)

        if beatType == 8, [6, 9, 12].contains(beats) {
            switch metronomeCompoundMode {
            case .largeBeat:
                let largeBeatCount = max(1, beats / 3)
                return MetronomeBeatPattern(
                    accents: largeBeatAccents(count: largeBeatCount),
                    ticksPerBeat: baseTicks * 3
                )
            case .subdivision:
                return MetronomeBeatPattern(
                    accents: compoundSubdivisionAccents(beats: beats),
                    ticksPerBeat: baseTicks
                )
            }
        }

        return MetronomeBeatPattern(
            accents: simpleAccents(beats: beats),
            ticksPerBeat: baseTicks
        )
    }

    private func simpleAccents(beats: Int) -> [PaletteMetronomeAccent] {
        guard beats > 1 else {
            return [.strong]
        }
        return [.strong] + Array(repeating: .weak, count: beats - 1)
    }

    private func largeBeatAccents(count: Int) -> [PaletteMetronomeAccent] {
        switch count {
        case 1:
            return [.strong]
        case 2:
            return [.strong, .weak]
        case 3:
            return [.strong, .weak, .weak]
        case 4:
            return [.strong, .weak, .medium, .weak]
        default:
            return simpleAccents(beats: count)
        }
    }

    private func compoundSubdivisionAccents(beats: Int) -> [PaletteMetronomeAccent] {
        (0..<beats).map { index in
            if index == 0 {
                return .strong
            }
            if index % 3 == 0 {
                return .medium
            }
            return .weak
        }
    }

    private struct MetronomeClickParameters {
        let midiPitch: Int
        let duration: TimeInterval
        let velocity: Double
    }

    private func metronomeClickParameters(accent: PaletteMetronomeAccent) -> MetronomeClickParameters {
        switch (metronomeClickSoundStyle, accent) {
        case (.classic, .strong):
            return MetronomeClickParameters(midiPitch: 96, duration: 0.040, velocity: 0.72)
        case (.classic, .medium):
            return MetronomeClickParameters(midiPitch: 90, duration: 0.036, velocity: 0.58)
        case (.classic, .weak):
            return MetronomeClickParameters(midiPitch: 84, duration: 0.035, velocity: 0.46)

        case (.soft, .strong):
            return MetronomeClickParameters(midiPitch: 88, duration: 0.030, velocity: 0.48)
        case (.soft, .medium):
            return MetronomeClickParameters(midiPitch: 84, duration: 0.028, velocity: 0.38)
        case (.soft, .weak):
            return MetronomeClickParameters(midiPitch: 79, duration: 0.026, velocity: 0.30)

        case (.wood, .strong):
            return MetronomeClickParameters(midiPitch: 76, duration: 0.030, velocity: 0.66)
        case (.wood, .medium):
            return MetronomeClickParameters(midiPitch: 72, duration: 0.028, velocity: 0.52)
        case (.wood, .weak):
            return MetronomeClickParameters(midiPitch: 67, duration: 0.026, velocity: 0.42)

        case (.electronic, .strong):
            return MetronomeClickParameters(midiPitch: 108, duration: 0.035, velocity: 0.70)
        case (.electronic, .medium):
            return MetronomeClickParameters(midiPitch: 102, duration: 0.030, velocity: 0.56)
        case (.electronic, .weak):
            return MetronomeClickParameters(midiPitch: 96, duration: 0.026, velocity: 0.44)
        }
    }

    private func timeSignature(for event: PlaybackEvent) -> TimeSignature {
        timeSignatureEvents
            .last { $0.measureID == event.measureID }
            .map(\.timeSignature)
            ?? TimeSignature(beats: 4, beatType: 4)
    }

    private func elapsedTicksInCurrentEvent(for event: PlaybackEvent) -> Double {
        guard let currentEventStartedAt else {
            return 0
        }
        let elapsedSeconds = Date().timeIntervalSince(currentEventStartedAt)
        guard elapsedSeconds.isFinite, elapsedSeconds > 0 else {
            return 0
        }
        let quarters = elapsedSeconds * tempoBPM(for: event) / 60.0
        guard quarters.isFinite, quarters > 0 else {
            return 0
        }
        let ticks = quarters * Double(event.onset.ticksPerQuarterNote)
        return min(max(ticks, 0), max(0, Double(event.nominalDuration.ticks) - 0.0001))
    }

    private func durationSeconds(for duration: MusicalTime, event: PlaybackEvent) -> TimeInterval {
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
            return 0
        }
        return min(max(0.01, seconds), 8)
    }

    private func remainingMeasureDurationSeconds(from event: PlaybackEvent) -> TimeInterval? {
        let measureEnd = events
            .filter { $0.measureID == event.measureID }
            .map { $0.onset + $0.nominalDuration }
            .max()
        guard let measureEnd, event.onset < measureEnd else {
            return nil
        }
        let remaining = measureEnd - event.onset
        guard let seconds = durationSecondsForScheduling(remaining, event: event) else {
            return nil
        }
        return min(max(0.01, seconds), 8)
    }

    private func durationSecondsForScheduling(_ duration: MusicalTime, event: PlaybackEvent) -> TimeInterval? {
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }
        return seconds
    }

    private func durationSecondsForTicks(
        _ ticks: Double,
        ticksPerQuarterNote: Int,
        event: PlaybackEvent
    ) -> TimeInterval? {
        let quarters = ticks / Double(ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }
        return seconds
    }

    private func notifyCurrentIndex() {
        onEventIndexChange?(currentEventIndex)
    }

    private func initialTempoBPM(for events: [PlaybackEvent]) -> Double {
        guard let firstEvent = events.first else {
            return Self.defaultTempoBPM
        }
        return tempoEvents
            .last { $0.onset <= firstEvent.onset }
            .map(\.bpm)
            .map(Self.clampedTempo)
            ?? Self.defaultTempoBPM
    }

    private func tempoBPM(for event: PlaybackEvent?) -> Double {
        if usesManualTempoOverride {
            return tempoBPM
        }
        guard let event else {
            return tempoBPM
        }
        return tempoEvents
            .last { $0.onset <= event.onset }
            .map(\.bpm)
            .map(Self.clampedTempo)
            ?? tempoBPM
    }

    private static func clampedTempo(_ tempo: Double) -> Double {
        guard tempo.isFinite else {
            return 120
        }
        return min(max(tempo, 30), 240)
    }

    private static func clampedGateRatio(_ ratio: Double) -> Double {
        guard ratio.isFinite else {
            return 0.85
        }
        return min(max(ratio, 0.50), 1.00)
    }

    static func clampedTranspose(_ semitones: Int) -> Int {
        min(max(semitones, transposeRange.lowerBound), transposeRange.upperBound)
    }

    static func transposedMIDIPitch(_ midiPitch: Int, by semitones: Int) -> Int? {
        let transposedPitch = midiPitch + clampedTranspose(semitones)
        guard (0...127).contains(transposedPitch) else {
            return nil
        }
        return transposedPitch
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
