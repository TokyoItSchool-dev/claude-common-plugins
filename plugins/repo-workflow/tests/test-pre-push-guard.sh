#!/bin/bash
# pre-push-guard.sh のテスト。deny は JSON の permissionDecision で判定する。
# すべてのケースで exit 0 を確認し、allow は stdout が空であることも確認する。
# 1 ケースの失敗で中断せず、最後に集計する。
set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/scripts/pre-push-guard.sh"
BASH_BIN="$(command -v bash)"
PASS=0
FAIL=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkrepo() {
  local dir="$1" branch="$2"
  git init -q "$dir" >/dev/null 2>&1
  git -C "$dir" checkout -q -b "$branch" >/dev/null 2>&1
  git -C "$dir" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false \
    commit --allow-empty -q -m init >/dev/null 2>&1
}
REPO_DEV="$TMP/dev";   mkrepo "$REPO_DEV" develop
REPO_MAIN="$TMP/main"; mkrepo "$REPO_MAIN" main
REPO_FEAT="$TMP/feat"; mkrepo "$REPO_FEAT" claude/x
REPO_LOCK="$TMP/lock"; mkrepo "$REPO_LOCK" claude/active-work
REPO_W45="$TMP/w45";   mkrepo "$REPO_W45" claude/45-x

record() {
  local ok="$1" label="$2"
  if [ "$ok" = 1 ]; then
    PASS=$((PASS + 1)); echo "PASS $label"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $label"
  fi
}

# judge expect rc out label
judge() {
  local expect="$1" rc="$2" out="$3" label="$4" actual
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1; then
    actual=deny
  else
    actual=allow
  fi
  if [ "$rc" != 0 ]; then
    record 0 "[exit $rc, expected 0] $label"
  elif [ "$actual" != "$expect" ]; then
    record 0 "[expected $expect, got $actual] $label"
  elif [ "$expect" = allow ] && [ -n "$out" ]; then
    record 0 "[allow with non-empty stdout] $label"
  else
    record 1 "[$expect] $label"
  fi
}

# run_case expect cmd [cwd] [run-from-dir]
run_case() {
  local expect="$1" cmd="$2" cwd="${3:-}" from="${4:-.}" out rc
  if [ -n "$cwd" ]; then
    out=$(MSYS2_ARG_CONV_EXCL="*" jq -n --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | (cd "$from" && "$BASH_BIN" "$GUARD"))
  else
    out=$(MSYS2_ARG_CONV_EXCL="*" jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | (cd "$from" && "$BASH_BIN" "$GUARD"))
  fi
  rc=$?
  judge "$expect" "$rc" "$out" "$cmd${cwd:+  (cwd=$cwd)}"
}

# run_raw expect raw-input label [PATH]
run_raw() {
  local expect="$1" raw="$2" label="$3" path="${4:-$PATH}" out rc
  out=$(printf '%s' "$raw" | env PATH="$path" "$BASH_BIN" "$GUARD" 2>/dev/null)
  rc=$?
  judge "$expect" "$rc" "$out" "$label"
}

# --- 既存ケース ---
run_case deny  'git push origin main'
run_case deny  'git push origin develop'
run_case deny  'git push origin HEAD:develop'
run_case deny  'git push origin HEAD:main'
run_case deny  'git push origin x:refs/heads/main'
run_case deny  'git push origin refs/heads/develop'
run_case deny  'git push origin --delete main'
run_case deny  'git push origin :develop'
run_case deny  'git push --force origin claude/1-x'
run_case deny  'git push -f origin claude/1-x'
run_case deny  'git push --force-with-lease origin claude/1-x'
run_case deny  'git push --force-if-includes origin claude/1-x'
run_case deny  'git push origin +claude/1-x'
run_case deny  'git status && git push origin main'
run_case deny  'git fetch; git push origin develop'
run_case deny  'echo a | git push origin main'
run_case deny  'jj git push -b main'
run_case deny  'jj git push --bookmark develop'
run_case deny  'jj git push --all'
run_case deny  'jj git push --allow-new -b main'
run_case deny  'git push -f origin claude/active-work'
run_case allow 'git push -u origin claude/1-x'
run_case allow 'git push origin claude/1-x'
run_case deny  'git push origin abc123:refs/heads/claude/active-work'
run_case deny  'git push origin HEAD:claude/active-work'
run_case deny  'git push origin abc:heads/claude/active-work'
run_case deny  'git push origin {HEAD:claude/active-work,x}'
run_case deny  'jj git push -b claude/active-work'
run_case deny  'jj git push --bookmark=claude/active-work'
run_case allow 'bash .claude/routines/pickup.sh acquire --issue 1 --slug x --session https://example.invalid/s --writers a'
run_case allow 'bash /tmp/pickup.sh release R-1 abc123'
run_case allow 'jj git push -b claude/1-x'
run_case allow 'git status'
run_case allow 'ls -la && echo done'

