#!/bin/bash
# PreToolUse hook (matcher: Bash): main / develop への push と force push、gh による PR のマージと
# PR のブランチの更新、gh api による main / develop への書き込みを拒否する。
# 誤操作を防ぐガードであり、セキュリティ境界ではない(変数・エイリアス・スクリプト経由の
# 間接実行は検出しない)。
#
# 仕様の根拠(AC-001):
#   出典: https://code.claude.com/docs/en/hooks.md (参照日 2026-11-06)
#   - 入力: stdin の JSON。tool_name="Bash"、コマンドは tool_input.command、
#     作業ディレクトリは cwd。
#   - 拒否: exit 2 と stderr の理由、または exit 0 と
#     {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
#      "permissionDecisionReason":"..."}} の JSON。両者は混在させない。本スクリプトは後者を使う。
#   - matcher: settings.json の hooks.PreToolUse[].matcher にツール名(例 "Bash")を書く。
#
# 依存: jq(JSON の解析と拒否 JSON の生成)、git(引数なし push の現在ブランチ解決)。
#
# fail-open(判定できないときは許可する。Bash 呼び出しをすべて止めるとセッションが壊れるため):
#   - jq が無い場合: stderr に警告を出して exit 0(ガードは無効になる)。
#   - 入力が空、または JSON として読めない場合: exit 0。
#   - 引数なし push(または HEAD / @ のみ)で現在ブランチを解決できない場合
#     (git リポジトリでない、cwd が存在しない、detached HEAD、初回コミット前): 許可する。
#
# 判定の概要:
#   - コマンドを引用符・エスケープを考慮して分割し、各セグメント(; & | 改行 ( ) ` で区切る)の
#     先頭コマンドだけを見る。先頭の VAR=val、env / sudo / command / exec / time / nohup は読み飛ばす。
#     basename で比較する(/usr/bin/git も git)。bash -c / sh -c / eval の引数は入れ子として再判定する。
#   - ヒアドキュメント(<< / <<-)の本文の行は判定しない。終端行の後の行と、開始行の後続のコマンドは判定する。
#     ただし開始行にシェル(bash <<EOF、cat <<EOF | bash など)があれば本文を判定し、区切り語を引用しない
#     本文のコマンド置換 $( ) と ` ` の中身は判定する。
#     シェル(bash / sh / zsh / dash / ksh、busybox 経由を含む)、source、.、eval は本文を実行しうるものとして扱う。
#
# 既知の制限(ヒアドキュメント):
#   - xargs / ssh などは本文を入力として受け取るが、ローカルでは実行しないため許可する(意図した動作)。
#   - 上記以外で本文を実行するコマンド(python -c 'exec(input())'、perl など)は検出しない。
#   - 本文がシェルへ渡るかは開始行のセグメントだけで判定する(exec 0<&3 のような fd の付け替えは追跡しない)。
#   - (true)#x の # は bash ではコメントだが、本スクリプトは語の途中として扱い、後続を判定する(拒否側に倒す)。
#   - $( ) と ` ` の入れ子は、ヒアドキュメントの本文のコマンド置換の抽出を除いて追跡しない。
#   - git: グローバルオプション(-C, -c, --git-dir など)を読み飛ばし、サブコマンドが push のときだけ判定する。
#   - 拒否: --force 系 / +refspec / --all / --mirror / --prune / main・develop への refspec
#     (heads/main、refs/heads/main、ブレース展開 {main,x}、引用符分断 ma""in を含む)。
#     長いオプションは省略形(--mir、--force-w など)も、短いオプションは結合(-uf、-vd など)も判定する。
#   - 引数なし push、または refspec が HEAD / @ だけの push は、現在ブランチが main / develop なら拒否する。
#     解決に使うディレクトリは入力 JSON の cwd(無ければ .)に、コマンド内の git -C の値を順に適用したもの。
#     コマンド内の cd は追跡しない。push.default や remote.pushDefault などの git 設定は考慮しない。
#   - jj: 先頭コマンドが jj のとき、グローバルオプションを読み飛ばし git push だけを判定する。
#     --all / --tracked / -b・--bookmark / -r・--revisions が main・develop を指す場合を拒否する。
#
# リモート ref の削除: --delete / -d / :<ref> / <空>:refs/heads/<ref> は、ref によらずすべて拒否する
# (claude/active-work を含む。ref の削除は人間が GitHub の UI から行う)。refspec の src が空でない
# 通常の push は削除として扱わない。
#
# 自動着手のロック claude/active-work: 宛先がこの ref の git push(<src>:claude/active-work、
# <src>:refs/heads/claude/active-work、<src>:heads/claude/active-work、ブレース展開を含む)と、
# jj git push の bookmark 指定はすべて拒否する。ロックは pickup.sh(repo-workflow の scripts/ にあり、
# consumer の .claude/repo-workflow.json の plugin_sha から一時ディレクトリに写したもの)だけで操作する。
# hook はコマンド行だけを調べ、bash -c / sh -c / eval 以外の bash <ファイル> の中身は再判定しないため、
# bash <一時ディレクトリ>/pickup.sh ... は許可される。
#
# PR のマージ: develop へのマージは、plugin_sha から一時ディレクトリに写した merge-pr.sh だけで行う
# (.claude/rules/repository-workflow.md 3.1、repo-workflow:issue-pickup の「スクリプトの取得」)。次の gh のコマンドを拒否する。
#   - gh pr merge(--auto、--admin などのオプションによらない)。
#   - gh api の pulls/<n>/merge へのリクエストで、メソッドが GET 以外のもの(-X / --method の指定、または
#     -f / -F / --field / --raw-field / --input があり既定のメソッドが POST になるもの)。
#   - gh api の repos/<owner>/<repo>/merges(ブランチを base へ直接マージする API)。メソッドによらない。
#   - gh api graphql で、引数に mergePullRequest、enablePullRequestAutoMerge、mergeBranch を含むもの。
#   - gh pr update-branch と、gh api の pulls/<n>/update-branch へのメソッドが GET 以外のリクエスト
#     (develop への追随は作業ブランチで git merge refs/remotes/origin/develop を実行して push する)。
#
# API による main / develop への書き込み: git push を通らない書き込みも拒否する。メソッドの決め方は上と同じ。
#   - gh api の repos/<owner>/<repo>/git/refs と git/ref 以下へのリクエストで、メソッドが GET 以外のもの
#     (ref の作成、更新、削除。ref によらない)。
#   - gh api の repos/<owner>/<repo>/contents/<path> へのリクエストで、メソッドが GET 以外のもの
#     (PUT / DELETE)のうち、-f / -F / --field / --raw-field の branch がない(デフォルトブランチ main に書く)、
#     main / develop / claude/active-work を指す、または --input で本文を渡すもの。
#
# 既知の制限(gh): ガードはセキュリティ境界ではない。次は検出しない。
#   - gh の別名(gh alias)と、gh 以外の HTTP クライアント(curl など)。
#   - GraphQL の問い合わせをファイルで渡すもの(-F query=@file、--input file)。ファイルの中身は読まない。
#   - xargs など、引数を別のコマンドに渡して gh を実行するもの。
#   - エンドポイントの大文字(Repos/...)や .. を含むパス、URL エンコードしたパス。
#   bash <写したファイル> merge ... は、ファイルの中身を判定しないため許可される。
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "pre-push-guard: jq が見つからないため判定をスキップします(fail-open)" >&2
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
if [ -z "$COMMAND" ]; then
  exit 0
