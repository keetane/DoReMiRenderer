import DoReMiRendererKit
import Foundation

struct KeyboardPitchMapper {
    static let defaultRange: ClosedRange<Int> = 36...84

    static func midiNumber(for pitch: Pitch) -> Int {
        let base: Int
        switch pitch.step {
        case .c: base = 0
        case .d: base = 2
        case .e: base = 4
        case .f: base = 5
        case .g: base = 7
        case .a: base = 9
        case .b: base = 11
        }
        return (pitch.octave + 1) * 12 + base + pitch.alter
    }

    static func isBlackKey(midi: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(normalizedPitchClass(midi))
    }

    static func whiteKeys(in range: ClosedRange<Int>) -> [Int] {
        range.filter { !isBlackKey(midi: $0) }
    }

    static func blackKeys(in range: ClosedRange<Int>) -> [KeyboardBlackKey] {
        let whites = whiteKeys(in: range)
        guard !whites.isEmpty else {
            return []
        }
        let whiteIndex = Dictionary(uniqueKeysWithValues: whites.enumerated().map { ($0.element, $0.offset) })
        return range.compactMap { midi in
            guard isBlackKey(midi: midi) else {
                return nil
            }
            let previousWhite = stride(from: midi - 1, through: range.lowerBound, by: -1)
                .first { !isBlackKey(midi: $0) }
            guard let previousWhite, let previousIndex = whiteIndex[previousWhite] else {
                return nil
            }
            return KeyboardBlackKey(midi: midi, precedingWhiteIndex: previousIndex)
        }
    }

    static func highlightedMIDINumbers(
        layout: ScoreLayout,
        currentNoteIDs: Set<NoteID>,
        range: ClosedRange<Int> = defaultRange
    ) -> Set<Int> {
        Set(currentNoteIDs.compactMap { noteID in
            guard let pitch = layout.noteLayout(for: noteID)?.pitch else {
                return nil
            }
            let midi = midiNumber(for: pitch)
            return range.contains(midi) ? midi : nil
        })
    }

    static func label(for midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let pitchClass = normalizedPitchClass(midi)
        let octave = midi / 12 - 1
        return "\(names[pitchClass])\(octave)"
    }

    private static func normalizedPitchClass(_ midi: Int) -> Int {
        let value = midi % 12
        return value >= 0 ? value : value + 12
    }
}

struct KeyboardBlackKey: Hashable {
    let midi: Int
    let precedingWhiteIndex: Int
}

