import DoReMiRendererKit
import SwiftUI

struct TrackLayoutView: View {
    let title: String
    let events: [PlaybackEvent]
    let currentEventIndex: Int
    let currentMIDIPitches: Set<Int>
    let playbackState: PalettePlaybackState
    let tempoBPM: Double
    let transposeSemitones: Int
    let palette: ScaleColorPalette
    let pitchClassColorState: PalettePitchClassColorState
    let scaleTonicPitchClass: Int?
    let playbackTimeProvider: (() -> TimeInterval)?
    let scheduledStartTimes: [TimeInterval]
    let scheduledDurations: [TimeInterval]
    let scheduledPitchDurations: [[Int: TimeInterval]]
    let onVisualEventIndexChange: ((Int) -> Void)?
    let onActiveMIDIPitchesChange: ((Set<Int>) -> Void)?
    var range: ClosedRange<Int> = KeyboardPitchMapper.defaultRange

    @State private var anchorEventIndex = 0
    @State private var anchorDate = Date()

    private let lookAheadSeconds: TimeInterval = 5.0
    private let lookBehindSeconds: TimeInterval = 0.8

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let timeline = TrackPlaybackTimeline(
                    events: events,
                    tempoBPM: tempoBPM,
                    scheduledStartTimes: scheduledStartTimes,
                    scheduledDurations: scheduledDurations,
                    scheduledPitchDurations: scheduledPitchDurations
                )
                let playbackTime = currentPlaybackTime(
                    now: context.date,
                    timeline: timeline
                )
                let visualEventIndex = timeline.eventIndex(at: playbackTime) ?? currentEventIndex
                let activeMIDIPitches = timeline.activeMIDIPitches(
                    at: playbackTime,
                    transposeSemitones: transposeSemitones
                )
                let activeBarKeys = timeline.activeBarKeys(at: playbackTime)
                ZStack(alignment: .topLeading) {
                    TrackGridView(range: range)
                    Canvas { canvas, size in
                        drawTrack(
                            in: &canvas,
                            size: size,
                            timeline: timeline,
                            playbackTime: playbackTime,
                            activeBarKeys: activeBarKeys
                        )
                    }
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onAppear {
                            reportVisualEventIndex(visualEventIndex)
                            reportActiveMIDIPitches(activeMIDIPitches)
                        }
                        .onChange(of: visualEventIndex) { _, newIndex in
                            reportVisualEventIndex(newIndex)
                        }
                        .onChange(of: activeMIDIPitches) { _, newPitches in
                            reportActiveMIDIPitches(newPitches)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.custom(trackTitleFontName(for: title), size: 34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                        Text("Track")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                            .padding(10)
                    }
                    .allowsHitTesting(false)
                }
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Rectangle())
            }
        }
        .accessibilityLabel("トラックレイアウト")
        .onAppear {
            resetAnchor()
        }
        .onChange(of: currentEventIndex) { _, _ in
            if playbackState != .playing {
                resetAnchor()
            }
        }
        .onChange(of: playbackState) { _, _ in
            resetAnchor()
        }
        .onChange(of: tempoBPM) { _, _ in
            resetAnchor()
        }
    }

    private func resetAnchor() {
        anchorEventIndex = currentEventIndex
        anchorDate = Date()
    }

    private func currentPlaybackTime(now: Date, timeline: TrackPlaybackTimeline) -> TimeInterval {
        if playbackState == .playing,
           let playbackTime = playbackTimeProvider?(),
           playbackTime.isFinite {
            return max(0, playbackTime)
        }
        let anchorStart = timeline.startTime(at: min(max(anchorEventIndex, 0), max(events.count - 1, 0)))
        guard playbackState == .playing else {
            return timeline.startTime(at: min(max(currentEventIndex, 0), max(events.count - 1, 0)))
        }
        return anchorStart + max(0, now.timeIntervalSince(anchorDate))
    }

    private func drawTrack(
        in canvas: inout GraphicsContext,
        size: CGSize,
        timeline: TrackPlaybackTimeline,
        playbackTime: TimeInterval,
        activeBarKeys: Set<TrackPlaybackTimeline.BarKey>
    ) {
        let hitLineY = max(80, size.height - 26)
        let pixelsPerSecond = max(72, size.height / CGFloat(lookAheadSeconds + 0.9))
        let visibleStart = playbackTime - lookBehindSeconds
        let visibleEnd = playbackTime + lookAheadSeconds

        drawHitLine(in: &canvas, size: size, y: hitLineY)

        for bar in timeline.bars where bar.endTime >= visibleStart && bar.startTime <= visibleEnd {
            guard let midi = KeyboardPitchMapper.transposedMIDINumber(bar.midiPitch, by: transposeSemitones),
                  range.contains(midi) else { continue }
            let yStart = hitLineY - CGFloat(bar.startTime - playbackTime) * pixelsPerSecond
            let height = max(18, CGFloat(bar.duration) * pixelsPerSecond)
            let rectY = yStart - height
            guard rectY < size.height + 24, rectY + height > -24 else {
                continue
            }

            let keyFrame = keyFrame(for: midi, in: size)
            let noteWidth = max(12, min(keyFrame.width * 0.84, 34))
            let rect = CGRect(
                x: keyFrame.midX - noteWidth / 2,
                y: rectY,
                width: noteWidth,
                height: height
            )
            let isActivePitch = activeBarKeys.contains(bar.key)
            let color = color(for: midi).opacity(isActivePitch ? 1.0 : 0.5)
            canvas.fill(
                Path(roundedRect: rect, cornerRadius: 6),
                with: .color(color)
            )
            canvas.stroke(
                Path(roundedRect: rect, cornerRadius: 6),
                with: .color(isActivePitch ? .black.opacity(0.34) : .black.opacity(0.08)),
                lineWidth: isActivePitch ? 1.5 : 1
            )
        }
    }

    private func drawHitLine(in canvas: inout GraphicsContext, size: CGSize, y: CGFloat) {
        let rect = CGRect(x: 0, y: y - 2, width: size.width, height: 4)
        canvas.fill(Path(rect), with: .color(.blue.opacity(0.38)))
    }

    private func reportVisualEventIndex(_ index: Int) {
        guard events.indices.contains(index) else {
            return
        }
        DispatchQueue.main.async {
            onVisualEventIndexChange?(index)
        }
    }

    private func reportActiveMIDIPitches(_ midiPitches: Set<Int>) {
        DispatchQueue.main.async {
            onActiveMIDIPitchesChange?(midiPitches)
        }
    }

    private func keyFrame(for midi: Int, in size: CGSize) -> CGRect {
        KeyboardPitchMapper.keyFrame(for: midi, totalSize: size, range: range)
    }

    private func color(for midi: Int) -> Color {
        let pitchClass: PitchClass
        if let scaleTonicPitchClass,
           let scalePitchClass = KeyboardScaleColor.majorScalePitchClass(
                midi: midi,
                tonicPitchClass: scaleTonicPitchClass
           ) {
            pitchClass = scalePitchClass
        } else {
            pitchClass = KeyboardScaleColor.basicPitchClass(midi: midi)
        }
        if !isPitchColorEnabled(for: midi) {
            return .secondary.opacity(0.44)
        }
        let scoreColor = palette.color(for: pitchClass)
        return Color(
            .sRGB,
            red: scoreColor.red,
            green: scoreColor.green,
            blue: scoreColor.blue,
            opacity: 1
        )
    }

    private func isPitchColorEnabled(for midi: Int) -> Bool {
        if pitchClassColorState.enabledMIDINotes != nil {
            return pitchClassColorState.isEnabledForStaffLine(
                midi: midi,
                scaleTonicPitchClass: scaleTonicPitchClass,
                requiresScaleMembership: true
            )
        }
        guard let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
            midi: midi,
            scaleTonicPitchClass: scaleTonicPitchClass
        ) else {
            return false
        }
        return pitchClassColorState.isEnabled(pitchClass: enabledPitchClass)
    }

    private func trackTitleFontName(for title: String) -> String {
        let usesJapaneseScript = title.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0x3040...0x30FF).contains(value)
                || (0x3400...0x9FFF).contains(value)
                || (0xF900...0xFAFF).contains(value)
        }
        return usesJapaneseScript ? "HiraginoMincho-W6" : "TimesNewRomanPS-BoldMT"
    }
}

