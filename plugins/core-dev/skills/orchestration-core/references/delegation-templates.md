# 委譲プロンプト雛形集

サブエージェントへ委譲する際にそのままコピペできるプロンプト雛形を用途別にまとめる。曖昧な依頼は曖昧な結果しか返さないため、必須要素は省略しないこと。

## 言語規律（最優先）

- **委譲プロンプトは全文英語で書く**。サブエージェントからの返却も英語で受け取る（各雛形の Return format に "Reply in English." を含めてある。削らないこと）。
- **人間向け出力は不要**: 各雛形の Return format に「出力はオーケストレーター宛の最終メッセージのみ。進捗・推論・途中経過は出力しない」旨の英文を含めてある。削らないこと。チームメイトの最終メッセージは自動でリードに届く（SendMessage はチームメイト→リードの作業中の連絡用）。
- 理由: 日本語での委譲・返却は幻覚（存在しないファイル名・関数名・仕様の捏造）を誘発しやすいため。
- ユーザーとの会話は日本語。サブエージェントの英語返却は、メインが日本語に要約してユーザーへ報告する。
- タスク固有の記入欄（Task / Deliverables / Constraints 等）も英語で埋める。日本語の固有名詞（ファイル名・資料名等）はそのまま埋め込んでよい。

## 共通固定句

全ての委譲文の冒頭には必ず以下を入れる（チームメイト起動文は例外。雛形7）。

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.
```

理由: 過去に general-purpose エージェントがグローバル方針を継承して Codex CLI へ再委譲し、成果物ゼロで「完了」と誤報告した事故があるため。委譲文には毎回この固定句を明示し、継承ではなく明文で再委譲を止める。

`[PLAIN PROSE]` の理由: Fable 5.1 は文が長く修辞に寄りやすい。Anthropic の Fable 5.1 プロンプトガイド（Writing density）が示す処方をそのまま入れる。

## 並列分解の手順

① メインがタスクを「1機能＝1サブエージェント、1タスク＝1サブエージェント」の独立単位に分解する。
② 各委譲文に担当ファイル一覧（スコープ）と触ってはならないファイルを明記する。
③ 独立タスクは単一メッセージで複数エージェントを同時起動する。
④ 同一ファイルを同時に編集するのは1エージェントのみ（メインがファイルパーティショニングを決定する）。

## 雛形1: 調査・探索

Explore または general-purpose（`model: sonnet` / `haiku` 等を指定）向け。徹底度は探索範囲の広さに応じて選ぶ。単一ファイル・単一シンボルの特定なら `medium`、命名規則が複数あり得る／複数ディレクトリにまたがる横断調査なら `very thorough` を指定する。

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Task: <what to investigate and why, in 1-2 sentences>

Thoroughness: <state either "medium" or "very thorough">

Return format: conclusions, summary, and relevant locations (file:line) only. Do NOT paste raw file contents or exploration logs. Your output is read only by the orchestrating session, never by a human: do not narrate progress, reasoning, or intermediate steps; emit only this final message. Reply in English.
Evidence: back every claim with the file path and line number it comes from. Do not state anything you cannot back with evidence.
```

記入例（Task 欄のみ差し替え）:

```
Task: Identify which routes the authentication middleware is applied to, and list any endpoints where it is missing.
Thoroughness: very thorough
```

## 雛形2: 実装

Agent ツール `subagent_type: claude` + `model: sonnet` または `opus` 向け。

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Deliverables: <files to create/modify and the expected content, concretely>
Constraints: <allowed scope (target directories/files) and forbidden operations (e.g., touching unrelated files, destructive git operations)>
Scope — files you own: <list>
Files you must NOT touch: <list>

