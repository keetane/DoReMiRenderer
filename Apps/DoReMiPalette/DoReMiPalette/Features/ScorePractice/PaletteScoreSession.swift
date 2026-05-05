import DoReMiRendererKit
import Foundation

@MainActor
final class PaletteScoreSession: ObservableObject {
    @Published private(set) var loadedScore: PaletteLoadedScore?
    @Published private(set) var diagnostics: [RendererDiagnostic] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published var playbackCursor = PalettePlaybackCursor(events: [])
    @Published var lastHitSummary = "音符または五線をタップしてください"

    private let loader = PaletteScoreLoader()
    private let bundledSampleName = "phase12_sample"

    var currentNoteIDs: Set<NoteID> {
        playbackCursor.currentNoteIDs
    }

    func loadBundledSampleIfNeeded(bundle: Bundle = .main) {
        guard loadedScore == nil, !isLoading else {
            return
        }
        loadBundledSample(bundle: bundle)
    }

    func loadBundledSample(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: bundledSampleName, withExtension: "musicxml") else {
            fail(PaletteImportError.bundledSampleMissing("\(bundledSampleName).musicxml"))
            return
        }
        loadFileData(from: url, sourceName: url.lastPathComponent, securityScoped: false)
    }

    func loadImportedFile(url: URL) {
        loadFileData(from: url, sourceName: url.lastPathComponent, securityScoped: true)
    }

    func reloadSample() {
        loadBundledSample()
    }

    func setImportError(_ error: Error) {
        fail(error)
    }

    func handleTap(_ result: HitTestResult) {
        let kindText = result.elements.first.map { "\($0.kind)" } ?? "なし"
        let noteText = result.nearestNoteID?.rawValue ?? "なし"
        lastHitSummary = "要素: \(kindText) / 音符: \(noteText)"
        if let noteID = result.nearestNoteID {
            playbackCursor.select(noteID: noteID)
        }
    }

    func movePlaybackStep(by offset: Int) {
        playbackCursor.move(by: offset)
        lastHitSummary = playbackCursor.stepSummary
    }

    private func loadFileData(from url: URL, sourceName: String, securityScoped: Bool) {
        isLoading = true
        errorMessage = nil

        let scoped = securityScoped && url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            try load(data: data, sourceName: sourceName)
        } catch {
            fail(error)
        }
    }

    func load(data: Data, sourceName: String) throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try loader.load(data: data, sourceName: sourceName)
            loadedScore = loaded
            diagnostics = loaded.diagnostics
            errorMessage = nil
            playbackCursor.reset(events: loaded.playbackEvents)
            lastHitSummary = "\(sourceName) を読み込みました"
        } catch {
            fail(error)
            throw error
        }
    }

    private func fail(_ error: Error) {
        isLoading = false
        if let reporting = error as? RendererDiagnosticReporting {
            diagnostics = [reporting.diagnostic]
            errorMessage = reporting.diagnostic.message
        } else {
            diagnostics = []
            errorMessage = error.localizedDescription
        }
    }
}
