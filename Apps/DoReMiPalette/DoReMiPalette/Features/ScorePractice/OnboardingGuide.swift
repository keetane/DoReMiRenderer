import SwiftUI

enum OnboardingGuideAnchorID: String, Hashable, CaseIterable {
    case settingsButton
    case paletteButton
    case settingsDisplayOptions
    case settingsLayoutOptions
    case firstBeatNote
    case currentNoteDisplay
    case keyboardArea
    case measureDisplay
    case previousNextControls
    case playStopControls
    case keyTransposeDisplay
    case colorPatternButton
    case pitchClassEButton
    case paletteKeyButton
    case playPracticePrompt
}

enum OnboardingGuideStep: String, CaseIterable, Identifiable, Equatable {
    case settingsButton
    case settingsDisplayOptions
    case settingsLayoutOptions
    case currentNoteAndKeyboard
    case measureJump
    case nextPrevious
    case playStop
    case keyAndTranspose
    case paletteButton
    case colorPatternButton
    case pitchClassEButton
    case paletteKeyButton
    case playPracticePrompt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settingsButton:
            "設定"
        case .settingsDisplayOptions:
            "カラーリング"
        case .settingsLayoutOptions:
            "レイアウト"
        case .currentNoteAndKeyboard:
            "現在の音とキーボード"
        case .measureJump:
            "小節ジャンプ"
        case .nextPrevious:
            "前後の音へ移動"
        case .playStop:
            "再生"
        case .keyAndTranspose:
            "キーと移調"
        case .paletteButton:
            "カラーパレット"
        case .colorPatternButton:
            "カラーリングパターン"
        case .pitchClassEButton:
            "音ごとの色"
        case .paletteKeyButton:
            "キーとカラーリング"
        case .playPracticePrompt:
            "弾いてみましょう"
        }
    }

    var bodyText: String {
        switch self {
        case .settingsButton:
            "表示、移調、メトロノーム、パレットなどの細かな設定をここから変更できます。"
        case .settingsDisplayOptions:
            "音符、五線、鍵盤、ラインNo.の色表示を切り替えられます。"
        case .settingsLayoutOptions:
            "横一列表示、鍵盤、上部ツールバー、現在の音、次の音、小節数の表示を切り替えられます。"
        case .currentNoteAndKeyboard:
            "譜面上の現在の音がハイライトされ、下のキーボードでも対応する鍵盤が光ります。"
        case .measureJump:
            "小節番号を入力すると、指定した小節へ移動できます。"
        case .nextPrevious:
            "Previous / Nextで、前後の音や練習ステップへ移動できます。"
        case .playStop:
            "Playで再生を開始し、Stopで停止します。メトロノームをONにすると拍に合わせてクリックも鳴ります。"
        case .keyAndTranspose:
            "現在のキー、移調設定、譜面も移調するかを確認できます。ピアノ練習用に半音単位で調整できます。"
        case .paletteButton:
            "パレットボタンからカラーパターンを選択できます。"
        case .colorPatternButton:
            "カラーリングパターンを変更できます。ラインモードは五線譜上の音符のみをカラーリングします。"
        case .pitchClassEButton:
            "音符ごとにカラーリングのオンオフを設定できます。"
        case .paletteKeyButton:
            "各音符の色はキーボードの色と連動しています。カラーリングはスケールと連動しています。"
        case .playPracticePrompt:
            "Playボタンを押して鍵盤の位置を確認しながら弾いてみましょう。"
        }
    }

    var anchorID: OnboardingGuideAnchorID {
        switch self {
        case .settingsButton:
            .settingsButton
        case .settingsDisplayOptions:
            .settingsDisplayOptions
        case .settingsLayoutOptions:
            .settingsLayoutOptions
        case .currentNoteAndKeyboard:
            .firstBeatNote
        case .measureJump:
            .measureDisplay
        case .nextPrevious:
            .previousNextControls
        case .playStop:
            .playStopControls
        case .keyAndTranspose:
            .keyTransposeDisplay
        case .paletteButton:
            .paletteButton
        case .colorPatternButton:
            .colorPatternButton
        case .pitchClassEButton:
            .pitchClassEButton
        case .paletteKeyButton:
            .paletteKeyButton
        case .playPracticePrompt:
            .playStopControls
        }
    }

    var prefersCardAboveAnchor: Bool {
        self == .settingsDisplayOptions || self == .settingsLayoutOptions
    }

    var stepIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var isFirst: Bool {
        stepIndex == 0
    }

    var isLast: Bool {
        stepIndex == Self.allCases.count - 1
    }

    var next: OnboardingGuideStep? {
        let index = stepIndex + 1
        guard Self.allCases.indices.contains(index) else { return nil }
        return Self.allCases[index]
    }

    var previous: OnboardingGuideStep? {
        let index = stepIndex - 1
        guard Self.allCases.indices.contains(index) else { return nil }
        return Self.allCases[index]
    }
}

