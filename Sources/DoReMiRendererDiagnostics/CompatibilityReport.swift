import DoReMiRendererKit
import Foundation

public struct DiagnosticCodeSummary: Hashable, Sendable {
    public let severity: DiagnosticSeverity
    public let code: String
    public let count: Int
}

public struct MusicXMLCompatibilityReport: Sendable {
    public init() {}

    public func makeMarkdown(
        result: MusicXMLCompatibilityResult,
        generatedAt: Date = Date()
    ) -> String {
        var lines: [String] = [
            "# MusicXML Compatibility Report",
            "",
            "Generated: \(Self.format(generatedAt))",
            "Input directory: `\(result.scan.inputDirectory.path)`",
            "",
        ]

        lines.append("## Status")
        lines.append("")
        lines.append("- Generated from local/private samples")
        lines.append("- Private sample files are not committed")
        lines.append("- Report does not include copyrighted score contents")
        if result.scan.skippedMissingInputDirectory {
            lines.append("- Input directory missing; scan skipped successfully")
            lines.append("- Status: skipped because the input directory does not exist.")
        }
        lines.append("")
        if result.scan.skippedMissingInputDirectory {
            lines.append("No MusicXML sample contents were read.")
            lines.append("")
        }

        lines.append("## Summary")
        lines.append("")
        lines.append("Files scanned: \(result.scan.files.count)")
        lines.append("Diagnostics found: \(result.diagnostics.count)")
        lines.append("")
        lines.append("| Metric | Count |")
        lines.append("|---|---:|")
        lines.append("| Files scanned | \(result.scan.files.count) |")
        lines.append("| Parsed successfully | \(successCount(result)) |")
        lines.append("| Failed | \(failureCount(result)) |")
        lines.append("| Diagnostics total | \(result.diagnostics.count) |")
        lines.append("")

        lines.append("## Diagnostics by severity")
        lines.append("")
        lines.append("| Severity | Count |")
        lines.append("|---|---:|")
        for severity in DiagnosticSeverity.allReportCases {
            lines.append("| \(severity.rawValue) | \(count(result.diagnostics, severity: severity)) |")
        }
        lines.append("")

        lines.append("## Diagnostics by code")
        lines.append("")
        let summaries = codeSummaries(for: result.diagnostics)
        if summaries.isEmpty {
            lines.append("No diagnostics.")
        } else {
            lines.append("| Code | Count | Priority | Notes |")
            lines.append("|---|---:|---|---|")
            for summary in summaries {
                lines.append("| `\(summary.code)` | \(summary.count) | \(priority(for: summary.code)) | \(summary.severity.rawValue) |")
            }
        }
        lines.append("")

        lines.append("## Files")
        lines.append("")
        lines.append("| File | Type | Status | Diagnostics | Notes |")
        lines.append("|---|---|---|---:|---|")
        if result.scan.files.isEmpty {
            lines.append("| - | - | skipped | 0 | No `.musicxml`, `.xml`, or `.mxl` files found. |")
        } else {
            for file in result.scan.files {
                let fileDiagnostics = result.diagnostics.filter { $0.relativePath == file.relativePath }
                let status = fileDiagnostics.contains { $0.diagnostic.severity == .error } ? "failed" : "success"
                let codes = fileDiagnostics.map { $0.diagnostic.code }.joined(separator: ", ")
                lines.append("| `\(escapeMarkdown(file.relativePath))` | \(file.format.rawValue) | \(status) | \(fileDiagnostics.count) | \(escapeMarkdown(codes)) |")
            }
        }
        lines.append("")

        lines.append("## Priority classification")
        lines.append("")
        lines.append("### High")
        lines.append("")
        lines.append("Onset, NoteID, staff/voice/chord, pitch/accidental/key/transposition, layout coordinate, or playback grouping risks.")
        lines.append("")
        lines.append("### Medium")
        lines.append("")
        lines.append("Lyrics, fingering, key signature display, tempo metadata, repeat metadata, slur display, and tie display refinement.")
        lines.append("")
        lines.append("### Low")
        lines.append("")
        lines.append("Ornaments, publishing details, advanced beams, complex engraving, and decorative text.")
        lines.append("")

        lines.append("## Fixture candidates")
        lines.append("")
        lines.append("| Feature | Reason | Proposed fixture | Priority |")
        lines.append("|---|---|---|---|")
        lines.append("| - | Add candidates after reviewing private diagnostics. | Self-authored minimal MusicXML only. | - |")
        lines.append("")

        lines.append("## Recommended next steps")
        lines.append("")
        lines.append("1. Review high-priority diagnostics first.")
        lines.append("2. Create self-authored minimal fixtures for recurring diagnostics.")
        lines.append("3. Update parser/layout tests before changing rendering behavior.")
        lines.append("")

        lines.append("## Diagnostics")
        lines.append("")
        if result.diagnostics.isEmpty {
            lines.append("No diagnostics.")
        } else {
            lines.append("| File | Severity | Code | Location | Message |")
            lines.append("| --- | --- | --- | --- | --- |")
            for fileDiagnostic in result.diagnostics {
                let diagnostic = fileDiagnostic.diagnostic
                lines.append(
                    "| `\(escapeMarkdown(fileDiagnostic.relativePath))` | \(diagnostic.severity.rawValue) | `\(escapeMarkdown(diagnostic.code))` | \(escapeMarkdown(locationText(diagnostic.location))) | \(escapeMarkdown(diagnostic.message)) |"
                )
            }
        }
        lines.append("")
        lines.append("This report records paths and diagnostics only. It does not include MusicXML score contents.")

        return lines.joined(separator: "\n") + "\n"
    }

