#!/usr/bin/env bash
# base が develop の PR を、マージの直前の条件を確かめてからマージする（マージコミット）。
# 規則: consumer リポジトリの .claude/rules/repository-workflow.md 3.1。手順書: repo-workflow:issue-pickup 6 章。
# このスクリプトは run-checks.sh の実行とレビューをしない。それらの証跡が、マージの時点の PR の先頭（H）と
# develop の先頭（D）に対するものであることと、PR の状態がマージしてよい形であることだけを確かめる。
# 使うのは、consumer の main の .claude/repo-workflow.json の plugin_sha が指す claude-common-plugins の
# コミットにあるこのファイルの写しである（PR のブランチやセッションが読み込んだプラグインのものは使わない）。
# 取得の手順は repo-workflow:issue-pickup の「スクリプトの取得」。
#
# 使い方（clone の作業ツリーで実行する。リモートは origin）:
#   merge-pr.sh check --pr <n> --head <H> --develop <D>
#   merge-pr.sh merge --pr <n> --head <H> --develop <D>
#
# 結果は 1 行で標準出力に出す。
#   result=ok                                    （check: 条件をすべて満たす）
#   result=merged pr=<n> merge_sha=<sha>         （merge: マージした）
#   result=stop pr=<n> reason=<r> [k=v]          （条件を満たさない。マージしない）
#   result=unknown step=<s>                      （状態を確認できない。マージしない）
#   result=invalid-args detail=<...>             （引数の誤り）
# 終了コード: 0 = ok / merged、1 = stop、2 = 引数の誤り（何もしない）、3 = unknown。
#
# 確かめる順（最初に当てはまった理由で止まる）:
#   not-open / merged、base-not-develop base=<ref>、head-is-lock、head-from-fork、head-moved actual=<sha>、
#   develop-moved actual=<sha|none>、not-up-to-date behind_by=<k>、draft（merge のときだけ）、
#   label-gate-blocked on=<pr|issue-N>、label-ai-blocked on=...、label-needs-human on=...、
#   review-requested、changes-requested reviewer=<login>、check-failed name=<name>、check-pending name=<name>、
#   mergeable-false、evidence-missing、config-missing、config-invalid、gated-path path=<path>。
# 止める変更のパスは、origin の main の先頭（git ls-remote で読み、手元になければ git fetch する）の
# .claude/repo-workflow.json の gated_paths から読む。作業ツリーと PR のブランチの設定ファイルは読まない。
#   そのコミットに設定ファイルがない: result=stop reason=config-missing。
#   JSON でない、オブジェクトでない、gated_paths が空でない文字列（制御文字を含まない）の配列でない:
#   result=stop reason=config-invalid。
#   main を読めない（ls-remote の失敗、main がない、名前が refs/heads/main と完全に一致する行が 2 行以上、
#   fetch の失敗）: result=unknown step=config。
# ls-remote の結果は、ref の名前が refs/heads/main、refs/heads/develop と完全に一致する行だけを使う
# （ls-remote のパターンは名前の末尾でも一致するため、claude/x/refs/heads/main のようなブランチを除く）。
# develop がないときは result=stop reason=develop-moved actual=none、ls-remote の失敗と、完全に一致する行が
# 2 行以上のときは result=unknown step=develop。
# merge は、すべて満たすときだけ PUT repos/{owner}/{repo}/pulls/{n}/merge（merge_method=merge、sha=H）を 1 回呼ぶ。
#   HTTP 405 / 409 は result=stop reason=merge-refused http=<code>。ほかの失敗は PR を 1 回読み直し、
#   マージ済みなら result=merged、そうでなければ result=unknown step=merge。PUT は再試行しない。
#   成功の後に PR を読み直し、merged が true のときだけ result=merged を出す。
# name= と path= は行の最後のキーで、その後ろはすべてデータである（制御文字は ? に置き換える）。
# 使うコマンドは bash、git、gh、jq と、jq の出力から CR を除く tr だけである（gh api の --jq は使わない）。
# GitHub のリポジトリは origin の URL の末尾 2 要素で決める。GH_REPO があり、それと違えば
# result=unknown step=repo-mismatch で止める。
set -euo pipefail

