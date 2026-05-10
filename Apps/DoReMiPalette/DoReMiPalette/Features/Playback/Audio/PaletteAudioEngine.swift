import DoReMiRendererKit
import Foundation

protocol PaletteAudioEngine: AnyObject {
    var lastFailure: Error? { get }

    func start() throws
    func stop()
    func silence()
    func play(midiPitches: [Int], duration: TimeInterval, velocity: Double)
    func play(event: PlaybackEvent, tempoBPM: Double, velocity: Double)
}

final class SilentPaletteAudioEngine: PaletteAudioEngine {
    private(set) var playedEvents: [[Int]] = []
    private(set) var silenceCount = 0
    private(set) var stopCount = 0
    private(set) var lastFailure: Error?

    func start() throws {}

    func stop() {
        stopCount += 1
        silence()
    }

    func silence() {
        silenceCount += 1
    }

    func play(midiPitches: [Int], duration: TimeInterval, velocity: Double) {
        playedEvents.append(midiPitches)
    }

    func play(event: PlaybackEvent, tempoBPM: Double, velocity: Double) {
        guard !event.midiPitches.isEmpty else {
            silence()
            return
        }
        play(
            midiPitches: event.midiPitches,
            duration: Self.seconds(for: event.nominalDuration, tempoBPM: tempoBPM),
            velocity: velocity
        )
    }

    private static func seconds(for time: MusicalTime, tempoBPM: Double) -> TimeInterval {
        let tempo = min(max(tempoBPM, 30), 240)
        let quarterNotes = Double(time.ticks) / Double(time.ticksPerQuarterNote)
        return min(max(quarterNotes * 60 / tempo, 0.04), 8)
    }
}