fi
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$CWD" ] || CWD="."

# Windows の jq.exe は改行を CRLF で出力するため、CR を取り除く。
COMMAND=${COMMAND//$'\r'/}
CWD=${CWD//$'\r'/}

# 行継続(バックスラッシュ + 改行)は process_line の中で扱う。ヒアドキュメントの本文では、区切り語を
# 引用したときは連結せず、引用しないときは終端と比べる前に連結する(bash と同じ)。

REASON=""
GIT_CDIRS=()
# 1 のとき、ヒアドキュメントの本文を読み飛ばさずにコマンドとして判定する(eval / シェル -c の引数の中)。
HD_EXEC=0

deny() {
  REASON="$1"
}

is_protected() {
  local ref="${1#+}"
  ref="${ref##*:}"
  ref="${ref#refs/heads/}"
  ref="${ref#heads/}"
  [ "$ref" = "main" ] || [ "$ref" = "develop" ]
}

is_lock() {
  local ref="${1#+}"
  ref="${ref##*:}"
  ref="${ref#refs/heads/}"
  ref="${ref#heads/}"
  [ "$ref" = "claude/active-work" ]
}

# ブレース展開 {a,b} の各要素も含めて保護対象かを判定する。第 2 引数に判定関数を渡せる(既定は is_protected)。
is_protected_token() {
  local tok="$1" pred="${2:-is_protected}" re='^(.*)\{([^{}]*,[^{}]*)\}(.*)$' e
  local -a els
  if [[ "$tok" =~ $re ]]; then
    IFS=, read -ra els <<<"${BASH_REMATCH[2]}"
    for e in "${els[@]}"; do
      if "$pred" "${BASH_REMATCH[1]}$e${BASH_REMATCH[3]}"; then return 0; fi
    done
  fi
  "$pred" "$tok"
}

is_lock_token() {
  is_protected_token "$1" is_lock
}

# jj のリビジョン指定が main / develop を名指ししているか。
names_protected() {
  local v="$1" re='(^|[^A-Za-z0-9_/-])(main|develop)($|[^A-Za-z0-9_/-])'
  is_protected_token "$v" || [[ "$v" =~ $re ]]
}

# jj のリビジョン指定が claude/active-work を名指ししているか。
names_lock() {
  local v="$1" re='(^|[^A-Za-z0-9_/-])claude/active-work($|[^A-Za-z0-9_/-])'
  is_lock_token "$v" || [[ "$v" =~ $re ]]
}

# refspec の宛先が * を含み、claude/active-work に一致するか(claude/*、refs/heads/*、* など)。
lock_glob_dst() {
  local dst="${1#+}"
  dst="${dst##*:}"
  [[ "$dst" == *'*'* ]] || return 1
  # shellcheck disable=SC2053
  [[ "claude/active-work" == $dst || "refs/heads/claude/active-work" == $dst ]]
}

LOCK_REASON="claude/active-work への push は禁止です。ロックは repo-workflow の \`pickup.sh\`(plugin_sha から一時ディレクトリに写したもの)だけで操作する"
UPDATE_BRANCH_REASON="PR のブランチの更新(gh pr update-branch、pulls/<n>/update-branch)は行いません。develop への追随は作業ブランチで git merge refs/remotes/origin/develop を実行して push します(.claude/rules/repository-workflow.md 3.1 の手順 3)"
API_WRITE_REASON="gh api による main / develop / claude/active-work への書き込み(Contents API の PUT / DELETE、Git refs API の GET 以外)は禁止です。作業ブランチに git push し、develop 宛の PR を作成してください"
MERGE_REASON="PR のマージは plugin_sha から一時ディレクトリに写した repo-workflow の \`merge-pr.sh\` だけで行います(.claude/rules/repository-workflow.md 3.1)。gh pr merge、gh api によるマージ、auto-merge の有効化は行いません"

current_branch() {
  local d="$CWD" x b
  for x in ${GIT_CDIRS[@]+"${GIT_CDIRS[@]}"}; do
    case "$x" in
      /*) d="$x" ;;
      *) d="$d/$x" ;;
    esac
  done
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null) || b=""
  printf '%s' "$b"
}

# $1 が残りの引数のいずれかの前方一致か(git は長いオプションの一意な省略形を受け付ける)。
abbrev_of() {
  local p="$1" full
  shift
  for full in "$@"; do
    if [ "${full#"$p"}" != "$full" ]; then return 0; fi
  done
  return 1
}

check_git_push() {
  local -a pos=()
  local delete=0 arg skip=0 redir='^[0-9]*(>>?|<)(.*)$' r lopt grp
  for arg in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [[ "$arg" =~ $redir ]]; then
      [ -n "${BASH_REMATCH[2]}" ] || skip=1
      continue
    fi
    case "$arg" in
      --) ;;
      -o|--push-option|--repo|--receive-pack|--exec) skip=1 ;;
      -o?*|--push-option=*|--repo=*|--receive-pack=*|--exec=*) ;;
      --*)
        # 曖昧な省略形(--f など)は git がエラーにするため、拒否側に倒しても害はない。
        lopt="${arg#--}"
        lopt="${lopt%%=*}"
        if abbrev_of "$lopt" force force-with-lease force-if-includes; then
          deny "force push は禁止です"; return
        fi
        if abbrev_of "$lopt" all mirror prune; then
          deny "git push $arg は全ブランチを対象とするため禁止です"; return
        fi
        if abbrev_of "$lopt" delete; then delete=1; fi ;;
      -*)
        # 結合した短いオプション(-vd、-uf など)。o 以降は -o の値である。
        grp="${arg#-}"
        if [[ "$grp" == *o* ]]; then
          [ -n "${grp#*o}" ] || skip=1
          grp="${grp%%o*}"
        fi
        if [[ "$grp" == *f* ]]; then
          deny "force push は禁止です"; return
        fi
        if [[ "$grp" == *d* ]]; then delete=1; fi ;;
      +*)
        deny "force push(+refspec)は禁止です"; return ;;
      *)
        pos+=("$arg")
        if is_protected_token "$arg"; then
          deny "main / develop への push は禁止です"; return
        fi
        if is_lock_token "$arg" || lock_glob_dst "$arg"; then
          deny "$LOCK_REASON"; return
        fi ;;
    esac
  done
  # リモート ref の削除はすべて拒否する。pos[0] は通常リポジトリだが、拒否側に倒すため 0 から見る。
  for ((r = 0; r < ${#pos[@]}; r++)); do
    if [ "$delete" = 1 ] || [[ "${pos[r]}" == :* ]]; then
      deny "リモート ref の削除は禁止です。ref の削除は人間が GitHub の UI から行ってください"; return
    fi
  done
  # refspec なし、または HEAD / @ だけのときは現在ブランチを確認する。
  # --repo を指定しても、git は位置引数があれば pos[0] をリポジトリとして使うため、refspec は pos[1] から見る(#55)。
  local resolve=1
  for ((r = 1; r < ${#pos[@]}; r++)); do
    if [ "${pos[r]}" != "HEAD" ] && [ "${pos[r]}" != "@" ]; then resolve=0; fi
  done
  if [ "$resolve" = 1 ]; then
    local b
    b=$(current_branch)
    if [ "$b" = "main" ] || [ "$b" = "develop" ]; then
      deny "現在のブランチ($b)への push は禁止です"; return
    fi
    if [ "$b" = "claude/active-work" ]; then
      deny "$LOCK_REASON"; return
    fi
  fi
}

check_jj_push() {
  local arg prev=""
  for arg in "$@"; do
    case "$arg" in
      --bookmark=*|-b=*|--revisions=*|-r=*|--named=*)
        if names_lock "${arg#*=}"; then deny "$LOCK_REASON"; return; fi ;;
      -b?*)
        if names_lock "${arg#-b}"; then deny "$LOCK_REASON"; return; fi ;;
      -r?*)
        if names_lock "${arg#-r}"; then deny "$LOCK_REASON"; return; fi ;;
    esac
    case "$prev" in
      -b|--bookmark|-r|--revisions|--named)
        if names_lock "$arg"; then deny "$LOCK_REASON"; return; fi ;;
    esac
    case "$arg" in
      --all|--tracked)
        deny "jj git push $arg は禁止です"; return ;;
      --bookmark=*|-b=*)
        if names_protected "${arg#*=}"; then deny "main / develop への push は禁止です"; return; fi ;;
      -b?*)
        if names_protected "${arg#-b}"; then deny "main / develop への push は禁止です"; return; fi ;;
      --revisions=*|-r=*)
        if names_protected "${arg#*=}"; then deny "main / develop を含む push は禁止です"; return; fi ;;
      -r?*)
        if names_protected "${arg#-r}"; then deny "main / develop を含む push は禁止です"; return; fi ;;
    esac
    case "$prev" in
      -b|--bookmark|-r|--revisions)
        if names_protected "$arg"; then deny "main / develop への push は禁止です"; return; fi ;;
    esac
    prev="$arg"
  done
}

parse_git() {
  local depth="$1"; shift
  local -a a=("$@")
  local m=${#a[@]} j=0
  GIT_CDIRS=()
  while [ "$j" -lt "$m" ]; do
    case "${a[j]}" in
      -C) GIT_CDIRS+=("${a[j+1]:-}"); j=$((j + 2)) ;;
      -c|--git-dir|--work-tree|--namespace|--super-prefix|--config-env) j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$j" -lt "$m" ] && [ "${a[j]}" = "push" ]; then
    check_git_push "${a[@]:j+1}"
  fi
}

# gh のコマンドを判定する(PR のマージ、PR のブランチの更新、main / develop への API での書き込み)。
# 位置引数の 1 番目と 2 番目でサブコマンドを決める。
parse_gh() {
  local -a pos=()
  local arg skip=0 method="" fields=0 input=0 branch="" branch_set=0 all="" ep kv
  for arg in "$@"; do
    all+=" $arg"
    if [ "$skip" != 0 ]; then
      case "$skip" in
        method) method="$arg" ;;
        field) kv="$arg" ;;
      esac
      skip=0
      [ -z "${kv:-}" ] || { case "$kv" in branch=*) branch="${kv#branch=}"; branch_set=1 ;; esac; kv=""; }
      continue
    fi
    kv=""
    case "$arg" in
      -X|--method) skip=method ;;
      -X?*) method="${arg#-X}" ;;
      --method=*) method="${arg#*=}" ;;
      --input) fields=1; input=1; skip=1 ;;
      --input=*) fields=1; input=1 ;;
      -f|-F|--field|--raw-field) fields=1; skip=field ;;
      -f?*|-F?*) fields=1; kv="${arg#-?}" ;;
      --field=*|--raw-field=*) fields=1; kv="${arg#*=}" ;;
      -R|--repo|-H|--header|-q|--jq|-t|--template|--hostname|--cache|-p|--preview) skip=1 ;;
      -*) ;;
      *) pos+=("$arg") ;;
    esac
    [ -z "$kv" ] || { case "$kv" in branch=*) branch="${kv#branch=}"; branch_set=1 ;; esac; kv=""; }
  done
  if [ "${pos[0]:-}" = "pr" ] && [ "${pos[1]:-}" = "merge" ]; then
    deny "$MERGE_REASON"; return
  fi
  if [ "${pos[0]:-}" = "pr" ] && [ "${pos[1]:-}" = "update-branch" ]; then
    deny "$UPDATE_BRANCH_REASON"; return
  fi
  [ "${pos[0]:-}" = "api" ] || return 0
  ep="${pos[1]:-}"
  if [ "$ep" = "graphql" ] || [[ "$ep" == */graphql ]]; then
    case "$all" in
      *mergePullRequest*|*enablePullRequestAutoMerge*|*mergeBranch*) deny "$MERGE_REASON" ;;
    esac
    return
  fi
  ep="${ep%%[?#]*}"
  ep="${ep%/}"
  if [[ "$ep" =~ (^|/)repos/[^/]+/[^/]+/merges$ ]]; then
    deny "$MERGE_REASON"; return
  fi
  if [ -z "$method" ]; then
    if [ "$fields" = 1 ]; then method=POST; else method=GET; fi
  fi
  # macOS の /bin/bash 3.2 は ${var^^} を使えないため、case で大文字と小文字を区別せずに比べる。
  case "$method" in
    [Gg][Ee][Tt]) return 0 ;;
  esac
  if [[ "$ep" =~ (^|/)repos/[^/]+/[^/]+/pulls/[^/]+/merge$ ]]; then
    deny "$MERGE_REASON"; return
  fi
  if [[ "$ep" =~ (^|/)repos/[^/]+/[^/]+/pulls/[^/]+/update-branch$ ]]; then
    deny "$UPDATE_BRANCH_REASON"; return
  fi
  if [[ "$ep" =~ (^|/)repos/[^/]+/[^/]+/git/refs?(/|$) ]]; then
    deny "$API_WRITE_REASON"; return
  fi
  if [[ "$ep" =~ (^|/)repos/[^/]+/[^/]+/contents(/|$) ]]; then
    # branch がなければ GitHub はデフォルトブランチ(main)に書く。--input の本文は読まないため拒否側に倒す。
    if [ "$input" = 1 ] || [ "$branch_set" = 0 ]; then
      deny "$API_WRITE_REASON"; return
    fi
    branch="${branch#refs/heads/}"
    branch="${branch#heads/}"
    case "$branch" in
      ""|main|develop|claude/active-work) deny "$API_WRITE_REASON"; return ;;
    esac
  fi
}

