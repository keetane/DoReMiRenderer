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

struct CurrentNoteHighlightState: Equatable {
    var attackNoteIDs: Set<NoteID>
    var continuationNoteIDs: Set<NoteID>
    var attackMIDIPitches: Set<Int>
    var continuationMIDIPitches: Set<Int>
    var isRest: Bool

    static let empty = CurrentNoteHighlightState(
        attackNoteIDs: [],
        continuationNoteIDs: [],
        attackMIDIPitches: [],
        continuationMIDIPitches: [],
        isRest: true
    )

    var scoreFollowNoteIDs: Set<NoteID> {
        attackNoteIDs.isEmpty ? continuationNoteIDs : attackNoteIDs
    }

    func visible(if isVisible: Bool) -> CurrentNoteHighlightState {
        isVisible ? self : .empty
    }

    static func make(event: PlaybackEvent?, layout: ScoreLayout) -> CurrentNoteHighlightState {
        guard let event else {
            return .empty
        }

        var remainingAttacks = Dictionary(grouping: event.midiPitches, by: { $0 })
            .mapValues(\.count)
        var attackNoteIDs: Set<NoteID> = []
        var continuationNoteIDs: Set<NoteID> = []
        var attackMIDIPitches: Set<Int> = []
        var continuationMIDIPitches: Set<Int> = []
        var sawPitchedNote = false

        for noteID in event.noteIDs {
            guard let pitch = layout.noteLayout(for: noteID)?.pitch else {
                continue
            }
            sawPitchedNote = true
            let midi = KeyboardPitchMapper.midiNumber(for: pitch)
            if (remainingAttacks[midi] ?? 0) > 0 {
                attackNoteIDs.insert(noteID)
                attackMIDIPitches.insert(midi)
                remainingAttacks[midi, default: 0] -= 1
            } else {
                continuationNoteIDs.insert(noteID)
                continuationMIDIPitches.insert(midi)
            }
        }

        return CurrentNoteHighlightState(
            attackNoteIDs: attackNoteIDs,
            continuationNoteIDs: continuationNoteIDs,
            attackMIDIPitches: attackMIDIPitches,
            continuationMIDIPitches: continuationMIDIPitches.subtracting(attackMIDIPitches),
            isRest: !sawPitchedNote && event.midiPitches.isEmpty
        )
    }
}


struct PracticeNoteDisplay: Equatable {
    let englishName: String
    let solfegeName: String
    let summary: String

    static let rest = PracticeNoteDisplay(englishName: "Rest", solfegeName: "休符", summary: "休符")
}

struct PracticeNoteNameFormatter {
    static func display(
        layout: ScoreLayout,
        noteIDs: Set<NoteID>
    ) -> PracticeNoteDisplay {
        guard !noteIDs.isEmpty else {
            return .rest
        }
        let pitches = noteIDs.compactMap { layout.noteLayout(for: $0)?.pitch }
        guard !pitches.isEmpty else {
            return .rest
        }
        let sorted = pitches.sorted { lhs, rhs in
            KeyboardPitchMapper.midiNumber(for: lhs) < KeyboardPitchMapper.midiNumber(for: rhs)
        }
        let english = sorted.map(englishName(for:)).joined(separator: "-")
        let solfege = sorted.map(solfegeName(for:)).joined(separator: "-")
        let prefix = sorted.count > 1 ? "Chord: " : ""
        return PracticeNoteDisplay(
            englishName: english,
            solfegeName: solfege,
            summary: "\(prefix)\(english) / \(solfege)"
        )
    }

    static func englishName(for pitch: Pitch) -> String {
        "\(englishStepName(for: pitch.step))\(accidentalText(for: pitch.alter))\(pitch.octave)"
    }

    static func solfegeName(for pitch: Pitch) -> String {
        "\(solfegeStepName(for: pitch.step))\(accidentalText(for: pitch.alter))"
    }

    private static func englishStepName(for step: PitchStep) -> String {
        switch step {
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .a: return "A"
        case .b: return "B"
        }
    }

    private static func solfegeStepName(for step: PitchStep) -> String {
        switch step {
        case .c: return "ド"
        case .d: return "レ"
        case .e: return "ミ"
        case .f: return "ファ"
        case .g: return "ソ"
        case .a: return "ラ"
        case .b: return "シ"
        }
    }

    private static func accidentalText(for alter: Int) -> String {
        switch alter {
        case 1: return "#"
        case -1: return "b"
        case let value where value > 1: return String(repeating: "#", count: value)
        case let value where value < -1: return String(repeating: "b", count: abs(value))
        default: return ""
        }
    }
}
