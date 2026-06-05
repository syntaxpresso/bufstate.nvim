-- lua/bufstate/session.lua
-- High-level session operations: save, load, delete, list, new.
-- Uses storage.lua for I/O; has no dependency on bufstate.nvim's state or filter
-- logic (those run automatically via autocmds when buffers are opened).
--
-- save_fn is injected by init.lua during setup() via set_save_fn(). It wraps
-- storage.save() with a relist-all-bufs step so that :mksession records buffers
-- from every tab (not just the currently-listed ones). Falls back to a plain
-- storage.save() if called before setup (e.g. in tests).

local storage = require("bufstate.storage")

local M = {}

-- Current session name (nil = unsaved / no session active)
M.current = nil

-- Previously active session name (nil = no alternate to switch to)
M.previous = nil

-- Injected by init.lua; wraps storage.save() with the buflisted relist sandwich
local save_fn = nil

--- Set the save implementation. Called once by init.lua during M.setup().
--- fn(name) must raise on failure and update session.current.
---@param fn fun(name: string)
function M.set_save_fn(fn)
	save_fn = fn
end

-- ── helpers ───────────────────────────────────────────────────────────────────

--- Wipe all normal (non-terminal, non-scratch) buffers, listed or not.
--- Called before sourcing a new session so that badd/edit in the session
--- file always create fresh buffers and fire BufAdd/BufReadPost correctly.
local function clear_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
			pcall(vim.cmd, "bwipeout! " .. buf)
		end
	end
end

-- ── public API ────────────────────────────────────────────────────────────────

--- Save the current workspace to `name`.
--- Routes through save_fn (injected by init.lua) so that all known buffers are
--- temporarily relisted before :mksession runs. Falls back to storage.save()
--- if save_fn hasn't been set yet (e.g. standalone tests).
---@param name string
function M.save(name)
	assert(type(name) == "string" and name ~= "", "session name required")
	if save_fn then
		save_fn(name) -- raises on failure; also sets session.current and restores filter
	else
		storage.save(name) -- raises on failure
		M.current = name
	end
	return true
end

--- Load a named session, saving the current one first.
---@param name string
---@return boolean ok, string|nil err
function M.load(name)
	assert(type(name) == "string" and name ~= "", "session name required")

	-- Persist current work before blowing it away
	if M.current then
		pcall(M.save, M.current)
	else
		pcall(M.save, "_autosave")
	end

	clear_buffers()

	local ok, err = storage.load(name)
	if not ok then
		return false, err
	end

	M.previous = M.current
	M.current = name
	storage.save_last_loaded(name)
	return true
end

--- Delete a named session file.
---@param name string
---@return boolean ok, string|nil err
function M.delete(name)
	assert(type(name) == "string" and name ~= "", "session name required")
	local ok, err = storage.delete(name)
	if ok and M.current == name then
		M.current = nil
	end
	return ok, err
end

--- Start a new empty session (saves current first, then clears workspace).
---@param name string
---@return boolean ok, string|nil err
function M.new(name)
	assert(type(name) == "string" and name ~= "", "session name required")

	if M.current then
		pcall(M.save, M.current)
	else
		pcall(M.save, "_autosave")
	end

	clear_buffers()
	M.current = name
	return true
end

--- Save current workspace, wipe all buffers and tabs, leave a clean slate.
--- Does not prompt — the user can follow up with :BufstateLoad to switch context.
function M.close()
	if M.current then
		pcall(M.save, M.current)
	else
		pcall(M.save, "_autosave")
	end

	clear_buffers()

	local tabs = vim.api.nvim_list_tabpages()
	for i = #tabs, 2, -1 do
		pcall(vim.api.nvim_set_current_tabpage, tabs[i])
		pcall(vim.cmd, "tabclose!")
	end

	M.current = nil
end

--- Load the previously active session (toggle between last two).
--- Calls M.load(), which saves current and tracks the swap.
---@return boolean ok, string|nil err
function M.alternate()
	if not M.previous then
		return false, "No alternate session available"
	end
	return M.load(M.previous)
end

--- List all saved sessions.
---@return { name: string, path: string, mtime: integer }[]
function M.list()
	return storage.list()
end

return M
