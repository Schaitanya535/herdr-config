#!/usr/bin/env bash
# Dump the source pane's scrollback to a temp file and open it in your editor
# (nvim), so you get full search / visual yank / whatever. Wired to prefix+/ via
# a [[keys.command]] type="pane" bind in config.toml.
#
# Source pane = the pane focused when the key was pressed. herdr injects it as
# $HERDR_ACTIVE_PANE_ID at dispatch. Do NOT use `pane current --current` here:
# this script runs in a fresh temp pane that is now focused, so --current would
# read this pane instead of the one whose scrollback you want.
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
src="${HERDR_ACTIVE_PANE_ID:-}"

if [ -z "$src" ]; then
  src="$("$herdr" pane current --current 2>/dev/null | jq -r '.result.pane.pane_id // empty')"
fi

if [ -z "$src" ]; then
  echo "scrollback: could not resolve source pane" >&2
  sleep 1.5
  exit 1
fi

tmp="$(mktemp -t herdr-scrollback)"
trap 'rm -f "$tmp"' EXIT

"$herdr" pane read "$src" --source recent-unwrapped --lines 50000 --format text > "$tmp"

editor="${VISUAL:-${EDITOR:-nvim}}"
# open at the last line (most recent output). temp file is deleted on exit,
# so any edits are throwaway — yank what you need to the clipboard.
"$editor" + "$tmp"
