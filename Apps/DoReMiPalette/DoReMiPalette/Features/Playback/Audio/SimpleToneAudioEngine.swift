import AVFoundation
import DoReMiRendererKit
import Foundation

final class SimpleToneAudioEngine: PaletteAudioEngine {
    private struct BufferCacheKey: Hashable {
        let midiPitch: Int
        let frameCount: AVAudioFrameCount
        let velocityBucket: Int
    }

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let polyphonyLimit = 16
    private let maxCachedBuffers = 512
    private static let maxGeneratedBufferDuration: TimeInterval = 8.0
    private static let maxCachedBufferDuration: TimeInterval = 1.25
    private var isConfigured = false
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var activeVoiceRegistry = PaletteAudioVoiceRegistry()
    private var bufferCache: [BufferCacheKey: AVAudioPCMBuffer] = [:]
    private var bufferCacheOrder: [BufferCacheKey] = []
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
        for player in playerPool where !player.isPlaying {
            player.play()
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

    func prepare(midiPitches: [Int], duration: TimeInterval, velocity: Double) {
        guard !midiPitches.isEmpty, duration.isFinite, duration > 0 else {
            return
        }
        guard Self.synthesizedBufferDuration(for: duration) <= Self.maxCachedBufferDuration else {
            return
        }
        do {
            try start()
        } catch {
            return
        }
        for midiPitch in midiPitches.prefix(polyphonyLimit) {
            _ = makeBuffer(midiPitch: midiPitch, duration: duration, velocity: velocity)
        }
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

        guard !playerPool.isEmpty else {
            return
        }
        let now = Date().timeIntervalSinceReferenceDate
        activeVoiceRegistry.removeExpiredVoices(now: now)
        for midiPitch in midiPitches.prefix(polyphonyLimit) {
            guard let buffer = makeBuffer(midiPitch: midiPitch, duration: duration, velocity: velocity) else {
                continue
            }
            let playerIndex = activeVoiceRegistry.availablePlayerIndex(
                poolCount: playerPool.count,
                now: now
            ) ?? (nextPlayerIndex % playerPool.count)
            nextPlayerIndex = (nextPlayerIndex + 1) % playerPool.count
            let wasActive = activeVoiceRegistry.activeVoices[playerIndex] != nil
            activeVoiceRegistry.registerVoice(
                playerIndex: playerIndex,
                pitches: [midiPitch],
                duration: duration,
                now: now
            )
            let player = playerPool[playerIndex]
            if wasActive {
                player.stop()
            }
            player.scheduleBuffer(buffer, at: nil)
            if !player.isPlaying {
                player.play()
            }
        }
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

    private func makeBuffer(midiPitch: Int, duration: TimeInterval, velocity: Double) -> AVAudioPCMBuffer? {
        guard duration.isFinite, duration > 0 else {
            return nil
        }
        let synthesizedDuration = Self.synthesizedBufferDuration(for: duration)
        let frameCount = AVAudioFrameCount(max(1, Int(synthesizedDuration * sampleRate)))
        let cacheKey = BufferCacheKey(
            midiPitch: midiPitch,
            frameCount: frameCount,
            velocityBucket: Int((min(max(velocity, 0), 1) * 100).rounded())
        )
        let shouldCache = synthesizedDuration <= Self.maxCachedBufferDuration
        if shouldCache, let cached = bufferCache[cacheKey] {
            return cached
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = frameCount
        let amplitude = Float(min(max(velocity, 0), 1)) * 0.22
        let frequency = Self.frequency(forMIDIPitch: midiPitch)

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let lowPitchBoost = frequency < 180 ? 1.35 : 1.0
            let fundamental = sin(2.0 * Double.pi * frequency * t)
            let secondHarmonic = 0.32 * sin(2.0 * Double.pi * frequency * 2.0 * t)
            let thirdHarmonic = 0.12 * sin(2.0 * Double.pi * frequency * 3.0 * t)
            let sample = (fundamental + secondHarmonic + thirdHarmonic) * lowPitchBoost / 1.44
            let fade = envelope(frame: frame, frameCount: Int(frameCount))
            samples[frame] = Float(sample) * amplitude * fade
        }
        if shouldCache {
            cache(buffer, for: cacheKey)
        }
        return buffer
    }

    private func cache(_ buffer: AVAudioPCMBuffer, for key: BufferCacheKey) {
        if bufferCache[key] == nil {
            bufferCacheOrder.append(key)
        }
        bufferCache[key] = buffer
        while bufferCacheOrder.count > maxCachedBuffers {
            let removed = bufferCacheOrder.removeFirst()
            bufferCache.removeValue(forKey: removed)
        }
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

    static func synthesizedBufferDuration(for duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else {
            return 0
        }
        let clamped = min(duration, maxGeneratedBufferDuration)
        switch clamped {
        case ..<0.08:
            return 0.06
        case ..<0.13:
            return 0.10
        default:
            return clamped
        }
    }
}

struct PaletteAudioVoiceRegistry {
    struct Voice: Equatable {
        let pitches: Set<Int>
        let endsAt: TimeInterval
    }

    private(set) var activeVoices: [Int: Voice] = [:]

    mutating func availablePlayerIndex(poolCount: Int, now: TimeInterval) -> Int? {
        removeExpiredVoices(now: now)
        return (0..<poolCount).first { activeVoices[$0] == nil }
    }

    mutating func registerVoice(
        playerIndex: Int,
        pitches: Set<Int>,
        duration: TimeInterval,
        now: TimeInterval
    ) {
        activeVoices.removeValue(forKey: playerIndex)
        if !pitches.isEmpty, duration.isFinite, duration > 0 {
            activeVoices[playerIndex] = Voice(pitches: pitches, endsAt: now + duration)
        }
    }

    mutating func removeExpiredVoices(now: TimeInterval) {
        activeVoices = activeVoices.filter { _, voice in voice.endsAt > now }
    }

    mutating func clear() {
        activeVoices.removeAll()
    }
}
