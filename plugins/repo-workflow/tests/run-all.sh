#!/usr/bin/env bash
# repo-workflow のテストをすべて実行する。1 つでも失敗すれば終了コード 1 で終わる。
# 実行: bash plugins/repo-workflow/tests/run-all.sh（bash 4.2 以降、git、jq が必要）
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failed=()
for t in test-merge-pr.sh test-pickup.sh test-pre-push-guard.sh test-mcp-branch-guard.sh; do
  echo "=== ${t}"
  if bash "${here}/${t}"; then
    echo "=== ${t}: PASS"
  else
    echo "=== ${t}: FAIL"
    failed+=("${t}")
  fi
done
if [ "${#failed[@]}" -gt 0 ]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
echo "all tests passed"
