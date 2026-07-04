# herdr config

My [herdr](https://herdr.dev) config — an agent multiplexer ("tmux for coding
agents"). Lives at `~/.config/herdr/`.

## What's here

- `config.toml` — keybindings, theme, UI. Prefix is `ctrl+s` (matches my tmux).
- `scripts/scrollback-edit.sh` — `prefix+/` dumps the focused pane's scrollback
  to a temp file and opens it in `$EDITOR` (nvim), since herdr copy mode has no
  search yet. Temp file is deleted on exit.

Runtime state (logs, sockets, `session.json`, installed `plugins/`) is
gitignored.

## Setup on a new machine

```bash
git clone <this-repo> ~/.config/herdr

# plugin: vim-tmux-navigator, ported to herdr (Ctrl+hjkl across panes + vim splits)
herdr plugin install paulbkim-dev/vim-herdr-navigation --yes   # needs: jq

# reload
herdr server reload-config
```

### Neovim side (for the vim-herdr-navigation plugin)

`vim-tmux-navigator` is kept with its own maps disabled; the herdr nav script
owns `<C-hjkl>`:

```lua
-- lua/custom/plugins/tmux.lua
return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  init = function() vim.g.tmux_navigator_no_mappings = 1 end,
}
```

Then copy the plugin's editor script so it loads last and wins:

```bash
cp ~/.config/herdr/plugins/github/vim-herdr-navigation-*/editor/nvim.lua \
   ~/.config/nvim/after/plugin/herdr_nav.lua
```

## Keymap notes

- `prefix = ctrl+s`
- `prefix+\` — vertical split (side-by-side)
- `ctrl+hjkl` — vim-aware pane/split navigation (plugin)
- `alt+hjkl` (M-hjkl) — resize pane (via `herdr pane resize` CLI)
- `prefix+/` — scrollback → nvim
- `prefix+w` — workspace picker · `prefix+g` — goto picker · `prefix+?` — all binds

Workflow: one workspace per repo, everything in the default session; separate
sessions only for wholly unrelated work.
