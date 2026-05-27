import DoReMiRendererKit
import SwiftUI

struct KeyboardView: View {
    let layout: ScoreLayout
    let currentNoteIDs: Set<NoteID>
    var highlightState: CurrentNoteHighlightState?
    var nextMIDIPitches: Set<Int> = []
    var range: ClosedRange<Int> = KeyboardPitchMapper.defaultRange
    var palette: ScaleColorPalette = defaultEducationalPalette
    var pitchClassColorState: PalettePitchClassColorState = .allOn
    var colorIdleKeys = false
    var colorPositionTop = true
    var scaleTonicPitchClass: Int?

    private var whiteKeys: [Int] {
        KeyboardPitchMapper.whiteKeys(in: range)
    }

    private var blackKeys: [KeyboardBlackKey] {
        KeyboardPitchMapper.blackKeys(in: range)
    }

    private var highlighted: Set<Int> {
        KeyboardPitchMapper.highlightedMIDINumbers(
            layout: layout,
            currentNoteIDs: currentNoteIDs,
            range: range
        )
    }

    private var attackHighlighted: Set<Int> {
        guard let highlightState else {
            return highlighted
        }
        return Set(highlightState.attackMIDIPitches.filter(range.contains))
    }

    private var continuationHighlighted: Set<Int> {
        guard let highlightState else {
            return []
        }
        return Set(highlightState.continuationMIDIPitches.filter(range.contains))
            .subtracting(attackHighlighted)
    }

    private var nextHighlighted: Set<Int> {
        Set(nextMIDIPitches.filter(range.contains))
    }

    var body: some View {
        GeometryReader { proxy in
            let whiteWidth = proxy.size.width / CGFloat(max(whiteKeys.count, 1))
            let colorBandHeight = max(8, proxy.size.height * 0.20)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        WhiteKey(
                            midi: midi,
                            highlightKind: highlightKind(for: midi),
                            showsNextNote: nextHighlighted.contains(midi),
                        outlinesNextNote: shouldOutlineNextNote(for: midi),
                        color: color(for: midi),
                            isPitchColorEnabled: isPitchColorEnabled(for: midi),
                            colorIdleKey: colorIdleKeys,
                            colorPositionTop: colorPositionTop,
                            colorBandHeight: colorBandHeight
                        )
                        .frame(width: whiteWidth)
                    }
                }

                ForEach(blackKeys, id: \.self) { key in
                    BlackKey(
                        midi: key.midi,
                        highlightKind: highlightKind(for: key.midi),
                        showsNextNote: nextHighlighted.contains(key.midi),
                        outlinesNextNote: shouldOutlineNextNote(for: key.midi),
                        color: color(for: key.midi),
                        isPitchColorEnabled: isPitchColorEnabled(for: key.midi),
                        colorIdleKey: colorIdleKeys,
                        colorPositionTop: colorPositionTop,
                        colorBandHeight: colorBandHeight
                    )
                    .frame(width: whiteWidth * 0.62, height: proxy.size.height * 0.62)
                    .offset(x: (CGFloat(key.precedingWhiteIndex) + 0.68) * whiteWidth)
                }
            }
        }
        .accessibilityLabel("Piano keyboard")
        .accessibilityElement(children: .ignore)
    }

    private func color(for midi: Int) -> Color {
        if colorIdleKeys, let scaleTonicPitchClass {
            guard let scalePitchClass = KeyboardScaleColor.majorScalePitchClass(
                midi: midi,
                tonicPitchClass: scaleTonicPitchClass
            ) else {
                return KeyboardPitchMapper.isBlackKey(midi: midi) ? .black : .white
            }
            return color(for: scalePitchClass)
        }
        let pitchClass = KeyboardScaleColor.basicPitchClass(midi: midi)
        return color(for: pitchClass)
    }

    private func color(for pitchClass: PitchClass) -> Color {
        let scoreColor = palette.color(for: pitchClass)
        return Color(
            .sRGB,
            red: scoreColor.red,
            green: scoreColor.green,
            blue: scoreColor.blue,
            opacity: 1
        )
    }

    private func highlightKind(for midi: Int) -> KeyboardKeyHighlight {
        if attackHighlighted.contains(midi) {
            return .attack
        }
        if continuationHighlighted.contains(midi) {
            return .continuation
        }
        return .none
    }

    private func shouldOutlineNextNote(for midi: Int) -> Bool {
        nextHighlighted.contains(midi) && (attackHighlighted.contains(midi) || continuationHighlighted.contains(midi))
    }

    private func isPitchColorEnabled(for midi: Int) -> Bool {
        if pitchClassColorState.enabledMIDINotes != nil {
            return pitchClassColorState.isEnabledForStaffLine(
                midi: midi,
                scaleTonicPitchClass: scaleTonicPitchClass,
                requiresScaleMembership: true
            )
        }
        if colorIdleKeys {
            guard let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
                midi: midi,
                scaleTonicPitchClass: scaleTonicPitchClass
            ) else {
                return true
            }
            return pitchClassColorState.isEnabled(pitchClass: enabledPitchClass)
        }
        return pitchClassColorState.isEnabled(pitchClass: PalettePitchClassColorState.chromaticPitchClass(for: midi))
    }

}

