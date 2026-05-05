import DoReMiRendererKit
import Foundation

public enum MusicXMLSampleFormat: String, Hashable, Sendable {
    case musicxml
    case xml
    case mxl

    init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "musicxml":
            self = .musicxml
        case "xml":
            self = .xml
        case "mxl":
            self = .mxl
        default:
            return nil
        }
    }
}

public struct MusicXMLSampleFile: Hashable, Sendable {
    public let url: URL
    public let relativePath: String
    public let format: MusicXMLSampleFormat

    public init(url: URL, relativePath: String, format: MusicXMLSampleFormat) {
        self.url = url
        self.relativePath = relativePath
        self.format = format
    }
}

public struct MusicXMLSampleScan: Hashable, Sendable {
    public let inputDirectory: URL
    public let skippedMissingInputDirectory: Bool
    public let files: [MusicXMLSampleFile]

    public init(inputDirectory: URL, skippedMissingInputDirectory: Bool, files: [MusicXMLSampleFile]) {
        self.inputDirectory = inputDirectory
        self.skippedMissingInputDirectory = skippedMissingInputDirectory
        self.files = files
    }
}

public struct MusicXMLSampleScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(inputDirectory: URL) -> MusicXMLSampleScan {
        let standardizedDirectory = inputDirectory.standardizedFileURL
        guard isDirectory(standardizedDirectory) else {
            return MusicXMLSampleScan(
                inputDirectory: standardizedDirectory,
                skippedMissingInputDirectory: true,
                files: []
            )
        }

        guard let enumerator = fileManager.enumerator(
            at: standardizedDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return MusicXMLSampleScan(
                inputDirectory: standardizedDirectory,
                skippedMissingInputDirectory: false,
                files: []
            )
        }

        let files = enumerator.compactMap { entry -> MusicXMLSampleFile? in
            guard let url = entry as? URL,
                  isRegularFile(url),
                  let format = MusicXMLSampleFormat(pathExtension: url.pathExtension)
            else {
                return nil
            }
            return MusicXMLSampleFile(
                url: url,
                relativePath: relativePath(from: standardizedDirectory, to: url),
                format: format
            )
        }
        .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }

        return MusicXMLSampleScan(
            inputDirectory: standardizedDirectory,
            skippedMissingInputDirectory: false,
            files: files
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func relativePath(from directory: URL, to file: URL) -> String {
        let directoryPath = directory.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(directoryPath) else {
            return file.lastPathComponent
        }
        let startIndex = filePath.index(filePath.startIndex, offsetBy: directoryPath.count)
        return String(filePath[startIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

public struct MusicXMLFileDiagnostic: Hashable, Sendable {
    public let relativePath: String
    public let diagnostic: RendererDiagnostic

    public init(relativePath: String, diagnostic: RendererDiagnostic) {
        self.relativePath = relativePath
        self.diagnostic = diagnostic
    }
}

public struct MusicXMLCompatibilityResult: Hashable, Sendable {
    public let scan: MusicXMLSampleScan
    public let diagnostics: [MusicXMLFileDiagnostic]

    public init(scan: MusicXMLSampleScan, diagnostics: [MusicXMLFileDiagnostic]) {
        self.scan = scan
        self.diagnostics = diagnostics
    }
}

public struct MusicXMLDiagnosticsCollector: Sendable {
    private let renderer: DoReMiRenderer

    public init(renderer: DoReMiRenderer = DoReMiRenderer()) {
        self.renderer = renderer
    }

    public func collect(scan: MusicXMLSampleScan) -> MusicXMLCompatibilityResult {
        guard !scan.skippedMissingInputDirectory else {
            return MusicXMLCompatibilityResult(scan: scan, diagnostics: [])
        }

        var diagnostics: [MusicXMLFileDiagnostic] = []
        for file in scan.files {
            do {
                let data = try Data(contentsOf: file.url)
                let input: ScoreInput = file.format == .mxl ? .mxlData(data) : .musicXMLData(data)
                let result = try renderer.parseWithDiagnostics(input: input)
                diagnostics.append(contentsOf: result.diagnostics.map {
                    MusicXMLFileDiagnostic(relativePath: file.relativePath, diagnostic: $0)
                })
            } catch let error as RendererDiagnosticReporting {
                diagnostics.append(MusicXMLFileDiagnostic(relativePath: file.relativePath, diagnostic: error.diagnostic))
            } catch {
                diagnostics.append(MusicXMLFileDiagnostic(
                    relativePath: file.relativePath,
                    diagnostic: RendererDiagnostic(
                        severity: .error,
                        code: "diagnostics.readOrParseFailed",
                        message: error.localizedDescription
                    )
                ))
            }
        }

        return MusicXMLCompatibilityResult(scan: scan, diagnostics: diagnostics)
    }
}
