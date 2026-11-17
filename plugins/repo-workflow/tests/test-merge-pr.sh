#!/usr/bin/env bash
# merge-pr.sh のテスト（オフライン）。ローカルの bare リポジトリを origin にし、gh は PATH 上の偽物（fake-gh-merge.sh）にする。
# 実行: bash .claude/routines/tests/test-merge-pr.sh（git と jq が必要）
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../merge-pr.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

mkdir -p "${work}/bin" "${work}/crlf-bin"
cp "${here}/fake-gh-merge.sh" "${work}/bin/gh"
chmod +x "${work}/bin/gh"
# Windows の jq.exe を模す偽の jq（run_crlf だけが使う）。本物の jq を呼び、出力の改行を CRLF にする。終了コードは保つ。
REAL_JQ="$(command -v jq)"
export REAL_JQ
cat > "${work}/crlf-bin/jq" <<'EOF'
#!/usr/bin/env bash
set -o pipefail
"${REAL_JQ}" "$@" | awk '{ printf "%s\r\n", $0 }'
EOF
chmod +x "${work}/crlf-bin/jq"
export PATH="${work}/bin:${PATH}"
export GH_REPO="owner/repo"
: > "${work}/gitconfig"
export GIT_CONFIG_GLOBAL="${work}/gitconfig" GIT_CONFIG_NOSYSTEM=1

# GATED_PATHS を埋めた写し（派生テンプレートの設定を模す）。
gated_script="${work}/merge-pr-gated.sh"
sed "s|^GATED_PATHS=()$|GATED_PATHS=('.github/*' 'package.json')|" "${script}" > "${gated_script}"
grep -q "^GATED_PATHS=('.github/\*' 'package.json')$" "${gated_script}" || { echo "FAIL setup: GATED_PATHS=() not found in merge-pr.sh"; exit 1; }

H="1111111111111111111111111111111111111111"
H2="2222222222222222222222222222222222222222"
passed=0
failed=0

tgit() {
  GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.invalid \
    GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.invalid git "$@"
}

fixture() { printf '%s\n' "$2" > "${FIXTURE_DIR}/$1.json"; }
# pr_set <jq filter>: pr-7.json を書き換える。
pr_set() {
  jq "$1" "${FIXTURE_DIR}/pr-7.json" > "${FIXTURE_DIR}/tmp.json"
  mv "${FIXTURE_DIR}/tmp.json" "${FIXTURE_DIR}/pr-7.json"
}
evidence() { echo "develop-merge-evidence: head=${1:-${H}} develop=${2:-${DEVELOP}} run-checks=PASS review=APPROVE"; }
# set_body <body>: PR 本文を置き換える。
set_body() { pr_set ".body = $(jq -Rs . <<< "$1")"; }

# new_case <name>: origin（bare、main と develop を持つ）、clone a、条件をすべて満たす fixture を用意する。
new_case() {
  CASE="$1"
  CASE_FAILED=0
  D="${work}/${CASE}"
  # origin の URL の末尾 2 要素が GH_REPO（owner/repo）と一致するようにする。
  ORIGIN="${D}/owner/repo.git"
  export FIXTURE_DIR="${D}/fx"
  mkdir -p "${FIXTURE_DIR}"
  : > "${FIXTURE_DIR}/calls.log"
  mkdir -p "${D}/owner"
  git init -q --bare "${ORIGIN}"
  tgit init -q "${D}/seed"
  tgit -C "${D}/seed" commit -q --allow-empty -m "initial"
  tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/main HEAD:refs/heads/develop
  DEVELOP="$(git --git-dir="${ORIGIN}" rev-parse refs/heads/develop)"
  git clone -q "${ORIGIN}" "${D}/a" 2>/dev/null
  jq -n --arg h "${H}" --arg body "Closes #12"$'\n\n'"$(evidence)"$'\n' '{
    number: 7, state: "open", merged: false, draft: false, mergeable: true,
    user: {login: "owner1"},
    base: {ref: "develop"}, head: {ref: "claude/12-fix-x", sha: $h, repo: {full_name: "owner/repo"}},
    labels: [{name: "work:in-progress"}], requested_reviewers: [], requested_teams: [],
    body: $body}' > "${FIXTURE_DIR}/pr-7.json"
  fixture issue-12 '{"number":12,"state":"open","labels":[{"name":"ai:ready"},{"name":"work:in-progress"}]}'
  fixture compare '{"status":"ahead","ahead_by":1,"behind_by":0}'
}

