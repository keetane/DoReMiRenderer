import DoReMiRendererKit
import Foundation

enum PaletteImportError: LocalizedError, Equatable {
    case unsupportedExtension(String)
    case bundledSampleMissing(String)
    case missingLibraryFile(String)
    case unsupportedLibraryItem(String)
    case emptyFile(String)
    case fileTooLarge(String, maxMegabytes: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let fileExtension):
            return "対応していないファイル形式です: .\(fileExtension)"
        case .bundledSampleMissing(let name):
            return "\(name) がアプリ内に見つかりません。"
        case .missingLibraryFile(let name):
            return "\(name) を開けませんでした。ファイルを再選択してください。"
        case .unsupportedLibraryItem(let name):
            return "\(name) はライブラリから開けません。"
        case .emptyFile(let name):
            return "\(name) は空のファイルです。MusicXML または MXL ファイルを選択してください。"
        case .fileTooLarge(let name, let maxMegabytes):
            return "\(name) は大きすぎます。\(maxMegabytes)MB以下のMusicXMLまたはMXLファイルを選択してください。"
        }
    }
}

struct PaletteLoadedScore {
    let sourceName: String
    let score: ScoreDocument
    let horizontalLayout: ScoreLayout
    let a4Layout: ScoreLayout
    var layoutMode: PaletteScoreLayoutMode
    let diagnostics: [RendererDiagnostic]
    let baseDiagnostics: [RendererDiagnostic]
    let playbackEvents: [PlaybackEvent]
    let playbackMetadata: PlaybackMetadata

    var layout: ScoreLayout {
        switch layoutMode {
        case .horizontal:
            horizontalLayout
        case .a4, .track:
            a4Layout
        }
    }

    var printLayout: ScoreLayout {
        a4Layout
    }

    var performancePreferredLayoutMode: PaletteScoreLayoutMode {
        let measureCount = score.parts.map(\.measures.count).max() ?? 0
        if horizontalLayout.canvasSize.width > 16_000 || measureCount > 64 {
            return .a4
        }
        return layoutMode
    }

    var displayName: String {
        if let title = score.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return sourceName
    }
}

enum PaletteScoreLayoutMode: String, CaseIterable, Identifiable {
    case horizontal
    case a4
    case track

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal:
            "横一段"
        case .a4:
            "A4"
        case .track:
            "トラック"
        }
    }

    static func fromRawValue(_ rawValue: String) -> PaletteScoreLayoutMode {
        PaletteScoreLayoutMode(rawValue: rawValue) ?? .a4
    }
}

struct PaletteScoreLoader {
    static let maximumInputBytes = 50 * 1_024 * 1_024
    static let maximumInputMegabytes = 50

    var renderer = DoReMiRenderer(
        configuration: RendererConfiguration(unsupportedFeaturePolicy: .ignoreWithWarning)
    )

    func load(
        data: Data,
        sourceName: String,
        displayTitle: String? = nil,
        displayTransposeSemitones: Int = 0
    ) throws -> PaletteLoadedScore {
        try validateInputData(data, sourceName: sourceName)
        let input = try scoreInput(for: sourceName, data: data)
        let parseResult = try renderer.parseWithDiagnostics(input: input)
        let score = scoreWithDisplayTitle(parseResult.score, sourceName: sourceName, displayTitle: displayTitle)
        let layouts = try makeLayouts(score: score, displayTransposeSemitones: displayTransposeSemitones)
        let playbackEvents = renderer.makePlaybackSequence(
            score: score,
            options: PlaybackOptions(includeRests: true)
        )
        let playbackMetadata = renderer.makePlaybackMetadata(score: score)
        let baseDiagnostics = parseResult.diagnostics + playbackMetadata.diagnostics
        return PaletteLoadedScore(
            sourceName: sourceName,
            score: score,
            horizontalLayout: layouts.horizontal.layout,
            a4Layout: layouts.a4.layout,
            layoutMode: Self.initialLayoutMode(
                score: score,
                horizontalLayout: layouts.horizontal.layout
            ),
            diagnostics: baseDiagnostics + layouts.horizontal.diagnostics + layouts.a4.diagnostics,
            baseDiagnostics: baseDiagnostics,
            playbackEvents: playbackEvents,
            playbackMetadata: playbackMetadata
        )
    }

