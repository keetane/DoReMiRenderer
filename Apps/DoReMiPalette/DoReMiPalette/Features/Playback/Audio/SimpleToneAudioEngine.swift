import AVFoundation
import DoReMiRendererKit
import Foundation

final class SimpleToneAudioEngine: PaletteAudioEngine {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let polyphonyLimit = 8
    private var isConfigured = false
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var activeVoiceRegistry = PaletteAudioVoiceRegistry()
    private(set) var lastFailure: Error?

    func start() throws {
        if !isConfigured {
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            playerPool = (0..<polyphonyLimit).map { _ in AVAudioPlayerNode() }
            for player in playerPool {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
            }
            isConfigured = true
        }
        if !engine.isRunning {
            do {
                try engine.start()
                lastFailure = nil
            } catch {
                lastFailure = error
                throw error
            }
        }
    }

    func stop() {
        silence()
        engine.stop()
    }

    func silence() {
        for player in playerPool {
            player.stop()
        }
        activeVoiceRegistry.clear()
    }

    func play(midiPitches: [Int], duration: TimeInterval, velocity: Double) {
        guard !midiPitches.isEmpty, duration.isFinite, duration > 0 else {
            silence()
            return
        }
        do {
            try start()
        } catch {
            return
        }

        guard let buffer = makeBuffer(midiPitches: midiPitches, duration: duration, velocity: velocity) else {
            return
        }

        guard !playerPool.isEmpty else {
            return
        }
        let playerIndex = nextPlayerIndex % playerPool.count
        nextPlayerIndex = (nextPlayerIndex + 1) % playerPool.count
        let stoppedVoiceIndices = activeVoiceRegistry.prepareToPlay(
            playerIndex: playerIndex,
            pitches: Set(midiPitches),
            duration: duration,
            now: Date().timeIntervalSinceReferenceDate
        )
        for index in stoppedVoiceIndices where playerPool.indices.contains(index) {
            playerPool[index].stop()
        }
        let player = playerPool[playerIndex]
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
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

    private func makeBuffer(midiPitches: [Int], duration: TimeInterval, velocity: Double) -> AVAudioPCMBuffer? {
        guard duration.isFinite, duration > 0 else {
            return nil
        }
        let frameCount = AVAudioFrameCount(max(1, Int(duration * sampleRate)))
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = frameCount
        let amplitude = Float(min(max(velocity, 0), 1)) * 0.22
        let frequencies = midiPitches.map(Self.frequency(forMIDIPitch:))
        let divisor = Float(max(frequencies.count, 1))

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let sample = frequencies.reduce(0.0) { partial, frequency in
                let lowPitchBoost = frequency < 180 ? 1.35 : 1.0
                let fundamental = sin(2.0 * Double.pi * frequency * t)
                let secondHarmonic = 0.32 * sin(2.0 * Double.pi * frequency * 2.0 * t)
                let thirdHarmonic = 0.12 * sin(2.0 * Double.pi * frequency * 3.0 * t)
                return partial + (fundamental + secondHarmonic + thirdHarmonic) * lowPitchBoost / 1.44
            }
            let fade = envelope(frame: frame, frameCount: Int(frameCount))
            samples[frame] = Float(sample) / divisor * amplitude * fade
        }
        return buffer
    }

    private func envelope(frame: Int, frameCount: Int) -> Float {
        let rampFrames = max(1, min(Int(sampleRate * 0.01), frameCount / 2))
        if frame < rampFrames {
            return Float(frame) / Float(rampFrames)
        }
        let remaining = frameCount - frame - 1
        if remaining < rampFrames {
            return Float(max(remaining, 0)) / Float(rampFrames)
        }
        return 1
    }

    static func frequency(forMIDIPitch midiPitch: Int) -> Double {
        440.0 * pow(2.0, Double(midiPitch - 69) / 12.0)
    }

    static func seconds(for time: MusicalTime, tempoBPM: Double) -> TimeInterval {
        let tempo = min(max(tempoBPM, 30), 240)
        let quarterNotes = Double(time.ticks) / Double(time.ticksPerQuarterNote)
        return min(max(quarterNotes * 60 / tempo, 0.04), 8)
    }
}

struct PaletteAudioVoiceRegistry {
    struct Voice: Equatable {
        let pitches: Set<Int>
        let endsAt: TimeInterval
    }

    private(set) var activeVoices: [Int: Voice] = [:]

    mutating func prepareToPlay(
        playerIndex: Int,
        pitches: Set<Int>,
        duration: TimeInterval,
        now: TimeInterval
    ) -> [Int] {
        let stoppedIndices = activeVoices.compactMap { index, voice -> Int? in
            if index == playerIndex || voice.endsAt <= now || !voice.pitches.isDisjoint(with: pitches) {
                return index
            }
            return nil
        }
        for index in stoppedIndices {
            activeVoices.removeValue(forKey: index)
        }
        if !pitches.isEmpty, duration.isFinite, duration > 0 {
            activeVoices[playerIndex] = Voice(pitches: pitches, endsAt: now + duration)
        }
        return stoppedIndices
    }

    mutating func clear() {
        activeVoices.removeAll()
    }
}
