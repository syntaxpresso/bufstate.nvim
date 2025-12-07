local storage = require("bufstate.storage")
local tabfilter = require("bufstate.tabfilter")
local buffer = require("bufstate.buffer")

-- Session management module
local M = {}

-- Configuration
local config = {
	stop_lsp_on_session_load = true, -- Stop LSP servers when loading a session (default: true)
}

-- Setup function to accept configuration
function M.setup(opts)
	opts = opts or {}
	config.stop_lsp_on_session_load = opts.stop_lsp_on_session_load ~= false -- default true
end

-- Save current workspace using :mksession!
function M.save(name)
	-- Update timestamps for current tab and buffer
	tabfilter.update_current_timestamps()

	-- Save using :mksession!
	local ok, err = pcall(storage.save, name)

	if not ok then
		error(err)
	end

	return true
end

-- Load workspace using :source
-- @param name string: Session name to load (required)
-- @param current_session string|nil: Current session name for buffer cleanup
-- @return boolean, string|nil: success status, session_name_or_error (session name on success, error on failure)
function M.load(name, current_session)
	-- Session name is required - picker logic is in init.lua
	if not name then
		return false, "Session name is required"
	end

	current_session = current_session or "_autosave"

	-- Handle modified buffers
	for _, buf in ipairs(buffer.get_all_open()) do
		if buf.modified then
			-- Prompt to save if modified
			local ok, err = buffer.prompt_save_modified(buf.bufnr, buf.path)
			if not ok then
				-- TODO: restart clients
				return false, err or "Operation cancelled"
			end
		end
	end

	-- Save current session
	local save_ok, save_err = pcall(M.save, current_session)
	if not save_ok then
		vim.notify("Warning: Failed to save current session: " .. save_err, vim.log.levels.WARN)
	end

	buffer.clear_buffers(config.stop_lsp_on_session_load)

	-- Load the vim session file
	local load_ok, load_err = storage.load(name)
	if not load_ok then
		return false, load_err or "Failed to load session"
	end

	-- Rebuild tab filtering and update buflisted
	vim.schedule(function()
		tabfilter.rebuild_mapping()
		local current_tab = vim.fn.tabpagenr()
		tabfilter.update_buflisted(current_tab)
	end)

	return true, name -- Return success and the loaded session name
end

-- Start a new session (save current, then clear workspace)
-- @param name string: New session name (required)
-- @param current_session string|nil: Current session name to save before clearing
-- @return boolean, string|nil: success status, session_name_or_error
function M.new(name, current_session)
	-- Session name is required - prompt logic is in init.lua
	if not name then
		return false, "Session name is required"
	end

	current_session = current_session or "_autosave"

	-- Handle modified buffers
	for _, buf in ipairs(buffer.get_all_open()) do
		if buf.modified then
			-- Prompt to save if modified
			local ok, err = buffer.prompt_save_modified(buf.bufnr, buf.path)
			if not ok then
				-- TODO: restart clients
				return false, err or "Operation cancelled"
			end
		end
	end

	-- Save current session before starting new one
	local save_ok, save_err = pcall(M.save, current_session)
	if not save_ok then
		vim.notify("Warning: Failed to save current session: " .. save_err, vim.log.levels.WARN)
	end

	-- Delete all open buffers and tabs after saving the session
	buffer.clear_buffers(config.stop_lsp_on_session_load)

	return true, name
end

return M
