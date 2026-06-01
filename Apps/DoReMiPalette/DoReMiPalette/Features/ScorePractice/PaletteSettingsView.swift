import SwiftUI

struct PaletteSettingsView: View {
    @Binding var noteColorVisible: Bool
    @Binding var staffColorVisible: Bool
    @Binding var keyboardVisible: Bool
    @Binding var keyboardColorVisible: Bool
    @Binding var keyboardColorPositionTop: Bool
    @Binding var keyboardLineNumberVisible: Bool
    @Binding var topToolbarVisible: Bool
    @Binding var currentNoteDisplayVisible: Bool
    @Binding var nextNoteDisplayVisible: Bool
    @Binding var measureNumbersVisible: Bool
    @Binding var zoomScale: Double
    @Binding var colorSchemeRawValue: String
    @Binding var scoreLayoutModeRawValue: String
    @Binding var transposeSemitones: Int
    @Binding var displayTransposeEnabled: Bool
    @Binding var metronomeEnabled: Bool
    @Binding var metronomeCompoundModeRawValue: String
    @Binding var metronomeClickSoundStyleRawValue: String
    var writtenKeyPitchClass: Int? = nil
    @Binding var guideState: OnboardingGuideState
    var onTapTempo: () -> Void = {}
    var onRestartGuide: () -> Void = {}
    var onCompleteGuide: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("カラーリング") {
                    Toggle("音符の色", isOn: $noteColorVisible)
                    Toggle("五線の色", isOn: $staffColorVisible)
                    Toggle("鍵盤の色", isOn: $keyboardColorVisible)
                    Toggle("カラーポジション", isOn: $keyboardColorPositionTop)
                    Toggle("ラインNo.", isOn: $keyboardLineNumberVisible)
                }
                .onboardingAnchor(.settingsDisplayOptions)
                Section("レイアウト") {
                    Toggle("横一列", isOn: horizontalLayoutBinding)
                    Toggle("鍵盤を表示", isOn: $keyboardVisible)
                    Toggle("上部ツールバー", isOn: $topToolbarVisible)
                    Toggle("現在の音を表示", isOn: $currentNoteDisplayVisible)
                    Toggle("次の音を表示", isOn: $nextNoteDisplayVisible)
                    Toggle("小節数を表示", isOn: $measureNumbersVisible)
                }
                Section("再生") {
                    Toggle("メトロノーム", isOn: $metronomeEnabled)
                    Picker("複合拍子", selection: $metronomeCompoundModeRawValue) {
                        ForEach(PaletteMetronomeCompoundMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("クリック音", selection: $metronomeClickSoundStyleRawValue) {
                        ForEach(PaletteMetronomeClickSoundStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    Button("Tap Tempo") {
                        onTapTempo()
                    }
                    Text("再生中にテンポへ同期したクリックを鳴らします。6/8などは大拍または細分を選べます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("ガイド") {
                    Button("使い方ガイドを再表示") {
                        onRestartGuide()
                    }
                    Text("初回ガイドは完了またはスキップ後に自動表示されません。このボタンでいつでも再表示できます。")
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
            .overlayPreferenceValue(OnboardingAnchorPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    if guideState.isActive,
                       guideState.currentStep == .settingsDisplayOptions {
                        let anchorFrame = anchors[guideState.currentStep.anchorID].map { proxy[$0] }
                        OnboardingGuideOverlay(
                            step: guideState.currentStep,
                            anchorFrame: anchorFrame,
                            containerSize: proxy.size,
                            onBack: { guideState.moveBack() },
                            onNext: { _ = guideState.moveNext() },
                            onSkip: {
                                onCompleteGuide()
                                dismiss()
                            }
                        )
                        .zIndex(50)
                    }
                }
            }
        }
    }

    private var horizontalLayoutBinding: Binding<Bool> {
        Binding(
            get: { PaletteScoreLayoutMode.fromRawValue(scoreLayoutModeRawValue) == .horizontal },
            set: { isHorizontal in
                scoreLayoutModeRawValue = isHorizontal
                    ? PaletteScoreLayoutMode.horizontal.rawValue
                    : PaletteScoreLayoutMode.a4.rawValue
            }
        )
    }
}
