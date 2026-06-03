import SwiftUI

enum PaletteSettingsKeys {
    static let noteColorVisible = "doremi.palette.noteColorVisible"
    static let staffColorVisible = "doremi.palette.staffColorVisible"
    static let keyboardVisible = "doremi.palette.keyboardVisible"
    static let keyboardColorVisible = "doremi.palette.keyboardColorVisible"
    static let keyboardColorPositionTop = "doremi.palette.keyboardColorPositionTop"
    static let keyboardLineNumberVisible = "doremi.palette.keyboardLineNumberVisible"
    static let topToolbarVisible = "doremi.palette.topToolbarVisible"
    static let currentNoteDisplayVisible = "doremi.palette.currentNoteDisplayVisible"
    static let nextNoteDisplayVisible = "doremi.palette.nextNoteDisplayVisible"
    static let measureNumbersVisible = "doremi.palette.measureNumbersVisible"
    static let zoomScale = "doremi.palette.zoomScale"
    static let colorScheme = "doremi.palette.colorScheme"
    static let scoreLayoutMode = "doremi.palette.scoreLayoutMode"
    static let transposeSemitones = "doremi.palette.transposeSemitones"
    static let displayTransposeEnabled = "doremi.palette.displayTransposeEnabled"
    static let pitchClassColorEnabled = "doremi.palette.pitchClassColorEnabled"
    static let metronomeEnabled = "doremi.palette.metronomeEnabled"
    static let metronomeCompoundMode = "doremi.palette.metronomeCompoundMode"
    static let metronomeClickSoundStyle = "doremi.palette.metronomeClickSoundStyle"
    static let onboardingCompleted = "doremi.palette.onboardingCompleted"
}

