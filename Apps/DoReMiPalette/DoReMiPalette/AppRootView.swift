import SwiftUI

enum PaletteSettingsKeys {
    static let noteColorVisible = "doremi.palette.noteColorVisible"
    static let staffColorVisible = "doremi.palette.staffColorVisible"
    static let keyboardVisible = "doremi.palette.keyboardVisible"
    static let currentNoteDisplayVisible = "doremi.palette.currentNoteDisplayVisible"
    static let nextNoteDisplayVisible = "doremi.palette.nextNoteDisplayVisible"
    static let zoomScale = "doremi.palette.zoomScale"
    static let colorScheme = "doremi.palette.colorScheme"
    static let scoreLayoutMode = "doremi.palette.scoreLayoutMode"
}

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage(PaletteSettingsKeys.noteColorVisible) private var noteColorVisible = true
    @AppStorage(PaletteSettingsKeys.staffColorVisible) private var staffColorVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardVisible) private var keyboardVisible = true
    @AppStorage(PaletteSettingsKeys.currentNoteDisplayVisible) private var currentNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.nextNoteDisplayVisible) private var nextNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.zoomScale) private var zoomScale = 1.0
    @AppStorage(PaletteSettingsKeys.colorScheme) private var colorSchemeRawValue = PaletteColorScheme.educational.rawValue
    @AppStorage(PaletteSettingsKeys.scoreLayoutMode) private var scoreLayoutModeRawValue = PaletteScoreLayoutMode.horizontal.rawValue

    var body: some View {
        ScorePracticeView(
            session: session,
            noteColorVisible: $noteColorVisible,
            staffColorVisible: $staffColorVisible,
            keyboardVisible: $keyboardVisible,
            currentNoteDisplayVisible: $currentNoteDisplayVisible,
            nextNoteDisplayVisible: $nextNoteDisplayVisible,
            zoomScale: $zoomScale,
            colorSchemeRawValue: $colorSchemeRawValue,
            scoreLayoutModeRawValue: $scoreLayoutModeRawValue
        )
        .task {
            session.loadBundledSampleIfNeeded()
        }
    }
}
