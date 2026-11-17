#!/usr/bin/env bash
# pickup.sh のテスト（オフライン）。ローカルの bare リポジトリを origin にし、gh は PATH 上の偽物（fake-gh.sh）にする。
# 実行: bash plugins/repo-workflow/tests/test-pickup.sh（git と jq が必要）
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pickup="${here}/../scripts/pickup.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

mkdir -p "${work}/bin" "${work}/crlf-bin"
cp "${here}/fake-gh.sh" "${work}/bin/gh"
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
# 利用者の git の設定を使わない（pickup.sh が作成者の設定なしで動くことも確かめる）。
: > "${work}/gitconfig"
export GIT_CONFIG_GLOBAL="${work}/gitconfig" GIT_CONFIG_NOSYSTEM=1
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_AUTHOR_DATE GIT_COMMITTER_DATE

EMPTY_TREE="$(git hash-object -t tree /dev/null)"
LOCK_REF="refs/heads/claude/active-work"
SESSION="https://claude.ai/code/session_test"
WRITERS="alice,bob"
AC_BODY=$'## 受入基準\n- [ ] AC-001: something'
passed=0
failed=0

# テスト側の git 操作（作成者を固定する）。
tgit() {
  GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.invalid \
    GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.invalid git "$@"
}

# new_case <name>: origin（bare、main と develop を持つ）、clone a、空の fixture を用意する。
new_case() {
  CASE="$1"
  CASE_FAILED=0
  D="${work}/${CASE}"
  ORIGIN="${D}/origin.git"
  export FIXTURE_DIR="${D}/fx"
  mkdir -p "${FIXTURE_DIR}"
  git init -q --bare "${ORIGIN}"
  tgit init -q "${D}/seed"
  tgit -C "${D}/seed" commit -q --allow-empty -m "initial"
  tgit -C "${D}/seed" push -q "${ORIGIN}" HEAD:refs/heads/main HEAD:refs/heads/develop
  DEVELOP="$(git --git-dir="${ORIGIN}" rev-parse refs/heads/develop)"
  git clone -q "${ORIGIN}" "${D}/a" 2>/dev/null
  echo '[]' > "${FIXTURE_DIR}/issues.json"
  runs_success
}

# lock_commit <message> [parent]: origin に空の tree のコミットを作り、sha を出す（ref は変えない）。
lock_commit() {
  local args=(commit-tree "${EMPTY_TREE}")
  [ -z "${2:-}" ] || args+=(-p "$2")
  tgit --git-dir="${ORIGIN}" "${args[@]}" -m "$1"
}
set_lock() { git --git-dir="${ORIGIN}" update-ref "${LOCK_REF}" "$1"; }
lock_sha() { git --git-dir="${ORIGIN}" rev-parse -q --verify "${LOCK_REF}" || echo none; }
held_msg() { echo "claude-active-work: issue #$1 branch claude/$1-$2 session ${3:-${SESSION}/$1}"; }
# set_held <issue> <slug> / set_free / set_unreadable: 先頭をその形のコミットにする（親は現在の先頭）。
set_held() { local p; p="$(lock_sha)"; [ "${p}" != none ] || p=""; set_lock "$(lock_commit "$(held_msg "$1" "$2")" "${p}")"; }
set_free() {
  local h; h="$(lock_commit "$(held_msg 7 old)")"
  set_lock "$(lock_commit "claude-active-work: released R-1 from ${h}" "${h}")"
}
set_unreadable() { set_lock "$(lock_commit "${1:-lock taken by hand}")"; }
msg_line1() { git --git-dir="${ORIGIN}" log -1 --format=%B "$1" | head -n 1; }
parents() { git --git-dir="${ORIGIN}" log -1 --format=%P "$1"; }

# add_issue <n> <labels, comma separated> [body] [author]: issues.json に Open の ai:ready の Issue を加える。
# 作成者（user.login）の既定は alice。author に空文字を渡すと user を持たない Issue にする。
add_issue() {
  local body="${3-${AC_BODY}}" author="${4-alice}"
  jq --argjson n "$1" --arg labels "ai:ready${2:+,$2}" --arg body "${body}" --arg author "${author}" \
    '. += [{number: $n, state: "open", body: $body, labels: ($labels | split(",") | map({name: .}))}
      + (if $author == "" then {} else {user: {login: $author}} end)]' \
    "${FIXTURE_DIR}/issues.json" > "${FIXTURE_DIR}/tmp.json"
  mv "${FIXTURE_DIR}/tmp.json" "${FIXTURE_DIR}/issues.json"
}
# add_event <n> <login> <time> [label]: events-<n>.json に labeled イベントを加える。
add_event() {
  local f="${FIXTURE_DIR}/events-$1.json"
  [ -f "${f}" ] || echo '[]' > "${f}"
  jq --arg a "$2" --arg t "$3" --arg l "${4:-ai:ready}" \
    '. += [{event: "labeled", actor: {login: $a}, created_at: $t, label: {name: $l}}]' "${f}" > "${f}.tmp"
  mv "${f}.tmp" "${f}"
}
fixture() { printf '%s\n' "$2" > "${FIXTURE_DIR}/$1.json"; }
runs_success() { fixture runs '{"workflow_runs":[{"status":"completed","conclusion":"success","html_url":"https://example.invalid/run/1"}]}'; }
# ready_issue <n>: キューに入る Issue（priority:high、alice が付けた ai:ready）を加える。
ready_issue() { add_issue "$1" "priority:high"; add_event "$1" alice "2026-11-10T00:00:0${2:-0}Z"; }

