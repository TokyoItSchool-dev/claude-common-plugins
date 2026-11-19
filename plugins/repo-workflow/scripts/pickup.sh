#!/usr/bin/env bash
# 【凍結】claude-common-plugins#8 の決定 D4（2026-11-17）により、このスクリプトは凍結した。新しい作業には使わない。
# ワーカープールへの移行で削除する。スケジュールタスクは使わず、ロック claude/active-work も使わない
# （acquire と release は呼ばない）。使ってよいのは、repo-workflow:issue-launch の親セッションが次の Issue を
# 選ぶための pickup.sh queue（読み取りだけ）に限る。凍結の間も動作は変えない。
#
# 自動着手のロック（refs/heads/claude/active-work）とキューを操作する。
# 手順書: repo-workflow:issue-pickup（1 章、2 章、3.1、3.3）。設計: ベーステンプレート（systemshared-ai-advance/claude-dev-template）の
# docs/template/portfolio-integration-design.md 5.5。
# 使うのは、consumer の main の .claude/repo-workflow.json の plugin_sha が指すコミットにあるこのファイルの写しである。
#
# 使い方（clone の作業ツリーで実行する。リモートは origin）:
#   pickup.sh status
#   pickup.sh queue --writers <login,...>
#   pickup.sh acquire --issue <n> --slug <slug> --session <url> --writers <login,...>
#   pickup.sh release <R-1|R-2|R-3|R-4|R-5> <expected-sha>
#
# --writers は write 以上の権限（admin、maintain、write）を持つ人の login の一覧。最新の ai:ready を付けた人と、Issue の作成者の
# 両方がこの一覧にない Issue はキューに入れない（skip の reason は not-writer、author-not-writer）。
# 結果は 1 行の key=value で標準出力に出す（queue は複数行）。git の出力は標準エラーに出す。
# 終了コード: 0 = 成功、1 = 取得・解放しなかった（正常な拒否）、2 = 引数の誤り（何も変えない）、
#             3 = 状態を確認できない。
# 使うコマンドは bash、git、gh、jq と、jq の出力から CR を除く tr だけである（gh api の --jq は使わず、gh の出力を jq に渡す）。
# status の unreadable の行では、line= を最後のキーとし、その後ろはすべてデータ（コミットメッセージの 1 行目。制御文字は ? に置き換える）である。
# GitHub のリポジトリは GH_REPO（owner/repo）、なければ origin の URL の末尾 2 要素で決める。
# 取得と解放の成否は、push の終了コードや git のメッセージではなく、push の後に読み直したロックの先頭で決める。
# push は常に force なしで行う。
set -euo pipefail

# bash 4.2 未満では printf '%(...)T'（4.2 以降）と ${var,,}（4.0 以降）が使えないため、何もせずに終了する。
if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  echo "pickup.sh: bash 4.2 or later is required (running ${BASH_VERSION})" >&2
  echo "result=unknown detail=bash-4.2-required"
  exit 3
fi

readonly REMOTE="origin"
readonly LOCK_REF="refs/heads/claude/active-work"
readonly LOCK_NAME="claude-active-work"
readonly LOCK_EMAIL="claude-active-work@example.invalid"
readonly RE_HELD='^claude-active-work: issue #([0-9]+) branch (claude/([0-9]+)-[a-z0-9]+(-[a-z0-9]+)*) session (https://[^[:space:]]+)$'
readonly RE_RELEASED='^claude-active-work: released R-[1-5] from [0-9a-f]{40}([0-9a-f]{24})?$'
readonly RE_SLUG='^[a-z0-9]+(-[a-z0-9]+)*$'
readonly RE_WRITERS='^[A-Za-z0-9-]+(,[A-Za-z0-9-]+)*$'
export GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1

# jq の出力から CR を除く。Windows の jq.exe は改行を CRLF で出力し、$(...) は最後の改行しか除かないため、
# 比較が一致しなくなる。-b（--binary）は使わない: jq 1.6 以前は -b を受け付けず（Unknown option で終わる）、
# このリポジトリは jq の最低バージョンを決めていない。jq の出力に CR を含むデータはない（-c の JSON では CR は \r になる）。
# jq の終了コードを返す（呼び出し側は jq の失敗で判定できないとする）。
jq() {
  local -a st
  command jq "$@" | tr -d '\r'
  st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || return "${st[0]}"
  return "${st[1]}"
}

