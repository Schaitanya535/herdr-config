#!/usr/bin/env bash
# prefix+l: one-pick launch of a pinned "folder + layout" recipe.
# Wired via a [[keys.command]] type="pane" bind in config.toml.
#
# The fast path: prefix+N asks for folder AND layout; a recipe pins both, so
# this is a single pick -> new workspace. Recipes live in lib/wm.sh (WM_RECIPES)
# and reuse the same layout fns (wm_build) as prefix+N / prefix+G.
#
# Special case: the `review` layout branches a throwaway git WORKTREE off
# origin/main instead of opening a plain workspace on the repo folder — so a
# review never disturbs your main checkout. codex then `glab mr checkout`s the
# MR you hand it, inside that isolated worktree.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wm.sh
source "$DIR/lib/wm.sh"

LOG="${TMPDIR:-/tmp}/herdr-new-recipe.log"
log() { printf '%s\n' "$*" >>"$LOG"; }
die() { printf '\nnew-recipe: %s\n' "$*"; log "ERROR: $*"; printf 'press enter to close…'; read -r _ || sleep 3; exit 1; }

pick=$(wm_pick_recipe); [ -z "$pick" ] && exit 0
folder=$(printf '%s' "$pick" | cut -f1)
layout=$(printf '%s' "$pick" | cut -f2)
folder="${folder/#\~/$HOME}"
[ -d "$folder" ] || { echo "not a directory: $folder"; sleep 2; exit 1; }

mr=""; scope=""
if [ "$layout" = "review" ]; then
  # --- review: branch a throwaway worktree off origin/main --------------------
  log "--- review-recipe run $(date '+%F %T') folder=$folder ---"
  repo=$(git -C "$folder" rev-parse --show-toplevel 2>/dev/null || true)
  [ -z "$repo" ] && die "review recipe needs a git repo (folder=$folder)"

  # Capture the MR here, at templating time, so codex starts on it immediately.
  # Blank is fine — the mr-review skill just asks for it once codex opens.
  printf 'MR to review (URL or number, blank to skip): '
  read -r mr || mr=""
  # Sanitize: a paste into `read` arrives wrapped in bracketed-paste markers
  # (ESC[200~ … ESC[201~) when the terminal has that mode on. Those raw ESC bytes
  # end up in the codex command and corrupt the launch. Strip the markers, drop
  # any remaining control chars, and trim surrounding whitespace.
  mr=${mr//$'\e[200~'/}; mr=${mr//$'\e[201~'/}
  mr=$(printf '%s' "$mr" | tr -d '\000-\037')
  mr="${mr#"${mr%%[![:space:]]*}"}"; mr="${mr%"${mr##*[![:space:]]}"}"
  log "mr=$mr"

  # Pick the review scope now too, so codex opens at the right depth. Cancel or
  # "ask" -> the skill runs its own scope prompt inside codex.
  scope=$(wm_pick_review_scope)
  log "scope=$scope"

  db=$(wm_default_branch "$repo")
  git -C "$repo" fetch origin "$db" --quiet 2>>"$LOG" || true
  branch="review/$(date +%Y%m%d-%H%M%S)"
  log "repo=$repo branch=$branch base=origin/$db default=$db"

  out=$("$herdr" worktree create --cwd "$repo" --branch "$branch" --base "origin/$db" --no-focus --json 2>>"$LOG" || true)
  log "create-out: $out"
  ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
  [ -z "$ws" ] && die "worktree create failed — $(printf '%s' "$out" | jq -r '.error // "see '"$LOG"'"')"
  rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
  rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')
  cwd=$(printf '%s' "$out" | jq -r '.result.worktree.path // empty')
  [ -z "$cwd" ] && cwd="$repo"
else
  # --- everything else: plain workspace on the pinned folder ------------------
  # No --label: herdr auto-derives the workspace name from the active pane's repo
  # and updates it as you cd (side-panel chip follows). Same as new-workspace.sh.
  out=$("$herdr" workspace create --cwd "$folder" --no-focus)
  ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')
  rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
  rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')
  cwd="$folder"
fi

wm_build "$layout" "$ws" "$cwd" "$rt" "$rp" "$mr" "$scope"

# Gotcha: unzoom the overlay's own tab BEFORE focusing (focus lands on the new
# workspace, no stray "Z"). Focus is the last move.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true
"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
"$herdr" tab focus "$rt"       >/dev/null 2>&1 || true
