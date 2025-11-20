-- Session management module
local M = {}

-- Capture the current workspace state (all tabs and their root directories)
function M.capture()
	local tabfilter = require("bufstate.tabfilter")

	-- Update timestamps for current tab and buffer BEFORE capturing
	tabfilter.update_current_timestamps()

	local tabs = {}
	local tab_count = vim.fn.tabpagenr("$")
	local current_tab = vim.fn.tabpagenr()
	local current_win = vim.fn.winnr()

	for i = 1, tab_count do
		-- Switch to each tab to get its info
		vim.cmd("tabnext " .. i)

		-- Get the tab-local directory (tcd)
		local cwd = vim.fn.getcwd(-1, i)

		-- Get ALL buffers (not just listed ones - critical for tab filtering)
		local buffers = {}
		local seen = {}
		local buffer_index = 1

		-- Get all buffers globally - REMOVED buflisted check to capture all buffers
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				local bufname = vim.api.nvim_buf_get_name(bufnr)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

				-- Only save real files (not special buffers like terminal, quickfix, etc.)
				if bufname ~= "" and buftype == "" and vim.fn.filereadable(bufname) == 1 then
					-- Check if buffer belongs to this tab by checking if its path is under the tab's cwd
					-- or if it's currently displayed in this tab
					local is_in_tab = false
					local cursor_line = 1
					local cursor_col = 1

					-- Check if buffer is displayed in any window of this tab
					local wins = vim.fn.tabpagewinnr(i, "$")
					for w = 1, wins do
						local win_id = vim.fn.win_getid(w, i)
						local win_bufnr = vim.fn.winbufnr(win_id)
						if win_bufnr == bufnr then
							is_in_tab = true
							cursor_line = vim.fn.line(".", win_id)
							cursor_col = vim.fn.col(".", win_id)
							break
						end
					end

					-- If not visible, check if the buffer path is under this tab's cwd
					if not is_in_tab then
						if vim.startswith(bufname, cwd .. "/") or bufname == cwd then
							is_in_tab = true
						end
					end

					if is_in_tab and not seen[bufnr] then
						seen[bufnr] = true
						-- Store relative path if inside cwd, otherwise absolute
						local relative = vim.fn.fnamemodify(bufname, ":.")
						local path = vim.startswith(relative, "/") and bufname or relative

						table.insert(buffers, {
							path = path,
							line = cursor_line,
							col = cursor_col,
							timestamp = tabfilter.get_buffer_timestamp(bufnr) or os.time(),
							index = buffer_index,
						})
						buffer_index = buffer_index + 1
					end
				end
			end
		end

		table.insert(tabs, {
			index = i,
			cwd = cwd,
			buffers = buffers,
			timestamp = tabfilter.get_tab_timestamp(i) or os.time(),
		})
	end

	-- Return to original tab and window
	vim.cmd("tabnext " .. current_tab)
	vim.cmd(current_win .. "wincmd w")

	-- Sort tabs by index (preserve tab order)
	table.sort(tabs, function(a, b)
		return a.index < b.index
	end)

	-- Find the most recently active tab to mark for focus
	local most_recent_tab_idx = 1
	local most_recent_tab_time = 0
	for idx, tab in ipairs(tabs) do
		if (tab.timestamp or 0) > most_recent_tab_time then
			most_recent_tab_time = tab.timestamp or 0
			most_recent_tab_idx = idx
		end
	end

	-- Sort buffers within each tab by index (preserve buffer list order)
	for _, tab in ipairs(tabs) do
		table.sort(tab.buffers, function(a, b)
			-- If both have index, sort by index (lower index = earlier in list)
			if a.index and b.index then
				return a.index < b.index
			end
			-- Fallback to timestamp for backward compatibility with old sessions
			return (a.timestamp or 0) > (b.timestamp or 0)
		end)

		-- Find the most recently active buffer to mark for focus
		local most_recent_idx = 1
		local most_recent_time = 0
		for idx, buf in ipairs(tab.buffers) do
			if (buf.timestamp or 0) > most_recent_time then
				most_recent_time = buf.timestamp or 0
				most_recent_idx = idx
			end
		end
		tab.active_buffer_index = most_recent_idx
	end

	return {
		tabs = tabs,
		active_tab_index = most_recent_tab_idx,
		version = 3, -- Bump version for timestamp support
		timestamp = os.time(),
	}
end

-- Restore a workspace session
function M.restore(session_data)
	if not session_data or not session_data.tabs then
		error("Invalid session data")
	end

	local tabfilter = require("bufstate.tabfilter")

	-- Close all tabs except the first one
	vim.cmd("tabonly")

	-- Close all buffers in the first tab
	vim.cmd("silent! %bdelete")

	-- Restore each tab with its directory and buffers
	-- Note: tabs are already sorted by timestamp (most recent first) from capture()
	for i, tab in ipairs(session_data.tabs) do
		-- Restore buffers if available (version 2+)
		-- Note: buffers are sorted by index (preserving original order) from capture()
		if tab.buffers and #tab.buffers > 0 then
			local active_idx = tab.active_buffer_index or 1
			local active_buf_data = nil

			if i == 1 then
				-- First tab already exists, just set its directory
				vim.cmd("tcd " .. vim.fn.fnameescape(tab.cwd))
			else
				-- Create new tab with the first buffer to avoid [No Name]
				vim.cmd("tabnew")
				-- Set tab-local directory
				vim.cmd("tcd " .. vim.fn.fnameescape(tab.cwd))
			end

			-- First pass: Load all buffers in order using :badd to preserve order
			for j, buf in ipairs(tab.buffers) do
				local path = buf.path
				-- Make path absolute if relative
				if not vim.startswith(path, "/") then
					path = tab.cwd .. "/" .. path
				end

				-- Load buffer without displaying
				vim.cmd("badd " .. vim.fn.fnameescape(path))

				-- Set buflisted=false for all initially
				local bufnr = vim.fn.bufnr(path)
				if bufnr ~= -1 then
					vim.bo[bufnr].buflisted = false
				end

				-- Remember the active buffer data for later
				if j == active_idx then
					active_buf_data = { path = path, line = buf.line, col = buf.col }
				end
			end

			-- Second pass: Switch to the active buffer and restore cursor
			if active_buf_data then
				vim.cmd("buffer " .. vim.fn.fnameescape(active_buf_data.path))
				vim.fn.cursor(active_buf_data.line or 1, active_buf_data.col or 1)
			end

			-- Delete all [No Name] buffers created during tab initialization
			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					local bufname = vim.api.nvim_buf_get_name(bufnr)
					if bufname == "" then
						vim.cmd("silent! bdelete " .. bufnr)
					end
				end
			end
		end
	end

	-- Rebuild buffer-tab mapping
	tabfilter.rebuild_mapping()

	-- Switch to the most recently active tab (or first tab if not specified)
	local active_tab = session_data.active_tab_index or 1
	vim.cmd("tabnext " .. active_tab)

	-- Set buflisted=true only for current tab's buffers
	tabfilter.update_buflisted(active_tab)
end

return M
