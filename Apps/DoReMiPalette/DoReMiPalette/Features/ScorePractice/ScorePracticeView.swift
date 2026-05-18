import DoReMiRendererKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ScorePracticeView: View {
    @ObservedObject var session: PaletteScoreSession
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var keyboardColorVisible: Bool
    @Binding var keyboardColorPositionTop: Bool
    @Binding var currentNoteDisplayVisible: Bool
    @Binding var nextNoteDisplayVisible: Bool
    @Binding var measureNumbersVisible: Bool
    @Binding var zoomScale: Double
    @Binding var colorSchemeRawValue: String
    @Binding var scoreLayoutModeRawValue: String
    @Binding var transposeSemitones: Int
    @Binding var displayTransposeEnabled: Bool
    @Binding var metronomeEnabled: Bool
    @Binding var metronomeCompoundModeRawValue: String
    @Binding var metronomeClickSoundStyleRawValue: String
    @Binding var pitchClassColorEnabledRawValue: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsDiagnostics = false
    @State private var showsImporter = false
    @State private var showsLibrary = false
    @State private var showsSettings = false
    @State private var showsPaletteEditor = false
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
                    Button("パレット", systemImage: "paintpalette") { showsPaletteEditor = true }
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
            .overlay(alignment: .bottom) {
                paletteEditorDrawer
            }
            .background(PalettePrintPresenter(printJob: $printJob))
            .sheet(isPresented: $showsSettings) {
                PaletteSettingsView(
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
                    metronomeEnabled: $metronomeEnabled,
                    metronomeCompoundModeRawValue: $metronomeCompoundModeRawValue,
                    metronomeClickSoundStyleRawValue: $metronomeClickSoundStyleRawValue,
                    writtenKeyPitchClass: session.currentKeyDisplay?.writtenPitchClass,
                    onTapTempo: { session.registerTapTempo() }
                )
            }
            .onAppear {
                displayTransposeEnabled = true
                syncTransposeSetting()
                applyPaletteEditorLaunchArgumentsIfNeeded()
            }
            .onChange(of: transposeSemitones) { _, _ in
                syncTransposeSetting()
            }
            .onChange(of: displayTransposeEnabled) { _, newValue in
                if !newValue {
                    displayTransposeEnabled = true
                }
                session.setDisplayTransposeEnabled(true)
            }
            .onChange(of: scoreLayoutModeRawValue) { _, newValue in
                session.setScoreLayoutMode(PaletteScoreLayoutMode.fromRawValue(newValue))
            }
            .onChange(of: session.loadedScore?.sourceName) { _, _ in
                session.setScoreLayoutMode(selectedScoreLayoutMode)
            }
            .onChange(of: metronomeEnabled) { _, newValue in
                session.setMetronomeEnabled(newValue)
            }
            .onChange(of: metronomeCompoundModeRawValue) { _, newValue in
                session.setMetronomeCompoundMode(PaletteMetronomeCompoundMode.fromRawValue(newValue))
            }
            .onChange(of: metronomeClickSoundStyleRawValue) { _, newValue in
                session.setMetronomeClickSoundStyle(PaletteMetronomeClickSoundStyle.fromRawValue(newValue))
            }
        }
    }

    @ViewBuilder
    private var paletteEditorDrawer: some View {
        if showsPaletteEditor {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showsPaletteEditor = false
                    }
                PaletteEditorView(
                    colorSchemeRawValue: $colorSchemeRawValue,
                    pitchClassColorEnabledRawValue: $pitchClassColorEnabledRawValue,
                    noteColorVisible: $noteColorVisible,
                    staffColorVisible: $staffColorVisible,
                    selectedKeyPitchClass: transposeKeyBinding,
                    keyboardColorPositionTop: keyboardColorPositionTop,
                    scaleTonicPitchClass: selectedMainKeyPitchClass,
                    onDone: { showsPaletteEditor = false }
                )
                .frame(maxWidth: .infinity)
                .frame(height: max(UIScreen.main.bounds.height * 0.54, 430))
                .background(Color(.systemBackground))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: -6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(10)
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
            } else if let keyDisplay = session.currentKeyDisplay {
                Text(keyDisplay.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func currentNoteText(loaded: PaletteLoadedScore) -> some View {
        Group {
            let display = PracticeNoteNameFormatter.display(
                layout: loaded.layout,
                noteIDs: session.currentNoteIDs,
                transposeSemitones: session.transposeSemitones,
                displayTransposeEnabled: session.displayTransposeEnabled
            )
            let highlight = session.currentHighlightState
            VStack(alignment: .trailing, spacing: 2) {
                if session.transposeSemitones == 0 || session.displayTransposeEnabled {
                    Text("現在の音: \(display.summary)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("表示: \(display.englishName) / \(display.solfegeName)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("再生: \(display.soundingEnglishName ?? display.englishName) / \(display.soundingSolfegeName ?? display.solfegeName) (\(PaletteTranspose.formatted(session.transposeSemitones)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if session.displayTransposeEnabled && session.transposeSemitones != 0,
                   let keyDisplay = session.currentKeyDisplay,
                   let displayKey = keyDisplay.displayKey {
                    Text("表示キー: \(displayKey)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let keyDisplay = session.currentKeyDisplay {
                    Text(keyDisplay.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
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
        HStack(spacing: 12) {
            displayToggle("Keyboard", isOn: $keyboardVisible)
            displayToggle("メトロノーム", isOn: $metronomeEnabled)
            Button("Tap", systemImage: "metronome") {
                session.registerTapTempo()
            }
            .buttonStyle(.borderless)
            .disabled(session.playbackCursor.events.isEmpty)
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
                transposeKeyPicker
            }
            VStack(alignment: .leading, spacing: 8) {
                tempoPicker
                HStack(spacing: 10) {
                    layoutModePicker
                    zoomScalePicker
                    transposeKeyPicker
                }
            }
        }
    }

    private var transposeKeyPicker: some View {
        HStack(spacing: 6) {
            Text("キー")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            PaletteKeyDrumPicker(selection: transposeKeyBinding, arrowEdge: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("移調キー \(PaletteTranspose.keyName(forPitchClass: transposeKeyBinding.wrappedValue))")
    }

    private var transposeKeyBinding: Binding<Int> {
        Binding(
            get: {
                selectedMainKeyPitchClass
            },
            set: { targetPitchClass in
                transposeSemitones = PaletteTranspose.semitones(
                    fromWrittenPitchClass: session.currentKeyDisplay?.writtenPitchClass,
                    toTargetPitchClass: targetPitchClass
                )
            }
        )
    }

    private var selectedMainKeyPitchClass: Int {
        PaletteTranspose.selectedTargetPitchClass(
            writtenPitchClass: session.currentKeyDisplay?.writtenPitchClass,
            transposeSemitones: transposeSemitones
        )
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
            let pitchColorState = PalettePitchClassColorState(encodedValue: pitchClassColorEnabledRawValue)
            VStack(spacing: 0) {
                scoreTitleBar(loaded)
                ScoreCanvasView(
                    layout: loaded.layout,
                    score: loaded.score,
                    style: PaletteStyleFactory.makeStyle(
                        noteColorVisible: noteColorVisible,
                        staffColorVisible: staffColorVisible,
                        paletteKind: selectedColorScheme,
                        pitchClassColorState: pitchColorState,
                        scaleTonicPitchClass: selectedMainKeyPitchClass,
                        measureNumbersVisible: measureNumbersVisible
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
                        palette: selectedColorScheme.palette,
                        pitchClassColorState: pitchColorState,
                        colorIdleKeys: keyboardColorVisible,
                        colorPositionTop: keyboardColorPositionTop,
                        scaleTonicPitchClass: selectedMainKeyPitchClass
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

    private func scoreTitleBar(_ loaded: PaletteLoadedScore) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
            Text(loaded.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, isCompact ? 14 : 24)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemBackground))
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
            paletteKind: selectedColorScheme,
            pitchClassColorState: PalettePitchClassColorState(encodedValue: pitchClassColorEnabledRawValue),
            scaleTonicPitchClass: selectedMainKeyPitchClass,
            measureNumbersVisible: measureNumbersVisible
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

    private func syncTransposeSetting() {
        if !displayTransposeEnabled {
            displayTransposeEnabled = true
        }
        let clamped = PaletteTranspose.clamped(transposeSemitones)
        if clamped != transposeSemitones {
            transposeSemitones = clamped
        }
        session.setDisplayTransposeEnabled(true)
        session.setTransposeSemitones(clamped)
    }

    private func applyPaletteEditorLaunchArgumentsIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--palette-preview-c-off") {
            pitchClassColorEnabledRawValue = PalettePitchClassColorState.allOn.toggled(0).encodedValue
        }
        if arguments.contains("--show-palette-editor") {
            DispatchQueue.main.async {
                showsPaletteEditor = true
            }
        }
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

private struct PaletteKeyDrumPicker: View {
    @Binding var selection: Int
    var arrowEdge: Edge = .bottom
    @State private var showsPicker = false

    var body: some View {
        Button {
            showsPicker = true
        } label: {
            Text(PaletteTranspose.keyName(forPitchClass: selection))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 62)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showsPicker, arrowEdge: arrowEdge) {
            PaletteKeyClockFace(selection: $selection) {
                showsPicker = false
            }
        }
    }
}

private struct PaletteKeyClockFace: View {
    @Binding var selection: Int
    let onSelect: () -> Void

    private let size: CGFloat = 320
    private let keyRadius: CGFloat = 126

    var body: some View {
        VStack(spacing: 12) {
            Text("キー")
                .font(.headline)
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                ForEach(Array(PaletteTranspose.keyOptions.enumerated()), id: \.element.id) { index, option in
                    keyButton(option)
                        .position(position(for: index))
                }
                VStack(spacing: 2) {
                    Text(PaletteTranspose.keyName(forPitchClass: selection))
                        .font(.title3.weight(.bold))
                    Text("選択中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
        }
        .padding(20)
        .frame(width: 380, height: 400)
    }

    private func keyButton(_ option: PaletteTranspose.KeyOption) -> some View {
        let isSelected = PaletteTranspose.normalizedPitchClass(selection) == option.pitchClass
        return Button {
            selection = option.pitchClass
            onSelect()
        } label: {
            VStack(spacing: 0) {
                Text(shortName(option.name))
                    .font(.callout.weight(.semibold))
                Text(PaletteTranspose.relativeMinorName(forMajorPitchClass: option.pitchClass))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : Color.secondary)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(width: 58, height: 44)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("キー \(option.name)、対応マイナー \(PaletteTranspose.relativeMinorName(forMajorPitchClass: option.pitchClass))")
    }

    private func position(for index: Int) -> CGPoint {
        let angle = (-90.0 + Double(index) * 30.0) * .pi / 180.0
        return CGPoint(
            x: size / 2 + CGFloat(cos(angle)) * keyRadius,
            y: size / 2 + CGFloat(sin(angle)) * keyRadius
        )
    }

    private func shortName(_ name: String) -> String {
        name.components(separatedBy: "/").first ?? name
    }
}

private struct PaletteEditorView: View {
    @Binding var colorSchemeRawValue: String
    @Binding var pitchClassColorEnabledRawValue: String
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var selectedKeyPitchClass: Int
    let keyboardColorPositionTop: Bool
    let scaleTonicPitchClass: Int?
    let onDone: () -> Void
    @State private var previewScore: PaletteLoadedScore?
    @State private var previewError: String?

    private var selectedColorScheme: PaletteColorScheme {
        PaletteColorScheme.fromRawValue(colorSchemeRawValue)
    }

    private var pitchColorState: PalettePitchClassColorState {
        PalettePitchClassColorState(encodedValue: pitchClassColorEnabledRawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("カラーパレット")
                    .font(.headline)
                Spacer()
                Button("完了") { onDone() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    pitchClassButtons
                    scorePreview
                    keyboardPreview
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            loadPreviewIfNeeded()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    pitchClassColorEnabledRawValue = pitchColorState.isStaffLineOnly
                        ? PalettePitchClassColorState.allOn.encodedValue
                        : PalettePitchClassColorState.staffLineOnly.encodedValue
                } label: {
                    Text(pitchColorState.isStaffLineOnly ? "ライン" : "全音")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(pitchColorState.isStaffLineOnly ? .blue : .gray)
                .accessibilityLabel(pitchColorState.isStaffLineOnly ? "ラインモード" : "全音モード")
                Button("全ON") {
                    pitchClassColorEnabledRawValue = PalettePitchClassColorState.allOn.encodedValue
                }
                Button("全OFF") {
                    pitchClassColorEnabledRawValue = PalettePitchClassColorState.allOff.encodedValue
                }
                Button("リセット") {
                    pitchClassColorEnabledRawValue = PalettePitchClassColorState.defaultEncodedValue
                }
                HStack(spacing: 6) {
                    Text("キー")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    PaletteKeyDrumPicker(selection: $selectedKeyPitchClass)
                }
                .accessibilityLabel("カラーパレットのキー \(PaletteTranspose.keyName(forPitchClass: selectedKeyPitchClass))")
                Spacer(minLength: 0)
                Label("MVPでは12 pitch class単位", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
        }
    }

    private var pitchClassButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("音ごとの色")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 64), spacing: 8), count: 7), spacing: 8) {
                ForEach(PalettePitchClassColorState.paletteButtonPitchClasses, id: \.self) { pitchClass in
                    pitchClassButton(pitchClass)
                }
            }
        }
    }

    private func pitchClassButton(_ pitchClass: Int) -> some View {
        let isEnabled = pitchColorState.isEnabledForPaletteButton(pitchClass)
        let isMIDISpecificMode = pitchColorState.enabledMIDINotes != nil
        let color = color(for: pitchClass)
        return Button {
            pitchClassColorEnabledRawValue = pitchColorState.toggledPaletteButton(pitchClass).encodedValue
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isEnabled ? color : Color(.systemGray4))
                    .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                    .frame(width: 14, height: 14)
                Text(PalettePitchClassColorState.label(for: pitchClass))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(isMIDISpecificMode)
        .opacity(isMIDISpecificMode ? 0.45 : (isEnabled ? 1 : 0.62))
        .accessibilityLabel("\(PalettePitchClassColorState.label(for: pitchClass)) \(isEnabled ? "ON" : "OFF")")
    }

    @ViewBuilder
    private var keyboardPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let previewScore {
                KeyboardView(
                    layout: previewScore.layout,
                    currentNoteIDs: [],
                    range: 36...84,
                    palette: selectedColorScheme.palette,
                    pitchClassColorState: pitchColorState,
                    colorIdleKeys: true,
                    colorPositionTop: keyboardColorPositionTop,
                    scaleTonicPitchClass: scaleTonicPitchClass
                )
                .frame(height: 120)
                .padding(.vertical, 6)
            } else if let previewError {
                Text(previewError)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var scorePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                PaletteScorePreviewView(
                    palette: selectedColorScheme.palette,
                    pitchClassColorState: pitchColorState,
                    noteColorVisible: noteColorVisible,
                    staffColorVisible: staffColorVisible,
                    scaleTonicPitchClass: scaleTonicPitchClass
                )
                .frame(width: 980, height: 210)
                .accessibilityIdentifier("palette-score-preview-c2-c6")
            }
            .frame(height: 220)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func color(for pitchClass: Int) -> Color {
        let palette = selectedColorScheme.palette
        let scoreColor: ScoreColor
        switch PalettePitchClassColorState.normalizedPitchClass(pitchClass) {
        case 0, 1: scoreColor = palette.c
        case 2, 3: scoreColor = palette.d
        case 4: scoreColor = palette.e
        case 5, 6: scoreColor = palette.f
        case 7, 8: scoreColor = palette.g
        case 9, 10: scoreColor = palette.a
        default: scoreColor = palette.b
        }
        return Color(.sRGB, red: scoreColor.red, green: scoreColor.green, blue: scoreColor.blue, opacity: 1)
    }

    private func loadPreviewIfNeeded() {
        guard previewScore == nil, previewError == nil else { return }
        do {
            previewScore = try PaletteScoreLoader().load(
                data: PalettePreviewScore.musicXMLData,
                sourceName: "palette-preview-c2-c6.musicxml"
            )
        } catch {
            previewError = "プレビューを読み込めません: \(error.localizedDescription)"
        }
    }
}

private struct PaletteScorePreviewView: View {
    let palette: ScaleColorPalette
    let pitchClassColorState: PalettePitchClassColorState
    let noteColorVisible: Bool
    let staffColorVisible: Bool
    let scaleTonicPitchClass: Int?

    private let whiteKeyMIDIs: [Int] = Array(36...84).filter { midi in
        [0, 2, 4, 5, 7, 9, 11].contains(PalettePitchClassColorState.normalizedPitchClass(midi))
    }

    var body: some View {
        Canvas { context, size in
            let topStaffY: CGFloat = 42
            let bottomStaffY: CGFloat = 132
            let lineSpacing: CGFloat = 10
            let leftPadding: CGFloat = 26
            let rightPadding: CGFloat = 26
            let usableWidth = max(size.width - leftPadding - rightPadding, 1)
            let stepX = usableWidth / CGFloat(max(whiteKeyMIDIs.count - 1, 1))
            drawStaff(
                context: &context,
                startY: topStaffY,
                width: size.width,
                lineSpacing: lineSpacing,
                lineMIDIs: [77, 74, 71, 67, 64]
            )
            drawStaff(
                context: &context,
                startY: bottomStaffY,
                width: size.width,
                lineSpacing: lineSpacing,
                lineMIDIs: [57, 53, 50, 47, 43]
            )
            drawLedgerLines(
                context: &context,
                leftPadding: leftPadding,
                stepX: stepX,
                topStaffY: topStaffY,
                bottomStaffY: bottomStaffY,
                lineSpacing: lineSpacing
            )

            for (index, midi) in whiteKeyMIDIs.enumerated() {
                let x = leftPadding + CGFloat(index) * stepX
                let staffStartY = midi < 60 ? bottomStaffY : topStaffY
                let y = yPosition(midi: midi, staffStartY: staffStartY, lineSpacing: lineSpacing)
                let color = noteColor(midi: midi)
                let rect = CGRect(x: x - 6.8, y: y - 4.8, width: 13.6, height: 9.6)
                context.fill(Path(ellipseIn: rect), with: .color(color))
                context.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.2)), lineWidth: 0.8)
            }
        }
    }

    private func drawStaff(context: inout GraphicsContext, startY: CGFloat, width: CGFloat, lineSpacing: CGFloat, lineMIDIs: [Int]) {
        for line in 0..<5 {
            let y = startY + CGFloat(line) * lineSpacing
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            let color = staffColorVisible ? noteColor(midi: lineMIDIs[line]) : Color(.systemGray3)
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
    }

    private func drawLedgerLines(
        context: inout GraphicsContext,
        leftPadding: CGFloat,
        stepX: CGFloat,
        topStaffY: CGFloat,
        bottomStaffY: CGFloat,
        lineSpacing: CGFloat
    ) {
        for midi in [36, 40, 60, 81, 84] {
            guard let index = whiteKeyMIDIs.firstIndex(of: midi) else { continue }
            let x = leftPadding + CGFloat(index) * stepX
            let staffStartY = midi < 60 ? bottomStaffY : topStaffY
            let y = yPosition(midi: midi, staffStartY: staffStartY, lineSpacing: lineSpacing)
            var path = Path()
            path.move(to: CGPoint(x: x - 12, y: y))
            path.addLine(to: CGPoint(x: x + 12, y: y))
            let color = staffColorVisible ? noteColor(midi: midi) : Color(.systemGray3)
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
    }

    private func yPosition(midi: Int, staffStartY: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        let referenceMidi = midi < 60 ? 50 : 71 // D3 / B4 middle staff lines for bass / treble preview.
        let whiteStepDelta = diatonicIndex(midi: midi) - diatonicIndex(midi: referenceMidi)
        let middleLineY = staffStartY + lineSpacing * 2
        return middleLineY - CGFloat(whiteStepDelta) * (lineSpacing / 2)
    }

    private func diatonicIndex(midi: Int) -> Int {
        let octave = midi / 12 - 1
        let pitchClass = PalettePitchClassColorState.normalizedPitchClass(midi)
        let degree: Int
        switch pitchClass {
        case 0, 1: degree = 0
        case 2, 3: degree = 1
        case 4: degree = 2
        case 5, 6: degree = 3
        case 7, 8: degree = 4
        case 9, 10: degree = 5
        default: degree = 6
        }
        return octave * 7 + degree
    }

    private func noteColor(midi: Int) -> Color {
        guard noteColorVisible else { return Color(.label) }
        if pitchClassColorState.enabledMIDINotes != nil {
            guard pitchClassColorState.isEnabledForStaffLine(midi: midi, scaleTonicPitchClass: scaleTonicPitchClass) else {
                return Color(.label)
            }
            if let scaleTonicPitchClass {
                return color(for: KeyboardScaleColor.majorScalePitchClassForStaffPosition(
                    midi: midi,
                    tonicPitchClass: scaleTonicPitchClass
                ))
            }
            return color(for: KeyboardScaleColor.basicPitchClass(midi: midi))
        }
        if let scaleTonicPitchClass {
            let scalePitchClass = KeyboardScaleColor.majorScalePitchClassForStaffPosition(
                midi: midi,
                tonicPitchClass: scaleTonicPitchClass
            )
            let enabledPitchClass = KeyboardScaleColor.enabledPitchClass(
                midi: midi,
                scaleTonicPitchClass: scaleTonicPitchClass
            ) ?? PalettePitchClassColorState.pitchClass(for: scalePitchClass)
            guard pitchClassColorState.isEnabled(pitchClass: enabledPitchClass) else {
                return Color(.label)
            }
            return color(for: scalePitchClass)
        }
        let pitchClass = PalettePitchClassColorState.normalizedPitchClass(midi)
        guard pitchClassColorState.isEnabled(pitchClass: pitchClass) else { return Color(.label) }
        return color(for: KeyboardScaleColor.basicPitchClass(midi: midi))
    }

    private func color(for pitchClass: PitchClass) -> Color {
        let scoreColor = palette.color(for: pitchClass)
        return Color(.sRGB, red: scoreColor.red, green: scoreColor.green, blue: scoreColor.blue, opacity: 1)
    }
}

enum PalettePreviewScore {
    static var musicXMLData: Data {
        Data(musicXML.utf8)
    }

    static let midiRange = 36...84

    private static var musicXML: String {
        let notes = midiRange.enumerated().map { index, midi in
            noteXML(midi: midi)
        }
        let measures = stride(from: 0, to: notes.count, by: 8).enumerated().map { index, offset in
            let body = notes[offset..<min(offset + 8, notes.count)].joined(separator: "\n")
            return """
              <measure number="\(index + 1)">
                \(index == 0 ? attributesXML : "")
            \(body)
              </measure>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="3.1">
          <identification>
            <creator type="composer">DoReMi Palette generated palette preview</creator>
            <rights>Generated in-app preview fixture for pitch class color QA.</rights>
          </identification>
          <part-list>
            <score-part id="P1"><part-name>Palette Preview</part-name></score-part>
          </part-list>
          <part id="P1">
        \(measures)
          </part>
        </score-partwise>
        """
    }

    private static let attributesXML = """
        <attributes>
          <divisions>2</divisions>
          <key><fifths>0</fifths></key>
          <time><beats>4</beats><beat-type>4</beat-type></time>
          <staves>2</staves>
          <clef number="1"><sign>G</sign><line>2</line></clef>
          <clef number="2"><sign>F</sign><line>4</line></clef>
        </attributes>
    """

    private static func noteXML(midi: Int) -> String {
        let spelling = spelling(for: midi)
        let staff = midi < 60 ? 2 : 1
        return """
                <note>
                  <pitch><step>\(spelling.step)</step>\(spelling.alter.map { "<alter>\($0)</alter>" } ?? "")<octave>\(spelling.octave)</octave></pitch>
                  <duration>1</duration>
                  <voice>1</voice>
                  <type>eighth</type>
                  <staff>\(staff)</staff>
                </note>
        """
    }

    private static func spelling(for midi: Int) -> (step: String, alter: Int?, octave: Int) {
        let pitchClass = PalettePitchClassColorState.normalizedPitchClass(midi)
        let octave = midi / 12 - 1
        switch pitchClass {
        case 0: return ("C", nil, octave)
        case 1: return ("C", 1, octave)
        case 2: return ("D", nil, octave)
        case 3: return ("D", 1, octave)
        case 4: return ("E", nil, octave)
        case 5: return ("F", nil, octave)
        case 6: return ("F", 1, octave)
        case 7: return ("G", nil, octave)
        case 8: return ("G", 1, octave)
        case 9: return ("A", nil, octave)
        case 10: return ("A", 1, octave)
        default: return ("B", nil, octave)
        }
    }
}