if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  echo "merge-pr.sh: bash 4.2 or later is required (running ${BASH_VERSION})" >&2
  echo "result=unknown step=bash-4.2-required"
  exit 3
fi

readonly REMOTE="origin"
readonly LOCK_BRANCH="claude/active-work"
readonly RE_SHA='^[0-9a-f]{40}([0-9a-f]{24})?$'
export GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1

# consumer の設定ファイル（origin の main から読む）。
readonly CONFIG_PATH=".claude/repo-workflow.json"
# マージを止める変更のパス（bash のパターン。* は / にも一致する）。load_gated_paths が設定ファイルの
# gated_paths で埋める。PR の変更ファイル（名前を変えたファイルは元の名前も）のどれかが当てはまれば gated-path で止める。
GATED_PATHS=()

# jq の出力から CR を除く（pickup.sh と同じ。Windows の jq.exe は改行を CRLF で出力する）。jq の終了コードを返す。
jq() {
  local -a st
  command jq "$@" | tr -d '\r'
  st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || return "${st[0]}"
  return "${st[1]}"
}

usage() {
  printf '%s\n' 'usage:' \
    '  merge-pr.sh check --pr <n> --head <H> --develop <D>' \
    '  merge-pr.sh merge --pr <n> --head <H> --develop <D>' >&2
}

bad_args() {
  echo "result=invalid-args detail=$*"
  echo "merge-pr.sh: $*" >&2
  usage
  exit 2
}

stop() {
  echo "result=stop pr=${PR} reason=$*"
  exit 1
}

unknown() {
  echo "result=unknown step=$*"
  exit 3
}

# repo_of <url または owner/repo>: 末尾 2 要素を owner/repo の形で出す（ssh、https、ssh://、プロキシの URL、
# ホスト名付きの GH_REPO を同じ規則で扱う）。
repo_of() {
  local r="$1"
  r="${r%/}"
  r="${r%.git}"
  r="${r//:/\/}"
  local name="${r##*/}" rest="${r%/*}"
  local owner="${rest##*/}"
  printf '%s/%s' "${owner}" "${name}"
}

