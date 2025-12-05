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
	local storage = require("bufstate.storage")
	local tabfilter = require("bufstate.tabfilter")

	-- Update timestamps for current tab and buffer
	tabfilter.update_current_timestamps()

	-- Step 1: Collect all tab working directories
	local tab_cwds = {}
	local tab_count = vim.fn.tabpagenr("$")
	for tabnr = 1, tab_count do
		local cwd = vim.fn.getcwd(-1, tabnr)
		tab_cwds[cwd] = true
	end

	-- Step 2: Collect buffers that are visible in any window split
	-- These must always be kept regardless of their path
	local visible_buffers = {}
	for tabnr = 1, tab_count do
		local wins = vim.fn.tabpagewinnr(tabnr, "$")
		for w = 1, wins do
			local win_id = vim.fn.win_getid(w, tabnr)
			local bufnr = vim.fn.winbufnr(win_id)
			if bufnr > 0 then
				visible_buffers[bufnr] = true
			end
		end
	end

	-- Step 3: Delete buffers that don't belong to any tab's working directory
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

			-- Only check real file buffers
			if bufname ~= "" and buftype == "" then
				local belongs_to_session = false

				-- Always keep if visible in any window
				if visible_buffers[bufnr] then
					belongs_to_session = true
				else
					-- Check if buffer path starts with any tab's cwd
					for cwd, _ in pairs(tab_cwds) do
						if vim.startswith(bufname, cwd .. "/") or bufname == cwd then
							belongs_to_session = true
							break
						end
					end
				end

				-- Delete buffer if it doesn't belong to session
				if not belongs_to_session then
					pcall(function()
						vim.cmd("silent! bdelete " .. bufnr)
					end)
				end
			end
		end
	end

	-- Step 4: Save using :mksession! (only session buffers remain)
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

-- Kill buffers by their file paths
-- Prompts to save if buffer is modified
-- @param buffer_paths table: Array of buffer file paths to kill
-- @return boolean, string|nil: true if successful, or nil + error message if cancelled
function M.kill_buffers_by_path(buffer_paths)
	-- Create an empty buffer to prevent closing Neovim
	vim.cmd("enew")
	if not buffer_paths or #buffer_paths == 0 then
		return true -- Nothing to do
	end

	-- Build a set of paths for quick lookup
	local paths_to_kill = {}
	for _, path in ipairs(buffer_paths) do
		paths_to_kill[path] = true
	end

	-- Find buffers that match the paths
	local buffers_to_kill = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			if bufname ~= "" and paths_to_kill[bufname] then
				table.insert(buffers_to_kill, {
					bufnr = bufnr,
					name = bufname,
					modified = vim.bo[bufnr].modified,
				})
			end
		end
	end

	-- Handle each buffer
	for _, buf in ipairs(buffers_to_kill) do
		if buf.modified then
			-- Prompt to save if modified
			local ok, err = prompt_save_modified_buffer(buf.bufnr, buf.name)
			if not ok then
				return nil, err or "Operation cancelled"
			end
		end

		-- Delete the buffer
		pcall(vim.api.nvim_buf_delete, buf.bufnr, { force = true })
	end

	return true
end

-- Load workspace using :source
function M.load(name, current_session_name)
	local storage = require("bufstate.storage")
	local tabfilter = require("bufstate.tabfilter")

	-- Step 1: Save current session if provided
	if current_session_name then
		local ok, err = pcall(M.save, current_session_name)
		if ok then
			vim.notify("Current session saved: " .. current_session_name, vim.log.levels.INFO)
		else
			vim.notify("Warning: Failed to save current session: " .. (err or "unknown error"), vim.log.levels.WARN)
		end
	end

	-- Step 2: Stop all LSP clients before deleting buffers (if enabled)
	if config.stop_lsp_on_session_load then
		local clients = vim.lsp.get_clients()
		for _, client in ipairs(clients) do
			vim.lsp.stop_client(client.id, true)
		end
	end

	-- Step 3: Wipe all buffers with force (modified buffers already handled)
	local buffers = vim.api.nvim_list_bufs()
	for _, buf in ipairs(buffers) do
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end

	-- Step 4: Load the vim session file
	local ok, err = storage.load(name)
	if not ok then
		return nil, err
	end

	-- Step 5: Rebuild tab filtering and update buflisted
	vim.schedule(function()
		tabfilter.rebuild_mapping()
		local current_tab = vim.fn.tabpagenr()
		tabfilter.update_buflisted(current_tab)
	end)

	return true
end

return M