# run <clone dir> <args...>: pickup.sh を実行し、OUT と RC を設定する。
run() {
  local d="$1"
  shift
  RC=0
  OUT="$(cd "${d}" && bash "${pickup}" "$@" 2>>"${D}/stderr")" || RC=$?
}

# run_crlf <clone dir> <args...>: 偽の jq（CRLF で出力する）を PATH の先頭に置いて run する。
run_crlf() {
  local saved="${PATH}"
  export PATH="${work}/crlf-bin:${PATH}"
  run "$@"
  export PATH="${saved}"
}

fail() {
  echo "FAIL ${CASE}: $1"
  echo "  out: ${OUT:-}"
  echo "  rc: ${RC:-}"
  CASE_FAILED=1
}
expect_rc() { [ "${RC}" = "$1" ] || fail "exit code ${RC}, expected $1"; }
expect_out() { [ "${OUT}" = "$1" ] || fail "output mismatch, expected: $1"; }
expect_out_re() { [[ "${OUT}" =~ $1 ]] || fail "output does not match: $1"; }
expect_lock() { [ "$(lock_sha)" = "$1" ] || fail "lock ref is $(lock_sha), expected $1"; }
done_case() {
  if [ "${CASE_FAILED}" -eq 0 ]; then
    echo "PASS ${CASE}"
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
}
field() { local k; for k in ${OUT}; do [[ "${k}" != "$1="* ]] || { echo "${k#*=}"; return; }; done; }

# install_hook <clone> <script body>: clone に pre-push hook を置く（競合の再現に使う）。
install_hook() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$1/.git/hooks/pre-push"
  chmod +x "$1/.git/hooks/pre-push"
}
# push_then_fail_hook <clone>: hook が自分で origin の ref を更新してから失敗を返す（push は失敗と表示されるが ref は進む）。
push_then_fail_hook() {
  install_hook "$1" "while read -r _ sha _ _; do git cat-file commit \"\${sha}\" | git --git-dir='${ORIGIN}' hash-object -t commit -w --stdin >/dev/null; git --git-dir='${ORIGIN}' update-ref '${LOCK_REF}' \"\${sha}\"; done; touch '${D}/hook-failed-push'; exit 1"
}
# barrier_hook <clone> <me> <other> <dir>: 両方の実行が push の直前に来るまで待つ hook。
barrier_hook() {
  install_hook "$1" "cat >/dev/null; touch '$4/$2'; for i in \$(seq 1 200); do [ -f '$4/$3' ] && exit 0; sleep 0.02; done; exit 0"
}

# ---------------------------------------------------------------- status

new_case status-absent
run "${D}/a" status; expect_rc 0; expect_out "state=absent"; done_case

new_case status-free
set_free; run "${D}/a" status; expect_rc 0; expect_out "state=free sha=$(lock_sha)"; done_case

new_case status-held
set_held 9 fix-lock
run "${D}/a" status; expect_rc 0
expect_out "state=held sha=$(lock_sha) time=$(git --git-dir="${ORIGIN}" log -1 --format=%cI "$(lock_sha)") issue=9 branch=claude/9-fix-lock session=${SESSION}/9"
done_case

new_case status-unreadable
set_unreadable "lock taken by hand"
run "${D}/a" status; expect_rc 0; expect_out "state=unreadable sha=$(lock_sha) line=lock taken by hand"; done_case

new_case status-unreadable-number-mismatch
set_unreadable "claude-active-work: issue #9 branch claude/8-x session ${SESSION}"
run "${D}/a" status; expect_rc 0; expect_out_re "^state=unreadable "; done_case

new_case status-unreadable-control-chars
set_unreadable $'bad\tline\rend'
run "${D}/a" status; expect_rc 0; expect_out "state=unreadable sha=$(lock_sha) line=bad?line?end"; done_case

new_case status-unknown
git -C "${D}/a" remote set-url origin "${D}/missing.git"
run "${D}/a" status; expect_rc 3; expect_out "state=unknown"; done_case

# ls-remote のパターンは名前の末尾でも一致する。名前の末尾が refs/heads/claude/active-work のブランチ（偽のロック）は
# ロックとして読まない。
DECOY_LOCK_REF="refs/heads/claude/1-x/refs/heads/claude/active-work"
new_case status-decoy-lock-absent
git --git-dir="${ORIGIN}" update-ref "${DECOY_LOCK_REF}" "$(lock_commit "$(held_msg 7 decoy)")"
run "${D}/a" status; expect_rc 0; expect_out "state=absent"; done_case

