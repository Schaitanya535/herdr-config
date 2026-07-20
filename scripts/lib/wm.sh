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

# wm_default_branch REPO -> echoes the repo's default branch. Never assume main:
# repos differ (pei-ra-api uses master, pei-fusion uses main). Resolve via
# origin/HEAD, fall back to `remote show`, then to main.
wm_default_branch() {
  local repo=$1 db
  db=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  [ -z "$db" ] && db=$(git -C "$repo" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
  [ -z "$db" ] && db=main
  printf '%s' "$db"
}

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

# wm_launch_agent PANE CMD PROCNAME
# Auto-launch an agent (codex etc.) into a freshly created pane, reliably. A
# fresh pane's shell needs a beat to spawn + source its profile before it accepts
# typed input; a `pane run` fired too early has its keystrokes silently dropped,
# and worktree creation widens that race. Screen-scraping "is the shell ready"
# is flaky — transient pre-prompt output trips it. So instead: fire the command,
# then VERIFY the target process actually started (process-info), and retry with
# a line-clear if it didn't. Self-correcting regardless of timing.
wm_launch_agent() {
  local rp=$1 cmd=$2 proc=$3 i j
  for i in 1 2 3 4; do
    "$herdr" pane run "$rp" "$cmd" >/dev/null 2>&1 || true
    for j in $(seq 1 20); do   # ~3s: wait for the process to appear
      if "$herdr" pane process-info --pane "$rp" 2>/dev/null \
           | jq -e --arg p "$proc" '.result.process_info.foreground_processes[]? | select(.name==$p)' >/dev/null 2>&1; then
        return 0
      fi
      sleep 0.15
    done
    # keystrokes were dropped (shell not ready) — clear any partial line, retry.
    "$herdr" pane send-keys "$rp" ctrl+c >/dev/null 2>&1 || true
    sleep 0.3
  done
}

# --- layouts --------------------------------------------------------------
# Picker registry: one "key<TAB>description" line per layout.
WM_LAYOUTS=$(cat <<'EOF'
pei-agentic	claude(cs) runs · nvim/codex/pi = empty tabs
pei-lean	claude(cs) runs · nvim = empty tab
personal	nvim runs · claude/pi = empty tabs
nvim-cs	claude(cs) primary runs · nvim = empty tab
review	codex only (mr-review skill; prompts for MR)
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

# cs is primary (auto-runs in the root claude tab); nvim is an empty tab you
# open on demand. Same shape as pei-lean — kept as its own name for config repos.
wm_layout_nvim_cs() {
  local ws=$1 cwd=$2 rt=$3 rp=$4
  "$herdr" tab rename "$rt" claude >/dev/null 2>&1
  "$herdr" pane run "$rp" "cs" >/dev/null 2>&1 || true   # cs is primary
  wm_tab "$ws" "$cwd" nvim >/dev/null                    # empty nvim tab
}

# wm_layout_review WS CWD RT RP [MR] [SCOPE]
# The review workflow itself lives in the `mr-review` skill (canonical source at
# ~/.agents/skills/mr-review, symlinked into ~/.codex/skills and ~/.claude/skills).
# We only hand codex a one-line trigger; the skill supplies the steps. MR and
# SCOPE are captured at recipe-pick time and baked into the trigger, so codex
# starts at the right depth immediately. Blank MR -> skill asks for it; blank/
# "ask" SCOPE -> skill runs its own scope prompt (step 1). SCOPE is a picker key
# (thorough|minimal|ask), mapped to the sentence the skill understands here.
wm_layout_review() {
  local ws=$1 cwd=$2 rt=$3 rp=$4 mr=${5:-} scope=${6:-}
  local prompt
  if [ -n "$mr" ]; then
    prompt="Use the mr-review skill to review GitLab MR: $mr"
  else
    prompt="Use the mr-review skill to review a GitLab MR. I'll give you the MR shortly."
  fi
  # Keep these sentences plain ASCII (no ';', no em-dash): multibyte or shell-meta
  # chars typed through `pane run` can corrupt the escaping and split the prompt
  # into multiple args, which codex then rejects.
  case "$scope" in
    thorough) prompt="$prompt Scope: Jira/MR requirements, Code smells, and Testing." ;;
    minimal)  prompt="$prompt Scope: Minimal. Keep it lightweight and report only clear correctness, regression, or test-risk issues." ;;
    # ask / empty: bake nothing; the skill runs its own scope prompt.
  esac
  "$herdr" tab rename "$rt" review >/dev/null 2>&1
  # codex gates every untrusted directory behind a "Do you trust this dir?"
  # prompt (trusted paths live in ~/.codex/config.toml). It keys trust on the
  # git REPO ROOT, not the cwd — and for a linked worktree that resolves to the
  # MAIN repo (parent of --git-common-dir), not the throwaway review/<ts> path.
  # Each review lands in a fresh worktree, so codex halts on the gate and never
  # reaches the prompt. Pre-trust the resolved repo root inline via -c so codex
  # opens straight to work. Idempotent: harmless if the root is already trusted.
  local root
  root=$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")
  local opts=""
  [ -d "$root" ] && opts="-c $(printf '%q' "projects.\"$root\".trust_level=\"trusted\"") "
  # codex has a SECOND gate on startup: "Hooks need review" whenever hooks are new
  # or changed. It blocks the composer, so the baked prompt never submits and the
  # review never starts. --dangerously-bypass-hook-trust clears it; with both gates
  # gone codex auto-runs the positional prompt (no keystroke needed). Consistent
  # with this setup (config is already sandbox=danger-full-access, approval=never).
  opts="--dangerously-bypass-hook-trust ${opts}"
  # Verify-and-retry: worktree shell may not be ready, dropping the keystrokes.
  wm_launch_agent "$rp" "codex ${opts}$(printf '%q' "$prompt")" codex
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

