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

# Clear the overlay's zoom on this (source) tab BEFORE jumping, so `workspace
# focus` is the last focus move (lands on the target workspace) and no stray "Z"
# is left on the source tab.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true

"$herdr" workspace focus "$target"
