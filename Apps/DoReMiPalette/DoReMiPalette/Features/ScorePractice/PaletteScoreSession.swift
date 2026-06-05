import DoReMiRendererKit
import Foundation

@MainActor
final class PaletteScoreSession: ObservableObject {
    @Published private(set) var loadedScore: PaletteLoadedScore?
    @Published private(set) var diagnostics: [RendererDiagnostic] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var libraryItems: [LibraryItem] = []
    @Published private(set) var playbackState: PalettePlaybackState = .stopped
    @Published private(set) var audioErrorMessage: String?
    @Published private(set) var playbackTempoBPM: Double
    @Published private(set) var transposeSemitones: Int
    @Published private(set) var metronomeEnabled: Bool
    @Published private(set) var metronomeCompoundMode: PaletteMetronomeCompoundMode
    @Published private(set) var metronomeClickSoundStyle: PaletteMetronomeClickSoundStyle
    @Published private(set) var displayTransposeEnabled: Bool = true
    @Published private(set) var practiceSession = PalettePracticeSession()
    @Published var playbackCursor = PalettePlaybackCursor(events: [])
    @Published var lastHitSummary = "音符または五線をタップしてください"

    private let loader: PaletteScoreLoader
    private let sampleCatalog: SampleScoreCatalog
    private let libraryStore: LibraryStore
    private let libraryFileResolver: LibraryFileResolving
    private let playbackRuntime: PalettePlaybackRuntime
    private var libraryCollection: LibraryCollection
    private var pendingPlaybackCursorIndex: Int?
    private var playbackCursorUpdateTask: Task<Void, Never>?
    private var preferredScoreLayoutMode: PaletteScoreLayoutMode = .a4
    private static let playbackCursorUpdateIntervalNanoseconds: UInt64 = 180_000_000

    init(
        loader: PaletteScoreLoader = PaletteScoreLoader(),
        sampleCatalog: SampleScoreCatalog = .default,
        libraryStore: LibraryStore = .default,
        libraryFileResolver: LibraryFileResolving = SecurityScopedLibraryFileResolver(),
        playbackRuntime: PalettePlaybackRuntime = PalettePlaybackRuntime()
    ) {
        self.loader = loader
        self.sampleCatalog = sampleCatalog
        self.libraryStore = libraryStore
        self.libraryFileResolver = libraryFileResolver
        self.playbackRuntime = playbackRuntime
        self.playbackTempoBPM = playbackRuntime.tempoBPM
        self.transposeSemitones = playbackRuntime.transposeSemitones
        self.metronomeEnabled = playbackRuntime.metronomeEnabled
        self.metronomeCompoundMode = playbackRuntime.metronomeCompoundMode
        self.metronomeClickSoundStyle = playbackRuntime.metronomeClickSoundStyle
        self.libraryCollection = LibraryCollection(
            sampleItems: sampleCatalog.libraryItems(),
            importedItems: libraryStore.loadImportedItems()
        )
        self.libraryItems = libraryCollection.allItems
        bindPlaybackRuntime()
    }

    var currentNoteIDs: Set<NoteID> {
        practiceSession.isEnabled ? practiceSession.currentNoteIDs : playbackCursor.currentNoteIDs
    }

    var currentPlaybackEvent: PlaybackEvent? {
        practiceSession.isEnabled ? practiceSession.currentEvent : playbackCursor.currentEvent
    }

    var nextFollowNoteIDs: Set<NoteID> {
        let event = practiceSession.isEnabled ? practiceSession.nextPitchedEvent : playbackCursor.nextPitchedEvent
        return Set(event?.noteIDs ?? [])
    }

    var continuousFollowNoteIDs: [NoteID] {
        guard playbackState == .playing,
              !practiceSession.isEnabled else {
            return []
        }
        return playbackCursor
            .upcomingPitchedEvents(limit: 16)
            .flatMap(\.noteIDs)
    }

    var currentFollowAnimationDuration: TimeInterval? {
        guard playbackState == .playing,
              !practiceSession.isEnabled,
              let event = playbackCursor.currentEvent else {
            return nil
        }
        return playbackRuntime.eventDurationSeconds(for: event)
    }

    var continuousFollowPlaybackDuration: TimeInterval? {
        guard playbackState == .playing,
              !practiceSession.isEnabled else {
            return nil
        }
        let duration = playbackRuntime.totalSchedulingDurationSeconds()
        return duration.isFinite && duration > 0 ? duration : nil
    }