# run <args...>: merge-pr.sh を clone a で実行し、OUT と RC を設定する。
run() {
  RC=0
  OUT="$(cd "${D}/a" && bash "${SCRIPT_UNDER_TEST:-${script}}" "$@" 2>>"${D}/stderr")" || RC=$?
}
run_crlf() {
  local saved="${PATH}"
  export PATH="${work}/crlf-bin:${PATH}"
  run "$@"
  export PATH="${saved}"
}
check() { run check --pr 7 --head "${H}" --develop "${DEVELOP}"; }
merge() { run merge --pr 7 --head "${H}" --develop "${DEVELOP}"; }

fail() {
  echo "FAIL ${CASE}: $1"
  echo "  out: ${OUT:-}"
  echo "  rc: ${RC:-}"
  CASE_FAILED=1
}
expect_rc() { [ "${RC}" = "$1" ] || fail "exit code ${RC}, expected $1"; }
expect_out() { [ "${OUT}" = "$1" ] || fail "output mismatch, expected: $1"; }
expect_out_re() { [[ "${OUT}" =~ $1 ]] || fail "output does not match: $1"; }
expect_no_put() { ! grep -q '^PUT ' "${FIXTURE_DIR}/calls.log" || fail "PUT was called"; }
expect_put_once() {
  local n
  n="$(grep -c '^PUT ' "${FIXTURE_DIR}/calls.log" || true)"
  [ "${n}" = 1 ] || fail "PUT called ${n} times, expected 1"
}
done_case() {
  if [ "${CASE_FAILED}" -eq 0 ]; then
    echo "PASS ${CASE}"
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
}
# expect_stop <reason and k=v...>: check と merge の両方で同じ stop になり、PUT が呼ばれないことを確かめる。
expect_stop() {
  check; expect_rc 1; expect_out "result=stop pr=7 reason=$1"
  merge; expect_rc 1; expect_out "result=stop pr=7 reason=$1"
  expect_no_put
}

# ---------------------------------------------------------------- 成功

new_case check-ok
check; expect_rc 0; expect_out "result=ok"; expect_no_put
grep -q '^GET repos/owner/repo/issues/12$' "${FIXTURE_DIR}/calls.log" || fail "linked issue was not read"
done_case

new_case merge-ok
merge; expect_rc 0; expect_out "result=merged pr=7 merge_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
expect_put_once
grep -qx "PUT repos/owner/repo/pulls/7/merge merge_method=merge sha=${H}" "${FIXTURE_DIR}/calls.log" \
  || fail "PUT was not called with merge_method=merge and sha=H"
done_case

# check は draft を止めない（Ready にする前に確かめるため）。
new_case check-draft-ok
pr_set '.draft = true'
check; expect_rc 0; expect_out "result=ok"; done_case

# 証跡の行は前後の空白と CR を許す。
new_case check-evidence-crlf
set_body "Closes #12"$'\r\n'"  $(evidence)  "$'\r\n'
check; expect_rc 0; expect_out "result=ok"; done_case

# 人間の COMMENTED は CHANGES_REQUESTED を上書きしない。APPROVED は上書きする。
new_case check-review-superseded
fixture reviews-7 '[
  {"user":{"login":"carol"},"state":"CHANGES_REQUESTED","submitted_at":"2026-11-10T00:00:00Z"},
  {"user":{"login":"carol"},"state":"APPROVED","submitted_at":"2026-11-11T00:00:00Z"},
  {"user":{"login":"dave"},"state":"COMMENTED","submitted_at":"2026-11-11T00:00:00Z"}]'
