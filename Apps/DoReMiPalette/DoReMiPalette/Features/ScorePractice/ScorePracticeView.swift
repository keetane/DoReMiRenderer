import DoReMiRendererKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ScorePracticeView: View {
    @ObservedObject var session: PaletteScoreSession
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var currentNoteDisplayVisible: Bool
    @Binding var nextNoteDisplayVisible: Bool
    @Binding var zoomScale: Double
    @Binding var colorSchemeRawValue: String
    @Binding var scoreLayoutModeRawValue: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsDiagnostics = false
    @State private var showsImporter = false
    @State private var showsLibrary = false
    @State private var showsSettings = false
    @State private var printJob: PalettePrintJob?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlBar
                Divider()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("印刷", systemImage: "printer") { preparePrint() }
                        .disabled(session.loadedScore == nil)
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
            .background(PalettePrintPresenter(printJob: $printJob))
            .sheet(isPresented: $showsSettings) {
                PaletteSettingsView(
                    noteColorVisible: $noteColorVisible,
                    staffColorVisible: $staffColorVisible,
                    keyboardVisible: $keyboardVisible,
                    currentNoteDisplayVisible: $currentNoteDisplayVisible,
                    zoomScale: $zoomScale,
                    colorSchemeRawValue: $colorSchemeRawValue,
                    scoreLayoutModeRawValue: $scoreLayoutModeRawValue
                )
            }
            .onChange(of: scoreLayoutModeRawValue) { _, newValue in
                session.setScoreLayoutMode(PaletteScoreLayoutMode.fromRawValue(newValue))
            }
            .onChange(of: session.loadedScore?.sourceName) { _, _ in
                session.setScoreLayoutMode(selectedScoreLayoutMode)
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
            playbackOptionsRow
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

    private var playbackOptionsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                playbackDisplayControls
                Spacer(minLength: 16)
                currentNoteDisplay
            }
            VStack(alignment: .leading, spacing: 8) {
                playbackDisplayControls
                HStack {
                    Spacer(minLength: 0)
                    currentNoteDisplay
                }
            }
        }
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
            VStack(alignment: .trailing, spacing: 2) {
                Text("現在の音: \(display.summary)")
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

    private var displayToggles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: isCompact ? 10 : 16) {
                displayToggle("Note Color", isOn: $noteColorVisible)
                displayToggle("Staff Color", isOn: $staffColorVisible)
                displayToggle("Keyboard", isOn: $keyboardVisible)
                displayToggle("Current Note", isOn: $currentNoteDisplayVisible)
                displayToggle("Next Note", isOn: $nextNoteDisplayVisible)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow { displayToggle("Note Color", isOn: $noteColorVisible); displayToggle("Staff Color", isOn: $staffColorVisible) }
                GridRow { displayToggle("Keyboard", isOn: $keyboardVisible); displayToggle("Current Note", isOn: $currentNoteDisplayVisible) }
                GridRow { displayToggle("Next Note", isOn: $nextNoteDisplayVisible) }
            }
        }
    }

    private func displayToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
            Toggle(title, isOn: isOn)
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
    }

    private var layoutModePicker: some View {
        Picker("譜面レイアウト", selection: scoreLayoutModeBinding) {
            ForEach(PaletteScoreLayoutMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: isCompact ? 180 : 220)
    }

    private var tempoPicker: some View {
        HStack(spacing: 4) {
            Picker("Tempo", selection: playbackTempoPickerBinding) {
                ForEach(30...240, id: \.self) { bpm in
                    Text("\(bpm)").tag(bpm)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: isCompact ? 82 : 92, height: isCompact ? 88 : 96)
            .clipped()
            Text("BPM")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Tempo")
    }

    private var playbackTempoPickerBinding: Binding<Int> {
        Binding(
            get: { min(max(Int(session.playbackTempoBPM.rounded()), 30), 240) },
            set: { session.setPlaybackTempoBPM(Double($0)) }
        )
    }

    private var playbackDisplayControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                tempoPicker
                layoutModePicker
                zoomScalePicker
            }
            VStack(alignment: .leading, spacing: 8) {
                tempoPicker
                HStack(spacing: 10) {
                    layoutModePicker
                    zoomScalePicker
                }
            }
        }
    }

    private var zoomPicker: some View {
        HStack(spacing: 10) {
            layoutModePicker
            zoomScalePicker
        }
    }

    private var zoomScalePicker: some View {
        Group {
            Picker("Zoom", selection: $zoomScale) {
                Text("1.0x").tag(1.0)
                Text("1.5x").tag(1.5)
                Text("2.0x").tag(2.0)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: isCompact ? 220 : 260)
        }
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
                        nextMIDIPitches: nextNoteDisplayVisible ? session.nextNoteMIDIPitches : [],
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

    private func preparePrint() {
        guard let loaded = session.loadedScore else { return }
        let style = PaletteStyleFactory.makeStyle(
            noteColorVisible: noteColorVisible,
            staffColorVisible: staffColorVisible,
            paletteKind: selectedColorScheme
        )
        let printLayout = loaded.printLayout
        let pageRect = CGRect(origin: .zero, size: printLayout.canvasSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            ScoreGraphicsRenderer().draw(
                layout: printLayout,
                score: loaded.score,
                style: style,
                in: context.cgContext
            )
        }
        printJob = PalettePrintJob(
            jobName: loaded.sourceName,
            data: data
        )
    }

    private var selectedColorScheme: PaletteColorScheme {
        PaletteColorScheme.fromRawValue(colorSchemeRawValue)
    }

    private var selectedScoreLayoutMode: PaletteScoreLayoutMode {
        PaletteScoreLayoutMode.fromRawValue(scoreLayoutModeRawValue)
    }

    private var scoreLayoutModeBinding: Binding<PaletteScoreLayoutMode> {
        Binding(
            get: { selectedScoreLayoutMode },
            set: { mode in
                scoreLayoutModeRawValue = mode.rawValue
                session.setScoreLayoutMode(mode)
            }
        )
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
}

private struct PalettePrintJob: Identifiable, Equatable {
    let id = UUID()
    let jobName: String
    let data: Data
}

private struct PalettePrintPresenter: UIViewControllerRepresentable {
    @Binding var printJob: PalettePrintJob?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard let printJob, context.coordinator.presentedJobID != printJob.id else {
            return
        }
        context.coordinator.presentedJobID = printJob.id

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = printJob.jobName
        printController.printInfo = printInfo
        printController.printingItem = printJob.data
        printController.present(animated: true) { _, _, _ in
            DispatchQueue.main.async {
                self.printJob = nil
                context.coordinator.presentedJobID = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var presentedJobID: UUID?
    }
}

private extension UTType {
    static let musicXML = UTType(filenameExtension: "musicxml", conformingTo: .xml) ?? .xml
    static let plainXML = UTType(filenameExtension: "xml", conformingTo: .xml) ?? .xml
    static let compressedMusicXML = UTType(filenameExtension: "mxl", conformingTo: .zip) ?? .zip
}
