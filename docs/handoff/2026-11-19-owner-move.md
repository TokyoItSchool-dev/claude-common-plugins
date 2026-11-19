# 引き継ぎ: claude-common-plugins の移動と、所有者の名前の修正（2026-11-19）

次のセッションが続きを行うための記録。作業が終わったら、このファイルとブランチ `claude/magical-bardeen-b4twq5` は消してよい（`main` へはマージしない）。

## 1. 経緯

- 2026-11-19、所有者が `TokyoItSchool-dev/claude-common-plugins` を `systemshared-ai-advance/claude-common-plugins` へ移動した（公開のまま。履歴と Issue / PR の番号は変わらない）。
- 以前の URL は GitHub が転送している。以前の所有者の下に同じ名前のリポジトリを作ると転送が止まり、5 つのリポジトリの `develop` へのマージの手順（`merge-pr.sh` の取得）とプラグインの読み込みが止まる。作らないこと。
- 所有者の決定: 5 つのリポジトリ（`claude-dev-template`、`claude-dev-template-gas`、`claude-dev-template-test`、`claude-portfolio-dashboard`、`kintone-ai-dev-template`）と claude-common-plugins の所有者の名前を、文書と設定のすべてで `systemshared-ai-advance` に直す。5 つのリポジトリ自身の名前の修正は終わっている（2 章）。残りは `claude-common-plugins` の名前だけである。
- 前のセッションは、以前の所有者の名前でこのリポジトリを付けていたため、新しい名前のリポジトリを同じセッションに足せなかった。次のセッションは、6 つのリポジトリを新しい名前で付けて始める。

## 2. 各リポジトリの状態（2026-11-19 の終了時点）

所有者はすべて `systemshared-ai-advance`。

| リポジトリ | `main` | `develop` | `develop` にあって `main` にないもの |
|---|---|---|---|
| claude-common-plugins | f6e7d5e | なし（`main` だけ） | Draft PR #17（3 章） |
| claude-dev-template | 4146b37 | 8592693 | 内容の差はない（マージコミットだけ） |
| claude-dev-template-gas | 005c6b3 | 689fdad | PR #22（所有者の名前）、#23（PR #24 テストの修正の取り込み） |
| claude-dev-template-test | f6656ba | 5a84c70 | PR #40（所有者の名前）、#41（PR #42 テストの修正の取り込み） |
| claude-portfolio-dashboard | 8fce935 | dd3c96b | #150（PR #151 所有者の名前とテストの修正の取り込み）、#149（PR #152 Windows / macOS の CI を外す） |
| kintone-ai-dev-template | e6089ee | f5ab0aa | #46（PR #47 `security.yml` のコメント。所有者がマージ）、#48（PR #49 文書の刷新）、#50（PR #51 所有者の名前とテストの修正の取り込み） |

- 4 つの派生リポジトリの `.claude/template-sync.json` の `upstream.commit` は、`develop` で 4146b37 である。
- `develop` -> `main` の PR は、どのリポジトリでも作っていない。4 章の名前の修正を `develop` に入れた後に、リポジトリごとに 1 つ作る（何度も人間のマージを頼まないため）。
- 作業ブランチは、どのリポジトリでも `claude/magical-bardeen-b4twq5` を使った（前のセッションに割り当てられた名前）。次のセッションは、自分に割り当てられたブランチを使う。

## 3. claude-common-plugins の中の修正（進行中）

