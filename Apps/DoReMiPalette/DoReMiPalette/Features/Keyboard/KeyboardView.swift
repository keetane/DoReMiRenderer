import DoReMiRendererKit
import SwiftUI

struct KeyboardView: View {
    let layout: ScoreLayout
    let currentNoteIDs: Set<NoteID>
    var highlightState: CurrentNoteHighlightState?
    var nextMIDIPitches: Set<Int> = []
    var range: ClosedRange<Int> = KeyboardPitchMapper.defaultRange
    var palette: ScaleColorPalette = defaultEducationalPalette

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
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        WhiteKey(
                            midi: midi,
                            highlightKind: highlightKind(for: midi),
                            showsNextNote: nextHighlighted.contains(midi),
                            outlinesNextNote: shouldOutlineNextNote(for: midi),
                            color: color(for: midi)
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
                        color: color(for: key.midi)
                    )
                    .frame(width: whiteWidth * 0.62, height: proxy.size.height * 0.62)
                    .offset(x: (CGFloat(key.precedingWhiteIndex) + 0.68) * whiteWidth)
                }
            }
        }
        .accessibilityLabel("Piano keyboard")
    }

    private func color(for midi: Int) -> Color {
        let pitchClass = pitchClass(for: midi)
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

    private func pitchClass(for midi: Int) -> PitchClass {
        switch ((midi % 12) + 12) % 12 {
        case 0, 1: .c
        case 2, 3: .d
        case 4: .e
        case 5, 6: .f
        case 7, 8: .g
        case 9, 10: .a
        default: .b
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

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(strokeColor, lineWidth: highlightKind == .continuation ? 2 : 1)
                )
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
                    .padding(.bottom, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(KeyboardPitchMapper.label(for: midi))
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

    private var strokeColor: Color {
        switch highlightKind {
        case .attack:
            return Color.black.opacity(0.35)
        case .continuation:
            return color.opacity(0.9)
        case .none:
            return Color.black.opacity(0.35)
        }
    }
}

private struct BlackKey: View {
    let midi: Int
    let highlightKind: KeyboardKeyHighlight
    let showsNextNote: Bool
    let outlinesNextNote: Bool
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(strokeColor, lineWidth: highlightKind == .continuation ? 2 : 1)
                )
            if showsNextNote {
                Circle()
                    .fill(color.opacity(0.95))
                    .overlay(Circle().stroke(Color.black, lineWidth: outlinesNextNote ? 2 : 0))
                    .frame(width: 10, height: 10)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
            }
        }
        .shadow(radius: 1, y: 1)
        .accessibilityLabel(KeyboardPitchMapper.label(for: midi))
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

    private var strokeColor: Color {
        switch highlightKind {
        case .attack, .none:
            return Color.white.opacity(0.28)
        case .continuation:
            return color.opacity(0.95)
        }
    }
}