    func currentTrackPlaybackTimeSeconds() -> TimeInterval {
        playbackRuntime.currentPlaybackElapsedSecondsForVisualTimeline()
    }

    func trackPlaybackStartTimes() -> [TimeInterval] {
        playbackRuntime.visualTimelineStartTimesForTrack()
    }

    func trackPlaybackDurations() -> [TimeInterval] {
        playbackRuntime.visualTimelineDurationsForTrack()
    }

    func trackPlaybackPitchDurations() -> [[Int: TimeInterval]] {
        playbackRuntime.visualTimelinePitchDurationsForTrack()
    }

    var totalMeasureCount: Int {
        loadedScore?.score.parts.first?.measures.count ?? 0
    }

    var currentMeasureNumber: Int? {
        guard totalMeasureCount > 0 else {
            return nil
        }
        if let measureID = currentPlaybackEvent?.measureID,
           let number = measureNumber(for: measureID) {
            return number
        }
        for noteID in currentNoteIDs {
            if let measureID = loadedScore?.layout.noteLayout(for: noteID)?.measureID,
               let number = measureNumber(for: measureID) {
                return number
            }
        }
        return min(max(playbackCursor.index + 1, 1), totalMeasureCount)
    }

    var measureProgressText: String? {
        guard totalMeasureCount > 0 else {
            return nil
        }
        let current = currentMeasureNumber ?? 1
        return "\(current) / \(totalMeasureCount)"
    }

    var currentHighlightState: CurrentNoteHighlightState {
        guard let layout = loadedScore?.layout else {
            return .empty
        }
        return CurrentNoteHighlightState.make(
            event: currentPlaybackEvent,
            layout: layout,
            transposeSemitones: transposeSemitones,
            displayTransposeEnabled: displayTransposeEnabled
        )
    }

    var nextNoteMIDIPitches: Set<Int> {
        let event = practiceSession.isEnabled ? practiceSession.nextPitchedEvent : playbackCursor.nextPitchedEvent
        return KeyboardPitchMapper.transposedMIDINumbers(event?.midiPitches ?? [], by: transposeSemitones)
    }

    var currentKeyDisplay: PaletteKeyDisplay? {
        guard let score = loadedScore?.score else {
            return nil
        }
        return PaletteKeyDisplay.make(
            score: score,
            transposeSemitones: transposeSemitones,
            displayTransposeEnabled: displayTransposeEnabled
        )
    }

    var isPracticeModeEnabled: Bool {
        practiceSession.isEnabled
    }

    var practiceStepSummary: String {
        practiceSession.stepSummary
    }

    var sampleLibraryItems: [LibraryItem] {
        libraryCollection.sampleItems
    }