- Issue #16、Draft PR #17（`claude/fix-owner-name-16` -> `main`、先頭 ab940d6）。別のクラウドセッションが作った。
- 内容: `TokyoItSchool-dev` の 14 か所を `systemshared-ai-advance` に置き換えた（`README.md` 8、`templates/CLAUDE.md` 1、`plugins/repo-workflow/skills/issue-launch/SKILL.md` 1、`plugins/repo-workflow/skills/issue-pickup/SKILL.md` 3、`plugins/repo-workflow/scripts/pickup.sh` のコメント 1）。`plugins/repo-workflow/.claude-plugin/plugin.json` の版を 0.1.1 から 0.1.2 に上げた（README の決まり）。`docs/CHANGELOG.md` は変えていない（リリースの手順で書く）。
- 検査: `bash plugins/repo-workflow/tests/run-all.sh` が成功。独立レビューは APPROVE。
- **人間の作業**: PR #17 を Ready にして `main` へマージする。マージコミットの sha が、4 章の新しい `plugin_sha` になる。

## 4. 残りの作業（順序を守る）

1. **PR #17 が `main` に入るのを待つ。** 新しい `plugin_sha` = claude-common-plugins の `main` の先頭の sha。
2. **テンプレート（claude-dev-template）。** Issue を作り（1.1 の条件で `ai:ready`）、次を 1 つの PR で行う。
   - `.claude/repo-workflow.json` の `plugin_sha` と、`.claude/settings.json` の `extraKnownMarketplaces.mori-claude-tools.source.ref` を新しい sha にし、同じ `source.repo` を `systemshared-ai-advance/claude-common-plugins` にする。
   - `git grep -n 'TokyoItSchool-dev'` の残りを直す。`CLAUDE.md` の上半分（19 行目のマーケットプレイスのコマンド）は、claude-common-plugins の `templates/CLAUDE.md` と同じ内容にする。`scripts/tests/test-validate-repo.sh` の置き換えの式（`TokyoItSchool-dev\/claude-common-plugins` を含む 1 行）も直す。`*.sh` を変えるので Windows の CI を起動する（規則 3.2 (a)）。
   - ガードのフックの写し（`.claude/hooks/pre-push-guard.sh`、`mcp-branch-guard.sh`）が新しい `plugin_sha` の版のスクリプトと同じであることを確かめる（PR #17 はフックを変えていないので、差はない見込み）。
   - Issue #104（`docs/template/requirements.html` の 758 行と CON-01）も進める。移動により「両リポジトリとも同じ org」は再び事実になった。直すのは org の名前と、プランの根拠である（`systemshared-ai-advance` は当面 Free プラン。根拠は所有者の 2026-11-19 の回答。以前の確認の記録は残す）。`docs/template/open-issues.html` の 1211 行も同じ PR で見る。
   - `develop` へマージ -> `develop` -> `main` の PR -> 人間がマージ。規則は `main` の版が効くため、派生リポジトリの取り込みは、テンプレートの `main` に入った後に行う。
3. **派生リポジトリ 4 つ。** スキル `template-sync` で取り込む（3〜4 並列まで）。
   - gas、test、ダッシュボード: Claude が `develop` へマージする。gas と test は `*.sh` を変えるので Windows の CI を起動する。ダッシュボードは起動しない（5 章）。
   - kintone: `.claude/settings.json` と `.claude/repo-workflow.json` は `gated_paths` に当たる。Draft PR と `gate:needs-human` までで止め、`develop` へのマージは人間が行う。
   - `merge-pr.sh` は、`origin` の `main` の `plugin_sha` から取得する。取得先の URL は、その版の手順書（`repo-workflow:issue-pickup` の 2.0）に書かれたものを使う。古い `plugin_sha` の間は以前の URL（転送される）、新しい `plugin_sha` が `main` に入った後は新しい URL になる。
4. **`develop` -> `main` の PR をリポジトリごとに 1 つ作る。** `Closes` の一覧、「main へのマージ前に人間が確認する変更」、文書の見直し（規則 9.2）を書く。kintone では `security.yml` を `develop` の先頭に対して起動し、結果を本文に書く（規則 4 章の (3)）。マージは人間が行う。

## 5. 所有者が決めたこと（前のセッションの会話）