usage() {
  printf '%s\n' 'usage:' \
    '  pickup.sh status' \
    '  pickup.sh queue --writers <login,...>' \
    '  pickup.sh acquire --issue <n> --slug <slug> --session <url> --writers <login,...>' \
    '  pickup.sh release <R-1|R-2|R-3|R-4|R-5> <expected-sha>' \
    '  --writers: logins with admin, maintain or write; both the ai:ready labeler and the Issue author must be listed' >&2
}

# bad_args <detail>: 引数の誤り。何も変えずに終了コード 2 で終わる。
bad_args() {
  echo "result=invalid-args detail=$*"
  echo "pickup.sh: $*" >&2
  usage
  exit 2
}

# ---------------------------------------------------------------- ロックの読み取り（git だけ）

# remote_ref_sha <完全な ref の名前>: origin のその ref の sha を出す。名前が完全に一致する行だけを使う
# （ls-remote のパターンは名前の末尾でも一致するため。claude/1-x/refs/heads/claude/active-work など）。
# ref がなければ空を出す。ls-remote の失敗は 1、一致する行が 2 行以上は 2 を返す。
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

# fetch_exact <完全な ref の名前> <sha>: その ref を取得し、取得したコミットが sha と同じことを確かめる。
# git fetch の取得元の名前は省略形としても解決される（ref がないと refs/heads/refs/heads/... に当たりうる）ため、
# ls-remote で完全一致で読んだ sha と比べる。違えば、または取得できなければ 1 を返す。
fetch_exact() {
  local got
  git fetch --quiet --no-tags "${REMOTE}" "$1" >&2 || return 1
  got=$(git rev-parse --verify --quiet 'FETCH_HEAD^{commit}' 2>/dev/null) || return 1
  [ "${got}" = "$2" ]
}

# read_lock: ロックを読み、L_STATE（held|free|absent|unreadable|unknown）と L_* を設定する。
# 名前が LOCK_REF と完全に一致する ref がなければ absent、2 行以上か ls-remote の失敗は unknown とする。
read_lock() {
  L_STATE="unknown" L_SHA="" L_TIME="" L_ISSUE="" L_BRANCH="" L_SESSION="" L_LINE=""
  local sha time body
  sha=$(remote_ref_sha "${LOCK_REF}") || return 0
  if [ -z "${sha}" ]; then
    L_STATE="absent"
    return 0
  fi
  fetch_exact "${LOCK_REF}" "${sha}" || return 0
  time=$(git log -1 --format=%cI "${sha}" 2>/dev/null) || return 0
  body=$(git log -1 --format=%B "${sha}" 2>/dev/null) || return 0
  L_SHA="${sha}" L_TIME="${time}"
  L_LINE="${body%%$'\n'*}"
  L_LINE="${L_LINE%$'\r'}"
  if [[ "${L_LINE}" =~ ${RE_HELD} ]] && [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[3]}" ]; then
    L_STATE="held" L_ISSUE="${BASH_REMATCH[1]}" L_BRANCH="${BASH_REMATCH[2]}" L_SESSION="${BASH_REMATCH[5]}"
  elif [[ "${L_LINE}" =~ ${RE_RELEASED} ]]; then
    L_STATE="free"
  else
    L_STATE="unreadable"
  fi
}

print_lock() {
  case "${L_STATE}" in
    held) echo "state=held sha=${L_SHA} time=${L_TIME} issue=${L_ISSUE} branch=${L_BRANCH} session=${L_SESSION}" ;;
    free) echo "state=free sha=${L_SHA}" ;;
    absent) echo "state=absent" ;;
    unreadable) echo "state=unreadable sha=${L_SHA} line=${L_LINE//[[:cntrl:]]/?}" ;;
    *) echo "state=unknown" ;;
  esac
}

# make_lock_commit <message> [parent]: 空の tree と固定の作成者でロックのコミットを作り、sha を出す。
# 2 行目以降に一意な値を入れ、同じ親・同じ 1 行目の 2 つのコミットが同じ sha にならないようにする。
make_lock_commit() {
  local msg="$1" parent="${2:-}" tree nonce
  tree=$(git mktree </dev/null) || return 1
  printf -v nonce '%(%Y%m%dT%H%M%S)T-%s-%s-%s%s' -1 "${EPOCHREALTIME:-}" "$$" "${RANDOM}" "${RANDOM}"
  local args=(commit-tree "${tree}")
  [ -z "${parent}" ] || args+=(-p "${parent}")
  args+=(-m "${msg}" -m "pickup-nonce: ${nonce}")
  (
    unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
    export GIT_AUTHOR_NAME="${LOCK_NAME}" GIT_AUTHOR_EMAIL="${LOCK_EMAIL}"
    export GIT_COMMITTER_NAME="${LOCK_NAME}" GIT_COMMITTER_EMAIL="${LOCK_EMAIL}"
    git -c user.name="${LOCK_NAME}" -c user.email="${LOCK_EMAIL}" "${args[@]}"
  )
}

