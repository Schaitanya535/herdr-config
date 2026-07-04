# herdr — session handoff

Working notes for continuing the herdr setup. Config repo: this dir
(`~/.config/herdr`) → github.com/Schaitanya535/herdr-config. herdr v0.7.1, macOS.

## Current state (done)

Keybindings (`config.toml`, prefix `ctrl+s`):
- `prefix+\` vert split · `ctrl+hjkl` vim-aware nav (plugin) · `alt+hjkl` resize
- `prefix+/` scrollback→nvim · `prefix+a` agents picker · `prefix+f` fzf workspace picker
- `prefix+w` native workspace picker (kept) · `prefix+g` native goto (find-everything)

Scripts (`scripts/`, all `[[keys.command]]` type=pane → `list | fzf | focus`):
- `agents-jump.sh` — `agent list` → fzf → `agent focus <terminal_id>`
- `workspaces-jump.sh` — `workspace list` → fzf → `workspace focus`
- `scrollback-edit.sh` — `pane read` → temp file → nvim (copy-mode search workaround)

Plugin: `paulbkim-dev/vim-herdr-navigation` (C-hjkl vim/herdr nav; needs `jq`).
Neovim: `after/plugin/herdr_nav.lua` owns `<C-hjkl>`; vim-tmux-navigator kept for `$TMUX` fallback.
Integrations installed: claude, codex, cursor, pi, opencode.

## Hard-won gotchas (read before editing scripts)

- **type=pane overlay zooms its tab.** A picker that moves focus must run
  `herdr pane zoom --current --off` **BEFORE** the focus call — zoom steals focus
  back if done after, and leaves the tab marked `Z` (zoomed indicator).
  Focus command must be last.
- `herdr agent list` only shows agents herdr **hosts + an integration reports**.
  A session in tmux won't appear (that's why testing from tmux shows empty).
- `$HERDR_ACTIVE_PANE_ID` = the pane focused when the key was pressed (source
  pane), captured at dispatch. `--current` inside a temp pane = the temp pane.
- **`herdr workspace create` is NOT read-only** — it makes a workspace. Don't run
  it to "check usage." (Left a stray `w9` "Projects" once — close strays with
  `herdr workspace close <id>`.)
- Reload after edits: `herdr server reload-config`. List binds: `prefix+?`.
- Never bind `ctrl+r` (shell reverse-search). Prefix-free binds: only `ctrl+alt+<key>` is safe on macOS.

## NEXT TASK — workspace template / bootstrap

Goal: on new workspace, load a template — open nvim, set up panes, and start
claude + codex + pi in subsequent tabs. One command, whole layout.

### Option A (recommended): use the existing plugin `cloudmanic/herdr-plus`

Does exactly this. https://github.com/cloudmanic/herdr-plus
- Declarative workspace **layouts** you fuzzy-pick to spin up a whole workspace
  (every tab + pane + startup command) in one keypress.
- Auto-applies: on `herdr worktree create/open`, herdr-plus catches the event,
  matches the worktree's repo to a layout, and opens its tabs/panes with commands
  running — no keypress.
- A layout = **repo matcher + tabs**; each tab is either a `command` or nested
  `panes`; tabs open in file order, first tab reuses the workspace root tab.

Next session: `herdr plugin install cloudmanic/herdr-plus`, read its layout format,
write a layout for the pei repos with tabs: `nvim`, `claude`, `codex`, `pi`.
Evaluate before committing to it vs DIY.

### Option B (DIY): a script using the herdr CLI

If herdr-plus doesn't fit, a `scripts/new-workspace.sh` bound to a key can build it.
Building blocks (all over the socket API):
- `herdr workspace create --cwd PATH --label TEXT [--no-focus]`
- `herdr tab create --workspace ID --label TEXT --cwd PATH`
- `herdr pane split [--pane ID|--current] --direction right|down [--ratio F] [--cwd P]`
- `herdr agent start <name> [--workspace ID] [--tab ID] [--split right|down] --cwd P -- <argv...>`
  (starts claude/codex/pi as reported agents — use this, not `pane run`, so they
  show in the agents panel / `prefix+a` picker)
- `herdr tab focus <tab_id>` / `herdr pane focus --direction …`

Sketch: create tab "nvim" running nvim; create tabs for claude/codex/pi each via
`agent start`; optionally split the nvim tab into editor + shell panes.

Decision for next session: try Option A first (less effort, event-driven auto-load
per repo), fall back to B for full control.

## File map
- `config.toml` — keybindings/theme/ui
- `scripts/` — the fzf picker + scrollback scripts
- `README.md` — setup on a new machine (plugin + nvim wiring)
- `HANDOFF.md` — this file
