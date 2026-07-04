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

# No --label: herdr then auto-derives the workspace name from the active pane's
# repo and updates it as you cd — so the side-panel repo/branch chip follows,
# like a native workspace. An explicit --label pins the name and it won't follow.
out=$("$herdr" workspace create --cwd "$folder" --no-focus)
ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id')
rt=$(printf '%s' "$out" | jq -r '.result.tab.tab_id')
rp=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id')

wm_build "$layout" "$ws" "$folder" "$rt" "$rp"

# Gotcha: unzoom the overlay's own tab BEFORE focusing, so focus lands on the
# new workspace and no stray "Z" is left behind. Focus is the last move.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true
"$herdr" workspace focus "$ws" >/dev/null 2>&1 || true
"$herdr" tab focus "$rt"       >/dev/null 2>&1 || true
