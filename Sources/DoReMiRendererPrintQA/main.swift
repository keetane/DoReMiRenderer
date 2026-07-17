import CoreGraphics
import DoReMiRendererKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct PrintQAArguments {
    var samplesURL = URL(fileURLWithPath: "Apps/DoReMiPalette/DoReMiPalette/Resources/Samples")
    var outputURL = URL(fileURLWithPath: "/tmp/DoReMiPaletteQA/a4-print-quality")
    var limit: Int?
    var writePNG = true
    var containsFilters: [String] = []

    init(rawArguments: [String]) {
        var iterator = rawArguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--samples", "--input":
                if let value = iterator.next() {
                    samplesURL = URL(fileURLWithPath: value)
                }
            case "--output":
                if let value = iterator.next() {
                    outputURL = URL(fileURLWithPath: value)
                }
            case "--limit":
                if let value = iterator.next(), let parsed = Int(value) {
                    limit = max(1, parsed)
                }
            case "--no-png":
                writePNG = false
            case "--contains":
                if let value = iterator.next(), !value.isEmpty {
                    containsFilters.append(value.lowercased())
                }
            default:
                continue
            }
        }
    }
}

private struct PrintQASummary: Codable {
    let generatedAt: String
    let samplesPath: String
    let outputPath: String
    let totalFiles: Int
    let successfulFiles: Int
    let failedFiles: Int
    let records: [PrintQARecord]
}

private struct PrintQARecord: Codable {
    let file: String
    let title: String
    let status: String
    let pageCount: Int
    let systemCount: Int
    let measureCount: Int
    let maxMeasuresPerSystem: Int
    let maxSystemHeight: Double
    let minNoteGap: Double?
    let cutSystemCount: Int
    let diagnosticCount: Int
    let pageSystemCounts: [Int]
    let warnings: [String]
    let pdfPath: String?
    let previewPaths: [String]
}

private struct PrintPageSlice: Equatable {
    let sourceStartY: CGFloat
    let sourceEndY: CGFloat
    let destinationY: CGFloat
    let scale: CGFloat

    var visibleHeight: CGFloat {
        max(1, (sourceEndY - sourceStartY) * scale)
    }
}

private struct PrintQAPage: Equatable {
    let index: Int
    let frame: CGRect
    let contentFrame: CGRect
    let systemIndices: [Int]
}

private enum PrintPageLayout {
    static let a4Size = CGSize(width: 595, height: 842)
    static let printScale: CGFloat = 0.9
    static let maxSystemsPerPage = 5
    static let notationBottomBleed: CGFloat = 54

    static func pageSlices(
        forContentHeight contentHeight: CGFloat,
        pageHeight: CGFloat,
        systemFrames: [CGRect]
    ) -> [PrintPageSlice] {
        guard contentHeight.isFinite, pageHeight.isFinite, pageHeight > 0 else {
            return [PrintPageSlice(sourceStartY: 0, sourceEndY: 1, destinationY: 0, scale: printScale)]
        }
        let safeContentHeight = max(contentHeight, 1)
        let sortedSystemFrames = systemFrames
            .filter { !$0.isNull && !$0.isEmpty && $0.minY.isFinite && $0.maxY.isFinite }
            .sorted { $0.minY < $1.minY }
        guard !sortedSystemFrames.isEmpty else {
            return contiguousPageSlices(forContentHeight: safeContentHeight, pageHeight: pageHeight)
        }

        let repeatedPageTopInset = min(max(72, pageHeight * 0.09), 96)
        let repeatedPageBottomInset = min(max(72, pageHeight * 0.10), 96)
        let firstPageBottomInset = min(max(24, pageHeight * 0.03), 32)
        var slices: [PrintPageSlice] = []
        var systemIndex = 0
        func paddedSystemEndY(for index: Int) -> CGFloat {
            let systemEndY = min(safeContentHeight, sortedSystemFrames[index].maxY)
            let paddedEndY = min(safeContentHeight, systemEndY + notationBottomBleed)
            guard index + 1 < sortedSystemFrames.count else {
                return paddedEndY
            }
            let nextSystemStartY = sortedSystemFrames[index + 1].minY
            guard systemEndY < nextSystemStartY else {
                return systemEndY
            }
            return min(paddedEndY, nextSystemStartY - 1)
        }

        while systemIndex < sortedSystemFrames.count {
            let isFirstPage = slices.isEmpty
            let destinationY: CGFloat = isFirstPage ? 0 : repeatedPageTopInset
            let bottomInset = isFirstPage ? firstPageBottomInset : repeatedPageBottomInset
            let availableHeight = max(1, pageHeight - destinationY - bottomInset)
            let sourceStartY: CGFloat = isFirstPage
                ? 0
                : max(0, sortedSystemFrames[systemIndex].minY)
            let endIndex = min(systemIndex + maxSystemsPerPage - 1, sortedSystemFrames.count - 1)
            let sourceEndY = max(paddedSystemEndY(for: endIndex), sourceStartY + 1)
            let rawHeight = max(1, sourceEndY - sourceStartY)
            let scale = min(printScale, availableHeight / rawHeight)

            slices.append(PrintPageSlice(
                sourceStartY: sourceStartY,
                sourceEndY: max(sourceEndY, sourceStartY + 1),
                destinationY: destinationY,
                scale: scale
            ))
            systemIndex = endIndex + 1
        }

        return slices.isEmpty ? contiguousPageSlices(forContentHeight: safeContentHeight, pageHeight: pageHeight) : slices
    }

