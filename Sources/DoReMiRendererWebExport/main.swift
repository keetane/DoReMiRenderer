import DoReMiRendererKit
import Foundation

private struct Arguments {
    var inputPath: String?
    var outputPath = "score-web.json"
    var width = 1024.0
    /// Total number of chromatic transpose choices, capped at one octave.
    /// Twelve choices include the written key exactly once.
    var transposeOptionCount = 12

    init(_ values: [String]) {
        var iterator = values.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--input":
                inputPath = iterator.next()
            case "--output":
                if let value = iterator.next() { outputPath = value }
            case "--width":
                if let value = iterator.next(), let parsed = Double(value) { width = parsed }
            case "--transpose-range":
                if let value = iterator.next(), let parsed = Int(value) {
                    transposeOptionCount = min(max(parsed, 1), 12)
                }
            default:
                continue
            }
        }
    }
}

@main
struct DoReMiRendererWebExportCommand {
    static func main() throws {
        let arguments = Arguments(CommandLine.arguments)
        guard let inputPath = arguments.inputPath else {
            throw NSError(domain: "DoReMiRendererWebExport", code: 64, userInfo: [
                NSLocalizedDescriptionKey: "Usage: DoReMiRendererWebExport --input <score.musicxml|score.mxl> [--output score-web.json] [--width 1024] [--transpose-range 12]"
            ])
        }

        let inputURL = URL(fileURLWithPath: inputPath)
        let data = try Data(contentsOf: inputURL)
        let renderer = DoReMiRenderer()
        let input: ScoreInput = inputURL.pathExtension.lowercased() == "mxl" ? .mxlData(data) : .musicXMLData(data)
        let score = try renderer.parse(input: input)
        let bundle = try renderer.makeWebRenderBundle(
            score: score,
            containerWidth: arguments.width,
            displayTransposeRange: {
                let lower = -(arguments.transposeOptionCount / 2)
                return lower...(lower + arguments.transposeOptionCount - 1)
            }()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputURL = URL(fileURLWithPath: arguments.outputPath)
        try encoder.encode(bundle).write(to: outputURL, options: .atomic)
        print("Wrote \(outputURL.path) commands=\(bundle.primaryPlan.commands.count) noteAnchors=\(bundle.primaryPlan.noteAnchors.count) transposeVariants=\(bundle.transposeVariants.count)")
    }
}
