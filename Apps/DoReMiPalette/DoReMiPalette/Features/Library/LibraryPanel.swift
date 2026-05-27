import SwiftUI

struct LibraryPanel: View {
    @ObservedObject var session: PaletteScoreSession
    let currentZoomScale: Double
    var onWillOpenItem: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("サンプル譜面") {
                    ForEach(session.sampleLibraryItems) { item in
                        LibraryRow(
                            item: item,
                            actionTitle: "開く",
                            onOpen: {
                                onWillOpenItem()
                                session.openLibraryItem(item, currentZoomScale: currentZoomScale)
                                dismiss()
                            },
                            onRemove: nil
                        )
                    }
                }

                Section("最近使ったファイル") {
                    if session.recentImportedItems.isEmpty {
                        ContentUnavailableView(
                            "最近使ったファイルはありません",
                            systemImage: "clock",
                            description: Text("MusicXML または MXL を読み込むと、ここに表示されます。")
                        )
                        .listRowInsets(EdgeInsets())
                    } else {
                        ForEach(session.recentImportedItems) { item in
                            LibraryRow(
                                item: item,
                                actionTitle: "再読み込み",
                                onOpen: {
                                    onWillOpenItem()
                                    session.openLibraryItem(item, currentZoomScale: currentZoomScale)
                                    if session.errorMessage == nil {
                                        dismiss()
                                    }
                                },
                                onRemove: {
                                    session.removeFromRecent(item)
                                }
                            )
                        }
                    }
                }

                if let errorMessage = session.errorMessage {
                    Section("読み込みエラー") {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("ライブラリ")
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

private struct LibraryRow: View {
    let item: LibraryItem
    let actionTitle: String
    let onOpen: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Label(item.displayName, systemImage: item.sourceType == .sample ? "music.note.list" : "doc")
                            .font(.headline)
                            .lineLimit(1)

                        Text(item.sourceType == .sample ? "サンプル" : "読み込み済み")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }

                    Text("最終更新: \(Self.dateFormatter.string(from: item.lastOpenedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let summary = item.diagnosticsSummary {
                        Text(summaryText(summary))
                            .font(.caption)
                            .foregroundStyle(summary.errors > 0 ? .red : .secondary)
                    } else if item.sourceType == .imported, item.bookmarkData == nil {
                        Text("再選択が必要な可能性があります")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                Button(actionTitle, action: onOpen)
                    .buttonStyle(.bordered)

                if let onRemove {
                    Button("削除", role: .destructive, action: onRemove)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if let onRemove {
                Button("削除", role: .destructive, action: onRemove)
            }
        }
    }

    private func summaryText(_ summary: DiagnosticsSummary) -> String {
        if summary.errors == 0, summary.warnings == 0, summary.infos == 0 {
            return "診断: 問題は検出されませんでした"
        }
        return "診断: エラー \(summary.errors) / 警告 \(summary.warnings) / 情報 \(summary.infos)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