    private func scoreWithDisplayTitle(
        _ score: ScoreDocument,
        sourceName: String,
        displayTitle: String?
    ) -> ScoreDocument {
        if let title = score.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return score
        }
        let resolvedTitle = preferredDisplayTitle(displayTitle, sourceName: sourceName)
        return ScoreDocument(parts: score.parts, title: resolvedTitle)
    }

    private func preferredDisplayTitle(_ displayTitle: String?, sourceName: String) -> String {
        if let displayTitle = displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayTitle.isEmpty {
            return displayTitle
        }
        let filename = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
        let normalized = filename
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? sourceName : normalized
    }

    func relayout(_ loaded: PaletteLoadedScore, displayTransposeSemitones: Int) throws -> PaletteLoadedScore {
        let layouts = try makeLayouts(score: loaded.score, displayTransposeSemitones: displayTransposeSemitones)
        return PaletteLoadedScore(
            sourceName: loaded.sourceName,
            score: loaded.score,
            horizontalLayout: layouts.horizontal.layout,
            a4Layout: layouts.a4.layout,
            layoutMode: loaded.layoutMode,
            diagnostics: loaded.baseDiagnostics + layouts.horizontal.diagnostics + layouts.a4.diagnostics,
            baseDiagnostics: loaded.baseDiagnostics,
            playbackEvents: loaded.playbackEvents,
            playbackMetadata: loaded.playbackMetadata
        )
    }

    private func makeLayouts(
        score: ScoreDocument,
        displayTransposeSemitones: Int
    ) throws -> (horizontal: ScoreLayoutResult, a4: ScoreLayoutResult) {
        let horizontalLayoutResult = try renderer.layoutWithDiagnostics(
            score: score,
            options: LayoutOptions(
                pageWidth: 980,
                staffSpace: 16,
                systemSpacing: 96,
                measureSpacing: 0,
                displayMode: .horizontal,
                displayTransposeSemitones: displayTransposeSemitones
            )
        )
        let a4LayoutResult = try renderer.layoutWithDiagnostics(
            score: score,
            options: LayoutOptions(
                pageWidth: 595,
                pageHeight: 842,
                staffSpace: 8,
                systemSpacing: 48,
                measureSpacing: 0,
                displayMode: .print,
                showPageMargins: true,
                displayTransposeSemitones: displayTransposeSemitones
            )
        )
        return (horizontalLayoutResult, a4LayoutResult)
    }

    private static func initialLayoutMode(score _: ScoreDocument, horizontalLayout _: ScoreLayout) -> PaletteScoreLayoutMode {
        return .a4
    }

    func scoreInput(for fileName: String, data: Data) throws -> ScoreInput {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "musicxml", "xml":
            try validateInputData(data, sourceName: fileName)
            return .musicXMLData(data)
        case "mxl":
            try validateInputData(data, sourceName: fileName)
            return .mxlData(data)
        default:
            throw PaletteImportError.unsupportedExtension(ext.isEmpty ? fileName : ext)
        }
    }

    func validateInputFile(at url: URL) throws {
        let name = url.lastPathComponent
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile != false else {
            throw PaletteImportError.unsupportedLibraryItem(name)
        }
        if values.fileSize == 0 {
            throw PaletteImportError.emptyFile(name)
        }
        if let fileSize = values.fileSize, fileSize > Self.maximumInputBytes {
            throw PaletteImportError.fileTooLarge(name, maxMegabytes: Self.maximumInputMegabytes)
        }
    }

    private func validateInputData(_ data: Data, sourceName: String) throws {
        if data.isEmpty {
            throw PaletteImportError.emptyFile(sourceName)
        }
        if data.count > Self.maximumInputBytes {
            throw PaletteImportError.fileTooLarge(sourceName, maxMegabytes: Self.maximumInputMegabytes)
        }
    }
}
