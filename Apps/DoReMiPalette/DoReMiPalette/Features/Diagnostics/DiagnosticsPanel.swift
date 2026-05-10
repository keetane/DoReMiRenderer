import DoReMiRendererKit
import SwiftUI

struct DiagnosticsPanel: View {
    let diagnostics: [RendererDiagnostic]
    @Environment(\.dismiss) private var dismiss
    private var presentation: DiagnosticsPresentation {
        DiagnosticsPresentation(diagnostics: diagnostics)
    }

    var body: some View {
        NavigationStack {
            List {
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
            return "リピート情報を検出しました。MVPではリピート展開は行いません。"
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
