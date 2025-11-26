-- Session management module
local M = {}

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

-- Check and handle modified buffers before loading a session
-- Returns true if we can proceed, false if cancelled, or error message
function M.handle_modified_buffers()
	local modified = has_modified_buffers()
	for _, buf in ipairs(modified) do
		local display_name = vim.fn.fnamemodify(buf.name, ":~:.")
		local msg = string.format('Save changes to "%s"?', display_name)

		local choice = vim.fn.confirm(msg, "&Save\n&Discard\n&Cancel", 1)

		if choice == 1 then -- Save
			local ok = pcall(vim.api.nvim_buf_call, buf.bufnr, function()
				vim.cmd("write")
			end)
			if not ok then
				return nil, "Failed to save buffer: " .. buf.name
			end
		elseif choice == 3 or choice == 0 then -- Cancel or ESC
			return nil, "Session load cancelled"
		end
		-- choice == 2 (Discard) continues to next buffer
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

	-- Step 2: Wipe all buffers with force (modified buffers already handled)
	local buffers = vim.api.nvim_list_bufs()
	for _, buf in ipairs(buffers) do
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end

	-- Step 3: Load the vim session file
	local ok, err = storage.load(name)
	if not ok then
		return nil, err
	end

	-- Step 4: Rebuild tab filtering and update buflisted
	vim.schedule(function()
		tabfilter.rebuild_mapping()
		local current_tab = vim.fn.tabpagenr()
		tabfilter.update_buflisted(current_tab)
	end)

	return true
end

return M
