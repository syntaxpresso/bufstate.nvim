<div align="center">
  <img width="500" alt="syntaxpresso" src="https://github.com/user-attachments/assets/be0749b2-1e53-469c-8d99-012024622ade" />
</div>

<div align="center">
  <img alt="neovim" src="https://img.shields.io/badge/NeoVim-%2357A143.svg?&logo=neovim&logoColor=white" />
  <img alt="lua" src="https://img.shields.io/badge/built%20with-Lua-blue?logo=lua" />
</div>

## Why bufstate?

Stop juggling between tmux sessions and Neovim. **bufstate.nvim** brings the power of persistent workspaces directly into Neovim, giving you:

- **🎯 Tab-based workspaces** - Each tab is an isolated workspace with its own working directory
- **💾 Persistent sessions** - Save and restore your entire workspace layout instantly (including window splits!)
- **🧠 Smart buffer filtering** - Only see buffers relevant to your current tab
- **⚡ Auto-save everything** - Never lose your workspace state again
- **🎨 Order preservation** - Tabs and buffers restore in exactly the same order
- **🪟 Window splits** - Restore your exact window layout using Neovim's native `:mksession`
- **🔄 Context switching** - Jump between projects faster than tmux sessions

**Think of it as:** tmux sessions + vim-obsession.

https://github.com/user-attachments/assets/9162f9a5-8576-4f95-b01b-0f2a1ab10f17

### What Makes bufstate Different?

