# MIGRATION

`~/.claude` および `C:/git/training-project-skills/claude-share` に散在していた個人設定・規約・スキルを、チーム共有プラグイン（`mori-claude-tools`）へ移行した記録である。何をどこへ移したか、何を意図的に変えたか、何を残したか、そして何が劣化したかを記す。

移行元は次の 4 か所。

- `~/.claude/skills/*`
- `~/.claude/rules/*`
- `~/.claude/commands/*`
- `C:/git/training-project-skills/claude-share/skills/*`

`~/.claude/agents` は存在しない。したがって移行されたエージェントは 0 件であり、本リポジトリの 6 エージェントはすべて新規作成である。

## Migrated

### core-dev

| 移行元 | 移行先 |
| --- | --- |
| `claude-share/skills/code-review` + `rules/common/code-review.md` | `core-dev:code-review` |
| `claude-share/skills/coding-standards` + `rules/common/coding-style.md` | `core-dev:coding-standards` |
| `claude-share/skills/git-workflow` + `rules/common/git-workflow.md` | `core-dev:git-workflow` |
| `claude-share/skills/security-check` + `rules/common/security.md` | `core-dev:security-check` |
| `claude-share/skills/tdd-testing` + `rules/common/testing.md` | `core-dev:tdd-testing` |
| `skills/api-design` | `core-dev:api-design` |
| `skills/test-run-discipline`（`scripts/run-tests.sh` を含む） | `core-dev:test-run-discipline` |
| `commands/changelog-commit.md` | `core-dev:changelog-commit`（コマンドからスキルへ変換） |

`claude-share` 側の 5 スキルをベースとし、`rules/common` の対応ファイルの内容を統合している（詳細は Merged 節）。

### java-dev

| 移行元 | 移行先 |
| --- | --- |
| `rules/java/coding-style.md` + `rules/java/patterns.md` + `rules/java/hooks.md` + `skills/java-coding-standards` | `java-dev:java-conventions` |
| `rules/java/security.md` | `java-dev:java-security` |
| `rules/java/testing.md` + `skills/springboot-tdd` | `java-dev:java-testing` |
| `skills/springboot-patterns` | `java-dev:springboot-patterns` |
| `skills/springboot-verification` | `java-dev:springboot-verification` |

### dotnet-dev

| 移行元 | 移行先 |
| --- | --- |
| `rules/csharp/coding-style.md` + `rules/csharp/hooks.md` | `dotnet-dev:dotnet-conventions` |
| `rules/csharp/security.md` | `dotnet-dev:dotnet-security` |
| `rules/csharp/testing.md` + ECC `skills/csharp-testing` | `dotnet-dev:dotnet-testing` |
| `rules/csharp/patterns.md` + ECC `skills/dotnet-patterns` | `dotnet-dev:aspnet-patterns` |

### docs

| 移行元 | 移行先 |
| --- | --- |
| `skills/japanese-tech-writing` | `docs:japanese-tech-writing` |
| `skills/cognitive-rhythm-writing` | `docs:cognitive-rhythm-writing` |
| `skills/markdown-conventions` | `docs:markdown-conventions` |
| `skills/html-design-doc` | `docs:html-design-doc` |
| `skills/officecli` | `docs:officecli` |
| `skills/anydoc` | `docs:anydoc` |
| `skills/frontend-slides` | `docs:frontend-slides` |

### templates

| 移行元 | 移行先 |
| --- | --- |
| `claude-share/CLAUDE.md` | `templates/CLAUDE.md`（スキル参照を `core-dev:*` に書き換え） |

## Modified

移行にあたって内容を意図的に変更した箇所。

