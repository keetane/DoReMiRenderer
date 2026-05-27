import DoReMiRendererKit
import Foundation

enum PaletteTranspose {
    static let range = -12...12
    static let fallbackWrittenPitchClass = 0

    struct KeyOption: Identifiable, Equatable {
        let name: String
        let pitchClass: Int

        var id: Int { pitchClass }
    }

    static let keyOptions: [KeyOption] = [
        KeyOption(name: "C", pitchClass: 0),
        KeyOption(name: "C#/Db", pitchClass: 1),
        KeyOption(name: "D", pitchClass: 2),
        KeyOption(name: "D#/Eb", pitchClass: 3),
        KeyOption(name: "E", pitchClass: 4),
        KeyOption(name: "F", pitchClass: 5),
        KeyOption(name: "F#/Gb", pitchClass: 6),
        KeyOption(name: "G", pitchClass: 7),
        KeyOption(name: "G#/Ab", pitchClass: 8),
        KeyOption(name: "A", pitchClass: 9),
        KeyOption(name: "A#/Bb", pitchClass: 10),
        KeyOption(name: "B", pitchClass: 11),
    ]

    static func clamped(_ semitones: Int) -> Int {
        min(max(semitones, range.lowerBound), range.upperBound)
    }

    static func formatted(_ semitones: Int) -> String {
        let clampedValue = clamped(semitones)
        if clampedValue > 0 {
            return "+\(clampedValue)"
        }
        return "\(clampedValue)"
    }

    static func normalizedPitchClass(_ pitchClass: Int) -> Int {
        let value = pitchClass % 12
        return value >= 0 ? value : value + 12
    }

    static func selectedTargetPitchClass(writtenPitchClass: Int?, transposeSemitones: Int) -> Int {
        normalizedPitchClass((writtenPitchClass ?? fallbackWrittenPitchClass) + clamped(transposeSemitones))
    }

    static func semitones(fromWrittenPitchClass writtenPitchClass: Int?, toTargetPitchClass targetPitchClass: Int) -> Int {
        let written = writtenPitchClass ?? fallbackWrittenPitchClass
        let upward = normalizedPitchClass(targetPitchClass - written)
        let nearest = upward <= 6 ? upward : upward - 12
        return clamped(nearest)
    }

    static func keyName(forPitchClass pitchClass: Int) -> String {
        keyOptions.first { $0.pitchClass == normalizedPitchClass(pitchClass) }?.name ?? "C"
    }

    static func relativeMinorName(forMajorPitchClass pitchClass: Int) -> String {
        let minorPitchClass = normalizedPitchClass(pitchClass - 3)
        let names = [
            0: "Cm",
            1: "C#m",
            2: "Dm",
            3: "D#m",
            4: "Em",
            5: "Fm",
            6: "F#m",
            7: "Gm",
            8: "G#m",
            9: "Am",
            10: "A#m",
            11: "Bm",
        ]
        return names[minorPitchClass, default: "Am"]
    }
}

struct PaletteKeyDisplay: Equatable {
    let writtenKey: String
    let soundingKey: String?
    let displayKey: String?
    let transposeDescription: String?
    let displayTransposeEnabled: Bool
    let writtenPitchClass: Int?
    let displayPitchClass: Int?

    var summary: String {
        if let displayKey, displayTransposeEnabled {
            return "\(writtenKey) / \(displayKey)"
        }
        guard let soundingKey else {
            return writtenKey
        }
        return "\(writtenKey) / \(soundingKey)"
    }

    static func make(
        score: ScoreDocument,
        transposeSemitones: Int,
        displayTransposeEnabled: Bool = false
    ) -> PaletteKeyDisplay {
        guard let keySignature = score.parts.first?.measures.first(where: { $0.keySignature != nil })?.keySignature else {
            return PaletteKeyDisplay(
                writtenKey: "unknown",
                soundingKey: nil,
                displayKey: nil,
                transposeDescription: nil,
                displayTransposeEnabled: displayTransposeEnabled,
                writtenPitchClass: nil,
                displayPitchClass: nil
            )
        }
        return make(
            keySignature: keySignature,
            transposeSemitones: transposeSemitones,
            displayTransposeEnabled: displayTransposeEnabled
        )
    }