check; expect_rc 0; expect_out "result=ok"; done_case

# DISMISSED は、同じ人のそれより前の CHANGES_REQUESTED を上書きする。
new_case check-review-dismissed
fixture reviews-7 '[
  {"user":{"login":"carol"},"state":"CHANGES_REQUESTED","submitted_at":"2026-11-10T00:00:00Z"},
  {"user":{"login":"carol"},"state":"DISMISSED","submitted_at":"2026-11-11T00:00:00Z"}]'
check; expect_rc 0; expect_out "result=ok"; done_case

# head のリポジトリの名前は大文字と小文字を区別しない（GitHub と同じ）。
new_case check-head-repo-case
pr_set '.head.repo.full_name = "Owner/Repo"'
check; expect_rc 0; expect_out "result=ok"; done_case

# GH_REPO は、origin から求めた名前と一致すれば使える（ホスト名付きと大文字を含む）。
new_case check-gh-repo-host
GH_REPO="github.com/Owner/repo" check; expect_rc 0; expect_out "result=ok"; done_case

# PR の作成者自身のレビュー（COMMENTED など）は数えない。
new_case check-author-review-ignored
fixture reviews-7 '[{"user":{"login":"owner1"},"state":"CHANGES_REQUESTED","submitted_at":"2026-11-10T00:00:00Z"}]'
check; expect_rc 0; expect_out "result=ok"; done_case

new_case check-checks-pass
fixture check-runs '{"total_count":3,"check_runs":[
  {"name":"ci","status":"completed","conclusion":"success"},
  {"name":"lint","status":"completed","conclusion":"neutral"},
  {"name":"opt","status":"completed","conclusion":"skipped"}]}'
fixture status '{"state":"success","statuses":[{"context":"ext","state":"success"}]}'
check; expect_rc 0; expect_out "result=ok"; done_case

# mergeable が null（GitHub が計算中）のときは止めない。PUT の側で GitHub が判定する。
new_case check-mergeable-null
pr_set '.mergeable = null'
check; expect_rc 0; expect_out "result=ok"; done_case

# GATED_PATHS に当てはまらない変更は止めない。
new_case check-gated-other-path
fixture files-7 '[{"filename":"src/a.sh"},{"filename":"docs/package.json"}]'
SCRIPT_UNDER_TEST="${gated_script}" check; expect_rc 0; expect_out "result=ok"; done_case

# GATED_PATHS が空（ベース）のときは、ファイルの一覧を読まない。
new_case check-gated-empty
fixture files-7 '[{"filename":".github/workflows/ci.yml"}]'
check; expect_rc 0; expect_out "result=ok"
! grep -q '/files' "${FIXTURE_DIR}/calls.log" || fail "files were read with empty GATED_PATHS"
done_case

new_case check-ok-crlf
fixture reviews-7 '[{"user":{"login":"carol"},"state":"APPROVED","submitted_at":"2026-11-11T00:00:00Z"}]'
run_crlf check --pr 7 --head "${H}" --develop "${DEVELOP}"; expect_rc 0; expect_out "result=ok"; done_case

new_case merge-ok-crlf
run_crlf merge --pr 7 --head "${H}" --develop "${DEVELOP}"
expect_rc 0; expect_out "result=merged pr=7 merge_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"; done_case

# ---------------------------------------------------------------- stop（計画の順）

new_case stop-not-open
pr_set '.state = "closed"'
expect_stop "not-open"; done_case

new_case stop-merged
pr_set '.state = "closed" | .merged = true'
expect_stop "merged"; done_case

new_case stop-base-not-develop
pr_set '.base.ref = "main"'
expect_stop "base-not-develop base=main"; done_case

