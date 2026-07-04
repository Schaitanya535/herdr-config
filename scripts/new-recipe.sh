#!/usr/bin/env bash
# prefix+l: one-pick launch of a pinned "folder + layout" recipe.
# Wired via a [[keys.command]] type="pane" bind in config.toml.
#
# The fast path: prefix+N asks for folder AND layout; a recipe pins both, so
# this is a single pick -> new workspace. Recipes live in lib/wm.sh (WM_RECIPES)
# and reuse the same layout fns (wm_build) as prefix+N / prefix+G.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wm.sh
source "$DIR/lib/wm.sh"

pick=$(wm_pick_recipe); [ -z "$pick" ] && exit 0
folder=$(printf '%s' "$pick" | cut -f1)
layout=$(printf '%s' "$pick" | cut -f2)
folder="${folder/#\~/$HOME}"
[ -d "$folder" ] || { echo "not a directory: $folder"; sleep 2; exit 1; }

# No --label: herdr auto-derives the workspace name from the active pane's repo
# and updates it as you cd (side-panel chip follows). Same as new-workspace.sh.
out=$("$herdr" workspace create --cwd "$folder" --no-focus)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')
rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')

wm_build "$layout" "$ws" "$folder" "$rt" "$rp"

# Gotcha: unzoom the overlay's own tab BEFORE focusing (focus lands on the new
# workspace, no stray "Z"). Focus is the last move.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true
"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
"$herdr" tab focus "$rt"       >/dev/null 2>&1 || true
