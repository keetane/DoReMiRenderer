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

#if DEBUG
struct PaletteMetronomeClickPlanEntry: Equatable {
    let playbackTime: TimeInterval
    let eventIndex: Int
    let measureID: MeasureID
    let beatIndexInMeasure: Int
    let accent: PaletteMetronomeAccent
    let timeSignature: TimeSignature
}
#endif

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
    private(set) var humanizeEnabled: Bool

    private let audioEngine: PaletteAudioEngine
    private var playbackTask: Task<Void, Never>?
    private var metronomeTask: Task<Void, Never>?
    private var measureOrderByID: [MeasureID: Int] = [:]
    private var orderedTempoEvents: [OrderedTempoEvent] = []
    private var globalTempoEvents: [TempoEvent] = []
    private var timeSignatureByMeasureID: [MeasureID: TimeSignature] = [:]
    private var playbackScheduleStartMonotonic: TimeInterval?
    private var currentEventStartedAtMonotonic: TimeInterval?
    private var metronomePlanStartMonotonic: TimeInterval?
    private var metronomeClickPlan: [MetronomeScheduledClick] = []
    private var metronomeClickCursor = 0
    private var metronomeBeatIndex = 0
    private var currentEventStartedAt: Date?
    private var tapTempoDates: [Date] = []
    private var usesManualTempoOverride = false
#if DEBUG
    private var playbackTimingSamples: [PlaybackTimingSample] = []
#endif
    private static let defaultTempoBPM: Double = 120
    private static let minimumAudibleDuration: TimeInterval = 0.06
    private static let audioPrewarmEventLimit = 512
    static let transposeRange = -12...12

#if DEBUG
    private struct PlaybackTimingSample {
        let eventIndex: Int
        let expectedElapsed: TimeInterval
        let actualElapsed: TimeInterval
        let jitterMilliseconds: Double
        let eventInterval: TimeInterval
        let midiPitchCount: Int
    }
