import DoReMiRendererKit

struct PaletteStyleFactory {
    static func makeStyle(
        noteColorVisible: Bool,
        staffColorVisible: Bool,
        paletteKind: PaletteColorScheme = .educational
    ) -> ScoreStyle {
        let palette = paletteKind.palette
        return ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: staffColorVisible
                ? .pitchClass(defaultPalette: palette, clefOverrides: [:])
                : .monochrome(.black),
            noteColorStyle: noteColorVisible
                ? .pitchClass(palette)
                : .monochrome(.black),
            ledgerLineStyle: noteColorVisible ? .matchNotePitch : .defaultInk,
            accidentalStyle: noteColorVisible ? .matchNotePitch : .defaultInk,
            highlightStyle: HighlightStyle(color: ScoreColor(red: 0.1, green: 0.45, blue: 1.0, alpha: 0.28))
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
