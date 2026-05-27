import DoReMiRendererKit
import Foundation

struct PaletteStyleFactory {
    static func makeStyle(
        noteColorVisible: Bool,
        staffColorVisible: Bool,
        paletteKind: PaletteColorScheme = .educational,
        pitchClassColorState: PalettePitchClassColorState = .allOn,
        scaleTonicPitchClass: Int? = nil,
        measureNumbersVisible: Bool = false
    ) -> ScoreStyle {
        let palette = paletteKind.palette
        return ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: staffColorVisible
                ? .rule(PalettePitchClassStaffLineColorRule(
                        palette: palette,
                        enabledState: pitchClassColorState,
                        disabledColor: .black,
                        scaleTonicPitchClass: scaleTonicPitchClass
                    ))
                : .monochrome(.black),
            noteColorStyle: noteColorVisible
                ? .rule(PalettePitchClassNoteColorRule(
                        palette: palette,
                        enabledState: pitchClassColorState,
                        disabledColor: .black,
                        scaleTonicPitchClass: scaleTonicPitchClass
                    ))
                : .monochrome(.black),
            ledgerLineStyle: staffColorVisible
                ? .rule(PalettePitchClassLedgerLineColorRule(
                    palette: palette,
                    enabledState: pitchClassColorState,
                    disabledColor: .black,
                    scaleTonicPitchClass: scaleTonicPitchClass
                ))
                : .defaultInk,
            accidentalStyle: noteColorVisible ? .matchNotePitch : .defaultInk,
            highlightStyle: HighlightStyle(color: ScoreColor(red: 0.1, green: 0.45, blue: 1.0, alpha: 0.28)),
            measureNumberDisplayMode: measureNumbersVisible ? .evenMeasures : .hidden
        )
    }
}

enum PaletteColorScheme: String, CaseIterable, Identifiable {
    case educational
    case muted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .educational: return "標準"
        case .muted: return "やさしい色"
        }
    }

    var palette: ScaleColorPalette {
        switch self {
        case .educational:
            return defaultEducationalPalette
        case .muted:
            return ScaleColorPalette(
                c: ScoreColor(red: 0.78, green: 0.22, blue: 0.22),
                d: ScoreColor(red: 0.83, green: 0.48, blue: 0.18),
                e: ScoreColor(red: 0.72, green: 0.62, blue: 0.18),
                f: ScoreColor(red: 0.20, green: 0.56, blue: 0.32),
                g: ScoreColor(red: 0.20, green: 0.38, blue: 0.70),
                a: ScoreColor(red: 0.38, green: 0.30, blue: 0.62),
                b: ScoreColor(red: 0.60, green: 0.28, blue: 0.55)
            )
        }
    }

    static func fromRawValue(_ rawValue: String) -> PaletteColorScheme {
        PaletteColorScheme(rawValue: rawValue) ?? .educational
    }
}

struct PalettePitchClassColorState: Equatable, Codable, Sendable {
    static let allPitchClasses = Array(0...11)
    static let paletteButtonPitchClasses = [0, 2, 4, 5, 7, 9, 11]
    static let staffLineMIDINotes: Set<Int> = [36, 40, 43, 47, 50, 53, 57, 60, 64, 67, 71, 74, 77, 81, 84]
    static let suppressesStaffLineModeGrayOut = false
    static let defaultEncodedValue = allPitchClasses.map(String.init).joined(separator: ",")
    static let allOn = PalettePitchClassColorState(enabledPitchClasses: Set(allPitchClasses))
    static let allOff = PalettePitchClassColorState(enabledPitchClasses: [])
    static let staffLineOnly = PalettePitchClassColorState(enabledMIDINotes: staffLineMIDINotes)

    var enabledPitchClasses: Set<Int>
    var enabledMIDINotes: Set<Int>?

    var isStaffLineOnly: Bool {
        enabledMIDINotes == Self.staffLineMIDINotes
    }

    init(enabledPitchClasses: Set<Int>) {
        self.enabledPitchClasses = Set(enabledPitchClasses.map(Self.normalizedPitchClass))
        self.enabledMIDINotes = nil
    }

