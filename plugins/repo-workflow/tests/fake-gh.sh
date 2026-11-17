#!/usr/bin/env bash
# pickup.sh のテスト用の偽 gh（.github/scripts/tests/fake-gh.sh の方式）。`gh api` の GET を FIXTURE_DIR の JSON で応答する。
# --jq は受け付けない（pickup.sh は gh の出力を jq に渡すため。--jq の使用をテストで検出する）。応答は JSON をそのまま返す。
# --paginate のとき <name>.p2.json があれば、2 ページ目として続けて出す（gh と同じく別々の JSON になる）。
# パスから名前を決め、<name>.json を返す。なければ一覧の API は []、ci の runs は {"workflow_runs":[]} を返す。
# <name>.fail、または FIXTURE_DIR/gh.fail があれば HTTP 500 として失敗する。
# 名前: issues、pulls-open、pulls-closed、events-<n>、sub-<n>、deps-<n>、runs。
# 知らない引数の形は終了コード 2 で失敗させ、テストで取りこぼさないようにする。
set -euo pipefail

die() { echo "fake gh: $*" >&2; exit 2; }

[ "${1:-}" = "api" ] || die "unsupported command: $*"
shift
path="" paginate=""
while [ $# -gt 0 ]; do
  case "$1" in
    --paginate) paginate=1 ;;
    --jq) die "--jq is not supported: pipe the output to jq" ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "${path}" ] || die "more than one path: ${path} $1"; path="$1" ;;
  esac
  shift
done
[ -n "${path}" ] || die "missing path"
echo "GET ${path}" >> "${FIXTURE_DIR}/calls.log"

default='[]'
case "${path}" in
  repos/owner/repo/issues\?state=open\&labels=ai%3Aready\&per_page=100) name=issues ;;
  repos/owner/repo/pulls\?state=open\&per_page=100) name=pulls-open ;;
  repos/owner/repo/pulls\?state=closed\&base=develop\&per_page=100) name=pulls-closed ;;
  repos/owner/repo/issues/*/events\?per_page=100)
    n="${path#repos/owner/repo/issues/}"; name="events-${n%%/*}" ;;
  repos/owner/repo/issues/*/sub_issues\?per_page=1)
    n="${path#repos/owner/repo/issues/}"; name="sub-${n%%/*}" ;;
  repos/owner/repo/issues/*/dependencies/blocked_by\?per_page=100)
    n="${path#repos/owner/repo/issues/}"; name="deps-${n%%/*}" ;;
  repos/owner/repo/actions/workflows/ci.yml/runs\?branch=develop\&head_sha=*\&per_page=1)
    name=runs; default='{"workflow_runs":[]}' ;;
  *) die "unknown path: ${path}" ;;
esac

if [ -f "${FIXTURE_DIR}/gh.fail" ] || [ -f "${FIXTURE_DIR}/${name}.fail" ]; then
  echo "gh: Server Error (HTTP 500)" >&2
  exit 1
fi
file="${FIXTURE_DIR}/${name}.json"
if [ -f "${file}" ]; then
  cat "${file}"
else
  printf '%s\n' "${default}"
fi
if [ -n "${paginate}" ] && [ -f "${FIXTURE_DIR}/${name}.p2.json" ]; then
  cat "${FIXTURE_DIR}/${name}.p2.json"
fi
