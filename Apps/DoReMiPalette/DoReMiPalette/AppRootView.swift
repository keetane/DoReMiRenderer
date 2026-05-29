import SwiftUI

enum PaletteSettingsKeys {
    static let noteColorVisible = "doremi.palette.noteColorVisible"
    static let staffColorVisible = "doremi.palette.staffColorVisible"
    static let keyboardVisible = "doremi.palette.keyboardVisible"
    static let keyboardColorVisible = "doremi.palette.keyboardColorVisible"
    static let keyboardColorPositionTop = "doremi.palette.keyboardColorPositionTop"
    static let keyboardLineNumberVisible = "doremi.palette.keyboardLineNumberVisible"
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

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage(PaletteSettingsKeys.noteColorVisible) private var noteColorVisible = true
    @AppStorage(PaletteSettingsKeys.staffColorVisible) private var staffColorVisible = false
    @AppStorage(PaletteSettingsKeys.keyboardVisible) private var keyboardVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardColorVisible) private var keyboardColorVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardColorPositionTop) private var keyboardColorPositionTop = true
    @AppStorage(PaletteSettingsKeys.keyboardLineNumberVisible) private var keyboardLineNumberVisible = false
    @AppStorage(PaletteSettingsKeys.currentNoteDisplayVisible) private var currentNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.nextNoteDisplayVisible) private var nextNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.measureNumbersVisible) private var measureNumbersVisible = true
    @AppStorage(PaletteSettingsKeys.zoomScale) private var zoomScale = 1.0
    @AppStorage(PaletteSettingsKeys.colorScheme) private var colorSchemeRawValue = PaletteColorScheme.educational.rawValue
    @AppStorage(PaletteSettingsKeys.scoreLayoutMode) private var scoreLayoutModeRawValue = PaletteScoreLayoutMode.horizontal.rawValue
    @AppStorage(PaletteSettingsKeys.transposeSemitones) private var transposeSemitones = 0
    @AppStorage(PaletteSettingsKeys.displayTransposeEnabled) private var displayTransposeEnabled = true
    @AppStorage(PaletteSettingsKeys.pitchClassColorEnabled) private var pitchClassColorEnabledRawValue = PalettePitchClassColorState.defaultEncodedValue
    @AppStorage(PaletteSettingsKeys.metronomeEnabled) private var metronomeEnabled = false
    @AppStorage(PaletteSettingsKeys.metronomeCompoundMode) private var metronomeCompoundModeRawValue = PaletteMetronomeCompoundMode.largeBeat.rawValue
    @AppStorage(PaletteSettingsKeys.metronomeClickSoundStyle) private var metronomeClickSoundStyleRawValue = PaletteMetronomeClickSoundStyle.classic.rawValue
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
