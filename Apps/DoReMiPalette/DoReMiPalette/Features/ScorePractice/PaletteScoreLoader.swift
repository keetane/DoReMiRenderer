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

    func load(data: Data, sourceName: String) throws -> PaletteLoadedScore {
        let input = try scoreInput(for: sourceName, data: data)
        let parseResult = try renderer.parseWithDiagnostics(input: input)
        let horizontalLayoutResult = try renderer.layoutWithDiagnostics(
            score: parseResult.score,
            options: LayoutOptions(
                pageWidth: 980,
                staffSpace: 16,
                systemSpacing: 96,
                measureSpacing: 36,
                displayMode: .horizontal
            )
        )
        let a4LayoutResult = try renderer.layoutWithDiagnostics(
            score: parseResult.score,
            options: LayoutOptions(
                pageWidth: 595,
                pageHeight: 842,
                staffSpace: 12,
                systemSpacing: 72,
                measureSpacing: 24,
                displayMode: .print,
                showPageMargins: true
            )
        )
        let playbackEvents = renderer.makePlaybackSequence(
            score: parseResult.score,
            options: PlaybackOptions(includeRests: true)
        )
        let playbackMetadata = renderer.makePlaybackMetadata(score: parseResult.score)
        return PaletteLoadedScore(
            sourceName: sourceName,
            score: parseResult.score,
            horizontalLayout: horizontalLayoutResult.layout,
            a4Layout: a4LayoutResult.layout,
            layoutMode: .horizontal,
            diagnostics: parseResult.diagnostics + horizontalLayoutResult.diagnostics + a4LayoutResult.diagnostics + playbackMetadata.diagnostics,
            playbackEvents: playbackEvents,
            playbackMetadata: playbackMetadata
        )
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
