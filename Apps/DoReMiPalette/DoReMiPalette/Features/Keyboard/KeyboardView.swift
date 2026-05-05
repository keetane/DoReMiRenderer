import DoReMiRendererKit
import SwiftUI

struct KeyboardView: View {
    let layout: ScoreLayout
    let currentNoteIDs: Set<NoteID>
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

    var body: some View {
        GeometryReader { proxy in
            let whiteWidth = proxy.size.width / CGFloat(max(whiteKeys.count, 1))
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { midi in
                        WhiteKey(
                            midi: midi,
                            isHighlighted: highlighted.contains(midi),
                            color: color(for: midi)
                        )
                        .frame(width: whiteWidth)
                    }
                }

                ForEach(blackKeys, id: \.self) { key in
                    BlackKey(
                        midi: key.midi,
                        isHighlighted: highlighted.contains(key.midi),
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

private struct WhiteKey: View {
    let midi: Int
    let isHighlighted: Bool
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isHighlighted ? color.opacity(0.9) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                )
            if midi % 12 == 0 {
                Text(KeyboardPitchMapper.label(for: midi))
                    .font(.caption2)
                    .foregroundStyle(isHighlighted ? .white : .secondary)
                    .padding(.bottom, 6)
            }
        }
        .accessibilityLabel(KeyboardPitchMapper.label(for: midi))
    }
}

private struct BlackKey: View {
    let midi: Int
    let isHighlighted: Bool
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isHighlighted ? color : Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(radius: 1, y: 1)
            .accessibilityLabel(KeyboardPitchMapper.label(for: midi))
    }
}