# push_lock <sha>: force なしで push する。終了コードと出力は判定に使わない（呼び出し側が読み直す）。
push_lock() {
  git push "${REMOTE}" "$1:${LOCK_REF}" >&2 2>&1 || true
}

# ---------------------------------------------------------------- GitHub（gh、jq）

resolve_repo() {
  local r="${GH_REPO:-}"
  if [ -z "${r}" ]; then
    r=$(git remote get-url "${REMOTE}" 2>/dev/null) || return 1
  fi
  r="${r%/}"
  r="${r%.git}"
  r="${r//:/\/}"
  local name="${r##*/}" rest="${r%/*}"
  local owner="${rest##*/}"
  REPO="${owner}/${name}"
  [[ "${REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
}

# gh_get <path>: gh api の応答（1 つの JSON）を出す。--jq は使わない（gh の --jq は jq と正規表現の方言が違うため）。
gh_get() {
  gh api "$1"
}

# gh_list <path>: --paginate で全ページを読み、配列を 1 つにまとめて出す（ページは別々の JSON として届く）。
gh_list() {
  local raw
  raw=$(gh api --paginate "$1") || return 1
  printf '%s' "${raw}" | jq -cs 'map(if type == "array" then . else [.] end) | add // []'
}

# PR の配列から、紐付く Issue 番号を 1 行ずつ出す jq（head ブランチ名 claude/<n>-* と本文のクローズキーワード #<n>）。
# 先読みは使わない。\b で #16 が #160 に一致しないようにする。
readonly JQ_PR_LINKS='.[] | ((.head.ref // "") | capture("^claude/(?<n>[0-9]+)-") | .n),
  ((.body // "") | scan("(?i)\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?[ \\t]+#([0-9]+)\\b") | .[0])
  | tonumber | tostring'

# compute_queue: 手順書 3.1 のキューを求める。ai:ready を付けた人と Issue の作成者（user.login）の両方が --writers にあることを確かめる。Q_QUEUE（順序付きの queue 行）、Q_SKIP（skip 行）、Q_HEAD を設定する。
# gh または git の失敗で判定できないときは Q_ERR を設定して 1 を返す（依存を読めないときは Issue を除外するだけ）。
# 事前に read_lock と WRITERS（小文字、前後にカンマ）を設定しておく。
compute_queue() {
  Q_QUEUE="" Q_SKIP="" Q_HEAD="none" Q_ERR=""
  resolve_repo || { Q_ERR="repo"; return 1; }

  local json issues open_links merged_links branches
  json=$(gh_list "repos/${REPO}/issues?state=open&labels=ai%3Aready&per_page=100") || { Q_ERR="issues"; return 1; }
  issues=$(jq -r '
    map(select(.pull_request == null)) | sort_by(.number) | .[]
    | (.labels | map(.name)) as $l
    | select(.state == "open" and ($l | any(. == "ai:ready")))
    | [ .number,
        (if ($l | any(. == "gate:blocked")) then "gate-blocked"
         elif ($l | any(. == "ai:blocked")) then "ai-blocked"
         elif ($l | any(. == "gate:needs-human")) then "gate-needs-human"
         elif ((.body // "") | test("AC-[0-9]{3}") | not) then "no-ac"
         else "ok" end),
        (if ($l | any(. == "priority:high")) then "0 high"
         elif ($l | any(. == "priority:medium")) then "1 medium"
         elif ($l | any(. == "priority:low")) then "2 low"
         else "3 none" end),
        (.user.login // "")
      ] | @tsv' <<< "${json}") || { Q_ERR="issues"; return 1; }
  json=$(gh_list "repos/${REPO}/pulls?state=open&per_page=100") || { Q_ERR="open-pulls"; return 1; }
  open_links=$(jq -r "${JQ_PR_LINKS}" <<< "${json}") || { Q_ERR="open-pulls"; return 1; }
  json=$(gh_list "repos/${REPO}/pulls?state=closed&base=develop&per_page=100") || { Q_ERR="merged-pulls"; return 1; }
  merged_links=$(jq -r "map(select(.merged_at != null)) | ${JQ_PR_LINKS}" <<< "${json}") || { Q_ERR="merged-pulls"; return 1; }
  branches=$(git ls-remote "${REMOTE}" 'refs/heads/claude/*' 2>/dev/null) || { Q_ERR="branches"; return 1; }
  open_links=" ${open_links//$'\n'/ } "
  merged_links=" ${merged_links//$'\n'/ } "

  local holder=""
  [ "${L_STATE}" != "held" ] || holder="$((10#${L_ISSUE}))"

  local n reason prio author rows="" skip="" line
  # author（Issue の作成者）は最後の列に置く。IFS のタブは空の列を詰めるため、空になりうる列を途中に置かない。
  while IFS=$'\t' read -r n reason prio author; do
    [ -n "${n}" ] || continue
    if [ "${n}" = "${holder}" ]; then
      skip+="skip issue=${n} reason=holder"$'\n'; continue
    fi
    if [ "${reason}" != "ok" ]; then
      skip+="skip issue=${n} reason=${reason}"$'\n'; continue
    fi

    local subs
    json=$(gh_get "repos/${REPO}/issues/${n}/sub_issues?per_page=1") \
      && subs=$(jq -r 'length' <<< "${json}") || { Q_ERR="sub-issues issue=${n}"; return 1; }
    if [ "${subs:-0}" != "0" ]; then
      skip+="skip issue=${n} reason=parent"$'\n'; continue
    fi

    # 最新の ai:ready の labeled イベント（created_at の昇順に並べた最後）。
    local ready_at actor
    json=$(gh_list "repos/${REPO}/issues/${n}/events?per_page=100") \
      && line=$(jq -r 'map(select(.event == "labeled" and .label.name == "ai:ready"))
        | sort_by(.created_at) | last // empty | "\(.created_at // "") \(.actor.login // "")"' <<< "${json}") \
      || { Q_ERR="events issue=${n}"; return 1; }
    ready_at="${line%% *}" actor="${line#* }"
    if [ -z "${line}" ] || [ -z "${ready_at}" ]; then
      skip+="skip issue=${n} reason=no-event"$'\n'; continue
    fi
    if [ -z "${actor}" ] || [ "${actor}" = "${line}" ] || [[ "${WRITERS}" != *",${actor,,},"* ]]; then
      skip+="skip issue=${n} reason=not-writer actor=${actor}"$'\n'; continue
    fi
    # Issue の作成者も write 以上であること（手順書 3.2）。ai:ready を付けた人だけでは、Claude が所有者のトークンで
    # 付けたラベルと人間が付けたラベルを区別できないため、受入基準を書いた人の権限をすべての Issue で確かめる。
    if [ -z "${author}" ] || [[ "${WRITERS}" != *",${author,,},"* ]]; then
      skip+="skip issue=${n} reason=author-not-writer author=${author}"$'\n'; continue
    fi

    if [[ "${open_links}" == *" ${n} "* ]]; then
      skip+="skip issue=${n} reason=open-pr"$'\n'; continue
    fi
    if [[ "${merged_links}" == *" ${n} "* ]]; then
      skip+="skip issue=${n} reason=merged-pr"$'\n'; continue
    fi

    local deps="" unmet="" dn dstate durl
    if ! json=$(gh_list "repos/${REPO}/issues/${n}/dependencies/blocked_by?per_page=100") \
      || ! deps=$(jq -r '.[] | "\(.number) \(.state) \(.repository_url // "")"' <<< "${json}"); then
      skip+="skip issue=${n} reason=deps-unreadable"$'\n'; continue
    fi
    while read -r dn dstate durl; do
      [ -n "${dn}" ] || continue
      [ "${dstate}" != "closed" ] || continue
      local same=1
      if [ -n "${durl}" ] && [[ "${durl,,}" != *"/repos/${REPO,,}" ]]; then same=0; fi
      if [ "${same}" -eq 1 ] && [[ "${merged_links}" == *" ${dn} "* ]]; then continue; fi
      if [ "${same}" -eq 1 ]; then unmet+="${unmet:+,}${dn}"; else unmet+="${unmet:+,}${durl##*/repos/}#${dn}"; fi
    done <<< "${deps}"
    if [ -n "${unmet}" ]; then
      skip+="skip issue=${n} reason=deps blocked_by=${unmet}"$'\n'; continue
    fi

    local br="" ref
    while read -r _ ref; do
      if [[ "${ref}" == "refs/heads/claude/${n}-"* ]]; then br="${ref#refs/heads/}"; break; fi
    done <<< "${branches}"
    if [ -n "${br}" ]; then
      skip+="skip issue=${n} reason=branch branch=${br}"$'\n'; continue
    fi

    rows+="${prio%% *}"$'\t'"${ready_at}"$'\t'"${n}"$'\t'"${prio#* }"$'\t'"${actor}"$'\n'
  done <<< "${issues}"

  # 並べ替え: priority、ai:ready の時刻、Issue 番号の順。
  local sorted
  sorted=$(printf '%s' "${rows}" | jq -rRs '
    split("\n") | map(select(length > 0) | split("\t")
      | {p: (.[0] | tonumber), t: .[1], n: (.[2] | tonumber), pn: .[3], a: .[4]})
    | sort_by(.p, .t, .n) | to_entries[]
    | "queue rank=\(.key + 1) issue=\(.value.n) priority=\(.value.pn) ready_at=\(.value.t) actor=\(.value.a)"') \
    || { Q_ERR="sort"; return 1; }
  if [ -n "${sorted}" ]; then
    Q_QUEUE="${sorted}"$'\n'
    line="${sorted%%$'\n'*}"
    line="${line#*issue=}"
    Q_HEAD="${line%% *}"
  fi
  Q_SKIP="${skip}"
}

# check_ci <develop-sha>: 手順書 3.3。CI_STATE（failed|success|pending|unknown）と CI_RUN を設定する。
# gh の失敗、または応答を読めないときは 1 を返す（呼び出し側は push しない）。
# 呼び出しが成功し、develop の先頭の実行がないときは unknown とする。
check_ci() {
  CI_STATE="unknown" CI_RUN="none"
  local json out st concl url
  json=$(gh_get "repos/${REPO}/actions/workflows/ci.yml/runs?branch=develop&head_sha=$1&per_page=1") || return 1
  out=$(jq -r '.workflow_runs[0] // empty | "\(.status // "null") \(.conclusion // "null") \(.html_url // "none")"' \
    <<< "${json}") || return 1
  [ -n "${out}" ] || return 0
  read -r st concl url <<< "${out}"
  CI_RUN="${url:-none}"
  case "${concl}" in
    failure|timed_out) CI_STATE="failed" ;;
    success) CI_STATE="success" ;;
    *) if [ "${st}" != "completed" ]; then CI_STATE="pending"; fi ;;
  esac
}

parse_writers() {
  [[ "$1" =~ ${RE_WRITERS} ]] || bad_args "--writers must be a comma-separated login list"
  WRITERS=",${1,,},"
}

# ---------------------------------------------------------------- サブコマンド

cmd_status() {
  [ $# -eq 0 ] || bad_args "status takes no arguments"
  read_lock
  print_lock
  [ "${L_STATE}" != "unknown" ] || exit 3
}

cmd_queue() {
  local writers=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --writers) [ $# -ge 2 ] || bad_args "--writers needs a value"; writers="$2"; shift ;;
      *) bad_args "unknown argument: $1" ;;
    esac
    shift
  done
  [ -n "${writers}" ] || bad_args "--writers is required"
  parse_writers "${writers}"
  read_lock
  if [ "${L_STATE}" = "unknown" ]; then
    echo "result=unknown step=lock"
    exit 3
  fi
  if ! compute_queue; then
    echo "result=unknown step=${Q_ERR}"
    exit 3
  fi
  printf '%s' "${Q_QUEUE}${Q_SKIP}"
  if [ "${Q_HEAD}" = "none" ]; then
    echo "head none"
  else
    echo "head issue=${Q_HEAD}"
  fi
}

cmd_acquire() {
  local issue="" slug="" session="" writers=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --issue|--slug|--session|--writers)
        [ $# -ge 2 ] || bad_args "$1 needs a value"
        case "$1" in
          --issue) issue="$2" ;;
          --slug) slug="$2" ;;
          --session) session="$2" ;;
          --writers) writers="$2" ;;
        esac
        shift ;;
      *) bad_args "unknown argument: $1" ;;
    esac
    shift
  done
  # 1. 引数
  [[ "${issue}" =~ ^[1-9][0-9]{0,8}$ ]] || bad_args "--issue must be a number"
  [[ "${slug}" =~ ${RE_SLUG} ]] && [ "${#slug}" -le 40 ] || bad_args "--slug must match ${RE_SLUG} and be at most 40 characters"
  [[ "${session}" =~ ^https://[^[:space:][:cntrl:]]+$ ]] || bad_args "--session must start with https:// and contain no whitespace"
  [ -n "${writers}" ] || bad_args "--writers is required"
  parse_writers "${writers}"

  # 2. ロック
  read_lock
  case "${L_STATE}" in
    free|absent) ;;
    unknown) echo "result=busy state=unknown sha=none"; exit 3 ;;
    *) echo "result=busy state=${L_STATE} sha=${L_SHA}"; exit 1 ;;
  esac
  local parent="${L_SHA}"

  # 3. キューの先頭
  if ! compute_queue; then
    echo "result=unknown step=${Q_ERR}"
    exit 3
  fi
  if [ "${Q_HEAD}" != "${issue}" ]; then
    echo "result=not-head head=${Q_HEAD}"
    exit 1
  fi

  # 4. develop の CI
  # develop の sha は名前が refs/heads/develop と完全に一致する ref から読み、取得したコミットがそれと同じことを
  # 確かめる。develop がない、2 行以上、ls-remote か fetch の失敗、取得したコミットが違うときは unknown。
  local develop
  develop=$(remote_ref_sha refs/heads/develop) && [ -n "${develop}" ] \
    && fetch_exact refs/heads/develop "${develop}" \
    || { echo "result=unknown step=develop"; exit 3; }
  if ! check_ci "${develop}"; then
    echo "result=unknown step=ci"
    exit 3
  fi
  if [ "${CI_STATE}" = "failed" ]; then
    echo "result=ci-failed issue=${issue} run=${CI_RUN}"
    exit 1
  fi

  # 5. 保持のコミットを作り、force なしで push する
  local branch="claude/${issue}-${slug}" c
  c=$(make_lock_commit "claude-active-work: issue #${issue} branch ${branch} session ${session}" "${parent}") \
    || { echo "result=unknown step=commit-tree"; exit 3; }
  push_lock "${c}"

  # 6. 読み直して判定する
  read_lock
  if [ "${L_STATE}" = "unknown" ]; then
    echo "result=unknown sha=${c}"
    exit 3
  fi
  if [ "${L_SHA}" = "${c}" ]; then
    echo "result=acquired issue=${issue} branch=${branch} sha=${c} develop=${develop} ci=${CI_STATE}"
    exit 0
  fi
  echo "result=lost sha=${L_SHA:-none}"
  exit 1
}

cmd_release() {
  [ $# -eq 2 ] || bad_args "release takes <R-1|R-2|R-3|R-4|R-5> <expected-sha>"
  local kind="$1" expected="$2"
  [[ "${kind}" =~ ^R-[1-5]$ ]] || bad_args "release reason must be R-1..R-5"
  [[ "${expected}" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || bad_args "expected-sha must be a full hex sha"

  read_lock
  if [ "${L_STATE}" = "unknown" ]; then
    echo "result=unknown"
    exit 3
  fi
  if [ "${L_STATE}" = "absent" ] || [ "${L_SHA}" != "${expected}" ]; then
    echo "result=lost sha=${L_SHA:-none}"
    exit 1
  fi
  if [ "${L_STATE}" != "held" ] && ! { [ "${kind}" = "R-5" ] && [ "${L_STATE}" = "unreadable" ]; }; then
    echo "result=refused state=${L_STATE} sha=${L_SHA}"
    exit 1
  fi

  local r
  r=$(make_lock_commit "claude-active-work: released ${kind} from ${expected}" "${expected}") \
    || { echo "result=unknown"; exit 3; }
  push_lock "${r}"

  read_lock
  if [ "${L_STATE}" = "unknown" ]; then
    echo "result=unknown"
    exit 3
  fi
  if [ "${L_SHA}" = "${r}" ]; then
    echo "result=released sha=${r} from=${expected}"
    exit 0
  fi
  echo "result=lost sha=${L_SHA:-none}"
  exit 1
}

main() {
  [ $# -ge 1 ] || bad_args "missing subcommand"
  local sub="$1"
  shift
  case "${sub}" in
    status) cmd_status "$@" ;;
    queue) cmd_queue "$@" ;;
    acquire) cmd_acquire "$@" ;;
    release) cmd_release "$@" ;;
    -h|--help) usage; exit 0 ;;
    *) bad_args "unknown subcommand: ${sub}" ;;
  esac
}

main "$@"