new_case status-decoy-lock-free
set_free
git --git-dir="${ORIGIN}" update-ref "${DECOY_LOCK_REF}" "$(lock_commit "$(held_msg 7 decoy)")"
run "${D}/a" status; expect_rc 0; expect_out "state=free sha=$(lock_sha)"; done_case

# 偽のロックを解放の形にし、本物のロックを保持にする。本物のロックを読む。
new_case status-decoy-lock-held
set_held 9 fix-lock
git --git-dir="${ORIGIN}" update-ref "${DECOY_LOCK_REF}" "$(lock_commit "claude-active-work: released R-1 from $(lock_sha)")"
run "${D}/a" status; expect_rc 0
expect_out "state=held sha=$(lock_sha) time=$(git --git-dir="${ORIGIN}" log -1 --format=%cI "$(lock_sha)") issue=9 branch=claude/9-fix-lock session=${SESSION}/9"
done_case

new_case acquire-decoy-lock
ready_issue 9
git --git-dir="${ORIGIN}" update-ref "${DECOY_LOCK_REF}" "$(lock_commit "$(held_msg 7 decoy)")"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out_re "^result=acquired issue=9 branch=claude/9-fix-lock sha=$(lock_sha) "
done_case

new_case status-extra-arg
run "${D}/a" status extra; expect_rc 2; done_case

# ---------------------------------------------------------------- acquire

new_case acquire-absent
ready_issue 9
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0
C="$(lock_sha)"
expect_out "result=acquired issue=9 branch=claude/9-fix-lock sha=${C} develop=${DEVELOP} ci=success"
[ -z "$(parents "${C}")" ] || fail "acquire from absent has a parent"
[ "$(git --git-dir="${ORIGIN}" log -1 --format=%T "${C}")" = "${EMPTY_TREE}" ] || fail "tree is not empty"
[ "$(git --git-dir="${ORIGIN}" log -1 --format='%an <%ae> %cn <%ce>' "${C}")" = \
  "claude-active-work <claude-active-work@example.invalid> claude-active-work <claude-active-work@example.invalid>" ] \
  || fail "author is not fixed"
[ "$(msg_line1 "${C}")" = "claude-active-work: issue #9 branch claude/9-fix-lock session ${SESSION}" ] || fail "message line 1"
run "${D}/a" status; expect_out_re "^state=held sha=${C} time=[^ ]+ issue=9 branch=claude/9-fix-lock session=${SESSION}$"
done_case

new_case acquire-free
ready_issue 9; set_free; P="$(lock_sha)"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out_re "^result=acquired issue=9 "
[ "$(parents "$(lock_sha)")" = "${P}" ] || fail "parent is not the free commit"
done_case

new_case acquire-slug-40
ready_issue 9
run "${D}/a" acquire --issue 9 --slug "$(printf 'a%.0s' $(seq 1 40))" --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out_re "^result=acquired "; done_case

new_case acquire-held
ready_issue 9; set_held 5 other; H="$(lock_sha)"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=busy state=held sha=${H}"; expect_lock "${H}"; done_case

# 2026-11-10 の事故: 先頭が Issue 9 の保持のときに Issue 9 で取得しようとした。
new_case acquire-incident-held-same-issue
ready_issue 9; set_held 9 fix-lock "${SESSION}/run-a"; H="$(lock_sha)"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}/run-b" --writers "${WRITERS}"
expect_rc 1; expect_out "result=busy state=held sha=${H}"; expect_lock "${H}"
[ ! -f "${FIXTURE_DIR}/calls.log" ] || fail "gh was called while the lock was held"
done_case

new_case acquire-unreadable
ready_issue 9; set_unreadable; H="$(lock_sha)"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=busy state=unreadable sha=${H}"; expect_lock "${H}"; done_case

new_case acquire-unknown
ready_issue 9; set_free; H="$(lock_sha)"
git -C "${D}/a" remote set-url origin "${D}/missing.git"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 3; expect_out "result=busy state=unknown sha=none"; expect_lock "${H}"; done_case

new_case acquire-not-head
ready_issue 9; add_issue 1 "priority:low"; add_event 1 alice 2026-11-09T00:00:00Z
run "${D}/a" acquire --issue 1 --slug first --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=not-head head=9"; expect_lock none; done_case

new_case acquire-empty-queue
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=not-head head=none"; expect_lock none; done_case

new_case acquire-ci-failed
ready_issue 9
fixture runs '{"workflow_runs":[{"status":"completed","conclusion":"failure","html_url":"https://example.invalid/run/2"}]}'
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=ci-failed issue=9 run=https://example.invalid/run/2"; expect_lock none
grep -q "head_sha=${DEVELOP}&" "${FIXTURE_DIR}/calls.log" || fail "CI was not checked for the develop head"
done_case

new_case acquire-ci-timed-out
ready_issue 9; set_free; H="$(lock_sha)"
fixture runs '{"workflow_runs":[{"status":"completed","conclusion":"timed_out","html_url":"https://example.invalid/run/3"}]}'
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=ci-failed issue=9 run=https://example.invalid/run/3"; expect_lock "${H}"; done_case

