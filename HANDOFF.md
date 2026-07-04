# herdr — session handoff

Working notes for continuing the herdr setup. Config repo: this dir
(`~/.config/herdr`) → github.com/Schaitanya535/herdr-config. herdr v0.7.1, macOS.

## Current state (done)

Keybindings (`config.toml`, prefix `ctrl+s`):
- `prefix+\` vert split · `ctrl+hjkl` vim-aware nav (plugin) · `alt+hjkl` resize
- `prefix+/` scrollback→nvim · `prefix+a` agents picker · `prefix+f` fzf workspace picker
- `prefix+w` native workspace picker (kept) · `prefix+g` native goto (find-everything)
- `prefix+N` new workspace from template · `prefix+G` new worktree from template (DIY)

Scripts (`scripts/`, pickers are `[[keys.command]]` type=pane):
- `agents-jump.sh` — `agent list` → fzf → `agent focus <terminal_id>`
- `workspaces-jump.sh` — `workspace list` → fzf → `workspace focus`
- `scrollback-edit.sh` — `pane read` → temp file → nvim
- `lib/wm.sh` — shared template-picker library: build primitives + layout defs + pickers
- `new-workspace.sh` (prefix+N) — pick layout → pick folder (zoxide+free-type) → build
- `new-worktree.sh` (prefix+G) — branch/base/layout → `worktree create` → build

Plugins: `paulbkim-dev/vim-herdr-navigation` (C-hjkl vim/herdr nav; needs `jq`).
**herdr-plus was evaluated then uninstalled** — see "Template system" below.
Neovim: `after/plugin/herdr_nav.lua` owns `<C-hjkl>`; vim-tmux-navigator kept for `$TMUX` fallback.
Integrations installed: claude, codex, cursor, pi, opencode.

## Template system (DIY — the workspace/worktree bootstrap)

Replaces `cloudmanic/herdr-plus`. We tried herdr-plus (declarative TOML projects +
repo-matched worktree auto-layout) but it's **list-based**: can't prompt for a
folder at launch, and worktree layouts auto-match by repo name (no picking). We
wanted runtime folder choice + template choice, so built our own and uninstalled it.

**Layouts** live in `lib/wm.sh` as `wm_layout_<key>` bash functions (dashes in the
picker key → underscores in the fn name). Current set:
Only ONE tab per layout auto-launches a command; the rest are empty, labelled tabs
you start yourself (lighter startup, open what you need when you need it):
- `pei-agentic` — **claude** runs `cs`; `nvim`/`codex`/`pi` are empty tabs
- `pei-lean` — **claude** runs `cs`; `nvim` is an empty tab
- `personal` — **nvim** runs; `claude`/`pi` are empty tabs   (~/Projects)
- `review` — codex only, seeded with a code-review prompt (uses glab); no nvim
- `blank` — single empty shell (native-like)

Add a layout: write `wm_layout_<key>()` + add a `key<TAB>desc` line to `WM_LAYOUTS`.

**nvim tab** (`wm_nvim`): just opens nvim in the tab's root pane — no auto splits.
Splits (shell/lazygit) are made on demand. `wm_split` primitive is kept in `wm.sh`
for future use (e.g. recipes) even though no layout calls it now.

**Worktree base:** `new-worktree.sh` always branches off a freshly-fetched
`origin/main` (no base picker) — `git fetch origin main` then `--base origin/main`.

**Repo chip / cwd-follow:** plain `herdr workspace create` leaves the workspace's
`.worktree` (repo association) **null**, so the side-panel repo/branch chip is blank
and doesn't follow `cd` — unlike native workspaces. Fix: after building, if the
folder is in a git repo, `new-workspace.sh` runs `herdr worktree open --cwd REPO
--path REPO`, which **adopts the same workspace** (dedups by checkout, no new ws)
and populates `.worktree`. Non-destructive on the main checkout (`worktree remove`
on it only closes the herdr workspace; git refuses to delete the checkout).
`new-worktree.sh` needs no such step — real worktrees get `.worktree` on create.

`cs` is a shell **alias** (`claude --dangerously-skip-permissions --plugin-dir
~/dev/repos/pegasus`). `pane run` executes in the pane's interactive shell so the
alias resolves. If it ever misfires, expand it in the layout fn.

### herdr CLI building blocks (all emit JSON by default; parse with jq)
- `workspace create --cwd P --label L --no-focus` → `.result.{workspace.workspace_id, tab.tab_id, root_pane.pane_id}`
- `tab create --workspace WS --cwd P --label L --no-focus` → `.result.{tab.tab_id, root_pane.pane_id}`
- `pane split --pane PID --direction down|right --ratio F --cwd P --no-focus` → `.result.pane.pane_id`
- `pane run PID "cmd"` — fire-and-forget (no output)
- `worktree create --cwd REPO --branch B --base REF --no-focus --json` → same shape as
  workspace create **plus** `.result.worktree.path` (the new worktree dir = build cwd)
- `pane get PID` → `.result.pane.{cwd, foreground_cwd}` (used to find the current repo)
- `workspace close WS` · `worktree remove --workspace WS --force`
- Root ids of a fresh workspace are always `WS:t1` / `WS:p1`.

## Hard-won gotchas (read before editing scripts)

- **type=pane overlay zooms its tab.** A picker that moves focus must run
  `herdr pane zoom --current --off` **BEFORE** the focus call — zoom steals focus
  back if done after, and leaves the tab marked `Z`. Focus command must be last.
- **`set -euo pipefail` footgun:** a standalone `[ -n "$x" ] && cmd` returns 1 when
  `$x` is empty → aborts the script. Use `if [ -n "$x" ]; then …; fi`. fzf pickers
  need `|| true` (ESC exits 130). Both handled in `wm.sh` — keep it that way.
- **fzf as a text prompt:** `: | fzf --print-query` (empty list) captures typed input
  — used for the branch name. `--print-query` prints query on line 1, selection on
  line 2; prefer selection, fall back to query (folder + base pickers).
- `$HERDR_ACTIVE_PANE_ID` = the source pane focused when the key was pressed (the
  worktree script reads its cwd via `pane get` to locate the repo). `HERDR_PANE_ID`
  in a type=pane script is the temp overlay pane, not the source.
- `herdr agent list` only shows agents herdr hosts + an integration reports; a tmux
  session won't appear. Agents started via `pane run "cs"` still get detected by the
  claude integration → show in `prefix+a`.
- **`herdr workspace create` / `worktree create` are NOT read-only.** Probe with a
  throwaway then `workspace close` / `worktree remove --force` + `git worktree prune`.
- Reload after config edits: `herdr server reload-config`. List binds live: `prefix+?`.
- Never bind `ctrl+r` (shell reverse-search). Prefix-free binds: only `ctrl+alt+<key>`
  safe on macOS.
- **Slow multi-pane startup was pyenv, not herdr.** `pyenv init -` rehashes on every
  shell; N panes launching at once fought the flock (`~/.pyenv/shims/.pyenv-shim`, 60s
  timeout each) → ~minute-long startup. Fixed in `~/.zshrc` with `pyenv init
  - --no-rehash zsh` (run `pyenv rehash` manually after installing a console script).
  Not part of this repo, but relevant when panes feel slow.

## Testing checklist (do this — scripts are built but unpressed)

1. `prefix+N` → layout picker → folder picker (zoxide list + type any path) → confirm
   a new workspace spawns with the layout's tabs, `cs`/codex/pi running, nvim tab has
   the 3-pane split.
2. `prefix+G` from inside a repo → type branch → pick base → pick layout → confirm a
   worktree workspace opens at `~/.herdr/worktrees/<repo>/<branch>` with the layout.
3. Confirm `prefix+N`/`prefix+G` (shift) don't collide with anything native (`prefix+?`).
4. Eyeball the nvim pane ratios; tune `wm_nvim` if needed.

## NEXT TASK — "recipes" (pinned quick-pick)

Wanted: preconfigured **project + template** pairs for one-pick launch (the fast path
that herdr-plus "projects" gave, but ours). Idea: a `prefix+l` picker over a small
list of `folder + layout` recipes (e.g. `pei-fusion-monorepo → pei-agentic`), pinned
at the top / bypassing the two-step folder pick. Reuse `wm_build` + the layout fns in
`lib/wm.sh` so there's a single source of layout defs. Likely a `recipes` array in a
config file or inline in a `new-recipe.sh`, bound to `prefix+l`.

## File map
- `config.toml` — keybindings/theme/ui
- `scripts/` — pickers; `scripts/lib/wm.sh` — template library
- `README.md` — setup on a new machine (plugin + nvim wiring)
- `HANDOFF.md` — this file
