#!/bin/bash
# mcp-branch-guard.sh のテスト。deny は JSON の permissionDecision で判定する。
# すべてのケースで exit 0 を確認し、allow は stdout が空であることも確認する。
set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/scripts/mcp-branch-guard.sh"
BASH_BIN="$(command -v bash)"
PASS=0
FAIL=0

# judge expect rc out label
judge() {
  local expect="$1" rc="$2" out="$3" label="$4" actual
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1; then
    actual=deny
  else
    actual=allow
  fi
  if [ "$rc" != 0 ]; then
    FAIL=$((FAIL + 1)); echo "FAIL [exit $rc, expected 0] $label"
  elif [ "$actual" != "$expect" ]; then
    FAIL=$((FAIL + 1)); echo "FAIL [expected $expect, got $actual] $label"
  elif [ "$expect" = allow ] && [ -n "$out" ]; then
    FAIL=$((FAIL + 1)); echo "FAIL [allow with non-empty stdout] $label"
  else
    PASS=$((PASS + 1)); echo "PASS [$expect] $label"
  fi
}

# run_case expect tool tool_input_json
run_case() {
  local expect="$1" tool="$2" input="$3" out rc
  out=$(jq -n --arg t "$tool" --argjson i "$input" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}' | "$BASH_BIN" "$GUARD")
  rc=$?
  judge "$expect" "$rc" "$out" "$tool $input"
}

# run_raw expect raw-input label [PATH]
run_raw() {
  local expect="$1" raw="$2" label="$3" path="${4:-$PATH}" out rc
  out=$(printf '%s' "$raw" | env PATH="$path" "$BASH_BIN" "$GUARD" 2>/dev/null)
  rc=$?
  judge "$expect" "$rc" "$out" "$label"
}

for tool in mcp__github__push_files mcp__github__create_or_update_file mcp__github__delete_file; do
  for b in main develop refs/heads/main refs/heads/develop heads/develop claude/active-work refs/heads/claude/active-work; do
    run_case deny "$tool" "{\"owner\":\"o\",\"repo\":\"r\",\"branch\":\"$b\",\"path\":\"a\",\"message\":\"m\"}"
  done
  # branch を省くと、GitHub の Contents API はデフォルトブランチ（main）に書き込むため拒否する。
  run_case deny "$tool" '{"owner":"o","repo":"r","path":"a","message":"m"}'
  run_case deny "$tool" '{"owner":"o","repo":"r","branch":"","path":"a","message":"m"}'
  run_case deny "$tool" '{"owner":"o","repo":"r","branch":null,"path":"a","message":"m"}'
  for b in claude/12-fix-x feature/main develop2 main-x Main; do
    run_case allow "$tool" "{\"owner\":\"o\",\"repo\":\"r\",\"branch\":\"$b\",\"path\":\"a\",\"message\":\"m\"}"
  done
done
# Windows の jq.exe は CRLF で出力する（branch の値の末尾の CR を除いて比べる）。
run_raw deny  '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"main\r"}}' 'branch with CR'
# 対象外のツールは見ない。
run_case allow mcp__github__create_branch '{"owner":"o","repo":"r","branch":"main","from_branch":"develop"}'
run_case allow Bash '{"command":"git push origin claude/1-x"}'
# 判定できないときは許可する（fail-open）。
run_raw allow '' 'empty input'
run_raw allow 'not json' 'invalid json'
run_raw allow '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"main"}}' 'jq missing' "/nonexistent"

# プラグインの hooks/hooks.json が、PreToolUse で 2 つのガードを登録していることを確かめる。
# マージ、auto-merge、PR のブランチの更新の GitHub MCP ツールは、consumer の settings.json の permissions.deny で
# 拒否する（プラグインは permissions を持てない。README の「consumer の設定」）。
HOOKS="$(cd "$(dirname "$0")/.." && pwd)/hooks/hooks.json"
# hook_registered <matcher に一致するツール名> <コマンドの末尾>
hook_registered() {
  jq -e --arg tool "$1" --arg cmd "$2" '
    [.hooks.PreToolUse[]? | select(.matcher as $m | $tool | test("^(" + $m + ")$"))
      | .hooks[]? | select(.type == "command" and (.command | endswith($cmd))
        and (.command | startswith("\"${CLAUDE_PLUGIN_ROOT}\"/scripts/")))]
    | length == 1' "$HOOKS" >/dev/null 2>&1
}
for tool in Bash; do
  if hook_registered "$tool" '/scripts/pre-push-guard.sh'; then
    PASS=$((PASS + 1)); echo "PASS [hooks.json] pre-push-guard for $tool"
  else
    FAIL=$((FAIL + 1)); echo "FAIL [hooks.json に $tool の pre-push-guard がない]"
  fi
done
for tool in mcp__github__push_files mcp__github__create_or_update_file mcp__github__delete_file; do
  if hook_registered "$tool" '/scripts/mcp-branch-guard.sh'; then
    PASS=$((PASS + 1)); echo "PASS [hooks.json] mcp-branch-guard for $tool"
  else
    FAIL=$((FAIL + 1)); echo "FAIL [hooks.json に $tool の mcp-branch-guard がない]"
  fi
done
# 対象外のツールに mcp-branch-guard を登録しない。
if ! hook_registered mcp__github__create_branch '/scripts/mcp-branch-guard.sh'; then
  PASS=$((PASS + 1)); echo "PASS [hooks.json] mcp-branch-guard not for create_branch"
else
  FAIL=$((FAIL + 1)); echo "FAIL [hooks.json が create_branch に mcp-branch-guard を登録している]"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
