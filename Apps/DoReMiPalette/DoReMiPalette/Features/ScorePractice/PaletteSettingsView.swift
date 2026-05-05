import SwiftUI

struct PaletteSettingsView: View {
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var zoomScale: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("表示") {
                    Toggle("音符の色", isOn: $noteColorVisible)
                    Toggle("五線の色", isOn: $staffColorVisible)
                    Toggle("鍵盤を表示", isOn: $keyboardVisible)
                }
                Section("拡大率") {
                    Picker("拡大率", selection: $zoomScale) {
                        Text("1.0x").tag(1.0)
                        Text("1.5x").tag(1.5)
                        Text("2.0x").tag(2.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("表示設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