    var recentImportedItems: [LibraryItem] {
        libraryCollection.importedItems.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    func loadBundledSampleIfNeeded(bundle: Bundle = .main) {
        guard loadedScore == nil, !isLoading else {
            return
        }
        loadBundledSample(bundle: bundle)
    }

    func loadBundledSample(bundle: Bundle = .main) {
        guard let sample = sampleCatalog.defaultSample else {
            fail(PaletteImportError.bundledSampleMissing("sample catalog"))
            return
        }
        loadSample(sample, bundle: bundle)
    }

    func loadSample(_ sample: SampleScoreItem, bundle: Bundle = .main) {
        guard let url = sample.url(in: bundle) else {
            fail(PaletteImportError.bundledSampleMissing("\(sample.resourceName).\(sample.fileExtension)"))
            return
        }
        loadFileData(
            from: url,
            sourceName: url.lastPathComponent,
            securityScoped: false,
            displayTitle: sample.displayName
        )
    }

    func loadImportedFile(url: URL, currentZoomScale: Double? = nil) {
        loadFileData(
            from: url,
            sourceName: url.lastPathComponent,
            securityScoped: true,
            libraryImportURL: url,
            currentZoomScale: currentZoomScale,
            bookmarkData: makeBookmarkData(for: url)
        )
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
        if let noteID = result.nearestNoteID {
            playbackRuntime.select(noteID: noteID)
            playbackCursor.select(noteID: noteID)
            if practiceSession.isEnabled {
                practiceSession.select(noteID: noteID)
                playbackCursor.setIndex(practiceSession.index)
            }
        }
        lastHitSummary = "要素: \(kindText) / 音符: \(noteText)"
    }

    func movePlaybackStep(by offset: Int) {
        if practiceSession.isEnabled {
            movePracticeStep(by: offset)
        } else {
            guard !playbackCursor.events.isEmpty else {
                playbackRuntime.move(to: 0)
                lastHitSummary = playbackCursor.stepSummary
                return
            }
            let targetIndex = min(max(playbackCursor.index + offset, 0), playbackCursor.events.count - 1)
            playbackCursor.setIndex(targetIndex)
            playbackRuntime.move(to: targetIndex)
            lastHitSummary = playbackCursor.stepSummary
        }
    }

    func play() {
        if practiceSession.isEnabled {
            setPracticeModeEnabled(false)
        }
        playbackRuntime.play()
    }

    func pause() {
        playbackRuntime.pause()
    }

    func stop() {
        playbackRuntime.stop()
    }

    func resetPlayback() {
        playbackRuntime.reset()
        lastHitSummary = playbackCursor.stepSummary
    }

    func setPlaybackTempoBPM(_ tempo: Double) {
        playbackRuntime.setTempoBPM(tempo)
        playbackTempoBPM = playbackRuntime.tempoBPM
    }

    func setMetronomeEnabled(_ enabled: Bool) {
        playbackRuntime.setMetronomeEnabled(enabled)
        metronomeEnabled = playbackRuntime.metronomeEnabled
    }

    func setMetronomeCompoundMode(_ mode: PaletteMetronomeCompoundMode) {
        playbackRuntime.setMetronomeCompoundMode(mode)
        metronomeCompoundMode = playbackRuntime.metronomeCompoundMode
    }

    func setMetronomeClickSoundStyle(_ style: PaletteMetronomeClickSoundStyle) {
        playbackRuntime.setMetronomeClickSoundStyle(style)
        metronomeClickSoundStyle = playbackRuntime.metronomeClickSoundStyle
    }

    @discardableResult
    func registerTapTempo() -> Double? {
        let tempo = playbackRuntime.registerTapTempo()
        playbackTempoBPM = playbackRuntime.tempoBPM
        return tempo
    }

    func setTransposeSemitones(_ semitones: Int) {
        let clamped = PaletteTranspose.clamped(semitones)
        playbackRuntime.setTransposeSemitones(clamped)
        transposeSemitones = playbackRuntime.transposeSemitones
        relayoutForDisplayTransposeIfNeeded()
    }

    func resetTranspose() {
        setTransposeSemitones(0)
    }

    func setDisplayTransposeEnabled(_ enabled: Bool) {
        guard displayTransposeEnabled != enabled else {
            return
        }
        displayTransposeEnabled = enabled
        relayoutForDisplayTransposeIfNeeded(force: true)
    }

    func setScoreLayoutMode(_ mode: PaletteScoreLayoutMode) {
        preferredScoreLayoutMode = mode
        guard var loadedScore, loadedScore.layoutMode != mode else {
            return
        }
        loadedScore.layoutMode = mode
        self.loadedScore = loadedScore
    }

    func setPracticeModeEnabled(_ enabled: Bool) {
        if enabled {
            stop()
            practiceSession.setEnabled(true, startingAt: playbackCursor.index)
            playbackCursor.setIndex(practiceSession.index)
            playbackRuntime.move(to: practiceSession.index)
            lastHitSummary = practiceSession.stepSummary
        } else {
            practiceSession.setEnabled(false)
            lastHitSummary = playbackCursor.stepSummary
        }
    }

    func movePracticeStep(by offset: Int) {
        practiceSession.move(by: offset)
        playbackCursor.setIndex(practiceSession.index)
        playbackRuntime.move(to: practiceSession.index)
        lastHitSummary = practiceSession.stepSummary
    }

    func resetPractice() {
        practiceSession.reset()
        playbackCursor.setIndex(practiceSession.index)
        playbackRuntime.move(to: practiceSession.index)
        lastHitSummary = practiceSession.stepSummary
    }

    @discardableResult
    func jumpToMeasure(_ measureNumber: Int) -> MeasureJumpResult {
        guard totalMeasureCount > 0 else {
            return .failure("小節情報がありません")
        }
        guard (1...totalMeasureCount).contains(measureNumber) else {
            return .failure("1〜\(totalMeasureCount) の小節番号を入力してください")
        }
        guard let targetIndex = targetEventIndex(forMeasureNumber: measureNumber) else {
            return .failure("\(measureNumber) 小節目に移動できる音符がありません")
        }

        if playbackState == .playing {
            pause()
        }
        if practiceSession.isEnabled {
            practiceSession.setIndex(targetIndex)
        }
        playbackCursor.setIndex(targetIndex)
        playbackRuntime.move(to: targetIndex)
        lastHitSummary = "\(measureNumber) 小節目へ移動しました"
        return .success
    }

    func openLibraryItem(_ item: LibraryItem, bundle: Bundle = .main, currentZoomScale: Double? = nil) {
        switch item.sourceType {
        case .sample:
            guard let sample = sampleCatalog.samples.first(where: { $0.sourceIdentifier == item.sourceIdentifier }) else {
                fail(PaletteImportError.unsupportedLibraryItem(item.displayName))
                return
            }
            loadSample(sample, bundle: bundle)
        case .imported:
            do {
                let resolved = try libraryFileResolver.resolveFile(for: item)
                loadFileData(
                    from: resolved.url,
                    sourceName: resolved.url.lastPathComponent,
                    securityScoped: resolved.securityScoped,
                    libraryImportURL: resolved.url,
                    currentZoomScale: currentZoomScale,
                    bookmarkData: item.bookmarkData
                )
                if resolved.bookmarkDataIsStale {
                    lastHitSummary = "\(resolved.url.lastPathComponent) を読み込みました（bookmark更新が必要です）"
                }
            } catch {
                fail(error)
            }
        }
    }

    func removeFromRecent(_ item: LibraryItem) {
        guard item.sourceType == .imported else {
            return
        }
        libraryCollection.removeImported(id: item.id)
        libraryItems = libraryCollection.allItems
        do {
            try libraryStore.saveImportedItems(libraryCollection.importedItems)
        } catch {
            errorMessage = "ライブラリ情報を保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func loadFileData(
        from url: URL,
        sourceName: String,
        securityScoped: Bool,
        displayTitle: String? = nil,
        libraryImportURL: URL? = nil,
        currentZoomScale: Double? = nil,
        bookmarkData: Data? = nil
    ) {
        isLoading = true
        errorMessage = nil

        let scoped = securityScoped && url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try loader.validateInputFile(at: url)
            let data = try Data(contentsOf: url)
            if let libraryImportURL {
                try loadImportedData(
                    data: data,
                    sourceName: sourceName,
                    sourceURL: libraryImportURL,
                    bookmarkData: bookmarkData,
                    currentZoomScale: currentZoomScale
                )
            } else {
                try load(data: data, sourceName: sourceName, displayTitle: displayTitle)
            }
        } catch {
            fail(error)
        }
    }

    func load(data: Data, sourceName: String, displayTitle: String? = nil) throws {
        isLoading = true
        defer { isLoading = false }
        do {
            resetKeyStateForScoreLoad()
            var displayed = try loader.load(
                data: data,
                sourceName: sourceName,
                displayTitle: displayTitle,
                displayTransposeSemitones: activeDisplayTransposeSemitones
            )
            displayed.layoutMode = preferredScoreLayoutMode
            loadedScore = displayed
            diagnostics = displayed.diagnostics
            errorMessage = nil
            resetPlaybackEvents(displayed.playbackEvents, metadata: displayed.playbackMetadata)
            lastHitSummary = "\(sourceName) を読み込みました"
        } catch {
            fail(error)
            throw error
        }
    }

    func loadImportedData(
        data: Data,
        sourceName: String,
        sourceURL: URL,
        bookmarkData: Data? = nil,
        currentZoomScale: Double? = nil,
        openedAt: Date = Date()
    ) throws {
        isLoading = true
        defer { isLoading = false }
        do {
            resetKeyStateForScoreLoad()
            var displayed = try loader.load(
                data: data,
                sourceName: sourceName,
                displayTransposeSemitones: activeDisplayTransposeSemitones
            )
            displayed.layoutMode = preferredScoreLayoutMode
            loadedScore = displayed
            diagnostics = displayed.diagnostics
            errorMessage = nil
            resetPlaybackEvents(displayed.playbackEvents, metadata: displayed.playbackMetadata)
            lastHitSummary = "\(sourceName) を読み込みました"
            recordImportedLibraryItem(
                loaded: displayed,
                sourceURL: sourceURL,
                bookmarkData: bookmarkData,
                currentZoomScale: currentZoomScale,
                openedAt: openedAt
            )
        } catch {
            fail(error)
            throw error
        }
    }

    private func recordImportedLibraryItem(
        loaded: PaletteLoadedScore,
        sourceURL: URL,
        bookmarkData: Data?,
        currentZoomScale: Double?,
        openedAt: Date
    ) {
        let item = LibraryItem.imported(
            displayName: loaded.sourceName,
            sourceURL: sourceURL,
            openedAt: openedAt,
            bookmarkData: bookmarkData,
            diagnosticsSummary: DiagnosticsSummary(diagnostics: loaded.diagnostics),
            currentNoteID: playbackCursor.currentNoteID,
            zoomScale: currentZoomScale
        )
        libraryCollection.upsertImported(item)
        libraryItems = libraryCollection.allItems
        do {
            try libraryStore.saveImportedItems(libraryCollection.importedItems)
        } catch {
            errorMessage = "ライブラリ情報を保存できませんでした: \(error.localizedDescription)"
        }
    }

    private func resetPlaybackEvents(_ events: [PlaybackEvent], metadata: PlaybackMetadata?) {
        playbackCursor.reset(events: events)
        practiceSession.configure(events: events)
        practiceSession.setEnabled(false)
        playbackRuntime.configure(events: events, metadata: metadata)
        playbackTempoBPM = playbackRuntime.effectiveTempoBPM
        playbackState = playbackRuntime.state
        audioErrorMessage = nil
    }

    private func targetEventIndex(forMeasureNumber measureNumber: Int) -> Int? {
        guard let measures = loadedScore?.score.parts.first?.measures,
              measures.indices.contains(measureNumber - 1) else {
            return nil
        }
        let targetMeasureID = measures[measureNumber - 1].id
        if let exact = playbackCursor.events.firstIndex(where: { $0.measureID == targetMeasureID }) {
            return exact
        }
        let laterMeasureIDs = measures.dropFirst(measureNumber).map(\.id)
        return playbackCursor.events.firstIndex { laterMeasureIDs.contains($0.measureID) }
    }

    private func measureNumber(for measureID: MeasureID) -> Int? {
        guard let measures = loadedScore?.score.parts.first?.measures else {
            return nil
        }
        return measures.firstIndex { $0.id == measureID }.map { $0 + 1 }
    }

    private func relayoutForDisplayTransposeIfNeeded(force: Bool = false) {
        guard let loadedScore else {
            return
        }
        guard force || displayTransposeEnabled else {
            return
        }
        do {
            let displayed = try relayoutIfNeeded(loadedScore)
            self.loadedScore = displayed
            diagnostics = displayed.diagnostics
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func relayoutIfNeeded(_ loaded: PaletteLoadedScore) throws -> PaletteLoadedScore {
        try loader.relayout(loaded, displayTransposeSemitones: activeDisplayTransposeSemitones)
    }

    private var activeDisplayTransposeSemitones: Int {
        displayTransposeEnabled ? transposeSemitones : 0
    }

    private func resetKeyStateForScoreLoad() {
        displayTransposeEnabled = true
        playbackRuntime.setTransposeSemitones(0)
        transposeSemitones = playbackRuntime.transposeSemitones
    }

    private func bindPlaybackRuntime() {
        playbackRuntime.onStateChange = { [weak self] state in
            self?.playbackState = state
            if state != .playing {
                self?.flushPendingPlaybackCursorIndex()
            }
        }
        playbackRuntime.onEventIndexChange = { [weak self] index in
            guard let self else {
                return
            }
            if self.playbackRuntime.state == .playing,
               self.preferredScoreLayoutMode != .track {
                self.schedulePlaybackCursorUpdate(index)
            } else {
                self.pendingPlaybackCursorIndex = nil
                self.applyPlaybackCursorIndex(index)
            }
        }
        playbackRuntime.onAudioError = { [weak self] error in
            self?.audioErrorMessage = "音声を開始できませんでした: \(error.localizedDescription)"
        }
    }

    private func schedulePlaybackCursorUpdate(_ index: Int) {
        pendingPlaybackCursorIndex = index
        guard playbackCursorUpdateTask == nil else {
            return
        }
        playbackCursorUpdateTask = Task { @MainActor [weak self] in
            while let self, let index = self.pendingPlaybackCursorIndex {
                self.pendingPlaybackCursorIndex = nil
                self.applyPlaybackCursorIndex(index)
                try? await Task.sleep(nanoseconds: Self.playbackCursorUpdateIntervalNanoseconds)
            }
            self?.playbackCursorUpdateTask = nil
        }
    }

    private func flushPendingPlaybackCursorIndex() {
        guard let index = pendingPlaybackCursorIndex else {
            return
        }
        pendingPlaybackCursorIndex = nil
        applyPlaybackCursorIndex(index)
    }

    private func applyPlaybackCursorIndex(_ index: Int) {
        playbackCursor.setIndex(index)
        lastHitSummary = playbackCursor.stepSummary
    }

    private func makeBookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
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

enum MeasureJumpResult: Equatable {
    case success
    case failure(String)
}
