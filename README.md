# claude-common-plugins

チーム共有用の Claude Code プラグイン群（マーケットプレイス名: `mori-claude-tools`）。

## Overview

このリポジトリは、これまで各自の `~/.claude` に置かれていた開発規約・レビュー観点・文書作成規範を、Claude Code のプラグインとして再構成し、チームで共有できるようにしたものである。

配布単位は 4 プラグイン。いずれも skills と agents だけで構成され、hooks・MCP サーバー・実行バイナリは同梱していない。したがってインストールしてもローカル環境で勝手にコマンドが走ることはなく、Windows 固有の実行系にも依存しない。

移行の経緯・出典・既知の劣化については [MIGRATION.md](MIGRATION.md) を参照。

## Plugins

| Plugin | Skills | Agents | 用途 |
| --- | --- | --- | --- |
| `core-dev` | 8 | 3 | 言語非依存の開発ワークフロー（規約・レビュー・TDD・セキュリティ・git・API 設計・テスト実行規律） |
| `java-dev` | 5 | 1 | Java / Spring Boot の規約・パターン・セキュリティ・テスト・検証ループ |
| `dotnet-dev` | 4 | 1 | C# / .NET / ASP.NET Core / EF Core の規約・パターン・セキュリティ・テスト |
| `docs` | 7 | 1 | 技術文書作成（日本語ライティング、Markdown、HTML 設計書、Office 文書、HTML スライド） |

いずれも `version` は `0.1.0`。プラグインは個別にインストールでき、必要なものだけを有効化してよい。

## Available Skills

スキル名はインストール後に `plugin:skill` の形で名前空間化される。

### core-dev

| Skill | 用途 |
| --- | --- |
| `core-dev:api-design` | REST/HTTP API のリソース命名、HTTP メソッドとステータスコード、エラー応答、ページング、バージョニングの設計規範 |
| `core-dev:changelog-commit` | CHANGELOG 更新・バージョンバンプ・コミット・タグ・push を一括実行する（原則 main ブランチ専用） |
| `core-dev:code-review` | 変更差分を深刻度付きでレビューし、承認・警告・ブロックの可否を判断する |
| `core-dev:coding-standards` | 命名、ファイル分割、エラー処理、入力検証など、コードを書く側の品質規約 |
| `core-dev:git-workflow` | コミットメッセージと PR の作法、サブエージェント並列実行中の git 操作規律 |
| `core-dev:security-check` | コミット前のセキュリティ点検（認証・認可・入力検証・DB クエリ・秘密情報の扱い） |
| `core-dev:tdd-testing` | RED-GREEN-REFACTOR の TDD サイクルとカバレッジ基準に沿ってテストを書く |
| `core-dev:test-run-discipline` | テスト実行と結果報告の作法。実行は同梱の `run-tests.sh` 経由に統一する |

### java-dev

| Skill | 用途 |
| --- | --- |
| `java-dev:java-conventions` | Java の命名、不変性、モダン構文、Optional/Stream、例外、プロジェクト構成、アーキテクチャパターン |
| `java-dev:java-security` | 秘密情報管理、SQL インジェクション対策、入力検証、認証・認可、依存スキャン |
| `java-dev:java-testing` | JUnit 5、Mockito、AssertJ、MockMvc、Testcontainers、JaCoCo カバレッジ |
| `java-dev:springboot-patterns` | Spring Boot の REST 設計、レイヤ構成、JPA、キャッシュ、非同期、リトライ、レート制限、可観測性 |
| `java-dev:springboot-verification` | PR 前・リファクタ後・デプロイ前のビルド、静的解析、テスト、セキュリティスキャン、差分レビューの検証ループ |

### dotnet-dev

| Skill | 用途 |
| --- | --- |
| `dotnet-dev:aspnet-patterns` | ASP.NET Core / EF Core のオプション束縛、DI ライフタイム、Minimal API、ミドルウェア、Result パターン、リポジトリ |
| `dotnet-dev:dotnet-conventions` | C# の null 許容参照型、不変性、async/await、エラー処理、ガード節、書式 |
| `dotnet-dev:dotnet-security` | 秘密情報管理、SQL インジェクション対策、入力検証、認証・認可、安全なエラー処理 |
| `dotnet-dev:dotnet-testing` | xUnit、FluentAssertions、モック、統合テスト、テストコードの構成 |

### docs

| Skill | 用途 |
| --- | --- |
| `docs:anydoc` | Office ファイル（xlsx/docx/pptx/pdf/ods 等）を Markdown へ変換する CLI `anydoc` の導入と使用 |
| `docs:cognitive-rhythm-writing` | 説明的な文章に緩急（認知モードの切替と未回収の緊張）を設計するための規範 |
| `docs:frontend-slides` | アニメーション付き HTML プレゼンテーションの新規作成、および PowerPoint からの変換 |
| `docs:html-design-doc` | 設計書・説明書をスタンドアロン HTML（左サイドバー目次＋本文 1 カラム）で生成する。作図は既定で Mermaid |
| `docs:japanese-tech-writing` | 日本語技術文書の整形、段落と論証の構成、論証の厳密さ、冗長の排除 |
| `docs:markdown-conventions` | Markdown 出力時に必ず適用する記述規範（HTML 変換を前提とした空行ルール等） |
| `docs:officecli` | `officecli` CLI による Office 文書（.docx/.xlsx/.pptx）の作成・解析・校正・修正 |

