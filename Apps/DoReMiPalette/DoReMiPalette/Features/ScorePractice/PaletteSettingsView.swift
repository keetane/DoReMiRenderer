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
                .onboardingAnchor(.settingsDisplayOptions)
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
                Section("譜面レイアウト") {
                    Picker("譜面レイアウト", selection: $scoreLayoutModeRawValue) {
                        ForEach(PaletteScoreLayoutMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("拡大率") {
                    HStack {
                        Text("現在")
                        Spacer()
                        Text(PaletteZoomScale.percentText(zoomScale))
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: zoomScaleBinding,
                        in: PaletteZoomScale.minimum...PaletteZoomScale.maximum,
                        step: 0.05
                    )
                    Button("拡大率をリセット") {
                        zoomScale = PaletteZoomScale.default
                    }
                    Text("譜面はピンチ操作で拡大縮小できます。設定値は保存され、次回起動時に復元されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var zoomScaleBinding: Binding<Double> {
        Binding(
            get: { PaletteZoomScale.clamped(zoomScale) },
            set: { zoomScale = PaletteZoomScale.clamped($0) }
        )
    }
}
