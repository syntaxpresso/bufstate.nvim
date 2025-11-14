-- Session management module
local M = {}

-- Capture the current workspace state (all tabs and their root directories)
function M.capture()
	local tabs = {}
	local tab_count = vim.fn.tabpagenr("$")
	local current_tab = vim.fn.tabpagenr()
	local current_win = vim.fn.winnr()

	for i = 1, tab_count do
		-- Switch to each tab to get its info
		vim.cmd("tabnext " .. i)

		-- Get the tab-local directory (tcd)
		local cwd = vim.fn.getcwd(-1, i)

		-- Get ALL listed buffers (not just visible ones)
		local buffers = {}
		local seen = {}

		-- First, get all listed buffers globally
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1 then
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
						})
					end
				end
			end
		end

		table.insert(tabs, {
			index = i,
			cwd = cwd,
			buffers = buffers,
		})
	end

	-- Return to original tab and window
	vim.cmd("tabnext " .. current_tab)
	vim.cmd(current_win .. "wincmd w")

	return {
		tabs = tabs,
		version = 2, -- Increment version for buffer support
		timestamp = os.time(),
	}
end

-- Restore a workspace session
function M.restore(session_data)
	if not session_data or not session_data.tabs then
		error("Invalid session data")
	end

	-- Close all tabs except the first one
	vim.cmd("tabonly")

	-- Close all buffers in the first tab
	vim.cmd("%bdelete")

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

		-- Restore buffers if available (version 2+)
		if tab.buffers and #tab.buffers > 0 then
			-- Load all buffers in this tab (use :badd to load without displaying)
			for j, buf in ipairs(tab.buffers) do
				local path = buf.path
				-- Make path absolute if relative
				if not vim.startswith(path, "/") then
					path = tab.cwd .. "/" .. path
				end

				if j == 1 then
					-- First buffer: open it in the current window
					vim.cmd("edit " .. vim.fn.fnameescape(path))
					-- Restore cursor position
					vim.fn.cursor(buf.line or 1, buf.col or 1)
				else
					-- Other buffers: just load them without displaying
					vim.cmd("badd " .. vim.fn.fnameescape(path))
				end
			end
		end
	end

	-- Return to the first tab
	vim.cmd("tabnext 1")
end

return M