    init(enabledMIDINotes: Set<Int>) {
        self.enabledMIDINotes = enabledMIDINotes
        self.enabledPitchClasses = Set(enabledMIDINotes.map(Self.chromaticPitchClass(for:)))
    }

    init(encodedValue: String) {
        let trimmed = encodedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("midi:") {
            let parsedMIDINotes = trimmed
                .dropFirst("midi:".count)
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            self.init(enabledMIDINotes: Set(parsedMIDINotes))
            return
        }

        let parsed = trimmed
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if parsed.isEmpty && !trimmed.isEmpty {
            self = .allOn
        } else {
            self.init(enabledPitchClasses: Set(parsed))
        }
    }

    var encodedValue: String {
        if let enabledMIDINotes {
            return "midi:" + enabledMIDINotes.sorted().map(String.init).joined(separator: ",")
        }
        return Self.allPitchClasses
            .filter { enabledPitchClasses.contains($0) }
            .map(String.init)
            .joined(separator: ",")
    }

    func isEnabled(pitchClass: Int) -> Bool {
        enabledPitchClasses.contains(Self.normalizedPitchClass(pitchClass))
    }

    func isEnabled(midi: Int) -> Bool {
        if let enabledMIDINotes {
            return enabledMIDINotes.contains(midi)
        }
        return isEnabled(pitchClass: Self.chromaticPitchClass(for: midi))
    }

    func isEnabledForStaffLine(
        midi: Int,
        scaleTonicPitchClass: Int?,
        requiresScaleMembership: Bool = false
    ) -> Bool {
        guard isStaffLineOnly else {
            return isEnabled(midi: midi)
        }
        if Self.suppressesStaffLineModeGrayOut {
            return true
        }
        if requiresScaleMembership, let scaleTonicPitchClass {
            guard KeyboardScaleColor.majorScalePitchClass(midi: midi, tonicPitchClass: scaleTonicPitchClass) != nil else {
                return false
            }
        }
        return Self.staffLineMIDINotes.contains(Self.staffPositionMIDINote(
            midi: midi,
            scaleTonicPitchClass: scaleTonicPitchClass
        ))
    }

    func toggled(_ pitchClass: Int) -> PalettePitchClassColorState {
        var next = enabledPitchClasses
        let normalized = Self.normalizedPitchClass(pitchClass)
        if next.contains(normalized) {
            next.remove(normalized)
        } else {
            next.insert(normalized)
        }
        return PalettePitchClassColorState(enabledPitchClasses: next)
    }

    func isEnabledForPaletteButton(_ pitchClass: Int) -> Bool {
        guard enabledMIDINotes == nil else { return false }
        return Self.containedPitchClasses(forPaletteButton: pitchClass).allSatisfy { enabledPitchClasses.contains($0) }
    }

    func toggledPaletteButton(_ pitchClass: Int) -> PalettePitchClassColorState {
        var next = enabledPitchClasses
        let contained = Self.containedPitchClasses(forPaletteButton: pitchClass)
        let shouldDisable = contained.allSatisfy { next.contains($0) }
        for value in contained {
            if shouldDisable {
                next.remove(value)
            } else {
                next.insert(value)
            }
        }
        return PalettePitchClassColorState(enabledPitchClasses: next)
    }

    static func containedPitchClasses(forPaletteButton pitchClass: Int) -> [Int] {
        switch normalizedPitchClass(pitchClass) {
        case 0: return [0, 1]
        case 2: return [2, 3]
        case 4: return [4]
        case 5: return [5, 6]
        case 7: return [7, 8]
        case 9: return [9, 10]
        case 11: return [11]
        default: return [normalizedPitchClass(pitchClass)]
        }
    }

    static func normalizedPitchClass(_ pitchClass: Int) -> Int {
        let value = pitchClass % 12
        return value >= 0 ? value : value + 12
    }

    static func chromaticPitchClass(for pitch: Pitch) -> Int {
        normalizedPitchClass(naturalSemitone(for: pitch.step) + pitch.alter)
    }

    static func chromaticPitchClass(for midi: Int) -> Int {
        normalizedPitchClass(midi)
    }

