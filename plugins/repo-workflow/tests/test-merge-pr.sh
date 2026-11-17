#!/usr/bin/env bash
# merge-pr.sh のテスト（オフライン）。ローカルの bare リポジトリを origin にし、gh は PATH 上の偽物（fake-gh-merge.sh）にする。
# 止める変更のパス（gated_paths）は、origin の main の .claude/repo-workflow.json に置く（main_config）。
# 実行: bash plugins/repo-workflow/tests/test-merge-pr.sh（git と jq が必要）
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../scripts/merge-pr.sh"
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

# 設定ファイルの例（派生テンプレートの gated_paths を模す）。
readonly PLUGIN_SHA="0123456789abcdef0123456789abcdef01234567"
config_json() { jq -cn --arg s "${PLUGIN_SHA}" --argjson g "$1" '{plugin_sha: $s, gated_paths: $g, pre_check_commands: []}'; }
readonly GATED_EXAMPLE='[".github/*", "package.json"]'
# gas の gated_paths（claude-dev-template-gas の GATED_PATHS）。
readonly GATED_GAS='["app/src/appsscript.json"]'
# kintone の gated_paths（kintone-ai-dev-template の GATED_PATHS）。
readonly GATED_KINTONE='[".mcp.json", "config/policy.json", "config/project.json", "config/schema/*", "approvals/*",
  ".github/workflows/deploy-*.yml", ".github/workflows/plan-staging.yml", ".github/workflows/e2e-staging.yml",
  ".github/workflows/security.yml", ".claude/settings.json", ".claude/routines/merge-pr.sh",
  ".claude/rules/kintone-deployment.md", ".claude/rules/kintone-security.md",
  "packages/kintone-core/src/auth.ts", "packages/kintone-core/src/write-client.ts",
  "packages/kintone-settings/src/guard.ts", "packages/kintone-settings/src/apply.ts",
  "packages/kintone-settings/src/plan.ts", "packages/kintone-settings/src/approval.ts",
  "packages/kintone-settings/src/git.ts", ".npmrc", "*/.npmrc", "npm-shrinkwrap.json", "*/npm-shrinkwrap.json",
  "package.json", "*/package.json", "package-lock.json", "*/package-lock.json"]'

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
# main と develop は、gated_paths が空の設定ファイル（.claude/repo-workflow.json）を持つ。
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
  mkdir -p "${D}/seed/.claude"
  config_json '[]' > "${D}/seed/.claude/repo-workflow.json"
  tgit -C "${D}/seed" add .claude/repo-workflow.json
  tgit -C "${D}/seed" commit -q -m "initial"
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

# main_raw <content>: origin の main に、設定ファイルをこの内容にしたコミットを足す（develop は動かさない）。
# clone a の origin/main は古いままになる（merge-pr.sh が main の先頭を読むことを確かめる）。
main_raw() {
  printf '%s\n' "$1" > "${D}/seed/.claude/repo-workflow.json"
  tgit -C "${D}/seed" add .claude/repo-workflow.json
  tgit -C "${D}/seed" commit -q --allow-empty -m "config"
  tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/main
}
# main_config <gated_paths の JSON>: origin の main の gated_paths を変える。
main_config() { main_raw "$(config_json "$1")"; }

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

# gated_paths に当てはまらない変更は止めない。
new_case check-gated-other-path
main_config "${GATED_EXAMPLE}"
fixture files-7 '[{"filename":"src/a.sh"},{"filename":"docs/package.json"}]'
check; expect_rc 0; expect_out "result=ok"; done_case

# gated_paths が空（ベース）のときは、ファイルの一覧を読まない。
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

# 名前の末尾が refs/heads/develop のブランチを develop として読まない（develop-moved にしない）。
new_case check-develop-decoy-branch
tgit -C "${D}/seed" commit -q --allow-empty -m "decoy"
tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/claude/1-x/refs/heads/develop
[ "$(git -C "${D}/a" ls-remote origin refs/heads/develop | head -n 1 | cut -f 2)" = "refs/heads/claude/1-x/refs/heads/develop" ] \
  || fail "setup: the decoy branch is not listed first"
check; expect_rc 0; expect_out "result=ok"; done_case

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
main_config "${GATED_EXAMPLE}"
fixture files-7 '[{"filename":"src/a.sh"},{"filename":".github/workflows/ci.yml"}]'
expect_stop "gated-path path=.github/workflows/ci.yml"; done_case

# 名前を変えたファイルは、元の名前も確かめる。
new_case stop-gated-path-renamed
main_config "${GATED_EXAMPLE}"
fixture files-7 '[{"filename":"pkg.json","previous_filename":"package.json","status":"renamed"}]'
expect_stop "gated-path path=package.json"; done_case

# 順序: 先の理由が出る（ラベルとレビューと証跡がすべて欠けていても base-not-develop）。
new_case stop-order-first-wins
pr_set '.base.ref = "main" | .labels += [{name: "gate:blocked"}] | .mergeable = false | .body = ""'
expect_stop "base-not-develop base=main"; done_case

