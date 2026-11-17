---
name: release-prep
description: リリース準備として、リリースブランチの作成、CHANGELOG エントリの追記（バージョンは見出しにのみ存在する）、受入テスト手順書の作成、develop 宛てのリリース PR の作成と develop へのマージ、後続の develop -> main PR 用の Closes 一覧と人間が確認する変更の一覧の作成を行う。「リリース準備をして」「vX.Y.Z のリリース PR を作って」「リリースに含まれる Issue を集めて」と言われた時に使用する。
argument-hint: "<X.Y.Z またはバンプ種別>"
---

# release-prep

リリース PR（`claude/release-vX.Y.Z` -> `develop`）を用意し、`repo-workflow:pr-handoff` の手順で `develop` へマージする。運用ルールの正は、作業するリポジトリの `.claude/rules/repository-workflow.md` の 3.1、第4節と第7節、`CONTRIBUTING.md` の「リリースの流れ」。リポジトリの `.claude/rules/` に追加のゲート（例: 8.1）や、リリースについての追加の規則があれば、それにも従う。

共通スキル（`core-dev`）は名前で参照し、内容をここに複製しない。

- CHANGELOG の記載ルール（機能単位の集約、実装詳細を書かない）だけを `core-dev:changelog-commit` から参照する。そのブランチ作成・バージョン検出・コミット・PR 作成の手順は使わない（ブランチと PR は下の手順で作る）
- 委譲と受入判定: `core-dev:orchestration-core`
- Git 操作: `core-dev:git-workflow`

バージョンは `docs/CHANGELOG.md` の `## [X.Y.Z] - YYYY-MM-DD` 見出しにだけ持つ。`package.json` があっても、その `version` は使わず、更新もしない。`changelog-commit` のバージョン検出（`package.json` の参照）には頼らない。

## 手順

1. **前提の確認**
   - 人間から `X.Y.Z` またはバンプ種別（major / minor / build）を受け取る。バンプ種別だけの場合は、`docs/CHANGELOG.md` の先頭見出しのバージョンから `X.Y.Z` を計算し、人間に確認する。指定がなければ報告して止まる。
   - `git fetch origin` の後、`git rev-parse origin/develop` で `develop` の先頭コミットを取得する。
   - `develop` の先頭のツリーで `bash scripts/run-checks.sh` を実行する。別の作業ツリー（`git worktree add --detach <ディレクトリ> origin/develop`）で実行するか、`git switch --detach origin/develop` の後で実行する。実行の前に `git status --short` が空である（未コミットの変更と未追跡のファイルがない）ことを確認し、空でなければ報告して止まる。`run-checks.sh` の前に、同じ作業ツリーで、`origin/main` の `.claude/repo-workflow.json` の `pre_check_commands` を順に実行する（`repo-workflow:issue-pickup` の 2.0.1）。どれかが失敗したら報告して止まる。終了コード 0 のときだけ `PASS`。失敗なら報告して止まる。
   - 続けて `gh run list --workflow ci.yml --commit <先頭の sha> --json databaseId,status,conclusion,createdAt,url` を読み、実行ごとに `gh run view <id> --json jobs` で OS ごとの結論を読む。その sha に対する実行のうち、ある OS のジョブの結論が `failure` または `timed_out` で、同じ OS についてそれより後に成功した実行がないものがあれば、手動実行が失敗しているとして報告して止まる。実行がなければ `NOT_CONFIGURED` と記録する。判定できないとき（実行中、結論を読めない、どの OS のジョブか分からないなど）は、報告して止まる。
