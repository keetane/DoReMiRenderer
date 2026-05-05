import DoReMiRendererKit
import Foundation

enum PaletteImportError: LocalizedError, Equatable {
    case unsupportedExtension(String)
    case bundledSampleMissing(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let fileExtension):
            return "対応していないファイル形式です: .\(fileExtension)"
        case .bundledSampleMissing(let name):
            return "\(name) がアプリ内に見つかりません。"
        }
    }
}

struct PaletteLoadedScore {
    let sourceName: String
    let score: ScoreDocument
    let layout: ScoreLayout
    let diagnostics: [RendererDiagnostic]
    let playbackEvents: [PlaybackEvent]
    let playbackMetadata: PlaybackMetadata
}

struct PaletteScoreLoader {
    var renderer = DoReMiRenderer(
        configuration: RendererConfiguration(unsupportedFeaturePolicy: .ignoreWithWarning)
    )

    func load(data: Data, sourceName: String) throws -> PaletteLoadedScore {
        let input = try scoreInput(for: sourceName, data: data)
        let parseResult = try renderer.parseWithDiagnostics(input: input)
        let layoutResult = try renderer.layoutWithDiagnostics(
            score: parseResult.score,
            options: LayoutOptions(
                pageWidth: 980,
                staffSpace: 16,
                systemSpacing: 96,
                measureSpacing: 36
            )
        )
        let playbackEvents = renderer.makePlaybackSequence(score: parseResult.score, options: .default)
        let playbackMetadata = renderer.makePlaybackMetadata(score: parseResult.score)
        return PaletteLoadedScore(
            sourceName: sourceName,
            score: parseResult.score,
            layout: layoutResult.layout,
            diagnostics: parseResult.diagnostics + layoutResult.diagnostics + playbackMetadata.diagnostics,
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

