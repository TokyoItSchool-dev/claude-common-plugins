---
name: git-workflow
description: コミットメッセージを書く時、プルリクエストを作成・要約する時、「コミットして」「PR を作って」と言われた時、サブエージェントの並列実行中に git 操作を行う時に使用する。CHANGELOG 更新とバージョンバンプを伴うリリース作業には使用不可 — `core-dev:changelog-commit` を使用すること。
---

# Git ワークフロー

## コミットメッセージ形式

```
<type>: <description>

<optional body>
```

Type: `feat` / `fix` / `refactor` / `docs` / `test` / `chore` / `perf` / `ci`

## プルリクエスト

1. 最新コミットだけでなく、全コミット履歴を分析する。
2. `git diff [base-branch]...HEAD` で全変更を確認する。
3. 包括的な PR サマリを作成する。
4. テスト計画（TODO 付き）を含める。
5. 新規ブランチは `-u` フラグでプッシュする。

## 安全規律

- サブエージェントの並列実行中は、`git stash` / `git reset` / `git checkout .` など作業ツリー全体に及ぶ破壊的操作を行わない。進行中の編集が静かに失われる。

## VCS の選択

- リポジトリに `.jj` ディレクトリがある場合は、git ではなく jujutsu（`jj` コマンド）で操作する（コミット、ブランチ、履歴確認、push 等）。
- `.jj` がない場合は従来どおり git を使用する。