new_case stop-head-is-lock
pr_set '.head.ref = "claude/active-work"'
expect_stop "head-is-lock"; done_case

# fork からの PR はマージしない（head のリポジトリが origin と違う、または削除された fork）。
new_case stop-head-from-fork
pr_set '.head.repo.full_name = "someone/repo"'
expect_stop "head-from-fork"; done_case

new_case stop-head-from-deleted-fork
pr_set '.head.repo = null'
expect_stop "head-from-fork"; done_case

new_case stop-head-moved
pr_set ".head.sha = \"${H2}\""
expect_stop "head-moved actual=${H2}"; done_case

new_case stop-develop-moved
tgit -C "${D}/seed" commit -q --allow-empty -m "next"
tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/develop
expect_stop "develop-moved actual=$(git --git-dir="${ORIGIN}" rev-parse refs/heads/develop)"; done_case

new_case stop-develop-missing
git --git-dir="${ORIGIN}" update-ref -d refs/heads/develop
expect_stop "develop-moved actual=none"; done_case

new_case stop-not-up-to-date
fixture compare '{"status":"diverged","ahead_by":1,"behind_by":2}'
expect_stop "not-up-to-date behind_by=2"; done_case

new_case stop-draft
pr_set '.draft = true'
merge; expect_rc 1; expect_out "result=stop pr=7 reason=draft"; expect_no_put; done_case

new_case stop-label-gate-blocked-pr
pr_set '.labels += [{name: "gate:blocked"}]'
expect_stop "label-gate-blocked on=pr"; done_case

new_case stop-label-gate-blocked-issue
fixture issue-12 '{"number":12,"labels":[{"name":"gate:blocked"}]}'
expect_stop "label-gate-blocked on=issue-12"; done_case

new_case stop-label-ai-blocked-pr
pr_set '.labels += [{name: "ai:blocked"}]'
expect_stop "label-ai-blocked on=pr"; done_case

new_case stop-label-ai-blocked-issue
fixture issue-12 '{"number":12,"labels":[{"name":"ai:blocked"}]}'
expect_stop "label-ai-blocked on=issue-12"; done_case

new_case stop-label-needs-human-pr
pr_set '.labels += [{name: "gate:needs-human"}]'
expect_stop "label-needs-human on=pr"; done_case

new_case stop-label-needs-human-issue
fixture issue-12 '{"number":12,"labels":[{"name":"gate:needs-human"}]}'
expect_stop "label-needs-human on=issue-12"; done_case

# gate:blocked は ai:blocked と gate:needs-human より先に判定する（PR と Issue をまたいでも）。
new_case stop-label-order
pr_set '.labels += [{name: "gate:needs-human"}, {name: "ai:blocked"}]'
fixture issue-12 '{"number":12,"labels":[{"name":"gate:blocked"}]}'
expect_stop "label-gate-blocked on=issue-12"; done_case

# 本文のクローズキーワードで紐付く Issue（head ブランチ名と別の番号）も見る。#16 は #160 に一致しない。
new_case stop-label-issue-from-body
pr_set '.head.ref = "feature/x"'
set_body "fixes #16"$'\n'"see #160"$'\n'"$(evidence)"
fixture issue-16 '{"number":16,"labels":[{"name":"ai:blocked"}]}'
fixture issue-160 '{"number":160,"labels":[{"name":"gate:blocked"}]}'
expect_stop "label-ai-blocked on=issue-16"
! grep -q 'issues/160' "${FIXTURE_DIR}/calls.log" || fail "issue 160 was read"
done_case

new_case stop-label-issue-from-branch
set_body "$(evidence)"
fixture issue-12 '{"number":12,"labels":[{"name":"gate:needs-human"}]}'
expect_stop "label-needs-human on=issue-12"; done_case

new_case stop-review-requested
pr_set '.requested_reviewers = [{login: "carol"}]'
expect_stop "review-requested"; done_case

new_case stop-review-requested-team
pr_set '.requested_teams = [{slug: "core"}]'
expect_stop "review-requested"; done_case