enum KeyboardScaleColor {
    static func enabledPitchClass(midi: Int, scaleTonicPitchClass: Int?) -> Int? {
        guard let scaleTonicPitchClass else {
            return PalettePitchClassColorState.chromaticPitchClass(for: midi)
        }
        guard let scalePitchClass = majorScalePitchClass(midi: midi, tonicPitchClass: scaleTonicPitchClass) else {
            return nil
        }
        return PalettePitchClassColorState.pitchClass(for: scalePitchClass)
    }

    static func majorScalePitchClassForStaffPosition(midi: Int, tonicPitchClass: Int) -> PitchClass {
        let naturalDegree = naturalDiatonicDegree(midi: midi)
        switch naturalDegree {
        case 0: return .c
        case 1: return .d
        case 2: return .e
        case 3: return .f
        case 4: return .g
        case 5: return .a
        default: return .b
        }
    }

    static func majorScalePitchClass(midi: Int, tonicPitchClass: Int) -> PitchClass? {
        let pitchClass = PalettePitchClassColorState.normalizedPitchClass(midi)
        switch PalettePitchClassColorState.normalizedPitchClass(tonicPitchClass) {
        case 0: return [0: .c, 2: .d, 4: .e, 5: .f, 7: .g, 9: .a, 11: .b][pitchClass]
        case 1: return [1: .c, 3: .d, 5: .e, 6: .f, 8: .g, 10: .a, 0: .b][pitchClass]
        case 2: return [2: .d, 4: .e, 6: .f, 7: .g, 9: .a, 11: .b, 1: .c][pitchClass]
        case 3: return [3: .e, 5: .f, 7: .g, 8: .a, 10: .b, 0: .c, 2: .d][pitchClass]
        case 4: return [4: .e, 6: .f, 8: .g, 9: .a, 11: .b, 1: .c, 3: .d][pitchClass]
        case 5: return [5: .f, 7: .g, 9: .a, 10: .b, 0: .c, 2: .d, 4: .e][pitchClass]
        case 6: return [6: .f, 8: .g, 10: .a, 11: .b, 1: .c, 3: .d, 5: .e][pitchClass]
        case 7: return [7: .g, 9: .a, 11: .b, 0: .c, 2: .d, 4: .e, 6: .f][pitchClass]
        case 8: return [8: .a, 10: .b, 0: .c, 1: .d, 3: .e, 5: .f, 7: .g][pitchClass]
        case 9: return [9: .a, 11: .b, 1: .c, 2: .d, 4: .e, 6: .f, 8: .g][pitchClass]
        case 10: return [10: .b, 0: .c, 2: .d, 3: .e, 5: .f, 7: .g, 9: .a][pitchClass]
        default: return [11: .b, 1: .c, 3: .d, 4: .e, 6: .f, 8: .g, 10: .a][pitchClass]
        }
    }

    static func basicPitchClass(midi: Int) -> PitchClass {
        switch PalettePitchClassColorState.normalizedPitchClass(midi) {
        case 0, 1: return .c
        case 2, 3: return .d
        case 4: return .e
        case 5, 6: return .f
        case 7, 8: return .g
        case 9, 10: return .a
        default: return .b
        }
    }

    private static func naturalDiatonicDegree(midi: Int) -> Int {
        switch PalettePitchClassColorState.normalizedPitchClass(midi) {
        case 0, 1: return 0
        case 2, 3: return 1
        case 4: return 2
        case 5, 6: return 3
        case 7, 8: return 4
        case 9, 10: return 5
        default: return 6
        }
    }
}

private enum KeyboardKeyHighlight {
    case none
    case attack
    case continuation
}

