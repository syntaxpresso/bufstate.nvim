<div align="center">
  <img width="500" alt="syntaxpresso" src="https://github.com/user-attachments/assets/be0749b2-1e53-469c-8d99-012024622ade" />
</div>

<div align="center">
  <img alt="neovim" src="https://img.shields.io/badge/NeoVim-%2357A143.svg?&logo=neovim&logoColor=white" />
  <img alt="lua" src="https://img.shields.io/badge/built%20with-Lua-blue?logo=lua" />
</div>

## Why bufstate?

**bufstate.nvim** brings persistent workspace management directly into Neovim. Stop juggling between tmux sessions and manual session files.

- **Tab-based workspaces** — Each tab is an isolated workspace with its own working directory (`tcd`)
- **Persistent sessions** — Save and restore your entire layout including window splits, tab order, and buffer order
- **Smart buffer filtering** — Only see buffers relevant to your current tab, automatically
- **Auto-save** — Periodic background saves keep your workspace state safe without thinking about it
- **Exact state restoration** — Tabs, buffers, cursor positions, and focus restore precisely in the same order
- **Context switching** — Jump between projects faster than tmux attach, with fuzzy session picker

Uses Neovim's native `:mksession` command under the hood for reliable session persistence. All sessions are stored as standard `.vim` session files, paired with a JSON sidecar for metadata.

https://github.com/user-attachments/assets/9162f9a5-8576-4f95-b01b-0f2a1ab10f17

## Features

### Session Management

- **Save** (`BufstateSave`) — Overwrites the current session
- **Save As** (`BufstateSaveAs`) — Creates a new named session
- **Load** (`BufstateLoad`) — Restores a session interactively via fuzzy picker
- **Delete** (`BufstateDelete`) — Removes a session with picker confirmation
- **New** (`BufstateNew`) — Saves the current workspace, then clears everything for a fresh start
- **Close** (`BufstateClose`) — Saves the current workspace and closes it, leaving a clean slate. Follow up with `:BufstateLoad` to switch context.
- **List** (`BufstateList`) — Shows all saved sessions with timestamps and current marker
- **Auto-load on startup** — Optionally restores the last used session when Neovim opens
- **Interactive picker** — Fuzzy-search through sessions with preview (snacks.nvim integration, falls back to `vim.ui.select`)
- **Multiple named sessions** — Maintain as many independent sessions as you need

### Workspace Isolation

- Each tab operates as an independent project workspace
- Tab-local working directories (`tcd`) are preserved across saves and restores
- Buffers are automatically associated with the tab they were opened in
- Buffer listing is filtered per-tab so you only see what belongs to the current workspace
- Works seamlessly with bufferline, Telescope, fzf, and any other buffer plugin

### State Tracking

- Tab order is preserved exactly as saved
- Buffer order per tab is preserved exactly as saved
- Cursor position restored for every buffer
- Last active tab and buffer are focused automatically on restore
- Window splits and layout fully restored via `:mksession`
- Session timestamps tracked via filesystem mtime for smart ordering

### Auto-save System

- Periodic background saves at configurable interval (default: every 5 minutes)
- Debounce mechanism prevents excessive file I/O (default: minimum 30s between saves)
- Optional save-on-exit (`VimLeavePre`) ensures you never lose state
- Unnamed workspaces auto-save under the `_autosave` session name
- Runtime controls: pause, resume, force immediate save, or check status

### LSP Management

- Stop LSP clients when leaving a tab — saves resources when switching contexts
- Restart LSP clients when entering a tab — ensures language features are live
- Stop all LSP clients before loading a session — prevents LSP accumulation
- All LSP controls are individually configurable

### Safe Buffer Operations

- `:Bdelete` — Deletes a buffer without closing the tab (safe alternative to `:bdelete`)
- `:Bwipeout` — Wipes a buffer without closing the tab (safe alternative to `:bwipeout`)
- `:bd` auto-expands to `:Bdelete` in command-line mode
- `:bw` auto-expands to `:Bwipeout` in command-line mode
- Lua equivalents: `require("bufstate").bdelete()` and `.bwipeout()`