new_case acquire-ci-pending
ready_issue 9
fixture runs '{"workflow_runs":[{"status":"in_progress","conclusion":null,"html_url":"https://example.invalid/run/4"}]}'
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out_re " ci=pending$"; done_case

new_case acquire-ci-no-run
ready_issue 9; fixture runs '{"workflow_runs":[]}'
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out_re " ci=unknown$"; done_case

new_case acquire-ci-gh-failure
ready_issue 9; set_free; H="$(lock_sha)"; : > "${FIXTURE_DIR}/runs.fail"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 3; expect_out "result=unknown step=ci"; expect_lock "${H}"; done_case

new_case acquire-gh-failure
ready_issue 9; set_free; H="$(lock_sha)"; : > "${FIXTURE_DIR}/gh.fail"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 3; expect_out "result=unknown step=issues"; expect_lock "${H}"; done_case

new_case acquire-gh-events-failure
ready_issue 9; : > "${FIXTURE_DIR}/events-9.fail"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 3; expect_out "result=unknown step=events issue=9"; expect_lock none; done_case

# push が失敗を返しても、読み直した先頭が自分のコミットなら取得とする。
new_case acquire-push-error-but-ref-updated
ready_issue 9
push_then_fail_hook "${D}/a"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
[ -f "${D}/hook-failed-push" ] || fail "the pre-push hook did not run"
expect_rc 0; expect_out "result=acquired issue=9 branch=claude/9-fix-lock sha=$(lock_sha) develop=${DEVELOP} ci=success"
done_case

# 読んだ後に他の実行が先に取得した: push は拒否され、lost になる。
new_case acquire-lost
ready_issue 9; set_free; P="$(lock_sha)"
OTHER="$(lock_commit "$(held_msg 9 fix-lock "${SESSION}/other")" "${P}")"
install_hook "${D}/a" "cat >/dev/null; git --git-dir='${ORIGIN}' update-ref '${LOCK_REF}' '${OTHER}'"
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=lost sha=${OTHER}"; expect_lock "${OTHER}"; done_case

# 引数の誤り: 終了コード 2、ref も gh も使わない。
bad_acquire() {
  new_case "acquire-bad-args-$1"
  shift
  ready_issue 9; set_free; H="$(lock_sha)"
  run "${D}/a" acquire "$@"
  expect_rc 2; expect_out_re "^result=invalid-args "; expect_lock "${H}"
  [ ! -f "${FIXTURE_DIR}/calls.log" ] || fail "gh was called"
  done_case
}
bad_acquire issue-not-number --issue abc --slug x --session "${SESSION}" --writers a
bad_acquire issue-zero --issue 0 --slug x --session "${SESSION}" --writers a
bad_acquire slug-uppercase --issue 9 --slug Fix --session "${SESSION}" --writers a
bad_acquire slug-double-hyphen --issue 9 --slug a--b --session "${SESSION}" --writers a
bad_acquire slug-leading-hyphen --issue 9 --slug -a --session "${SESSION}" --writers a
bad_acquire slug-41 --issue 9 --slug "$(printf 'a%.0s' $(seq 1 41))" --session "${SESSION}" --writers a
bad_acquire slug-empty --issue 9 --slug "" --session "${SESSION}" --writers a
bad_acquire session-space --issue 9 --slug x --session "https://example.invalid/a b" --writers a
bad_acquire session-http --issue 9 --slug x --session "http://example.invalid/s" --writers a
bad_acquire writers-missing --issue 9 --slug x --session "${SESSION}"
bad_acquire writers-space --issue 9 --slug x --session "${SESSION}" --writers "a b"
bad_acquire unknown-option --issue 9 --slug x --session "${SESSION}" --writers a --force
bad_acquire missing-value --issue 9 --slug x --session "${SESSION}" --writers

new_case bad-subcommand
run "${D}/a" lock; expect_rc 2; run "${D}/a"; expect_rc 2; done_case

# 2 つの clone から同時に取得する（5 回）。両方が同じ先頭を読んでから push するよう、pre-push hook で待ち合わせる。
new_case acquire-concurrent
ready_issue 9
git clone -q "${ORIGIN}" "${D}/b" 2>/dev/null
git clone -q "${ORIGIN}" "${D}/c" 2>/dev/null
for round in 1 2 3 4 5; do
  B="${D}/barrier-${round}"; mkdir -p "${B}"
  barrier_hook "${D}/a" a b "${B}"
  barrier_hook "${D}/b" b a "${B}"
  P="$(lock_sha)"
  rca=0; rcb=0
  (cd "${D}/a" && bash "${pickup}" acquire --issue 9 --slug fix-lock --session "${SESSION}/a${round}" --writers "${WRITERS}" > "${B}/out-a" 2>>"${D}/stderr") & pa=$!
  (cd "${D}/b" && bash "${pickup}" acquire --issue 9 --slug fix-lock --session "${SESSION}/b${round}" --writers "${WRITERS}" > "${B}/out-b" 2>>"${D}/stderr") & pb=$!
  wait "${pa}" || rca=$?
  wait "${pb}" || rcb=$?
  OUT="$(cat "${B}/out-a" "${B}/out-b")"; RC="${rca}/${rcb}"
  n_acq="$(grep -c '^result=acquired ' <<< "${OUT}" || true)"
  n_lost="$(grep -c '^result=lost ' <<< "${OUT}" || true)"
  [ "${n_acq}" = 1 ] && [ "${n_lost}" = 1 ] || fail "round ${round}: expected one acquired and one lost"
  W="$(lock_sha)"
  grep -q "^result=acquired .* sha=${W} " <<< "${OUT}" || fail "round ${round}: the ref is not the winner's commit"
  [ "$(parents "${W}")" = "$( [ "${P}" = none ] || echo "${P}")" ] || fail "round ${round}: winner's parent is not the read head"
  # 次の回のために、hook のない clone で解放する。
  run "${D}/c" release R-3 "${W}"; [ "${RC}" = 0 ] || fail "round ${round}: release failed"
