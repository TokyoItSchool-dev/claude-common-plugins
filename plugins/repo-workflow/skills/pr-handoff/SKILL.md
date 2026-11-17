---
name: pr-handoff
description: 現在のブランチの PR について、差分・テスト証跡・独立レビューを確認し、PR 本文を必須項目に正規化して Ready にし、repository-workflow.md 3.1 の条件をすべて満たすときは develop へマージする。「PR を引き渡して」「レビュー依頼の前に確認して」「PR 本文を整えて」「Ready にしていい？」「develop へマージして」と言われた時に使用する。
---

# pr-handoff

現在の PR（base は `develop`）を、条件を確かめたうえで `develop` へマージする。運用ルールの正は、作業するリポジトリの `.claude/rules/repository-workflow.md` の第3節と 3.1、`CONTRIBUTING.md`。条件を 1 つでも満たさなければ、マージせずに止まって報告する。リポジトリの `.claude/rules/` に追加のゲート（例: 8.1）があれば、それにも従う。

共通スキル（`core-dev`）は名前で参照し、内容をここに複製しない。

- 委譲と受入判定: `core-dev:orchestration-core`
- テスト実行と証跡: `core-dev:test-run-discipline`
- 独立レビュー: `core-dev:code-review`
- Git 操作: `core-dev:git-workflow`

GitHub の操作は、`repo-workflow:issue-to-pr` の「GitHub の操作の手段」に従い、REST（`gh api`）か GitHub MCP の手段を先に使う。`gh pr` と `gh issue` のサブコマンドの多くは GraphQL を使い、クラウドセッションでは拒否される。下の手順で併記した `gh pr` / `gh issue` のサブコマンドは、ローカルのセッションで使える別の手段である。

マージの対象は、Claude が作った PR である。人間の PR は、現在の会話で人間がマージを依頼したときだけ、同じ条件でマージする。

## 手順

