import DoReMiRendererKit
import Foundation

enum PaletteImportError: LocalizedError, Equatable {
    case unsupportedExtension(String)
    case bundledSampleMissing(String)
    case missingLibraryFile(String)
    case unsupportedLibraryItem(String)

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
        case .a4:
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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal:
            "横一段"
        case .a4:
            "A4"
        }
    }

    static func fromRawValue(_ rawValue: String) -> PaletteScoreLayoutMode {
        PaletteScoreLayoutMode(rawValue: rawValue) ?? .horizontal
    }
}

struct PaletteScoreLoader {
    var renderer = DoReMiRenderer(
        configuration: RendererConfiguration(unsupportedFeaturePolicy: .ignoreWithWarning)
    )

    func load(data: Data, sourceName: String, displayTransposeSemitones: Int = 0) throws -> PaletteLoadedScore {
        let input = try scoreInput(for: sourceName, data: data)
        let parseResult = try renderer.parseWithDiagnostics(input: input)
        let layouts = try makeLayouts(score: parseResult.score, displayTransposeSemitones: displayTransposeSemitones)
        let playbackEvents = renderer.makePlaybackSequence(
            score: parseResult.score,
            options: PlaybackOptions(includeRests: true)
        )
        let playbackMetadata = renderer.makePlaybackMetadata(score: parseResult.score)
        let baseDiagnostics = parseResult.diagnostics + playbackMetadata.diagnostics
        return PaletteLoadedScore(
            sourceName: sourceName,
            score: parseResult.score,
            horizontalLayout: layouts.horizontal.layout,
            a4Layout: layouts.a4.layout,
            layoutMode: Self.initialLayoutMode(
                score: parseResult.score,
                horizontalLayout: layouts.horizontal.layout
            ),
            diagnostics: baseDiagnostics + layouts.horizontal.diagnostics + layouts.a4.diagnostics,
            baseDiagnostics: baseDiagnostics,
            playbackEvents: playbackEvents,
            playbackMetadata: playbackMetadata
        )
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
                measureSpacing: 36,
                displayMode: .horizontal,
                displayTransposeSemitones: displayTransposeSemitones
            )
        )
        let a4LayoutResult = try renderer.layoutWithDiagnostics(
            score: score,
            options: LayoutOptions(
                pageWidth: 595,
                pageHeight: 842,
                staffSpace: 12,
                systemSpacing: 72,
                measureSpacing: 24,
                displayMode: .print,
                showPageMargins: true,
                displayTransposeSemitones: displayTransposeSemitones
            )
        )
        return (horizontalLayoutResult, a4LayoutResult)
    }

    private static func initialLayoutMode(score: ScoreDocument, horizontalLayout: ScoreLayout) -> PaletteScoreLayoutMode {
        let measureCount = score.parts.map(\.measures.count).max() ?? 0
        if horizontalLayout.canvasSize.width > 16_000 || measureCount > 64 {
            return .a4
        }
        return .horizontal
    }

    func scoreInput(for fileName: String, data: Data) throws -> ScoreInput {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "musicxml", "xml":
            return .musicXMLData(data)
        case "mxl":
            return .mxlData(data)
        default:
            throw PaletteImportError.unsupportedExtension(ext.isEmpty ? fileName : ext)
        }
    }
}