    private static func contiguousPageSlices(forContentHeight contentHeight: CGFloat, pageHeight: CGFloat) -> [PrintPageSlice] {
        var slices: [PrintPageSlice] = []
        var sourceStartY: CGFloat = 0
        let epsilon: CGFloat = 0.5
        while sourceStartY < contentHeight - epsilon {
            let sourceEndY = min(sourceStartY + pageHeight, contentHeight)
            slices.append(PrintPageSlice(
                sourceStartY: sourceStartY,
                sourceEndY: max(sourceEndY, sourceStartY + 1),
                destinationY: 0,
                scale: printScale
            ))
            sourceStartY = sourceEndY
        }
        return slices.isEmpty ? [PrintPageSlice(sourceStartY: 0, sourceEndY: pageHeight, destinationY: 0, scale: printScale)] : slices
    }
}

@main
struct DoReMiRendererPrintQACommand {
    static func main() throws {
        let arguments = PrintQAArguments(rawArguments: CommandLine.arguments)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: arguments.outputURL, withIntermediateDirectories: true)

        let sampleURLs = scanSamples(in: arguments.samplesURL)
            .filter { url in
                arguments.containsFilters.isEmpty
                    || arguments.containsFilters.contains { url.lastPathComponent.lowercased().contains($0) }
            }
        let selectedURLs = arguments.limit.map { Array(sampleURLs.prefix($0)) } ?? sampleURLs
        var records: [PrintQARecord] = []

        for url in selectedURLs {
            let record = renderSample(url, samplesRoot: arguments.samplesURL, outputRoot: arguments.outputURL, writePNG: arguments.writePNG)
            records.append(record)
            print("\(record.status.uppercased()) \(record.file) pages=\(record.pageCount) warnings=\(record.warnings.count)")
        }