# --- recipes --------------------------------------------------------------
# A recipe = a pinned "folder + layout" pair for one-pick launch (prefix+l),
# bypassing the two-step folder/layout pick of prefix+N. Reuses the layout fns
# above — the layout key must match a WM_LAYOUTS key.
#
# One "name<TAB>folder<TAB>layout" line per recipe. ~ is expanded at launch.
# Add a recipe: append a line here. The name is just the picker label.
#
# Special case: recipes whose layout is `review` don't open a workspace on the
# folder — new-recipe.sh treats the folder as a git repo and branches a
# throwaway worktree (review/<ts>) off origin/main, so the review runs isolated
# from your main checkout. codex then `glab mr checkout`s the MR inside it.
WM_RECIPES=$(cat <<'EOF'
work-ra	~/Work/pei-ra-api	pei-agentic
work-fusion	~/Work/pei-fusion-monorepo	pei-agentic
review-ra	~/Work/pei-ra-api	review
review-fusion	~/Work/pei-fusion-monorepo	review
upskill	~/Projects/mission-upskilling	personal
nvim	~/.config/nvim	nvim-cs
herdr	~/.config/herdr	nvim-cs
EOF
)

# --- pickers --------------------------------------------------------------

# wm_pick_layout -> echoes the chosen key (empty on cancel)
wm_pick_layout() {
  { printf '%s\n' "$WM_LAYOUTS" \
      | fzf --delimiter='\t' --prompt="layout> " --height=60% --border --info=inline \
      | cut -f1; } || true
}

# wm_pick_review_scope -> echoes the chosen scope key (thorough|minimal|ask),
# empty on cancel. Baked into the review trigger so codex opens at the right
# depth; "ask" (or cancel) leaves the mr-review skill to run its own scope prompt.
wm_pick_review_scope() {
  { printf '%s\n' \
      "thorough	requirements + code smells + testing" \
      "minimal	quick — correctness / regression / test-risk only" \
      "ask	let the skill ask inside codex" \
      | fzf --delimiter='\t' --with-nth='1,2' --prompt="scope> " --height=40% --border --info=inline \
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

# wm_pick_recipe -> echoes the chosen "folder<TAB>layout" (empty on cancel).
# fzf shows all three columns; we drop field 1 (the label) from the result.
wm_pick_recipe() {
  { printf '%s\n' "$WM_RECIPES" \
      | fzf --delimiter='\t' --with-nth='1,3,2' --prompt="recipe> " \
            --height=60% --border --info=inline \
      | cut -f2,3; } || true
}