# --- 1. --all / --mirror / --prune ---
run_case deny  'git push --all'
run_case deny  'git push --all origin'
run_case deny  'git push origin --all'
run_case deny  'git -C . push --all'
run_case deny  'git push --mirror'
run_case deny  'git push --mirror origin'
run_case deny  'git push --prune origin '\''refs/heads/claude/*:refs/heads/claude/*'\'''

# --- 2. 先頭コマンド判定 ---
run_case allow 'git commit -m "fix git push origin main docs"'
run_case allow 'git stash push -m main'
run_case allow 'git stash push main'
run_case allow 'git log --grep push origin main'
run_case allow 'echo git push origin main'
run_case allow 'gh pr create --body "run git push origin main"'
run_case allow 'echo "a; git push origin main"'
run_case deny  'bash -c "git push origin main"'
run_case deny  "sh -c 'git push origin develop'"
run_case deny  "sh -lc 'git push --force origin x'"
run_case deny  "bash -c 'git status && git push --all'"
run_case deny  'eval "git push origin main"'
run_case allow 'bash -c "echo hi"'
run_case allow "bash -c 'git push origin claude/1-x'"
run_case deny  'FOO=bar git push origin main'
run_case deny  'env FOO=1 git push origin main'
run_case deny  'env -i git push origin main'
run_case deny  'sudo git push origin main'
run_case deny  'sudo -u root git push origin main'
run_case deny  'command git push origin main'
run_case deny  'exec git push origin main'
run_case deny  'time git push origin main'
run_case deny  'git -C /tmp push origin main'
run_case deny  'git -c core.x=1 push origin main'
run_case deny  'git --git-dir=.git push origin main'
run_case deny  'git --git-dir .git push origin main'
run_case deny  'git --work-tree=. push origin main'
run_case deny  'git --work-tree . push origin main'
run_case deny  'git --no-pager push origin main'
run_case deny  'git -P push origin main'
run_case deny  'git --namespace=x push origin main'
run_case allow 'git -C /tmp status'
run_case allow 'git -c core.x=1 push origin claude/1-x'

# --- 6. basename ---
run_case deny  '/usr/bin/git push origin main'
run_case deny  '/usr/bin/git push --force origin claude/1-x'
run_case allow '/usr/bin/git push origin claude/1-x'

# --- 3. refspec なし / HEAD / @ は現在ブランチを解決 ---
run_case deny  'git push'                  "$REPO_DEV"
run_case deny  'git push origin'           "$REPO_DEV"
run_case deny  'git push origin HEAD'      "$REPO_DEV"
run_case deny  'git push origin @'         "$REPO_DEV"
run_case deny  'git push HEAD'             "$REPO_DEV"
run_case deny  'git push -u origin HEAD'   "$REPO_DEV"
run_case deny  'git push'                  "$REPO_MAIN"
run_case deny  'git push origin HEAD'      "$REPO_MAIN"
run_case deny  "git -C $REPO_DEV push"     "$REPO_FEAT"
run_case deny  'git push'                  ""  "$REPO_DEV"
run_case deny  'git push'                  "$REPO_LOCK"
run_case deny  'git push origin HEAD'      "$REPO_LOCK"
run_case deny  'git push -u origin HEAD'   "$REPO_LOCK"
run_case deny  'git push origin @'         "$REPO_LOCK"
run_case allow 'git push -u origin HEAD'   "$REPO_W45"
run_case allow 'git push origin HEAD'      "$REPO_W45"
run_case deny  'git push origin "refs/heads/claude/*:refs/heads/claude/*"'
run_case deny  'git push origin HEAD:refs/heads/claude/*'
run_case deny  'git push origin HEAD:refs/heads/*'
run_case deny  'git push origin "*:*"'
run_case deny  'git push origin claude/*'
run_case allow 'git push origin HEAD:refs/heads/claude/45-*'
run_case deny  'jj git push --named claude/active-work=@'
run_case deny  'jj git push --named=claude/active-work=@'
run_case allow 'jj git push --named claude/45-x=@'
run_case allow 'git push'                  "$REPO_FEAT"
run_case allow 'git push origin'           "$REPO_FEAT"
run_case allow 'git push origin HEAD'      "$REPO_FEAT"
run_case allow 'git push origin @'         "$REPO_FEAT"
run_case allow "git -C $REPO_FEAT push"    "$REPO_DEV"
run_case allow 'git push origin HEAD >/dev/null 2>&1' "$REPO_FEAT"
run_case allow 'git push'                  "$TMP/does-not-exist"
run_case allow 'git push'                  "$TMP"
run_case allow 'git push origin claude/1-x' "$REPO_DEV"
run_case deny  'git push origin HEAD >/dev/null' "$REPO_DEV"

# --- 4. fail-open ---
NOJQ_BIN="$TMP/nojq-bin"
mkdir -p "$NOJQ_BIN"
ln -s "$BASH_BIN" "$NOJQ_BIN/bash"
run_raw allow '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  'jq missing (PATH without jq): fail-open' "$NOJQ_BIN"
run_raw allow 'this is not json' 'non-JSON input'
run_raw allow '' 'empty input'
run_raw allow '{"tool_name":"Bash"}' 'JSON without command'
run_raw allow 'git push origin main' 'raw command string (not JSON)'

# --- 5. 行継続 ---
run_case deny  $'git push \\\n origin main'
run_case deny  $'git pu\\\nsh origin main'
run_case deny  $'git push origin \\\n  --all'
run_case deny  $'git status\ngit push origin main'
run_case allow $'git status\ngit log'

# --- 5b. jq が CRLF を出力する環境(Windows の jq.exe)を、LF を CRLF に変えるラッパーで再現する ---
CR_BIN="$TMP/crjq-bin"
mkdir -p "$CR_BIN"
REAL_JQ="$(command -v jq)"
{
  echo '#!/bin/bash'
  echo "\"$REAL_JQ\" \"\$@\" | sed 's/\$/\r/'"
} > "$CR_BIN/jq"
chmod +x "$CR_BIN/jq"

# run_crlf expect cmd [cwd]
run_crlf() {
  local expect="$1" cmd="$2" cwd="${3:-.}" out rc
  out=$(MSYS2_ARG_CONV_EXCL="*" jq -n --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | PATH="$CR_BIN:$PATH" "$BASH_BIN" "$GUARD")
  rc=$?
  judge "$expect" "$rc" "$out" "[CRLF jq] $cmd${cwd:+  (cwd=$cwd)}"
}
run_crlf deny  $'git push \\\n origin main'
run_crlf deny  $'git pu\\\nsh origin main'
run_crlf deny  $'git push origin \\\n  --all'
run_crlf deny  $'git status\ngit push origin main'
run_crlf deny  'git push origin main'
run_crlf deny  'git push' "$REPO_DEV"
run_crlf allow 'git push' "$REPO_FEAT"
run_crlf allow $'git status\ngit log'

# --- 7. 引用符・ブレース ---
run_case deny  'git push origin ma""in'
run_case deny  "git push origin 'main'"
run_case deny  'git push origin "develop"'
run_case deny  'git push origin ma\in'
run_case deny  'git push origin {main,x}'
run_case deny  'git push origin {x,develop}'
run_case deny  'git push origin {a,main,b}'
run_case deny  'git push origin HEAD:{x,main}'
run_case allow 'git push origin {x,y}'
run_case allow 'git push origin claude/{a,b}'

# --- 8. jj ---
run_case deny  'jj --no-pager git push -b main'
run_case deny  'jj -R . git push --all'
run_case deny  'jj --repository /x git push -b develop'
run_case deny  'jj --repository=/x git push -b develop'
run_case deny  'jj --config x=y git push -b main'
run_case deny  'jj --ignore-working-copy git push --all'
run_case deny  'jj --at-op @ git push --all'
run_case deny  'jj git push --tracked'
run_case deny  'jj git push -bmain'
run_case deny  'jj git push -b=main'
run_case deny  'jj git push --bookmark=develop'
run_case deny  'jj git push --bookmark main'
run_case deny  'jj git push -r main'
run_case deny  'jj git push --revisions develop'
run_case deny  'jj git push --revisions=develop'
run_case deny  'jj git push -rmain'
run_case deny  'jj git push -r "main..@"'
run_case deny  'jj git push --allow-new --tracked'
run_case deny  'jj git push --allow-new --bookmark main'
run_case deny  '/usr/bin/jj git push -b main'
run_case deny  'jj git push -b claude/x -b main'
run_case allow 'jj git push --allow-new -b claude/1-x'
run_case allow 'jj --ignore-working-copy git push -b claude/1-x'
run_case allow 'jj --repository /x git push -b claude/y'
run_case allow 'jj git push -r claude/x'
run_case allow 'jj git push --bookmark main-fix'
run_case allow 'jj log -r main'
run_case allow 'jj git fetch'
run_case allow 'echo jj git push --all'

# --- 9. 値を取るオプション ---
run_case allow 'git push -o main origin x'
run_case allow 'git push --push-option main origin x'
run_case allow 'git push --push-option=main origin x'
run_case allow 'git push --receive-pack main origin x'
run_case allow 'git push --exec main origin x'
run_case allow 'git push -ofoo origin x'
run_case deny  'git push -o x origin main'

# --- 11. リモート ref の削除はすべて拒否する。claude/active-work への push は拒否する ---
run_case deny  'git push origin --delete claude/5-foo'
run_case deny  'git push origin :claude/5-foo'
run_case deny  'git push origin -d feature/x'
run_case deny  'git push origin --delete claude/active-work'
run_case deny  'git push origin --delete refs/heads/claude/active-work'
run_case deny  'git push origin -d claude/active-work'
run_case deny  'git push origin :claude/active-work'
run_case deny  'git push origin :refs/heads/claude/active-work'
run_case deny  'git push origin +abc123:refs/heads/claude/active-work'
run_case deny  'git push --force-with-lease origin abc123:refs/heads/claude/active-work'
run_case deny  'git push origin HEAD:claude/active-work'
run_case deny  'git push origin HEAD:refs/heads/claude/active-work'

# --- 12. 短いオプションの結合、--repo、長いオプションの省略形 ---
run_case deny  'git push -vd origin claude/active-work'
run_case deny  'git push -ud origin claude/active-work'
run_case deny  'git push -dv origin claude/active-work'
run_case deny  'git push -uf origin claude/1-x'
run_case deny  'git push --repo origin --delete claude/active-work'
run_case deny  'git push --repo=origin :claude/active-work'
run_case deny  'git push --repo=origin --delete claude/active-work'
run_case deny  'git push origin --del claude/active-work'
run_case deny  'git push origin --dele claude/active-work'
run_case deny  'git push --mir origin'
run_case deny  'git push --pru origin'
run_case deny  'git push --for origin claude/1-x'
run_case deny  'git push --force-w origin claude/1-x'
run_case deny  'git push --force-w=claude/1-x origin claude/1-x'
run_case deny  'git push --force-i origin claude/1-x'
run_case allow 'git push -uv origin claude/1-x'
run_case allow 'git push -v origin claude/1-x'
run_case allow 'git push --dry-run origin claude/1-x'
run_case allow 'git push --follow-tags origin claude/1-x'
run_case allow 'git push --set-upstream origin claude/1-x'
run_case allow 'git push --no-verify origin claude/1-x'
run_case deny  'git push --repo=origin abc123:refs/heads/claude/active-work'
run_case allow 'git push -uo ci.skip origin claude/1-x'

# --- 10. heads/ ---
run_case deny  'git push origin heads/main'
run_case deny  'git push origin HEAD:heads/develop'

# --- 13. ヒアドキュメント(#36) ---
# AC-001: 本文の行はファイルへ書く文字列であり、コマンドとして判定しない。
run_case allow $'cat > ./f.md <<\'EOF\'\ngit push origin main\nEOF'
run_case allow $'cat > ./f.md <<EOF\ngit push origin main\nEOF'
run_case allow $'cat > ./f.md <<"EOF"\ngit push origin main\nEOF'
run_case allow $'cat > ./f.md <<-EOF\n\tgit push origin main\n\tEOF'
run_case allow $'cat > ./f.md <<EOF\n  git push origin main\nEOF'
run_case allow $'cat > ./f.md << EOF\ngit push --force origin x\nEOF'
run_case allow $'cat > ./f.md <<\\EOF\ngit push origin develop\nEOF'
run_case allow $'cat <<A <<\'B\'\ngit push origin main\nA\ngit push origin develop\nB'
run_case allow $'cat > ./f.md <<EOF\ngit push origin main'
run_case allow $'bash -c "cat <<EOF\ngit push origin main\nEOF"'
# AC-002: 終端行の後の行はコマンドとして判定する。
run_case deny  $'cat > ./f.md <<\'EOF\'\ngit push origin main\nEOF\ngit push origin main'
run_case deny  $'cat > ./f.md <<EOF\nx\nEOF\ngit push origin develop'
run_case deny  $'cat > ./f.md <<-EOF\n\tx\n\tEOF\ngit push origin main'
run_case deny  $'cat <<A <<\'B\'\nx\nA\ny\nB\ngit push origin main'
# 終端と同じ文字列でも、前後に空白がある行や <<- でない行頭のタブは終端ではない。
run_case deny  $'cat <<EOF\n\tEOF\nEOF\ngit push origin main'
# ヒアドキュメントの開始行にある後続のコマンドは判定する。
run_case deny  $'cat <<EOF && git push origin main\nx\nEOF'
run_case deny  $'cat <<EOF; git push origin develop\nx\nEOF'
# 引用符の中の <<、ヒアストリング <<<、算術式の << はヒアドキュメントではない。
run_case deny  $'echo "<<EOF"\ngit push origin main\nEOF'
run_case deny  $'cat <<<EOF\ngit push origin main\nEOF'
run_case deny  $'echo $((1<<2))\ngit push origin main\n2'
# 語の先頭の # から行末まではコメントであり、その中の << はヒアドキュメントではない。
run_case deny  $'echo hi # <<X\ngit push origin main\nX'
run_case deny  $'# <<X\ngit push origin main\nX'
run_case deny  $'echo hi;# <<X\ngit push origin develop\nX'
run_case deny  $'cat <<EOF # <<X\nbody\nEOF\ngit push origin main\nX'
# 語の途中の # はコメントではない。
run_case allow 'git push origin feature#1'
run_case deny  'git push origin x#y main'
run_case deny  'echo $#; git push origin main'
run_case deny  'echo ${#x}; git push origin main'
run_case allow $'echo a#<<X\ngit push origin main\nX'
# 区切り語を引用した(一部でも引用符・バックスラッシュを含む)ヒアドキュメントでは、bash は本文の
# 行末のバックスラッシュ + 改行をそのまま残す。foo\ の次の EOF は終端であり、その後の行は実行される。
run_case deny  $'cat > f <<\'EOF\'\nfoo\\\nEOF\ngit push origin main'
run_case deny  $'cat > f <<"EOF"\nfoo\\\nEOF\ngit push origin main'
run_case deny  $'cat > f <<\\EOF\nfoo\\\nEOF\ngit push origin main'
run_case deny  $'cat > f <<E"O"F\nfoo\\\nEOF\ngit push origin main'
run_case deny  $'cat > f <<-\'EOF\'\n\tfoo\\\n\tEOF\ngit push origin main'
# 区切り語を引用しないヒアドキュメントでは、bash は本文の行末の奇数個のバックスラッシュ + 改行を
# 連結してから終端と比べる。foo\ + EOF は fooEOF になり終端ではないため、次の行も本文である
# (bash -c で確認: 2 行目の git push は cat の出力になり、実行されない)。
run_case allow $'cat > f <<EOF\nfoo\\\nEOF\ngit push origin main\nEOF'
# EO\ + F は EOF になり終端である。その後の行は実行される。
run_case deny  $'cat > f <<EOF\nfoo\nEO\\\nF\ngit push origin main'
# 行末の \\ (偶数個)はバックスラッシュの文字であり、連結しない。次の EOF は終端である。
run_case deny  $'cat > f <<EOF\nfoo\\\\\nEOF\ngit push origin main'
# <<- では連結した行の先頭のタブは取り除かない。EO\ + タブ F は EO<タブ>F になり終端ではない。
run_case allow $'cat > f <<-EOF\n\tEO\\\n\tF\ngit push origin main\nEOF'
# コメントは行末のバックスラッシュで次の行へ続かない。
run_case deny  $'echo a # c \\\ngit push origin main'
# 単一引用符の中のバックスラッシュ + 改行は、従来どおり連結して判定する(拒否側に倒す)。
run_case deny  $'git push origin \'ma\\\nin\''
# シェルへ渡すヒアドキュメント(開始行のどれかのセグメントのコマンドがシェル)は、bash が本文を実行するため判定する。
run_case deny  $'bash <<\'EOF\'\ngit push origin main\nEOF'
run_case deny  $'sh <<EOF\ngit push --force origin feat\nEOF'
run_case deny  $'cat <<\'EOF\' | bash\ngit push origin main\nEOF'
run_case deny  $'bash -s <<EOF\ngit push origin develop\nEOF'
run_case deny  $'/bin/bash <<EOF\ngit push origin main\nEOF'
run_case deny  $'env FOO=1 bash <<EOF\ngit push origin main\nEOF'
run_case deny  $'sudo sh <<EOF\ngit push origin main\nEOF'
run_case deny  $'command bash <<EOF\ngit push origin main\nEOF'
run_case allow $'bash <<\'EOF\'\ngit push origin claude/1-x\nEOF'
# 区切り語を引用しないヒアドキュメントの本文では、bash がコマンド置換 $( ) と ` ` を実行するため判定する。
run_case deny  $'cat <<EOF\n$(git push origin main)\nEOF'
run_case deny  $'cat <<EOF\n`git push origin main`\nEOF'
run_case deny  $'echo a<<EOF\n$(git push origin main)\nEOF'
run_case deny  $'cat <<EOF\ntext $(git push origin develop) text\nEOF'
run_case deny  $'cat <<EOF\ndon\'t $(git push origin main)\nEOF'
run_case deny  $'cat <<EOF\n$(echo x\ngit push origin main)\nEOF'
# 区切り語を引用したヒアドキュメントの本文は展開されないため判定しない。エスケープした \$( も展開されない。
run_case allow $'cat <<\'EOF\'\n$(git push origin main)\nEOF'
run_case allow $'cat <<"EOF"\n`git push origin main`\nEOF'
run_case allow $'cat <<EOF\n\\$(git push origin main)\nEOF'
# ) や閉じた ` の直後の # は語の途中であり、コメントではない。
run_case deny  'echo $(true)#x; git push origin main'
run_case deny  'echo `true`#x; git push origin main'
run_case deny  'echo $((1))#x; git push origin main'
run_case deny  $'echo $(true) #x <<X\ngit push origin main'
# 算術式の中の括弧を数え、対応する )) までの << をヒアドキュメントとして扱わない。
run_case deny  $'echo $(( ( (1)) <<2 ))\ngit push origin main'
run_case deny  $'(( (1) <<2 ))\ngit push origin main'
# source / . / eval も本文を実行しうるシェルとして扱う(引数によらず拒否側に倒す)。busybox は env と同じく読み飛ばす。
run_case deny  $'source /dev/stdin <<EOF\ngit push origin main\nEOF'
run_case deny  $'. /dev/stdin <<EOF\ngit push origin main\nEOF'
run_case deny  $'cat <<EOF | source /dev/stdin\ngit push origin main\nEOF'
run_case deny  $'busybox sh <<EOF\ngit push origin main\nEOF'
run_case deny  'busybox sh -c "git push origin main"'
# eval や bash -c の引数のコマンド置換の中のヒアドキュメントは、出力がコマンドとして実行されるため本文を判定する。
run_case deny  $'eval "$(cat <<EOF\ngit push origin main\nEOF\n)"'
run_case deny  $'bash -c "$(cat <<\'EOF\'\ngit push origin main\nEOF\n)"'
# git commit -m "$(cat <<'EOF' ...)" の本文はコミットメッセージであり、判定しない。
run_case allow $'git commit -m "$(cat <<\'EOF\'\nfix: git push origin main を直す\nEOF\n)"'
# 本文のコマンド置換の中の引用符の ) は括弧として数えない。
run_case deny  $'cat <<EOF\n$(echo ")" ; git push origin main)\nEOF'
run_case deny  $'cat <<EOF\n$(echo \')\' ; git push origin main)\nEOF'
# 区切り語の中のバックスラッシュ + 改行は取り除く。<<E\ + 改行 + OF の区切り語は EOF(引用なし)である。
run_case deny  $'cat <<E\\\nOF\nx\nEOF\ngit push origin main'
run_case allow $'cat <<E\\\nOF\ngit push origin main\nEOF'

# --- 10. --repo と現在ブランチ(#55) ---
# git は --repo を指定しても、1 番目の位置引数があればそれをリポジトリとして使う(git push --help:
# "If both are specified, the command-line argument takes precedence")。git push --repo main x は
# リモート x へ現在ブランチを push するため、現在ブランチが main / develop なら拒否する。
# 現在ブランチを解決するケースは、テストを実行するチェックアウトのブランチに依存しないよう cwd を指定する。
for repo_case in "$REPO_DEV deny" "$REPO_MAIN deny" "$REPO_FEAT allow"; do
  d="${repo_case% *}"; e="${repo_case##* }"
  run_case "$e"  'git push --repo main x'            "$d"
  run_case "$e"  'git push --repo=main x'            "$d"
  run_case "$e"  'git push --repo origin claude/1-x' "$d"
  run_case "$e"  'git push --repo origin'            "$d"
  run_case "$e"  'git push --repo=origin'            "$d"
  run_case "$e"  'git push --repo origin HEAD'       "$d"
  run_case "$e"  'git push origin'                   "$d"
  run_case "$e"  'git push'                          "$d"
  run_case "$e"  'git push origin HEAD'              "$d"
  run_case "$e"  'git push origin @'                 "$d"
  # 位置引数でリポジトリを指定し、refspec が保護ブランチでなければ現在ブランチによらず許可する。
  run_case allow 'git push --repo origin origin claude/1-x' "$d"
  run_case allow 'git push --repo=main origin x'     "$d"
  run_case allow 'git push origin claude/1-x'        "$d"
done

# --- 11. PR のマージ（gh pr merge、REST の merge と merges、GraphQL の mergePullRequest） ---
# develop へのマージは plugin_sha から写した merge-pr.sh だけで行う（.claude/rules/repository-workflow.md 3.1）。
# hook はコマンド行だけを調べるため、bash <写したファイル> merge ... は許可される。
run_case deny  'gh pr merge 7'
run_case deny  'gh pr merge 7 --merge'
run_case deny  'gh pr merge 7 --auto --merge'
run_case deny  'gh pr merge --admin 7'
run_case deny  'gh pr merge'
run_case deny  'gh pr -R owner/repo merge 7'
run_case deny  'gh -R owner/repo pr merge 7'
run_case deny  '/usr/bin/gh pr merge 7'
run_case deny  'cd x && gh pr merge 7 --squash'
run_case deny  'bash -c "gh pr merge 7"'
run_case deny  'GH_REPO=o/r gh pr merge 7'
run_case deny  'gh api -X PUT repos/o/r/pulls/7/merge -f merge_method=merge'
run_case deny  'gh api -XPUT repos/o/r/pulls/7/merge'
run_case deny  'gh api --method PUT repos/o/r/pulls/7/merge'
run_case deny  'gh api --method=put repos/o/r/pulls/7/merge'
run_case deny  'gh api repos/o/r/pulls/7/merge -X PUT -f sha=abc'
run_case deny  'gh api -X POST "repos/{owner}/{repo}/pulls/7/merge"'
run_case deny  'gh api /repos/o/r/pulls/7/merge -X PUT'
run_case deny  'gh api https://api.github.com/repos/o/r/pulls/7/merge -X PUT'
run_case deny  'gh api -X PUT repos/o/r/pulls/7/merge/'
# フィールドを渡すと gh api の既定のメソッドは POST になる。
run_case deny  'gh api repos/o/r/pulls/7/merge -f merge_method=merge'
run_case deny  'gh api repos/o/r/pulls/7/merge -F merge_method=merge'
run_case deny  'gh api repos/o/r/pulls/7/merge --raw-field merge_method=merge'
run_case deny  'gh api repos/o/r/pulls/7/merge --input body.json'
# ブランチを直接マージする API（POST repos/{owner}/{repo}/merges）は、メソッドによらず拒否する。
run_case deny  'gh api -X POST repos/o/r/merges -f base=develop -f head=claude/1-x'
run_case deny  'gh api repos/o/r/merges -f base=main -f head=develop'
run_case deny  'gh api repos/o/r/merges'
run_case deny  $'gh api graphql -f query=\'mutation { mergePullRequest(input: {pullRequestId: "x"}) { clientMutationId } }\''
run_case deny  $'gh api graphql -f query=\'mutation { enablePullRequestAutoMerge(input: {pullRequestId: "x"}) { clientMutationId } }\''
run_case deny  $'gh api graphql -f query=\'mutation { mergeBranch(input: {repositoryId: "x", base: "main", head: "develop"}) { clientMutationId } }\''
run_case allow 'gh pr view 7'
run_case allow 'gh pr list --state open'
run_case allow 'gh pr ready 7'
run_case allow 'gh pr edit 7 --body-file /tmp/body.md'
run_case allow 'gh pr create --base develop --draft --title merge --body x'
run_case allow 'gh api repos/o/r/pulls/7'
run_case allow 'gh api repos/o/r/pulls/7/reviews'
run_case allow 'gh api repos/o/r/pulls/7/merge'
run_case allow 'gh api -X GET repos/o/r/pulls/7/merge'
run_case allow 'gh api repos/o/r/pulls?state=closed&base=develop'
run_case allow $'gh api graphql -f query=\'query { repository(owner: "o", name: "r") { name } }\''
run_case allow 'bash /tmp/x/merge-pr.sh merge --pr 7 --head a --develop b'
run_case allow 'bash .claude/routines/merge-pr.sh check --pr 7 --head a --develop b'
run_case allow 'echo gh pr merge 7'
run_case allow 'git commit -m "gh pr merge を拒否する"'
run_case allow 'gh issue edit 7 --add-label gate:needs-human'

# --- 12. gh api による main / develop への書き込みと、PR のブランチの更新 ---
# Contents API の PUT / DELETE は、branch の指定がない(デフォルトブランチ main に書く)か、main / develop を指すとき拒否する。
run_case deny  'gh api -X PUT repos/o/r/contents/README.md -f message=x -f content=eA=='
run_case deny  'gh api -X PUT repos/o/r/contents/README.md -f message=x -f content=eA== -f branch=main'
run_case deny  'gh api -X PUT repos/o/r/contents/a/b.md -F branch=develop -f message=x'
run_case deny  'gh api --method PUT repos/o/r/contents/a.md -fbranch=refs/heads/develop'
run_case deny  'gh api -X PUT repos/o/r/contents/a.md --field=branch=heads/main'
run_case deny  'gh api -X DELETE repos/o/r/contents/a.md -f message=x -f sha=abc'
run_case deny  'gh api repos/o/r/contents/a.md -f message=x -f content=eA== -f branch=main'
run_case deny  'gh api -X PUT repos/o/r/contents/a.md --input body.json'
run_case deny  'gh api -X PUT repos/o/r/contents/a.md -f branch=claude/active-work'
run_case allow 'gh api -X PUT repos/o/r/contents/a.md -f message=x -f content=eA== -f branch=claude/7-x'
run_case allow 'gh api repos/o/r/contents/README.md'
run_case allow 'gh api "repos/o/r/contents/README.md?ref=main"'
run_case allow 'gh api -X GET repos/o/r/contents/a.md -f ref=develop'
# Git refs API は、GET 以外をすべて拒否する(ref の作成、更新、削除)。
run_case deny  'gh api -X PATCH repos/o/r/git/refs/heads/main -f sha=abc -F force=true'
run_case deny  'gh api -X PATCH repos/o/r/git/refs/heads/develop -f sha=abc'
run_case deny  'gh api -X DELETE repos/o/r/git/refs/heads/develop'
run_case deny  'gh api -X POST repos/o/r/git/refs/heads/main'
run_case deny  'gh api repos/o/r/git/refs -f ref=refs/heads/main -f sha=abc'
run_case deny  'gh api -X POST repos/o/r/git/refs -f ref=refs/heads/x -f sha=abc'
run_case deny  'gh api -X PATCH repos/o/r/git/refs/heads/claude/active-work -f sha=abc'
run_case allow 'gh api repos/o/r/git/ref/heads/develop'
run_case allow 'gh api repos/o/r/git/refs/heads/main'
run_case allow 'gh api -X GET repos/o/r/git/refs/heads'
run_case allow 'gh api repos/o/r/git/matching-refs/heads/claude'
# PR のブランチの更新(update-branch)は、REST と gh pr update-branch の両方を拒否する。追随は git merge で行う。
run_case deny  'gh api -X PUT repos/o/r/pulls/7/update-branch'
run_case deny  'gh api repos/o/r/pulls/7/update-branch -f expected_head_sha=abc'
run_case deny  'gh pr update-branch 7'
run_case deny  'gh pr update-branch 7 --rebase'
run_case deny  'gh -R o/r pr update-branch'
run_case allow 'gh api -X GET repos/o/r/pulls/7/update-branch'
# 自動着手と 3.1 の手順で使う読み取りとラベル、コメントの操作は許可する。
run_case allow 'gh api --paginate "repos/o/r/issues/7/events?per_page=100"'
run_case allow 'gh api "repos/o/r/actions/workflows/ci.yml/runs?branch=develop&head_sha=abc&per_page=1"'
run_case allow 'gh api repos/o/r/issues/7/dependencies/blocked_by'
run_case allow 'gh api -X POST repos/o/r/issues/7/labels -f "labels[]=gate:needs-human"'
run_case allow 'gh api -X DELETE repos/o/r/issues/7/labels/work:in-progress'
run_case allow 'gh api -X POST repos/o/r/issues/7/comments -f body=x'
run_case allow 'gh api -X PATCH repos/o/r/pulls/7 -F draft=false'

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
