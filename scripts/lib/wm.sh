#!/usr/bin/env bash
# Shared library for the DIY workspace/worktree template pickers.
# Sourced by new-workspace.sh (prefix+N) and new-worktree.sh (prefix+G).
#
# A "layout" is a bash function `wm_layout_<key>` that, given a target workspace
# and its root tab/pane, fills the workspace with tabs/panes + startup commands
# over the herdr CLI. Both entry scripts pick a layout, decide a cwd (a folder or
# a new worktree path), create the workspace, then call wm_build.
#
# Add a layout: (1) write a `wm_layout_<key>` function (dashes in the key become
# underscores in the function name), (2) add a "key<TAB>description" line to
# WM_LAYOUTS below so it shows in the picker.

herdr="${HERDR_BIN_PATH:-herdr}"

# --- primitives -----------------------------------------------------------

# wm_tab WS CWD LABEL [CMD] -> echoes the new tab's root pane id
wm_tab() {
  local ws=$1 cwd=$2 label=$3 cmd=${4:-} pid
  pid=$("$herdr" tab create --workspace "$ws" --cwd "$cwd" --label "$label" --no-focus 2>/dev/null \
        | jq -r '.result.root_pane.pane_id')
  if [ -n "$cmd" ]; then "$herdr" pane run "$pid" "$cmd" >/dev/null 2>&1 || true; fi
  printf '%s' "$pid"
}

# wm_split PANE down|right RATIO CWD [CMD] -> echoes the new pane id
wm_split() {
  local pane=$1 dir=$2 ratio=$3 cwd=$4 cmd=${5:-} pid
  pid=$("$herdr" pane split --pane "$pane" --direction "$dir" --ratio "$ratio" --cwd "$cwd" --no-focus 2>/dev/null \
        | jq -r '.result.pane.pane_id')
  if [ -n "$cmd" ]; then "$herdr" pane run "$pid" "$cmd" >/dev/null 2>&1 || true; fi
  printf '%s' "$pid"
}

# wm_nvim ROOT_PANE
# The universal editor tab: just nvim in the root pane. Splits (shell, lazygit)
# are left to you to make on demand — keeps startup light (fewer shells at once).
wm_nvim() {
  local rp=$1
  "$herdr" pane run "$rp" "nvim" >/dev/null 2>&1 || true
}

# --- layouts --------------------------------------------------------------
# Picker registry: one "key<TAB>description" line per layout.
WM_LAYOUTS=$(cat <<'EOF'
pei-agentic	claude(cs) runs · nvim/codex/pi = empty tabs
pei-lean	claude(cs) runs · nvim = empty tab
personal	nvim runs · claude/pi = empty tabs
review	codex only (code-review prompt)
blank	single empty shell (native-like)
EOF
)

# Each layout fn signature: WS CWD ROOT_TAB ROOT_PANE
# Only one tab auto-launches a command; the rest are empty, labelled tabs you
# start yourself (lighter startup + you open what you need, when you need it).

wm_layout_pei_agentic() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  "$herdr" tab rename "$rt" claude >/dev/null 2>&1
  "$herdr" pane run "$rp" "cs" >/dev/null 2>&1 || true   # only cs auto-runs
  wm_tab "$ws" "$cwd" nvim  >/dev/null                   # empty tab
  wm_tab "$ws" "$cwd" codex >/dev/null                   # empty tab
  wm_tab "$ws" "$cwd" pi    >/dev/null                   # empty tab
}

wm_layout_pei_lean() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  "$herdr" tab rename "$rt" claude >/dev/null 2>&1
  "$herdr" pane run "$rp" "cs" >/dev/null 2>&1 || true   # only cs auto-runs
  wm_tab "$ws" "$cwd" nvim >/dev/null                    # empty tab
}

wm_layout_personal() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  "$herdr" tab rename "$rt" nvim >/dev/null 2>&1
  wm_nvim "$rp"                                          # only nvim auto-runs
  wm_tab "$ws" "$cwd" claude >/dev/null                  # empty tab
  wm_tab "$ws" "$cwd" pi     >/dev/null                  # empty tab
}

wm_layout_review() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  local prompt="You are going to do a code review. Ground the review in the actual code. Use glab to inspect the merge request. I will shortly give you the MR."
  "$herdr" tab rename "$rt" review >/dev/null 2>&1
  "$herdr" pane run "$rp" "codex $(printf '%q' "$prompt")" >/dev/null 2>&1 || true
}

wm_layout_blank() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  "$herdr" tab rename "$rt" shell >/dev/null 2>&1
}

# wm_build LAYOUT_KEY WS CWD ROOT_TAB ROOT_PANE
wm_build() {
  local key=$1; shift
  "wm_layout_${key//-/_}" "$@"
}

# --- pickers --------------------------------------------------------------

# wm_pick_layout -> echoes the chosen key (empty on cancel)
wm_pick_layout() {
  { printf '%s\n' "$WM_LAYOUTS" \
      | fzf --delimiter='\t' --prompt="layout> " --height=60% --border --info=inline \
      | cut -f1; } || true
}

# wm_pick_folder -> echoes the chosen dir. Sourced from zoxide's frecency DB;
# --print-query lets you type any path not in the list (line 1 = query, line 2 =
# selection if one was chosen).
wm_pick_folder() {
  local out sel query
  out=$(zoxide query -l 2>/dev/null \
        | fzf --prompt="folder> " --height=60% --border --info=inline --print-query \
        || true)
  query=$(printf '%s\n' "$out" | sed -n '1p')
  sel=$(printf '%s\n' "$out" | sed -n '2p')
  if [ -n "$sel" ]; then printf '%s' "$sel"; else printf '%s' "$query"; fi
}
