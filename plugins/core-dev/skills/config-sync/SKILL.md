---
name: config-sync
description: HOME（~/.claude）・training-project-skills・claude-common-plugins・claude-dev-template の4拠点で CLAUDE.md / rules / skills / commands を同期するときに使用。いずれかの拠点でこれらを編集した後、または「同期して」「他のリポジトリにも反映」「config-sync」と言われた時に使用。対応表（references/sync-map.tsv）に載っていないファイルには使用不可 — 系統が別のため同期しない。
---

# config-sync

## 目的

同じ内容を持つべき設定・スキル・コマンドを、HOME・TPS・CCP の3拠点の間で双方向に同期する。CDT だけは一方向で、CCP の `templates/CLAUDE.md` から CDT の `CLAUDE.md` へ同期する（HOME からはコピーしない）。

- HOME: `~/.claude`（git + jj 併置、bookmark `main`）
- TPS: `training-project-skills`（git、`main`）
- CCP: `claude-common-plugins`（git + jj 併置、`main`、プラグインマーケットプレイス）
- CDT: `claude-dev-template`（git + jj 併置、`main`。チーム配布用リポジトリテンプレート。同期対象は CLAUDE.md のみで、CCP の `templates/CLAUDE.md` を同期元とする mirror）

実際のパスは `${CLAUDE_PLUGIN_ROOT}/skills/config-sync/scripts/check-sync.sh` の既定値、または環境変数 `CONFIG_SYNC_HOME` / `CONFIG_SYNC_TPS` / `CONFIG_SYNC_CCP` / `CONFIG_SYNC_CDT` で解決する。

同期対象は2種類に分かれる。

- **mirror**: バイト単位で一致させる。`cp` で上書きしてよい。
- **variant**: 意図的な差分を持つ派生版。同じ意味の変更を手作業で当て、既知の差分は保存する。

## 対応表の場所

`references/sync-map.tsv`（タブ区切り）が唯一の正。列は `home / tps / ccp / class_tps / class_ccp / cdt / class_cdt / notes`。

- パスは各ルートからの相対。`/` で終わる行はディレクトリ（再帰）。
- 対応物がない場合は `-`。
- `notes` 列に variant の既知差分を記載する。
- 末尾の `# exclude:` 行が同期対象外の系統を明示する。

## 手順

1. `bash "${CLAUDE_PLUGIN_ROOT}/skills/config-sync/scripts/check-sync.sh"` を実行し、ペアごとのドリフト状況を得る（読み取り専用のためメインが直接実行してよい）。出力末尾の `git status --short` で各拠点の未コミット変更が見える。
2. 同期方向を決める。未コミット変更がある側、または mtime が新しい側がソース。**両側に未コミット変更がある場合は作業を止めてユーザーに確認する。**
3. mirror クラスのペアは `cp` でソースからターゲットへ上書きする（Haiku に委譲。CDT の CLAUDE.md は CCP の `templates/CLAUDE.md` から `cp` で上書きしてよい mirror で、HOME からはコピーしない。メインは `orchestration-core` スキルの方針どおり指示と受入判定のみ行う）。
4. variant クラスのペアは、同じ意味の変更を当てつつ TSV の `notes` に記載された既知差分を保存する意味編集として Haiku / Sonnet に委譲する。**全文コピーで上書きしない。** CDT の CLAUDE.md は HOME の変種なので、HOME の CLAUDE.md を直接反映せず、CCP の `templates/CLAUDE.md` を更新してから CDT へ `cp` する（手順3）。 `skills/orchestration-core/` の委譲固定句を変更した場合は、CCP の `plugins/*/agents/*.md` の `## Output format` 節にも同等の行を手作業で入れる（HOME に対応物がないため自動同期されない）。
5. `bash "${CLAUDE_PLUGIN_ROOT}/skills/config-sync/scripts/check-sync.sh"` を再実行する。mirror ペアがすべて `IDENTICAL` になっていること。
6. 変更した語句を各ターゲットで `grep` し、実際に反映されていることを確認する。
7. 拠点ごとに `/changelog-commit` を提案する。CCP は触ったプラグインの `plugins/<plugin>/.claude-plugin/plugin.json` の `version` も手作業でバンプする。CDT は jj でコミットする。`docs/CHANGELOG.md` の先頭に `## [X.Y.Z]` 見出しを追加すると GitHub Release が作成されるため、CDT のコミットはユーザーへの提案にとどめ、自動では実行しない。

## 禁止事項

- variant クラスのターゲットへの全文コピー上書き。既知差分が消える。
- `git stash` / `git reset` / `git checkout .` など作業ツリー全体に及ぶ操作。並列委譲中の編集が失われる。
- 対応表にないファイルの同期。系統が別か、拠点固有の設定である。
- 新しくミラーすべきファイルを追加したのに TSV に行を足さないこと。同じ変更の中で TSV も更新する。

## Origin

user skills directory (config-sync)
