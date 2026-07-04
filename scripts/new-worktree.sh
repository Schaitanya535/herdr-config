#!/usr/bin/env bash
# prefix+G: branch a NEW git worktree from the CURRENT repo, with a chosen layout.
# Wired via a [[keys.command]] type="pane" bind in config.toml.
#
# Flow: read current repo from the source pane's cwd -> type a branch name ->
# pick a base ref -> pick a layout -> `herdr worktree create` (makes a fresh
# workspace at the worktree path) -> build the layout's tabs -> focus it.
#
# Failures are logged to $LOG and the pane is held open so you can read them.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wm.sh
source "$DIR/lib/wm.sh"

LOG="${TMPDIR:-/tmp}/herdr-new-worktree.log"
log() { printf '%s\n' "$*" >>"$LOG"; }
die() { printf '\nnew-worktree: %s\n' "$*"; log "ERROR: $*"; printf 'press enter to close…'; read -r _ || sleep 3; exit 1; }
log "--- new-worktree run $(date '+%F %T') ---"

# Source pane = the pane focused when the key was pressed (herdr injects it).
src="${HERDR_ACTIVE_PANE_ID:-}"
[ -z "$src" ] && src=$("$herdr" pane current --current 2>/dev/null | jq -r '.result.pane.pane_id // empty')
cwd=""
[ -n "$src" ] && cwd=$("$herdr" pane get "$src" 2>/dev/null \
                       | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"
log "src=$src cwd=$cwd"

repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$repo" ] && die "not inside a git repo (cwd=$cwd)"
log "repo=$repo"

# Branch name — a plain prompt (robust; fzf-as-text-input was flaky).
printf 'New worktree branch name: '
read -r branch || true
branch="$(printf '%s' "$branch" | tr -d '[:space:]')"
[ -z "$branch" ] && die "no branch name given"

# Always branch off a fresh origin/main.
git -C "$repo" fetch origin main --quiet 2>>"$LOG" || true
base="origin/main"
log "branch=$branch base=$base"

layout=$(wm_pick_layout); [ -z "$layout" ] && { log "layout cancelled"; exit 0; }
log "layout=$layout"

out=$("$herdr" worktree create --cwd "$repo" --branch "$branch" --base "$base" --no-focus --json 2>>"$LOG" || true)
log "create-out: $out"
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
[ -z "$ws" ] && die "worktree create failed — $(printf '%s' "$out" | jq -r '.error // "see '"$LOG"'"')"
rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')
wtpath=$(printf '%s' "$out" | jq -r '.result.worktree.path // empty')
[ -z "$wtpath" ] && wtpath="$repo"

wm_build "$layout" "$ws" "$wtpath" "$rt" "$rp"

# Gotcha: unzoom the overlay's own tab BEFORE focusing (focus lands on the new
# worktree workspace, no stray "Z"). Focus is the last move.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true
"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
"$herdr" tab focus "$rt"       >/dev/null 2>&1 || true
