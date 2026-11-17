# claude-common-plugins

チーム共有用の Claude Code プラグイン群（マーケットプレイス名: `mori-claude-tools`）。

## Overview

このリポジトリは、これまで各自の `~/.claude` に置かれていた開発規約・レビュー観点・文書作成規範を、Claude Code のプラグインとして再構成し、チームで共有できるようにしたものである。

配布単位は 7 プラグイン。`repo-workflow` を除く 6 プラグインは skills と agents だけで構成され、hooks・MCP サーバー・実行バイナリを同梱していない。これらはインストールしてもローカル環境でコマンドを実行せず、Windows 固有の実行系にも依存しない。

`repo-workflow` だけは、フック（`hooks/hooks.json`）とシェルスクリプト（`scripts/`。bash、git、gh、jq を使う）を同梱する。フックは有効にすると PreToolUse で Bash と GitHub MCP の書き込みのツール呼び出しのたびに動き、`main`・`develop`・ロックのブランチへの push と書き込みを拒否する。`bin/` と MCP サーバーは同梱しない。詳細は [repo-workflow](#repo-workflow-1) の節を参照。

移行の経緯・出典・既知の劣化については [MIGRATION.md](MIGRATION.md) を参照。

## Plugins

| Plugin | Skills | Agents | 用途 |
| --- | --- | --- | --- |
| `core-dev` | 10 | 3 | 言語非依存の開発ワークフロー（規約・レビュー・TDD・セキュリティ・git・API 設計・テスト実行規律・オーケストレーション） |
| `java-dev` | 5 | 1 | Java / Spring Boot の規約・パターン・セキュリティ・テスト・検証ループ |
| `dotnet-dev` | 4 | 1 | C# / .NET / ASP.NET Core / EF Core の規約・パターン・セキュリティ・テスト |
| `web-dev` | 4 | 1 | TypeScript / React + Vite / Hono の規約・パターン、Vitest のテスト |
| `python-dev` | 3 | 1 | Python / uv / FastAPI / Pydantic の規約・パターン、pytest のテスト |
| `repo-workflow` | 4 | 0 | テンプレートから作ったリポジトリの Issue -> PR -> develop の手順（着手、PR の引き渡しと develop へのマージ、リリース準備、自動着手）、マージとロックのスクリプト、push のガードのフック |
| `docs` | 8 | 1 | 技術文書作成（日本語ライティング、Markdown、HTML 設計書、Office 文書、HTML スライド） |

プラグインは個別にインストールでき、必要なものだけを有効化してよい。

## Available Skills

スキル名はインストール後に `plugin:skill` の形で名前空間化される。

### core-dev

| Skill | 用途 |
| --- | --- |
| `core-dev:api-design` | REST/HTTP API のリソース命名、HTTP メソッドとステータスコード、エラー応答、ページング、バージョニングの設計規範 |
| `core-dev:changelog-commit` | CHANGELOG 更新・バージョンバンプ・コミット・タグ・push を一括実行する（原則 main ブランチ専用。main への直接 push を禁止するリポジトリではリリースブランチから PR を作成） |
| `core-dev:code-review` | 変更差分を深刻度付きでレビューし、承認・警告・ブロックの可否を判断する |
| `core-dev:config-sync` | HOME（`~/.claude`）・training-project-skills・claude-common-plugins の 3 拠点で CLAUDE.md / rules / skills / commands を同期し、差分を検査する |
| `core-dev:coding-standards` | 命名、ファイル分割、エラー処理、入力検証など、コードを書く側の品質規約 |
| `core-dev:git-workflow` | コミットメッセージと PR の作法、サブエージェント並列実行中の git 操作規律 |
| `core-dev:orchestration-core` | サブエージェントへの委譲・モデル選択・委譲プロンプト雛形・受入判定と検証の手順。`templates/CLAUDE.md` が参照する。Codex は任意で、ない場合は本スキル記載のフォールバックを使う |
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

### web-dev

| Skill | 用途 |
| --- | --- |
| `web-dev:typescript-conventions` | TypeScript のコンパイラオプション、実行環境ごとの tsconfig、型安全、型だけの import、I/O と現在時刻を持たないドメイン層、ESLint、Prettier、npm の使い方 |
| `web-dev:react-patterns` | React + Vite の構成、コンポーネント、中断できるデータ取得、取得中・失敗・取得済みの区別、エラー境界、型付きの API クライアント、アクセシビリティ、クライアント側のセキュリティ |
| `web-dev:hono-patterns` | Hono の依存を注入するアプリのファクトリ、型付きの Bindings と Variables、ルーターとミドルウェアの順序、入力の検証、エラー応答、Web 標準の API だけを使う制約、Cloudflare Workers と D1 |
| `web-dev:vitest-testing` | Vitest のテストの配置、実行環境ごとの projects、`app.request` による Hono のテスト、Testing Library と jsdom による React のテスト、モック、時刻の固定、テストの実行 |

### python-dev

| Skill | 用途 |
| --- | --- |
| `python-dev:python-conventions` | Python の最低バージョン、uv のプロジェクトとロックファイル、pyproject.toml、検査コマンド（ruff、mypy、pytest、pip-audit）、型ヒント、I/O と現在時刻を持たないドメイン層、例外の扱い、クラウドセッションでのパッケージの取得 |
| `python-dev:fastapi-patterns` | FastAPI のアプリのファクトリと lifespan、`Depends` と `Annotated` による依存、pydantic-settings による設定、ルーター、入力と出力で分けた Pydantic モデル、入力の検証、エラー応答、`def` と `async def` の使い分け、データベースへのアクセス |
| `python-dev:pytest-testing` | pytest のテストの配置と pyproject.toml の設定、fixture と conftest.py、`TestClient` による FastAPI のテスト、`dependency_overrides` による依存の差し替え、parametrize、時刻と環境変数の固定、SQLite のテスト用データベース、uv によるテストの実行 |

### repo-workflow

| Skill | 用途 |
| --- | --- |
| `repo-workflow:issue-to-pr` | Issue の着手条件を確かめ、実装・テスト・独立レビューを行い、base が develop の Draft PR を作り、`repo-workflow:pr-handoff` へ進める |
| `repo-workflow:pr-handoff` | PR の差分・テスト証跡・独立レビューを確かめ、本文を必須項目にそろえて Ready にし、条件を満たせば `merge-pr.sh` で develop へマージする |
| `repo-workflow:release-prep` | リリースブランチ、CHANGELOG、受入テスト手順書、develop 宛てのリリース PR、develop -> main の PR 用の Closes 一覧と人間が確認する変更の一覧を作る |
| `repo-workflow:issue-pickup` | `ai:ready` を起点とするスケジュールタスク（自動着手）の手順書。ロック、キュー、着手、develop へのマージと、`plugin_sha` からのスクリプトの取得（2.0）を定める |

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
| `docs:uml-svg` | UML 8 種を、編集できて拡大しても劣化しない手書き SVG で作図する（PNG 描画と記法チェックリストで検証）。構成案パッケージ図・画像からの SVG 再現・UML 以外の図は `/docs:uml-svg` の明示呼び出し時のみ |

## Available Agents

8 エージェントはいずれもこのリポジトリで新規に作成したものである（`~/.claude/agents` は存在せず、移行元のエージェント資産はない）。レビュー系の 7 つは `disallowedTools: Write, Edit` を指定しており、レビュー中にファイルを書き換えない。

| Agent | Model | 用途 |
| --- | --- | --- |
| `core-dev:code-reviewer` | sonnet | コード変更後・共有ブランチへのコミット前・PR マージ前に、深刻度順のレビュー結果を返す |
| `core-dev:security-reviewer` | sonnet | 認証・認可・入力・DB・ファイル操作・暗号・決済に触れる変更の脆弱性レビュー |
| `core-dev:planner` | opus | 複数ファイルにまたがる機能実装やリファクタの実装計画（フェーズ、スコープ、リスク、テスト戦略）を立てる |
| `java-dev:java-reviewer` | sonnet | Java / Spring Boot の変更（コントローラ、サービス、リポジトリ、DTO、テスト、ビルドファイル）のレビュー |
| `dotnet-dev:dotnet-reviewer` | sonnet | C# / .NET の変更（ASP.NET Core、EF Core、xUnit/NUnit テストプロジェクト）のレビュー |
| `web-dev:web-reviewer` | sonnet | TypeScript の Web の変更（React + Vite、Hono、Vitest のテスト、tsconfig・ESLint・package.json）のレビュー |
| `python-dev:python-reviewer` | sonnet | Python の変更（FastAPI、Pydantic、pytest のテスト、pyproject.toml・uv.lock）のレビュー |
| `docs:doc-reviewer` | sonnet | 日本語技術文書・Markdown 成果物を、このプラグインのライティング規範に照らしてレビュー |

## Team CLAUDE.md template

`templates/CLAUDE.md` は、`training-project-skills` の `claude-share/CLAUDE.md` を移行したチーム共有版の CLAUDE.md ひな形である。標準（バニラ）の Claude Code のみを前提としており、参照している各論スキル（コーディング規約・テスト・セキュリティ・レビュー・Git）は `core-dev` プラグインが提供する。

導入方法は、プロジェクトのルートに `CLAUDE.md` としてコピーするか、個人設定として `~/.claude/CLAUDE.md` にマージするかのいずれか。すでに `CLAUDE.md` がある場合は上書きせず、既存のルールと内容をマージすること。

```
claude plugin marketplace add TokyoItSchool-dev/claude-common-plugins --scope project
claude plugin install core-dev@mori-claude-tools --scope project
cp templates/CLAUDE.md ./CLAUDE.md
```

## Installation

マーケットプレイスを登録し、必要なプラグインを個別にインストールする。既定は `--scope project` である。これにより、マーケットプレイスとプラグインがリポジトリの `.claude/settings.json` に記録され、git 経由でチームメンバーと共有される。

```
claude plugin marketplace add TokyoItSchool-dev/claude-common-plugins --scope project
claude plugin install core-dev@mori-claude-tools --scope project
claude plugin install java-dev@mori-claude-tools --scope project
claude plugin install dotnet-dev@mori-claude-tools --scope project
claude plugin install web-dev@mori-claude-tools --scope project
claude plugin install python-dev@mori-claude-tools --scope project
claude plugin install repo-workflow@mori-claude-tools --scope project
claude plugin install docs@mori-claude-tools --scope project
```

`repo-workflow` は、テンプレート（`TokyoItSchool-dev/claude-dev-template` とその派生）から作ったリポジトリだけで有効にする。使う前に、下の [repo-workflow](#repo-workflow-1) の節の設定ファイルと sha の固定を行う。

### 個人環境へのインストール（オプション）

プロジェクト単位ではなく、個人環境として全プロジェクト共通でインストールしたい場合は、CLI の既定値である `--scope user` を使う。

```
claude plugin marketplace add TokyoItSchool-dev/claude-common-plugins --scope user
claude plugin install core-dev@mori-claude-tools --scope user
cp ~/.claude/plugins/marketplaces/mori-claude-tools/templates/CLAUDE.md ./CLAUDE.md
```

### プロジェクト単位での自動登録

上記の `--scope project` コマンドは、以下と同じ設定をリポジトリの `.claude/settings.json` に自動で書き込む。手動で書きたい場合のために JSON を示す。Java を使わないリポジトリで `java-dev` を有効にする必要はないので、`enabledPlugins` はプロジェクトごとに取捨選択する。

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

`TokyoItSchool-dev/claude-common-plugins` は公開リポジトリである。`repo-workflow:issue-pickup` の 2.0（スクリプトの取得）は、このリポジトリを認証なしの https で `git fetch` するため、公開であることを前提にしている。非公開に変えると、この取得が失敗し、2.0 の「取得に失敗したとき」のとおり、無人実行はロックにもキューにも触れずに終了し、対話のセッションはマージせずに止まる。プラグインのインストールが Web セッションで動くかどうかは、最初の Web セッションで確認すること。

`repo-workflow` を除くプラグインは hooks を同梱していないため、Windows 固有のシェルやスクリプトを実行しない。`repo-workflow` のフックとスクリプトは bash 4.2 以降、git、jq（`merge-pr.sh` と `pickup.sh` は gh も）を使う。

## repo-workflow

`repo-workflow` は、テンプレートから作ったリポジトリ（以下 consumer）が写しとして持っていたスキル、手順書、スクリプト、フックをまとめたプラグインである（#8、#9）。consumer のルールファイル（`.claude/rules/repository-workflow.md`、`dashboard-contract.md`）、`scripts/run-checks.sh`、`.claude/hooks/session-start.sh` は consumer に残す。

| パス | 内容 |
| --- | --- |
| `skills/` | `issue-to-pr`、`pr-handoff`、`release-prep`、`issue-pickup` |
| `scripts/merge-pr.sh` | develop へのマージの直前の条件を確かめてマージする |
| `scripts/pickup.sh` | 自動着手のロック（`claude/active-work`）とキューを操作する |
| `scripts/pre-push-guard.sh`、`scripts/mcp-branch-guard.sh` | PreToolUse のガード（`hooks/hooks.json` で登録する） |
| `tests/` | 上のスクリプトのテスト。`bash plugins/repo-workflow/tests/run-all.sh` で全件を実行する |
| `config/repo-workflow.example.json` | consumer の設定ファイルの例 |

### consumer の設定ファイル（`.claude/repo-workflow.json`）

consumer のリポジトリのルートの `.claude/repo-workflow.json` に置く。プラグインには置かない。

```json
{
  "plugin_sha": "<claude-common-plugins の 40 桁のコミット sha>",
  "gated_paths": ["app/src/appsscript.json"],
  "pre_check_commands": ["npm ci"]
}
```

| キー | 必須 | 形 | 意味 |
| --- | --- | --- | --- |
| `plugin_sha` | はい | 40 桁の小文字の 16 進数 | `merge-pr.sh` と `pickup.sh`（と手順書）を取得する claude-common-plugins のコミット。タグ、ブランチ名、短い sha は使わない |
| `gated_paths` | はい | 空でない文字列の配列（空の配列も可） | `merge-pr.sh` が `reason=gated-path` で止める変更のパス。bash のパターンで、`*` は `/` にも一致する。PR の変更ファイルと、名前を変えたファイルの元の名前に当てる。旧 `merge-pr.sh` の `GATED_PATHS` と同じ書き方 |
| `pre_check_commands` | いいえ（既定は空） | 文字列の配列 | `bash scripts/run-checks.sh` の前に、リポジトリのルートで順に実行するコマンド（例: `["npm ci"]`）。どれかが失敗すると検査の失敗として扱う |

読み方の規則:

- 設定はすべて consumer の `origin` の `main` の版を読む。作業ツリー、作業ブランチ、PR のブランチの設定ファイルは読まない。このため、PR が設定ファイルを変えても、人間がその変更を `main` へマージするまで判定は変わらない。
- `merge-pr.sh` は、`origin` の `main` の先頭（`git ls-remote` で読み、手元になければ `git fetch` する）の設定ファイルから `gated_paths` を読む。`main` の先頭のコミットに設定ファイルがないときは `result=stop reason=config-missing`、JSON でない、オブジェクトでない、`gated_paths` が空でない文字列（制御文字を含まない）の配列でないときは `result=stop reason=config-invalid` で止める。`main` を読めないとき（`ls-remote` の失敗、`main` がない、名前が `refs/heads/main` と完全に一致する行が 2 行以上、`fetch` の失敗）は `result=unknown step=config`。
- `gated_paths` が空でないとき、`merge-pr.sh` は PR の変更ファイルの一覧（`pulls/<n>/files`。GitHub は 3000 件までしか返さない）の件数を PR の `changed_files` と比べる。違うとき、または 3000 件以上のときは、一覧にないファイルを確かめられないため `result=stop reason=files-incomplete listed=<k> changed_files=<n>` で止める。`changed_files` が数でないときは `result=unknown step=files`。
- `ls-remote` のパターンは ref の名前の末尾でも一致する（`claude/1-x/refs/heads/main` というブランチも `refs/heads/main` に当たる）。`merge-pr.sh` と `pickup.sh` は、名前が `refs/heads/main`、`refs/heads/develop`、`refs/heads/claude/active-work` と完全に一致する行だけを使う。
- #8 D1 の付随の決定により、`.claude/repo-workflow.json` と `.claude/settings.json` を既定の `gated_paths` に入れない（D-07 のまま）。必要なリポジトリは自分の `gated_paths` に書く。

リポジトリごとの値の例（#8 の差分の表から）:

| リポジトリ | `gated_paths` | `pre_check_commands` |
| --- | --- | --- |
| claude-dev-template、claude-dev-template-test | `[]` | `[]` |
| claude-dev-template-gas | `["app/src/appsscript.json"]` | `[]` |
| kintone-ai-dev-template | 今の `GATED_PATHS` の 28 個のパターン（`tests/test-merge-pr.sh` の `GATED_KINTONE`）と `.claude/repo-workflow.json`（今の `GATED_PATHS` が持つ `.claude/routines/merge-pr.sh` に代わり、`plugin_sha` と `gated_paths` の変更を止める） | `["npm ci"]` |
| claude-portfolio-dashboard | `[]` | `["npm ci"]` |

### スクリプトの取得と sha の固定

スキルと手順書は、`merge-pr.sh` と `pickup.sh` を、セッションが読み込んだプラグインからではなく、consumer の `main` の `plugin_sha` のコミットから一時ディレクトリへ取得して使う（#8 D1-B）。手順は `repo-workflow:issue-pickup` の 2.0 に書いてある。要点は次のとおり。

```
d="$(mktemp -d)"
git fetch --quiet origin +refs/heads/main:refs/remotes/origin/main
m="$(git rev-parse --verify 'refs/remotes/origin/main^{commit}')"   # 短い名前 origin/main はタグ refs/tags/origin/main が先に当たるため使わない
git show "$m":.claude/repo-workflow.json > "$d/repo-workflow.json"
jq -r '.plugin_sha' "$d/repo-workflow.json"          # ^[0-9a-f]{40}$ であることを確かめる
git init --quiet --bare "$d/plugin.git"
git -C "$d/plugin.git" fetch --quiet https://github.com/TokyoItSchool-dev/claude-common-plugins +refs/heads/main:refs/remotes/upstream/main
git -C "$d/plugin.git" merge-base --is-ancestor <plugin_sha> refs/remotes/upstream/main   # 終了コード 0 のときだけ続ける
git -C "$d/plugin.git" show <plugin_sha>:plugins/repo-workflow/scripts/merge-pr.sh > "$d/merge-pr.sh"
git -C "$d/plugin.git" show <plugin_sha>:plugins/repo-workflow/scripts/pickup.sh > "$d/pickup.sh"
```

どれかの手順が失敗したときは、マージもロックの操作もせずに止まって報告する。`plugin_sha` が claude-common-plugins の `main` の履歴にないとき（`merge-base --is-ancestor` の終了コードが 0 でないとき）も失敗とする。GitHub はフォークに push されたコミットも元のリポジトリの URL で渡すため、sha だけを取得せず、`main` を取得してその履歴にあることを確かめる。`main` は `--depth` を付けずに取得する（深さを限ると、それより古い `plugin_sha` の祖先関係を確かめられないため）。Bash から `${CLAUDE_PLUGIN_ROOT}` でスクリプトを呼ばない（Bash ツールの環境にはこの変数が入らず、指す版もセッションの読み込みで決まるため）。

#8 D3-C により、consumer の `.claude/settings.json` のマーケットプレイスも同じ sha に固定する。

```json
{
  "extraKnownMarketplaces": {
    "mori-claude-tools": {
      "source": { "source": "github", "repo": "TokyoItSchool-dev/claude-common-plugins", "ref": "<plugin_sha と同じ sha>" }
    }
  },
  "enabledPlugins": { "core-dev@mori-claude-tools": true, "repo-workflow@mori-claude-tools": true }
}
```

- `source.ref` に commit sha を書くには Claude Code v2.1.324 以降が要る。
- `ref` を固定すると、同じマーケットプレイスの全プラグイン（core-dev、docs など）が同じ sha に固定される。
- 上げるときは、consumer への 1 つの PR で `plugin_sha` と `ref` を同時に変える。claude-common-plugins の `main` が変わっても、consumer の `main` の固定値を変える PR を人間が `main` へマージするまで、consumer の判定は変わらない。
- `plugins/repo-workflow/` を変える claude-common-plugins の PR は、人間がマージする（#8 D1）。

### フック

`hooks/hooks.json` は、`pre-push-guard.sh`（matcher `Bash`）と `mcp-branch-guard.sh`（matcher `mcp__github__push_files|mcp__github__create_or_update_file|mcp__github__delete_file`）を `"${CLAUDE_PLUGIN_ROOT}"/scripts/...` で登録する。

#8 D2-B により、consumer は、プラグインのフックがスケジュールタスクの実行で最初のツール呼び出しから動くと確かめるまで、自分の `.claude/hooks/` のガードの写しを `.claude/settings.json` から呼び続ける。その間は、プラグインを有効にしたセッションで同じガードが 2 回動く。2 つは同じ操作を拒否するため、重複してもよい。

プラグインは `permissions` を持てない。`mcp__github__merge_pull_request`、`mcp__github__enable_pr_auto_merge`、`mcp__github__update_pull_request_branch` の拒否は、consumer の `.claude/settings.json` の `permissions.deny` に残す。

## Development

ローカルのプラグインディレクトリを直接読み込んで動作確認できる。フラグは繰り返し指定できる。

```
claude --plugin-dir ./plugins/core-dev
claude --plugin-dir ./plugins/core-dev --plugin-dir ./plugins/docs
```

`plugins/*/skills` 配下を編集した場合は、この方法でスキルが認識されること、および description のトリガー文が意図どおり発火することを確認してから push する。

## Validation

以下 21 コマンドがすべて終了コード 0 であることを確認する。

```
claude plugin validate ./plugins/core-dev --strict
claude plugin validate ./plugins/java-dev --strict
claude plugin validate ./plugins/dotnet-dev --strict
claude plugin validate ./plugins/web-dev --strict
claude plugin validate ./plugins/python-dev --strict
claude plugin validate ./plugins/repo-workflow --strict
claude plugin validate ./plugins/docs --strict
claude plugin validate . --strict
claude plugin validate ./plugins/core-dev/skills --strict
claude plugin validate ./plugins/core-dev/agents --strict
claude plugin validate ./plugins/java-dev/skills --strict
claude plugin validate ./plugins/java-dev/agents --strict
claude plugin validate ./plugins/dotnet-dev/skills --strict
claude plugin validate ./plugins/dotnet-dev/agents --strict
claude plugin validate ./plugins/web-dev/skills --strict
claude plugin validate ./plugins/web-dev/agents --strict
claude plugin validate ./plugins/python-dev/skills --strict
claude plugin validate ./plugins/python-dev/agents --strict
claude plugin validate ./plugins/repo-workflow/skills --strict
claude plugin validate ./plugins/docs/skills --strict
claude plugin validate ./plugins/docs/agents --strict
```

重要な注意点として、プラグインディレクトリを指定した `claude plugin validate ./plugins/core-dev --strict` は **`plugin.json` マニフェストしか検証しない**（出力も `Validating plugin manifest:` となる）。skills と agents の内容を検証するには、`skills` / `agents` サブディレクトリを明示的に指定する必要がある（出力は `Validating components in:`）。CI を組む際は、上記 21 コマンドをすべて回すこと。`repo-workflow` はエージェントを持たないため、`agents` の検証はない。

`repo-workflow` のスクリプトのテストは `bash plugins/repo-workflow/tests/run-all.sh` で実行する（bash 4.2 以降、git、jq が必要。ネットワークは使わない）。1 件でも失敗すれば終了コードが 0 以外になる。

JSON の構文チェックは次のようにする。

```
python -c "import json,os; fs=[os.path.join(r,n) for r,d,f in os.walk('.') if '.git' not in r.split(os.sep) for n in f if n.endswith('.json')]; [json.load(open(p,encoding='utf-8')) for p in fs]; print('OK',len(fs))"
```

`glob.glob('**/*.json', recursive=True)` は使わないこと。glob は既定で先頭がドットのパスにマッチしないため、`.claude-plugin/` 配下のマニフェスト 8 件を 1 つも拾わず、検査対象 0 件のまま成功してしまう。Python 3.11 以降であれば `glob.glob(..., include_hidden=True)` でも代替できる。

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
- `skills/codex-brief-review`（Codex 前提。`skills/orchestration-core` は `core-dev:orchestration-core` として移行済み）
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