Return format: list of changed files + `git diff --stat` output + tests you ran and their results. Do NOT paste full file contents. Your output is read only by the orchestrating session, never by a human: do not narrate progress, reasoning, or intermediate steps; emit only this final message. Reply in English.
```

注意: 担当ファイルの分割はメインが決定し、上記 Scope 欄で明示する。ファイル分担で書き込み先を分離できない場合のみ、Agent 呼び出しに `isolation: "worktree"` を指定する（通常のサブエージェント限定。`name` と混ぜない）。並列委譲が進行中は、メインセッションが `git stash` / `git reset` / `git checkout .` 等、作業ツリー全体に及ぶ操作を行わないこと。進行中の編集が静かに失われる。

記入例（Deliverables・Constraints・Scope 欄のみ差し替え）:

```
Deliverables: Add a GET /users/:id endpoint to src/api/users.ts, and add unit tests to tests/api/users.test.ts.
Constraints: Do not touch the existing src/api/orders.ts. Do not run DB migrations.
Scope — files you own: src/api/users.ts, tests/api/users.test.ts
Files you must NOT touch: src/api/orders.ts
```

## 雛形3: Codex 委譲

`subagent_type: codex:codex-rescue`（モデル未指定時は config.toml の既定 Luna・effort xhigh で実行される）向け。タスク本文も英語で書く。用途は「コードレビュー・計画レビュー・レビュー観点のセカンドオピニオン」「重要成果物のレビュー」（routing.md の Codex ゲート参照）。定型・低難度の作業には使わない。

モデルの使い分け: Web 検索・軽量な調査は Claude（Haiku/Sonnet）+ WebSearch を使う（Codex は使わない）。コードレビュー・計画レビューは常に Luna・effort xhigh（唯一のモデル）。最重要タスクの検証・重要な設計は Codex ではなく Fable（`model: fable`）に委譲する。

前提: Codex のローカルファイル読取可否はプローブで確認する（routing.md の Codex ゲート参照）。ただし確実性を優先する場合は対象コード・資料を委譲文にインライン貼付する。ファイルパスを渡す場合は、返却の [CODEX-AUDIT] と裏取りで実際に読めたことを検証する。

タスク本文の末尾には、以下の Self-Audit ブロックを verbatim（一字一句そのまま）で付加する。

```
---
## Self-Audit (mandatory final section of your reply)

At the end of your reply, output a Markdown table with one row per requested item:

| # | Requested item (verbatim or paraphrased) | Done? (Yes/No/Partial) | What you actually did | Deviation reason (if not Yes) |

When you list "What you actually did", include the file paths you edited (relative to repo root). If you created or deleted files, mark them explicitly as `(created)` or `(deleted)`.

Then, in a "Deviations" subsection, list any work you performed that was NOT explicitly requested, and any requested item you skipped. If there were none, write `Deviations: none.`
```

受領時の判定（`[CODEX-AUDIT]` ヘッダー規約）:

- OK: 全行 Yes かつ `Deviations: none` → 受理検討
- WARN: Partial・No・Deviations あり → 差分確認必須
- NG: Self-Audit 欠落・不成立 → 再委譲

いずれの判定であっても、Self-Audit の記載内容だけを根拠に受理してはならない。WARN・NG はもちろん、OK であっても実ファイルの diff（`git diff --stat` 等）と突き合わせて裏取りしてから受理する。

## 雛形4: レビュー委譲（モデル分離）

原則: 実装とレビューのモデルを分離し、同一モデルに自己レビューさせない。

- Claude 系が実装した場合 → Codex にレビューを委譲する。通常は `/codex-brief-review`（Luna・effort xhigh）、文脈不要の高速チェックのみ `/codex:review` を使う。Codex 不可・リミット時は `core-dev:code-reviewer`（実装と別の Claude モデル）にフォールバックする（リミット回復は待たない）。手動 ChatGPT（Astro Pro、`/codex-brief-review` 手順 4b）はフォールバックではなく、テンポより品質を優先する重要な設計・実装に対しユーザー指示で選択する。

レビュー雛形:

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Target: <the files / diff / PR to review>
Review focus: <security / correctness / maintainability, etc.>

Return format: list findings ordered by severity, 1-3 sentences each, with file:line. If no issues are found, state that explicitly. Your output is read only by the orchestrating session, never by a human: do not narrate progress, reasoning, or intermediate steps; emit only this final message. Reply in English.
```

記入例（Target・Review focus 欄のみ差し替え）:

```
Target: the diff of src/auth/session.ts in PR #142
Review focus: session fixation, token leakage, information disclosure via error messages
```

## 雛形5: 計画立案委譲

`core-dev:planner` / `Plan` / `claude`（`model: opus`、計画規模が大きい場合は `model: fable`）向け。特に重要な計画はドラフト後に雛形3で Codex に**レビュー**を委譲する（計画のドラフト自体は Opus / Fable / core-dev:planner が書く）。メインは計画を書かない: 要件を整理して本雛形で委譲し、返却された計画を採否判断して確定する。

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Task: Draft an implementation plan for the following requirement.
Requirement: <the requirement, constraints, and acceptance criteria, concretely>
Context: <known facts backed by tool results — file paths, existing behavior, prior findings>