done
# 保持のコミットの親が保持のコミットになっていない。
for sha in $(git --git-dir="${ORIGIN}" rev-list "${LOCK_REF}"); do
  for p in $(parents "${sha}"); do
    if [[ "$(msg_line1 "${sha}")" == "claude-active-work: issue #"* ]] && [[ "$(msg_line1 "${p}")" == "claude-active-work: issue #"* ]]; then
      fail "held commit ${sha} has a held parent ${p}"
    fi
  done
done
done_case

# ---------------------------------------------------------------- queue

new_case queue-order-and-exclusions
add_issue 1 "priority:low";      add_event 1 alice 2026-11-10T01:00:00Z
add_issue 2 "priority:high"
add_event 2 alice 2026-11-10T00:00:00Z; add_event 2 bob 2026-11-10T03:00:00Z
add_event 2 alice 2026-11-10T05:00:00Z priority:high
add_issue 3 "priority:high";     add_event 3 bob 2026-11-10T02:00:00Z
add_issue 4 "priority:high";     add_event 4 Alice 2026-11-10T02:00:00Z
add_issue 5 "";                  add_event 5 alice 2026-11-10T01:30:00Z
add_issue 6 "priority:medium";   add_event 6 alice 2026-11-10T04:00:00Z
add_issue 10 "priority:high" "no acceptance criteria"; add_event 10 alice 2026-11-10T00:00:00Z
add_issue 11 "gate:blocked";     add_event 11 alice 2026-11-10T00:00:00Z
add_issue 12 "ai:blocked";       add_event 12 alice 2026-11-10T00:00:00Z
add_issue 13 "gate:needs-human"; add_event 13 alice 2026-11-10T00:00:00Z
add_issue 14 "";                 add_event 14 alice 2026-11-10T00:00:00Z
fixture sub-14 '[{"number": 40}]'
add_issue 15 "";                 add_event 15 alice 2026-11-10T00:00:00Z
git --git-dir="${ORIGIN}" update-ref refs/heads/claude/15-foo "${DEVELOP}"
git --git-dir="${ORIGIN}" update-ref refs/heads/claude/150-bar "${DEVELOP}"
add_issue 16 "";                 add_event 16 alice 2026-11-10T00:00:00Z
add_issue 17 "";                 add_event 17 alice 2026-11-10T00:00:00Z
fixture pulls-open '[{"number": 100, "head": {"ref": "feature/x"}, "body": "Closes #16"},
  {"number": 101, "head": {"ref": "claude/300-y"}, "body": "fixes #0301"}]'
fixture pulls-closed '[{"number": 102, "head": {"ref": "claude/17-x"}, "body": "", "merged_at": "2026-11-09T00:00:00Z"},
  {"number": 103, "head": {"ref": "feature/y"}, "body": "Closes #1", "merged_at": null}]'
add_issue 18 "";                 add_event 18 alice 2026-11-10T00:00:00Z
fixture deps-18 '[{"number": 2, "state": "open", "repository_url": "https://api.github.com/repos/owner/repo"}]'
add_issue 19 "";                 add_event 19 alice 2026-11-10T00:00:00Z
: > "${FIXTURE_DIR}/deps-19.fail"
add_issue 20 "";                 add_event 20 alice 2026-11-10T00:00:00Z priority:low
add_issue 21 "";                 add_event 21 mallory 2026-11-10T00:00:00Z
add_issue 22 "work:in-progress"; add_event 22 alice 2026-11-10T00:00:00Z
set_held 22 holder
git --git-dir="${ORIGIN}" update-ref refs/heads/claude/22-holder "${DEVELOP}"
add_issue 23 "priority:medium";  add_event 23 alice 2026-11-10T05:00:00Z
fixture deps-23 '[{"number": 17, "state": "open", "repository_url": "https://api.github.com/repos/owner/repo"},
  {"number": 99, "state": "closed", "repository_url": "https://api.github.com/repos/owner/repo"}]'
