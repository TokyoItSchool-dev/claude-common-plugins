#!/usr/bin/env bash
# merge-pr.sh のテスト用の偽 gh。`gh api` の GET を FIXTURE_DIR の JSON で応答し、PUT（マージ）を記録する。
# --jq は受け付けない（merge-pr.sh は gh の出力を jq に渡すため）。
# --paginate のとき <name>.p2.json があれば、2 ページ目として続けて出す（gh と同じく別々の JSON になる）。
# 呼び出しは 1 行ずつ FIXTURE_DIR/calls.log に記録する（"GET <path>"、"PUT <path> <field> ..."）。
# GET の名前: pr-<n>、reviews-<n>、files-<n>、issue-<n>、compare、check-runs、status。
#   pr-<n> は、PUT が成功した後（FIXTURE_DIR/merged がある）はマージ済みの形にして返す。
#   reviews と files は既定で []、check-runs と status は既定で空の一覧を返す。ほかは <name>.json がなければ HTTP 404。
# <name>.fail、または FIXTURE_DIR/gh.fail があれば HTTP 500 として失敗する。
# PUT repos/owner/repo/pulls/<n>/merge:
#   FIXTURE_DIR/merge.http に HTTP の状態コードがあれば、その状態で失敗する。merge.applied もあれば、
#   失敗を返す前に FIXTURE_DIR/merged を作る（GitHub の側ではマージされたが応答が失敗した形）。
#   merge.breakpr があれば、失敗を返した後の pr-<n> の読み取りを HTTP 500 で失敗させる。
#   なければ成功し、FIXTURE_DIR/merged を作る（merge.noeffect があれば作らない）。
# 知らない引数の形は終了コード 2 で失敗させ、テストで取りこぼさないようにする。
set -euo pipefail

die() { echo "fake gh: $*" >&2; exit 2; }

[ "${1:-}" = "api" ] || die "unsupported command: $*"
shift
path="" paginate="" method="GET"
fields=()
while [ $# -gt 0 ]; do
  case "$1" in
    --paginate) paginate=1 ;;
    --jq) die "--jq is not supported: pipe the output to jq" ;;
    -X) [ $# -ge 2 ] || die "-X needs a value"; method="$2"; shift ;;
    -f) [ $# -ge 2 ] || die "-f needs a value"; fields+=("$2"); shift ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "${path}" ] || die "more than one path: ${path} $1"; path="$1" ;;
  esac
  shift
done
[ -n "${path}" ] || die "missing path"
echo "${method} ${path}${fields[*]+ ${fields[*]}}" >> "${FIXTURE_DIR}/calls.log"

fail_http() {
  echo "gh: $2 (HTTP $1)" >&2
  exit 1
}

if [ "${method}" = "PUT" ]; then
  case "${path}" in
    repos/owner/repo/pulls/*/merge) ;;
    *) die "unknown PUT path: ${path}" ;;
  esac
  [ ${#fields[@]} -gt 0 ] || die "PUT without fields"
  if [ -f "${FIXTURE_DIR}/merge.http" ]; then
    [ ! -f "${FIXTURE_DIR}/merge.applied" ] || : > "${FIXTURE_DIR}/merged"
    [ ! -f "${FIXTURE_DIR}/merge.breakpr" ] || : > "${FIXTURE_DIR}/pr-${path//[^0-9]/}.fail"
    fail_http "$(cat "${FIXTURE_DIR}/merge.http")" "merge refused"
  fi
  [ -f "${FIXTURE_DIR}/merge.noeffect" ] || : > "${FIXTURE_DIR}/merged"
  echo '{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","merged":true,"message":"Pull Request successfully merged"}'
  exit 0
fi
[ "${method}" = "GET" ] || die "unsupported method: ${method}"
[ ${#fields[@]} -eq 0 ] || die "GET with fields"

default=""
case "${path}" in
  repos/owner/repo/pulls/*/reviews\?per_page=100)
    n="${path#repos/owner/repo/pulls/}"; name="reviews-${n%%/*}"; default='[]' ;;
  repos/owner/repo/pulls/*/files\?per_page=100)
    n="${path#repos/owner/repo/pulls/}"; name="files-${n%%/*}"; default='[]' ;;
  repos/owner/repo/pulls/*)
    n="${path#repos/owner/repo/pulls/}"
    [[ "${n}" =~ ^[0-9]+$ ]] || die "unknown path: ${path}"
    name="pr-${n}" ;;
  repos/owner/repo/issues/*)
    n="${path#repos/owner/repo/issues/}"
    [[ "${n}" =~ ^[0-9]+$ ]] || die "unknown path: ${path}"
    name="issue-${n}" ;;
  repos/owner/repo/compare/*...*) name=compare ;;
  repos/owner/repo/commits/*/check-runs\?per_page=100)
    name=check-runs; default='{"total_count":0,"check_runs":[]}' ;;
  repos/owner/repo/commits/*/status\?per_page=100)
    name=status; default='{"state":"pending","statuses":[]}' ;;
  *) die "unknown path: ${path}" ;;
esac

if [ -f "${FIXTURE_DIR}/gh.fail" ] || [ -f "${FIXTURE_DIR}/${name}.fail" ]; then
  fail_http 500 "Server Error"
fi
file="${FIXTURE_DIR}/${name}.json"
if [ -f "${file}" ]; then
  if [[ "${name}" == pr-* ]] && [ -f "${FIXTURE_DIR}/merged" ]; then
    jq '.state = "closed" | .merged = true | .merge_commit_sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' "${file}"
  else
    cat "${file}"
  fi
elif [ -n "${default}" ]; then
  printf '%s\n' "${default}"
else
  fail_http 404 "Not Found"
fi
if [ -n "${paginate}" ] && [ -f "${FIXTURE_DIR}/${name}.p2.json" ]; then
  cat "${FIXTURE_DIR}/${name}.p2.json"
fi
