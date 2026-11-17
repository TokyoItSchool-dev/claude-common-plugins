#!/bin/bash
# PreToolUse hook (matcher: mcp__github__push_files|mcp__github__create_or_update_file|mcp__github__delete_file):
# GitHub MCP のファイルの書き込み(Contents API などでブランチへ直接コミットする)を、main、develop、
# claude/active-work に対して拒否する。main / develop への直接 push を禁じる pre-push-guard.sh と同じ規則を、
# git を通らない書き込みにも当てる。誤操作を防ぐガードであり、セキュリティ境界ではない。
#
# 入力: stdin の JSON。ブランチは tool_input.branch。値の前の refs/heads/ と heads/ を除いて比べる。
# branch がない、または空のときも拒否する(GitHub の Contents API はデフォルトブランチ main に書き込むため)。
# 拒否: exit 0 と {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",...}} の JSON。
# fail-open: jq がない、または入力が空か JSON として読めないときは許可する(exit 0、出力なし)。
# 対象外のツール名のときは何もしない(settings.json の matcher の誤りに備える)。
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "mcp-branch-guard: jq が見つからないため判定をスキップします(fail-open)" >&2
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0
LINE=$(printf '%s' "$INPUT" | jq -r '"\(.tool_name // "")\t\(.tool_input.branch // "")"' 2>/dev/null) || exit 0
# Windows の jq.exe は改行を CRLF で出力するため、CR を取り除く。
LINE=${LINE//$'\r'/}
TOOL=${LINE%%$'\t'*}
BRANCH=${LINE#*$'\t'}

case "$TOOL" in
  mcp__github__push_files|mcp__github__create_or_update_file|mcp__github__delete_file) ;;
  *) exit 0 ;;
esac

REF=${BRANCH#refs/heads/}
REF=${REF#heads/}
case "$REF" in
  ""|main|develop|claude/active-work) ;;
  *) exit 0 ;;
esac

MSG="GitHub MCP の $TOOL による ${REF:-デフォルトブランチ(branch の指定なし)} への書き込みは禁止です。main / develop への直接のコミットは行いません。claude/active-work はロックであり repo-workflow の pickup.sh(plugin_sha から一時ディレクトリに写したもの)だけで操作します。作業ブランチ(claude/<issue-number>-<slug>)に書き込み、develop 宛の PR を作成してください。"
jq -n --arg r "$MSG" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