- `develop` までの Issue の作成、PR、マージは、特別な理由（同じ誤りや修正を 3 回以上、設計と現状の大きな乖離）がない限り Claude が行う。順序はテンプレートが先、派生は後。並列は 3〜4 まで。
- CI は基本的に Windows だけ。`develop` 以下では、必要なときだけ Claude が起動する。
- kintone の `security.yml` は、`ci.yml` と同じ扱いで Claude が起動してよい（kintone の ADR 0007。`main` に入っている）。
- ダッシュボードは Cloudflare にデプロイするものなので、Windows / macOS の CI は不要（ダッシュボードの Issue #149、`docs/operations/decisions.md` の P-01。`develop` にある）。`main` に届くまでは `main` の版の規則が効くが、この決定があるので、ダッシュボードでは `ci.yml` を起動していない。この変更を運ぶ `develop` -> `main` の PR では、自動実行は始まらない見込みである（未確認）。その PR は、条件 (1)（ローカル検査）で人間がマージを決める。
- `systemshared-ai-advance` は当面 Free プラン。
- 文書の刷新は、ダッシュボード（`main`）、gas（`main`）、kintone（`develop`）で終わっている。test は対象外（`pending` のまま）。

## 6. 開いている Issue と、後の Issue の候補

- claude-common-plugins #14（スキルに残る「`ci.yml` は人間が手動で実行する」などの記述を直す）、#15（フックのテストが終了コード 141 でまれに失敗する。`plugins/repo-workflow/tests/test-mcp-branch-guard.sh:41`、`test-pre-push-guard.sh:71`）。どちらも `ai:ready` なし。
- claude-dev-template #104（4 章の 2）。
- kintone: Issue #46 に `gate:needs-human` が付いたままである（PR #47 は所有者がマージ済み。`main` に届くと閉じる）。Dependabot の PR #30〜#35 が `develop` 宛てに開いている（未着手。依存の変更は人間ゲート）。
- Issue にしていない候補:
  - ダッシュボードの PR #152 のレビューの LOW 5 件（PR 本文に記録）。P-01 に M5（`ci_state` が `PASS` であること）への影響と移行の説明を足す、P-01 の見直しの条件に dispatcher（Windows で動かすコード）を足す、`dashboard-contract.md` の 6.3 を「テンプレートに従う監視対象のリポジトリ」の説明に書き直す。
  - `scripts/validate-repo.sh` の YAML の検査は、重複したキーを見つけない（ダッシュボードの `ci.yml` で 1 度起きた）。
  - kintone の PR #51 の作業で見つかった不安定さ: `scripts/validate-repo.sh` の 469 行付近（`echo "$fm" | grep -qE ...` と `pipefail`）が、まれに「frontmatter に name がない」で失敗する（原因は未確認。SIGPIPE の可能性）。テンプレートの側で直す候補。
  - kintone の規則 8.1 の見出しが、`security.yml` を「kintone の資格情報を使うワークフロー」に入れている（`security.yml` は資格情報を使わない）。
  - kintone の `tasks/todo.md` の 83 行（完了した項目に以前の所有者の名前のコマンドが残る）。

## 7. 作業の進め方の覚え書き

- リポジトリごとの流れ: Issue（AC つき、`ai:ready`）-> 実装のサブエージェント -> Draft PR -> 別のサブエージェントの独立レビュー（`VERDICT: APPROVE head=<H> develop=<D>`）-> 必要なら Windows の CI -> 証跡を PR 本文に書く -> Ready -> `merge-pr.sh check` と `merge` -> Issue にコメント。
- クラウドのセッションでは `gh` は REST（`gh api`）だけが使える。共同作業者の一覧は GitHub MCP の `list_repository_collaborators` で読む。
- フックのテストの「jq がない」のケースは、まれに終了コード 141 で失敗する（#15）。1 回やり直す。
- kintone では、kintone へ書き込まず、資格情報を使う `kt` のコマンドを実行せず、`.env`、鍵のファイル、`config/environments/production.json` を読まない。起動してよいワークフローは `ci.yml` と `security.yml` だけである。