- **`mvn` → `./mvnw`**: java-dev の全スキルで Maven の呼び出しを Maven Wrapper に統一した。マシンに Maven が入っている前提を外すため。
- **`run-tests.sh` のパス**: `core-dev:test-run-discipline` の参照先を `${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh` に書き換えた。プラグインとして配布される以上、絶対パスもリポジトリ相対パスも使えないため。
- **`.ecc-design/` → `.slide-previews/`**: `docs:frontend-slides` のプレビュー出力先を、ECC 由来の名前から中立な名前に変更した。
- **ECC 節の削除**: `docs:frontend-slides` から ECC プラグイン固有の記述を除去した。
- **サンドボックス可否の追記**: `docs:anydoc` と `docs:officecli` に、ネイティブ CLI バイナリの導入・実行が許可されない環境（Claude Code on the web 等）では実行できず、迂回策を試みずに中断する旨の節を追加した。
- **PlantUML jar の解決順**: `docs:html-design-doc` で、jar の解決を `PLANTUML_JAR` 環境変数 → PATH 上の `plantuml` コマンド → `scripts/plantuml.jar` の順とした。`plantuml.jar`（約 17MB）はリポジトリに含めず、`.gitignore` で `*.jar` を除外している。あわせて、Mermaid 経路は追加セットアップ不要でサンドボックスでも動作するが PlantUML 経路は動作しない場合がある旨を明記した。
- **プロジェクト固有識別子の一般化**: `core-dev:changelog-commit` から特定プロジェクトの識別子を除去し、コマンド固有の `arguments:` フロントマターを削除した（スキルには不要なため）。
- **相互参照の名前空間化**: core-dev の各スキルの description 内の相互参照を `core-dev:security-check` のような名前空間付き表記に書き換えた。
- **フック定義の非同梱**: `~/.claude/settings.json` に `hooks` キーは存在せず（grep 一致 0 件）、`rules/*/hooks.md` はドキュメントにすぎなかった。この内容は `java-dev:java-conventions` と `dotnet-dev:dotnet-conventions` の「Recommended Hooks」節（利用者が自分の settings に設定するための推奨事項）として畳み込み、`hooks.json` は同梱していない。
- **テスト実装例の重複排除**: `java-dev/skills/springboot-verification/SKILL.md` から `java-testing` と重複するテスト実装例（JUnit 5 / MockMvc / Testcontainers）を削除し `java-dev:java-testing` へのポインタに置換（235 行 → 131 行）。
- **Markdown 空行ルールの圧縮**: `core-dev/skills/coding-standards/SKILL.md` の Markdown 空行ルールを 1 行に圧縮し `docs:markdown-conventions` を参照。
- **相対パス参照の置換**: `docs/skills/cognitive-rhythm-writing/SKILL.md` の相対パス参照を `docs:japanese-tech-writing` に変更。
- **出典表記の更新**: java-dev / dotnet-dev の `## Origin` 行の "ECC 2.0.0" を出典 URL 付き表記に変更。

### 出典の照合（ECC 2.0.0 プラグインキャッシュとの diff）

移行元がどこまで ECC 由来だったかを確認した結果。

- **ECC とバイト一致**: `rules/java/*`、`rules/csharp/*`、`rules/php/*`、`rules/python/*`、`rules/react/*`、`rules/typescript/*`、`rules/common/{development-workflow,git-workflow,hooks,performance,security,testing}.md`
- **ローカルで改変済み**: `rules/common/{agents,code-review,coding-style}.md`、`rules/web/*`
- **`~/.claude/skills` と `training-project-skills` で一致**: `cognitive-rhythm-writing`、`japanese-tech-writing`、`test-run-discipline`、`orchestration-core`
- **両者で差異あり**: `html-design-doc`（`SKILL.md` と `references/plantuml-conventions.md`）

各スキルの末尾には `Derived from ECC 2.0.0 ...` の形で出典を記載してある（java-dev / dotnet-dev の全 9 スキル）。

## Merged

複数の移行元を 1 つのスキルに統合したもの。

