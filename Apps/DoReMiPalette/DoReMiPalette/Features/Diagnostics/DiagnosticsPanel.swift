import DoReMiRendererKit
import SwiftUI

struct DiagnosticsPanel: View {
    let diagnostics: [RendererDiagnostic]
    let context: DiagnosticsScoreContext?
    @Environment(\.dismiss) private var dismiss
    private var presentation: DiagnosticsPresentation {
        DiagnosticsPresentation(diagnostics: diagnostics)
    }

    var body: some View {
        NavigationStack {
            List {
                if let context {
                    Section("譜面情報") {
                        DiagnosticsContextGrid(context: context)
                    }
                }
                if diagnostics.isEmpty {
                    ContentUnavailableView(
                        "問題は検出されませんでした",
                        systemImage: "checkmark.seal",
                        description: Text("現在の譜面に表示すべき診断はありません。")
                    )
                } else {
                    Section("概要") {
                        Text(presentation.summaryText)
                            .font(.callout)
                    }
                    Section("診断") {
                        ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            DiagnosticRow(diagnostic: diagnostic)
                        }
                    }
                }
            }
            .navigationTitle("診断")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DiagnosticsScoreContext: Equatable {
    let title: String
    let sourceName: String
    let partCount: Int
    let measureCount: Int
    let noteCount: Int
    let playbackEventCount: Int
    let layoutMode: String
    let canvasSize: CGSize
    let tempoBPM: Double
}

private struct DiagnosticsContextGrid: View {
    let context: DiagnosticsScoreContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            contextRow("曲名", context.title)
            contextRow("ファイル", context.sourceName)
            contextRow("構成", "\(context.partCount) part / \(context.measureCount) measures / \(context.noteCount) notes")
            contextRow("再生", "\(context.playbackEventCount) events / \(Int(context.tempoBPM.rounded())) BPM")
            contextRow("表示", "\(context.layoutMode) / \(Int(context.canvasSize.width.rounded())) x \(Int(context.canvasSize.height.rounded())) pt")
        }
        .font(.callout)
        .textSelection(.enabled)
    }

    private func contextRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DiagnosticRow: View {
    let diagnostic: RendererDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(severityText, systemImage: severityIcon)
                    .font(.headline)
                Spacer()
                Text(diagnostic.code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text(userMessage)
                .font(.body)
            Text(locationText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var severityText: String {
        DiagnosticsPresentation.severityText(for: diagnostic.severity)
    }

    private var severityIcon: String {
        DiagnosticsPresentation.severityIcon(for: diagnostic.severity)
    }

    private var userMessage: String {
        DiagnosticsPresentation.userMessage(for: diagnostic)
    }

    private var locationText: String {
        DiagnosticsPresentation.locationText(for: diagnostic)
    }
}

struct DiagnosticsPresentation {
    let diagnostics: [RendererDiagnostic]

    var summaryText: String {
        let errors = diagnostics.filter { $0.severity == .error }.count
        let warnings = diagnostics.filter { $0.severity == .warning }.count
        return "エラー \(errors) 件、警告 \(warnings) 件"
    }

    static func severityText(for severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: "情報"
        case .warning: "警告"
        case .error: "エラー"
        }
    }

    static func severityIcon(for severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    static func userMessage(for diagnostic: RendererDiagnostic) -> String {
        if diagnostic.code.hasPrefix("unsupported.") {
            return "この譜面には未対応の記譜があります。表示や再生ステップの一部が簡略化される可能性があります。"
        }
        if diagnostic.code.hasPrefix("repeat.") {
            return "リピート情報を検出しました。複雑な反復やジャンプは簡略化される可能性があります。"
        }
        if diagnostic.code.hasPrefix("layout.") {
            return "この譜面では一部の記号配置を簡略化しています。表示が重なる場合はA4/横一列の切り替えを試してください。"
        }
        if diagnostic.code.hasPrefix("musicxml.") {
            return "MusicXML内に、このアプリで完全対応していない情報があります。読み込み自体は継続しています。"
        }
        return diagnostic.message
    }

    static func locationText(for diagnostic: RendererDiagnostic) -> String {
        guard let location = diagnostic.location else {
            return "場所: 不明"
        }
        let part = location.partID ?? "-"
        let measure = location.measureNumber ?? "-"
        let element = location.elementName ?? "-"
        return "場所: part \(part), measure \(measure), element \(element)"
    }
}
