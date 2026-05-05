import Foundation

@main
enum DoReMiRendererDiagnosticsCommand {
    static func main() throws {
        let arguments = CommandArguments.parse(CommandLine.arguments.dropFirst())
        let scanner = MusicXMLSampleScanner()
        let scan = scanner.scan(inputDirectory: arguments.inputDirectory)
        let result = MusicXMLDiagnosticsCollector().collect(scan: scan)
        let report = MusicXMLCompatibilityReport().makeMarkdown(result: result)

        try FileManager.default.createDirectory(
            at: arguments.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try report.write(to: arguments.outputURL, atomically: true, encoding: .utf8)
        print("Wrote \(arguments.outputURL.path)")
    }
}

private struct CommandArguments {
    let inputDirectory: URL
    let outputURL: URL

    static func parse(_ rawArguments: ArraySlice<String>) -> CommandArguments {
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var inputDirectory = URL(fileURLWithPath: "LocalSamples", relativeTo: workingDirectory)
        var outputURL = URL(fileURLWithPath: "MUSICXML_COMPATIBILITY_REPORT.md", relativeTo: workingDirectory)

        var index = rawArguments.startIndex
        while index < rawArguments.endIndex {
            let argument = rawArguments[index]
            let nextIndex = rawArguments.index(after: index)
            switch argument {
            case "--input" where nextIndex < rawArguments.endIndex:
                inputDirectory = URL(fileURLWithPath: rawArguments[nextIndex], relativeTo: workingDirectory)
                index = rawArguments.index(after: nextIndex)
            case "--output" where nextIndex < rawArguments.endIndex:
                outputURL = URL(fileURLWithPath: rawArguments[nextIndex], relativeTo: workingDirectory)
                index = rawArguments.index(after: nextIndex)
            default:
                index = nextIndex
            }
        }

        return CommandArguments(
            inputDirectory: inputDirectory.standardizedFileURL,
            outputURL: outputURL.standardizedFileURL
        )
    }
}
