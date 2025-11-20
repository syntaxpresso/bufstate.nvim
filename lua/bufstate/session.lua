-- Session management module
local M = {}

-- Capture the current workspace state (all tabs and their root directories)
function M.capture()
	local tabfilter = require("bufstate.tabfilter")
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
						})
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

	return {
		tabs = tabs,
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
	vim.cmd("%bdelete")

	local latest_tab_idx = 1
	local latest_tab_timestamp = 0

	-- Restore each tab with its directory and buffers
	for i, tab in ipairs(session_data.tabs) do
		if i == 1 then
			-- First tab already exists, just set its directory
			vim.cmd("tcd " .. vim.fn.fnameescape(tab.cwd))
		else
			-- Create new tab
			vim.cmd("tabnew")
			-- Set tab-local directory
			vim.cmd("tcd " .. vim.fn.fnameescape(tab.cwd))
		end

		-- Track latest tab by timestamp
		local tab_ts = tab.timestamp or 0
		if tab_ts > latest_tab_timestamp then
			latest_tab_timestamp = tab_ts
			latest_tab_idx = i
		end

		-- Restore buffers if available (version 2+)
		if tab.buffers and #tab.buffers > 0 then
			-- Load all buffers with buflisted=false initially
			for j, buf in ipairs(tab.buffers) do
				local path = buf.path
				-- Make path absolute if relative
				if not vim.startswith(path, "/") then
					path = tab.cwd .. "/" .. path
				end

				if j == 1 then
					-- First buffer: open it in the current window
					vim.cmd("edit " .. vim.fn.fnameescape(path))
				else
					-- Other buffers: just load them without displaying
					vim.cmd("badd " .. vim.fn.fnameescape(path))
				end

				-- Set buflisted=false for all initially
				local bufnr = vim.fn.bufnr(path)
				if bufnr ~= -1 then
					vim.bo[bufnr].buflisted = false
				end
			end
		end
	end

	-- Rebuild buffer-tab mapping
	tabfilter.rebuild_mapping()

	-- Switch to latest tab
	vim.cmd("tabnext " .. latest_tab_idx)

	-- Find latest buffer in this tab and restore cursor
	local latest_tab = session_data.tabs[latest_tab_idx]
	if latest_tab.buffers and #latest_tab.buffers > 0 then
		local latest_buf = latest_tab.buffers[1]
		local latest_buf_timestamp = latest_buf.timestamp or 0

		for _, buf in ipairs(latest_tab.buffers) do
			local buf_ts = buf.timestamp or 0
			if buf_ts > latest_buf_timestamp then
				latest_buf_timestamp = buf_ts
				latest_buf = buf
			end
		end

		-- Switch to latest buffer and restore cursor
		local path = latest_buf.path
		if not vim.startswith(path, "/") then
			path = latest_tab.cwd .. "/" .. path
		end

		vim.cmd("edit " .. vim.fn.fnameescape(path))
		vim.fn.cursor(latest_buf.line or 1, latest_buf.col or 1)
	end

	-- Set buflisted=true only for current tab's buffers
	tabfilter.update_buflisted(latest_tab_idx)
end

return M