    static func label(for pitchClass: Int) -> String {
        switch normalizedPitchClass(pitchClass) {
        case 0: return "C"
        case 1: return "C#"
        case 2: return "D"
        case 3: return "D#"
        case 4: return "E"
        case 5: return "F"
        case 6: return "F#"
        case 7: return "G"
        case 8: return "G#"
        case 9: return "A"
        case 10: return "A#"
        default: return "B"
        }
    }

    static func pitchClass(for pitchClass: PitchClass) -> Int {
        switch pitchClass {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }

    private static func staffLineDiatonicIndex(midi: Int) -> Int {
        let octave = midi / 12 - 1
        let degree = naturalDiatonicDegree(forChromaticPitchClass: normalizedPitchClass(midi))
        return staffLineDiatonicIndexForNatural(octave: octave, degree: degree)
    }

    private static func staffPositionMIDINote(midi: Int) -> Int {
        let octave = midi / 12 - 1
        let degree = naturalDiatonicDegree(forChromaticPitchClass: normalizedPitchClass(midi))
        return (octave + 1) * 12 + [0, 2, 4, 5, 7, 9, 11][degree]
    }

    private static func staffPositionMIDINote(midi: Int, scaleTonicPitchClass: Int?) -> Int {
        let octave = midi / 12 - 1
        let degree: Int
        if let scaleTonicPitchClass,
           let scalePitchClass = KeyboardScaleColor.majorScalePitchClass(
            midi: midi,
            tonicPitchClass: scaleTonicPitchClass
           ) {
            degree = diatonicDegree(for: scalePitchClass)
        } else {
            degree = naturalDiatonicDegree(forChromaticPitchClass: normalizedPitchClass(midi))
        }
        return (octave + 1) * 12 + [0, 2, 4, 5, 7, 9, 11][degree]
    }

    private static func staffLineDiatonicIndexForNatural(octave: Int, degree: Int) -> Int {
        octave * 7 + degree
    }

    private static func diatonicDegree(for pitchClass: PitchClass) -> Int {
        switch pitchClass {
        case .c: return 0
        case .d: return 1
        case .e: return 2
        case .f: return 3
        case .g: return 4
        case .a: return 5
        case .b: return 6
        }
    }

    private static func naturalDiatonicDegree(forChromaticPitchClass pitchClass: Int) -> Int {
        switch normalizedPitchClass(pitchClass) {
        case 0, 1: return 0
        case 2, 3: return 1
        case 4: return 2
        case 5, 6: return 3
        case 7, 8: return 4
        case 9, 10: return 5
        default: return 6
        }
    }

    private static func naturalSemitone(for step: PitchStep) -> Int {
        switch step {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }
}

struct PalettePitchClassNoteColorRule: NoteColorRule {
    let palette: ScaleColorPalette
    let enabledState: PalettePitchClassColorState
    let disabledColor: ScoreColor
    let scaleTonicPitchClass: Int?

    func color(for note: ScoreNote, layout: NoteLayout?, context: ColorContext) -> ScoreColor {
        guard let pitch = layout?.pitch ?? note.pitch else {
            return disabledColor
        }
        let midi = Self.midiNumber(for: pitch)
        let palettePitchClass = Self.palettePitchClassForPalettePreviewLogic(
            pitch: pitch,
            midi: midi,
            scaleTonicPitchClass: scaleTonicPitchClass
        )
        let enabled = Self.isEnabledForPalettePreviewLogic(
            pitch: pitch,
            midi: midi,
            palettePitchClass: palettePitchClass,
            enabledState: enabledState,
            scaleTonicPitchClass: scaleTonicPitchClass
        )
        guard enabled else {
            return disabledColor
        }
        return palette.color(for: palettePitchClass)
    }

    private static func palettePitchClassForPalettePreviewLogic(
        pitch: Pitch,
        midi: Int,
        scaleTonicPitchClass: Int?
    ) -> PitchClass {
        if let scaleTonicPitchClass {
            return KeyboardScaleColor.majorScalePitchClassForStaffPosition(
                midi: midi,
                tonicPitchClass: scaleTonicPitchClass
            )
        }
        return KeyboardScaleColor.basicPitchClass(midi: PalettePitchClassColorState.chromaticPitchClass(for: pitch))
    }

    private static func isEnabledForPalettePreviewLogic(
        pitch: Pitch,
        midi: Int,
        palettePitchClass: PitchClass,
        enabledState: PalettePitchClassColorState,
        scaleTonicPitchClass: Int?
    ) -> Bool {
        if enabledState.enabledMIDINotes != nil {
            if let scaleTonicPitchClass,
               KeyboardScaleColor.majorScalePitchClass(midi: midi, tonicPitchClass: scaleTonicPitchClass) == nil {
                return false
            }
            return enabledState.enabledMIDINotes?.contains(Self.staffPositionMIDINote(for: pitch)) ?? false
        }
        if let scaleTonicPitchClass {
            let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
                midi: midi,
                scaleTonicPitchClass: scaleTonicPitchClass
            ) ?? PalettePitchClassColorState.pitchClass(for: palettePitchClass)
            return enabledState.isEnabled(pitchClass: enabledPitchClass)
        }
        return enabledState.isEnabled(pitchClass: PalettePitchClassColorState.normalizedPitchClass(midi))
    }

    private static func midiNumber(for pitch: Pitch) -> Int {
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

    private static func staffPositionMIDINote(for pitch: Pitch) -> Int {
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
        return (pitch.octave + 1) * 12 + base
    }
}

struct PalettePitchClassStaffLineColorRule: StaffLineColorRule {
    let palette: ScaleColorPalette
    let enabledState: PalettePitchClassColorState
    let disabledColor: ScoreColor
    let scaleTonicPitchClass: Int?

    func color(for staffLine: StaffLineLayout, context: ColorContext) -> ScoreColor {
        let pitchClassHint = staffLine.pitchClassHint ?? staffLinePitchClass(clefKind: staffLine.clefKind, lineIndex: staffLine.lineIndex)
        let chromaticPitchClass = PalettePitchClassColorState.pitchClass(for: pitchClassHint)
        let palettePitchClass: PitchClass
        if let scaleTonicPitchClass,
           let scalePitchClass = KeyboardScaleColor.majorScalePitchClass(
            midi: chromaticPitchClass,
            tonicPitchClass: scaleTonicPitchClass
           ) {
            palettePitchClass = scalePitchClass
        } else {
            palettePitchClass = pitchClassHint
        }
        let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
            midi: chromaticPitchClass,
            scaleTonicPitchClass: scaleTonicPitchClass
        ) ?? chromaticPitchClass
        guard enabledState.isEnabled(pitchClass: enabledPitchClass) else {
            return disabledColor
        }
        return palette.color(for: palettePitchClass)
    }
}

struct PalettePitchClassLedgerLineColorRule: LedgerLineColorRule {
    let palette: ScaleColorPalette
    let enabledState: PalettePitchClassColorState
    let disabledColor: ScoreColor
    let scaleTonicPitchClass: Int?

    func color(for ledgerLine: LedgerLineLayout, note: ScoreNote?, context: ColorContext) -> ScoreColor {
        let pitchClassHint = ledgerLine.pitchClassHint
            ?? context.clef.map { staffPitchClass(clefKind: $0.kind, lineStepFromMiddle: ledgerLine.lineStepFromMiddle) }
            ?? note?.pitch?.pitchClass
            ?? .c
        let chromaticPitchClass = PalettePitchClassColorState.pitchClass(for: pitchClassHint)
        let palettePitchClass: PitchClass
        if let scaleTonicPitchClass,
           let scalePitchClass = KeyboardScaleColor.majorScalePitchClass(
            midi: chromaticPitchClass,
            tonicPitchClass: scaleTonicPitchClass
           ) {
            palettePitchClass = scalePitchClass
        } else {
            palettePitchClass = pitchClassHint
        }
        let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
            midi: chromaticPitchClass,
            scaleTonicPitchClass: scaleTonicPitchClass
        ) ?? chromaticPitchClass
        guard enabledState.isEnabled(pitchClass: enabledPitchClass) else {
            return disabledColor
        }
        return palette.color(for: palettePitchClass)
    }
}