    static func make(
        keySignature: KeySignature,
        transposeSemitones: Int,
        displayTransposeEnabled: Bool = false
    ) -> PaletteKeyDisplay {
        let mode = normalizedMode(keySignature.mode)
        let written = keyName(fifths: keySignature.fifths, mode: mode)
        let transpose = PaletteTranspose.clamped(transposeSemitones)
        guard transpose != 0 else {
            return PaletteKeyDisplay(
                writtenKey: written,
                soundingKey: nil,
                displayKey: nil,
                transposeDescription: nil,
                displayTransposeEnabled: displayTransposeEnabled,
                writtenPitchClass: tonicPitchClass(fifths: keySignature.fifths, mode: mode),
                displayPitchClass: nil
            )
        }
        let writtenPitchClass = tonicPitchClass(fifths: keySignature.fifths, mode: mode)
        let transposedPitchClass = normalizedPitchClass(writtenPitchClass + transpose)
        let transposedFifths = fifths(forTonicPitchClass: transposedPitchClass, mode: mode)
        let sounding = keyName(fifths: transposedFifths, mode: mode)
        return PaletteKeyDisplay(
            writtenKey: written,
            soundingKey: sounding,
            displayKey: displayTransposeEnabled ? sounding : nil,
            transposeDescription: PaletteTranspose.formatted(transpose),
            displayTransposeEnabled: displayTransposeEnabled,
            writtenPitchClass: writtenPitchClass,
            displayPitchClass: displayTransposeEnabled ? transposedPitchClass : nil
        )
    }

    private static func normalizedMode(_ mode: String?) -> String {
        guard let mode = mode?.lowercased(), mode == "minor" else {
            return "major"
        }
        return "minor"
    }

    private static func keyName(fifths: Int, mode: String) -> String {
        let clampedFifths = min(max(fifths, -7), 7)
        if mode == "minor" {
            let names = [
                -7: "Ab", -6: "Eb", -5: "Bb", -4: "F", -3: "C", -2: "G", -1: "D",
                 0: "A",  1: "E",  2: "B",  3: "F#", 4: "C#", 5: "G#", 6: "D#", 7: "A#",
            ]
            return "\(names[clampedFifths, default: "A"]) minor"
        }
        let names = [
            -7: "Cb", -6: "Gb", -5: "Db", -4: "Ab", -3: "Eb", -2: "Bb", -1: "F",
             0: "C",   1: "G",   2: "D",   3: "A",   4: "E",   5: "B",   6: "F#", 7: "C#",
        ]
        return "\(names[clampedFifths, default: "C"]) major"
    }

    private static func tonicPitchClass(fifths: Int, mode: String) -> Int {
        let majorPitchClass = normalizedPitchClass(fifths * 7)
        if mode == "minor" {
            return normalizedPitchClass(majorPitchClass - 3)
        }
        return majorPitchClass
    }

    private static func fifths(forTonicPitchClass pitchClass: Int, mode: String) -> Int {
        let normalized = normalizedPitchClass(pitchClass)
        let candidates = (-7...7).compactMap { fifths -> (fifths: Int, pitchClass: Int)? in
            let candidate = tonicPitchClass(fifths: fifths, mode: mode)
            return candidate == normalized ? (fifths, candidate) : nil
        }
        return candidates.min { lhs, rhs in
            abs(lhs.fifths) < abs(rhs.fifths)
        }?.fifths ?? 0
    }

    private static func normalizedPitchClass(_ pitchClass: Int) -> Int {
        PaletteTranspose.normalizedPitchClass(pitchClass)
    }
}