Unlike **vim-obsession** (which wraps Vim's `:mksession`) or **vim-ctrlspace** (which is a feature-heavy workspace ecosystem):

- ✅ **Zero external dependencies** (except snacks.nvim for UI)
- ✅ **Focused on doing one thing well** - session management with tab filtering
- ✅ **Neovim-native** - Built with modern Lua APIs and `:mksession`
- ✅ **Native vim sessions** - Uses Neovim's powerful built-in session format
- ✅ **Smart state tracking** - Remembers last active tab/buffer with timestamps
- ✅ **Order preservation** - Exact tab and buffer order and cursor position, always
- ✅ **Window splits** - Full window layout restoration via `:mksession`
- ✅ **Integrates seamlessly** - Works with Telescope, statusline plugins, etc

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

## 🆚 Comparison with Other Session Managers

### bufstate vs vim-obsession

| Feature                  | vim-obsession                       | bufstate.nvim                                      |
| ------------------------ | ----------------------------------- | -------------------------------------------------- |
| **Approach**             | Wraps Vim's `:mksession`            | **Uses `:mksession` with enhanced workflow**       |
| **Multiple sessions**    | ❌ One active session               | ✅ Multiple named sessions                         |
| **Session switching**    | ❌ Manual load/save                 | ✅ Interactive picker with fuzzy search            |
| **Auto-save**            | ✅ Continuous (every layout change) | ✅ Configurable intervals (5 min default)          |
| **Tab support**          | ⚠️ Basic (saves layout)             | ✅ **Advanced**: Order, timestamps, tab-local dirs |
| **Buffer management**    | ⚠️ Saves open buffers               | ✅ **Order, positions, timestamps per tab**        |
| **Buffer filtering**     | ❌ None                             | ✅ **Tab-based filtering via `buflisted`**         |
| **Focus restoration**    | ❌ No                               | ✅ **Last active tab + buffer**                    |
| **Order preservation**   | ⚠️ Partial                          | ✅ **Exact tab and buffer order**                  |
| **Window splits**        | ✅ Yes                              | ✅ **Yes** (via `:mksession`)                      |
| **Session metadata**     | ❌ None                             | ✅ Timestamps via filesystem mtime                 |
| **Auto-load on startup** | ❌ Manual                           | ✅ Configurable                                    |
| **Storage format**       | Vim session file (`.vim`)           | ✅ **Same** (Vim session `.vim`)                   |
| **Project isolation**    | ❌ No concept                       | ✅ **Tab-local working directories**               |

**Use vim-obsession if you want:**

- ✅ Minimal, lightweight solution
- ✅ Single session workflow
- ✅ Vim's native session format
- ✅ "Set and forget" continuous save

**Use bufstate if you want:**

- ✅ **Multiple projects with instant switching**
- ✅ **Tab-based workspace isolation**
- ✅ **Smart buffer filtering**
- ✅ **Exact state restoration (order, focus, positions)**

---

### bufstate vs vim-ctrlspace

| Feature                  | vim-ctrlspace                                                  | bufstate.nvim                                   |
| ------------------------ | -------------------------------------------------------------- | ----------------------------------------------- |
| **Platform**             | Vim + Neovim                                                   | ✅ **Neovim-first** (modern API)                |
| **Dependencies**         | ⚠️ Go file engine binary                                       | ✅ **Zero external deps** (except snacks.nvim)  |
| **Complexity**           | ⚠️ Feature-heavy (buffers, files, tabs, workspaces, bookmarks) | ✅ **Focused** (sessions + tab filtering)       |
| **Buffer lists**         | ✅ Per-tab buffer lists                                        | ✅ **Same, via `buflisted`** (more transparent) |
| **File browser**         | ✅ Built-in fuzzy search                                       | ❌ Use Telescope/fzf instead                    |
| **Bookmarks**            | ✅ Project bookmarks                                           | ❌ Use sessions instead                         |
| **Workspace management** | ✅ Save/load workspaces                                        | ✅ **Same** (called sessions)                   |
| **Auto-save**            | ⚠️ Manual or via events                                        | ✅ **Built-in, configurable**                   |
| **Tab management**       | ✅ Advanced (move, copy, name)                                 | ⚠️ **Standard Neovim tabs**                     |
| **Session format**       | Custom Vim format                                              | ✅ **Native Vim sessions** (`.vim`)             |
| **Window splits**        | ⚠️ Limited                                                     | ✅ **Full support** (via `:mksession`)          |
| **Tab filtering**        | ⚠️ Custom implementation                                       | ✅ **Native `buflisted`** (plugin-friendly)     |
| **UI**                   | ⚠️ Custom window                                               | ✅ **snacks.nvim picker** (modern)              |
| **Learning curve**       | ⚠️ Steep (many concepts)                                       | ✅ **Gentle** (familiar Neovim)                 |
| **Order preservation**   | ❌ Not emphasized                                              | ✅ **Core feature**                             |
| **Timestamp tracking**   | ❌ No                                                          | ✅ **Smart focus restoration**                  |

**Use vim-ctrlspace if you want:**

- ✅ All-in-one workspace solution
- ✅ Built-in fuzzy file search
- ✅ Project bookmarks feature
- ✅ Advanced tab manipulation (rename, move, copy)
- ✅ Don't mind external dependencies and complexity

**Use bufstate if you want:**

- ✅ **Simple, focused tool**
- ✅ **Zero external dependencies**
- ✅ **Modern Neovim integration**
- ✅ **Works with existing tools** (Telescope, etc.)
- ✅ **Minimal learning curve**

---

### bufstate vs tmux

| Feature                   | tmux                      | bufstate.nvim                        |
| ------------------------- | ------------------------- | ------------------------------------ |
| **Workspace isolation**   | ✅ Sessions               | ✅ Tab-based sessions                |
| **Persistent state**      | ✅ tmux-resurrect needed  | ✅ **Built-in, automatic**           |
| **Auto-save**             | ❌ Manual plugin required | ✅ **Native, configurable**          |
| **Buffer management**     | ❌ N/A                    | ✅ **Smart filtering per tab**       |
| **Context preservation**  | ⚠️ Window layout only     | ✅ **Tabs, buffers, cursors, order** |
| **Startup speed**         | ⚠️ Needs attach           | ✅ **Auto-loads instantly**          |
| **Integration**           | ⚠️ Separate tool          | ✅ **Native Neovim**                 |
| **Terminal multiplexing** | ✅ Yes                    | ❌ Use tabs + terminal buffers       |
| **Remote sessions**       | ✅ Yes                    | ❌ Local only                        |
| **Learning curve**        | ⚠️ Moderate               | ✅ **Minimal** (if you know Neovim)  |

**When to use bufstate instead of tmux:**

- ✅ You work primarily in Neovim
- ✅ You want automatic session management
- ✅ You prefer tab-based workflows
- ✅ You want intelligent buffer filtering
- ✅ You work on a single machine

**When to stick with tmux:**

- ✅ You need remote session persistence
- ✅ You use multiple terminal applications
- ✅ You need terminal multiplexing outside Neovim

**Pro tip:** You can use both! Run Neovim with bufstate inside a tmux session for the best of both worlds.

---

## 🎓 Usage Examples

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

" Evening: Just quit - everything auto-saves
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

## ⚙️ Configuration

### Full Configuration

```lua
require("bufstate").setup({
  -- Tab-based buffer filtering
  filter_by_tab = true,           -- Default: true

  -- Auto-load last session on startup
  autoload_last_session = true,   -- Default: false

  -- Autosave configuration
  autosave = {
    enabled = true,      -- Enable autosave feature
    on_exit = true,      -- Save when exiting Neovim
    interval = 300000,   -- Auto-save every 5 minutes (0 = disabled)
    debounce = 30000,    -- Minimum 30 seconds between saves
  }
})
```

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
  filter_by_tab = true,
  autoload_last_session = true,
  autosave = {
    enabled = true,
    on_exit = true,
    interval = 300000,  -- 5 minutes
  }
})
```

**Manual-save only:**

```lua
require("bufstate").setup({
  filter_by_tab = true,
  autosave = { enabled = false },
})
```

## 💡 Tips & Tricks

1. **Use descriptive session names**
   - ✅ `ecommerce-redesign`
   - ❌ `project1`

2. **One session per project context**
   - Frontend + Backend = one session
   - Different features = different sessions

3. **Leverage auto-load**
   - Set `autoload_last_session = true`
   - Just open Neovim - you're ready to work

4. **Quick save often**
   - `<leader>qs` becomes muscle memory
   - Auto-save is backup, manual save is intentional

5. **Use tabs for logical separation**
   - One tab = one area of concern
   - Different repositories = different tabs

## 🤝 Contributing

Issues and pull requests welcome!

[Report Bug](https://github.com/syntaxpresso/bufstate.nvim/issues) · [Request Feature](https://github.com/syntaxpresso/bufstate.nvim/issues)

## 🙏 Acknowledgments

- [snacks.nvim](https://github.com/folke/snacks.nvim) - UI components
- [vim-obsession](https://github.com/tpope/vim-obsession) - Session inspiration
- [vim-ctrlspace](https://github.com/vim-ctrlspace/vim-ctrlspace) - Workspace management inspiration
- [tmux](https://github.com/tmux/tmux) - Persistent workspace inspiration

---