private struct WhiteKey: View {
    let midi: Int
    let highlightKind: KeyboardKeyHighlight
    let showsNextNote: Bool
    let outlinesNextNote: Bool
    let color: Color
    let isPitchColorEnabled: Bool
    let colorIdleKey: Bool
    let colorPositionTop: Bool
    let colorBandHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(strokeColor, lineWidth: highlightKind == .continuation ? 2 : 1)
                )
            if colorIdleKey {
                VStack(spacing: 0) {
                    if !colorPositionTop {
                        Spacer()
                    }
                    Rectangle()
                        .fill(colorBandColor)
                        .frame(height: colorBandHeight)
                    if colorPositionTop {
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            if colorIdleKey && !colorPositionTop && highlightKind != .none {
                Circle()
                    .fill(color.opacity(highlightKind == .continuation ? 0.45 : 0.95))
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                    .frame(width: 12, height: 12)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
            if midi % 12 == 0 {
                Text(KeyboardPitchMapper.label(for: midi))
                    .font(.caption2)
                    .foregroundStyle(highlightKind == .attack ? .white : .secondary)
                    .padding(.top, 6)
                    .padding(.leading, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showsNextNote {
                Circle()
                    .fill(color.opacity(0.95))
                    .overlay(Circle().stroke(Color.black, lineWidth: outlinesNextNote ? 2 : 0))
                    .frame(width: 12, height: 12)
                    .padding(colorPositionTop ? .bottom : .top, 8)
                    .frame(maxHeight: .infinity, alignment: colorPositionTop ? .bottom : .top)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        switch highlightKind {
        case .attack:
            return color.opacity(0.9)
        case .continuation:
            return color.opacity(0.22)
        case .none:
            return .white
        }
    }

    private var colorBandColor: Color {
        if !isPitchColorEnabled {
            return .clear
        }
        switch highlightKind {
        case .attack:
            return color.opacity(0.95)
        case .continuation:
            return color.opacity(0.45)
        case .none:
            return color.opacity(0.95)
        }
    }

    private var strokeColor: Color {
        switch highlightKind {
        case .attack:
            if colorIdleKey {
                return Color.black.opacity(0.52)
            }
            return Color.black.opacity(0.35)
        case .continuation:
            if colorIdleKey {
                return Color.black.opacity(0.42)
            }
            return color.opacity(0.9)
        case .none:
            return Color.black.opacity(0.35)
        }
    }

    private func guideText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: 1)
    }
}

private struct BlackKey: View {
    let midi: Int
    let highlightKind: KeyboardKeyHighlight
    let showsNextNote: Bool
    let outlinesNextNote: Bool
    let color: Color
    let isPitchColorEnabled: Bool
    let colorIdleKey: Bool
    let colorPositionTop: Bool
    let colorBandHeight: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(strokeColor, lineWidth: highlightKind == .continuation ? 2 : 1)
                )
            if colorIdleKey {
                VStack(spacing: 0) {
                    if !colorPositionTop {
                        Spacer()
                    }
                    Rectangle()
                        .fill(colorBandColor)
                        .frame(height: colorBandHeight)
                    if colorPositionTop {
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            if colorIdleKey && !colorPositionTop && highlightKind != .none {
                Circle()
                    .fill(color.opacity(highlightKind == .continuation ? 0.55 : 0.95))
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                    .frame(width: 10, height: 10)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityHidden(true)
            }
            if showsNextNote {
                Circle()
                    .fill(color.opacity(0.95))
                    .overlay(Circle().stroke(Color.black, lineWidth: outlinesNextNote ? 2 : 0))
                    .frame(width: 10, height: 10)
                    .padding(colorPositionTop ? .bottom : .top, 8)
                    .frame(maxHeight: .infinity, alignment: colorPositionTop ? .bottom : .top)
                    .accessibilityHidden(true)
            }
        }
        .shadow(radius: 1, y: 1)
        .accessibilityHidden(true)
    }

    private var fillColor: Color {
        switch highlightKind {
        case .attack:
            return color
        case .continuation:
            return color.opacity(0.36)
        case .none:
            return .black
        }
    }

    private var colorBandColor: Color {
        if !isPitchColorEnabled {
            return .clear
        }
        switch highlightKind {
        case .attack:
            return color.opacity(0.95)
        case .continuation:
            return color.opacity(0.55)
        case .none:
            return color.opacity(0.95)
        }
    }

    private var strokeColor: Color {
        switch highlightKind {
        case .attack, .none:
            return Color.white.opacity(0.28)
        case .continuation:
            if colorIdleKey {
                return Color.white.opacity(0.45)
            }
            return color.opacity(0.95)
        }
    }

    private func guideText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.85), radius: 1, x: 0, y: 1)
    }
}