## Available Agents

6 エージェントはいずれもこのリポジトリで新規に作成したものである（`~/.claude/agents` は存在せず、移行元のエージェント資産はない）。レビュー系の 5 つは `disallowedTools: Write, Edit` を指定しており、レビュー中にファイルを書き換えない。

| Agent | Model | 用途 |
| --- | --- | --- |
| `core-dev:code-reviewer` | sonnet | コード変更後・共有ブランチへのコミット前・PR マージ前に、深刻度順のレビュー結果を返す |
| `core-dev:security-reviewer` | sonnet | 認証・認可・入力・DB・ファイル操作・暗号・決済に触れる変更の脆弱性レビュー |
| `core-dev:planner` | opus | 複数ファイルにまたがる機能実装やリファクタの実装計画（フェーズ、スコープ、リスク、テスト戦略）を立てる |
| `java-dev:java-reviewer` | sonnet | Java / Spring Boot の変更（コントローラ、サービス、リポジトリ、DTO、テスト、ビルドファイル）のレビュー |
| `dotnet-dev:dotnet-reviewer` | sonnet | C# / .NET の変更（ASP.NET Core、EF Core、xUnit/NUnit テストプロジェクト）のレビュー |
| `docs:doc-reviewer` | sonnet | 日本語技術文書・Markdown 成果物を、このプラグインのライティング規範に照らしてレビュー |

## Team CLAUDE.md template

`templates/CLAUDE.md` は、`training-project-skills` の `claude-share/CLAUDE.md` を移行したチーム共有版の CLAUDE.md ひな形である。標準（バニラ）の Claude Code のみを前提としており、参照している各論スキル（コーディング規約・テスト・セキュリティ・レビュー・Git）は `core-dev` プラグインが提供する。

導入方法は、プロジェクトのルートに `CLAUDE.md` としてコピーするか、個人設定として `~/.claude/CLAUDE.md` にマージするかのいずれか。すでに `CLAUDE.md` がある場合は上書きせず、既存のルールと内容をマージすること。

```
claude plugin marketplace add TokyoItSchool-dev/claude-common-plugins
claude plugin install core-dev@mori-claude-tools
cp templates/CLAUDE.md ./CLAUDE.md
```

## Installation

マーケットプレイスを登録し、必要なプラグインを個別にインストールする。

```
claude plugin marketplace add TokyoItSchool-dev/claude-common-plugins
claude plugin install core-dev@mori-claude-tools
claude plugin install java-dev@mori-claude-tools
claude plugin install dotnet-dev@mori-claude-tools
claude plugin install docs@mori-claude-tools
```

### プロジェクト単位での自動登録

リポジトリの `.claude/settings.json` に以下を置くと、そのリポジトリで作業するメンバーに対してマーケットプレイスが自動登録され、指定したプラグインが有効になる。Java を使わないリポジトリで `java-dev` を有効にする必要はないので、`enabledPlugins` はプロジェクトごとに取捨選択する。

```json
{
  "extraKnownMarketplaces": {
    "mori-claude-tools": { "source": { "source": "github", "repo": "TokyoItSchool-dev/claude-common-plugins" } }
  },
  "enabledPlugins": { "core-dev@mori-claude-tools": true, "docs@mori-claude-tools": true }
}
```

### Claude Code on the Web

事実として確認できている点と、確認できていない点を分けて記す。

- 確認できている: プロジェクトの `.claude/settings.json` による自動登録は、チームメンバーへマーケットプレイスを配る手段としてドキュメントに記載がある。
- 確認できている: クラウドセッションは、接続された GitHub アカウントが参照できるリポジトリにアクセスできる。
- 確認できていない: Web セッションでプラグインが自動的にインストールされるかどうかは、ドキュメントに明示されていない。

前提条件として、GitHub App / 連携アカウントがプライベートリポジトリ `TokyoItSchool-dev/claude-common-plugins` へのアクセス権を持っている必要がある。実際に動くかどうかは最初の Web セッションで確認すること。

なお、このリポジトリは hooks を一切同梱していないため、Windows 固有のシェルやスクリプトが実行されることはない。

## Development

ローカルのプラグインディレクトリを直接読み込んで動作確認できる。フラグは繰り返し指定できる。

```
claude --plugin-dir ./plugins/core-dev
claude --plugin-dir ./plugins/core-dev --plugin-dir ./plugins/docs
```

`plugins/*/skills` 配下を編集した場合は、この方法でスキルが認識されること、および description のトリガー文が意図どおり発火することを確認してから push する。

## Validation