- `core-dev` の 5 スキル（code-review、coding-standards、git-workflow、security-check、tdd-testing）は、`claude-share/skills` 側をベースに `rules/common` の対応ファイルを統合した。
- `java-dev:java-conventions` は `rules/java/coding-style.md`、`rules/java/patterns.md`、`rules/java/hooks.md`、`skills/java-coding-standards` の 4 つを統合したもの。
- `java-dev:java-testing` は `rules/java/testing.md` と `skills/springboot-tdd` の統合。
- `dotnet-dev:dotnet-testing` は `rules/csharp/testing.md` と ECC `skills/csharp-testing` の統合。
- `dotnet-dev:aspnet-patterns` は `rules/csharp/patterns.md` と ECC `skills/dotnet-patterns` の統合。`patterns.md` は分割されておらず全体がこのスキルへ移っている（`dotnet-conventions` に `patterns.md` 由来の節はない）。
- `dotnet-dev:dotnet-conventions` は `rules/csharp/coding-style.md` と `rules/csharp/hooks.md` の統合。

## Split

1 スキルが大きくなりすぎた箇所は `references/` に分割した。

- `java-dev:java-conventions` → `references/architecture-patterns.md`（リポジトリ、サービス層、DTO、ビルダー）
- `java-dev:springboot-patterns` → `references/resilience-and-middleware.md`（リトライ、レート制限、フィルタ、可観測性）
- `core-dev/skills/api-design/SKILL.md` の Implementation Patterns（TypeScript/Next.js, Python/DRF, Go の実装例）を `references/implementation-examples.md` に分離（526 行 → 421 行）。

`docs:html-design-doc` は移行前から `references/`（mermaid-conventions、plantuml-conventions、style.css、template.html）と `scripts/embed_images.py` を持っており、構成をそのまま維持している。

## New

このリポジトリで新規に作成したもの。移行元は存在しない。

| Agent | Model |
| --- | --- |
| `core-dev:code-reviewer` | sonnet |
| `core-dev:security-reviewer` | sonnet |
| `core-dev:planner` | opus |
| `java-dev:java-reviewer` | sonnet |
| `dotnet-dev:dotnet-reviewer` | sonnet |
| `docs:doc-reviewer` | sonnet |

レビュー系 5 エージェントには `disallowedTools: Write, Edit` を指定し、レビュー中にファイルを書き換えないようにしてある。

## Project-specific

各リポジトリ側に残すもの。共有プラグインには含めない。

- `~/.claude/commands/MajorLectureMaterials/*`（研修教材ドメイン → `training-project-skills` へ）
- `~/.claude/commands/generate-design-doc/*`（同上）
- 各プロジェクトの `CLAUDE.md` の内容

## Local-only

個人環境固有のため `~/.claude` に残すもの。

- `CLAUDE.md`（個人のオーケストレーション方針。Codex 依存）
- `skills/orchestration-core`、`skills/codex-brief-review`（Codex 前提）
- `skills/local-vision-analysis`（lemonade server と PowerShell スクリプト、絶対パス依存）
- `skills/image-generation-style`（gpt-image-2 MCP 前提）
- `rules/common/{agents,performance,hooks,development-workflow}.md`（Codex / ECC への言及を含む）
- `settings.json` / `settings.local.json`（権限設定、autoMode、マシン固有パス、絶対パス指定の `wt-local` マーケットプレイス）
- `.credentials.json`
- `settings.json.glm` — **API キーを含む。機微情報として扱い、内容を出力・共有・コミットしないこと。**
- `.claude.json` の MCP `codex` サーバー定義

## Deprecated

以下は「削除候補」であって、**この作業では一切削除していない**。

### ECC 由来のスキルコピー

`settings.json` の `skillOverrides` で既に無効化済みのもの。

`agent-introspection-debugging`、`agent-sort`、`backend-patterns`、`code-to-flowchart`、`code-tour`、`coding-standards`、`configure-ecc`、`council`、`eval-harness`、`frontend-design`、`golang-patterns`、`golang-testing`、`iterative-retrieval`、`java-coding-standards`、`mcp-server-patterns`、`plankton-code-quality`、`rust-patterns`、`rust-testing`、`skill-stocktake`、`springboot-patterns`、`springboot-tdd`、`springboot-verification`、`strategic-compact`、`agents-sdk`、`cloudflare-email-service`、`cloudflare-one`、`cloudflare-one-migrations`、`durable-objects`、`sandbox-sdk`、`turnstile-spin`、`web-perf`

### その他の削除候補

