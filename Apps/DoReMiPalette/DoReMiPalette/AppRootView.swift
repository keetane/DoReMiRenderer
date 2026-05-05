import SwiftUI

struct AppRootView: View {
    @StateObject private var session = PaletteScoreSession()
    @AppStorage("doremi.palette.noteColorVisible") private var noteColorVisible = true
    @AppStorage("doremi.palette.staffColorVisible") private var staffColorVisible = true
    @AppStorage("doremi.palette.keyboardVisible") private var keyboardVisible = true
    @AppStorage("doremi.palette.zoomScale") private var zoomScale = 1.0

    var body: some View {
        ScorePracticeView(
            session: session,
            noteColorVisible: $noteColorVisible,
            staffColorVisible: $staffColorVisible,
            keyboardVisible: $keyboardVisible,
            zoomScale: $zoomScale
        )
        .task {
            session.loadBundledSampleIfNeeded()
        }
    }
}