new_case stop-changes-requested
fixture reviews-7 '[
  {"user":{"login":"carol"},"state":"APPROVED","submitted_at":"2026-11-10T00:00:00Z"},
  {"user":{"login":"carol"},"state":"COMMENTED","submitted_at":"2026-11-12T00:00:00Z"},
  {"user":{"login":"carol"},"state":"CHANGES_REQUESTED","submitted_at":"2026-11-11T00:00:00Z"}]'
expect_stop "changes-requested reviewer=carol"; done_case

new_case stop-changes-requested-page2
fixture reviews-7 '[{"user":{"login":"carol"},"state":"APPROVED","submitted_at":"2026-11-10T00:00:00Z"}]'
fixture reviews-7.p2 '[{"user":{"login":"dave"},"state":"CHANGES_REQUESTED","submitted_at":"2026-11-11T00:00:00Z"}]'
expect_stop "changes-requested reviewer=dave"; done_case

new_case stop-check-failed
fixture check-runs '{"total_count":2,"check_runs":[
  {"name":"ok","status":"completed","conclusion":"success"},
  {"name":"CI windows","status":"completed","conclusion":"failure"}]}'
expect_stop "check-failed name=CI windows"; done_case

new_case stop-check-cancelled
fixture check-runs '{"total_count":1,"check_runs":[{"name":"ci","status":"completed","conclusion":"cancelled"}]}'
expect_stop "check-failed name=ci"; done_case

new_case stop-check-failed-page2
fixture check-runs '{"total_count":2,"check_runs":[{"name":"a","status":"completed","conclusion":"success"}]}'
fixture check-runs.p2 '{"total_count":2,"check_runs":[{"name":"b","status":"completed","conclusion":"timed_out"}]}'
expect_stop "check-failed name=b"; done_case

new_case stop-status-failed
fixture status '{"state":"failure","statuses":[{"context":"ext/ci","state":"error"}]}'
expect_stop "check-failed name=ext/ci"; done_case

# 失敗は実行中より先に判定する。
new_case stop-check-pending
fixture check-runs '{"total_count":1,"check_runs":[{"name":"ci","status":"in_progress","conclusion":null}]}'
expect_stop "check-pending name=ci"; done_case

new_case stop-status-pending
fixture status '{"state":"pending","statuses":[{"context":"ext","state":"pending"}]}'
expect_stop "check-pending name=ext"; done_case

new_case stop-check-failed-before-pending
fixture check-runs '{"total_count":1,"check_runs":[{"name":"ci","status":"queued","conclusion":null}]}'
fixture status '{"state":"failure","statuses":[{"context":"ext","state":"failure"}]}'
expect_stop "check-failed name=ext"; done_case

new_case stop-mergeable-false
pr_set '.mergeable = false'
expect_stop "mergeable-false"; done_case

new_case stop-evidence-missing
set_body "Closes #12"
expect_stop "evidence-missing"; done_case

new_case stop-evidence-other-head
set_body "Closes #12"$'\n'"$(evidence "${H2}")"
expect_stop "evidence-missing"; done_case

new_case stop-evidence-other-develop
set_body "Closes #12"$'\n'"$(evidence "${H}" "${H2}")"
expect_stop "evidence-missing"; done_case

new_case stop-evidence-not-pass
set_body "Closes #12"$'\n'"develop-merge-evidence: head=${H} develop=${DEVELOP} run-checks=FAIL review=APPROVE"
expect_stop "evidence-missing"; done_case

# 行の一部に含まれるだけでは証跡としない。
new_case stop-evidence-inline
set_body "Closes #12"$'\n'"note: $(evidence)"
expect_stop "evidence-missing"; done_case

new_case stop-gated-path
fixture files-7 '[{"filename":"src/a.sh"},{"filename":".github/workflows/ci.yml"}]'
SCRIPT_UNDER_TEST="${gated_script}" expect_stop "gated-path path=.github/workflows/ci.yml"; done_case