# ---------------------------------------------------------------- 設定ファイル（gated_paths）

# gated_paths が空の設定（ベース）は、ほかの止める変更のパスを持たない（.github/ と package.json も止めない）。
new_case check-config-empty-gated
fixture files-7 '[{"filename":".github/workflows/ci.yml"},{"filename":"package.json"},{"filename":".claude/repo-workflow.json"}]'
check; expect_rc 0; expect_out "result=ok"
merge; expect_rc 0; expect_out "result=merged pr=7 merge_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"; done_case

# gas の gated_paths（Apps Script のマニフェスト。gas の .claude/rules/repository-workflow.md 8.1）。
new_case stop-gas-appsscript
main_config "${GATED_GAS}"
fixture files-7 '[{"filename":"app/src/core/a.js"},{"filename":"app/src/appsscript.json"}]'
expect_stop "gated-path path=app/src/appsscript.json"; done_case

# マニフェストから名前を変えたファイルも止める。
new_case stop-gas-appsscript-renamed
main_config "${GATED_GAS}"
fixture files-7 '[{"filename":"app/src/appsscript.old.json","previous_filename":"app/src/appsscript.json","status":"renamed"}]'
expect_stop "gated-path path=app/src/appsscript.json"; done_case

# マニフェストに当たらない変更は止めない（似た名前を含む）。
new_case check-gas-other-paths
main_config "${GATED_GAS}"
fixture files-7 '[{"filename":"app/src/web.js"},{"filename":"app/src/core/appsscript.json"},
  {"filename":"appsscript.json"},{"filename":"docs/app/src/appsscript.json"},{"filename":"app/src/appsscript.json.bak"},
  {"filename":".github/workflows/ci.yml"},{"filename":"package.json"}]'
check; expect_rc 0; expect_out "result=ok"
grep -q '/files' "${FIXTURE_DIR}/calls.log" || fail "files were not read with the gas gated_paths"
done_case

# kintone の gated_paths（kintone の人間ゲート。kintone の .claude/rules/repository-workflow.md 8.1）。
for p in .mcp.json config/policy.json config/project.json config/schema/policy.schema.json \
  config/schema/settings/fields.schema.json approvals/staging/abc.json .github/workflows/deploy-staging.yml \
  .github/workflows/deploy-production.yml .github/workflows/plan-staging.yml .github/workflows/e2e-staging.yml \
  .github/workflows/security.yml .claude/settings.json .claude/routines/merge-pr.sh .claude/rules/kintone-deployment.md \
  .claude/rules/kintone-security.md package.json package-lock.json packages/kintone-core/package.json \
  packages/kintone-settings/package-lock.json packages/kintone-core/src/auth.ts \
  packages/kintone-core/src/write-client.ts packages/kintone-settings/src/guard.ts \
  packages/kintone-settings/src/apply.ts packages/kintone-settings/src/plan.ts \
  packages/kintone-settings/src/approval.ts packages/kintone-settings/src/git.ts .npmrc packages/kintone-core/.npmrc \
  npm-shrinkwrap.json packages/kintone-core/npm-shrinkwrap.json; do
  kintone_no=$((${kintone_no:-0} + 1))
  new_case "stop-kintone-gated-${kintone_no}"
  main_config "${GATED_KINTONE}"
  fixture files-7 "$(jq -cn --arg p "${p}" '[{"filename":"src/a.ts"},{"filename":$p}]')"
  expect_stop "gated-path path=${p}"; done_case
done

# kintone のゲートのパスから名前を変えたファイルも止める。
new_case stop-kintone-gated-renamed
main_config "${GATED_KINTONE}"
fixture files-7 '[{"filename":"config/policy.old.json","previous_filename":"config/policy.json","status":"renamed"}]'
expect_stop "gated-path path=config/policy.json"; done_case

# kintone のゲートに当たらない変更は止めない（ゲートのパスと似た名前を含む）。
new_case check-kintone-other-paths
main_config "${GATED_KINTONE}"
fixture files-7 '[{"filename":"apps/sample/src/desktop/index.ts"},{"filename":".github/workflows/ci.yml"},
  {"filename":".claude/rules/kintone-events.md"},{"filename":"config/environments/staging.example.json"},
  {"filename":"tests/fixtures/project/.mcp.json"},{"filename":"docs/config/policy.json"},
  {"filename":".claude/settings.local.json"},{"filename":"CLAUDE.md"},
  {"filename":"packages/kintone-settings/src/diff.ts"},{"filename":"packages/kintone-settings/tests/plan.test.ts"}]'
check; expect_rc 0; expect_out "result=ok"
grep -q '/files' "${FIXTURE_DIR}/calls.log" || fail "files were not read with the kintone gated_paths"
done_case