以下 13 コマンドがすべて終了コード 0 であることを確認する。

```
claude plugin validate ./plugins/core-dev --strict
claude plugin validate ./plugins/java-dev --strict
claude plugin validate ./plugins/dotnet-dev --strict
claude plugin validate ./plugins/docs --strict
claude plugin validate . --strict
claude plugin validate ./plugins/core-dev/skills --strict
claude plugin validate ./plugins/core-dev/agents --strict
claude plugin validate ./plugins/java-dev/skills --strict
claude plugin validate ./plugins/java-dev/agents --strict
claude plugin validate ./plugins/dotnet-dev/skills --strict
claude plugin validate ./plugins/dotnet-dev/agents --strict
claude plugin validate ./plugins/docs/skills --strict
claude plugin validate ./plugins/docs/agents --strict
```

重要な注意点として、プラグインディレクトリを指定した `claude plugin validate ./plugins/core-dev --strict` は **`plugin.json` マニフェストしか検証しない**（出力も `Validating plugin manifest:` となる）。skills と agents の内容を検証するには、`skills` / `agents` サブディレクトリを明示的に指定する必要がある（出力は `Validating components in:`）。CI を組む際は、上記 13 コマンドをすべて回すこと。

JSON の構文チェックは次のようにする。

```
python -c "import json,os; fs=[os.path.join(r,n) for r,d,f in os.walk('.') if '.git' not in r.split(os.sep) for n in f if n.endswith('.json')]; [json.load(open(p,encoding='utf-8')) for p in fs]; print('OK',len(fs))"
```

`glob.glob('**/*.json', recursive=True)` は使わないこと。glob は既定で先頭がドットのパスにマッチしないため、`.claude-plugin/` 配下のマニフェスト 5 件を 1 つも拾わず、検査対象 0 件のまま成功してしまう。Python 3.11 以降であれば `glob.glob(..., include_hidden=True)` でも代替できる。

## Update policy

- バージョンは SemVer に従い、`0.1.0` から始める。
- skills / agents に変更を加えたら、該当プラグインの `plugin.json` の `version` を必ず上げる。
- 利用側は `claude plugin marketplace update mori-claude-tools` を実行して更新を取り込む。
- `1.0.0` 以降は、破壊的変更（スキル名の変更・削除、トリガー条件の非互換な変更）でメジャーを上げる。
- リリースは `/core-dev:changelog-commit`（`docs/CHANGELOG.md` 更新・`vX.Y.Z` タグ付け。タグ push で Release ワークフローが GitHub Release 作成と Slack 通知を実行）で行う。

`version` フィールドについて。運用上は省略したかったが、`claude plugin validate --strict` は `version` の欠落を失敗として扱う。このため例外的に `0.1.0` を明記している。

`marketplace.json` については、ルート直下の `description` をバリデータがそのまま受け付けたため、`metadata` ブロックは追加していない。

## Local-only configuration

以下は個人環境固有のため、このリポジトリには移さず `~/.claude` に残す。

- `CLAUDE.md`（個人のオーケストレーション方針。Codex / ECC への依存を含む）
- `skills/orchestration-core`、`skills/codex-brief-review`（Codex 前提）
- `skills/local-vision-analysis`（lemonade server と PowerShell スクリプト、絶対パス依存）
- `skills/image-generation-style`（gpt-image-2 MCP サーバー前提）
- `rules/common/{agents,performance,hooks,development-workflow}.md`（Codex / ECC への言及を含む）
- `settings.json` / `settings.local.json`（権限設定、autoMode、マシン固有の絶対パス、絶対パス指定の `wt-local` マーケットプレイス）
- `.credentials.json`、`settings.json.glm`（認証情報を含む。**内容を共有・出力しないこと**）
- `.claude.json` の MCP `codex` サーバー定義

共有しない理由は 4 つに整理できる。第一に Codex / ECC プラグインへの依存があること。第二にローカル LLM や MCP サーバーという、マシンごとに存在が異なる実行系に依存すること。第三に絶対パスを含むこと。第四に認証情報そのものであること。

## Relationship to training-project-skills（棲み分け）

`training-project-skills` は、研修教材ドメインと個人方針を担当する。

- 研修教材ドメイン: `commands/MajorLectureMaterials/*`、`commands/generate-design-doc/*`
- 個人の Codex 依存方針: `claude-codex/`（CLAUDE.md、orchestration-core、rules/common）
- `claude-share/`（`templates/CLAUDE.md` + `core-dev` プラグインに置き換え済み。`training-project-skills` 側での削除は本リポジトリの公開後に別作業として行うため、それまでは現状のまま残る）

このリポジトリは、ドメインに依存しない再利用可能なプラグインを担当する。

現時点で両方に存在するスキルがある（`cognitive-rhythm-writing`、`html-design-doc`、`japanese-tech-writing`、`test-run-discipline`、`changelog-commit`、および `claude-share/skills/*`）。これらは、このマーケットプレイスの公開後に、別作業として `training-project-skills` 側から削除する予定である。
