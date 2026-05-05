import Foundation
import Testing
@testable import DoReMiRendererDiagnostics
import DoReMiRendererKit

@Test func scannerRecursivelyFindsMusicXMLXMLAndMXLFiles() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    try write("root", to: root.appending(path: "score.musicxml"))
    try FileManager.default.createDirectory(at: root.appending(path: "nested/deeper"), withIntermediateDirectories: true)
    try write("nested", to: root.appending(path: "nested/part.XML"))
    try write("mxl", to: root.appending(path: "nested/deeper/archive.mxl"))
    try write("ignored", to: root.appending(path: "nested/deeper/readme.txt"))

    let scan = MusicXMLSampleScanner().scan(inputDirectory: root)

    #expect(!scan.skippedMissingInputDirectory)
    #expect(scan.files.map(\.relativePath) == [
        "nested/deeper/archive.mxl",
        "nested/part.XML",
        "score.musicxml",
    ])
    #expect(scan.files.map(\.format) == [.mxl, .xml, .musicxml])
}

@Test func scannerSkipsMissingInputDirectory() throws {
    let root = try makeTemporaryDirectory().appending(path: "missing")

    let scan = MusicXMLSampleScanner().scan(inputDirectory: root)

    #expect(scan.skippedMissingInputDirectory)
    #expect(scan.files.isEmpty)
}

@Test func collectorAggregatesParserDiagnosticsWithoutScoreContents() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try write(validUnsupportedXML, to: root.appending(path: "unsupported.musicxml"))
    try write("<score-partwise><part-list>", to: root.appending(path: "invalid.xml"))

    let scan = MusicXMLSampleScanner().scan(inputDirectory: root)
    let result = MusicXMLDiagnosticsCollector().collect(scan: scan)
    let report = MusicXMLCompatibilityReport()
    let summaries = report.codeSummaries(for: result.diagnostics)
    let markdown = report.makeMarkdown(
        result: result,
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    #expect(summaries.contains(DiagnosticCodeSummary(severity: .warning, code: "unsupported.transpose", count: 1)))
    #expect(summaries.contains { $0.severity == .error && $0.code == "musicxml.invalidDocument" && $0.count == 1 })
    #expect(markdown.contains("Files scanned: 2"))
    #expect(markdown.contains("Diagnostics found: 2"))
    #expect(markdown.contains("`unsupported.musicxml`"))
    #expect(!markdown.contains("<score-partwise"))
    #expect(!markdown.contains("<transpose>"))
}

@Test func missingDirectoryReportIsSkippedAndDoesNotFail() throws {
    let root = try makeTemporaryDirectory().appending(path: "missing")
    let scan = MusicXMLSampleScanner().scan(inputDirectory: root)
    let result = MusicXMLDiagnosticsCollector().collect(scan: scan)
    let markdown = MusicXMLCompatibilityReport().makeMarkdown(
        result: result,
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    #expect(result.diagnostics.isEmpty)
    #expect(markdown.contains("Status: skipped because the input directory does not exist."))
    #expect(markdown.contains("No MusicXML sample contents were read."))
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "DoReMiRendererDiagnosticsTests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ string: String, to url: URL) throws {
    try string.data(using: .utf8)?.write(to: url)
}

private let validUnsupportedXML = """
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <transpose><chromatic>2</chromatic></transpose>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""
