-- Tab filtering module for bufstate
-- Maintains runtime state for buffer-to-tab mapping and handles autocmds
local M = {}

-- Runtime state (in memory only)
local state = {
	buffer_tabs = {}, -- { [bufnr] = {tab1, tab2, ...} }
	current_tab = 1,
	active_timestamps = {
		tabs = {}, -- { [tabnr] = timestamp }
		buffers = {}, -- { [bufnr] = timestamp }
	},
	enabled = true, -- Can be toggled via config
}

-- Check if buffer belongs to tab (using existing session.lua logic)
local function buffer_belongs_to_tab(bufnr, tabnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

	-- Only track real files
	if bufname == "" or buftype ~= "" or vim.fn.filereadable(bufname) ~= 1 then
		return false
	end

	-- Check if visible in this tab (from session.lua:36-47)
	local wins = vim.fn.tabpagewinnr(tabnr, "$")
	for w = 1, wins do
		local win_id = vim.fn.win_getid(w, tabnr)
		local win_bufnr = vim.fn.winbufnr(win_id)
		if win_bufnr == bufnr then
			return true
		end
	end

	-- Check if path under tab's cwd (from session.lua:49-54)
	local cwd = vim.fn.getcwd(-1, tabnr)
	if vim.startswith(bufname, cwd .. "/") or bufname == cwd then
		return true
	end

	return false
end

-- Initialize and setup autocmds
function M.setup(opts)
	opts = opts or {}
	state.enabled = opts.enabled ~= false -- default true

	if not state.enabled then
		return
	end

	-- Create autocmd group
	local group = vim.api.nvim_create_augroup("BufstateTabFilter", { clear = true })

	-- TabEnter: Update buflisted for new tab
	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			M.on_tab_enter()
		end,
	})

	-- TabLeave: Update timestamp
	vim.api.nvim_create_autocmd("TabLeave", {
		group = group,
		callback = function()
			M.on_tab_leave()
		end,
	})

	-- TabClosed: Clean up references
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			M.on_tab_closed()
		end,
	})

	-- BufEnter: Track buffer-to-tab association
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			M.on_buf_enter(ev.buf)
		end,
	})
end

-- Get buffer-to-tab mapping
function M.get_buffer_tabs()
	return state.buffer_tabs
end

-- Get timestamp for a tab
function M.get_tab_timestamp(tabnr)
	return state.active_timestamps.tabs[tabnr]
end

-- Get timestamp for a buffer
function M.get_buffer_timestamp(bufnr)
	return state.active_timestamps.buffers[bufnr]
end

-- Track buffer in current tab
function M.track_buffer(bufnr, tabnr)
	tabnr = tabnr or vim.fn.tabpagenr()

	if buffer_belongs_to_tab(bufnr, tabnr) then
		if not state.buffer_tabs[bufnr] then
			state.buffer_tabs[bufnr] = {}
		end

		if not vim.tbl_contains(state.buffer_tabs[bufnr], tabnr) then
			table.insert(state.buffer_tabs[bufnr], tabnr)
		end

		state.active_timestamps.buffers[bufnr] = os.time()
	end
end

-- Update buflisted based on current tab
function M.update_buflisted(tabnr)
	if not state.enabled then
		return
	end

	tabnr = tabnr or vim.fn.tabpagenr()

	for bufnr, tabs in pairs(state.buffer_tabs) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local should_list = vim.tbl_contains(tabs, tabnr)
			vim.bo[bufnr].buflisted = should_list
		end
	end
end

-- Remove tab from all buffer associations
function M.untrack_tab(tabnr)
	for bufnr, tabs in pairs(state.buffer_tabs) do
		for i, tab in ipairs(tabs) do
			if tab == tabnr then
				table.remove(tabs, i)
				break
			end
		end
	end

	state.active_timestamps.tabs[tabnr] = nil
end

-- Rebuild buffer-tab mapping (called after session restore)
function M.rebuild_mapping()
	state.buffer_tabs = {}

	local tab_count = vim.fn.tabpagenr("$")
	for tabnr = 1, tab_count do
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				M.track_buffer(bufnr, tabnr)
			end
		end
	end
end

-- Event handlers
function M.on_tab_enter()
	local tabnr = vim.fn.tabpagenr()
	state.current_tab = tabnr
	state.active_timestamps.tabs[tabnr] = os.time()
	M.update_buflisted(tabnr)
end

function M.on_tab_leave()
	local tabnr = vim.fn.tabpagenr()
	state.active_timestamps.tabs[tabnr] = os.time()
end

function M.on_tab_closed()
	-- TabClosed doesn't provide tab number, need to clean up
	-- Get all valid tab numbers
	local valid_tabs = {}
	local tab_count = vim.fn.tabpagenr("$")
	for i = 1, tab_count do
		valid_tabs[i] = true
	end

	-- Remove invalid tabs from state
	for tabnr in pairs(state.active_timestamps.tabs) do
		if not valid_tabs[tabnr] then
			M.untrack_tab(tabnr)
		end
	end
end

function M.on_buf_enter(bufnr)
	M.track_buffer(bufnr)
end

-- Update timestamps for current tab and buffer (call before saving session)
function M.update_current_timestamps()
	local current_tab = vim.fn.tabpagenr()
	local current_buf = vim.api.nvim_get_current_buf()
	
	-- Update current tab timestamp
	state.active_timestamps.tabs[current_tab] = os.time()
	
	-- Update current buffer timestamp
	if vim.api.nvim_buf_is_valid(current_buf) then
		state.active_timestamps.buffers[current_buf] = os.time()
	end
end

return M
