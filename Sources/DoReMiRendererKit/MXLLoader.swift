import Foundation
import ZIPFoundation

public enum ScoreInput: Sendable {
    case musicXMLData(Data)
    case mxlData(Data)
}

enum MXLLoaderError: Error, Hashable, Sendable, RendererDiagnosticReporting {
    case invalidZip(RendererDiagnostic)
    case missingContainer(RendererDiagnostic)
    case invalidContainer(RendererDiagnostic)
    case missingRootfile(RendererDiagnostic)
    case rootfileNotFound(RendererDiagnostic)
    case unsupportedArchive(RendererDiagnostic)

    var diagnostic: RendererDiagnostic {
        switch self {
        case .invalidZip(let diagnostic),
             .missingContainer(let diagnostic),
             .invalidContainer(let diagnostic),
             .missingRootfile(let diagnostic),
             .rootfileNotFound(let diagnostic),
             .unsupportedArchive(let diagnostic):
            diagnostic
        }
    }
}

struct MXLLoader: Sendable {
    func loadMusicXMLData(from data: Data) throws -> Data {
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw MXLLoaderError.invalidZip(diagnostic(
                code: "mxl.invalidZip",
                message: "MXL data is not a readable ZIP archive."
            ))
        }

        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw MXLLoaderError.missingContainer(diagnostic(
                code: "mxl.missingContainer",
                message: "MXL archive is missing META-INF/container.xml."
            ))
        }

        let containerData = try extract(containerEntry, from: archive)
        let rootfiles = try parseContainer(containerData)
        guard let rootfile = rootfiles.first(where: isMusicXMLRootfile) ?? rootfiles.first else {
            throw MXLLoaderError.missingRootfile(diagnostic(
                code: "mxl.missingRootfile",
                message: "MXL container.xml does not contain a rootfile."
            ))
        }

        guard let rootEntry = archive[rootfile.fullPath] else {
            throw MXLLoaderError.rootfileNotFound(diagnostic(
                code: "mxl.rootfileNotFound",
                message: "MXL rootfile was not found in the archive: \(rootfile.fullPath)."
            ))
        }

        return try extract(rootEntry, from: archive)
    }

    private func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var result = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                result.append(chunk)
            }
            return result
        } catch {
            throw MXLLoaderError.unsupportedArchive(diagnostic(
                code: "mxl.unsupportedArchive",
                message: "MXL archive entry could not be extracted. The compression method or file layout may be unsupported."
            ))
        }
    }

    private func parseContainer(_ data: Data) throws -> [MXLRootfile] {
        let delegate = MXLContainerParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw MXLLoaderError.invalidContainer(diagnostic(
                code: "mxl.invalidContainer",
                message: parser.parserError?.localizedDescription ?? "MXL container.xml is invalid."
            ))
        }
        return delegate.rootfiles
    }

    private func isMusicXMLRootfile(_ rootfile: MXLRootfile) -> Bool {
        let lowercasedPath = rootfile.fullPath.lowercased()
        let lowercasedMediaType = rootfile.mediaType?.lowercased() ?? ""
        return lowercasedMediaType.contains("musicxml")
            || lowercasedPath.hasSuffix(".musicxml")
            || lowercasedPath.hasSuffix(".xml")
    }

    private func diagnostic(code: String, message: String) -> RendererDiagnostic {
        RendererDiagnostic(
            severity: .error,
            code: code,
            message: message,
            location: MusicXMLLocation(elementName: "container.xml")
        )
    }
}

private struct MXLRootfile: Sendable {
    let fullPath: String
    let mediaType: String?
}

private final class MXLContainerParserDelegate: NSObject, XMLParserDelegate {
    private(set) var rootfiles: [MXLRootfile] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "rootfile", let fullPath = attributeDict["full-path"], !fullPath.isEmpty else {
            return
        }
        rootfiles.append(MXLRootfile(fullPath: fullPath, mediaType: attributeDict["media-type"]))
    }
}