private struct TrackGridView: View {
    let range: ClosedRange<Int>

    var body: some View {
        GeometryReader { proxy in
            let whiteKeys = KeyboardPitchMapper.whiteKeys(in: range)
            let whiteWidth = KeyboardPitchMapper.whiteKeyWidth(totalWidth: proxy.size.width, range: range)
            Canvas { canvas, size in
                for index in whiteKeys.indices {
                    let x = CGFloat(index) * whiteWidth
                    let rect = CGRect(x: x, y: 0, width: 1, height: size.height)
                    canvas.fill(Path(rect), with: .color(.primary.opacity(0.08)))
                }
                for blackKey in KeyboardPitchMapper.blackKeys(in: range) {
                    let frame = KeyboardPitchMapper.keyFrame(for: blackKey.midi, totalSize: size, range: range)
                    let rect = CGRect(x: frame.minX, y: 0, width: frame.width, height: size.height)
                    canvas.fill(Path(rect), with: .color(.primary.opacity(0.035)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct TrackPlaybackTimeline {
    struct BarKey: Hashable {
        let index: Int
        let midiPitch: Int
    }

    struct Item: Equatable {
        let index: Int
        let event: PlaybackEvent
        let startTime: TimeInterval
        let duration: TimeInterval

        var endTime: TimeInterval {
            startTime + duration
        }
    }

    struct Bar: Equatable {
        let index: Int
        let event: PlaybackEvent
        let midiPitch: Int
        let startTime: TimeInterval
        let duration: TimeInterval

        var endTime: TimeInterval {
            startTime + duration
        }

        var key: BarKey {
            BarKey(index: index, midiPitch: midiPitch)
        }
    }

    let items: [Item]
    let bars: [Bar]

    init(
        events: [PlaybackEvent],
        tempoBPM: Double,
        scheduledStartTimes: [TimeInterval] = [],
        scheduledDurations: [TimeInterval] = [],
        scheduledPitchDurations: [[Int: TimeInterval]] = []
    ) {
        let tempo = min(max(tempoBPM, 30), 240)
        let builtItems: [Item]
        let usesScheduledDurations = scheduledStartTimes.count == events.count
            && scheduledDurations.count == events.count
        if usesScheduledDurations {
            builtItems = events.enumerated().map { index, event in
                let duration = scheduledDurations[index]
                return Item(
                    index: index,
                    event: event,
                    startTime: max(0, scheduledStartTimes[index]),
                    duration: Self.clampedDuration(duration)
                )
            }
        } else {
            var elapsed: TimeInterval = 0
            builtItems = events.enumerated().map { index, event in
                let duration = Self.durationSeconds(for: event, tempoBPM: tempo)
                defer { elapsed += duration }
                return Item(
                    index: index,
                    event: event,
                    startTime: elapsed,
                    duration: duration
                )
            }
        }
        items = builtItems
        bars = builtItems.flatMap { item in
            item.event.midiPitches.map { midiPitch in
                let duration = scheduledPitchDurations.indices.contains(item.index)
                    ? scheduledPitchDurations[item.index][midiPitch] ?? item.duration
                    : usesScheduledDurations
                        ? item.duration
                        : Self.pitchDurationSeconds(for: midiPitch, event: item.event, tempoBPM: tempo)
                return Bar(
                    index: item.index,
                    event: item.event,
                    midiPitch: midiPitch,
                    startTime: item.startTime,
                    duration: Self.clampedDuration(duration)
                )
            }
        }
    }

    func startTime(at index: Int) -> TimeInterval {
        guard items.indices.contains(index) else {
            return 0
        }
        return items[index].startTime
    }

    func eventIndex(at playbackTime: TimeInterval) -> Int? {
        guard !items.isEmpty else {
            return nil
        }
        return items.last(where: { $0.startTime <= playbackTime })?.index
    }

    func activeMIDIPitches(at playbackTime: TimeInterval, transposeSemitones: Int) -> Set<Int> {
        Set(
            bars
                .filter { playbackTime >= $0.startTime && playbackTime < $0.endTime }
                .compactMap { bar in
                    KeyboardPitchMapper.transposedMIDINumber(bar.midiPitch, by: transposeSemitones)
                }
        )
    }

    func activeBarKeys(at playbackTime: TimeInterval) -> Set<BarKey> {
        Set(
            bars
                .filter { playbackTime >= $0.startTime && playbackTime < $0.endTime }
                .map(\.key)
        )
    }

    private static func durationSeconds(for event: PlaybackEvent, tempoBPM: Double) -> TimeInterval {
        let quarters = Double(event.nominalDuration.ticks) / Double(event.nominalDuration.ticksPerQuarterNote)
        let base = quarters * 60.0 / tempoBPM
        let scaled = base * event.expression.durationScale
        let extra = min(max(0, scaled - base), event.expression.maxDurationExtraSeconds)
        let duration = base + extra
        guard duration.isFinite, duration > 0 else {
            return 0.05
        }
        return clampedDuration(duration)
    }

    private static func pitchDurationSeconds(for midiPitch: Int, event: PlaybackEvent, tempoBPM: Double) -> TimeInterval {
        let duration = event.midiPitchDurations[midiPitch] ?? event.nominalDuration
        let quarters = Double(duration.ticks) / Double(duration.ticksPerQuarterNote)
        let base = quarters * 60.0 / tempoBPM
        let scaled = base * event.expression.durationScale
        let extra = min(max(0, scaled - base), event.expression.maxDurationExtraSeconds)
        let seconds = base + extra
        guard seconds.isFinite, seconds > 0 else {
            return 0.05
        }
        return clampedDuration(seconds)
    }

    private static func clampedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else {
            return 0.05
        }
        return min(max(duration, 0.05), 8)
    }
}