- `continuous-learning-v2`、`learned`（空）
- Cloudflare 系（`cloudflare` 約 2.1MB、`wrangler`、`workers-best-practices`）— ベンダー提供スキルであり 4 プラグインのスコープ外
- `settings.json.{bak,orig,pre-sanitize}`、`settings.local.json.pre-sanitize`
- `rules/{php,python,react,typescript,web}`、`skills/python-patterns`、`skills/python-testing`、`skills/frontend-patterns` — 今回の 4 プラグインのスコープ外。将来の `python-dev` / `web-dev` プラグインの候補として保留する

### 移行済みオリジナルの扱い

プラグインのインストール完了後、`~/.claude/skills` にある移行済みスキルのオリジナル、および `~/.claude/rules/{java,csharp}` は削除可能になる。ただし Known regressions の 3 点目に記載の依存があるため、削除は別タスクとして扱う。

## Follow-up (training-project-skills)

`training-project-skills` 側で、このマーケットプレイス公開後に削除すべきもの。

- `cognitive-rhythm-writing`
- `html-design-doc`
- `japanese-tech-writing`
- `test-run-discipline`
- `changelog-commit`
- `claude-share/CLAUDE.md`
- `claude-share/skills/*`

いずれも本リポジトリの `docs` / `core-dev` / `templates/CLAUDE.md` に移行済みで重複している。削除は本作業のスコープ外であり、別タスクとする。

## Review

レビュー経路 — Codex（`codex exec -p luna`）はクレジット切れ（"Your workspace is out of credits"）で実行不能のため `ecc:code-reviewer` にフォールバック。結果 CRITICAL 0 / HIGH 1（`changelog-commit` のスラッシュ起動が不可という指摘。スキルは `/plugin:skill 引数` で明示起動できるため却下）/ MEDIUM 4（すべて採用・修正済み）/ LOW 2（相対パス参照は採用、docs の Origin 行は出典情報として保持）。

## Known regressions

移行によって失われた、あるいは注意が必要になった挙動。

### 1. 自動読み込みからトリガー発火へ

`rules/` はパススコープ（編集中のファイルパス）に基づいて自動的に読み込まれていた。スキルは description のトリガー文によって発火する。この差を埋めるため、`java-dev:java-conventions` と `dotnet-dev:dotnet-conventions` の description には対象ファイル種別（`*.java`、`pom.xml`、`build.gradle`、`*.cs`、`*.csproj`、`*.sln` 等）を明記してある。とはいえ、パススコープほど確実ではない。

### 2. スキル名の名前空間化

インストール後、スキル名は `core-dev:test-run-discipline` のように名前空間付きになる。ローカルの参照のうち、`CLAUDE.md` の `/codex-brief-review` は影響を受けない。一方 `orchestration-core` は `test-run-discipline` と `local-vision-analysis` を素の名前で参照している。これらは `~/.claude/skills` のコピーが残っている限り動作するが、オリジナルを削除するとリンクが切れる。

### 3. スキル description 内の相互参照の表記ゆれ

core-dev のスキルは相互参照を名前空間付き（`core-dev:security-check`）で書いているが、java-dev / dotnet-dev は素の名前（"see dotnet-conventions"）、docs も素の名前（"use anydoc"）で書いている。動作上の実害は確認していないが、表記が統一されていない。skills 配下は今回の変更スコープ外のため、記録のみとし修正はしていない。

### 4. `run-tests.sh` の実行権限ビット

Windows では `core.filemode=false`（本リポジトリで確認済み）のため、実行権限ビットが Git に記録されない。`run-tests.sh` は POSIX 環境で `bash` 経由の呼び出しを前提としているが、実行ビットを立てて記録しておくのが安全である。

現在ファイルは未追跡なので、追加と同時に実行ビットを立てる。

```
git add --chmod=+x plugins/core-dev/skills/test-run-discipline/scripts/run-tests.sh
```

既に追跡済みの場合は、`git add` の後に `git update-index --chmod=+x <path>` を実行する（`update-index` はインデックスを操作するコマンドであり、未追跡ファイルには使えない）。
