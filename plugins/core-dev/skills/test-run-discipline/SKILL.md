---
name: test-run-discipline
description: テストを実行する、またはサブエージェントがテスト結果を報告する際に必ず使用。pytest/go test/gradle test/cargo test 等の実行前、および検証委譲（動作確認）でテストを走らせる前に読む。「テストを実行」「テストを流す」「pytest を走らせる」「go test / gradle test を回す」と言われた時、または委譲された動作確認タスクでテストを実行する時に使用。テストの書き方・TDD の指針には使用不可 — `core-dev:tdd-testing` または言語別のテスト作成スキルを使用すること。
---

# テスト実行ディスシプリン

テスト実行の生ログをそのままエージェントの応答に含めない。Bash ツールの結果は無条件に呼び出し元のコンテキストへ注入されるため、プロンプトの指示だけでは出力量を減らせない。出力は発生源（ラッパースクリプト）で絞る。

## 1. 実行はラッパー経由のみ

テストは直接コマンドを叩かず、必ず `${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh` 経由で実行する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh" pytest -q
bash "${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh" go test ./...
bash "${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh" cargo test
bash "${CLAUDE_PLUGIN_ROOT}/skills/test-run-discipline/scripts/run-tests.sh" ./gradlew test
```

コマンドの終了コードはそのままスクリプトの終了コードとして伝播するため、CI ゲートやスクリプトの分岐条件として引き続き使える。

環境変数:

- `RUN_TESTS_LOG_DIR`: ログの出力先ディレクトリ（既定は `$TMPDIR` または `/tmp`）
- `RUN_TESTS_FAIL_LINES`: 失敗時に表示するログ末尾の行数（既定 100）

## 2. 上位への報告

ラッパーが失敗時に標準出力へ返すのはログ末尾の生 tail（既定100行、下記3節）であり、これは実行したエージェント自身が確認するための中間出力に過ぎない。上位（呼び出し元）への報告はこの tail から抽出した内容のみとし、tail をそのまま転記しない。

- **成功時**: 1行のみ報告する（`PASS | <要約> | log: <path>` の形式）。追加の説明や生ログの貼り付けは不要。
- **失敗時**: 失敗したテスト名・エラーメッセージ・該当箇所（file:line）のみを報告する。生ログ（tail 出力そのもの）を返却に貼り付けることは禁止。ログのパスを添えて、読み手がそれを grep できるようにする。

## 3. 意図的な上限

失敗時の出力はログ末尾 N 行（既定 100）に上限を設けている。これは意図的な設計であり、根本原因の深掘りは「フル出力で再実行する」のではなく、報告されたログパスを `grep` することで行う。
