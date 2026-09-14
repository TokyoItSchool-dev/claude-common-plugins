# 変更履歴 (CHANGELOG)

本ドキュメントは claude-common-plugins の変更履歴を記録します。

<!-- 新しいエントリはこの行の直下に追加 -->

## [0.1.2] - 2026-09-14

### 追加
- core-dev: config-sync スキル（HOME・training-project-skills・claude-common-plugins の3拠点で CLAUDE.md / rules / skills / commands を同期し、差分を検査する）
- docs: html-design-doc に手順D「インタラクティブ・ビジュアル版」を追加（KPIタイル・タブ・シナリオ切替などの表示切替を持つ経営層向け資料。ダッシュボード型・スクロール物語型・フロー中心型の3レイアウトから選択。JavaScript無効時と印刷時にも全内容が読める段階的強化）

### 改善
- docs: html-design-doc の検証手順に手順D向けチェック（JavaScript無効表示・印刷展開・外部参照ゼロ・id/aria 整合）を追加

## [0.1.1] - 2026-09-04

### 改善
- 飾らない文章（mannered prose 禁止）ルールをテンプレート CLAUDE.md と全レビュアー/プランナーエージェントに追加（Fable 5.1 ガイド準拠）
- インストール手順の既定を --scope project に変更

## [0.1.0] - 2026-09-03

### 追加

- Claude Code 共通プラグインマーケットプレイス `mori-claude-tools` を新設（core-dev / java-dev / dotnet-dev / docs の 4 プラグイン、24 スキル、6 エージェント）
- core-dev: コーディング規約・コードレビュー・TDD・セキュリティチェック・Git 運用・API 設計・テスト実行規律・CHANGELOG リリースのスキルと、code-reviewer / security-reviewer / planner エージェント
- java-dev: Java / Spring Boot の規約・セキュリティ・テスト・パターン・検証ループのスキルと java-reviewer エージェント
- dotnet-dev: C# / ASP.NET Core / EF Core の規約・セキュリティ・テスト・パターンのスキルと dotnet-reviewer エージェント
- docs: 日本語テクニカルライティング・Markdown 規約・HTML 設計書・Office 文書ツール・HTML スライドのスキルと doc-reviewer エージェント
- チーム共有 CLAUDE.md テンプレート（templates/CLAUDE.md）
- タグ push で GitHub Release 作成と Slack 通知を行うリリースワークフロー

### その他

- 移行元・ローカル専用設定・削除候補を記録した MIGRATION.md を同梱