### Debug Tools

- `:BufstateDebug` — Prints a snapshot of the internal tab-to-buffer state via notification
- `:BufstateWatch` — Toggles a live-updating floating window showing real-time buffer ownership per tab (refreshes every 500ms, uses `bufstate-watch` filetype for custom highlights)

## Installation

### Requirements

- Neovim >= 0.8.0
- [snacks.nvim](https://github.com/folke/snacks.nvim) (optional — for UI picker and input prompts; falls back to `vim.ui.select` and `vim.ui.input` when absent)

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Disable default keymaps before plugin loads (uncomment to use)
-- vim.g.bufstate_no_default_maps = 1

return {
  "syntaxpresso/bufstate.nvim",
  dependencies = { "folke/snacks.nvim" }, -- optional, for nicer UI
  opts = {
    -- LSP management
    stop_lsp_on_tab_leave = true,       -- Stop LSP when leaving a tab
    stop_lsp_on_session_load = true,    -- Stop all LSP before loading a session
    autoload_last_session = false,       -- Auto-load last session on startup

    -- Autosave
    autosave = {
      enabled = true,       -- Enable periodic background saves
      on_exit = true,       -- Save when exiting Neovim
      interval = 300000,    -- 5 minutes (in ms, 0 = disabled)
      debounce = 30000,     -- Minimum 30 seconds between saves
    },
  },

  -- Override default keymaps (uncomment to use)
  -- keys = {
  --   { "<leader>qs", "<cmd>BufstateSave<CR>",   desc = "Save session" },
  --   { "<leader>qS", "<cmd>BufstateSaveAs<CR>", desc = "Save session as" },
  --   { "<leader>ql", "<cmd>BufstateLoad<CR>",   desc = "Load session" },
  --   { "<leader>qd", "<cmd>BufstateDelete<CR>", desc = "Delete session" },
  --   { "<leader>qn", "<cmd>BufstateNew<CR>",    desc = "New session" },
  -- },
}

-- Bufferline integration (uncomment to use):
-- require("bufferline").setup({
--   options = {
--     always_show_bufferline = true,
--     custom_filter = require("bufstate").buf_filter,
--     close_command = function(buf)
--       require("bufstate").bdelete(buf)
--     end,
--   },
-- })
```

## Quick Start

### The tmux Workflow, Neovim Style

Instead of this:

```bash
tmux new -s myproject
tmux new -s work
tmux new -s personal
tmux attach -t myproject
```

Do this:

```vim
" Create workspaces (tabs)
:tabnew | tcd ~/projects/myproject
:tabnew | tcd ~/work
:tabnew | tcd ~/personal

" Save your workspace
:BufstateSave myworkspace

" Exit Neovim — session auto-saves on exit (VimLeavePre).
" Use :qall, close the terminal — whatever you prefer.

" Next day: restore instantly
:BufstateLoad myworkspace
" Or just open Neovim — auto-loads last session if configured!
```

### Basic Workflow

1. **Create workspaces:**

   ```vim
   :tabnew
   :tcd ~/projects/web-app
   :edit src/main.js

   :tabnew
   :tcd ~/projects/api
   :edit server.py
   ```

2. **Save your setup:**

   ```vim
   :BufstateSave fullstack
   ```

3. **Continue working:**
   - Make changes
   - Switch between tabs
   - Press `<leader>qs` to quick-save
   - Auto-saves happen every 5 minutes

4. **End of day / Tomorrow:**
   - Exit Neovim (`:qall`, close terminal, etc.) — session auto-saves on exit
   - Open Neovim
   - Everything auto-restores — tabs, buffers, window splits, even cursor positions

## Default Keymaps

| Keymap       | Command           | Description                                   |
| ------------ | ----------------- | --------------------------------------------- |
| `<leader>qs` | `:BufstateSave`   | Quick save (overwrites current session)       |
| `<leader>qS` | `:BufstateSaveAs` | Save as new session (prompts for name)        |
| `<leader>ql` | `:BufstateLoad`   | Load session (picker)                         |
| `<leader>qd` | `:BufstateDelete` | Delete session (picker)                       |
| `<leader>qn` | `:BufstateNew`    | New session (saves current, clears workspace) |
| `<leader>qc` | `:BufstateClose`  | Close workspace (save + clear buffers/tabs)   |

Disable all default keymaps:

```lua
vim.g.bufstate_no_default_maps = 1
```

## Commands

### Session Commands

| Command           | Arguments | Description                                    |
| ----------------- | --------- | ---------------------------------------------- |
| `:BufstateSave`   | `[name]`  | Save current session (overwrites if name given) |
| `:BufstateSaveAs` | `[name]`  | Save as new named session                       |
| `:BufstateLoad`   | `[name]`  | Load a session (shows picker if no name)        |
| `:BufstateDelete` | `[name]`  | Delete a session (shows picker if no name)      |
| `:BufstateNew`    | `[name]`  | Save current, then start a fresh workspace      |
| `:BufstateClose`  | None      | Save current and close workspace (clears buffers/tabs) |
| `:BufstateList`   | None      | List all sessions with timestamps and marker    |

### Safe Delete Commands

| Command      | Description                                         |
| ------------ | --------------------------------------------------- |
| `:Bdelete`   | Delete buffer without closing the tab               |
| `:Bwipeout`  | Wipeout buffer without closing the tab              |

In command-line mode, `:bd` auto-expands to `:Bdelete` and `:bw` auto-expands to `:Bwipeout`, matching only the exact bare commands (so `:bd!` and `:bdelete` still work as usual).

### Autosave Commands

| Command           | Description          |
| ----------------- | -------------------- |
| `:AutosaveStatus` | Show autosave status |
| `:AutosavePause`  | Pause autosave       |
| `:AutosaveResume` | Resume autosave      |
| `:AutosaveNow`    | Force immediate save |

### Debug Commands

| Command           | Description                                              |
| ----------------- | -------------------------------------------------------- |
| `:BufstateDebug`  | Print current tab-to-buffer ownership state              |
| `:BufstateWatch`  | Toggle a live-updating floating window showing state     |

## Lua API

The following functions are available on the public module:

```lua
local bufstate = require("bufstate")
```

### Buffer Filtering

```lua
bufstate.buf_filter(buf: integer) -> boolean
```

Returns whether `buf` belongs to the current tab. Wire into bufferline's `custom_filter` option so the tabline only shows buffers from the current workspace:

```lua
require("bufferline").setup({
  options = {
    always_show_bufferline = true,
    custom_filter = require("bufstate").buf_filter,
  },
})
```

### Safe Buffer Deletion

```lua
bufstate.bdelete(buf?: integer)   -- Safe bdelete, keeps tab alive
bufstate.bwipeout(buf?: integer)  -- Safe bwipeout, keeps tab alive
```

Can be wired into bufferline's `close_command` option. By default, bufferline uses `:bdelete` which closes the entire tab when it is the last buffer. bufstate's `bdelete` switches to another buffer first, keeping the tab (workspace) alive:

```lua
require("bufferline").setup({
  options = {
    always_show_bufferline = true,
    close_command = function(buf)
      require("bufstate").bdelete(buf)
    end,
  },
})
```

## How It Works

### Session Storage

Sessions are stored under Neovim's standard data directory at:

```
~/.local/share/nvim/bufstate-sessions/   (Linux)
~/AppData/Local/nvim-data/bufstate-sessions/   (Windows)
~/Library/Application Support/nvim/bufstate-sessions/   (macOS)
```

Two files per session:

- **`{name}.vim`** — Standard Neovim session file produced by `:mksession`. Contains buffer lists (`badd`), window layout, tab structure, `tcd` commands, and cursor positions. This file is fully self-contained and can be sourced by any Neovim instance with `:source {name}.vim`.

- **`{name}.bufstate.json`** — JSON sidecar tracking which buffers belong to which tab. Used to reconstruct per-tab buffer associations after a session loads. If missing (legacy sessions), bufstate falls back to the session file's window layout.

A third file `.last_loaded` stores the name of the most recently loaded session for the auto-load-on-startup feature.

### `_autosave` Fallback

When no session is active (e.g., a fresh Neovim instance with autosave enabled), unsaved workspaces are automatically saved under the name `_autosave`.

### Session Options

During save, bufstate temporarily ensures `sessionoptions` includes `buffers` and `tabpages` so `:mksession` captures the complete state. During load, it temporarily relaxes `winminwidth` and `winminheight` to avoid E592 errors, and closes floating windows to avoid E5601.

### Tab-Based Buffer Filtering

Buffer filtering is always active. When you enter a tab, only buffers associated with that tab are listed (`buflisted=true`). All other buffers are unlisted. When you leave a tab, all buffers are unlisted to prevent bleed between workspaces. This uses Neovim's native `buflisted` option, making it transparent to bufferline plugins, Telescope, fzf, and other tools.

## Configuration

```lua
require("bufstate").setup({
  -- Stop LSP clients when leaving a tab page
  stop_lsp_on_tab_leave = true,       -- Default: true

  -- Stop all LSP clients before loading a session
  stop_lsp_on_session_load = true,    -- Default: true

  -- Auto-load the last session on Neovim startup
  autoload_last_session = false,       -- Default: false

  -- Autosave settings
  autosave = {
    enabled = true,       -- Enable periodic background saves
    on_exit = true,       -- Save when exiting Neovim (VimLeavePre)
    interval = 300000,    -- Time between autosaves in ms (0 = disabled)
    debounce = 30000,     -- Minimum time between saves in ms
  },
})
```

If you call `setup()` with no arguments, all defaults are used. If you omit `autosave`, autosave is enabled by default.

### Configuration Examples

**Minimal (auto-save only):**

```lua
require("bufstate").setup({
  autoload_last_session = false,
  autosave = { enabled = true },
})
```

**tmux replacement mode:**

```lua
require("bufstate").setup({
  autoload_last_session = true,
  autosave = {
    enabled = true,
    on_exit = true,
    interval = 300000,
  },
})
```

**Manual-save only:**

```lua
require("bufstate").setup({
  autosave = { enabled = false },
})
```

## Comparison

### bufstate vs vim-obsession

| Feature                  | vim-obsession                       | bufstate.nvim                                      |
| ------------------------ | ----------------------------------- | -------------------------------------------------- |
| **Multiple sessions**    | No — one active session             | Yes — multiple named sessions                      |
| **Session switching**    | Manual load/save                    | Interactive picker with fuzzy search               |
| **Tab isolation**        | Basic (saves layout)                | Advanced: per-tab directories, buffer ownership    |
| **Buffer filtering**     | No                                  | Yes — tab-based via `buflisted`                    |
| **Focus restoration**    | No                                  | Yes — last active tab and buffer                   |
| **Order preservation**   | Partial                             | Yes — exact tab and buffer order                   |
| **Storage format**       | Vim session file (`.vim`)           | Same, with JSON sidecar for metadata               |
| **Auto-load on startup** | Manual                              | Yes — configurable                                 |
| **Auto-save**            | Continuous (every layout change)    | Configurable interval with debounce (5 min default) |
| **Session metadata**     | No                                  | Yes — timestamps, tab-to-buffer map                |

Use vim-obsession for a minimal, single-session workflow. Use bufstate for multiple projects, instant switching, and smart buffer filtering.

### bufstate vs vim-ctrlspace

| Feature                  | vim-ctrlspace                            | bufstate.nvim                                   |
| ------------------------ | ---------------------------------------- | ----------------------------------------------- |
| **Platform**             | Vim + Neovim                             | Neovim-first                                   |
| **Dependencies**         | Go binary, Python (optional)             | snacks.nvim optional (vim.ui fallback)          |
| **Complexity**           | Feature-heavy (buffers, files, bookmarks, workspaces) | Focused on sessions and tab filtering           |
| **Session format**       | Custom Vim format                        | Native `:mksession` (`.vim`)                   |
| **Window splits**        | Limited                                  | Full support via `:mksession`                  |
| **Buffer per tab**       | Custom implementation                    | Native `buflisted` (plugin-friendly)           |
| **Order preservation**   | Not emphasized                           | Core feature                                   |
| **UI**                   | Custom window                            | snacks.nvim picker or vim.ui.select            |
| **Learning curve**       | Steep (many concepts)                    | Gentle (familiar Neovim concepts)              |

Use vim-ctrlspace for an all-in-one workspace system with built-in file search and bookmarks. Use bufstate for a focused session manager that integrates with your existing tools.

### bufstate vs tmux

| Feature                   | tmux                      | bufstate.nvim                        |
| ------------------------- | ------------------------- | ------------------------------------ |
| **Workspace isolation**   | Sessions                  | Tab-based sessions                   |
| **Persistent state**      | tmux-resurrect needed     | Built-in, automatic                  |
| **Auto-save**             | Manual plugin required    | Native, configurable                 |
| **Buffer management**     | N/A                       | Smart filtering per tab              |
| **Context preservation**  | Window layout only        | Tabs, buffers, cursors, order        |
| **Startup speed**         | Needs attach              | Auto-loads instantly                 |
| **Terminal multiplexing** | Yes                       | Use tabs + terminal buffers          |
| **Remote sessions**       | Yes                       | Local only                           |

Use bufstate instead of tmux when you work primarily in Neovim and want automatic session management. Use tmux when you need remote sessions or multiplexing outside Neovim. You can use both together — run Neovim with bufstate inside a tmux session.

## Usage Examples

### Example 1: Multi-Project Developer

```vim
" Morning: Load your saved workspace
:BufstateLoad daily-work

" Workspace has 3 tabs:
" Tab 1: Frontend (/projects/web-app)
" Tab 2: Backend (/projects/api)
" Tab 3: Documentation (/projects/docs)

" Work all day, auto-saves every 5 minutes
" Quick saves with <leader>qs when needed

" Evening: Just quit — everything auto-saves
:qa
```

### Example 2: Context Switching

```vim
" Working on feature-A
:BufstateSave feature-a

" Emergency: switch to bugfix
:BufstateNew bugfix
:tcd ~/projects/app
:edit src/auth.js
" Fix bug...
:BufstateSave bugfix

" Back to feature-A
:BufstateLoad feature-a
" Exactly where you left off!
```

### Example 3: Client Projects

```vim
" Setup workspaces for different clients
:tabnew | tcd ~/clients/acme/web
:tabnew | tcd ~/clients/acme/api
:BufstateSave acme

:BufstateNew globex
:tabnew | tcd ~/clients/globex/app
:BufstateSave globex

" Switch between clients instantly
:BufstateLoad acme    " All ACME tabs
:BufstateLoad globex  " All Globex tabs
```

## Tips

1. **Use descriptive session names** — `ecommerce-redesign` is better than `project1`.
2. **One session per project context** — Frontend + Backend = one session. Different features = different sessions.
3. **Leverage auto-load** — Set `autoload_last_session = true` and opening Neovim puts you right back to work.
4. **Quick save often** — `<leader>qs` becomes muscle memory. Auto-save is backup, manual save is intentional.
5. **Use tabs for logical separation** — One tab per area of concern. Different repositories = different tabs.
6. **Use `:Bdelete` instead of `:bdelete`** — It will never close your tab, even if it's the last buffer.
7. **Check the watch window** — `:BufstateWatch` helps understand buffer-to-tab associations when debugging.

## Contributing

Issues and pull requests welcome at the [GitHub repository](https://github.com/syntaxpresso/bufstate.nvim).

## Acknowledgments

- [snacks.nvim](https://github.com/folke/snacks.nvim) — Optional UI components
- [vim-obsession](https://github.com/tpope/vim-obsession) — Session management inspiration
- [vim-ctrlspace](https://github.com/vim-ctrlspace/vim-ctrlspace) — Workspace management inspiration
- [tmux](https://github.com/tmux/tmux) — Persistent workspace inspiration