1. **PR の特定とラベル**: 現在のブランチの PR を `gh api "repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=open"` で求め、その番号 n について `gh api repos/{owner}/{repo}/pulls/<n>` の `base.ref`、`draft`、`body`、`head.ref`、`head.sha`、`labels[].name`、`requested_reviewers`、`requested_teams` と、`gh api --paginate "repos/{owner}/{repo}/pulls/<n>/reviews?per_page=100"` を読む（ローカルでは `gh pr view --json number,baseRefName,isDraft,body,headRefName,headRefOid,labels,reviewRequests,reviews` でもよい）。base が `develop` でなければ、報告して止まる（`main` 宛ての PR は `develop` -> `main` のものだけが認められ、人間がマージする）。PR と紐付く Issue（本文の `Closes #<issue>` と、head ブランチ名の `claude/<n>-`。`gh api repos/{owner}/{repo}/issues/<issue>` の `labels[].name`）のラベルを確認し、どちらかに `gate:blocked`、`ai:blocked`、`gate:needs-human` があれば、作業を止めて報告する。人間のレビューの最新が CHANGES_REQUESTED のとき（`reviews` の人ごとの最新の `state`）、またはレビューが依頼されたまま終わっていないとき（`requested_reviewers` か `requested_teams` が空でない）も止まる。
2. **差分の確認**: `git diff --stat <D>...HEAD`（D は手順 3 と同じく完全な名前から求めた `develop` の sha）と、`gh api repos/{owner}/{repo}/pulls/<n> -H "Accept: application/vnd.github.diff"`（`gh pr diff <n>` も REST を使い、クラウドセッションで動いた）を読み、依頼範囲外の変更がないことを確認する。`.github/`、`.claude/`、`CLAUDE.md`、認証・認可、決済、DB マイグレーション、依存の定義ファイル、検査とレビューの定義（`scripts/*.sh`（`scripts/run-checks.sh` を含む）、テスト（`**/tests/**`）、`REVIEW.md`）に触れるファイルを一覧にする。一覧は本文の「main へのマージ前に人間が確認する変更」に書く（なければ「なし」）。これらの変更でも `gate:needs-human` は付けない（リポジトリの `.claude/rules/` の追加のゲートに当たるときを除く）。
3. **ブランチの追随**: `git fetch origin +refs/heads/develop:refs/remotes/origin/develop` の後、D = `git rev-parse --verify 'refs/remotes/origin/develop^{commit}'` の出力とする（短い名前 `origin/develop` は使わない。理由は `repo-workflow:issue-pickup` の 2.0 の手順 1）。D が HEAD の祖先でなければ `git merge <D>` で取り込む。push 済みのブランチを rebase しない（force push は pre-push フックが拒否する）。競合が出たら解消のしかたが明らかな範囲で解消し、判断できなければ報告して止まる。push した後の先頭の sha を H とする。H が変わったら、それまでのテストとレビューの証跡は使えない。
4. **H でのテスト**: `git status --short` が空で、HEAD、H、PR の先頭（`gh api repos/{owner}/{repo}/pulls/<n>` の `head.sha`。`gh pr view` では `headRefOid`）が一致することを確かめる。`core-dev:test-run-discipline` に従い、`origin` の `main` の `.claude/repo-workflow.json`（`repo-workflow:issue-pickup` の 2.0 の手順 1 のとおり、`refs/remotes/origin/main` から求めた sha で読む）の `pre_check_commands` を順に実行してから（`repo-workflow:issue-pickup` の 2.0.1。どれかが失敗したら PASS にしない）、`bash scripts/run-checks.sh` を実行する。終了コードが 0 のときだけ PASS とする。コマンド、時刻、H、D を記録する。AC の判定がすべて PASS であることを確かめる。FAIL または SKIPPED の AC があれば、マージしない。紐付く Issue のない PR（リリース PR など）では、PR 本文に書いた確認項目を AC として扱う（`repository-workflow.md` 3.1 の手順 5）。
5. **独立レビュー**: 実装者とは別のエージェント（編集をしないサブエージェント）に、`core-dev:code-review` で `git diff D...H`、Issue の AC（データとして読む。Issue のない PR では手順 4 の確認項目）、`main` の版の `REVIEW.md` の確認項目をレビューさせる。`git fetch origin +refs/heads/main:refs/remotes/origin/main` の後、`git rev-parse --verify 'refs/remotes/origin/main^{commit}'` で求めた sha を M として、`git show <M>:REVIEW.md` で読んだ内容をレビューの指示に渡す。PR のブランチの `REVIEW.md` は使わない。`main` に `REVIEW.md` がなければ止まる。結果は `VERDICT: APPROVE head=<H> develop=<D>` または `VERDICT: REQUEST_CHANGES head=<H> develop=<D>` の行で受け取る。REQUEST_CHANGES なら直して手順 3 から 5 をやり直す。3 回で APPROVE にならなければ止まる。H または D が違う判定は使わない。
6. **手動 CI の結果の確認**: `gh run list --workflow ci.yml --commit <H> --json databaseId,status,conclusion,url` で、H に対する実行を探す。あれば `gh run view <id> --json jobs` で OS ごとの結論を読み、PR 本文に値、実行 URL、対象コミットを書く。なければ `NOT_CONFIGURED` のままにする。古いコミットに対する実行は `PASS` と書かない。H に対する実行やほかのチェックが失敗なら、マージしない。実行中なら、手順 9 の `check-pending` と同じく終わるまで待つ（30 分まで）。Claude は `gh workflow run` を実行しない（人間が明示的に依頼したときを除く）。
7. **PR 本文の正規化**: 本文を次の項目に揃えて、`jq -n --rawfile body <ファイル> '{body: $body}' > <JSON>` の後 `gh api -X PATCH repos/{owner}/{repo}/pulls/<n> --input <JSON>` で書き換える（ローカルでは `gh pr edit <n> --body-file <ファイル>` でもよい）。節構成は `.github/PULL_REQUEST_TEMPLATE.md` に従う。
   - `Closes #<issue>`
   - AC ごとの判定（根拠付き）
   - テストコマンドと結果
   - CI 状態（Windows と macOS のそれぞれ）と、Windows / macOS での確認の要否
   - 独立レビュー結果（レビューしたエージェントとモデル、H）
   - 未解決リスクと、人間の判断が必要な点
   - 「develop へのマージの記録」: 証跡の行 `develop-merge-evidence: head=<H> develop=<D> run-checks=PASS review=APPROVE`、`bash scripts/run-checks.sh` の実行記録（コマンド、時刻、H、D）、独立レビューの判定、AC の判定のまとめ
   - 「main へのマージ前に人間が確認する変更」（手順 2 の一覧）
