local ui = require("bufstate.ui")
local storage = require("bufstate.storage")
local tabfilter = require("bufstate.tabfilter")
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

-- Check if there are any modified buffers
local function has_modified_buffers()
	local modified = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

			-- Check real file buffers that are modified
			if bufname ~= "" and buftype == "" and vim.bo[bufnr].modified then
				table.insert(modified, {
					bufnr = bufnr,
					name = bufname,
				})
			end
		end
	end
	return modified
end

-- Prompt user to save, discard, or cancel for a modified buffer
-- @param bufnr number: Buffer number
-- @param bufname string: Buffer file path
-- @return boolean, string|nil: true if should proceed, nil + error message if cancelled
local function prompt_save_modified_buffer(bufnr, bufname)
	local display_name = vim.fn.fnamemodify(bufname, ":~:.")
	local msg = string.format('Save changes to "%s"?', display_name)

	local choice = vim.fn.confirm(msg, "&Save\n&Discard\n&Cancel", 1)

	if choice == 1 then -- Save
		local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
			vim.cmd("write")
		end)
		if not ok then
			return nil, "Failed to save buffer: " .. bufname
		end
	elseif choice == 3 or choice == 0 then -- Cancel or ESC
		return nil, "Operation cancelled"
	end
	-- choice == 2 (Discard) continues

	return true
end

-- Get all currently open file buffers
-- @return table: List of { bufnr, path, modified } for all valid file buffers
local function get_open_buffers()
	local buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

			-- Only include real file buffers
			if bufname ~= "" and buftype == "" then
				table.insert(buffers, {
					bufnr = bufnr,
					path = bufname,
					modified = vim.bo[bufnr].modified,
				})
			end
		end
	end
	return buffers
end

-- Check and handle modified buffers before loading a session
-- Returns true if we can proceed, false if cancelled, or error message
function M.handle_modified_buffers()
	local modified = has_modified_buffers()
	for _, buf in ipairs(modified) do
		local ok, err = prompt_save_modified_buffer(buf.bufnr, buf.name)
		if not ok then
			return nil, err or "Session load cancelled"
		end
	end
	return true
end

-- Clean up a specific provisory buffer if other buffers exist
-- @param bufnr number: The buffer number to delete
function M.cleanup_provisory_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return -- Buffer doesn't exist or was already deleted
	end

	-- Count valid buffers
	local buffer_count = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			buffer_count = buffer_count + 1
		end
	end

	-- Only delete if at least 2 buffers exist
	if buffer_count >= 2 then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end
end

-- Load workspace using :source
-- @param name string|nil: Session name to load, or nil to show picker
-- @param current_session string|nil: Current session name for buffer cleanup
-- @param on_loaded function|nil: Callback called with (session_name) when load completes
function M.load(name, current_session, on_loaded)
	local current_buffers = get_open_buffers()

	for _, buf in ipairs(current_buffers) do
		if buf.modified then
			-- Prompt to save if modified
			local ok, err = prompt_save_modified_buffer(buf.bufnr, buf.name)
			if not ok then
				return false, err or "Operation cancelled"
			end
		end
	end

	-- If no name provided, show picker first
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
		return true
	end

	-- Only do buffer cleanup if we have a current session
	if current_session then
		-- Save the current session, if any
		local ok, err = pcall(M.save, current_session)
		if not ok then
			vim.notify("Warning: Failed to save current session: " .. err, vim.log.levels.WARN)
		end
	end

	-- Load the vim session file
	local ok, err = storage.load(name)
	if not ok then
		return false, err or "Failed to load session"
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

	return true
end

return M