add_issue 24 "";                 add_event 24 alice 2026-11-10T00:00:00Z
fixture deps-24 '[{"number": 5, "state": "open", "repository_url": "https://api.github.com/repos/other/repo"}]'
jq '. += [{"number": 25, "state": "open", "body": "AC-001", "labels": [{"name": "ai:ready"}], "pull_request": {"url": "x"}}]' \
  "${FIXTURE_DIR}/issues.json" > "${FIXTURE_DIR}/tmp.json" && mv "${FIXTURE_DIR}/tmp.json" "${FIXTURE_DIR}/issues.json"
run "${D}/a" queue --writers "${WRITERS}"
expect_rc 0
expect_out "queue rank=1 issue=3 priority=high ready_at=2026-11-10T02:00:00Z actor=bob
queue rank=2 issue=4 priority=high ready_at=2026-11-10T02:00:00Z actor=Alice
queue rank=3 issue=2 priority=high ready_at=2026-11-10T03:00:00Z actor=bob
queue rank=4 issue=6 priority=medium ready_at=2026-11-10T04:00:00Z actor=alice
queue rank=5 issue=23 priority=medium ready_at=2026-11-10T05:00:00Z actor=alice
queue rank=6 issue=1 priority=low ready_at=2026-11-10T01:00:00Z actor=alice
queue rank=7 issue=5 priority=none ready_at=2026-11-10T01:30:00Z actor=alice
skip issue=10 reason=no-ac
skip issue=11 reason=gate-blocked
skip issue=12 reason=ai-blocked
skip issue=13 reason=gate-needs-human
skip issue=14 reason=parent
skip issue=15 reason=branch branch=claude/15-foo
skip issue=16 reason=open-pr
skip issue=17 reason=merged-pr
skip issue=18 reason=deps blocked_by=2
skip issue=19 reason=deps-unreadable
skip issue=20 reason=no-event
skip issue=21 reason=not-writer actor=mallory
skip issue=22 reason=holder
skip issue=24 reason=deps blocked_by=other/repo#5
head issue=3"
done_case

# 回帰: PR 本文の #16 の判定が #160 や #1600 に一致しない（正規表現は jq の実体で評価する。偽の gh は --jq を拒否する）。
# 2 ページ目の PR とイベントも読む（--paginate で別々の JSON として届く）。
new_case queue-pr-link-word-boundary
add_issue 16 "priority:high"; add_event 16 alice 2026-11-10T00:00:00Z
add_issue 160 "priority:high"; add_event 160 alice 2026-11-10T00:00:00Z
printf '%s\n' '[{"number": 7, "state": "open", "body": "x", "labels": [{"name": "ai:ready"}]}]' > "${FIXTURE_DIR}/issues.p2.json"
printf '%s\n' '[{"event": "labeled", "actor": {"login": "bob"}, "created_at": "2026-11-10T06:00:00Z", "label": {"name": "ai:ready"}}]' \
  > "${FIXTURE_DIR}/events-160.p2.json"
fixture pulls-open '[{"number": 100, "head": {"ref": "feature/a"}, "body": "Closes #16"}]'
printf '%s\n' '[{"number": 101, "head": {"ref": "feature/b"}, "body": "Closes #1600"},
  {"number": 102, "head": {"ref": "feature/c"}, "body": "xCloses #160 and fixes #16abc"}]' > "${FIXTURE_DIR}/pulls-open.p2.json"
run "${D}/a" queue --writers "${WRITERS}"
expect_rc 0
expect_out "queue rank=1 issue=160 priority=high ready_at=2026-11-10T06:00:00Z actor=bob
skip issue=7 reason=no-ac
skip issue=16 reason=open-pr
head issue=160"
done_case

new_case queue-empty
run "${D}/a" queue --writers "${WRITERS}"; expect_rc 0; expect_out "head none"; done_case

new_case queue-gh-failure
ready_issue 9; : > "${FIXTURE_DIR}/pulls-open.fail"
run "${D}/a" queue --writers "${WRITERS}"; expect_rc 3; expect_out "result=unknown step=open-pulls"; done_case

new_case queue-lock-unknown
ready_issue 9; git -C "${D}/a" remote set-url origin "${D}/missing.git"
run "${D}/a" queue --writers "${WRITERS}"; expect_rc 3; expect_out "result=unknown step=lock"; done_case

new_case queue-bad-args
run "${D}/a" queue; expect_rc 2; run "${D}/a" queue --writers "a;b"; expect_rc 2; done_case

# 回帰: Windows の jq.exe は出力の改行を CRLF にする。$(...) は最後の改行しか除かないため、複数行の出力の各行に CR が残り、
# キューの比較が一致しなくなっていた。偽の jq で CRLF を再現し、結果が LF の jq と同じになることを確かめる。
new_case queue-crlf-jq
add_issue 1 "priority:low";    add_event 1 alice 2026-11-10T01:00:00Z
add_issue 2 "priority:high";   add_event 2 alice 2026-11-10T00:00:00Z; add_event 2 bob 2026-11-10T03:00:00Z
add_issue 3 "priority:medium"; add_event 3 bob 2026-11-10T02:00:00Z
add_issue 4 "";                add_event 4 alice 2026-11-10T00:00:00Z
fixture deps-4 '[{"number": 99, "state": "closed", "repository_url": "https://api.github.com/repos/owner/repo"},
  {"number": 5, "state": "open", "repository_url": "https://api.github.com/repos/owner/repo"}]'