parse_jj() {
  local -a a=("$@")
  local m=${#a[@]} j=0
  while [ "$j" -lt "$m" ]; do
    case "${a[j]}" in
      -R|--repository|--config|--config-toml|--config-file|--at-op|--at-operation|--color)
        j=$((j + 2)) ;;
      -*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if [ "$((j + 1))" -lt "$m" ] && [ "${a[j]}" = "git" ] && [ "${a[j+1]}" = "push" ]; then
    check_jj_push "${a[@]:j+2}"
  fi
}

# 1 セグメント(トークン配列)を判定する。第 1 引数は入れ子の深さ。
check_segment() {
  local depth="$1"; shift
  local -a t=("$@")
  local n=${#t[@]} i=0 w base wrap="" k
  SEG_SHELL=0
  local assign='^[A-Za-z_][A-Za-z0-9_]*='
  while [ "$i" -lt "$n" ]; do
    w="${t[i]}"; base="${w##*/}"
    if [[ "$w" =~ $assign ]]; then i=$((i + 1)); continue; fi
    case "$w" in
      '{'|'}'|'!'|if|then|do|else|elif|while|until) i=$((i + 1)); continue ;;
    esac
    if [ -n "$wrap" ] && [[ "$w" == -* ]]; then
      case "$wrap:$w" in
        env:-u|env:-C|env:-S|sudo:-u|sudo:-g|sudo:-h|sudo:-p|sudo:-C|sudo:-D|sudo:-R|sudo:-T|sudo:-U)
          i=$((i + 2)) ;;
        *) i=$((i + 1)) ;;
      esac
      continue
    fi
    case "$base" in
      env|sudo|command|exec|time|nohup|busybox) wrap="$base"; i=$((i + 1)); continue ;;
    esac
    break
  done
  [ "$i" -lt "$n" ] || return 0
  base="${t[i]##*/}"
  local -a rest=("${t[@]:i+1}")
  local m=${#rest[@]}
  case "$base" in
    git) parse_git "$depth" ${rest[@]+"${rest[@]}"} ;;
    jj) parse_jj ${rest[@]+"${rest[@]}"} ;;
    gh) parse_gh ${rest[@]+"${rest[@]}"} ;;
    bash|sh|zsh|dash|ksh)
      local cre='^-[a-zA-Z]*c[a-zA-Z]*$'
      for ((k = 0; k < m; k++)); do
        if [[ "${rest[k]}" =~ $cre ]]; then
          # 引数のコマンド置換の出力はコマンドとして実行されるため、その中のヒアドキュメントの本文も判定する。
          if [[ "${rest[k+1]:-}" == *'$('* || "${rest[k+1]:-}" == *'`'* ]]; then
            local old_exec="$HD_EXEC"; HD_EXEC=1
            process_line "${rest[k+1]:-}" $((depth + 1))
            HD_EXEC="$old_exec"
          else
            process_line "${rest[k+1]:-}" $((depth + 1))
          fi
          break
        fi
        [[ "${rest[k]}" == -* ]] || break
      done
      # 先頭コマンドがシェルであることを呼び出し元に知らせる(標準入力のヒアドキュメントを実行するため)。
      SEG_SHELL=1 ;;
    eval)
      # eval の引数のヒアドキュメント(コマンド置換の中を含む)の本文はコマンドとして実行されうるため判定する。
      local old_exec="$HD_EXEC"; HD_EXEC=1
      process_line "${rest[*]:-}" $((depth + 1))
      HD_EXEC="$old_exec"
      SEG_SHELL=1 ;;
    source|.)
      # 引数によらず、標準入力のヒアドキュメントを実行しうるものとして扱う(拒否側に倒す)。
      SEG_SHELL=1 ;;
  esac
}

