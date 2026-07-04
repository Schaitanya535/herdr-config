#!/usr/bin/env bash
# prefix+N: create a NEW workspace at a chosen folder, with a chosen layout.
# Wired via a [[keys.command]] type="pane" bind in config.toml.
#
# Flow: pick layout -> pick folder (zoxide DB + free-type any path) -> create
# workspace at that folder -> build the layout's tabs/panes -> focus it.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wm.sh
source "$DIR/lib/wm.sh"

layout=$(wm_pick_layout); [ -z "$layout" ] && exit 0
folder=$(wm_pick_folder); [ -z "$folder" ] && exit 0
folder="${folder/#\~/$HOME}"
[ -d "$folder" ] || { echo "not a directory: $folder"; sleep 2; exit 1; }

out=$("$herdr" workspace create --cwd "$folder" --label "$(basename "$folder")" --no-focus)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')
rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')

wm_build "$layout" "$ws" "$folder" "$rt" "$rp"

# Attach the repo association so the side panel shows repo/branch and follows cd
# — like a native workspace. Plain `workspace create` leaves `.worktree` null;
# `worktree open` on the repo's checkout adopts THIS workspace (dedups by
# checkout, no new workspace) and populates it. Non-destructive on the main
# checkout, and a no-op for non-git folders.
repo=$(git -C "$folder" rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$repo" ]; then
  "$herdr" worktree open --cwd "$repo" --path "$repo" --no-focus --json >/dev/null 2>&1 || true
fi

# Gotcha: unzoom the overlay's own tab BEFORE focusing, so focus lands on the
# new workspace and no stray "Z" is left behind. Focus is the last move.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true
"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
"$herdr" tab focus "$rt"       >/dev/null 2>&1 || true