# 名前を変えたファイルは、元の名前も確かめる。
new_case stop-gated-path-renamed
fixture files-7 '[{"filename":"pkg.json","previous_filename":"package.json","status":"renamed"}]'
SCRIPT_UNDER_TEST="${gated_script}" expect_stop "gated-path path=package.json"; done_case

# 順序: 先の理由が出る（ラベルとレビューと証跡がすべて欠けていても base-not-develop）。
new_case stop-order-first-wins
pr_set '.base.ref = "main" | .labels += [{name: "gate:blocked"}] | .mergeable = false | .body = ""'
expect_stop "base-not-develop base=main"; done_case

# ---------------------------------------------------------------- マージの結果

new_case merge-refused-409
echo 409 > "${FIXTURE_DIR}/merge.http"
merge; expect_rc 1; expect_out "result=stop pr=7 reason=merge-refused http=409"; expect_put_once; done_case

new_case merge-refused-405
echo 405 > "${FIXTURE_DIR}/merge.http"
merge; expect_rc 1; expect_out "result=stop pr=7 reason=merge-refused http=405"; expect_put_once; done_case

new_case merge-unknown-422
echo 422 > "${FIXTURE_DIR}/merge.http"
merge; expect_rc 3; expect_out "result=unknown step=merge"; expect_put_once; done_case

new_case merge-unknown-500
echo 500 > "${FIXTURE_DIR}/merge.http"
merge; expect_rc 3; expect_out "result=unknown step=merge"; expect_put_once; done_case

# PUT が 405 / 409 以外で失敗したが、GitHub の側ではマージされていた（応答が届かなかったなど）。
# PR を 1 回読み直し、マージ済みなら result=merged とする。PUT はやり直さない。
new_case merge-failed-but-merged
echo 502 > "${FIXTURE_DIR}/merge.http"
: > "${FIXTURE_DIR}/merge.applied"
merge; expect_rc 0; expect_out "result=merged pr=7 merge_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"; expect_put_once
[ "$(grep -c '^GET repos/owner/repo/pulls/7$' "${FIXTURE_DIR}/calls.log")" = 2 ] || fail "PR was not read again after the failed PUT"
done_case

# 405 / 409 は読み直さない（GitHub がマージを拒否した）。
new_case merge-refused-no-reread
echo 409 > "${FIXTURE_DIR}/merge.http"
merge; expect_rc 1; expect_out "result=stop pr=7 reason=merge-refused http=409"
[ "$(grep -c '^GET repos/owner/repo/pulls/7$' "${FIXTURE_DIR}/calls.log")" = 1 ] || fail "PR was read again after 409"
done_case

# 読み直しも失敗したときは unknown step=merge のままにする。
new_case merge-failed-reread-failed
echo 500 > "${FIXTURE_DIR}/merge.http"
: > "${FIXTURE_DIR}/merge.breakpr"
merge; expect_rc 3; expect_out "result=unknown step=merge"; expect_put_once; done_case

# PUT は成功したが、読み直した PR がマージ済みでない。
new_case merge-unknown-verify
: > "${FIXTURE_DIR}/merge.noeffect"
merge; expect_rc 3; expect_out "result=unknown step=verify"; expect_put_once; done_case

# ---------------------------------------------------------------- unknown（読み取りの失敗）

for name in pr-7 issue-12 compare reviews-7 check-runs status; do
  new_case "unknown-${name}"
  : > "${FIXTURE_DIR}/${name}.fail"
  case "${name}" in
    pr-7) step=pr ;;
    issue-12) step="issue issue=12" ;;
    reviews-7) step=reviews ;;
    *) step="${name}" ;;
  esac
  check; expect_rc 3; expect_out "result=unknown step=${step}"
  merge; expect_rc 3; expect_out "result=unknown step=${step}"; expect_no_put
  done_case
done