        let summary = PrintQASummary(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            samplesPath: arguments.samplesURL.path,
            outputPath: arguments.outputURL.path,
            totalFiles: selectedURLs.count,
            successfulFiles: records.filter { $0.status == "ok" }.count,
            failedFiles: records.filter { $0.status != "ok" }.count,
            records: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(summary).write(to: arguments.outputURL.appendingPathComponent("summary.json"))
        try makeMarkdown(summary).write(
            to: arguments.outputURL.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func scanSamples(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { entry -> URL? in
            guard let url = entry as? URL,
                  ["musicxml", "xml", "mxl"].contains(url.pathExtension.lowercased())
            else { return nil }
            return url
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func renderSample(
        _ url: URL,
        samplesRoot: URL,
        outputRoot: URL,
        writePNG: Bool
    ) -> PrintQARecord {
        let relativePath = relativePath(for: url, root: samplesRoot)
        let directoryName = sanitize(relativePath.replacingOccurrences(of: "/", with: "_"))
        let outputDirectory = outputRoot.appendingPathComponent(directoryName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let data = try Data(contentsOf: url)
            let input: ScoreInput = url.pathExtension.lowercased() == "mxl" ? .mxlData(data) : .musicXMLData(data)
            let renderer = DoReMiRenderer()
            let parseResult = try renderer.parseWithDiagnostics(input: input)
            let layoutResult = try renderer.layoutWithDiagnostics(score: parseResult.score, options: a4Options())
            let layout = layoutResult.layout
            let systemFrames = layout.printSystemContentFramesForQA()
            let pages = layout.printPagesForQA()
            let pdfURL = outputDirectory.appendingPathComponent("score.pdf")
            try writePDF(layout: layout, score: parseResult.score, pages: pages, to: pdfURL)
            let previewURLs = writePNG
                ? try writePagePreviews(layout: layout, score: parseResult.score, pages: pages, outputDirectory: outputDirectory)
                : []
            let warnings = qualityWarnings(layout: layout, pages: pages, systemFrames: systemFrames)
            let diagnostics = parseResult.diagnostics + layoutResult.diagnostics
            let record = PrintQARecord(
                file: relativePath,
                title: parseResult.score.title ?? url.deletingPathExtension().lastPathComponent,
                status: "ok",
                pageCount: pages.count,
                systemCount: layout.systems.count,
                measureCount: layout.measures.count,
                maxMeasuresPerSystem: maxMeasuresPerSystem(in: layout),
                maxSystemHeight: Double(systemFrames.map(\.height).max() ?? 0),
                minNoteGap: minNoteGap(in: layout).map(Double.init),
                cutSystemCount: cutStaffLineCount(layout: layout, pages: pages),
                diagnosticCount: diagnostics.count,
                pageSystemCounts: pages.map { $0.systemIndices.count },
                warnings: warnings + diagnostics.prefix(12).map { "\($0.severity.rawValue): \($0.code)" },
                pdfPath: pdfURL.path,
                previewPaths: previewURLs.map(\.path)
            )
            try writeRecord(record, to: outputDirectory.appendingPathComponent("layout.json"))
            return record
        } catch {
            let record = PrintQARecord(
                file: relativePath,
                title: url.deletingPathExtension().lastPathComponent,
                status: "failed",
                pageCount: 0,
                systemCount: 0,
                measureCount: 0,
                maxMeasuresPerSystem: 0,
                maxSystemHeight: 0,
                minNoteGap: nil,
                cutSystemCount: 0,
                diagnosticCount: 1,
                pageSystemCounts: [],
                warnings: [String(describing: error)],
                pdfPath: nil,
                previewPaths: []
            )
            try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            try? writeRecord(record, to: outputDirectory.appendingPathComponent("layout.json"))
            return record
        }
    }

    private static func a4Options() -> LayoutOptions {
        LayoutOptions(
            pageWidth: 595,
            pageHeight: 842,
            staffSpace: 5.2,
            systemSpacing: 120,
            measureSpacing: 0,
            displayMode: .print,
            showPageMargins: true
        )
    }

    private static func writePDF(layout: ScoreLayout, score: ScoreDocument, pages: [PrintQAPage], to url: URL) throws {
        var mediaBox = CGRect(origin: .zero, size: PrintPageLayout.a4Size)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw PrintQAError.renderingFailed("Unable to create PDF context")
        }

        for page in pages {
            context.beginPDFPage(nil)
            drawPage(layout: layout, score: score, page: page, context: context)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func writePagePreviews(
        layout: ScoreLayout,
        score: ScoreDocument,
        pages: [PrintQAPage],
        outputDirectory: URL
    ) throws -> [URL] {
        var urls: [URL] = []
        for (index, page) in pages.enumerated() {
            guard let context = CGContext(
                data: nil,
                width: Int(PrintPageLayout.a4Size.width.rounded()),
                height: Int(PrintPageLayout.a4Size.height.rounded()),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw PrintQAError.renderingFailed("Unable to create PNG context")
            }
            drawPage(layout: layout, score: score, page: page, context: context)
            guard let image = context.makeImage() else {
                throw PrintQAError.renderingFailed("Unable to extract PNG image")
            }
            let url = outputDirectory.appendingPathComponent(String(format: "page-%03d.png", index + 1))
            try writePNG(image, to: url)
            urls.append(url)
        }
        return urls
    }

    private static func drawPage(layout: ScoreLayout, score: ScoreDocument, page: PrintQAPage, context: CGContext) {
        let renderedLayout: ScoreLayout
        let sourcePage = layout.pages.first { $0.index == page.index }
        if let sourcePage {
            renderedLayout = layout.pageLayout(for: sourcePage)
        } else {
            renderedLayout = layout
        }

        context.saveGState()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: PrintPageLayout.a4Size))
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: 0, y: PrintPageLayout.a4Size.height)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: CGRect(origin: .zero, size: PrintPageLayout.a4Size))
        context.translateBy(x: -page.frame.minX, y: -page.frame.minY)
        if let sourcePage {
            let clipFrame = sourcePage.index == 0
                ? sourcePage.contentFrame.union(layout.title?.frame ?? sourcePage.contentFrame)
                : sourcePage.contentFrame
            context.clip(to: clipFrame)
        }
        ScoreGraphicsRenderer().draw(layout: renderedLayout, score: score, style: ScoreStyle(), in: context)
        context.restoreGState()
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PrintQAError.renderingFailed("Unable to create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PrintQAError.renderingFailed("Unable to write PNG")
        }
    }

    private static func qualityWarnings(layout: ScoreLayout, pages: [PrintQAPage], systemFrames: [CGRect]) -> [String] {
        var warnings: [String] = []
        let cuts = cutStaffLineCount(layout: layout, pages: pages)
        if cuts > 0 {
            warnings.append("page-cuts-staff-line:\(cuts)")
        }
        let nonFinalOverfilledPages = pages.dropLast().filter { $0.systemIndices.count > 6 }
        if !nonFinalOverfilledPages.isEmpty {
            warnings.append("too-many-systems-per-page:\(nonFinalOverfilledPages.map(\.index))")
        }
        if let minGap = minNoteGap(in: layout), minGap < 10 {
            warnings.append(String(format: "very-tight-note-gap:%.1f", minGap))
        }
        let maxHeight = systemFrames.map(\.height).max() ?? 0
        if maxHeight > PrintPageLayout.a4Size.height * 0.70 {
            warnings.append(String(format: "very-tall-system:%.1f", maxHeight))
        }
        let maxMeasures = maxMeasuresPerSystem(in: layout)
        if maxMeasures > 4 {
            warnings.append("too-many-measures-in-system:\(maxMeasures)")
        }
        return warnings
    }

    private static func maxMeasuresPerSystem(in layout: ScoreLayout) -> Int {
        Dictionary(grouping: layout.measures, by: \.systemIndex)
            .values
            .map(\.count)
            .max() ?? 0
    }

    private static func minNoteGap(in layout: ScoreLayout) -> CGFloat? {
        let grouped = Dictionary(grouping: layout.noteByID.values) { note in
            "\(note.measureID?.rawValue ?? "-")|\(note.staffID?.rawValue ?? "-")|\(note.voiceID?.rawValue ?? "-")"
        }
        let gaps = grouped.values.flatMap { notes -> [CGFloat] in
            let sorted = notes.sorted { $0.noteheadCenter.x < $1.noteheadCenter.x }
            return zip(sorted, sorted.dropFirst()).compactMap { lhs, rhs in
                let dx = rhs.noteheadCenter.x - lhs.noteheadCenter.x
                return dx > 1 ? dx : nil
            }
        }
        return gaps.min()
    }

    private static func cutStaffLineCount(layout: ScoreLayout, pages: [PrintQAPage]) -> Int {
        let epsilon: CGFloat = 0.5
        return layout.staffLines.filter { staffLine in
            let frame = staffLine.frame
            let containingPage = pages.first { page in
                let pageContentFrame = contentFrame(for: page)
                return frame.minY >= pageContentFrame.minY - epsilon && frame.maxY <= pageContentFrame.maxY + epsilon
            }
            return containingPage == nil
        }.count
    }

    private static func contentFrame(for page: PrintQAPage) -> CGRect {
        page.contentFrame
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce("") { $0 + String($1) }
    }

    private static func writeRecord(_ record: PrintQARecord, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url)
    }

