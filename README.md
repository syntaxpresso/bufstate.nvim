<div align="center">

![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/built%20with-Lua-blue?logo=lua)
![License](https://img.shields.io/badge/license-MIT-blue)

</div>

## Why bufstate?

Stop juggling between tmux sessions and Neovim. **bufstate.nvim** brings the power of persistent workspaces directly into Neovim, giving you:

- **🎯 Tab-based workspaces** - Each tab is an isolated workspace with its own working directory
- **💾 Persistent sessions** - Save and restore your entire workspace layout instantly
- **🧠 Smart buffer filtering** - Only see buffers related to your current tab
- **⚡ Auto-save everything** - Never lose your workspace state again
- **🎨 Order preservation** - Tabs and buffers restore in exactly the same order
- **🔄 Context switching** - Jump between projects faster than tmux sessions

**Think of it as:** tmux sessions + vim-obsession.

## ✨ Features

### Core Capabilities

- **Workspace Isolation**
  - Each tab = one project/workspace
  - Tab-local working directories (`tcd`)
  - Automatic buffer-to-tab association
  - Clean buffer lists per workspace

- **Session Management**
  - Quick save current session (`<leader>qs`)
  - Save as new session (`<leader>qS`)
  - Instant session switching with picker
  - Auto-load last session on startup

- **Intelligent State Tracking**
  - Preserves exact tab order
  - Preserves exact buffer order per tab
  - Restores cursor positions
  - Focuses last active tab and buffer automatically

- **Auto-save System**
  - Background saves every 5 minutes
  - Debounced to prevent excessive I/O
  - Updates current session automatically
  - Saves on exit (optional)

- **Tab-based Buffer Filtering**
  - Only show buffers belonging to current tab
  - Automatic filtering via `vim.bo.buflisted`
  - Works seamlessly with any buffer plugin
  - Updates instantly on tab switch

## 📦 Installation

### Requirements

- Neovim >= 0.8.0
- [snacks.nvim](https://github.com/folke/snacks.nvim) (for UI)

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "syntaxpresso/bufstate.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    filter_by_tab = true,           -- Enable tab-based buffer filtering
    autoload_last_session = true,   -- Auto-load latest session on startup
    autosave = {
      enabled = true,      -- Enable autosave
      on_exit = true,      -- Save on exit
      interval = 300000,   -- Auto-save every 5 minutes
      debounce = 30000,    -- Min 30s between saves
    }
  },
}
```

## 🚀 Quick Start

### The tmux Workflow, Neovim Style

**Instead of this (tmux):**

```bash
tmux new -s myproject
tmux new -s work
tmux new -s personal
tmux attach -t myproject
```

**Do this (bufstate):**

```vim
" Create workspaces (tabs)
:BufstateNew
:tabnew | tcd ~/projects/myproject
:tabnew | tcd ~/work
:tabnew | tcd ~/personal

" Save your workspace
:BufstateSave myworkspace

" Next day: restore instantly
:BufstateLoad myworkspace
" Or just open Neovim - auto-loads last session!
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
   - Auto-saves every 5 minutes

4. **Tomorrow:**
   - Open Neovim
   - Everything auto-restores, even your cursor position!

## ⌨️ Default Keymaps

| Keymap       | Command           | Description                                   |
| ------------ | ----------------- | --------------------------------------------- |
| `<leader>qs` | `:BufstateSave`   | Quick save (overwrites current session)       |
| `<leader>qS` | `:BufstateSaveAs` | Save as new session (prompts for name)        |
| `<leader>ql` | `:BufstateLoad`   | Load session (picker)                         |
| `<leader>qd` | `:BufstateDelete` | Delete session (picker)                       |
| `<leader>qn` | `:BufstateNew`    | New session (saves current, clears workspace) |

**Disable defaults:**

```lua
vim.g.bufstate_no_default_maps = 1
```

## 📚 Commands

### Core Commands

| Command           | Arguments | Description                       |
| ----------------- | --------- | --------------------------------- |
| `:BufstateSave`   | None      | Save current session (overwrites) |
| `:BufstateSaveAs` | `[name]`  | Save as new session               |
| `:BufstateLoad`   | `[name]`  | Load session                      |
| `:BufstateDelete` | `[name]`  | Delete session                    |
| `:BufstateList`   | None      | List all sessions                 |
| `:BufstateNew`    | `[name]`  | New session                       |

### Autosave Commands

| Command           | Description          |
| ----------------- | -------------------- |
| `:AutosaveStatus` | Show autosave status |
| `:AutosavePause`  | Pause autosave       |
| `:AutosaveResume` | Resume autosave      |
| `:AutosaveNow`    | Force immediate save |
