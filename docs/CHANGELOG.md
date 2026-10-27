# 変更履歴 (CHANGELOG)

本ドキュメントは claude-common-plugins の変更履歴を記録します。

<!-- 新しいエントリはこの行の直下に追加 -->

## [0.1.8] - 2026-10-27

### 追加
- docs: html-design-doc: SVG 作図の規約（配色・寸法・title/desc・矢印）

### 変更
- docs: html-design-doc: 作図の既定を Mermaid から SVG 直書きに変更（Mermaid・PlantUML は明示指示時のみ）
- docs プラグインのバージョンを 0.1.3 に更新

## [0.1.7] - 2026-10-23

### 変更
- core-dev の changelog-commit: タグの作成を major / minor のバンプ、またはユーザーがタグ作成を明示した場合だけに変更。build（引数なしの既定を含む）ではタグを作成せず、GitHub Release も作成しない
- core-dev プラグインのバージョンを 0.2.2 に更新

## [0.1.6] - 2026-10-21

### 変更
- core-dev の orchestration-core: サブエージェントの effort はモデルごとの既定を使う方針に変更。Agent ツールの `effort` と Workflow の `opts.effort` はユーザーが明示した場合のみ指定し、委譲文冒頭で思考の深さを指示する運用を廃止
- core-dev の config-sync: 同期拠点に claude-dev-template を追加。同期対象は CLAUDE.md のみで、templates/CLAUDE.md を同期元とする
- core-dev プラグインのバージョンを 0.2.1 に更新

## [0.1.5] - 2026-10-19

### 追加
- core-dev の orchestration-core に Agent Teams の運用ルール（チームメイトの役割規則、チームを組む判断基準、チームメイトのモデル選択、チームメイト起動文の雛形）
- テンプレート CLAUDE.md に Agent Teams の節（自分の立場の判定、チームを組む条件）
- docs: html-design-doc に pack_doc.py（原稿の CSS・JS・画像を 1 つの単体 HTML にまとめる）を追加。印刷時は目次が PDF の 1 ページ目になり、図の `figure` / `figcaption` と手動改ページ用のスタイルを追加

### 改善
- docs: html-design-doc の原稿は CSS・JS を `<link>` / `<script src>` で参照する構成に変更。テンプレートが大幅に短くなり、検証は pack_doc.py の実行に一本化

### 変更
- core-dev プラグインのバージョンを 0.2.0 に更新
- config-sync の同期対象表を pack_doc.py・test_pack_doc.py の追加に合わせて更新

### 削除
- docs: html-design-doc の embed_images.py（画像の data URI 化は pack_doc.py に統合）

## [0.1.4] - 2026-10-05

### 追加
- core-dev に orchestration-core スキル（モデルルーティング、委譲規律、エスカレーション、検証）

### 変更
- テンプレート CLAUDE.md を縮小し、方針の詳細を core-dev:orchestration-core 参照に変更。スキル未導入時に core-dev プラグインをインストールする指示を追加
- README と MIGRATION を orchestration-core の同梱に合わせて更新

### 削除
- テンプレート CLAUDE.md のモデル割り当て以降の方針詳細、ワークフロー（機能実装ワークフローを除く）、タスク管理、コア原則、スキルの利用の各節

## [0.1.3] - 2026-09-25

### 変更
- config-sync の同期対象外リストを更新（coding-standards / api-design を対象外から外す）

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
