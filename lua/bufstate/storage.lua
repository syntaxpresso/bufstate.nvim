-- lua/bufstate/storage.lua
-- File I/O for bufstate.nvim session files (.vim format via :mksession).

local M = {}

local uv = vim.uv or vim.loop

-- ── paths ─────────────────────────────────────────────────────────────────────

function M.session_dir()
  local dir = vim.fn.stdpath("data") .. "/bufstate-sessions"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

function M.session_path(name)
  return M.session_dir() .. "/" .. name .. ".vim"
end

function M.last_loaded_path()
  return M.session_dir() .. "/.last_loaded"
end

-- ── session files ─────────────────────────────────────────────────────────────

--- Save current Neovim state to a named session file.
---@param name string
function M.save(name)
  local path = M.session_path(name)
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(path))
  if not ok then
    error("Failed to save session '" .. name .. "': " .. (err or "unknown error"))
  end
  return true
end

--- Source a named session file.
---@param name string
---@return boolean ok, string|nil err
function M.load(name)
  local path = M.session_path(name)
  if vim.fn.filereadable(path) == 0 then
    return false, "Session not found: " .. name
  end

  -- Close all floating windows before sourcing. The session file contains an
  -- `only` command that closes all but one window; if the only remaining window
  -- is a floating one Neovim raises E5601. Closing floats first avoids this.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  -- Temporarily relax window size constraints to avoid E592 during source
  local save_winminwidth  = vim.o.winminwidth
  local save_winminheight = vim.o.winminheight
  vim.o.winminwidth  = 0
  vim.o.winminheight = 0

  local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(path))

  -- Restore to sane minimums before re-applying saved mins
  vim.o.winwidth  = math.max(vim.o.winwidth,  20)
  vim.o.winheight = math.max(vim.o.winheight, 5)
  vim.o.winminwidth  = save_winminwidth
  vim.o.winminheight = save_winminheight

  if not ok then
    return false, "Failed to load session '" .. name .. "': " .. (err or "unknown error")
  end
  return true
end

--- Delete a named session file.
---@param name string
---@return boolean ok, string|nil err
function M.delete(name)
  local path = M.session_path(name)
  if vim.fn.filereadable(path) == 0 then
    return false, "Session not found: " .. name
  end
  vim.fn.delete(path)
  return true
end

--- List all saved sessions, sorted by modification time (newest first).
---@return { name: string, path: string, mtime: integer }[]
function M.list()
  local files = vim.fn.glob(M.session_dir() .. "/*.vim", false, true)
  local sessions = {}
  for _, file in ipairs(files) do
    local stat = uv.fs_stat(file)
    sessions[#sessions + 1] = {
      name  = vim.fn.fnamemodify(file, ":t:r"),
      path  = file,
      mtime = stat and stat.mtime.sec or 0,
    }
  end
  table.sort(sessions, function(a, b) return a.mtime > b.mtime end)
  return sessions
end

-- ── session metadata (for UI preview) ────────────────────────────────────────

--- Parse a session .vim file and extract human-readable metadata.
--- Returns a table with:
---   tab_count  integer
---   buffers    string[]   (raw paths from `badd` lines)
---   cwd_list   string[]   (paths from `tcd` lines, one per tab)
---@param name string
---@return { tab_count: integer, buffers: string[], cwd_list: string[] }|nil
function M.parse_session_metadata(name)
  local path = M.session_path(name)
  local file = io.open(path, "r")
  if not file then return nil end

  local metadata = {
    buffers  = {},
    cwd_list = {},
    tab_count = 1,
  }
  local tabnew_count = 0

  for line in file:lines() do
    local buf_path = line:match("^badd %+%d+ (.+)$")
    if buf_path then
      metadata.buffers[#metadata.buffers + 1] = buf_path
    end

    local tcd_path = line:match("^tcd (.+)$")
    if tcd_path then
      metadata.cwd_list[#metadata.cwd_list + 1] = tcd_path
    end

    if line:match("^tabnew") then
      tabnew_count = tabnew_count + 1
    end
  end

  file:close()
  metadata.tab_count = tabnew_count + 1
  return metadata
end

-- ── last-loaded tracking ──────────────────────────────────────────────────────

function M.save_last_loaded(name)
  local f = io.open(M.last_loaded_path(), "w")
  if not f then return false end
  f:write(name)
  f:close()
  return true
end

function M.get_last_loaded()
  local f = io.open(M.last_loaded_path(), "r")
  if not f then return nil end
  local name = f:read("*all")
  f:close()
  return name ~= "" and name or nil
end

return M
