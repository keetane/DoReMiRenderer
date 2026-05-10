import SwiftUI

enum PaletteSettingsKeys {
    static let noteColorVisible = "doremi.palette.noteColorVisible"
    static let staffColorVisible = "doremi.palette.staffColorVisible"
    static let keyboardVisible = "doremi.palette.keyboardVisible"
    static let currentNoteDisplayVisible = "doremi.palette.currentNoteDisplayVisible"
    static let zoomScale = "doremi.palette.zoomScale"
    static let colorScheme = "doremi.palette.colorScheme"
}

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage(PaletteSettingsKeys.noteColorVisible) private var noteColorVisible = true
    @AppStorage(PaletteSettingsKeys.staffColorVisible) private var staffColorVisible = true
    @AppStorage(PaletteSettingsKeys.keyboardVisible) private var keyboardVisible = true
    @AppStorage(PaletteSettingsKeys.currentNoteDisplayVisible) private var currentNoteDisplayVisible = true
    @AppStorage(PaletteSettingsKeys.zoomScale) private var zoomScale = 1.0
    @AppStorage(PaletteSettingsKeys.colorScheme) private var colorSchemeRawValue = PaletteColorScheme.educational.rawValue

    var body: some View {
        ScorePracticeView(
            session: session,
            noteColorVisible: $noteColorVisible,
            staffColorVisible: $staffColorVisible,
            keyboardVisible: $keyboardVisible,
            currentNoteDisplayVisible: $currentNoteDisplayVisible,
            zoomScale: $zoomScale,
            colorSchemeRawValue: $colorSchemeRawValue
        )
        .task {
            session.loadBundledSampleIfNeeded()
        }
    }
}