new_case unknown-files
fixture files-7 '[]'
: > "${FIXTURE_DIR}/files-7.fail"
SCRIPT_UNDER_TEST="${gated_script}" check; expect_rc 3; expect_out "result=unknown step=files"; done_case

# 紐付く Issue が見つからない（404）ときも判定できないとする。
new_case unknown-issue-missing
rm "${FIXTURE_DIR}/issue-12.json"
check; expect_rc 3; expect_out "result=unknown step=issue issue=12"; done_case

new_case unknown-develop
git -C "${D}/a" remote set-url origin "${D}/missing/owner/repo.git"
check; expect_rc 3; expect_out "result=unknown step=develop"; expect_no_put; done_case

new_case unknown-pr-parse
printf 'not json\n' > "${FIXTURE_DIR}/pr-7.json"
check; expect_rc 3; expect_out "result=unknown step=pr"; done_case

new_case unknown-pr-parse-crlf
printf 'not json\n' > "${FIXTURE_DIR}/pr-7.json"
run_crlf check --pr 7 --head "${H}" --develop "${DEVELOP}"; expect_rc 3; expect_out "result=unknown step=pr"; done_case

# ---------------------------------------------------------------- リポジトリの名前

# GH_REPO が origin から求めた名前と違うときは、何も読まずに止める。
new_case unknown-gh-repo-mismatch
GH_REPO="other/repo" check; expect_rc 3; expect_out "result=unknown step=repo-mismatch"
[ ! -s "${FIXTURE_DIR}/calls.log" ] || fail "gh was called with a mismatched GH_REPO"
done_case

# GH_REPO がないときは origin の URL の末尾 2 要素を使う（ssh、https、ssh://、セッションのプロキシの形）。
# URL はつながらないため、PR を読んだ後の develop の読み取りで unknown になる。PR を owner/repo で読んだことを確かめる。
for url in "git@github.com:owner/repo.git" "https://github.com/owner/repo.git" "https://github.com/owner/repo/" \
  "ssh://git@github.com/owner/repo.git" "http://local_proxy@127.0.0.1:34567/git/owner/repo"; do
  url_no=$((${url_no:-0} + 1))
  new_case "resolve-repo-${url_no}"
  git -C "${D}/a" remote set-url origin "${url}"
  OUT="" RC=0
  OUT="$(cd "${D}/a" && env -u GH_REPO bash "${script}" check --pr 7 --head "${H}" --develop "${DEVELOP}" 2>>"${D}/stderr")" || RC=$?
  expect_rc 3; expect_out "result=unknown step=develop"
  [ "$(head -n 1 "${FIXTURE_DIR}/calls.log")" = "GET repos/owner/repo/pulls/7" ] || fail "PR was not read from owner/repo"
  done_case
done

# ---------------------------------------------------------------- 引数

new_case bad-args
for args in "" "check" "push --pr 7 --head ${H} --develop ${DEVELOP}" \
  "check --pr 07 --head ${H} --develop ${DEVELOP}" "check --pr x --head ${H} --develop ${DEVELOP}" \
  "check --pr 7 --head ${H:0:7} --develop ${DEVELOP}" "check --pr 7 --head ${H} --develop ABC" \
  "check --pr 7 --head ${H}" "check --pr 7 --head ${H} --develop ${DEVELOP} --extra 1" \
  "check --pr 7 --head ${DEVELOP^^} --develop ${DEVELOP}" "check --pr 7 --head ${H} --develop"; do
  # shellcheck disable=SC2086
  run ${args}
  [ "${RC}" = 2 ] || fail "args '${args}': exit code ${RC}, expected 2"
  [[ "${OUT}" == "result=invalid-args detail="* ]] || fail "args '${args}': output ${OUT}"
done
[ ! -s "${FIXTURE_DIR}/calls.log" ] || fail "gh was called for invalid args"
done_case

echo "passed: ${passed}, failed: ${failed}"
[ "${failed}" -eq 0 ]