# リポジトリは origin の URL から決める。GH_REPO があれば、origin から求めた名前と一致することを確かめる
# （大文字と小文字は区別しない）。一致しなければ repo-mismatch で止める（何も読まない）。
resolve_repo() {
  local url
  url=$(git remote get-url "${REMOTE}" 2>/dev/null) || unknown "repo"
  REPO=$(repo_of "${url}")
  [[ "${REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || unknown "repo"
  if [ -n "${GH_REPO:-}" ]; then
    local g
    g=$(repo_of "${GH_REPO}")
    [ "${g,,}" = "${REPO,,}" ] || unknown "repo-mismatch"
  fi
}

# gh_list <path>: --paginate で全ページを読み、配列を 1 つにまとめて出す。
gh_list() {
  local raw
  raw=$(gh api --paginate "$1") || return 1
  printf '%s' "${raw}" | jq -cs 'map(if type == "array" then . else [.] end) | add // []'
}

# PR から、紐付く Issue 番号を 1 行ずつ出す jq（pickup.sh の JQ_PR_LINKS と同じ正規表現。重複は除く）。
readonly JQ_PR_LINKS='[ ((.head.ref // "") | capture("^claude/(?<n>[0-9]+)-") | .n),
  ((.body // "") | scan("(?i)\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?[ \\t]+#([0-9]+)\\b") | .[0])
  | tonumber ] | unique | .[] | tostring'

# ラベルの名前を 1 行ずつ出す jq の式の、ラベルごとの判定（gate:blocked、ai:blocked、gate:needs-human の順）。
readonly JQ_STOP_LABELS='(.labels // []) | map(.name) as $l
  | [("gate:blocked", "ai:blocked", "gate:needs-human") | . as $x | ($l | any(. == $x)) | if . then "1" else "0" end]
  | join(" ")'

# remote_ref_sha <完全な ref の名前>: origin のその ref の sha を出す。名前が完全に一致する行だけを使う
# （ls-remote のパターンは末尾一致でも当たるため）。ref がなければ空を出す。ls-remote の失敗は 1、
# 一致する行が 2 行以上は 2 を返す。
remote_ref_sha() {
  local out sha ref found="" n=0
  out=$(git ls-remote "${REMOTE}" "$1" 2>/dev/null) || return 1
  while IFS=$'\t' read -r sha ref; do
    [ "${ref}" = "$1" ] || continue
    n=$((n + 1))
    found="${sha}"
  done <<< "${out}"
  [ "${n}" -le 1 ] || return 2
  printf '%s' "${found}"
}

# load_gated_paths: origin の main の先頭のコミットから設定ファイルを読み、GATED_PATHS を埋める。
# 読めなければ stop（config-missing、config-invalid）か unknown（config）で終わる。
load_gated_paths() {
  local main json list p
  main=$(remote_ref_sha refs/heads/main) || unknown "config"
  [[ "${main}" =~ ${RE_SHA} ]] || unknown "config"
  if ! git cat-file -e "${main}^{commit}" 2>/dev/null; then
    git fetch --quiet --no-tags "${REMOTE}" "+refs/heads/main:refs/remotes/${REMOTE}/main" >/dev/null 2>&1 \
      || unknown "config"
    git cat-file -e "${main}^{commit}" 2>/dev/null || unknown "config"
  fi
  git cat-file -e "${main}:${CONFIG_PATH}" 2>/dev/null || stop "config-missing"
  json=$(git show "${main}:${CONFIG_PATH}" 2>/dev/null) || stop "config-invalid"
  list=$(jq -rs 'if length == 1 and (.[0] | type == "object") and (.[0].gated_paths | type == "array")
      and (.[0].gated_paths | all(type == "string" and length > 0 and (test("[[:cntrl:]]") | not)))
    then .[0].gated_paths[] else error("invalid config") end' <<< "${json}" 2>/dev/null) || stop "config-invalid"
  GATED_PATHS=()
  while IFS= read -r p; do
    [ -z "${p}" ] || GATED_PATHS+=("${p}")
  done <<< "${list}"
}

run_checks() {
  local mode="$1" json line

  # PR
  json=$(gh api "repos/${REPO}/pulls/${PR}") || unknown "pr"
  line=$(jq -r '[ (.state // ""), (.merged == true | tostring), (.base.ref // ""), (.head.ref // ""),
      (.head.sha // ""), (.draft == true | tostring), (.mergeable | tostring), (.user.login // ""),
      (((.requested_reviewers // []) + (.requested_teams // [])) | length | tostring),
      (.head.repo.full_name // "-") ]
      | map(gsub("[[:cntrl:][:space:]]"; "?")) | join(" ")' <<< "${json}" 2>/dev/null) || unknown "pr"
  local state merged base head_ref head_sha draft mergeable author nreq head_repo
  read -r state merged base head_ref head_sha draft mergeable author nreq head_repo <<< "${line}"
  [ -n "${head_repo:-}" ] || unknown "pr"
  local pr_labels issues evidence
  pr_labels=$(jq -r "${JQ_STOP_LABELS}" <<< "${json}") || unknown "pr"
  issues=$(jq -r "${JQ_PR_LINKS}" <<< "${json}") || unknown "pr"
  evidence=$(jq -r --arg e "develop-merge-evidence: head=${HEAD_SHA} develop=${DEVELOP_SHA} run-checks=PASS review=APPROVE" \
    '(.body // "") | split("\n") | map(gsub("^[ \t\r]+|[ \t\r]+$"; "")) | any(. == $e) | tostring' <<< "${json}") \
    || unknown "pr"

  # 1. 状態、base、head
  if [ "${state}" != "open" ]; then
    [ "${merged}" = "true" ] && stop "merged"
    stop "not-open"
  fi
  [ "${base}" = "develop" ] || stop "base-not-develop base=${base}"
  [ "${head_ref}" != "${LOCK_BRANCH}" ] || stop "head-is-lock"
  [ "${head_repo,,}" = "${REPO,,}" ] || stop "head-from-fork"
  [ "${head_sha}" = "${HEAD_SHA}" ] || stop "head-moved actual=${head_sha}"

  # 2. develop の先頭と、develop への追随
  local remote_develop
  remote_develop=$(remote_ref_sha refs/heads/develop) || unknown "develop"
  [ "${remote_develop}" = "${DEVELOP_SHA}" ] || stop "develop-moved actual=${remote_develop:-none}"
  local behind
  json=$(gh api "repos/${REPO}/compare/${DEVELOP_SHA}...${HEAD_SHA}") || unknown "compare"
  behind=$(jq -r '.behind_by | if type == "number" then tostring else error("no behind_by") end' <<< "${json}" 2>/dev/null) \
    || unknown "compare"
  [ "${behind}" = "0" ] || stop "not-up-to-date behind_by=${behind}"

  # 3. Draft（merge のときだけ。check は Ready にする前に使う）
  if [ "${mode}" = "merge" ] && [ "${draft}" = "true" ]; then
    stop "draft"
  fi

  # 4. 止めるラベル（PR と紐付く Issue）
  local -a targets=("pr") flags=("${pr_labels}")
  local n
  for n in ${issues}; do
    json=$(gh api "repos/${REPO}/issues/${n}") || unknown "issue issue=${n}"
    line=$(jq -r "${JQ_STOP_LABELS}" <<< "${json}" 2>/dev/null) || unknown "issue issue=${n}"
    targets+=("issue-${n}")
    flags+=("${line}")
  done
  local i k reason
  local -a f
  for k in 0 1 2; do
    reason=$(case "${k}" in 0) echo label-gate-blocked ;; 1) echo label-ai-blocked ;; *) echo label-needs-human ;; esac)
    for i in "${!targets[@]}"; do
      read -ra f <<< "${flags[i]}"
      [ "${f[k]:-0}" != "1" ] || stop "${reason} on=${targets[i]}"
    done
  done

  # 5. レビュー
  [ "${nreq}" = "0" ] || stop "review-requested"
  local who
  json=$(gh_list "repos/${REPO}/pulls/${PR}/reviews?per_page=100") || unknown "reviews"
  who=$(jq -r --arg a "${author}" '
    map(select((.user.login // "") != "" and .user.login != $a
      and (.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")))
    | group_by(.user.login) | map(sort_by(.submitted_at // "") | last)
    | map(select(.state == "CHANGES_REQUESTED")) | sort_by(.user.login) | .[0].user.login // empty' \
    <<< "${json}" 2>/dev/null) || unknown "reviews"
  [ -z "${who}" ] || stop "changes-requested reviewer=${who}"

  # 6. H に対するチェック（check run とコミットの status）。失敗を実行中より先に判定する。
  local raw runs statuses res
  raw=$(gh api --paginate "repos/${REPO}/commits/${HEAD_SHA}/check-runs?per_page=100") || unknown "check-runs"
  runs=$(printf '%s' "${raw}" | jq -cs 'map(.check_runs // []) | add // []' 2>/dev/null) || unknown "check-runs"
  json=$(gh api "repos/${REPO}/commits/${HEAD_SHA}/status?per_page=100") || unknown "status"
  statuses=$(jq -c '.statuses // []' <<< "${json}" 2>/dev/null) || unknown "status"
  res=$(jq -rn --argjson runs "${runs}" --argjson st "${statuses}" '
    def clean: tostring | gsub("[[:cntrl:]]"; "?");
    ([ ($runs[] | select(.status == "completed"
          and ((.conclusion // "") | IN("success", "neutral", "skipped") | not)) | .name),
       ($st[] | select(.state == "failure" or .state == "error") | .context) ] | .[0]) as $f
    | ([ ($runs[] | select(.status != "completed") | .name),
         ($st[] | select(.state == "pending") | .context) ] | .[0]) as $p
    | if $f != null then "check-failed name=\($f | clean)"
      elif $p != null then "check-pending name=\($p | clean)"
      else "" end') || unknown "check-runs"
  [ -z "${res}" ] || stop "${res}"

  # 7. GitHub のマージ可否（null は計算中。PUT の側で GitHub が判定する）
  [ "${mergeable}" != "false" ] || stop "mergeable-false"

  # 8. 証跡の行（H と D がこの実行の値と一致する行）
  [ "${evidence}" = "true" ] || stop "evidence-missing"

  # 9. 止める変更のパス（origin の main の設定ファイルから読む）
  load_gated_paths
  if [ "${#GATED_PATHS[@]}" -gt 0 ]; then
    local files p pat
    json=$(gh_list "repos/${REPO}/pulls/${PR}/files?per_page=100") || unknown "files"
    files=$(jq -r '.[] | (.filename // empty), (.previous_filename // empty) | gsub("[[:cntrl:]]"; "?")' \
      <<< "${json}" 2>/dev/null) || unknown "files"
    while IFS= read -r p; do
      [ -n "${p}" ] || continue
      for pat in "${GATED_PATHS[@]}"; do
        # shellcheck disable=SC2053
        [[ "${p}" != ${pat} ]] || stop "gated-path path=${p}"
      done
    done <<< "${files}"
  fi
}

# read_merged: PR を読み直し、マージ済みなら result=merged を出して終了する。そうでなければ 1 を返す。
read_merged() {
  local json line merged sha
  json=$(gh api "repos/${REPO}/pulls/${PR}") || return 1
  line=$(jq -r '"\(.merged == true) \(.merge_commit_sha // "")"' <<< "${json}" 2>/dev/null) || return 1
  read -r merged sha <<< "${line}"
  if [ "${merged}" = "true" ] && [[ "${sha:-}" =~ ${RE_SHA} ]]; then
    echo "result=merged pr=${PR} merge_sha=${sha}"
    exit 0
  fi
  return 1
}

do_merge() {
  local rc=0 err
  err=$( { gh api -X PUT "repos/${REPO}/pulls/${PR}/merge" -f merge_method=merge -f "sha=${HEAD_SHA}" >/dev/null; } 2>&1 ) || rc=$?
  [ -z "${err}" ] || printf '%s\n' "${err}" >&2
  if [ "${rc}" -ne 0 ]; then
    if [[ "${err}" =~ \(HTTP\ (405|409)\) ]]; then
      stop "merge-refused http=${BASH_REMATCH[1]}"
    fi
    # 応答が失敗しても GitHub の側でマージされたことがある。PR を 1 回だけ読み直す（PUT はやり直さない）。
    read_merged || unknown "merge"
  fi
  read_merged || unknown "verify"
}

main() {
  [ $# -ge 1 ] || bad_args "missing subcommand"
  local mode="$1"
  shift
  case "${mode}" in
    check|merge) ;;
    *) bad_args "unknown subcommand: ${mode}" ;;
  esac
  PR="" HEAD_SHA="" DEVELOP_SHA=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pr|--head|--develop)
        [ $# -ge 2 ] || bad_args "$1 needs a value"
        case "$1" in
          --pr) PR="$2" ;;
          --head) HEAD_SHA="$2" ;;
          --develop) DEVELOP_SHA="$2" ;;
        esac
        shift ;;
      *) bad_args "unknown argument: $1" ;;
    esac
    shift
  done
  [[ "${PR}" =~ ^[1-9][0-9]{0,8}$ ]] || bad_args "--pr must be a number"
  [[ "${HEAD_SHA}" =~ ${RE_SHA} ]] || bad_args "--head must be a full lowercase commit sha"
  [[ "${DEVELOP_SHA}" =~ ${RE_SHA} ]] || bad_args "--develop must be a full lowercase commit sha"
  resolve_repo

  run_checks "${mode}"
  if [ "${mode}" = "check" ]; then
    echo "result=ok"
    exit 0
  fi
  do_merge
}

main "$@"
