import DoReMiRendererKit
import Foundation

private struct Arguments {
    var inputPath: String?
    var outputPath = "score-web.json"
    var width = 1024.0

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
                NSLocalizedDescriptionKey: "Usage: DoReMiRendererWebExport --input <score.musicxml|score.mxl> [--output score-web.json] [--width 1024]"
            ])
        }

        let inputURL = URL(fileURLWithPath: inputPath)
        let data = try Data(contentsOf: inputURL)
        let renderer = DoReMiRenderer()
        let input: ScoreInput = inputURL.pathExtension.lowercased() == "mxl" ? .mxlData(data) : .musicXMLData(data)
        let score = try renderer.parse(input: input)
        let layout = try renderer.layout(score: score, options: renderer.webLayoutOptions(containerWidth: arguments.width))
        let plan = renderer.makeWebRenderPlan(score: score, layout: layout)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputURL = URL(fileURLWithPath: arguments.outputPath)
        try encoder.encode(plan).write(to: outputURL, options: .atomic)
        print("Wrote \(outputURL.path) commands=\(plan.commands.count) noteAnchors=\(plan.noteAnchors.count)")
    }
}
