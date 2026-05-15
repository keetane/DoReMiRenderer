import DoReMiRendererKit
import CoreGraphics
import Foundation
import Testing
@testable import DoReMiPalette

@Suite("Palette score loading")
struct PaletteScoreLoaderTests {
    @Test func sampleLoadSucceedsAndKeepsDiagnostics() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")

        #expect(loaded.sourceName == "unit.musicxml")
        #expect(!loaded.score.parts.isEmpty)
        #expect(!loaded.layout.noteByID.isEmpty)
        #expect(!loaded.playbackEvents.isEmpty)
        #expect(loaded.diagnostics.isEmpty)
    }

    @Test func parseFailureThrows() {
        #expect(throws: Error.self) {
            _ = try PaletteScoreLoader().load(data: Data("<score-partwise>".utf8), sourceName: "broken.musicxml")
        }
    }

    @Test func unsupportedExtensionThrows() {
        #expect(throws: PaletteImportError.unsupportedExtension("txt")) {
            _ = try PaletteScoreLoader().scoreInput(for: "score.txt", data: Data())
        }
    }

    @Test func supportedFileExtensionsMapToScoreInput() throws {
        let loader = PaletteScoreLoader()
        let data = Data("fixture".utf8)

        _ = try loader.scoreInput(for: "score.musicxml", data: data)
        _ = try loader.scoreInput(for: "score.xml", data: data)
        _ = try loader.scoreInput(for: "score.mxl", data: data)
    }

    @Test func importFixturesLoadSupportedFormats() throws {
        let loader = PaletteScoreLoader()

        let musicXML = try loader.load(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "import_sample.musicxml"
        )
        let xml = try loader.load(
            data: Self.fixtureData("import_sample.xml"),
            sourceName: "import_sample.xml"
        )
        let mxl = try loader.load(
            data: Self.fixtureData("import_sample.mxl"),
            sourceName: "import_sample.mxl"
        )

        #expect(musicXML.sourceName == "import_sample.musicxml")
        #expect(xml.sourceName == "import_sample.xml")
        #expect(mxl.sourceName == "import_sample.mxl")
        #expect(!musicXML.playbackEvents.isEmpty)
        #expect(!xml.playbackEvents.isEmpty)
        #expect(!mxl.playbackEvents.isEmpty)
    }

    @Test func previousNextChangesCurrentNoteID() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        var cursor = PalettePlaybackCursor(events: loaded.playbackEvents)
        let first = cursor.currentNoteID

        cursor.move(by: 1)

        #expect(cursor.currentNoteID != first)
        #expect(cursor.index == 1)
    }

    @Test func colorSettingsDoNotChangeLayoutIdentity() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let noteIDs = Set(loaded.layout.noteByID.keys)
        let elementIDs = Set(loaded.layout.elementByID.keys)
        let playbackIdentity = loaded.playbackEvents.map {
            "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)/\($0.onset.ticksPerQuarterNote)|\($0.nominalDuration.ticks)/\($0.nominalDuration.ticksPerQuarterNote)"
        }

        _ = PaletteStyleFactory.makeStyle(noteColorVisible: true, staffColorVisible: false)
        _ = PaletteStyleFactory.makeStyle(noteColorVisible: false, staffColorVisible: true)

        #expect(Set(loaded.layout.noteByID.keys) == noteIDs)
        #expect(Set(loaded.layout.elementByID.keys) == elementIDs)
        #expect(
            loaded.playbackEvents.map {
                "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)/\($0.onset.ticksPerQuarterNote)|\($0.nominalDuration.ticks)/\($0.nominalDuration.ticksPerQuarterNote)"
            } == playbackIdentity
        )
    }

    @Test func scoreLoaderCreatesHorizontalAndA4LayoutsForTheSameScore() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "unit.musicxml")

        #expect(loaded.layoutMode == .horizontal)
        #expect(loaded.layout.canvasSize == loaded.horizontalLayout.canvasSize)
        #expect(loaded.printLayout.canvasSize == loaded.a4Layout.canvasSize)
        #expect(loaded.horizontalLayout.canvasSize.width != loaded.a4Layout.canvasSize.width)
        #expect(Set(loaded.horizontalLayout.noteByID.keys) == Set(loaded.a4Layout.noteByID.keys))
        #expect(Set(loaded.horizontalLayout.elementByID.keys) == Set(loaded.a4Layout.elementByID.keys))
    }

    @Test @MainActor func scoreLayoutModeSwitchesActiveLayoutWithoutChangingPlaybackIdentity() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let initial = try #require(session.loadedScore)
        let noteIDs = Set(initial.layout.noteByID.keys)
        let playbackIdentity = initial.playbackEvents.map {
            "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)|\($0.nominalDuration.ticks)"
        }

        session.setScoreLayoutMode(.a4)
        let a4 = try #require(session.loadedScore)

        #expect(a4.layoutMode == .a4)
        #expect(a4.layout.canvasSize == a4.a4Layout.canvasSize)
        #expect(a4.printLayout.canvasSize == a4.a4Layout.canvasSize)
        #expect(Set(a4.layout.noteByID.keys) == noteIDs)
        #expect(a4.playbackEvents.map {
            "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)|\($0.nominalDuration.ticks)"
        } == playbackIdentity)

        session.setScoreLayoutMode(.horizontal)
        let horizontal = try #require(session.loadedScore)

        #expect(horizontal.layoutMode == .horizontal)
        #expect(horizontal.layout.canvasSize == horizontal.horizontalLayout.canvasSize)
        #expect(horizontal.printLayout.canvasSize == horizontal.a4Layout.canvasSize)
    }

    @Test @MainActor func handleTapSelectsNearestNoteAndKeepsScoreLoaded() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let loaded = try #require(session.loadedScore)
        let secondNoteID = try #require(loaded.playbackEvents.dropFirst().first?.noteIDs.first)
        let noteLayout = try #require(loaded.layout.noteLayout(for: secondNoteID))

        let result = loaded.layout.hitTest(point: noteLayout.noteheadCenter, radius: 24)
        session.handleTap(result)

        #expect(session.playbackCursor.currentNoteID == secondNoteID)
        #expect(session.loadedScore?.sourceName == "unit.musicxml")
        #expect(session.lastHitSummary.contains(secondNoteID.rawValue))
    }

    @Test @MainActor func keyboardVisibilityStateDoesNotClearCurrentScore() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let currentNoteID = session.playbackCursor.currentNoteID
        var keyboardVisible = true

        keyboardVisible.toggle()

        #expect(!keyboardVisible)
        #expect(session.loadedScore?.sourceName == "unit.musicxml")
        #expect(session.playbackCursor.currentNoteID == currentNoteID)
    }

    @Test @MainActor func zoomScaleStateDoesNotChangeTapCoordinateModel() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "unit.musicxml")
        let loaded = try #require(session.loadedScore)
        let firstNoteID = try #require(session.playbackCursor.currentNoteID)
        let noteLayout = try #require(loaded.layout.noteLayout(for: firstNoteID))
        let transform = ScoreViewportTransform(
            scale: 2.0,
            contentOffset: .zero,
            viewportSize: CGSize(width: 400, height: 300),
            contentSize: loaded.layout.canvasSize
        )
        let viewPoint = transform.viewPoint(fromLayoutPoint: noteLayout.noteheadCenter)
        let layoutPoint = transform.layoutPoint(fromViewPoint: viewPoint)

        let result = loaded.layout.hitTest(point: layoutPoint, radius: 24)

        #expect(result.nearestNoteID == firstNoteID)
    }

    @Test func settingsKeysStoreAndRestoreValues() throws {
        let suiteName = "PaletteSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: PaletteSettingsKeys.noteColorVisible)
        defaults.set(true, forKey: PaletteSettingsKeys.staffColorVisible)
        defaults.set(false, forKey: PaletteSettingsKeys.keyboardVisible)
        defaults.set(2.0, forKey: PaletteSettingsKeys.zoomScale)
        defaults.set(PaletteScoreLayoutMode.a4.rawValue, forKey: PaletteSettingsKeys.scoreLayoutMode)

        #expect(defaults.bool(forKey: PaletteSettingsKeys.noteColorVisible) == false)
        #expect(defaults.bool(forKey: PaletteSettingsKeys.staffColorVisible) == true)
        #expect(defaults.bool(forKey: PaletteSettingsKeys.keyboardVisible) == false)
        #expect(defaults.double(forKey: PaletteSettingsKeys.zoomScale) == 2.0)
        #expect(defaults.string(forKey: PaletteSettingsKeys.scoreLayoutMode) == PaletteScoreLayoutMode.a4.rawValue)
    }

    @Test func diagnosticsPresentationSummarizesWarningsAndErrorsInJapanese() {
        let presentation = DiagnosticsPresentation(diagnostics: [
            RendererDiagnostic(severity: .warning, code: "unsupported.slur.rendering", message: "slur"),
            RendererDiagnostic(severity: .error, code: "parser.invalidXML", message: "invalid")
        ])

        #expect(presentation.summaryText == "エラー 1 件、警告 1 件")
        #expect(DiagnosticsPresentation.severityText(for: .warning) == "警告")
        #expect(DiagnosticsPresentation.severityText(for: .error) == "エラー")
    }

    @Test func diagnosticsPresentationMapsUnsupportedAndRepeatMessages() {
        let unsupported = RendererDiagnostic(
            severity: .warning,
            code: "unsupported.tuplet.duration",
            message: "Tuplet unsupported"
        )
        let repeatDiagnostic = RendererDiagnostic(
            severity: .warning,
            code: "repeat.startMissingFallback",
            message: "Repeat fallback"
        )

        #expect(DiagnosticsPresentation.userMessage(for: unsupported).contains("未対応の記譜"))
        #expect(DiagnosticsPresentation.userMessage(for: repeatDiagnostic).contains("リピート情報"))
    }

    @Test func diagnosticsPresentationLocationTextIncludesContext() {
        let diagnostic = RendererDiagnostic(
            severity: .warning,
            code: "unsupported.slur.rendering",
            message: "slur",
            location: MusicXMLLocation(elementName: "slur", partID: "P1", measureNumber: "2")
        )

        #expect(DiagnosticsPresentation.locationText(for: diagnostic) == "場所: part P1, measure 2, element slur")
        #expect(DiagnosticsPresentation.locationText(for: RendererDiagnostic(severity: .info, code: "ok", message: "ok")) == "場所: 不明")
    }

    @Test @MainActor func importSuccessResetsCurrentNoteIDAndUpdatesDiagnostics() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        session.movePlaybackStep(by: 1)
        let movedNoteID = session.playbackCursor.currentNoteID

        try session.load(data: Self.fixtureData("import_sample.musicxml"), sourceName: "import_sample.musicxml")

        #expect(session.loadedScore?.sourceName == "import_sample.musicxml")
        #expect(session.playbackCursor.index == 0)
        #expect(session.playbackCursor.currentNoteID != movedNoteID)
        #expect(session.diagnostics.isEmpty)
    }

    @Test @MainActor func importFailureKeepsExistingScoreAndReportsError() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        let existingSourceName = session.loadedScore?.sourceName
        let existingNoteIDs = Set(session.loadedScore?.layout.noteByID.keys.map { $0 } ?? [])

        do {
            try session.load(data: Self.fixtureData("invalid.musicxml"), sourceName: "invalid.musicxml")
            Issue.record("Expected invalid import to fail")
        } catch {
            #expect(session.loadedScore?.sourceName == existingSourceName)
            #expect(Set(session.loadedScore?.layout.noteByID.keys.map { $0 } ?? []) == existingNoteIDs)
            #expect(session.errorMessage != nil)
        }
    }

    @Test @MainActor func unsupportedImportKeepsExistingScoreAndReportsError() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        let existingSourceName = session.loadedScore?.sourceName

        do {
            try session.load(data: Self.fixtureData("unsupported.txt"), sourceName: "unsupported.txt")
            Issue.record("Expected unsupported import to fail")
        } catch {
            #expect(session.loadedScore?.sourceName == existingSourceName)
            #expect(session.errorMessage?.contains("対応していないファイル形式") == true)
        }
    }

    @Test func librarySampleItemsAreGeneratedAndDistinguishSourceTypes() throws {
        let catalog = SampleScoreCatalog.default
        let sample = try #require(catalog.defaultSample)
        let sampleItem = LibraryItem.sample(from: sample, openedAt: Date(timeIntervalSince1970: 10))
        let importedItem = LibraryItem.imported(
            displayName: "import_sample.musicxml",
            sourceURL: URL(fileURLWithPath: "/tmp/import_sample.musicxml"),
            openedAt: Date(timeIntervalSince1970: 20),
            bookmarkData: nil,
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: nil
        )

        #expect(sampleItem.sourceType == .sample)
        #expect(importedItem.sourceType == .imported)
        #expect(sampleItem.displayName == "S9 Repeat Visuals Sample")
        #expect(sample.sourceIdentifier == "sample:s9_repeat_visuals_sample.musicxml")
    }

    @Test func libraryCollectionSortsAndUpdatesDuplicateImports() throws {
        let catalog = SampleScoreCatalog.default
        let sourceURL = URL(fileURLWithPath: "/tmp/import_sample.musicxml")
        let older = LibraryItem.imported(
            displayName: "Old",
            sourceURL: sourceURL,
            openedAt: Date(timeIntervalSince1970: 10),
            bookmarkData: nil,
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: 1.0
        )
        let newer = LibraryItem.imported(
            displayName: "New",
            sourceURL: sourceURL,
            openedAt: Date(timeIntervalSince1970: 20),
            bookmarkData: Data([1, 2, 3]),
            diagnosticsSummary: DiagnosticsSummary(diagnostics: [
                RendererDiagnostic(severity: .warning, code: "fixture.warning", message: "warning")
            ]),
            currentNoteID: NoteID(rawValue: "note-1"),
            zoomScale: 2.0
        )
        var collection = LibraryCollection(sampleItems: catalog.libraryItems(), importedItems: [])

        collection.upsertImported(older)
        let originalID = try #require(collection.importedItems.first?.id)
        collection.upsertImported(newer)

        #expect(collection.importedItems.count == 1)
        #expect(collection.importedItems[0].id == originalID)
        #expect(collection.importedItems[0].displayName == "New")
        #expect(collection.importedItems[0].diagnosticsSummary?.warnings == 1)
        #expect(collection.importedItems[0].lastCurrentNoteIDRawValue == "note-1")
        #expect(collection.importedItems[0].lastZoomScale == 2.0)
        #expect(collection.allItems.first?.sourceType == .sample)
    }

    @Test func libraryItemCodableRoundTripKeepsMetadata() throws {
        let item = LibraryItem.imported(
            displayName: "Round Trip",
            sourceURL: URL(fileURLWithPath: "/tmp/roundtrip.mxl"),
            openedAt: Date(timeIntervalSince1970: 42),
            bookmarkData: Data([4, 5, 6]),
            diagnosticsSummary: DiagnosticsSummary(diagnostics: [
                RendererDiagnostic(severity: .error, code: "parser.invalidXML", message: "invalid"),
                RendererDiagnostic(severity: .warning, code: "unsupported.slur.rendering", message: "slur")
            ]),
            currentNoteID: NoteID(rawValue: "note-roundtrip"),
            zoomScale: 1.5
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LibraryItem.self, from: data)

        #expect(decoded == item)
        #expect(decoded.diagnosticsSummary?.errors == 1)
        #expect(decoded.diagnosticsSummary?.warnings == 1)
        #expect(decoded.diagnosticsSummary?.codes == ["parser.invalidXML", "unsupported.slur.rendering"])
    }

    @Test func libraryStoreSavesLoadsAndIgnoresCorruptData() throws {
        let storeURL = Self.temporaryURL(fileName: "library.json")
        let store = LibraryStore(fileURL: storeURL)
        let item = LibraryItem.imported(
            displayName: "Stored",
            sourceURL: URL(fileURLWithPath: "/tmp/stored.musicxml"),
            openedAt: Date(timeIntervalSince1970: 100),
            bookmarkData: nil,
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: nil
        )

        #expect(store.loadImportedItems().isEmpty)

        try store.saveImportedItems([item])
        #expect(store.loadImportedItems() == [item])

        try Data("not json".utf8).write(to: storeURL, options: [.atomic])
        #expect(store.loadImportedItems().isEmpty)
    }

    @Test @MainActor func importSuccessAddsLibraryItemAndResetsCurrentNoteID() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let session = PaletteScoreSession(libraryStore: store)
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        session.movePlaybackStep(by: 1)

        let importURL = URL(fileURLWithPath: "/tmp/import_sample.musicxml")
        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "import_sample.musicxml",
            sourceURL: importURL,
            currentZoomScale: 1.5,
            openedAt: Date(timeIntervalSince1970: 200)
        )

        let importedItems = session.libraryItems.filter { $0.sourceType == .imported }
        let importedItem = try #require(importedItems.first)
        #expect(importedItems.count == 1)
        #expect(importedItem.displayName == "import_sample.musicxml")
        #expect(importedItem.lastZoomScale == 1.5)
        #expect(importedItem.diagnosticsSummary?.errors == 0)
        #expect(importedItem.diagnosticsSummary?.warnings == 0)
        #expect(importedItem.lastCurrentNoteIDRawValue == session.playbackCursor.currentNoteID?.rawValue)
        #expect(session.playbackCursor.index == 0)
        #expect(store.loadImportedItems().count == 1)
    }

    @Test @MainActor func duplicateImportUpdatesExistingLibraryItem() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let session = PaletteScoreSession(libraryStore: store)
        let importURL = URL(fileURLWithPath: "/tmp/import_sample.musicxml")

        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "First Name.musicxml",
            sourceURL: importURL,
            currentZoomScale: 1.0,
            openedAt: Date(timeIntervalSince1970: 100)
        )
        let originalID = try #require(session.libraryItems.first(where: { $0.sourceType == .imported })?.id)

        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "Updated Name.musicxml",
            sourceURL: importURL,
            currentZoomScale: 2.0,
            openedAt: Date(timeIntervalSince1970: 300)
        )

        let importedItems = session.libraryItems.filter { $0.sourceType == .imported }
        #expect(importedItems.count == 1)
        #expect(importedItems[0].id == originalID)
        #expect(importedItems[0].displayName == "Updated Name.musicxml")
        #expect(importedItems[0].lastZoomScale == 2.0)
        #expect(importedItems[0].lastOpenedAt == Date(timeIntervalSince1970: 300))
    }

    @Test @MainActor func importFailureDoesNotAddLibraryItemAndKeepsScore() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let session = PaletteScoreSession(libraryStore: store)
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        let existingSourceName = session.loadedScore?.sourceName

        do {
            try session.loadImportedData(
                data: Self.fixtureData("invalid.musicxml"),
                sourceName: "invalid.musicxml",
                sourceURL: URL(fileURLWithPath: "/tmp/invalid.musicxml")
            )
            Issue.record("Expected invalid import to fail")
        } catch {
            #expect(session.loadedScore?.sourceName == existingSourceName)
            #expect(session.libraryItems.filter { $0.sourceType == .imported }.isEmpty)
            #expect(store.loadImportedItems().isEmpty)
        }
    }

    @Test @MainActor func removeFromRecentRemovesImportedItemAndPersists() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let session = PaletteScoreSession(libraryStore: store)
        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "import_sample.musicxml",
            sourceURL: URL(fileURLWithPath: "/tmp/import_sample.musicxml")
        )
        let item = try #require(session.recentImportedItems.first)

        session.removeFromRecent(item)

        #expect(session.recentImportedItems.isEmpty)
        #expect(store.loadImportedItems().isEmpty)
    }

    @Test @MainActor func bookmarkDataCanBeStoredAndDuplicateImportUpdatesIt() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let session = PaletteScoreSession(libraryStore: store)
        let sourceURL = URL(fileURLWithPath: "/tmp/bookmarked.musicxml")

        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "bookmarked.musicxml",
            sourceURL: sourceURL,
            bookmarkData: Data([1]),
            openedAt: Date(timeIntervalSince1970: 10)
        )
        try session.loadImportedData(
            data: Self.fixtureData("import_sample.musicxml"),
            sourceName: "bookmarked.musicxml",
            sourceURL: sourceURL,
            bookmarkData: Data([2, 3]),
            openedAt: Date(timeIntervalSince1970: 20)
        )

        let item = try #require(session.recentImportedItems.first)
        #expect(session.recentImportedItems.count == 1)
        #expect(item.bookmarkData == Data([2, 3]))
        #expect(store.loadImportedItems().first?.bookmarkData == Data([2, 3]))
    }

    @Test @MainActor func nilBookmarkRecentItemBecomesMissingFileState() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        let existingSourceName = session.loadedScore?.sourceName
        let item = LibraryItem.imported(
            displayName: "missing.musicxml",
            sourceURL: URL(fileURLWithPath: "/tmp/missing.musicxml"),
            openedAt: Date(),
            bookmarkData: nil,
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: nil
        )

        session.openLibraryItem(item)

        #expect(session.loadedScore?.sourceName == existingSourceName)
        #expect(session.errorMessage?.contains("ファイルを再選択してください") == true)
    }

    @Test @MainActor func recentItemReloadSuccessOpensScoreAndUpdatesSummary() throws {
        let store = LibraryStore(fileURL: Self.temporaryURL(fileName: "library.json"))
        let scoreURL = Self.temporaryURL(fileName: "reload.musicxml")
        try Self.fixtureData("import_sample.musicxml").write(to: scoreURL)
        let item = LibraryItem.imported(
            displayName: "reload.musicxml",
            sourceURL: scoreURL,
            openedAt: Date(timeIntervalSince1970: 10),
            bookmarkData: Data([9]),
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: nil
        )
        try store.saveImportedItems([item])
        let session = PaletteScoreSession(
            libraryStore: store,
            libraryFileResolver: StubLibraryFileResolver(result: .success(
                LibraryResolvedFile(url: scoreURL, securityScoped: false, bookmarkDataIsStale: false)
            ))
        )

        session.openLibraryItem(item, currentZoomScale: 2.0)

        #expect(session.loadedScore?.sourceName == "reload.musicxml")
        #expect(session.playbackCursor.index == 0)
        #expect(session.errorMessage == nil)
        #expect(session.recentImportedItems.first?.diagnosticsSummary?.errors == 0)
        #expect(session.recentImportedItems.first?.lastZoomScale == 2.0)
    }

    @Test @MainActor func recentItemReloadFailureKeepsExistingScore() throws {
        let session = PaletteScoreSession(
            libraryFileResolver: StubLibraryFileResolver(result: .failure(
                PaletteImportError.missingLibraryFile("missing.musicxml")
            ))
        )
        try session.load(data: Self.validMusicXML, sourceName: "first.musicxml")
        let existingSourceName = session.loadedScore?.sourceName
        let item = LibraryItem.imported(
            displayName: "missing.musicxml",
            sourceURL: URL(fileURLWithPath: "/tmp/missing.musicxml"),
            openedAt: Date(),
            bookmarkData: Data([1]),
            diagnosticsSummary: nil,
            currentNoteID: nil,
            zoomScale: nil
        )

        session.openLibraryItem(item)

        #expect(session.loadedScore?.sourceName == existingSourceName)
        #expect(session.errorMessage?.contains("ファイルを再選択してください") == true)
    }

    @Test @MainActor func sampleLibraryItemOpensBundledSampleFromBundle() throws {
        let session = PaletteScoreSession()
        let sampleItem = try #require(session.sampleLibraryItems.first)

        session.openLibraryItem(sampleItem, bundle: .main)

        #expect(session.loadedScore?.sourceName == "s9_repeat_visuals_sample.musicxml")
        #expect(session.errorMessage == nil)
    }

    @Test func rhythmValuesSampleLoadsAndContainsExpectedDurations() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("rhythm_values_sample.musicxml"),
            sourceName: "rhythm_values_sample.musicxml"
        )
        let renderer = DoReMiRenderer()
        let eventsWithRests = renderer.makePlaybackSequence(
            score: loaded.score,
            options: PlaybackOptions(includeRests: true)
        )
        let pitchedEvents = loaded.playbackEvents
        let durations = pitchedEvents.map { Self.quarterNotes(for: $0.nominalDuration) }

        #expect(durations.contains(4.0))
        #expect(durations.contains(2.0))
        #expect(durations.contains(1.0))
        #expect(durations.contains(0.5))
        #expect(eventsWithRests.contains { $0.midiPitches.isEmpty && Self.quarterNotes(for: $0.nominalDuration) == 1.0 })
        #expect(eventsWithRests.contains { $0.midiPitches.isEmpty && Self.quarterNotes(for: $0.nominalDuration) == 0.5 })
        let whole: Double = 4.0
        let half: Double = 2.0
        let quarter: Double = 1.0
        let eighth: Double = 0.5
        #expect(whole > quarter)
        #expect(half > quarter)
        #expect(eighth < quarter)
    }

    @Test func rhythmValuesSampleKeepsRepeatedC4AsSeparateEventsInOnsetOrder() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("rhythm_values_sample.musicxml"),
            sourceName: "rhythm_values_sample.musicxml"
        )
        let repeatedC4Events = loaded.playbackEvents.filter { $0.midiPitches == [60] }
        let onsetKeys = repeatedC4Events.map { "\($0.onset.ticks)/\($0.onset.ticksPerQuarterNote)" }

        #expect(repeatedC4Events.count >= 4)
        #expect(Set(onsetKeys).count > 1)
    }

    @Test func sampleCatalogIncludesRhythmValuesSample() throws {
        let catalog = SampleScoreCatalog.default
        let rhythmSample = try #require(catalog.samples.first { $0.resourceName == "rhythm_values_sample" })

        #expect(rhythmSample.displayName == "Rhythm Values Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "Rhythm Values Sample" && $0.sourceType == .sample })
    }

    @Test func notationCoverageGrandStaffSampleLoadsAndIsListed() throws {
        let catalog = SampleScoreCatalog.default
        let sample = try #require(catalog.samples.first { $0.resourceName == "notation_coverage_grand_staff" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("notation_coverage_grand_staff.musicxml"),
            sourceName: "notation_coverage_grand_staff.musicxml"
        )

        #expect(sample.displayName == "Notation Coverage Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "Notation Coverage Sample" && $0.sourceType == .sample })
        #expect(loaded.score.parts.first?.measures.count == 10)
        #expect(loaded.score.parts.first?.measures.first?.clefsByStaff[StaffID(rawValue: "2")]?.kind == .bass)
        #expect(loaded.layout.elements.contains { $0.kind == .clef })
        #expect(loaded.layout.elements.contains { $0.kind == .timeSignature })
        #expect(loaded.layout.elements.contains { $0.kind == .keySignature })
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline != nil })
        #expect(loaded.layout.elements.contains { $0.kind == .dot })
        #expect(loaded.playbackEvents.count > 10)
        #expect(!loaded.diagnostics.contains { $0.code == "repeat.playbackExpansionUnsupported" })

        let upperClef = try #require(loaded.layout.elements.first {
            $0.kind == .clef && $0.staffID == StaffID(rawValue: "1") && $0.measureID?.rawValue.contains("1") == true
        })
        let upperKey = try #require(loaded.layout.elements.first {
            $0.kind == .keySignature && $0.staffID == StaffID(rawValue: "1") && $0.measureID?.rawValue.contains("1") == true
        })
        let upperTime = try #require(loaded.layout.elements.first {
            $0.kind == .timeSignature && $0.staffID == StaffID(rawValue: "1") && $0.measureID?.rawValue.contains("1") == true
        })
        let lowerTime = try #require(loaded.layout.elements.first {
            $0.kind == .timeSignature && $0.staffID == StaffID(rawValue: "2") && $0.measureID?.rawValue.contains("1") == true
        })
        #expect(upperClef.frame.maxX < upperKey.frame.minX)
        #expect(upperKey.frame.maxX < upperTime.frame.minX)
        #expect(upperTime.timeSignature == TimeSignature(beats: 4, beatType: 4))
        #expect(lowerTime.timeSignature == TimeSignature(beats: 4, beatType: 4))
        #expect(lowerTime.frame.width > 0)
    }

    @Test func s6NotationRefinementSampleIsDefaultAndContainsS6Elements() throws {
        let catalog = SampleScoreCatalog.default
        let defaultSample = try #require(catalog.defaultSample)
        let sample = try #require(catalog.samples.first { $0.resourceName == "s6_notation_refinement_grand_staff" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s6_notation_refinement_grand_staff.musicxml"),
            sourceName: "s6_notation_refinement_grand_staff.musicxml"
        )

        #expect(defaultSample.resourceName == "s9_repeat_visuals_sample")
        #expect(sample.displayName == "S6 Notation Refinement Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "S6 Notation Refinement Sample" && $0.sourceType == .sample })
        #expect(loaded.score.parts.first?.measures.count == 15)
        #expect(loaded.score.parts.first?.measures.first?.clefsByStaff[StaffID(rawValue: "2")]?.kind == .bass)
        #expect(loaded.layout.elements.contains { $0.kind == .beam })
        #expect(loaded.layout.elements.contains { $0.kind == .tie })
        #expect(loaded.layout.elements.contains { $0.kind == .slur })
        #expect(loaded.layout.elements.contains { $0.kind == .tuplet && $0.tuplet?.number == "3" })
        #expect(loaded.layout.elements.contains { $0.kind == .tuplet && $0.tuplet?.number == "5" })
        #expect(loaded.layout.elements.contains { $0.kind == .tuplet && $0.tuplet?.number == "7" })
        #expect(loaded.layout.elements.contains { $0.kind == .lyric })
        #expect(loaded.layout.elements.contains { $0.kind == .fingering })
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline != nil })
        #expect(loaded.playbackEvents.count > 20)

        let measure14 = try #require(loaded.score.parts.first?.measures.first { $0.id.rawValue == "0.14" })
        let measure15 = try #require(loaded.score.parts.first?.measures.first { $0.id.rawValue == "0.15" })
        let measure15PitchedNoteIDs = Set(measure15.notes.filter { $0.pitch != nil }.map(\.id))
        #expect(measure14.notes.filter { $0.pitch != nil && $0.noteValueKind == .sixteenth }.count == 6)
        #expect(measure15.notes.filter { $0.pitch != nil && $0.noteValueKind == .thirtySecond }.count == 6)
        #expect(loaded.layout.elements.contains { element in
            element.kind == .beam
                && !(Set(element.beam?.noteIDs ?? []).isDisjoint(with: measure15PitchedNoteIDs))
                && (element.beam?.secondarySegments.count ?? 0) >= 2
        })
    }

    @Test func s7RepeatPlaybackSampleLoadsAndExpandsSimpleRepeat() throws {
        let catalog = SampleScoreCatalog.default
        let defaultSample = try #require(catalog.defaultSample)
        let sample = try #require(catalog.samples.first { $0.resourceName == "s7_repeat_playback_sample" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s7_repeat_playback_sample.musicxml"),
            sourceName: "s7_repeat_playback_sample.musicxml"
        )

        #expect(defaultSample.resourceName == "s9_repeat_visuals_sample")
        #expect(sample.displayName == "S7 Repeat Playback Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "S7 Repeat Playback Sample" && $0.sourceType == .sample })
        #expect(loaded.score.parts.first?.measures.count == 4)
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline?.direction == .forward })
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline?.direction == .backward })
        #expect(!loaded.diagnostics.contains { $0.code == "repeat.playbackExpansionUnsupported" })

        let measureTransitions = loaded.playbackEvents.map(\.measureID.rawValue).reduce(into: [String]()) { result, measureID in
            if result.last != measureID {
                result.append(measureID)
            }
        }
        #expect(measureTransitions == ["0.1", "0.2", "0.3", "0.2", "0.3", "0.4"])
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.2" }.count == 8)
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.3" }.count == 8)
    }

    @Test func s8RepeatEndingsSampleLoadsAndExpandsFirstSecondEndings() throws {
        let catalog = SampleScoreCatalog.default
        let defaultSample = try #require(catalog.defaultSample)
        let sample = try #require(catalog.samples.first { $0.resourceName == "s8_repeat_endings_sample" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s8_repeat_endings_sample.musicxml"),
            sourceName: "s8_repeat_endings_sample.musicxml"
        )

        #expect(defaultSample.resourceName == "s9_repeat_visuals_sample")
        #expect(sample.displayName == "S8 Repeat Endings Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "S8 Repeat Endings Sample" && $0.sourceType == .sample })
        #expect(loaded.score.parts.first?.measures.count == 6)
        #expect(loaded.score.parts.first?.measures[3].repeatEndings.contains { $0.numbers == [1] && $0.kind == .start } == true)
        #expect(loaded.score.parts.first?.measures[4].repeatEndings.contains { $0.numbers == [2] && $0.kind == .start } == true)

        let measureTransitions = loaded.playbackEvents.map(\.measureID.rawValue).reduce(into: [String]()) { result, measureID in
            if result.last != measureID {
                result.append(measureID)
            }
        }
        #expect(measureTransitions == ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3", "0.5", "0.6"])
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.2" }.count == 8)
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.3" }.count == 8)
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.4" }.count == 4)
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.5" }.count == 4)
    }

    @Test func s9RepeatVisualsSampleLoadsDrawsEndingBracketsAndKeepsPlaybackOrder() throws {
        let catalog = SampleScoreCatalog.default
        let defaultSample = try #require(catalog.defaultSample)
        let sample = try #require(catalog.samples.first { $0.resourceName == "s9_repeat_visuals_sample" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s9_repeat_visuals_sample.musicxml"),
            sourceName: "s9_repeat_visuals_sample.musicxml"
        )

        #expect(defaultSample.resourceName == "s9_repeat_visuals_sample")
        #expect(sample.displayName == "S9 Repeat Visuals Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "S9 Repeat Visuals Sample" && $0.sourceType == .sample })
        #expect(loaded.score.parts.first?.measures.count == 6)
        #expect(loaded.layout.elements.contains { $0.kind == .repeatEnding && $0.repeatEnding?.label == "1." })
        #expect(loaded.layout.elements.contains { $0.kind == .repeatEnding && $0.repeatEnding?.label == "2." })
        #expect(loaded.diagnostics.contains { $0.code == "jump.dalSegnoUnsupported" })

        let measureTransitions = loaded.playbackEvents.map(\.measureID.rawValue).reduce(into: [String]()) { result, measureID in
            if result.last != measureID {
                result.append(measureID)
            }
        }
        #expect(measureTransitions == ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3", "0.5", "0.6"])
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.4" }.count == 4)
        #expect(loaded.playbackEvents.filter { $0.measureID.rawValue == "0.5" }.count == 4)
    }

    @Test func s10JumpSamplesLoadAndExpandExpectedPlaybackOrders() throws {
        let catalog = SampleScoreCatalog.default
        let expected: [(resource: String, displayName: String, order: [String])] = [
            ("s10_dc_fine_sample", "S10 D.C. al Fine Sample", ["0.1", "0.2", "0.3", "0.4", "0.1", "0.2", "0.3"]),
            ("s10_ds_fine_sample", "S10 D.S. al Fine Sample", ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3"]),
            ("s10_dc_coda_sample", "S10 D.C. al Coda Sample", ["0.1", "0.2", "0.3", "0.1", "0.2", "0.4", "0.5"]),
            ("s10_ds_coda_sample", "S10 D.S. al Coda Sample", ["0.1", "0.2", "0.3", "0.4", "0.2", "0.3", "0.5", "0.6"]),
        ]

        for sampleCase in expected {
            let sample = try #require(catalog.samples.first { $0.resourceName == sampleCase.resource })
            let loaded = try PaletteScoreLoader().load(
                data: Self.appSampleData("\(sampleCase.resource).musicxml"),
                sourceName: "\(sampleCase.resource).musicxml"
            )
            let measureTransitions = loaded.playbackEvents.map(\.measureID.rawValue).reduce(into: [String]()) { result, measureID in
                if result.last != measureID {
                    result.append(measureID)
                }
            }

            #expect(sample.displayName == sampleCase.displayName)
            #expect(catalog.libraryItems().contains { $0.displayName == sampleCase.displayName && $0.sourceType == .sample })
            #expect(measureTransitions == sampleCase.order)
            #expect(loaded.layout.elements.contains { $0.kind == .playbackJumpMarker })
            #expect(!loaded.diagnostics.contains { $0.code == "jump.codaUnsupported" })
        }
    }

    @Test func s10RepeatDiagnosticsSampleLoadsAndEmitsSpecificWarnings() throws {
        let catalog = SampleScoreCatalog.default
        let sample = try #require(catalog.samples.first { $0.resourceName == "s10_repeat_diagnostics_sample" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s10_repeat_diagnostics_sample.musicxml"),
            sourceName: "s10_repeat_diagnostics_sample.musicxml"
        )

        #expect(sample.displayName == "S10 Repeat Diagnostics Sample")
        #expect(loaded.layout.elements.contains { $0.kind == .repeatEnding && $0.repeatEnding?.label == "3." })
        #expect(loaded.layout.elements.contains { $0.kind == .playbackJumpMarker && $0.playbackJumpMarker?.label == "D.S. al Coda" })
        #expect(loaded.diagnostics.contains { $0.code == "repeat.nestedUnsupported" })
        #expect(loaded.diagnostics.contains { $0.code == "repeat.endingNumberUnsupported" })
        #expect(loaded.diagnostics.contains { $0.code == "jump.multipleSegnoUnsupported" })
        #expect(loaded.diagnostics.contains { $0.code == "jump.withRepeatsUnsupported" })
    }

    @Test func s10AllRepeatSymbolsSampleLoadsAndShowsRepeatMarkersForManualQA() throws {
        let catalog = SampleScoreCatalog.default
        let sample = try #require(catalog.samples.first { $0.resourceName == "s10_all_repeat_symbols_sample" })
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s10_all_repeat_symbols_sample.musicxml"),
            sourceName: "s10_all_repeat_symbols_sample.musicxml"
        )

        let markerLabels = Set(loaded.layout.elements.compactMap(\.playbackJumpMarker?.label))

        #expect(sample.displayName == "S10 All Repeat Symbols Sample")
        #expect(catalog.libraryItems().contains { $0.displayName == "S10 All Repeat Symbols Sample" && $0.sourceType == .sample })
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline?.direction == .forward })
        #expect(loaded.layout.elements.contains { $0.kind == .barline && $0.repeatBarline?.direction == .backward })
        #expect(loaded.layout.elements.contains { $0.kind == .repeatEnding && $0.repeatEnding?.label == "1." })
        #expect(loaded.layout.elements.contains { $0.kind == .repeatEnding && $0.repeatEnding?.label == "2." })
        #expect(markerLabels.isSuperset(of: [
            "Segno",
            "To Coda",
            "Fine",
            "D.C.",
            "D.C. al Fine",
            "D.C. al Coda",
            "D.S.",
            "D.S. al Fine",
            "Coda",
            "D.S. al Coda",
        ]))
        #expect(loaded.diagnostics.contains { $0.code == "jump.withRepeatsUnsupported" })
    }

    @Test func s6MeasureSixMixedBeamPatternsStayOnEighthVisualGrid() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.appSampleData("s6_notation_refinement_grand_staff.musicxml"),
            sourceName: "s6_notation_refinement_grand_staff.musicxml"
        )
        let measureSix = try #require(loaded.score.parts.first?.measures.first { $0.id.rawValue == "0.6" })
        let upperNotes = measureSix.notes
            .filter { $0.staffID == StaffID(rawValue: "1") && $0.voiceID == VoiceID(rawValue: "1") }

        let firstMixedBeam = Array(upperNotes.prefix(3))
        let secondMixedBeam = Array(upperNotes.dropFirst(3).prefix(3))
        let simpleEighthBeam = Array(upperNotes.dropFirst(6).prefix(2))

        #expect(firstMixedBeam.map(\.noteValueKind) == [.sixteenth, .sixteenth, .eighth])
        #expect(firstMixedBeam.map(\.duration.ticks).reduce(0, +) == 12)
        #expect(secondMixedBeam.map(\.noteValueKind) == [.sixteenth, .sixteenth, .eighth])
        #expect(secondMixedBeam.map(\.duration.ticks).reduce(0, +) == 12)
        #expect(simpleEighthBeam.map(\.noteValueKind) == [.eighth, .eighth])
        #expect(simpleEighthBeam.map(\.duration.ticks).reduce(0, +) == 12)

        let firstLayouts = try firstMixedBeam.map { note in
            try #require(loaded.layout.noteLayout(for: note.id))
        }
        let secondLayouts = try secondMixedBeam.map { note in
            try #require(loaded.layout.noteLayout(for: note.id))
        }
        let simpleLayouts = try simpleEighthBeam.map { note in
            try #require(loaded.layout.noteLayout(for: note.id))
        }

        let firstGapA = firstLayouts[1].noteheadCenter.x - firstLayouts[0].noteheadCenter.x
        let firstGapB = firstLayouts[2].noteheadCenter.x - firstLayouts[1].noteheadCenter.x
        let secondGapA = secondLayouts[1].noteheadCenter.x - secondLayouts[0].noteheadCenter.x
        let secondGapB = secondLayouts[2].noteheadCenter.x - secondLayouts[1].noteheadCenter.x
        let simpleEighthGap = simpleLayouts[1].noteheadCenter.x - simpleLayouts[0].noteheadCenter.x

        #expect(abs(firstGapA - firstGapB) < 0.001)
        #expect(abs(secondGapA - secondGapB) < 0.001)
        #expect(abs((firstGapA * 2) - simpleEighthGap) < 0.001)
        #expect(abs((secondGapA * 2) - simpleEighthGap) < 0.001)
    }

    @Test func currentHighlightStateSplitsMixedTieContinuationAndAttackEvent() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.mixedTieContinuationAndAttackMusicXML,
            sourceName: "mixed-tie.musicxml"
        )
        let mixedEvent = try #require(loaded.playbackEvents.first {
            $0.midiPitches == [69] && $0.noteIDs.count > $0.midiPitches.count
        })

        let highlight = CurrentNoteHighlightState.make(event: mixedEvent, layout: loaded.layout)

        #expect(highlight.attackMIDIPitches == [69])
        #expect(highlight.continuationMIDIPitches.contains(48))
        #expect(highlight.attackNoteIDs.count == 1)
        #expect(!highlight.continuationNoteIDs.isEmpty)
        #expect(!highlight.isRest)
        #expect(highlight.scoreFollowNoteIDs == highlight.attackNoteIDs)
    }

    @Test func currentHighlightStateHandlesContinuationOnlyAndRestEvents() throws {
        let loaded = try PaletteScoreLoader().load(
            data: Self.continuationOnlyAndRestMusicXML,
            sourceName: "continuation-rest.musicxml"
        )
        let continuationOnly = try #require(loaded.playbackEvents.first {
            $0.isTiedContinuation && $0.midiPitches.isEmpty && !$0.noteIDs.isEmpty
        })
        let continuationHighlight = CurrentNoteHighlightState.make(event: continuationOnly, layout: loaded.layout)

        #expect(continuationHighlight.attackNoteIDs.isEmpty)
        #expect(!continuationHighlight.continuationNoteIDs.isEmpty)
        #expect(!continuationHighlight.scoreFollowNoteIDs.isEmpty)

        let loader = PaletteScoreLoader()
        let input = try loader.scoreInput(for: "continuation-rest.musicxml", data: Self.continuationOnlyAndRestMusicXML)
        let parsed = try loader.renderer.parseWithDiagnostics(input: input)
        let restLayout = try loader.renderer.layout(score: parsed.score)
        let eventsWithRests = loader.renderer.makePlaybackSequence(
            score: parsed.score,
            options: PlaybackOptions(includeRests: true)
        )
        let rest = try #require(eventsWithRests.first {
            $0.midiPitches.isEmpty && !$0.isTiedContinuation && !$0.noteIDs.isEmpty
        })
        let restHighlight = CurrentNoteHighlightState.make(event: rest, layout: restLayout)

        #expect(restHighlight.attackNoteIDs.isEmpty)
        #expect(restHighlight.continuationNoteIDs.isEmpty)
        #expect(restHighlight.isRest)
    }

    @Test @MainActor func practiceModeMovesByPlaybackEventAndTracksCurrentNoteID() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "practice.musicxml")
        let first = try #require(session.playbackCursor.currentNoteID)

        session.setPracticeModeEnabled(true)
        #expect(session.isPracticeModeEnabled)
        #expect(session.currentNoteIDs == [first])

        session.movePracticeStep(by: 1)
        let second = try #require(session.playbackCursor.currentNoteID)
        #expect(second != first)
        #expect(session.currentNoteIDs == [second])

        session.resetPractice()
        #expect(session.playbackCursor.currentNoteID == first)
        #expect(session.practiceStepSummary.contains("練習 1/"))
    }

    @Test @MainActor func practiceModeStopsPlaybackAndDisablesBeforeNormalPlay() throws {
        let audio = ScoreSessionMockAudioEngine()
        let runtime = PalettePlaybackRuntime(audioEngine: audio)
        let session = PaletteScoreSession(playbackRuntime: runtime)
        try session.load(data: Self.validMusicXML, sourceName: "practice.musicxml")

        session.play()
        #expect(session.playbackState == .playing)

        session.setPracticeModeEnabled(true)
        #expect(session.isPracticeModeEnabled)
        #expect(session.playbackState == .stopped)
        #expect(audio.silenceCount > 0)

        session.play()
        #expect(!session.isPracticeModeEnabled)
        #expect(session.playbackState == .playing)
    }

    @Test @MainActor func practiceStepSyncsRuntimeBeforeNormalPlayback() throws {
        let audio = ScoreSessionMockAudioEngine()
        let runtime = PalettePlaybackRuntime(audioEngine: audio)
        let session = PaletteScoreSession(playbackRuntime: runtime)
        try session.load(data: Self.validMusicXML, sourceName: "practice.musicxml")

        session.setPracticeModeEnabled(true)
        session.movePracticeStep(by: 1)
        let practicedEvent = try #require(session.currentPlaybackEvent)

        #expect(runtime.currentEventIndex == 1)

        session.play()
        runtime.triggerAudioForCurrentEvent()

        #expect(!session.isPracticeModeEnabled)
        #expect(runtime.currentEventIndex == 1)
        #expect(audio.playedPitches.last == practicedEvent.midiPitches)
    }

    @Test @MainActor func practiceModeSelectsTappedNoteAndResetsOnImport() throws {
        let session = PaletteScoreSession()
        try session.load(data: Self.validMusicXML, sourceName: "practice.musicxml")
        let loaded = try #require(session.loadedScore)
        let secondNoteID = try #require(loaded.playbackEvents.dropFirst().first?.noteIDs.first)
        let noteLayout = try #require(loaded.layout.noteLayout(for: secondNoteID))

        session.setPracticeModeEnabled(true)
        session.handleTap(loaded.layout.hitTest(point: noteLayout.noteheadCenter, radius: 24))
        #expect(session.playbackCursor.currentNoteID == secondNoteID)
        #expect(session.currentNoteIDs == [secondNoteID])

        try session.load(data: Self.validMusicXML, sourceName: "reloaded.musicxml")
        #expect(!session.isPracticeModeEnabled)
        #expect(session.playbackCursor.index == 0)
    }

    @Test func paletteSelectionDoesNotChangeLayoutOrPlaybackIdentity() throws {
        let loaded = try PaletteScoreLoader().load(data: Self.validMusicXML, sourceName: "palette.musicxml")
        let noteIDs = Set(loaded.layout.noteByID.keys)
        let playbackIdentity = loaded.playbackEvents.map {
            "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)|\($0.nominalDuration.ticks)"
        }

        _ = PaletteStyleFactory.makeStyle(noteColorVisible: true, staffColorVisible: true, paletteKind: .educational)
        _ = PaletteStyleFactory.makeStyle(noteColorVisible: true, staffColorVisible: true, paletteKind: .muted)

        #expect(Set(loaded.layout.noteByID.keys) == noteIDs)
        #expect(loaded.playbackEvents.map {
            "\($0.noteIDs.map(\.rawValue).joined(separator: ","))|\($0.onset.ticks)|\($0.nominalDuration.ticks)"
        } == playbackIdentity)
    }

    @Test func libraryItemEncodingDoesNotContainScoreContents() throws {
        let item = LibraryItem.imported(
            displayName: "metadata.musicxml",
            sourceURL: URL(fileURLWithPath: "/tmp/metadata.musicxml"),
            openedAt: Date(),
            bookmarkData: Data([1, 2, 3]),
            diagnosticsSummary: nil,
            currentNoteID: NoteID(rawValue: "note-metadata"),
            zoomScale: 1.0
        )

        let data = try JSONEncoder().encode(item)
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("<score-partwise"))
        #expect(!json.contains(String(decoding: Self.validMusicXML, as: UTF8.self)))
    }

    static let validMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Unit</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let chordMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Chord</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
          <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let mixedTieContinuationAndAttackMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Mixed tie</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note>
            <pitch><step>C</step><octave>3</octave></pitch>
            <duration>4</duration><voice>1</voice><type>whole</type>
            <tie type="start"/>
          </note>
        </measure>
        <measure number="2">
          <note>
            <pitch><step>C</step><octave>3</octave></pitch>
            <duration>1</duration><voice>1</voice><type>quarter</type>
            <tie type="stop"/>
          </note>
          <note>
            <chord/>
            <pitch><step>A</step><octave>4</octave></pitch>
            <duration>1</duration><voice>1</voice><type>quarter</type>
          </note>
          <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    static let continuationOnlyAndRestMusicXML = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list><score-part id="P1"><part-name>Continuation</part-name></score-part></part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <clef><sign>G</sign><line>2</line></clef>
          </attributes>
          <note>
            <pitch><step>C</step><octave>3</octave></pitch>
            <duration>4</duration><voice>1</voice><type>whole</type>
            <tie type="start"/>
          </note>
        </measure>
        <measure number="2">
          <note>
            <pitch><step>C</step><octave>3</octave></pitch>
            <duration>1</duration><voice>1</voice><type>quarter</type>
            <tie type="stop"/>
          </note>
          <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
        </measure>
      </part>
    </score-partwise>
    """.utf8)

    private static func fixtureData(_ fileName: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = projectRoot
            .appendingPathComponent("TestImportFiles")
            .appendingPathComponent(fileName)
        return try Data(contentsOf: fixtureURL)
    }

    private static func appSampleData(_ fileName: String) throws -> Data {
        try appSampleDataForKeyboardTests(fileName)
    }

    static func appSampleDataForKeyboardTests(_ fileName: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sampleURL = projectRoot
            .appendingPathComponent("DoReMiPalette")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Samples")
            .appendingPathComponent(fileName)
        return try Data(contentsOf: sampleURL)
    }

    private static func quarterNotes(for time: MusicalTime) -> Double {
        Double(time.ticks) / Double(time.ticksPerQuarterNote)
    }

    private static func temporaryURL(fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DoReMiPaletteTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private struct StubLibraryFileResolver: LibraryFileResolving {
        var result: Result<LibraryResolvedFile, Error>

        func resolveFile(for item: LibraryItem) throws -> LibraryResolvedFile {
            try result.get()
        }
    }

    private final class ScoreSessionMockAudioEngine: PaletteAudioEngine {
        private(set) var silenceCount = 0
        private(set) var playedPitches: [[Int]] = []
        private(set) var lastFailure: Error?

        func start() throws {}

        func stop() {
            silence()
        }

        func silence() {
            silenceCount += 1
        }

        func play(midiPitches: [Int], duration: TimeInterval, velocity: Double) {
            playedPitches.append(midiPitches)
        }

        func play(event: PlaybackEvent, tempoBPM: Double, velocity: Double) {
            guard !event.midiPitches.isEmpty else {
                silence()
                return
            }
        }
    }
}
