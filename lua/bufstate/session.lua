local ui = require("bufstate.ui")
local storage = require("bufstate.storage")
local tabfilter = require("bufstate.tabfilter")
local buffer = require("bufstate.buffer")
local lsp = require("bufstate.lsp")

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
-- @param name string|nil: Session name to load, or nil to show picker
-- @param current_session string|nil: Current session name for buffer cleanup
-- @param on_loaded function|nil: Callback called with (session_name) when load completes
-- @return boolean|nil, string|nil: success status, session_name_or_error (session name on success, error on failure, nil when picker shown)
function M.load(name, current_session, on_loaded)
	current_session = current_session or "_autosave"
	-- Stop all language servers if user wants to
	if config.stop_lsp_on_session_load then
		lsp.stop_all_clients()
	end

	-- Clean up any unloaded buffers that LSP or other plugins might have left behind
	-- This prevents ghost buffers from being included in the saved session
	buffer.delete_unloaded()

	-- Save current session
	local save_ok, save_err = pcall(M.save, current_session)
	if not save_ok then
		vim.notify("Warning: Failed to save current session: " .. save_err, vim.log.levels.WARN)
	end

	-- Handle modified buffers (must happen after saving the session)
	-- Double-check that buffers are still loaded to prevent lazy-loading corruption
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

	-- If no session name provided, show picker first
	if not name then
		local sessions = storage.list()
		local filtered_sessions = {}
		for _, s in ipairs(sessions) do
			if s.name ~= current_session then
				table.insert(filtered_sessions, s)
			end
		end
		if #filtered_sessions == 0 then
			vim.notify("No sessions available", vim.log.levels.WARN)
			return false
		end
		ui.show_session_picker(filtered_sessions, function(selected)
			-- Recursively call load with the selected name
			M.load(selected.name, current_session, on_loaded)
		end, { prompt = "Session to load: " })
		return true, nil -- Picker shown, actual session name unknown until selection
	end

	-- Delete all open buffers after saving the session
	buffer.delete_all()

	-- Load the vim session file
	local load_ok, load_err = storage.load(name)
	if not load_ok then
		return false, load_err or "Failed to load session"
	end
	storage.save_last_loaded(name)

	-- Rebuild tab filtering and update buflisted
	vim.schedule(function()
		tabfilter.rebuild_mapping()
		local current_tab = vim.fn.tabpagenr()
		tabfilter.update_buflisted(current_tab)
	end)

	-- Notify caller of successful load
	if on_loaded then
		on_loaded(name)
	end

	return true, name -- Return success and the loaded session name
end

return M