struct OnboardingGuideState: Equatable {
    var isActive: Bool
    var currentStep: OnboardingGuideStep

    static let inactive = OnboardingGuideState(isActive: false, currentStep: .settingsButton)

    mutating func start() {
        isActive = true
        currentStep = .settingsButton
    }

    mutating func skipOrComplete() {
        isActive = false
    }

    mutating func moveNext() -> Bool {
        guard let next = currentStep.next else {
            isActive = false
            return true
        }
        currentStep = next
        return false
    }

    mutating func moveBack() {
        if let previous = currentStep.previous {
            currentStep = previous
        }
    }
}

struct OnboardingAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [OnboardingGuideAnchorID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [OnboardingGuideAnchorID: Anchor<CGRect>],
        nextValue: () -> [OnboardingGuideAnchorID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func onboardingAnchor(_ id: OnboardingGuideAnchorID) -> some View {
        anchorPreference(key: OnboardingAnchorPreferenceKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }

    @ViewBuilder
    func onboardingAnchor(_ id: OnboardingGuideAnchorID, when condition: Bool) -> some View {
        if condition {
            onboardingAnchor(id)
        } else {
            self
        }
    }
}

struct OnboardingGuideOverlay: View {
    let step: OnboardingGuideStep
    let anchorFrame: CGRect?
    let containerSize: CGSize
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private let cardWidth: CGFloat = 320

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.36)
                .ignoresSafeArea()
            if let anchorFrame {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    )
                    .frame(
                        width: max(anchorFrame.width + 16, 48),
                        height: max(anchorFrame.height + 16, 36)
                    )
                    .position(x: anchorFrame.midX, y: anchorFrame.midY)
                    .allowsHitTesting(false)
            }
            guideCard
                .frame(width: min(cardWidth, max(containerSize.width - 32, 240)))
                .position(cardPosition(anchorFrame: anchorFrame))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-guide-overlay")
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.title)
                    .font(.headline)
                Spacer()
                Text("\(step.stepIndex + 1)/\(OnboardingGuideStep.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(step.bodyText)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("スキップ", action: onSkip)
                    .buttonStyle(.borderless)
                Spacer()
                Button("戻る", action: onBack)
                    .disabled(step.isFirst)
                Button(step.isLast ? "完了" : "次へ", action: onNext)
                    .buttonStyle(.borderedProminent)
            }
            .font(.callout)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
        .accessibilityIdentifier("onboarding-guide-card-\(step.rawValue)")
    }

    private func cardPosition(anchorFrame: CGRect?) -> CGPoint {
        let width = min(cardWidth, max(containerSize.width - 32, 240))
        let fallback = CGPoint(x: containerSize.width / 2, y: containerSize.height * 0.64)
        guard let anchorFrame, containerSize.width > 0, containerSize.height > 0 else {
            return fallback
        }

        let verticalGap: CGFloat = 20
        let cardHeight: CGFloat = 190
        let belowY = anchorFrame.maxY + verticalGap + cardHeight / 2
        let aboveY = anchorFrame.minY - verticalGap - cardHeight / 2
        let y: CGFloat
        if step.prefersCardAboveAnchor,
           aboveY - cardHeight / 2 > 12 {
            y = aboveY
        } else if belowY + cardHeight / 2 < containerSize.height - 12 {
            y = belowY
        } else if aboveY - cardHeight / 2 > 12 {
            y = aboveY
        } else {
            y = fallback.y
        }

        let x = min(
            max(anchorFrame.midX, width / 2 + 16),
            max(width / 2 + 16, containerSize.width - width / 2 - 16)
        )
        return CGPoint(x: x, y: y)
    }
}