    public func codeSummaries(for diagnostics: [MusicXMLFileDiagnostic]) -> [DiagnosticCodeSummary] {
        let grouped = Dictionary(grouping: diagnostics) {
            DiagnosticSummaryKey(severity: $0.diagnostic.severity, code: $0.diagnostic.code)
        }

        return grouped
            .map { key, diagnostics in
                DiagnosticCodeSummary(severity: key.severity, code: key.code, count: diagnostics.count)
            }
            .sorted {
                if $0.severity.reportSortOrder != $1.severity.reportSortOrder {
                    return $0.severity.reportSortOrder < $1.severity.reportSortOrder
                }
                return $0.code < $1.code
            }
    }

    private func count(_ diagnostics: [MusicXMLFileDiagnostic], severity: DiagnosticSeverity) -> Int {
        diagnostics.filter { $0.diagnostic.severity == severity }.count
    }

    private func successCount(_ result: MusicXMLCompatibilityResult) -> Int {
        result.scan.files.filter { file in
            !result.diagnostics.contains { $0.relativePath == file.relativePath && $0.diagnostic.severity == .error }
        }.count
    }

    private func failureCount(_ result: MusicXMLCompatibilityResult) -> Int {
        result.scan.files.count - successCount(result)
    }

    private func priority(for code: String) -> String {
        if code.contains("transpose") || code.contains("tuplet") || code.contains("voice") || code.contains("crossStaff") || code.contains("grace") {
            return "High"
        }
        if code.contains("lyric") || code.contains("fingering") || code.contains("tempo") || code.contains("repeat") || code.contains("slur") || code.contains("key") {
            return "Medium"
        }
        return "Low"
    }

    private func locationText(_ location: MusicXMLLocation?) -> String {
        guard let location else {
            return "-"
        }

        var parts: [String] = []
        if let elementName = location.elementName {
            parts.append(elementName)
        }
        if let partID = location.partID {
            parts.append("part \(partID)")
        }
        if let measureNumber = location.measureNumber {
            parts.append("measure \(measureNumber)")
        }
        return parts.isEmpty ? "-" : parts.joined(separator: ", ")
    }

    private func escapeMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private struct DiagnosticSummaryKey: Hashable {
    let severity: DiagnosticSeverity
    let code: String
}

private extension DiagnosticSeverity {
    static let allReportCases: [DiagnosticSeverity] = [.error, .warning, .info]

    var reportSortOrder: Int {
        switch self {
        case .error:
            0
        case .warning:
            1
        case .info:
            2
        }
    }
}
