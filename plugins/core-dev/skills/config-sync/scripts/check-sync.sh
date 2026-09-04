#!/usr/bin/env bash
# Report drift between the three config roots, driven by references/sync-map.tsv.
# Exit 1 if any mirror pair differs or is missing.

HOME_ROOT="${CONFIG_SYNC_HOME:-$HOME/.claude}"
TPS_ROOT="${CONFIG_SYNC_TPS:-/c/git/training-project-skills}"
CCP_ROOT="${CONFIG_SYNC_CCP:-/c/git/claude-common-plugins}"
MAP="$(dirname "$0")/../references/sync-map.tsv"

[ -f "$MAP" ] || { echo "sync map not found: $MAP" >&2; exit 2; }

fail=0
hp=(); tp=(); cp=()

compare() { # $1=src $2=dst $3=class -> prints status, returns 1 if mirror drift
  local a=$1 b=$2 cls=$3 n
  if [ ! -e "$a" ] || [ ! -e "$b" ]; then
    echo "MISSING"
    [ "$cls" = mirror ] && return 1
    return 0
  fi
  if [ "$cls" = variant ]; then
    n=$(diff -r "$a" "$b" 2>/dev/null | grep -c '^[<>]')
    echo "VARIANT ($n diff lines)"
    return 0
  fi
  if [ -d "$a" ]; then
    n=$(diff -rq "$a" "$b" 2>/dev/null | wc -l)
  else
    cmp -s "$a" "$b" && n=0 || n=1
  fi
  [ "$n" -eq 0 ] && { echo "IDENTICAL"; return 0; }
  echo "DIFFERS ($n files)"
  return 1
}

check() { # $1=label $2=src $3=dst $4=class $5=home_path
  local st
  st=$(compare "$2" "$3" "$4") || fail=1
  printf '%-4s %-58s %s\n' "$1" "$5" "$st"
}

while IFS=$'\t' read -r h t c ct cc _note; do
  case "$h" in ''|'#'*|home) continue;; esac
  hp+=("$h")
  if [ "$t" != "-" ] && [ "$ct" != "-" ]; then
    tp+=("$t"); check TPS "$HOME_ROOT/$h" "$TPS_ROOT/$t" "$ct" "$h"
  fi
  if [ "$c" != "-" ] && [ "$cc" != "-" ]; then
    cp+=("$c"); check CCP "$HOME_ROOT/$h" "$CCP_ROOT/$c" "$cc" "$h"
  fi
done < <(tr -d '\r' < "$MAP")

show_status() { # $1=label $2=root, remaining args = pathspecs
  local label=$1 root=$2; shift 2
  echo
  echo "--- git status ($label: $root) ---"
  [ $# -gt 0 ] && git -C "$root" status --short -- "$@" 2>&1
}

show_status HOME "$HOME_ROOT" "${hp[@]}"
show_status TPS "$TPS_ROOT" "${tp[@]}"
show_status CCP "$CCP_ROOT" "${cp[@]}"

exit $fail
