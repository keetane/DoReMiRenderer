import SwiftUI

enum PaletteSettingsKeys {
    static let noteColorVisible = "doremi.palette.noteColorVisible"
    static let staffColorVisible = "doremi.palette.staffColorVisible"
    static let keyboardVisible = "doremi.palette.keyboardVisible"
    static let keyboardColorVisible = "doremi.palette.keyboardColorVisible"
    static let keyboardColorPositionTop = "doremi.palette.keyboardColorPositionTop"
    static let currentNoteDisplayVisible = "doremi.palette.currentNoteDisplayVisible"
    static let nextNoteDisplayVisible = "doremi.palette.nextNoteDisplayVisible"
    static let measureNumbersVisible = "doremi.palette.measureNumbersVisible"
    static let zoomScale = "doremi.palette.zoomScale"
    static let colorScheme = "doremi.palette.colorScheme"
    static let scoreLayoutMode = "doremi.palette.scoreLayoutMode"
    static let transposeSemitones = "doremi.palette.transposeSemitones"
    static let displayTransposeEnabled = "doremi.palette.displayTransposeEnabled"
    static let pitchClassColorEnabled = "doremi.palette.pitchClassColorEnabled"
}

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage(PaletteSettingsKeys.noteColorVisible) private var noteColorVisible = true
    @AppStorage(PaletteSettingsKeys.staffColorVisible) private var staffColorVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardVisible) private var keyboardVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardColorVisible) private var keyboardColorVisible = false
    @AppStorage(PaletteSettingsKeys.keyboardColorPositionTop) private var keyboardColorPositionTop = true
    @AppStorage(PaletteSettingsKeys.currentNoteDisplayVisible) private var currentNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.nextNoteDisplayVisible) private var nextNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.measureNumbersVisible) private var measureNumbersVisible = true
    @AppStorage(PaletteSettingsKeys.zoomScale) private var zoomScale = 1.0
    @AppStorage(PaletteSettingsKeys.colorScheme) private var colorSchemeRawValue = PaletteColorScheme.educational.rawValue
    @AppStorage(PaletteSettingsKeys.scoreLayoutMode) private var scoreLayoutModeRawValue = PaletteScoreLayoutMode.horizontal.rawValue
    @AppStorage(PaletteSettingsKeys.transposeSemitones) private var transposeSemitones = 0
    @AppStorage(PaletteSettingsKeys.displayTransposeEnabled) private var displayTransposeEnabled = true
    @AppStorage(PaletteSettingsKeys.pitchClassColorEnabled) private var pitchClassColorEnabledRawValue = PalettePitchClassColorState.defaultEncodedValue

    var body: some View {
        ScorePracticeView(
            session: session,
            noteColorVisible: $noteColorVisible,
            staffColorVisible: $staffColorVisible,
            keyboardVisible: $keyboardVisible,
            keyboardColorVisible: $keyboardColorVisible,
            keyboardColorPositionTop: $keyboardColorPositionTop,
            currentNoteDisplayVisible: $currentNoteDisplayVisible,
            nextNoteDisplayVisible: $nextNoteDisplayVisible,
            measureNumbersVisible: $measureNumbersVisible,
            zoomScale: $zoomScale,
            colorSchemeRawValue: $colorSchemeRawValue,
            scoreLayoutModeRawValue: $scoreLayoutModeRawValue,
            transposeSemitones: $transposeSemitones,
            displayTransposeEnabled: $displayTransposeEnabled,
            pitchClassColorEnabledRawValue: $pitchClassColorEnabledRawValue
        )
        .task {
            if !displayTransposeEnabled {
                displayTransposeEnabled = true
            }
            session.setDisplayTransposeEnabled(true)
            session.setTransposeSemitones(transposeSemitones)
            session.loadBundledSampleIfNeeded()
        }
    }
}