2. **リリースブランチ**: 同名のブランチが既にないことを `git ls-remote --heads origin claude/release-vX.Y.Z` で確認し、同じバージョンの Open の PR がないことを `gh pr list --state open --json number,headRefName` で確認する。どちらかがあれば、作らずに報告して止まる。なければ `git switch -c claude/release-vX.Y.Z origin/develop` で作る。
3. **CHANGELOG エントリ**: `docs/CHANGELOG.md` のアンカー行（`<!-- 新しいエントリはこの行の直下に追加 -->`）の直下に、`## [X.Y.Z] - YYYY-MM-DD` の見出しで直接追記する。既存エントリの書式（`### 追加` / `### 変更` / `### 修正`）に従い、`core-dev:changelog-commit` の記載ルールに沿って機能単位で簡潔に書く。内容は、前回のリリース以降に `develop` へマージされた PR（下の Closes 一覧の手順 1〜2 で集めたもの）から作る。`package.json` やその他のバージョンファイルは作らない。
4. **受入テスト手順書**: `docs/acceptance/vX.Y.Z.md` を `docs/acceptance/README.md` の書式で作る。`X.Y.Z` は CHANGELOG に追記した見出しのバージョンと一致させる。このリリースに含まれる Issue の AC ごとに、手順・期待結果・判定欄（未実施）を持つブロックを置く。実施は人間がテスト環境で行う。Claude は実施しない。
5. **コミットと push**: CHANGELOG と受入テスト手順書を意味のある単位でコミットし（メッセージは `<type>: <description>`）、`git push -u origin claude/release-vX.Y.Z` で push する。
6. **リリース PR**: 手順書をコミットした後に、`gh pr create --draft --base develop` で PR を作る。PR 本文の「受入テスト手順書」節に `docs/acceptance/vX.Y.Z.md` へのリンクを書く。CI 状態の書き方は `repo-workflow:pr-handoff` と同じ。PR 本文で Windows / macOS での確認を「必要」とし、`develop` -> `main` の前に手動実行するよう依頼する。
7. **`develop` へのマージ**: `repo-workflow:pr-handoff` の手順（`repository-workflow.md` 3.1）でリリース PR を `develop` へマージする。条件を満たさなければマージせずに止まる。受入テストは、`develop` -> `main` の前に人間が実施する。Claude は受入テストを実施しない。

## Closes 一覧と人間が確認する変更の一覧（後続の `develop` -> `main` PR 用）

GitHub は `Closes` を `main` に届いたときだけ働かせるため、`develop` -> `main` の PR 本文に全 Issue を列挙する必要がある。その一覧を作る。あわせて、人間が `main` へのマージの前に確認する変更の一覧を作る（`repository-workflow.md` 第4節）。

1. 直近の `main` へのマージ日時を求める。`gh pr list --base main --state merged --json number,mergedAt --limit 20` の結果から `mergedAt` が最大のものを取る。結果が空（初回リリース）の場合は日時を使わず、`git log origin/main..origin/develop` の範囲を対象とする。
2. その日時より後に `develop` へマージされた PR を集める。`gh pr list --base develop --state merged --search "merged:>=<日時>" --json number,title,body,headRefName,mergedAt,closingIssuesReferences --limit 200`。`merged:>=` は境界を含むため、`mergedAt` で再確認し、`main` へのマージ日時以前のものは除く。
3. Issue 番号は主に、各 PR 本文の `Closes` / `Fixes` / `Resolves` `#N` の行と、`headRefName` の `claude/<n>-` から集める。`closingIssuesReferences` は補助とする（デフォルトブランチ以外が base の PR では通常空になる）。重複を除き、リリース PR 自身は対象に含めない。
4. 次の形式で出力する。PR 本文に貼れる形にし、Issue 番号ごとに由来の PR 番号を併記する。

```
Closes #12
Closes #15
```

5. Issue 番号を持たない PR があれば、一覧とは別に「Issue 未紐付けの PR」として報告する。推測で Issue 番号を補わない。
6. 「main へのマージ前に人間が確認する変更」の一覧を作る。手順 2 の PR ごとに、本文の同名の節を読み、`gh pr view <n> --json files` のファイル一覧と突き合わせる。`.github/`、`.claude/`、`CLAUDE.md`、認証・認可、決済、DB マイグレーション、依存の定義ファイル、検査とレビューの定義（`scripts/*.sh`（`scripts/run-checks.sh` を含む）、テスト（`**/tests/**`）、`REVIEW.md`）に当たるファイルを、PR 番号ごとに次の形式で出力する。本文の節にない、または食い違うファイルは、そのことを併記する。どの PR にもなければ「なし」と書く。

```
#21: .claude/rules/repository-workflow.md, CLAUDE.md
#24: .github/workflows/ci.yml（PR 本文の節に記載なし）
```

7. 一覧はリリース PR の本文（人間が `develop` -> `main` の PR を作るときに使う）または報告に添える。リリース PR の作成後に `develop` へマージされた PR は一覧に入らないため、人間が `develop` -> `main` の PR を作る時点で、手順 1〜6 をやり直して一覧を再生成する。`develop` -> `main` の PR は、人間が作成してマージする。

## してはいけないこと

- `main` への push
- `develop` への push（リリースブランチからの PR 経由でのみ入れる）
- `develop` -> `main` の PR のマージ（人間が行う）
- `repo-workflow:pr-handoff`（`repository-workflow.md` 3.1）を通さないリリース PR のマージ
- タグの作成と GitHub Release の作成（`main` へのマージ後に人間が行う）