Return format: a step-by-step plan with (1) ordered tasks, (2) files to create/modify per task, (3) risks and dependencies, (4) verification steps per task. Cite file:line for every claim about existing code. Do NOT paste raw file contents. Your output is read only by the orchestrating session, never by a human: do not narrate progress, reasoning, or intermediate steps; emit only this final message. Reply in English.
```

## 雛形6: 検証（動作確認）委譲

機械的なテスト実行・ビルド・ログ収集は `claude`（`model: haiku` / `sonnet`）向け。検証（テスト実行・動作確認）は常に Claude 系（Haiku/Sonnet）が実施する。重要成果物は加えて雛形3で Codex にレビューを委譲する。テスト実行は `${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh` 経由で行わせ、返却は成功時1行、失敗時は失敗テスト名・エラー・該当箇所（file:line）・終了コード・ログパスのみとする。

```
[NO RE-DELEGATION] Execute this task directly yourself using your own Read/Write/Edit/Bash tools. Delegating to other agents or external CLIs (e.g., Codex) is prohibited.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Task: Verify the following deliverable by actually running the commands below. Do NOT modify any files.
Deliverable: <what was implemented and by which agent>
Commands: <exact test/build/run commands>

Return format: for each command, report the exact command, its exit code, and a 3-5 line summary of the output tail (include full error messages verbatim on failure). State PASS/FAIL per command and an overall verdict. Do NOT paste full logs. Your output is read only by the orchestrating session, never by a human: do not narrate progress, reasoning, or intermediate steps; emit only this final message. Reply in English.
```

## 雛形7: チームメイト起動

Agent ツールに `name` と `model`（選択は routing.md「チーム or サブエージェント」）を渡して起動する（agent-teams.md）。`name` と `isolation` は併用しない。`[NO RE-DELEGATION]` は入れない（チームメイトは自分の作業単位のオーケストレーターで、サブエージェントへ委譲する）。チームメイトを起動できない環境（ヘッドレス `-p`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 未設定、`name` 付き呼び出しでチームメイトが起動しなかった場合など）ではチームを組まず、雛形2で通常の委譲をする。`[TEAMMATE]` プロンプトは出さない。

```
[TEAMMATE] You are a teammate in an agent team and the orchestrator of the work unit below. Apply the main-session rules (CLAUDE.md "メインセッションの役割" and the orchestration-core skill) to your unit: delegate all real work, including trivial edits, to subagents per the routing rules and delegation templates; yourself do only read-only acceptance checks and reporting. You own the model-separated review of your unit (if Codex is available, Codex via /codex-brief-review or codex:codex-rescue first; otherwise, or on Codex failure, core-dev:code-reviewer), run in the foreground, one Codex review at a time across the team. Differences from the lead: never spawn teammates; never pass `name` to Agent calls and never use Agent `run_in_background` (foreground only); report to the lead.
[PLAIN PROSE] Remove all mannered prose: say what you mean; when a literal phrase is available, use it.

Work unit: <task, in 1-3 sentences>
Deliverables: <files to create/modify and the expected content, concretely>
Scope — files you own: <list>
Files you must NOT touch: <list; ask the lead via SendMessage if you need a change there>

Report: your final message is delivered to the lead automatically. In English: conclusions, summary, file:line, list of changed files, review result, and test results. Do NOT paste full file contents or raw logs. Your output is read only by the lead, never by a human: do not narrate progress or reasoning. Use SendMessage to the lead only for questions during the work.
```

## 禁止事項（ハルシネーション連鎖防止）

- 委譲文を日本語で書かない。英語で書けない固有情報（日本語資料の抜粋等）は引用として埋め込み、指示部分は英語を維持する。
- ツール結果の出所（どのツール結果の何行目に基づくか）を指せない「事実」を委譲文に書かない。書く前に「これはどのツール結果の何行目由来か」を自問し、指せなければそれは生成＝捏造である。
- サブエージェントの「完了」報告を無検証のまま下流の委譲文に注入しない。verification.md に従い裏取りを先に行う。
- 委譲は1エージェント1タスクを守る。曖昧な依頼は曖昧な結果しか返さない。1つの委譲文に複数の独立タスクを詰め込むと、片方だけ実行されて「完了」と誤報告される事故が起きやすい。
- 存在しないエージェント名・スキル名を憶測で書かない。`Explore` / `Plan` / `general-purpose` / `claude`（model 指定併用）/ `codex:codex-rescue` / `core-dev:planner` / `core-dev:code-reviewer` / `core-dev:security-reviewer` など、実在が確認できるものだけを使う。