# PR のブランチ（と作業ツリー）の設定ファイルは読まない。main が gated_paths を持てば、PR が設定ファイルで
# gated_paths を空にしても止まる。
new_case stop-config-pr-branch-ignored
main_config "${GATED_GAS}"
git -C "${D}/a" fetch -q origin
tgit -C "${D}/a" checkout -q -b claude/12-fix-x origin/main
config_json '[]' > "${D}/a/.claude/repo-workflow.json"
tgit -C "${D}/a" commit -q -am "empty gated_paths"
tgit -C "${D}/a" push -q origin HEAD:refs/heads/claude/12-fix-x
fixture files-7 '[{"filename":".claude/repo-workflow.json"},{"filename":"app/src/appsscript.json"}]'
expect_stop "gated-path path=app/src/appsscript.json"; done_case

# 逆に、PR のブランチが gated_paths を足しても、main が空なら止めない。
new_case check-config-pr-branch-added-ignored
tgit -C "${D}/a" checkout -q -b claude/12-fix-x origin/main
config_json "${GATED_GAS}" > "${D}/a/.claude/repo-workflow.json"
tgit -C "${D}/a" commit -q -am "add gated_paths"
fixture files-7 '[{"filename":".claude/repo-workflow.json"},{"filename":"app/src/appsscript.json"}]'
check; expect_rc 0; expect_out "result=ok"; done_case

# 手元の origin/main が古くても、origin の main の先頭の設定を読む。
new_case stop-config-stale-local-main
old_main="$(git -C "${D}/a" rev-parse origin/main)"
main_config "${GATED_GAS}"
fixture files-7 '[{"filename":"app/src/appsscript.json"}]'
expect_stop "gated-path path=app/src/appsscript.json"
[ "$(git -C "${D}/a" rev-parse origin/main)" != "${old_main}" ] || fail "origin/main was not fetched"
done_case

# main の設定ファイルがない（作業ツリーにあっても読まない）。
new_case stop-config-missing
git -C "${D}/seed" rm -q .claude/repo-workflow.json
tgit -C "${D}/seed" commit -q -m "remove config"
tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/main
mkdir -p "${D}/a/.claude"
config_json '[]' > "${D}/a/.claude/repo-workflow.json"
expect_stop "config-missing"; done_case

# origin に main がない（main を読めないものとして扱う）。
new_case unknown-config-no-main
git --git-dir="${ORIGIN}" update-ref -d refs/heads/main
check; expect_rc 3; expect_out "result=unknown step=config"
merge; expect_rc 3; expect_out "result=unknown step=config"; expect_no_put; done_case

# ls-remote のパターンは名前の末尾でも一致する。名前が refs/heads/main と完全に一致する ref だけを main とする。
# claude/1-x/refs/heads/main のブランチ（並びで main より前に来る）が gated_paths を空にしていても止まる。
new_case stop-config-decoy-main-branch
main_config "${GATED_GAS}"
tgit -C "${D}/seed" checkout -q -b decoy
config_json '[]' > "${D}/seed/.claude/repo-workflow.json"
tgit -C "${D}/seed" commit -q -am "decoy"
tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/claude/1-x/refs/heads/main
[ "$(git -C "${D}/a" ls-remote origin refs/heads/main | head -n 1 | cut -f 2)" = "refs/heads/claude/1-x/refs/heads/main" ] \
  || fail "setup: the decoy branch is not listed first"
fixture files-7 '[{"filename":"app/src/appsscript.json"}]'
expect_stop "gated-path path=app/src/appsscript.json"; done_case

# 形が正しくない設定ファイル。
for bad in 'not json' '' '[]' '{"plugin_sha":"0123456789abcdef0123456789abcdef01234567"}' \
  '{"gated_paths":"app/src/appsscript.json"}' '{"gated_paths":[1]}' '{"gated_paths":[null]}' \
  '{"gated_paths":[""]}' '{"gated_paths":["a\nb"]}' '{"gated_paths":[]} {"gated_paths":[]}' '{"gated_paths":null}'; do
  bad_no=$((${bad_no:-0} + 1))
  new_case "stop-config-invalid-${bad_no}"
  main_raw "${bad}"
  expect_stop "config-invalid"; done_case
done

# 設定ファイルが正しくないときは、gated_paths に当たる変更がなくても止める（先の理由があればそれが出る）。
new_case stop-config-invalid-before-ok
main_raw '{"gated_paths":{}}'
fixture files-7 '[{"filename":"src/a.sh"}]'
expect_stop "config-invalid"; done_case

new_case stop-config-invalid-after-evidence
main_raw 'not json'
set_body "Closes #12"
expect_stop "evidence-missing"; done_case

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
main_config "${GATED_EXAMPLE}"
fixture files-7 '[]'
: > "${FIXTURE_DIR}/files-7.fail"
check; expect_rc 3; expect_out "result=unknown step=files"; done_case

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