    private static func makeMarkdown(_ summary: PrintQASummary) -> String {
        var lines: [String] = [
            "# A4 Print Quality Audit",
            "",
            "- Generated: \(summary.generatedAt)",
            "- Samples: \(summary.samplesPath)",
            "- Output: \(summary.outputPath)",
            "- Files: \(summary.successfulFiles)/\(summary.totalFiles) succeeded",
            "",
            "| File | Status | Pages | Systems | Measures/system | Min note gap | Warnings |",
            "| --- | --- | ---: | ---: | ---: | ---: | --- |",
        ]
        for record in summary.records {
            let minGap = record.minNoteGap.map { String(format: "%.1f", $0) } ?? "-"
            let warnings = record.warnings.prefix(5).joined(separator: "<br>")
            lines.append("| \(record.file) | \(record.status) | \(record.pageCount) | \(record.systemCount) | \(record.maxMeasuresPerSystem) | \(minGap) | \(warnings) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

private extension ScoreLayout {
    func printPagesForQA() -> [PrintQAPage] {
        if !pages.isEmpty {
            return pages.map {
                PrintQAPage(index: $0.index, frame: $0.frame, contentFrame: $0.contentFrame, systemIndices: $0.systemIndices)
            }
        }
        let frame = CGRect(origin: .zero, size: CGSize(width: PrintPageLayout.a4Size.width, height: max(PrintPageLayout.a4Size.height, canvasSize.height)))
        return [
            PrintQAPage(
                index: 0,
                frame: frame,
                contentFrame: frame,
                systemIndices: systems.map(\.index)
            ),
        ]
    }

    func printSystemContentFramesForQA() -> [CGRect] {
        let verticalOverflowAllowance: CGFloat = 120
        var measureSystemByID: [MeasureID: Int] = [:]
        for measure in measures where measureSystemByID[measure.measureID] == nil {
            measureSystemByID[measure.measureID] = measure.systemIndex
        }
        var framesBySystem = Dictionary(uniqueKeysWithValues: systems.map { ($0.index, $0.frame) })

        if let title {
            framesBySystem[systems.first?.index ?? 0] = framesBySystem[systems.first?.index ?? 0]?.union(title.frame) ?? title.frame
        }
        for staff in staves {
            framesBySystem[staff.systemIndex] = framesBySystem[staff.systemIndex]?.union(staff.frame) ?? staff.frame
        }
        for measure in measures {
            framesBySystem[measure.systemIndex] = framesBySystem[measure.systemIndex]?.union(measure.frame) ?? measure.frame
        }
        for element in elements {
            guard !element.frame.isNull,
                  !element.frame.isEmpty else { continue }
            let systemIndex: Int?
            if let measureID = element.measureID {
                systemIndex = measureSystemByID[measureID]
            } else {
                systemIndex = systems.min {
                    abs($0.frame.midY - element.frame.midY) < abs($1.frame.midY - element.frame.midY)
                }?.index
            }
            guard let systemIndex else { continue }
            framesBySystem[systemIndex] = framesBySystem[systemIndex]?.union(element.frame) ?? element.frame
        }
        for note in noteByID.values {
            guard let measureID = note.measureID,
                  let systemIndex = measureSystemByID[measureID],
                  !note.noteheadFrame.isNull,
                  !note.noteheadFrame.isEmpty else { continue }
            framesBySystem[systemIndex] = framesBySystem[systemIndex]?.union(note.noteheadFrame) ?? note.noteheadFrame
        }
        for ledgerLine in ledgerLines {
            guard let measureID = ledgerLine.measureID,
                  let systemIndex = measureSystemByID[measureID],
                  !ledgerLine.frame.isNull,
                  !ledgerLine.frame.isEmpty else { continue }
            framesBySystem[systemIndex] = framesBySystem[systemIndex]?.union(ledgerLine.frame) ?? ledgerLine.frame
        }
        return systems.compactMap { system in
            guard var frame = framesBySystem[system.index] else { return nil }
            let safetyPadding = min(verticalOverflowAllowance, max(24, verticalOverflowAllowance * 0.4))
            frame = frame.insetBy(dx: 0, dy: -safetyPadding)
            if frame.minY < system.frame.minY - safetyPadding {
                let clampedMinY = system.frame.minY - safetyPadding
                frame = CGRect(x: frame.minX, y: clampedMinY, width: frame.width, height: max(1, frame.maxY - clampedMinY))
            }
            return frame
        }
    }
}

private enum PrintQAError: Error {
    case renderingFailed(String)
}
