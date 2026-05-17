import SwiftUI

struct PaletteSettingsView: View {
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var keyboardColorVisible: Bool
    @Binding var keyboardColorPositionTop: Bool
    @Binding var currentNoteDisplayVisible: Bool
    @Binding var nextNoteDisplayVisible: Bool
    @Binding var measureNumbersVisible: Bool
    @Binding var zoomScale: Double
    @Binding var colorSchemeRawValue: String
    @Binding var scoreLayoutModeRawValue: String
    @Binding var transposeSemitones: Int
    @Binding var displayTransposeEnabled: Bool
    var writtenKeyPitchClass: Int? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("表示") {
                    Toggle("音符の色", isOn: $noteColorVisible)
                    Toggle("五線の色", isOn: $staffColorVisible)
                    Toggle("鍵盤を表示", isOn: $keyboardVisible)
                    Toggle("鍵盤の色", isOn: $keyboardColorVisible)
                    Toggle("カラーポジション", isOn: $keyboardColorPositionTop)
                    Toggle("現在の音を表示", isOn: $currentNoteDisplayVisible)
                    Toggle("次の音を表示", isOn: $nextNoteDisplayVisible)
                    Toggle("小節数を表示", isOn: $measureNumbersVisible)
                }
                Section("譜面レイアウト") {
                    Picker("譜面レイアウト", selection: $scoreLayoutModeRawValue) {
                        ForEach(PaletteScoreLayoutMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("拡大率") {
                    Picker("拡大率", selection: $zoomScale) {
                        Text("1.0x").tag(1.0)
                        Text("1.5x").tag(1.5)
                        Text("2.0x").tag(2.0)
                    }
                    .pickerStyle(.segmented)
                }
                Section("移調") {
                    Picker("移調キー", selection: transposeKeyBinding) {
                        ForEach(PaletteTranspose.keyOptions) { option in
                            Text(option.name).tag(option.pitchClass)
                        }
                    }
                    Text("譜面表示、再生音、鍵盤を選択したキーに合わせます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var transposeKeyBinding: Binding<Int> {
        Binding(
            get: {
                PaletteTranspose.selectedTargetPitchClass(
                    writtenPitchClass: writtenKeyPitchClass,
                    transposeSemitones: transposeSemitones
                )
            },
            set: { targetPitchClass in
                displayTransposeEnabled = true
                transposeSemitones = PaletteTranspose.semitones(
                    fromWrittenPitchClass: writtenKeyPitchClass,
                    toTargetPitchClass: targetPitchClass
                )
            }
        )
    }
}
