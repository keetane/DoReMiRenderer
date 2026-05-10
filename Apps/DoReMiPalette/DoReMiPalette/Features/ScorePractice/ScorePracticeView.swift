import DoReMiRendererKit
import SwiftUI
import UniformTypeIdentifiers

struct ScorePracticeView: View {
    @ObservedObject var session: PaletteScoreSession
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var currentNoteDisplayVisible: Bool
    @Binding var zoomScale: Double
    @Binding var colorSchemeRawValue: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsDiagnostics = false
    @State private var showsImporter = false
    @State private var showsLibrary = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlBar
                Divider()
                content
            }
            .navigationTitle("DoReMi Palette")
            .navigationBarTitleDisplayMode(isCompact ? .inline : .large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("ライブラリ", systemImage: "books.vertical") { showsLibrary = true }
                    Button("読み込み", systemImage: "folder") { showsImporter = true }
                    Button("診断", systemImage: diagnosticsIcon) { showsDiagnostics = true }
                    Button("設定", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.musicXML, .plainXML, .compressedMusicXML],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .sheet(isPresented: $showsDiagnostics) { DiagnosticsPanel(diagnostics: session.diagnostics) }
            .sheet(isPresented: $showsLibrary) { LibraryPanel(session: session, currentZoomScale: zoomScale) }
            .sheet(isPresented: $showsSettings) {
                PaletteSettingsView(
                    noteColorVisible: $noteColorVisible,
                    staffColorVisible: $staffColorVisible,
                    keyboardVisible: $keyboardVisible,
                    currentNoteDisplayVisible: $currentNoteDisplayVisible,
                    zoomScale: $zoomScale,
                    colorSchemeRawValue: $colorSchemeRawValue
                )
            }
        }
    }

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    playbackControls
                    Spacer(minLength: 16)
                    displayToggles
                }
                VStack(alignment: .leading, spacing: 8) {
                    playbackControls
                    displayToggles
                }
            }
            practiceControls
            statusAndZoomRow
        }
        .toggleStyle(.switch)
        .padding(.horizontal, isCompact ? 14 : 24)
        .padding(.vertical, isCompact ? 8 : 12)
    }

    private var playbackControls: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            Button(session.playbackState == .playing ? "Pause" : "Play", systemImage: session.playbackState == .playing ? "pause.fill" : "play.fill") {
                if session.playbackState == .playing { session.pause() } else { session.play() }
            }
            .disabled(session.playbackCursor.events.isEmpty)

            Button("Stop", systemImage: "stop.fill") { session.stop() }
                .disabled(session.playbackCursor.events.isEmpty || session.playbackState == .stopped)

            Button("Reset", systemImage: "backward.end.fill") { session.resetPlayback() }
                .disabled(session.playbackCursor.events.isEmpty || session.playbackCursor.index == 0)

            Button("Previous", systemImage: "chevron.left") { session.movePlaybackStep(by: -1) }
                .disabled(session.playbackCursor.events.isEmpty || session.playbackCursor.index == 0)

            Button("Next", systemImage: "chevron.right") { session.movePlaybackStep(by: 1) }
                .disabled(session.playbackCursor.events.isEmpty || session.playbackCursor.index >= session.playbackCursor.events.count - 1)

            Button(isCompact ? "Reload" : "Sample Reload", systemImage: "arrow.clockwise") { session.reloadSample() }
            Button("ライブラリ", systemImage: "books.vertical") { showsLibrary = true }
        }
        .buttonStyle(.borderless)
    }

    private var practiceControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                practiceToggle
                practiceStepButtons
                currentNoteDisplay
                palettePicker
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) { practiceToggle; practiceStepButtons }
                HStack(spacing: 10) { currentNoteDisplay; palettePicker }
            }
        }
    }

    private var practiceToggle: some View {
        Toggle("練習", isOn: practiceModeBinding)
            .toggleStyle(.button)
            .disabled(session.playbackCursor.events.isEmpty)
    }

    private var practiceStepButtons: some View {
        HStack(spacing: 8) {
            Button("戻る", systemImage: "chevron.left") { session.movePracticeStep(by: -1) }
                .disabled(!session.isPracticeModeEnabled || session.playbackCursor.index == 0)
            Button("次へ", systemImage: "chevron.right") { session.movePracticeStep(by: 1) }
                .disabled(!session.isPracticeModeEnabled || session.playbackCursor.events.isEmpty || session.playbackCursor.index >= session.playbackCursor.events.count - 1)
            Button("最初へ", systemImage: "backward.end") { session.resetPractice() }
                .disabled(!session.isPracticeModeEnabled || session.playbackCursor.index == 0)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var currentNoteDisplay: some View {
        Group {
            if currentNoteDisplayVisible, let loaded = session.loadedScore {
                currentNoteText(loaded: loaded)
            } else if currentNoteDisplayVisible {
                Text("現在の音: なし")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func currentNoteText(loaded: PaletteLoadedScore) -> some View {
        Group {
            let display = PracticeNoteNameFormatter.display(layout: loaded.layout, noteIDs: session.currentNoteIDs)
            let highlight = session.currentHighlightState
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentNotePrefix) \(display.summary)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !highlight.continuationNoteIDs.isEmpty {
                    Text("濃い色: 鳴る音 / 薄い色: タイで続く音")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var currentNotePrefix: String {
        session.isPracticeModeEnabled ? session.practiceStepSummary : "現在の音"
    }

    private var palettePicker: some View {
        Picker("色ルール", selection: $colorSchemeRawValue) {
            ForEach(PaletteColorScheme.allCases) { scheme in
                Text(scheme.displayName).tag(scheme.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: isCompact ? 220 : 240)
    }

    private var practiceModeBinding: Binding<Bool> {
        Binding(get: { session.isPracticeModeEnabled }, set: { session.setPracticeModeEnabled($0) })
    }

    private var displayToggles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: isCompact ? 10 : 16) {
                Toggle("Note Color", isOn: $noteColorVisible)
                Toggle("Staff Color", isOn: $staffColorVisible)
                Toggle("Keyboard", isOn: $keyboardVisible)
                Toggle("Current Note", isOn: $currentNoteDisplayVisible)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow { Toggle("Note Color", isOn: $noteColorVisible); Toggle("Staff Color", isOn: $staffColorVisible) }
                GridRow { Toggle("Keyboard", isOn: $keyboardVisible); Toggle("Current Note", isOn: $currentNoteDisplayVisible) }
            }
        }
    }

    private var statusAndZoomRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { statusText; Spacer(minLength: 16); tempoPicker; zoomPicker }
            VStack(alignment: .leading, spacing: 8) { statusText; HStack(spacing: 12) { tempoPicker; zoomPicker } }
        }
    }

    private var statusText: some View {
        HStack(spacing: 10) {
            Text(session.playbackState.displayText)
                .font(.callout.weight(.semibold))
                .foregroundStyle(session.playbackState == .playing ? .blue : .secondary)
            Text(session.playbackCursor.stepSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(session.lastHitSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let audioError = session.audioErrorMessage {
                Text(audioError)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var tempoPicker: some View {
        Picker("Tempo", selection: playbackTempoBinding) {
            Text("60").tag(60.0)
            Text("90").tag(90.0)
            Text("120").tag(120.0)
            Text("150").tag(150.0)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: isCompact ? 220 : 260)
        .accessibilityLabel("Tempo")
    }

    private var playbackTempoBinding: Binding<Double> {
        Binding(get: { session.playbackTempoBPM }, set: { session.setPlaybackTempoBPM($0) })
    }

    private var zoomPicker: some View {
        Picker("Zoom", selection: $zoomScale) {
            Text("1.0x").tag(1.0)
            Text("1.5x").tag(1.5)
            Text("2.0x").tag(2.0)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: isCompact ? 220 : 260)
    }

    @ViewBuilder
    private var content: some View {
        if let loaded = session.loadedScore {
            let highlight = session.currentHighlightState.visible(if: currentNoteDisplayVisible)
            VStack(spacing: 0) {
                ScoreCanvasView(
                    layout: loaded.layout,
                    score: loaded.score,
                    style: PaletteStyleFactory.makeStyle(
                        noteColorVisible: noteColorVisible,
                        staffColorVisible: staffColorVisible,
                        paletteKind: selectedColorScheme
                    ),
                    currentNoteIDs: highlight.attackNoteIDs,
                    continuationNoteIDs: highlight.continuationNoteIDs,
                    scale: CGFloat(zoomScale),
                    scrollAxes: [.horizontal, .vertical],
                    followsCurrentNote: currentNoteDisplayVisible,
                    onTap: session.handleTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))

                if keyboardVisible {
                    Divider()
                    KeyboardView(
                        layout: loaded.layout,
                        currentNoteIDs: highlight.scoreFollowNoteIDs,
                        highlightState: highlight,
                        palette: selectedColorScheme.palette
                    )
                        .frame(height: isCompact ? 96 : 132)
                        .padding(.horizontal, isCompact ? 10 : 16)
                        .padding(.vertical, isCompact ? 6 : 10)
                        .background(Color(.secondarySystemBackground))
                }
            }
        } else if session.isLoading {
            ProgressView("読み込み中")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "譜面を読み込めません",
                systemImage: "exclamationmark.triangle",
                description: Text(session.errorMessage ?? "Sample Reload または 読み込み を試してください。")
            )
        }
    }

    private var diagnosticsIcon: String {
        session.diagnostics.isEmpty ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            session.loadImportedFile(url: url, currentZoomScale: zoomScale)
        case .failure(let error):
            session.setImportError(error)
        }
    }

    private var selectedColorScheme: PaletteColorScheme {
        PaletteColorScheme.fromRawValue(colorSchemeRawValue)
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
}

private extension UTType {
    static let musicXML = UTType(filenameExtension: "musicxml", conformingTo: .xml) ?? .xml
    static let plainXML = UTType(filenameExtension: "xml", conformingTo: .xml) ?? .xml
    static let compressedMusicXML = UTType(filenameExtension: "mxl", conformingTo: .zip) ?? .zip
}
