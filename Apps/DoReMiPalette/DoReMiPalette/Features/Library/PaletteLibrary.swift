import DoReMiRendererKit
import Foundation

enum LibrarySourceType: String, Codable, Hashable {
    case sample
    case imported
}

struct DiagnosticsSummary: Codable, Hashable {
    var errors: Int
    var warnings: Int
    var infos: Int
    var codes: [String]

    init(diagnostics: [RendererDiagnostic]) {
        var errors = 0
        var warnings = 0
        var infos = 0
        for diagnostic in diagnostics {
            switch diagnostic.severity {
            case .error:
                errors += 1
            case .warning:
                warnings += 1
            case .info:
                infos += 1
            }
        }
        self.errors = errors
        self.warnings = warnings
        self.infos = infos
        self.codes = Array(Set(diagnostics.map(\.code))).sorted()
    }
}

struct LibraryItem: Codable, Hashable, Identifiable {
    var id: UUID
    var displayName: String
    var sourceType: LibrarySourceType
    var sourceIdentifier: String
    var lastOpenedAt: Date
    var bookmarkData: Data?
    var diagnosticsSummary: DiagnosticsSummary?
    var lastCurrentNoteIDRawValue: String?
    var lastZoomScale: Double?

    static func sample(from sample: SampleScoreItem, openedAt: Date = Date()) -> LibraryItem {
        LibraryItem(
            id: sample.id,
            displayName: sample.displayName,
            sourceType: .sample,
            sourceIdentifier: sample.sourceIdentifier,
            lastOpenedAt: openedAt,
            bookmarkData: nil,
            diagnosticsSummary: nil,
            lastCurrentNoteIDRawValue: nil,
            lastZoomScale: nil
        )
    }

    static func imported(
        displayName: String,
        sourceURL: URL,
        openedAt: Date,
        bookmarkData: Data?,
        diagnosticsSummary: DiagnosticsSummary?,
        currentNoteID: NoteID?,
        zoomScale: Double?
    ) -> LibraryItem {
        LibraryItem(
            id: UUID(),
            displayName: displayName,
            sourceType: .imported,
            sourceIdentifier: Self.importedSourceIdentifier(for: sourceURL),
            lastOpenedAt: openedAt,
            bookmarkData: bookmarkData,
            diagnosticsSummary: diagnosticsSummary,
            lastCurrentNoteIDRawValue: currentNoteID?.rawValue,
            lastZoomScale: zoomScale
        )
    }

    static func importedSourceIdentifier(for url: URL) -> String {
        "imported:\(url.standardizedFileURL.path)"
    }
}

struct SampleScoreItem: Codable, Hashable, Identifiable {
    var id: UUID
    var displayName: String
    var resourceName: String
    var fileExtension: String

    var sourceIdentifier: String {
        "sample:\(resourceName).\(fileExtension)"
    }

    func url(in bundle: Bundle) -> URL? {
        bundle.url(forResource: resourceName, withExtension: fileExtension)
    }
}

struct SampleScoreCatalog: Hashable {
    var samples: [SampleScoreItem]

    static let `default` = SampleScoreCatalog(samples: [
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            displayName: "DoReMi Palette Sample",
            resourceName: "phase12_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000018")!,
            displayName: "S9 Repeat Visuals Sample",
            resourceName: "s9_repeat_visuals_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000019")!,
            displayName: "S10 D.C. al Fine Sample",
            resourceName: "s10_dc_fine_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001A")!,
            displayName: "S10 D.S. al Fine Sample",
            resourceName: "s10_ds_fine_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001B")!,
            displayName: "S10 D.C. al Coda Sample",
            resourceName: "s10_dc_coda_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001C")!,
            displayName: "S10 D.S. al Coda Sample",
            resourceName: "s10_ds_coda_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001D")!,
            displayName: "S10 Repeat Diagnostics Sample",
            resourceName: "s10_repeat_diagnostics_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001E")!,
            displayName: "S10 All Repeat Symbols Sample",
            resourceName: "s10_all_repeat_symbols_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
            displayName: "T2 Transpose Key Sample",
            resourceName: "t2_transpose_key_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
            displayName: "T2 Transpose Accidentals Sample",
            resourceName: "t2_transpose_accidentals_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
            displayName: "T2 MusicXML Transpose Sample",
            resourceName: "t2_musicxml_transpose_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!,
            displayName: "S8 Repeat Endings Sample",
            resourceName: "s8_repeat_endings_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!,
            displayName: "S7 Repeat Playback Sample",
            resourceName: "s7_repeat_playback_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!,
            displayName: "S6 Notation Refinement Sample",
            resourceName: "s6_notation_refinement_grand_staff",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            displayName: "Rhythm Values Sample",
            resourceName: "rhythm_values_sample",
            fileExtension: "musicxml"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
            displayName: "Notation Coverage Sample",
            resourceName: "notation_coverage_grand_staff",
            fileExtension: "musicxml"
        )
    ])

    var defaultSample: SampleScoreItem? {
        samples.first
    }

    func libraryItems(openedAt: Date = Date(timeIntervalSince1970: 0)) -> [LibraryItem] {
        samples.map { LibraryItem.sample(from: $0, openedAt: openedAt) }
    }
}

struct LibraryCollection: Hashable {
    var sampleItems: [LibraryItem]
    var importedItems: [LibraryItem]

    var allItems: [LibraryItem] {
        sampleItems + importedItems.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    mutating func upsertImported(_ item: LibraryItem) {
        guard item.sourceType == .imported else {
            return
        }
        if let index = importedItems.firstIndex(where: { $0.sourceIdentifier == item.sourceIdentifier }) {
            var updated = item
            updated.id = importedItems[index].id
            importedItems[index] = updated
        } else {
            importedItems.append(item)
        }
    }

    mutating func removeImported(id: UUID) {
        importedItems.removeAll { $0.id == id }
    }
}

struct LibraryResolvedFile {
    var url: URL
    var securityScoped: Bool
    var bookmarkDataIsStale: Bool
}

protocol LibraryFileResolving {
    func resolveFile(for item: LibraryItem) throws -> LibraryResolvedFile
}

struct SecurityScopedLibraryFileResolver: LibraryFileResolving {
    func resolveFile(for item: LibraryItem) throws -> LibraryResolvedFile {
        guard let bookmarkData = item.bookmarkData else {
            throw PaletteImportError.missingLibraryFile(item.displayName)
        }

        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PaletteImportError.missingLibraryFile(item.displayName)
            }
            return LibraryResolvedFile(url: url, securityScoped: true, bookmarkDataIsStale: stale)
        } catch let error as PaletteImportError {
            throw error
        } catch {
            throw PaletteImportError.missingLibraryFile(item.displayName)
        }
    }
}

struct LibraryStore {
    private struct Payload: Codable {
        var importedItems: [LibraryItem]
    }

    var fileURL: URL

    static let `default` = LibraryStore(
        fileURL: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("DoReMiPalette", isDirectory: true)
            .appendingPathComponent("library.json")
    )

    func loadImportedItems() -> [LibraryItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        do {
            return try JSONDecoder.paletteLibrary.decode(Payload.self, from: data).importedItems
        } catch {
            return []
        }
    }

    func saveImportedItems(_ importedItems: [LibraryItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.paletteLibrary.encode(Payload(importedItems: importedItems))
        try data.write(to: fileURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var paletteLibrary: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var paletteLibrary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
