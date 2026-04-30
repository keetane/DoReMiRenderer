# AGENTS.md

このリポジトリでは、`DoReMiRenderer_final.md` を最上位の開発指示書として扱うこと。

ただし、一度に全Phaseを実装しない。
ユーザーが指定したPhaseだけを実装する。

必ず守ること:

- 既存SDK、商用SDK、OSS譜面エンジンのコードをコピーしない
- SeeScoreLibのAPI名、型名、サンプルコード、内部設計を模倣しない
- MusicXML公開仕様とこのリポジトリ内の独自設計に基づいて実装する
- すべての座標はScoreLayout由来にする
- Rendererに色判定ロジックを持たせない
- 色はColorRule / ColorContext / ScoreColorResolver経由で解決する
- 描画後のSVG、DOM、画像解析をしない
- 未対応MusicXML機能はsilent failureにせずdiagnosticを返す
- 実装後は該当テストを追加し、`swift test` を実行する

現在の実装対象は、ユーザーがプロンプトで指定したPhaseのみ。

## Subagent運用方針

このリポジトリでは、Phase 2以降の大きな作業ではsubagent workflowを使用してよい。

ただし、Codexはユーザーが明示的に「subagentを使う」「multi agentで進める」「parallel agentsで分担する」と指示した場合のみsubagentを起動すること。

Phase 0〜1では原則としてsingle agentで作業し、以下を固定する。

- Swift Package構成
- Domain model
- NoteID
- ScoreElementID
- MusicalTime
- Pitch
- ClefKind
- ColorRule / ColorContext / ScoreColorResolver

Phase 2以降では、必要に応じて以下の分担でsubagentを使う。

- Parser agent: MusicXMLParser、diagnostics、parser tests
- Layout agent: ScoreLayoutEngine、staffPosition、noteByID、elementByID、layout tests
- Rendering agent: ScorePainter、ScoreCanvasView、rendering tests
- Interaction agent: hitTest、nearestNoteID、interaction tests
- Playback agent: PlaybackSequenceBuilder、PlaybackEvent、playback tests
- Review agent: API整合性、テスト不足、法的安全性、実装範囲の逸脱チェック

main agentは最終統合責任を持つこと。

- subagentの結果を統合する
- public APIの整合性を確認する
- 変更範囲が今回指定されたPhaseを超えていないか確認する
- `swift test` を実行する
- 失敗した場合は parser / domain / layout / rendering / interaction / playback / platform / legal に分類して報告する