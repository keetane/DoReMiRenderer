import DoReMiRendererKit
import Foundation

@MainActor
final class PalettePlaybackRuntime {
    var onStateChange: ((PalettePlaybackState) -> Void)?
    var onEventIndexChange: ((Int) -> Void)?
    var onAudioError: ((Error) -> Void)?

    private(set) var events: [PlaybackEvent] = []
    private(set) var tempoEvents: [TempoEvent] = []
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

    private let audioEngine: PaletteAudioEngine
    private var playbackTask: Task<Void, Never>?
    private var usesManualTempoOverride = false
    private static let minimumAudibleDuration: TimeInterval = 0.06
    static let transposeRange = -12...12

    init(
        events: [PlaybackEvent] = [],
        tempoBPM: Double = 120,
        noteGateRatio: Double = 0.85,
        transposeSemitones: Int = 0,
        audioEngine: PaletteAudioEngine = SimpleToneAudioEngine()
    ) {
        self.events = events
        self.tempoBPM = Self.clampedTempo(tempoBPM)
        self.noteGateRatio = Self.clampedGateRatio(noteGateRatio)
        self.transposeSemitones = Self.clampedTranspose(transposeSemitones)
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
        usesManualTempoOverride = false
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
        state = .playing
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
        audioEngine.silence()
        state = .paused
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        audioEngine.silence()
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
              nextEvent.measureID == event.measureID,
              event.onset < nextEvent.onset
        else {
            return eventDurationSeconds(for: event)
        }

        let delta = nextEvent.onset - event.onset
        let quarters = Double(delta.ticks) / Double(delta.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
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
                audioEngine.silence()
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

    private func durationSeconds(for duration: MusicalTime, event: PlaybackEvent) -> TimeInterval {
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        let seconds = quarters * 60.0 / tempoBPM(for: event)
        guard seconds.isFinite, seconds > 0 else {
            return 0
        }
        return min(max(0.01, seconds), 8)
    }

    private func notifyCurrentIndex() {
        onEventIndexChange?(currentEventIndex)
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