#endif

    private struct OrderedTempoEvent {
        let measureOrder: Int
        let onset: MusicalTime
        let bpm: Double
    }

    private struct MetronomeScheduledClick {
        let playbackTime: TimeInterval
        let eventIndex: Int
        let measureID: MeasureID
        let beatIndexInMeasure: Int
        let accent: PaletteMetronomeAccent
        let timeSignature: TimeSignature
    }

    init(
        events: [PlaybackEvent] = [],
        tempoBPM: Double = 120,
        noteGateRatio: Double = 1.0,
        transposeSemitones: Int = 0,
        metronomeEnabled: Bool = false,
        metronomeCompoundMode: PaletteMetronomeCompoundMode = .largeBeat,
        metronomeClickSoundStyle: PaletteMetronomeClickSoundStyle = .classic,
        humanizeEnabled: Bool = false,
        audioEngine: PaletteAudioEngine = SimpleToneAudioEngine()
    ) {
        self.events = events
        self.tempoBPM = Self.clampedTempo(tempoBPM)
        self.noteGateRatio = Self.clampedGateRatio(noteGateRatio)
        self.transposeSemitones = Self.clampedTranspose(transposeSemitones)
        self.metronomeEnabled = metronomeEnabled
        self.metronomeCompoundMode = metronomeCompoundMode
        self.metronomeClickSoundStyle = metronomeClickSoundStyle
        self.humanizeEnabled = humanizeEnabled
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
        measureOrderByID = Self.measureOrderByID(for: events)
        tempoEvents = metadata?.tempoEvents ?? []
        timeSignatureEvents = metadata?.timeSignatureEvents ?? []
        orderedTempoEvents = Self.orderedTempoEvents(from: tempoEvents, measureOrderByID: measureOrderByID)
        globalTempoEvents = tempoEvents
            .filter { $0.measureID == nil }
            .sorted { lhs, rhs in lhs.onset < rhs.onset }
        timeSignatureByMeasureID = Self.timeSignatureByMeasureID(
            from: timeSignatureEvents,
            measureOrderByID: measureOrderByID
        )
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
        prewarmAudioForUpcomingEvents(startingAt: currentEventIndex)
        let scheduleStart = Self.monotonicTime()
        playbackScheduleStartMonotonic = scheduleStart
        currentEventStartedAtMonotonic = scheduleStart
        currentEventStartedAt = Date()
        restartMetronomeIfNeeded(resetBeat: false)
        notifyCurrentIndex()
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop(scheduleStart: scheduleStart)
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
        guard events[safe: eventIndex] != nil else {
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
        playbackScheduleStartMonotonic = nil
#if DEBUG
        playbackTimingSamples.removeAll()
#endif
        prewarmAudioForUpcomingEvents(startingAt: currentEventIndex)
        let scheduleStart = Self.monotonicTime()
        playbackScheduleStartMonotonic = scheduleStart
        currentEventStartedAtMonotonic = scheduleStart
        currentEventStartedAt = Date()
        state = .playing
        startMetronome(resetBeat: currentEventIndex == 0, alignToCurrentPlaybackPosition: true)
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop(scheduleStart: scheduleStart)
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
        playbackScheduleStartMonotonic = nil
        currentEventStartedAtMonotonic = nil
        state = .paused
#if DEBUG
        flushPlaybackTimingReportIfNeeded(reason: "pause")
#endif
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        stopMetronome(resetBeat: true)
        audioEngine.silence()
        currentEventStartedAt = nil
        playbackScheduleStartMonotonic = nil
        currentEventStartedAtMonotonic = nil
        state = .stopped
#if DEBUG
        flushPlaybackTimingReportIfNeeded(reason: "stop")
#endif
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
            let now = Self.monotonicTime()
            currentEventStartedAt = Date()
            currentEventStartedAtMonotonic = now
            playbackScheduleStartMonotonic = now
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
            let now = Self.monotonicTime()
            currentEventStartedAt = Date()
            currentEventStartedAtMonotonic = now
            playbackScheduleStartMonotonic = now
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
            let now = Self.monotonicTime()
            currentEventStartedAt = Date()
            currentEventStartedAtMonotonic = now
            playbackScheduleStartMonotonic = now
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
        return expressionExtendedDuration(min(max(0.05, seconds), 8), for: event)
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
        let baseSoundWindow = extendsBeyondEvent ? pitchDuration : min(eventDuration, pitchDuration)
        let soundWindow = extendsBeyondEvent ? baseSoundWindow : expressionExtendedDuration(baseSoundWindow, for: event)
        let expressionGate = event.expression.gateScale
        let gatedDuration = extendsBeyondEvent ? soundWindow : soundWindow * noteGateRatio * expressionGate
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
        let maximumDuration: TimeInterval
        if !extendsBeyondEvent, expressionGate > 1 {
            maximumDuration = min(max(soundWindow, gatedDuration), soundWindow + 0.08)
        } else {
            maximumDuration = soundWindow
        }
        return min(maximumDuration, max(minimumDuration, gatedDuration))
    }

    private func expressionExtendedDuration(_ duration: TimeInterval, for event: PlaybackEvent) -> TimeInterval {
        let scale = event.expression.durationScale
        guard scale > 1, duration.isFinite, duration > 0 else {
            return duration
        }
        let extra = min(duration * (scale - 1), event.expression.maxDurationExtraSeconds)
        return min(max(duration, duration + extra), 9)
    }

    func schedulingIntervalSeconds(from index: Int) -> TimeInterval {
        guard let event = events[safe: index] else {
            return 0.05
        }
        guard let nextEvent = events[safe: index + 1],
              nextEvent.measureID == event.measureID
        else {
            let seconds = remainingMeasureDurationSeconds(from: event)
                ?? eventDurationSeconds(for: event)
            return min(max(0.01, expressionExtendedDuration(seconds, for: event)), 8)
        }

        guard event.onset < nextEvent.onset else {
            return 0.01
        }

        let delta = nextEvent.onset - event.onset
        guard let seconds = durationSecondsForScheduling(delta, event: event) else {
            return eventDurationSeconds(for: event)
        }
        return min(max(0.01, expressionExtendedDuration(seconds, for: event)), 8)
    }

    func totalSchedulingDurationSeconds() -> TimeInterval {
        guard !events.isEmpty else {
            return 0
        }
        return events.indices.reduce(0) { partial, index in
            partial + schedulingIntervalSeconds(from: index)
        }
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

    private func runPlaybackLoop(scheduleStart: TimeInterval) async {
        var scheduledElapsed: TimeInterval = 0

        while !Task.isCancelled, state == .playing, currentEventIndex < events.count {
            let event = events[currentEventIndex]
            let expectedElapsed = scheduledElapsed
            let actualElapsed = max(0, Self.monotonicTime() - scheduleStart)
            let eventStartedAt = Date()
            currentEventStartedAt = eventStartedAt
            currentEventStartedAtMonotonic = scheduleStart + expectedElapsed
            let duration = schedulingIntervalSeconds(from: currentEventIndex)
#if DEBUG
            recordPlaybackTiming(
                eventIndex: currentEventIndex,
                expectedElapsed: expectedElapsed,
                actualElapsed: actualElapsed,
                eventInterval: duration,
                midiPitchCount: event.midiPitches.count
            )
#endif
            triggerAudio(for: event)
            notifyCurrentIndex()
            scheduledElapsed += duration

            do {
                let sleepDuration = Self.absoluteSleepDuration(
                    scheduleStart: scheduleStart,
                    scheduledElapsed: scheduledElapsed,
                    now: Self.monotonicTime()
                )
                if sleepDuration > 0 {
                    try await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))
                }
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
                playbackScheduleStartMonotonic = nil
                currentEventStartedAtMonotonic = nil
                state = .stopped
                notifyCurrentIndex()
#if DEBUG
                flushPlaybackTimingReportIfNeeded(reason: "end")
#endif
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
                audioEngine.play(midiPitches: pitches.map(\.pitch), duration: duration, velocity: playbackVelocity(for: event))
            }
        } catch {
            onAudioError?(error)
        }
    }

    private func prewarmAudioForUpcomingEvents(startingAt startIndex: Int) {
        guard events.indices.contains(startIndex) else {
            return
        }
        do {
            try audioEngine.start()
        } catch {
            onAudioError?(error)
            return
        }
        let endIndex = min(events.count, startIndex + Self.audioPrewarmEventLimit)
        for event in events[startIndex..<endIndex] where !event.midiPitches.isEmpty {
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
                audioEngine.prepare(
                    midiPitches: pitches.map(\.pitch),
                    duration: duration,
                    velocity: playbackVelocity(for: event)
                )
            }
        }
    }

    private func playbackVelocity(for event: PlaybackEvent) -> Double {
        min(1.0, max(0.08, 0.8 * event.expression.velocityScale))
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
        metronomePlanStartMonotonic = currentEventStartedAtMonotonic
            ?? playbackScheduleStartMonotonic
            ?? Self.monotonicTime()
        rebuildMetronomeClickPlan()
        let elapsed = currentMetronomePlanElapsed()
        metronomeClickCursor = nextMetronomeClickIndex(
            after: elapsed,
            allowImmediate: resetBeat && elapsed < 0.02
        )
        metronomeBeatIndex = metronomeClickPlan[safe: metronomeClickCursor]?.beatIndexInMeasure ?? 0
        metronomeTask = Task { [weak self] in
            await self?.runMetronomeLoop()
        }
    }

    private func stopMetronome(resetBeat: Bool = false) {
        metronomeTask?.cancel()
        metronomeTask = nil
        metronomePlanStartMonotonic = nil
        if resetBeat {
            metronomeBeatIndex = 0
            metronomeClickCursor = 0
        }
    }

    private func runMetronomeLoop() async {
        while !Task.isCancelled, state == .playing, metronomeEnabled {
            guard let click = metronomeClickPlan[safe: metronomeClickCursor] else {
                return
            }
            let delay = click.playbackTime - currentMetronomePlanElapsed()
            do {
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                return
            }
            guard !Task.isCancelled, state == .playing, metronomeEnabled else {
                return
            }
            metronomeBeatIndex = click.beatIndexInMeasure
            recordMetronomeClickIfNeeded(click)
            triggerMetronomeClick(accent: click.accent)
            metronomeClickCursor += 1
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

    private func recordMetronomeClickIfNeeded(_ click: MetronomeScheduledClick) {
#if DEBUG
        let line = [
            "DPM_METRONOME",
            "playbackTime=\(String(format: "%.6f", click.playbackTime))",
            "eventIndex=\(click.eventIndex)",
            "measureID=\(click.measureID.rawValue)",
            "beatIndex=\(click.beatIndexInMeasure)",
            "accent=\(click.accent)",
            "timeSignature=\(click.timeSignature.beats)/\(click.timeSignature.beatType)",
            "tempoBPM=\(String(format: "%.3f", tempoBPM(for: events[safe: click.eventIndex])))",
        ].joined(separator: " ")
        if ProcessInfo.processInfo.environment["DOREMI_METRONOME_CLICK_LOG"] == "1" {
            print(line)
        }
        guard let path = ProcessInfo.processInfo.environment["DOREMI_METRONOME_CLICK_LOG_PATH"],
              !path.isEmpty
        else {
            return
        }
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let output = existing.isEmpty ? line : existing + "\n" + line
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("DPM_METRONOME_LOG_WRITE_FAILED \(error.localizedDescription)")
        }
#endif
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

    private func rebuildMetronomeClickPlan() {
        metronomeClickPlan = buildMetronomeClickPlan(startingAt: currentEventIndex)
    }

    private func currentMetronomePlanElapsed() -> TimeInterval {
        guard let metronomePlanStartMonotonic else {
            return 0
        }
        return max(0, Self.monotonicTime() - metronomePlanStartMonotonic)
    }

    private func nextMetronomeClickIndex(after elapsed: TimeInterval, allowImmediate: Bool) -> Int {
        let tolerance = allowImmediate ? 0.002 : -0.002
        return metronomeClickPlan.firstIndex { click in
            if allowImmediate {
                return click.playbackTime >= elapsed - tolerance
            }
            return click.playbackTime > elapsed + 0.002
        } ?? metronomeClickPlan.count
    }

    private func buildMetronomeClickPlan(startingAt requestedStartIndex: Int) -> [MetronomeScheduledClick] {
        guard !events.isEmpty else {
            return []
        }
        let startIndex = min(max(requestedStartIndex, 0), events.count - 1)
        let firstOccurrenceStart = contiguousMeasureStart(containing: startIndex)
        var eventStartTimes: [Int: TimeInterval] = [:]
        var elapsed: TimeInterval = 0
        for index in startIndex..<events.count {
            eventStartTimes[index] = elapsed
            elapsed += schedulingIntervalSeconds(from: index)
        }

        var clicks: [MetronomeScheduledClick] = []
        var occurrenceStart = firstOccurrenceStart
        while occurrenceStart < events.count {
            let measureID = events[occurrenceStart].measureID
            var occurrenceEnd = occurrenceStart + 1
            while occurrenceEnd < events.count, events[occurrenceEnd].measureID == measureID {
                occurrenceEnd += 1
            }
            appendMetronomeClicks(
                occurrenceStart: occurrenceStart,
                occurrenceEnd: occurrenceEnd,
                planStartIndex: startIndex,
                eventStartTimes: eventStartTimes,
                to: &clicks
            )
            occurrenceStart = occurrenceEnd
        }
        return clicks.sorted { lhs, rhs in
            if lhs.playbackTime != rhs.playbackTime {
                return lhs.playbackTime < rhs.playbackTime
            }
            return lhs.beatIndexInMeasure < rhs.beatIndexInMeasure
        }
    }

    private func appendMetronomeClicks(
        occurrenceStart: Int,
        occurrenceEnd: Int,
        planStartIndex: Int,
        eventStartTimes: [Int: TimeInterval],
        to clicks: inout [MetronomeScheduledClick]
    ) {
        guard occurrenceStart < occurrenceEnd else {
            return
        }
        let occurrenceEvents = events[occurrenceStart..<occurrenceEnd]
        let firstEvent = events[occurrenceStart]
        let referenceIndex = max(occurrenceStart, planStartIndex)
        guard referenceIndex < occurrenceEnd,
              let referencePlaybackStart = eventStartTimes[referenceIndex]
        else {
            return
        }
        let referenceEvent = events[referenceIndex]
        let timeSignature = timeSignature(for: firstEvent)
        let pattern = metronomePattern(for: firstEvent, timeSignature: timeSignature)
        guard pattern.ticksPerBeat > 0 else {
            return
        }
        let measureStart = occurrenceEvents.map(\.onset).min() ?? firstEvent.onset
        let measureEnd = occurrenceEvents
            .map { $0.onset + $0.nominalDuration }
            .max() ?? measureStart
        let beatQuarters = Double(pattern.ticksPerBeat) / Double(firstEvent.onset.ticksPerQuarterNote)
        let startQuarters = musicalQuarters(measureStart)
        let endQuarters = musicalQuarters(measureEnd)
        let referenceQuarters = musicalQuarters(referenceEvent.onset)
        let occurrencePlaybackStart = referencePlaybackStart
            - secondsForQuarters(max(0, referenceQuarters - startQuarters), event: referenceEvent)
        guard beatQuarters.isFinite,
              beatQuarters > 0,
              endQuarters > startQuarters
        else {
            return
        }

        let firstBeatNumber = Int(ceil((startQuarters / beatQuarters) - 0.000_001))
        let lastBeatNumber = Int(floor(((endQuarters - 0.000_001) / beatQuarters)))
        guard lastBeatNumber >= firstBeatNumber else {
            return
        }

        for beatNumber in firstBeatNumber...lastBeatNumber {
            let beatStartQuarters = Double(beatNumber) * beatQuarters
            let relativeQuarters = beatStartQuarters - startQuarters
            guard relativeQuarters >= -0.000_001 else {
                continue
            }
            let beatPlaybackTime = occurrencePlaybackStart
                + secondsForQuarters(relativeQuarters, event: firstEvent)
            guard beatPlaybackTime >= -0.002 else {
                continue
            }
            let beatIndexInMeasure = positiveModulo(beatNumber, pattern.accents.count)
            clicks.append(MetronomeScheduledClick(
                playbackTime: max(0, beatPlaybackTime),
                eventIndex: occurrenceStart,
                measureID: firstEvent.measureID,
                beatIndexInMeasure: beatIndexInMeasure,
                accent: pattern.accent(at: beatIndexInMeasure),
                timeSignature: timeSignature
            ))
        }
    }

    private func contiguousMeasureStart(containing index: Int) -> Int {
        guard events.indices.contains(index) else {
            return index
        }
        let measureID = events[index].measureID
        var start = index
        while start > 0, events[start - 1].measureID == measureID {
            start -= 1
        }
        return start
    }

    private func metronomeBeatsPerMeasure(for event: PlaybackEvent) -> Int {
        metronomePattern(for: event).accents.count
    }

    private func musicalQuarters(_ time: MusicalTime) -> Double {
        Double(time.ticks) / Double(time.ticksPerQuarterNote)
    }

    private func secondsForQuarters(_ quarters: Double, event: PlaybackEvent) -> TimeInterval {
        let tempo = tempoBPM(for: event)
        guard quarters.isFinite, tempo.isFinite, tempo > 0 else {
            return 0
        }
        return quarters * 60.0 / tempo
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else {
            return 0
        }
        let result = value % divisor
        return result >= 0 ? result : result + divisor
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
        timeSignatureByMeasureID[event.measureID] ?? TimeSignature(beats: 4, beatType: 4)
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
        return metadataTempoBPM(for: firstEvent) ?? Self.defaultTempoBPM
    }

    private func tempoBPM(for event: PlaybackEvent?) -> Double {
        if usesManualTempoOverride {
            return tempoBPM
        }
        guard let event else {
            return tempoBPM
        }
        return metadataTempoBPM(for: event) ?? tempoBPM
    }

    private func metadataTempoBPM(for event: PlaybackEvent) -> Double? {
        var candidateBPM: Double?
        if let eventMeasureOrder = measureOrderByID[event.measureID],
           let tempoEvent = orderedTempoEvent(atOrBeforeMeasureOrder: eventMeasureOrder, onset: event.onset) {
            candidateBPM = tempoEvent.bpm
        }
        if let globalTempoEvent = globalTempoEvent(atOrBefore: event.onset) {
            candidateBPM = globalTempoEvent.bpm
        }
        return candidateBPM.map(Self.clampedTempo)
    }

    private func tempoEventApplies(_ tempoEvent: TempoEvent, to event: PlaybackEvent) -> Bool {
        guard let tempoMeasureID = tempoEvent.measureID else {
            return tempoEvent.onset <= event.onset
        }
        guard let tempoMeasureOrder = measureOrderByID[tempoMeasureID],
              let eventMeasureOrder = measureOrderByID[event.measureID]
        else {
            return tempoMeasureID == event.measureID && tempoEvent.onset <= event.onset
        }
        if tempoMeasureOrder < eventMeasureOrder {
            return true
        }
        if tempoMeasureOrder == eventMeasureOrder {
            return tempoEvent.onset <= event.onset
        }
        return false
    }

    private func orderedTempoEvent(atOrBeforeMeasureOrder measureOrder: Int, onset: MusicalTime) -> OrderedTempoEvent? {
        guard !orderedTempoEvents.isEmpty else {
            return nil
        }
        var low = 0
        var high = orderedTempoEvents.count
        while low < high {
            let mid = (low + high) / 2
            let tempoEvent = orderedTempoEvents[mid]
            if tempoEvent.measureOrder < measureOrder ||
                (tempoEvent.measureOrder == measureOrder && tempoEvent.onset <= onset) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        guard low > 0 else {
            return nil
        }
        return orderedTempoEvents[low - 1]
    }

    private func globalTempoEvent(atOrBefore onset: MusicalTime) -> TempoEvent? {
        guard !globalTempoEvents.isEmpty else {
            return nil
        }
        var low = 0
        var high = globalTempoEvents.count
        while low < high {
            let mid = (low + high) / 2
            if globalTempoEvents[mid].onset <= onset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        guard low > 0 else {
            return nil
        }
        return globalTempoEvents[low - 1]
    }

    private static func clampedTempo(_ tempo: Double) -> Double {
        guard tempo.isFinite else {
            return 120
        }
        return min(max(tempo, 30), 240)
    }

    private static func sleepDuration(
        eventInterval: TimeInterval,
        eventStartedAt: Date,
        now: Date
    ) -> TimeInterval {
        guard eventInterval.isFinite, eventInterval > 0 else {
            return 0
        }
        let processingElapsed = max(0, now.timeIntervalSince(eventStartedAt))
        return max(0, eventInterval - processingElapsed)
    }

    private static func absoluteSleepDuration(
        scheduleStart: TimeInterval,
        scheduledElapsed: TimeInterval,
        now: TimeInterval
    ) -> TimeInterval {
        guard scheduleStart.isFinite,
              scheduledElapsed.isFinite,
              now.isFinite,
              scheduledElapsed > 0
        else {
            return 0
        }
        return max(0, scheduleStart + scheduledElapsed - now)
    }

    private static func monotonicTime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func measureOrderByID(for events: [PlaybackEvent]) -> [MeasureID: Int] {
        var order: [MeasureID: Int] = [:]
        for event in events where order[event.measureID] == nil {
            order[event.measureID] = order.count
        }
        return order
    }

    private static func orderedTempoEvents(
        from tempoEvents: [TempoEvent],
        measureOrderByID: [MeasureID: Int]
    ) -> [OrderedTempoEvent] {
        tempoEvents.compactMap { tempoEvent in
            guard let measureID = tempoEvent.measureID,
                  let measureOrder = measureOrderByID[measureID]
            else {
                return nil
            }
            return OrderedTempoEvent(
                measureOrder: measureOrder,
                onset: tempoEvent.onset,
                bpm: tempoEvent.bpm
            )
        }
        .sorted { lhs, rhs in
            if lhs.measureOrder != rhs.measureOrder {
                return lhs.measureOrder < rhs.measureOrder
            }
            return lhs.onset < rhs.onset
        }
    }

    private static func timeSignatureByMeasureID(
        from events: [TimeSignatureEvent],
        measureOrderByID: [MeasureID: Int]
    ) -> [MeasureID: TimeSignature] {
        let orderedSignatures = events
            .compactMap { event -> (measureOrder: Int, measureID: MeasureID, timeSignature: TimeSignature)? in
                guard let order = measureOrderByID[event.measureID] else {
                    return nil
                }
                return (order, event.measureID, event.timeSignature)
            }
            .sorted { lhs, rhs in
                if lhs.measureOrder != rhs.measureOrder {
                    return lhs.measureOrder < rhs.measureOrder
                }
                return lhs.measureID.rawValue < rhs.measureID.rawValue
            }

        var signatureIndex = 0
        var current = TimeSignature(beats: 4, beatType: 4)
        var result: [MeasureID: TimeSignature] = [:]
        let measuresInPlaybackOrder = measureOrderByID
            .map { (measureID: $0.key, order: $0.value) }
            .sorted { lhs, rhs in lhs.order < rhs.order }

        for measure in measuresInPlaybackOrder {
            while signatureIndex < orderedSignatures.count,
                  orderedSignatures[signatureIndex].measureOrder <= measure.order {
                current = orderedSignatures[signatureIndex].timeSignature
                signatureIndex += 1
            }
            result[measure.measureID] = current
        }
        return result
    }

    private static func clampedGateRatio(_ ratio: Double) -> Double {
        guard ratio.isFinite else {
            return 1.00
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

#if DEBUG
extension PalettePlaybackRuntime {
    static func sleepDurationForTesting(
        eventInterval: TimeInterval,
        processingElapsed: TimeInterval
    ) -> TimeInterval {
        sleepDuration(
            eventInterval: eventInterval,
            eventStartedAt: Date(timeIntervalSinceReferenceDate: 0),
            now: Date(timeIntervalSinceReferenceDate: max(0, processingElapsed))
        )
    }

    static func absoluteSleepDurationForTesting(
        scheduleStart: TimeInterval,
        scheduledElapsed: TimeInterval,
        now: TimeInterval
    ) -> TimeInterval {
        absoluteSleepDuration(
            scheduleStart: scheduleStart,
            scheduledElapsed: scheduledElapsed,
            now: now
        )
    }

    func playbackTimingJitterMillisecondsForTesting() -> [Double] {
        playbackTimingSamples.map(\.jitterMilliseconds)
    }

    func metronomeClickPlanForTesting(startingAt index: Int = 0) -> [PaletteMetronomeClickPlanEntry] {
        buildMetronomeClickPlan(startingAt: index).map { click in
            PaletteMetronomeClickPlanEntry(
                playbackTime: click.playbackTime,
                eventIndex: click.eventIndex,
                measureID: click.measureID,
                beatIndexInMeasure: click.beatIndexInMeasure,
                accent: click.accent,
                timeSignature: click.timeSignature
            )
        }
    }

    func nextMetronomeClickForTesting(
        after elapsed: TimeInterval,
        startingAt index: Int = 0,
        allowImmediate: Bool = false
    ) -> PaletteMetronomeClickPlanEntry? {
        metronomeClickPlan = buildMetronomeClickPlan(startingAt: index)
        let clickIndex = nextMetronomeClickIndex(after: elapsed, allowImmediate: allowImmediate)
        guard let click = metronomeClickPlan[safe: clickIndex] else {
            return nil
        }
        return PaletteMetronomeClickPlanEntry(
            playbackTime: click.playbackTime,
            eventIndex: click.eventIndex,
            measureID: click.measureID,
            beatIndexInMeasure: click.beatIndexInMeasure,
            accent: click.accent,
            timeSignature: click.timeSignature
        )
    }

    private func recordPlaybackTiming(
        eventIndex: Int,
        expectedElapsed: TimeInterval,
        actualElapsed: TimeInterval,
        eventInterval: TimeInterval,
        midiPitchCount: Int
    ) {
        let jitterMilliseconds = (actualElapsed - expectedElapsed) * 1_000
        let sample = PlaybackTimingSample(
            eventIndex: eventIndex,
            expectedElapsed: expectedElapsed,
            actualElapsed: actualElapsed,
            jitterMilliseconds: jitterMilliseconds,
            eventInterval: eventInterval,
            midiPitchCount: midiPitchCount
        )
        playbackTimingSamples.append(sample)
        if ProcessInfo.processInfo.environment["DOREMI_PLAYBACK_TIMING_LOG"] == "1" {
            print(
                "DPM_TIMING eventIndex=\(eventIndex) expected=\(String(format: "%.6f", expectedElapsed)) actual=\(String(format: "%.6f", actualElapsed)) jitterMs=\(String(format: "%.3f", jitterMilliseconds)) interval=\(String(format: "%.6f", eventInterval)) midiPitches=\(midiPitchCount)"
            )
        }
    }

    private func flushPlaybackTimingReportIfNeeded(reason: String) {
        guard let path = ProcessInfo.processInfo.environment["DOREMI_PLAYBACK_TIMING_LOG_PATH"],
              !path.isEmpty,
              !playbackTimingSamples.isEmpty
        else {
            return
        }
        let jitters = playbackTimingSamples.map(\.jitterMilliseconds)
        let average = jitters.reduce(0, +) / Double(jitters.count)
        let sorted = jitters.sorted()
        let p95Index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * 0.95)))
        let maxJitter = sorted.last ?? 0
        var lines: [String] = [
            "reason=\(reason)",
            "events=\(playbackTimingSamples.count)",
            "averageJitterMs=\(String(format: "%.3f", average))",
            "p95JitterMs=\(String(format: "%.3f", sorted[p95Index]))",
            "maxJitterMs=\(String(format: "%.3f", maxJitter))",
            "eventIndex,expectedElapsed,actualElapsed,jitterMs,eventInterval,midiPitchCount",
        ]
        lines.append(contentsOf: playbackTimingSamples.map { sample in
            [
                "\(sample.eventIndex)",
                String(format: "%.6f", sample.expectedElapsed),
                String(format: "%.6f", sample.actualElapsed),
                String(format: "%.3f", sample.jitterMilliseconds),
                String(format: "%.6f", sample.eventInterval),
                "\(sample.midiPitchCount)",
            ].joined(separator: ",")
        })
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("DPM_TIMING_REPORT_WRITE_FAILED \(error.localizedDescription)")
        }
    }
}
#endif

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
