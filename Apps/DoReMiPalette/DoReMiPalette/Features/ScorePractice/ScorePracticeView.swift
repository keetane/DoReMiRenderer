import DoReMiRendererKit
import SwiftUI
import UniformTypeIdentifiers

struct ScorePracticeView: View {
    @ObservedObject var session: PaletteScoreSession
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var zoomScale: Double

    @State private var showsDiagnostics = false
    @State private var showsImporter = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controlBar
                Divider()
                content
            }
            .navigationTitle("DoReMi Palette")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("読み込み", systemImage: "folder") {
                        showsImporter = true
                    }
                    Button("診断", systemImage: diagnosticsIcon) {
                        showsDiagnostics = true
                    }
                    Button("設定", systemImage: "gearshape") {
                        showsSettings = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.musicXML, .plainXML, .compressedMusicXML],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .sheet(isPresented: $showsDiagnostics) {
                DiagnosticsPanel(diagnostics: session.diagnostics)
            }
            .sheet(isPresented: $showsSettings) {
                PaletteSettingsView(
                    noteColorVisible: $noteColorVisible,
                    staffColorVisible: $staffColorVisible,
                    keyboardVisible: $keyboardVisible,
                    zoomScale: $zoomScale
                )
            }
        }
    }

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button("Previous", systemImage: "chevron.left") {
                    session.movePlaybackStep(by: -1)
                }
                .disabled(session.playbackCursor.events.isEmpty || session.playbackCursor.index == 0)

                Button("Next", systemImage: "chevron.right") {
                    session.movePlaybackStep(by: 1)
                }
                .disabled(
                    session.playbackCursor.events.isEmpty
                        || session.playbackCursor.index >= session.playbackCursor.events.count - 1
                )

                Button("Sample Reload", systemImage: "arrow.clockwise") {
                    session.reloadSample()
                }

                Spacer()

                Toggle("Note Color", isOn: $noteColorVisible)
                Toggle("Staff Color", isOn: $staffColorVisible)
                Toggle("Keyboard", isOn: $keyboardVisible)
            }

            HStack(spacing: 12) {
                Text(session.playbackCursor.stepSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(session.lastHitSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Picker("Zoom", selection: $zoomScale) {
                    Text("1.0x").tag(1.0)
                    Text("1.5x").tag(1.5)
                    Text("2.0x").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if let loaded = session.loadedScore {
            VStack(spacing: 0) {
                ScoreCanvasView(
                    layout: loaded.layout,
                    score: loaded.score,
                    style: PaletteStyleFactory.makeStyle(
                        noteColorVisible: noteColorVisible,
                        staffColorVisible: staffColorVisible
                    ),
                    currentNoteIDs: session.currentNoteIDs,
                    scale: CGFloat(zoomScale),
                    scrollAxes: [.horizontal, .vertical],
                    followsCurrentNote: true,
                    onTap: session.handleTap
                )
                .frame(maxWidth: .infinity, maxHeight: keyboardVisible ? .infinity : .infinity)
                .background(Color(.systemBackground))

                if keyboardVisible {
                    Divider()
                    KeyboardView(
                        layout: loaded.layout,
                        currentNoteIDs: session.currentNoteIDs,
                        palette: defaultEducationalPalette
                    )
                    .frame(height: 132)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
            guard let url = urls.first else {
                return
            }
            session.loadImportedFile(url: url)
        case .failure(let error):
            session.setImportError(error)
        }
    }
}

private extension UTType {
    static let musicXML = UTType(filenameExtension: "musicxml", conformingTo: .xml) ?? .xml
    static let plainXML = UTType(filenameExtension: "xml", conformingTo: .xml) ?? .xml
    static let compressedMusicXML = UTType(filenameExtension: "mxl", conformingTo: .zip) ?? .zip
}