add_issue 5 "";                add_event 5 alice 2026-11-10T00:00:00Z
add_issue 6 "";                add_event 6 alice 2026-11-10T00:00:00Z
add_issue 8 "" "no acceptance criteria"; add_event 8 alice 2026-11-10T00:00:00Z
add_issue 9 "";                add_event 9 mallory 2026-11-10T00:00:00Z
fixture pulls-open '[{"number": 100, "head": {"ref": "feature/a"}, "body": "Closes #6"},
  {"number": 101, "head": {"ref": "feature/b"}, "body": "Closes #7"}]'
fixture pulls-closed '[{"number": 102, "head": {"ref": "claude/5-x"}, "body": "", "merged_at": "2026-11-09T00:00:00Z"},
  {"number": 103, "head": {"ref": "claude/30-y"}, "body": "", "merged_at": "2026-11-09T00:00:00Z"}]'
run_crlf "${D}/a" queue --writers "${WRITERS}"
expect_rc 0
expect_out "queue rank=1 issue=2 priority=high ready_at=2026-11-10T03:00:00Z actor=bob
queue rank=2 issue=3 priority=medium ready_at=2026-11-10T02:00:00Z actor=bob
queue rank=3 issue=1 priority=low ready_at=2026-11-10T01:00:00Z actor=alice
queue rank=4 issue=4 priority=none ready_at=2026-11-10T00:00:00Z actor=alice
skip issue=5 reason=merged-pr
skip issue=6 reason=open-pr
skip issue=8 reason=no-ac
skip issue=9 reason=not-writer actor=mallory
head issue=2"
[[ "${OUT}" != *$'\r'* ]] || fail "output contains CR"
run_crlf "${D}/a" acquire --issue 2 --slug crlf --session "${SESSION}" --writers "${WRITERS}"
expect_rc 0; expect_out "result=acquired issue=2 branch=claude/2-crlf sha=$(lock_sha) develop=${DEVELOP} ci=success"
done_case

# Issue の作成者の権限（手順書 3.1、3.2）: ai:ready を付けた人が write 以上でも、作成者が write 以上でなければ着手しない。
# 理由の順序は not-writer（付けた人）の後。作成者を読めない Issue も除く。
new_case queue-author-not-writer
add_issue 1 "priority:high" "${AC_BODY}" mallory; add_event 1 alice 2026-11-10T00:00:00Z
add_issue 2 "priority:high" "${AC_BODY}" "";      add_event 2 alice 2026-11-10T00:00:00Z
add_issue 3 "priority:high" "${AC_BODY}" mallory; add_event 3 mallory 2026-11-10T00:00:00Z
add_issue 4 "priority:high" "${AC_BODY}" Bob;     add_event 4 alice 2026-11-10T01:00:00Z
add_issue 5 "priority:high" "${AC_BODY}" mallory
add_issue 6 "priority:high" "no acceptance criteria" mallory; add_event 6 alice 2026-11-10T00:00:00Z
run "${D}/a" queue --writers "${WRITERS}"
expect_rc 0
expect_out "queue rank=1 issue=4 priority=high ready_at=2026-11-10T01:00:00Z actor=alice
skip issue=1 reason=author-not-writer author=mallory
skip issue=2 reason=author-not-writer author=
skip issue=3 reason=not-writer actor=mallory
skip issue=5 reason=no-event
skip issue=6 reason=no-ac
head issue=4"
done_case

new_case queue-author-not-writer-crlf
add_issue 1 "priority:high" "${AC_BODY}" mallory; add_event 1 alice 2026-11-10T00:00:00Z
add_issue 2 "priority:high" "${AC_BODY}" "";      add_event 2 alice 2026-11-10T00:00:00Z
add_issue 3 "priority:high" "${AC_BODY}" mallory; add_event 3 mallory 2026-11-10T00:00:00Z
add_issue 4 "priority:high" "${AC_BODY}" Bob;     add_event 4 alice 2026-11-10T01:00:00Z
run_crlf "${D}/a" queue --writers "${WRITERS}"
expect_rc 0
expect_out "queue rank=1 issue=4 priority=high ready_at=2026-11-10T01:00:00Z actor=alice
skip issue=1 reason=author-not-writer author=mallory
skip issue=2 reason=author-not-writer author=
skip issue=3 reason=not-writer actor=mallory
head issue=4"
[[ "${OUT}" != *$'\r'* ]] || fail "output contains CR"
done_case

# acquire もキューの判定を使う: 作成者が write 以上でない Issue では取得しない。
new_case acquire-author-not-writer
add_issue 9 "priority:high" "${AC_BODY}" mallory; add_event 9 alice 2026-11-10T00:00:00Z
run "${D}/a" acquire --issue 9 --slug fix-lock --session "${SESSION}" --writers "${WRITERS}"
expect_rc 1; expect_out "result=not-head head=none"; expect_lock none; done_case

