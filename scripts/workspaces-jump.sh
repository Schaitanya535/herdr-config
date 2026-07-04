#!/usr/bin/env bash
# fzf workspace switcher: list workspaces, pick one, jump to it.
# Wired to prefix+w via a [[keys.command]] type="pane" bind in config.toml
# (replaces herdr's native workspace_picker).
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"

line="$(
  "$herdr" workspace list 2>/dev/null \
    | jq -r '.result.workspaces[]
        | [ .workspace_id,
            "\(.number)  \(.label)  ·  \(.tab_count)t/\(.pane_count)p  ·  [\(.agent_status)]  ·  \(.worktree.repo_name // .worktree.checkout_path // "")"
          ] | @tsv' \
    | fzf --with-nth=2.. --delimiter='\t' \
          --prompt="workspace> " --height=60% --border --info=inline \
    || true
)"

[ -z "${line:-}" ] && exit 0

target="${line%%$'\t'*}"
[ -z "$target" ] && exit 0

"$herdr" workspace focus "$target"

# The type="pane" overlay zooms its tab to show fzf; on exit herdr can restore
# the overlay-induced zoom (src/app/api.rs restore_overlay_after_exit), leaving
# the source tab marked "Z". Clear the source tab's zoom.
[ -n "${HERDR_ACTIVE_PANE_ID:-}" ] && "$herdr" pane zoom "$HERDR_ACTIVE_PANE_ID" --off >/dev/null 2>&1 || true