enum PaletteSettingsDefaults {
    static let noteColorVisible = true
    static let staffColorVisible = false
    static let keyboardVisible = true
    static let keyboardColorVisible = true
    static let keyboardColorPositionTop = true
    static let keyboardLineNumberVisible = false
    static let topToolbarVisible = true
    static let currentNoteDisplayVisible = true
    static let nextNoteDisplayVisible = true
    static let measureNumbersVisible = true
    static let zoomScale = PaletteZoomScale.default
    static let colorSchemeRawValue = PaletteColorScheme.educational.rawValue
    static let scoreLayoutModeRawValue = PaletteScoreLayoutMode.a4.rawValue
    static let transposeSemitones = 0
    static let displayTransposeEnabled = true
    static let pitchClassColorEnabledRawValue = PalettePitchClassColorState.defaultEncodedValue
    static let metronomeEnabled = false
    static let metronomeCompoundModeRawValue = PaletteMetronomeCompoundMode.largeBeat.rawValue
    static let metronomeClickSoundStyleRawValue = PaletteMetronomeClickSoundStyle.classic.rawValue
}

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage(PaletteSettingsKeys.noteColorVisible) private var noteColorVisible = PaletteSettingsDefaults.noteColorVisible
    @AppStorage(PaletteSettingsKeys.staffColorVisible) private var staffColorVisible = PaletteSettingsDefaults.staffColorVisible
    @AppStorage(PaletteSettingsKeys.keyboardVisible) private var keyboardVisible = PaletteSettingsDefaults.keyboardVisible
    @AppStorage(PaletteSettingsKeys.keyboardColorVisible) private var keyboardColorVisible = PaletteSettingsDefaults.keyboardColorVisible
    @AppStorage(PaletteSettingsKeys.keyboardColorPositionTop) private var keyboardColorPositionTop = PaletteSettingsDefaults.keyboardColorPositionTop
    @AppStorage(PaletteSettingsKeys.keyboardLineNumberVisible) private var keyboardLineNumberVisible = PaletteSettingsDefaults.keyboardLineNumberVisible
    @AppStorage(PaletteSettingsKeys.topToolbarVisible) private var topToolbarVisible = PaletteSettingsDefaults.topToolbarVisible
    @AppStorage(PaletteSettingsKeys.currentNoteDisplayVisible) private var currentNoteDisplayVisible = PaletteSettingsDefaults.currentNoteDisplayVisible
    @AppStorage(PaletteSettingsKeys.nextNoteDisplayVisible) private var nextNoteDisplayVisible = PaletteSettingsDefaults.nextNoteDisplayVisible
    @AppStorage(PaletteSettingsKeys.measureNumbersVisible) private var measureNumbersVisible = PaletteSettingsDefaults.measureNumbersVisible
    @AppStorage(PaletteSettingsKeys.zoomScale) private var zoomScale = PaletteSettingsDefaults.zoomScale
    @AppStorage(PaletteSettingsKeys.colorScheme) private var colorSchemeRawValue = PaletteSettingsDefaults.colorSchemeRawValue
    @AppStorage(PaletteSettingsKeys.scoreLayoutMode) private var scoreLayoutModeRawValue = PaletteSettingsDefaults.scoreLayoutModeRawValue
    @AppStorage(PaletteSettingsKeys.transposeSemitones) private var transposeSemitones = PaletteSettingsDefaults.transposeSemitones
    @AppStorage(PaletteSettingsKeys.displayTransposeEnabled) private var displayTransposeEnabled = PaletteSettingsDefaults.displayTransposeEnabled
    @AppStorage(PaletteSettingsKeys.pitchClassColorEnabled) private var pitchClassColorEnabledRawValue = PaletteSettingsDefaults.pitchClassColorEnabledRawValue
    @AppStorage(PaletteSettingsKeys.metronomeEnabled) private var metronomeEnabled = PaletteSettingsDefaults.metronomeEnabled
    @AppStorage(PaletteSettingsKeys.metronomeCompoundMode) private var metronomeCompoundModeRawValue = PaletteSettingsDefaults.metronomeCompoundModeRawValue
    @AppStorage(PaletteSettingsKeys.metronomeClickSoundStyle) private var metronomeClickSoundStyleRawValue = PaletteSettingsDefaults.metronomeClickSoundStyleRawValue
    @AppStorage(PaletteSettingsKeys.onboardingCompleted) private var onboardingCompleted = false

    var body: some View {
        ScorePracticeView(
            session: session,
            noteColorVisible: $noteColorVisible,
            staffColorVisible: $staffColorVisible,
            keyboardVisible: $keyboardVisible,
            keyboardColorVisible: $keyboardColorVisible,
            keyboardColorPositionTop: $keyboardColorPositionTop,
            keyboardLineNumberVisible: $keyboardLineNumberVisible,
            topToolbarVisible: $topToolbarVisible,
            currentNoteDisplayVisible: $currentNoteDisplayVisible,
            nextNoteDisplayVisible: $nextNoteDisplayVisible,
            measureNumbersVisible: $measureNumbersVisible,
            zoomScale: $zoomScale,
            colorSchemeRawValue: $colorSchemeRawValue,
            scoreLayoutModeRawValue: $scoreLayoutModeRawValue,
            transposeSemitones: $transposeSemitones,
            displayTransposeEnabled: $displayTransposeEnabled,
            metronomeEnabled: $metronomeEnabled,
            metronomeCompoundModeRawValue: $metronomeCompoundModeRawValue,
            metronomeClickSoundStyleRawValue: $metronomeClickSoundStyleRawValue,
            pitchClassColorEnabledRawValue: $pitchClassColorEnabledRawValue,
            onboardingCompleted: $onboardingCompleted
        )
        .task {
            if !displayTransposeEnabled {
                displayTransposeEnabled = true
            }
            session.setDisplayTransposeEnabled(true)
            session.setTransposeSemitones(transposeSemitones)
            session.setMetronomeEnabled(metronomeEnabled)
            session.setMetronomeCompoundMode(PaletteMetronomeCompoundMode.fromRawValue(metronomeCompoundModeRawValue))
            session.setMetronomeClickSoundStyle(PaletteMetronomeClickSoundStyle.fromRawValue(metronomeClickSoundStyleRawValue))
            session.loadBundledSampleIfNeeded()
#if DEBUG
            await runDebugAutoplayIfRequested()
#endif
        }
    }

#if DEBUG
    @MainActor
    private func runDebugAutoplayIfRequested() async {
        let environment = ProcessInfo.processInfo.environment
        guard environment["DOREMI_AUTOPLAY_PLAYBACK"] == "1" else {
            return
        }
        if let requestedSample = environment["DOREMI_AUTOPLAY_SAMPLE_RESOURCE"],
           let sample = SampleScoreCatalog.default.samples.first(where: {
               $0.resourceName == requestedSample || $0.displayName == requestedSample
           }) {
            session.loadSample(sample)
        }
        let delay = Double(environment["DOREMI_AUTOPLAY_DELAY_SECONDS"] ?? "") ?? 1.0
        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
        if nanoseconds > 0 {
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
        session.play()
    }
#endif
}