# CR を除いても jq の終了コードは保つ（JSON を読めないときは判定できない）。
new_case queue-crlf-jq-parse-error
ready_issue 9; fixture pulls-open 'not json'
run_crlf "${D}/a" queue --writers "${WRITERS}"; expect_rc 3; expect_out "result=unknown step=open-pulls"; done_case

# ---------------------------------------------------------------- release

new_case release-match
set_held 9 fix-lock; H="$(lock_sha)"
run "${D}/a" release R-1 "${H}"
expect_rc 0; R="$(lock_sha)"; expect_out "result=released sha=${R} from=${H}"
[ "$(parents "${R}")" = "${H}" ] || fail "release parent is not H"
[ "$(msg_line1 "${R}")" = "claude-active-work: released R-1 from ${H}" ] || fail "release message line 1"
[ "$(git --git-dir="${ORIGIN}" log -1 --format='%T %an' "${R}")" = "${EMPTY_TREE} claude-active-work" ] || fail "release tree or author"
run "${D}/a" status; expect_out "state=free sha=${R}"
done_case

new_case release-mismatch
set_held 9 fix-lock; H="$(lock_sha)"; OLD="$(lock_commit "$(held_msg 9 fix-lock "${SESSION}/old")")"
run "${D}/a" release R-1 "${OLD}"; expect_rc 1; expect_out "result=lost sha=${H}"; expect_lock "${H}"; done_case

new_case release-free-refused
set_free; H="$(lock_sha)"
run "${D}/a" release R-4 "${H}"; expect_rc 1; expect_out "result=refused state=free sha=${H}"; expect_lock "${H}"; done_case

new_case release-unreadable-refused
set_unreadable; H="$(lock_sha)"
run "${D}/a" release R-4 "${H}"; expect_rc 1; expect_out "result=refused state=unreadable sha=${H}"; expect_lock "${H}"; done_case

new_case release-r5-unreadable
set_unreadable; H="$(lock_sha)"
run "${D}/a" release R-5 "${H}"; expect_rc 0; expect_out "result=released sha=$(lock_sha) from=${H}"
[ "$(parents "$(lock_sha)")" = "${H}" ] || fail "release parent is not H"
done_case

new_case release-absent
run "${D}/a" release R-1 "$(git --git-dir="${ORIGIN}" rev-parse refs/heads/develop)"
expect_rc 1; expect_out "result=lost sha=none"; expect_lock none; done_case

new_case release-unknown
set_held 9 fix-lock; H="$(lock_sha)"; git -C "${D}/a" remote set-url origin "${D}/missing.git"
run "${D}/a" release R-1 "${H}"; expect_rc 3; expect_out "result=unknown"; expect_lock "${H}"; done_case

new_case release-push-error-but-ref-updated
set_held 9 fix-lock; H="$(lock_sha)"
push_then_fail_hook "${D}/a"
run "${D}/a" release R-2 "${H}"; expect_rc 0; expect_out "result=released sha=$(lock_sha) from=${H}"
[ -f "${D}/hook-failed-push" ] || fail "the pre-push hook did not run"
done_case

new_case release-bad-args
set_held 9 fix-lock; H="$(lock_sha)"
run "${D}/a" release R-6 "${H}"; expect_rc 2
run "${D}/a" release R-1 "${H:0:7}"; expect_rc 2
run "${D}/a" release R-1; expect_rc 2
run "${D}/a" release R-1 "${H}" extra; expect_rc 2
expect_lock "${H}"; done_case

# 同じ H に対する 2 つの解放の競合（5 回）: released は毎回 1 つだけ。
new_case release-concurrent
git clone -q "${ORIGIN}" "${D}/b" 2>/dev/null
for round in 1 2 3 4 5; do
  set_held 9 fix-lock; H="$(lock_sha)"
  B="${D}/barrier-${round}"; mkdir -p "${B}"
  barrier_hook "${D}/a" a b "${B}"
  barrier_hook "${D}/b" b a "${B}"
  rca=0; rcb=0
  (cd "${D}/a" && bash "${pickup}" release R-1 "${H}" > "${B}/out-a" 2>>"${D}/stderr") & pa=$!
  (cd "${D}/b" && bash "${pickup}" release R-1 "${H}" > "${B}/out-b" 2>>"${D}/stderr") & pb=$!
  wait "${pa}" || rca=$?
  wait "${pb}" || rcb=$?
  OUT="$(cat "${B}/out-a" "${B}/out-b")"; RC="${rca}/${rcb}"
  [ "$(grep -c '^result=released ' <<< "${OUT}" || true)" = 1 ] || fail "round ${round}: expected exactly one released"
  [ "$(grep -c '^result=lost ' <<< "${OUT}" || true)" = 1 ] || fail "round ${round}: expected one lost"
  [ "$(parents "$(lock_sha)")" = "${H}" ] || fail "round ${round}: ref is not a release of H"
done
done_case

echo "passed: ${passed}, failed: ${failed}"
[ "${failed}" -eq 0 ]