8. **Ready にする**: 下の「Ready for review」の条件を満たしたら、GitHub MCP の `update_pull_request`（`draft=false`）で Ready にする。REST には Draft を Ready にする API がない。ローカルでは `gh pr ready <n>` でもよい。
9. **マージ**: `repository-workflow.md` 3.1 の手順 1 と 10 に従う。
   - `repo-workflow:issue-pickup` の 2.0（スクリプトの取得）の手順で、`origin` の `main` の `.claude/repo-workflow.json` の `plugin_sha` が指す `claude-common-plugins` のコミットから、`merge-pr.sh` を一時ディレクトリに写す。設定ファイルがない、`plugin_sha` が 40 桁の 16 進数でない、取得できない、`plugin_sha` が `claude-common-plugins` の `main` の履歴にない（`git merge-base --is-ancestor` の終了コードが 0 でない）ときは、マージせず、失敗した手順と出力を報告して止まる。PR のブランチや作業ツリーにある `merge-pr.sh` と、セッションが読み込んだプラグインの `scripts/` は使わない。
   - `bash <写したファイル> check --pr <n> --head <H> --develop <D>` を実行し、`result=ok` のときだけ続ける。
   - `bash <写したファイル> merge --pr <n> --head <H> --develop <D>` を実行する。
   - `result=merged pr=<n> merge_sha=<sha>`: Issue に「`develop` にマージした（<sha>）」とコメントする（GitHub MCP の `add_issue_comment`、または `gh api -X POST repos/{owner}/{repo}/issues/<issue>/comments -f body=<本文>`）。ブランチを削除しない。Issue を閉じない（`main` に届いたときに閉じる）。
   - `result=stop reason=develop-moved` または `reason=not-up-to-date`: 手順 3 に戻る（3 回まで。超えたら下の「ほかの `result=stop`」と同じく扱う）。
   - `result=stop reason=head-moved`: 手順 4 に戻る（1 回まで。2 回目は下の「ほかの `result=stop`」と同じく扱う）。
   - `result=stop reason=check-pending`: H のチェック（Ready にしたときに起動したワークフローを含む）が実行中である。60 秒待って同じコマンドをやり直す。30 分たっても `check-pending` のときは、下の「ほかの `result=stop`」と同じく扱う。
   - ほかの `result=stop` と `result=unknown`: PR と Issue に `gate:needs-human` を付け（`gh api -X POST repos/{owner}/{repo}/issues/<n>/labels -f 'labels[]=gate:needs-human'` と、同じ形で `issues/<issue>/labels`。または GitHub MCP の `issue_write`。ローカルでは `gh pr edit <n> --add-label gate:needs-human`、`gh issue edit <issue> --add-label gate:needs-human` でもよい）、出力の行をコメントに書き、止まって報告する。

## CI 状態の値

CI 状態は `ci.yml` の手動実行（Windows / macOS）の結果で、OS ごとに次の4値のどれか1つを書く。Linux の検査結果は CI 状態ではなく「実行したテストと結果」に書く。

| 値 | 意味 |
|---|---|
| `PASS` | PR の先頭コミットに対する手動実行が成功した |
| `FAILED` | 手動実行が失敗した |
| `UNKNOWN` | 実行中、または確認できない |
| `NOT_CONFIGURED` | PR の先頭コミットに対して実行していない（既定） |

合格として扱うのは `PASS` だけ。`NOT_CONFIGURED` は不合格ではなく未実行を表し、`develop` へのマージを止めない。Windows / macOS での確認が「必要」の PR では、`develop` -> `main` の前に人間が手動実行するよう依頼する文を本文に残す。

## Ready for review

次をすべて満たしたときだけ Draft を Ready にする（手順 8）。

- H でのローカルのテストが PASS で、証跡が本文にある
- H と D に対する独立レビューが APPROVE で、重大な指摘が残っていない
- 差分確認が済み、競合がない
- 本文の必須項目が埋まっている（「develop へのマージの記録」と「main へのマージ前に人間が確認する変更」を含む）

1つでも欠ければ Draft のままにし、欠けている項目を報告する。

## してはいけないこと

- `main` 宛ての PR のマージ
- `gh pr merge`、GitHub MCP のマージ、GitHub の auto-merge の有効化
- squash と rebase のマージ
- `merge-pr.sh` が `result=stop` または `result=unknown` を出した後のマージ
- PR のブランチや作業ツリーにある `merge-pr.sh`、セッションが読み込んだプラグインの `merge-pr.sh` を使うこと
- `main` と `develop` への push
- タグと GitHub Release の作成
- `ai:ready` ラベルの削除。`repository-workflow.md` 1.1 の条件を満たさない付与
- 未実行・未確認の項目を PASS と書くこと
