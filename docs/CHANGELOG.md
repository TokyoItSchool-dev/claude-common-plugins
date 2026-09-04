# 変更履歴 (CHANGELOG)

本ドキュメントは claude-common-plugins の変更履歴を記録します。

<!-- 新しいエントリはこの行の直下に追加 -->

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
