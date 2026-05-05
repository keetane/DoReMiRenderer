import DoReMiRendererKit

struct PaletteStyleFactory {
    static func makeStyle(noteColorVisible: Bool, staffColorVisible: Bool) -> ScoreStyle {
        ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: staffColorVisible
                ? .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:])
                : .monochrome(.black),
            noteColorStyle: noteColorVisible
                ? .pitchClass(defaultEducationalPalette)
                : .monochrome(.black),
            ledgerLineStyle: noteColorVisible ? .matchNotePitch : .defaultInk,
            accidentalStyle: noteColorVisible ? .matchNotePitch : .defaultInk,
            highlightStyle: HighlightStyle(color: ScoreColor(red: 0.1, green: 0.45, blue: 1.0, alpha: 0.28))
        )
    }
}

