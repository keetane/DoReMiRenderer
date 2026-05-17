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
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            displayName: "Canon in D",
            resourceName: "Canon_in_D",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            displayName: "Fur Elise - Beginner Piano",
            resourceName: "Fur_Elise_-_Beethoven_-_for_beginner_piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
            displayName: "Happy Birthday To You Piano",
            resourceName: "Happy_Birthday_To_You_Piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
            displayName: "Ode to Joy Easy Variation",
            resourceName: "Ode_to_Joy_Easy_variation",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000106")!,
            displayName: "The Entertainer",
            resourceName: "The_Entertainer_-_Scott_Joplin_-_1902",
            fileExtension: "mxl"
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
