# bufstate.nvim

A Neovim plugin for managing tab-based workspace sessions with intelligent buffer filtering. Save and restore your tab layouts with their respective working directories and buffer lists.

## Features

- **Tab-based buffer filtering** - Only show buffers relevant to the current tab
- Save current tab layout with all tab-local directories
- Save and restore all open buffers per tab with cursor positions
- **Timestamp-based focus restoration** - Opens the most recently used tab and buffer
- Restore saved sessions with automatic tab recreation
- Interactive session picker powered by [snacks.nvim](https://github.com/folke/snacks.nvim)
- Autosave functionality with configurable intervals
- Session tracking - autosaves update the current session
- Sessions stored as JSON files for easy inspection and portability
- Tab completion for session names
- Preview pane showing session details and buffer list

## Requirements

- Neovim >= 0.8.0
- [snacks.nvim](https://github.com/folke/snacks.nvim) (for UI components)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "syntaxpresso/bufstate.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    filter_by_tab = true,        -- Enable tab-based buffer filtering (default: true)
    autoload_last_session = false,  -- Auto-load latest session on startup (default: false)
    autosave = {
      enabled = true,      -- Enable autosave (default: true)
      on_exit = true,      -- Save on VimLeavePre (default: true)
      interval = 300000,   -- Auto-save every 5 minutes (default: 300000ms)
      debounce = 30000,    -- Min time between saves (default: 30000ms)
    }
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "syntaxpresso/bufstate.nvim",
  requires = { "folke/snacks.nvim" },
  config = function()
    require("bufstate").setup()
  end,
}
```

## Usage

### Tab-Based Buffer Filtering

**New in v3:** Bufstate now automatically filters buffers based on the current tab, showing only buffers that belong to the active tab. This keeps your buffer lists clean and relevant.

**How it works:**
- Buffers are associated with tabs based on:
  - Being visible in a window of that tab, OR
  - Having a file path under the tab's working directory (`cwd`)
- When switching tabs, only relevant buffers appear in buffer lists (`:ls`, `:buffers`)
- Controlled via `vim.bo.buflisted` - transparent to other plugins

**Configuration:**
```lua
require("bufstate").setup({
  filter_by_tab = true,  -- Default: true, set to false to disable
})
```

**Behavior on session restore:**
- All buffers from all tabs are loaded
- The most recently active tab (by timestamp) is focused
- Within that tab, the most recently active buffer is focused
- Only the current tab's buffers are listed initially
- Switch tabs to see different buffer lists

### Migration from v2 to v3

**BREAKING CHANGE:** Version 3 introduces timestamp-based session management and tab filtering.

**Action Required:**
- Existing sessions (v2) will continue to work for loading
- However, you must **re-save your sessions** to enable new features:
  - Timestamp tracking
  - Tab-based buffer filtering
  - Latest session auto-loading

**How to migrate:**
1. Load your existing session: `:LoadSession <name>`
2. Re-save it: `:SaveSession <name>`
3. Repeat for all sessions you want to keep

Old session files remain compatible for reading but won't have timestamps or filtering until re-saved.

### Commands

- `:SaveSession [name]` - Save current workspace session
  - Without argument: Opens `snacks.input` prompt for session name
  - With argument: Saves session with the provided name

- `:LoadSession [name]` - Load a saved session
  - Without argument: Opens `snacks.picker` to select session
  - With argument: Loads the specified session

- `:DeleteSession [name]` - Delete a session
  - Without argument: Opens `snacks.picker` to select session to delete
  - With argument: Deletes the specified session

- `:ListSessions` - Print all available sessions to command line

**Autosave Commands:**

- `:AutosaveStatus` - Show autosave status and current session
- `:AutosavePause` - Pause autosave temporarily
- `:AutosaveResume` - Resume autosave
- `:AutosaveNow` - Trigger an immediate autosave

### Default Keymaps

The plugin provides default keymaps for common operations:

- `<leader><tab>s` - Save session (opens input prompt)
- `<leader><tab>l` - Load session (opens picker)
- `<leader><tab>d` - Delete session (opens picker)

To disable default keymaps, add to your config before the plugin loads:

```lua
vim.g.bufstate_no_default_maps = 1
```

Or in VimScript:

```vim
let g:bufstate_no_default_maps = 1
```

Then set your own keymaps:

```lua
vim.keymap.set('n', '<your-key>', ':SaveSession<CR>')
vim.keymap.set('n', '<your-key>', ':LoadSession<CR>')
vim.keymap.set('n', '<your-key>', ':DeleteSession<CR>')
```

### Example Workflow

```vim
" Open multiple tabs with different projects
:tabnew
:tcd ~/projects/project-a
:tabnew
:tcd ~/projects/project-b
:tabnew
:tcd ~/projects/project-c

" Save the current layout
:SaveSession
" (Enter name in the prompt, e.g., "my-workspace")

" Later, restore your workspace
:LoadSession
" (Select "my-workspace" from the picker)
```

### Lua API

```lua
local ws = require("bufstate")

-- Save session
ws.save("my-session")       -- Save with name
ws.save()                   -- Prompt for name

-- Load session
ws.load("my-session")       -- Load specific session
ws.load()                   -- Show picker

-- Delete session
ws.delete("my-session")     -- Delete specific session
ws.delete()                 -- Show picker

-- List all sessions
ws.list()                   -- Print to command line

-- Get all sessions programmatically
local storage = require("bufstate.storage")
local sessions = storage.list()

-- Autosave functions
ws.autosave()               -- Trigger autosave now
ws.autosave_pause()         -- Pause autosave
ws.autosave_resume()        -- Resume autosave
ws.autosave_status()        -- Show autosave status
ws.get_current_session()    -- Get current session name
```

## Autosave

The plugin includes intelligent autosave functionality that automatically saves your workspace:

### How Autosave Works

- **Session Tracking**: The plugin tracks the currently loaded or saved session
- **Smart Targeting**: Autosave updates the current session (defaults to `_autosave` if no session loaded)
- **On Exit**: Automatically saves when you quit Neovim (if enabled)
- **Periodic**: Optionally saves at regular intervals (default: 5 minutes)
- **Debouncing**: Won't save too frequently (minimum 30 seconds between saves)
- **Silent**: Runs in the background without notifications

### Autosave Behavior

```
Scenario 1: Fresh Neovim, no session loaded
  → Autosaves to "_autosave"

Scenario 2: User saves session as "myproject"
  → Autosaves to "myproject" from now on

Scenario 3: User loads session "work"
  → Autosaves to "work" from now on

Scenario 4: User deletes current session
  → Falls back to "_autosave"
```

### Configuration

```lua
require("bufstate").setup({
  autosave = {
    enabled = true,      -- Enable/disable autosave (default: true)
    on_exit = true,      -- Save on VimLeavePre (default: true)
    interval = 300000,   -- Auto-save interval in ms (default: 5 min, 0 to disable)
    debounce = 30000,    -- Minimum time between saves in ms (default: 30 sec)
  }
})
```

### Autosave Commands

- `:AutosaveStatus` - View current session and last save time
- `:AutosavePause` - Temporarily disable autosave
- `:AutosaveResume` - Re-enable autosave
- `:AutosaveNow` - Force an immediate autosave

## How It Works

1. **Saving**: Captures the tab-local directory (`tcd`), all open buffers, and timestamps for each tab
2. **Storage**: Sessions saved as JSON files in `~/.local/share/nvim/bufstate-sessions/`
   - Individual session files (e.g., `myproject.json`)
   - Metadata file (`sessions.json`) for tracking timestamps
3. **Loading**: 
   - Closes all tabs/buffers
   - Recreates tabs with saved directories
   - Loads all buffers with `buflisted=false` initially
   - Finds and focuses the most recently active tab (by timestamp)
   - Finds and focuses the most recently active buffer in that tab
   - Sets `buflisted=true` only for the current tab's buffers
4. **Tab Filtering**: Buffers automatically filter based on current tab
   - Associated by: visible in tab OR path under tab's `cwd`
   - Updates on `TabEnter`, `TabLeave`, `TabClosed`, and `BufEnter` events
5. **Autosave**: Automatically updates the current session in the background

## Session File Format

Sessions are stored as JSON files with the following structure (v3):

```json
{
  "version": 3,
  "timestamp": 1699564800,
  "tabs": [
    {
      "index": 1,
      "cwd": "/home/user/project-a",
      "timestamp": 1699564850,
      "buffers": [
        { 
          "path": "main.rs", 
          "line": 42, 
          "col": 10,
          "timestamp": 1699564900
        },
        { 
          "path": "lib.rs", 
          "line": 1, 
          "col": 1,
          "timestamp": 1699564880
        }
      ]
    },
    {
      "index": 2,
      "cwd": "/home/user/project-b",
      "timestamp": 1699564820,
      "buffers": [
        { 
          "path": "index.js", 
          "line": 15, 
          "col": 5,
          "timestamp": 1699564840
        }
      ]
    }
  ]
}
```

**Metadata file** (`sessions.json`):
```json
{
  "sessions": [
    { "name": "myproject", "timestamp": 1699564900 },
    { "name": "work", "timestamp": 1699564800 }
  ]
}
```

## Configuration

The plugin works out of the box with sensible defaults. Available configuration options:

```lua
require("bufstate").setup({
  filter_by_tab = true,           -- Enable tab-based buffer filtering (default: true)
  autoload_last_session = false,  -- Auto-load latest session on startup (default: false)
  autosave = {
    enabled = true,      -- Enable autosave feature
    on_exit = true,      -- Save when exiting Neovim
    interval = 300000,   -- Auto-save every 5 minutes (0 to disable periodic saves)
    debounce = 30000,    -- Minimum 30 seconds between saves
  }
})
```

### Tab Filtering

Enable or disable tab-based buffer filtering:

```lua
require("bufstate").setup({
  filter_by_tab = true,  -- Default: true
})
```

When enabled:
- Only buffers belonging to the current tab appear in `:ls` and `:buffers`
- Switching tabs automatically updates which buffers are listed
- Buffers are associated based on being visible in the tab OR having a path under the tab's `cwd`

### Auto-load Last Session

Enable `autoload_last_session` to automatically load your most recently saved session (by timestamp) when Neovim starts:

```lua
require("bufstate").setup({
  autoload_last_session = true,
})
```

This will restore the latest session you saved every time you open Neovim without arguments, making it easy to pick up where you left off.

### Disable Autosave

To disable autosave completely:

```lua
require("bufstate").setup({
  autosave = {
    enabled = false,
  }
})
```

## Tips

- Use descriptive session names for easy identification
- Sessions are sorted by timestamp (most recent first)
- Tab completion works for all commands that accept session names
- Session files can be manually edited or version controlled
- The `_autosave` session is automatically created if you don't save/load a session
- Use `:AutosaveStatus` to see which session is currently being autosaved
- Pause autosave with `:AutosavePause` when doing temporary work
- **Tab filtering**: Switch tabs to see different buffer lists - only current tab's buffers are shown
- Buffers from all tabs are always loaded, just filtered from view
- To disable filtering temporarily, use `:lua require("bufstate.tabfilter").update_buflisted = function() end`

## Contributing

Issues and pull requests are welcome!
