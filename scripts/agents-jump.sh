#!/usr/bin/env bash
# Keyboard "agents panel": list reported agents, pick one in fzf, jump to it.
# Wired to prefix+a via a [[keys.command]] type="pane" bind in config.toml.
#
# `herdr agent focus` handles the workspace/tab/pane switch. Agents only appear
# here when an integration reports them (herdr integration install <agent>);
# an agent running outside herdr (e.g. in tmux) won't show up.
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"

line="$(
  "$herdr" agent list 2>/dev/null \
    | jq -r '.result.agents[]
        | [ .terminal_id,
            "[\(.agent_status)]  \(.agent)  ·  \(.pane_id) @ \(.tab_id)  ·  \(.cwd)"
          ] | @tsv' \
    | fzf --with-nth=2.. --delimiter='\t' \
          --prompt="agent> " --height=60% --border --info=inline \
    || true
)"

[ -z "${line:-}" ] && exit 0

target="${line%%$'\t'*}"
[ -z "$target" ] && exit 0

# Clear the zoom the type="pane" overlay applied to this (source) tab BEFORE we
# jump. Doing it first (on --current = the overlay's own tab) means `agent focus`
# is the last focus move, so focus lands on the target — not back here — and no
# stray "Z" is left behind.
"$herdr" pane zoom --current --off >/dev/null 2>&1 || true

"$herdr" agent focus "$target"