flush_tok() {
  if [ "$has" = 1 ]; then tok+=("$cur"); fi
  cur=""; has=0
}

end_seg() {
  flush_tok
  SEG_SHELL=0
  if [ "${#tok[@]}" -gt 0 ]; then
    check_segment "$depth" "${tok[@]}"
  fi
  [ "$SEG_SHELL" = 0 ] || line_shell=1
  tok=()
}

# 区切り語を引用しないヒアドキュメントの本文 $1 から、コマンド置換 $( ) と ` ` の中身を取り出して
# 入れ子として判定する(bash は本文を展開するため)。\ の次の文字はエスケープとして読み飛ばす。
# $( ) は括弧の数で対応を取る(中の引用符は考慮しない)。閉じていなければ本文の終わりまでを中身とする。
check_heredoc_subst() {
  local s="$1" d="$2" k=0 L=${#1} st pd inner
  while [ "$k" -lt "$L" ]; do
    [ -z "$REASON" ] || return 0
    case "${s:k:1}" in
      '\') k=$((k + 2)); continue ;;
      '$')
        if [ "${s:k+1:1}" = '(' ]; then
          st=$((k + 2)); pd=1; k=$st
          while [ "$k" -lt "$L" ] && [ "$pd" -gt 0 ]; do
            case "${s:k:1}" in
              '(') pd=$((pd + 1)) ;;
              ')') pd=$((pd - 1)) ;;
              '\') k=$((k + 1)) ;;
              "'")
                # 単一引用符の中の括弧は数えない。
                k=$((k + 1))
                while [ "$k" -lt "$L" ] && [ "${s:k:1}" != "'" ]; do k=$((k + 1)); done ;;
              '"')
                # 二重引用符の中の括弧は数えない(\ の次の文字は読み飛ばす)。
                k=$((k + 1))
                while [ "$k" -lt "$L" ] && [ "${s:k:1}" != '"' ]; do
                  [ "${s:k:1}" != '\' ] || k=$((k + 1))
                  k=$((k + 1))
                done ;;
            esac
            k=$((k + 1))
          done
          if [ "$pd" = 0 ]; then inner="${s:st:k-1-st}"; else inner="${s:st}"; fi
          process_line "$inner" $((d + 1))
          continue
        fi ;;
      '`')
        st=$((k + 1))
        inner="${s:st}"
        inner="${inner%%\`*}"
        process_line "$inner" $((d + 1))
        k=$((st + ${#inner} + 1))
        continue ;;
    esac
    k=$((k + 1))
  done
}

# ヒアドキュメントの区切り語を読む。$1 は << の直後の位置。HD_WORD(引用符とバックスラッシュを
# 取り除いた語)と HD_END(語の直後の位置)を設定する。<<- のときは HD_TABS=1 にする。
# 語が引用符またはバックスラッシュを含むときは HD_QUOTED=1 にする(本文の行継続を連結しない)。
read_heredoc_word() {
  local line="$1" p="$2" n=${#1} hq="" hc
  HD_WORD=""; HD_TABS=0; HD_QUOTED=0
  if [ "${line:p:1}" = "-" ]; then HD_TABS=1; p=$((p + 1)); fi
  while [ "$p" -lt "$n" ] && { [ "${line:p:1}" = ' ' ] || [ "${line:p:1}" = $'\t' ]; }; do
    p=$((p + 1))
  done
  for ((; p < n; p++)); do
    hc="${line:p:1}"
    if [ -n "$hq" ]; then
      if [ "$hc" = "$hq" ]; then hq=""; else HD_WORD+="$hc"; fi
      continue
    fi
    case "$hc" in
      "'"|'"') hq="$hc"; HD_QUOTED=1 ;;
      '\')
        # バックスラッシュ + 改行は行継続として取り除く(<<E\ + 改行 + OF の区切り語は EOF)。
        p=$((p + 1))
        if [ "${line:p:1}" != $'\n' ]; then HD_WORD+="${line:p:1}"; HD_QUOTED=1; fi ;;
      ' '|$'\t'|$'\n'|';'|'&'|'|'|'('|')'|'<'|'>'|'`') break ;;
      *) HD_WORD+="$hc" ;;
    esac
  done
  HD_END=$p
}

# 引用符・エスケープを考慮して分割する。引用符そのものは取り除く(ma""in は main になる)。
# ヒアドキュメント(<< / <<-)は区切り語を記録し、その行を終える改行の後から終端行までの本文を
# 判定の対象から外す(本文はコマンドではなく入力の文字列であるため)。1 行に複数あれば順に読み飛ばす。
# 終端行が無ければ残りすべてを本文とする(bash と同じ)。引用符の中の <<、ヒアストリング <<<、
# 算術式 (( )) の中の << はヒアドキュメントとして扱わない。
# 語の先頭の #(入力の先頭、空白、; & | ( ) ` 改行の直後)から行末まではコメントとして読み飛ばす。
# 語の途中の #(a#b、${#x}、$#、$(true)#x、`true`#x)はコメントではない。
# 例外: 開始行のどれかのセグメントの先頭コマンドがシェル(bash <<EOF、cat <<EOF | bash など)のときは、
# 本文を読み飛ばさずコマンドとして判定する。区切り語を引用しない本文のコマンド置換は判定する。
process_line() {
  local line="$1" depth="${2:-0}"
  [ "$depth" -le 3 ] || return 0
  local -a tok=() hd_words=() hd_tabs=() hd_quoted=()
  local cur="" has=0 q="" c nx i n=${#line} arith=0 apd=0 gl=0 bt=0 line_shell=0 h p body bl bs hd_body
  local HD_WORD HD_TABS HD_QUOTED HD_END
  for ((i = 0; i < n; i++)); do
    [ -z "$REASON" ] || return 0
    c="${line:i:1}"
    if [ "$q" = "'" ]; then
      # 単一引用符の中のバックスラッシュ + 改行は、bash では文字のままだが、拒否側に倒すため連結する。
      if [ "$c" = "'" ]; then
        q=""
      elif [ "$c" = '\' ] && [ "${line:i+1:1}" = $'\n' ]; then
        i=$((i + 1))
      else
        cur+="$c"
      fi
    elif [ "$q" = '"' ]; then
      if [ "$c" = '"' ]; then
        q=""
      elif [ "$c" = '\' ] && [ "$((i + 1))" -lt "$n" ]; then
        nx="${line:i+1:1}"
        case "$nx" in
          '"'|'\'|'$'|'`') cur+="$nx"; i=$((i + 1)) ;;
          $'\n') i=$((i + 1)) ;;
          *) cur+='\' ;;
        esac
      else
        cur+="$c"
      fi
    else
      case "$c" in
        "'") q="'"; has=1 ;;
        '"') q='"'; has=1 ;;
        '\')
          if [ "$((i + 1))" -lt "$n" ]; then
            i=$((i + 1)); nx="${line:i:1}"
            if [ "$nx" != $'\n' ]; then cur+="$nx"; has=1; fi
          fi ;;
        ' '|$'\t') flush_tok; gl=0 ;;
        '#')
          # gl=1 は直前が ) または閉じた ` であることを示す。その # は語の途中である。
          if [ "$has" = 0 ] && [ "$gl" = 0 ]; then
            # 語の先頭の # はコメント。次の改行の直前まで読み飛ばす(改行は下の $'\n' で扱う)。
            body="${line:i}"
            bl="${body%%$'\n'*}"
            i=$((i + ${#bl} - 1))
          else
            cur+="$c"
          fi ;;
        '<')
          if [ "$arith" = 0 ] && [ "${line:i+1:1}" = '<' ] && [ "${line:i+2:1}" != '<' ]; then
            # ヒアドキュメント。演算子と区切り語はトークンに含めない(0<<EOF の fd 番号も捨てる)。
            if [[ "$cur" =~ ^[0-9]+$ ]]; then cur=""; has=0; fi
            flush_tok
            read_heredoc_word "$line" $((i + 2))
            hd_words+=("$HD_WORD"); hd_tabs+=("$HD_TABS"); hd_quoted+=("$HD_QUOTED")
            i=$((HD_END - 1))
          elif [ "${line:i+1:2}" = '<<' ]; then
            # ヒアストリング <<<。3 文字をそのままトークンに含める。
            cur+='<<<'; has=1; i=$((i + 2))
          else
            cur+="$c"; has=1
          fi ;;
        '(')
          # 算術式 (( )) の中では括弧の数(apd)を数え、対応する )) で算術式を閉じる。
          if [ "$arith" = 1 ]; then
            apd=$((apd + 1))
          elif [ "${line:i+1:1}" = '(' ]; then
            arith=1; apd=0; i=$((i + 1))
          fi
          gl=0
          end_seg ;;
        ')')
          if [ "$arith" = 1 ]; then
            if [ "$apd" -gt 0 ]; then
              apd=$((apd - 1))
            elif [ "${line:i+1:1}" = ')' ]; then
              arith=0; i=$((i + 1))
            fi
          fi
          end_seg
          gl=1 ;;
        $'\n')
          end_seg
          gl=0
          if [ "$line_shell" = 1 ] || [ "$HD_EXEC" = 1 ]; then
            # 本文はシェルが実行するため、読み飛ばさずに次の行からコマンドとして判定する。
            hd_words=(); hd_tabs=(); hd_quoted=(); line_shell=0
            continue
          fi
          # 保留中のヒアドキュメントの本文を順に読み飛ばす。
          p=$((i + 1))
          for ((h = 0; h < ${#hd_words[@]}; h++)); do
            hd_body=""
            while [ "$p" -lt "$n" ]; do
              body="${line:p}"
              bl="${body%%$'\n'*}"
              p=$((p + ${#bl} + 1))
              if [ "${hd_tabs[h]}" = 1 ]; then
                while [ "${bl:0:1}" = $'\t' ]; do bl="${bl:1}"; done
              fi
              # 区切り語を引用しないときは、行末の奇数個のバックスラッシュ + 改行を次の行と連結する。
              # 連結した行の先頭のタブは <<- でも取り除かない(bash と同じ)。
              if [ "${hd_quoted[h]}" = 0 ]; then
                while [ "$p" -le "$n" ]; do
                  bs="${bl%"${bl##*[!\\]}"}"
                  bs="${bl:${#bs}}"
                  [ $(( ${#bs} % 2 )) = 1 ] && [ "$p" -lt "$n" ] || break
                  body="${line:p}"
                  nx="${body%%$'\n'*}"
                  p=$((p + ${#nx} + 1))
                  bl="${bl%\\}$nx"
                done
              fi
              [ "$bl" != "${hd_words[h]}" ] || break
              hd_body+="$bl"$'\n'
            done
            if [ "${hd_quoted[h]}" = 0 ] && [[ "$hd_body" == *'$('* || "$hd_body" == *'`'* ]]; then
              check_heredoc_subst "$hd_body" "$depth"
              [ -z "$REASON" ] || return 0
            fi
          done
          hd_words=(); hd_tabs=(); hd_quoted=()
          i=$((p - 1)) ;;
        '`')
          # 閉じた ` の直後の # は語の途中である。
          end_seg
          bt=$((1 - bt)); gl=$((1 - bt)) ;;
        ';'|'&'|'|') end_seg; gl=0 ;;
        *) cur+="$c"; has=1 ;;
      esac
    fi
  done
  end_seg
}

process_line "$COMMAND" 0

if [ -n "$REASON" ]; then
  if [ "$REASON" = "$LOCK_REASON" ] || [ "$REASON" = "$MERGE_REASON" ]; then
    MSG="$REASON。"
  else
    MSG="${REASON}。main / develop への直接 push と force push は行いません。作業ブランチ(claude/<issue-number>-<slug>)を push し、develop 宛の PR を作成してください。"
  fi
  jq -n --arg r "$MSG" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
fi
exit 0
