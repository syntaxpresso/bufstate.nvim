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
	stop_lsp_on_tab_leave = true, -- Kill LSP servers when leaving tab (default: true)
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
	state.stop_lsp_on_tab_leave = opts.stop_lsp_on_tab_leave ~= false -- default true

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
	for _, tabs in pairs(state.buffer_tabs) do
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

-- Stop LSP clients for buffers belonging to a specific tab
local function stop_lsp_for_tab(tabnr)
	-- Track which clients are used by buffers in this tab
	local clients_to_stop = {}

	for bufnr, tabs in pairs(state.buffer_tabs) do
		if vim.tbl_contains(tabs, tabnr) and vim.api.nvim_buf_is_valid(bufnr) then
			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			for _, client in ipairs(clients) do
				-- Mark this client for stopping
				clients_to_stop[client.id] = client
			end
		end
	end

	-- Stop each unique client (this will kill the jdtls process)
	for client_id, _ in pairs(clients_to_stop) do
		vim.schedule(function()
			-- Stop the client completely (terminates the LSP server process)
			vim.lsp.stop_client(client_id, true)
		end)
	end
end

-- Restart LSP clients for buffers in the current tab
local function restart_lsp_for_tab(tabnr)
	-- Schedule this to run after buflisted is updated and clients are stopped
	vim.schedule(function()
		for bufnr, tabs in pairs(state.buffer_tabs) do
			if vim.tbl_contains(tabs, tabnr) and vim.api.nvim_buf_is_valid(bufnr) then
				local bufname = vim.api.nvim_buf_get_name(bufnr)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

				-- Only restart LSP for real file buffers
				if bufname ~= "" and buftype == "" then
					-- Check if buffer has LSP clients attached
					local clients = vim.lsp.get_clients({ bufnr = bufnr })

					-- If no clients are attached, trigger FileType autocmd to restart LSP
					if #clients == 0 then
						local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
						if filetype ~= "" then
							-- Trigger FileType event which will cause LSP to attach
							vim.api.nvim_exec_autocmds("FileType", {
								buffer = bufnr,
								data = { filetype = filetype },
							})
						end
					end
				end
			end
		end
	end)
end

-- Event handlers
function M.on_tab_enter()
	local tabnr = vim.fn.tabpagenr()
	state.current_tab = tabnr
	state.active_timestamps.tabs[tabnr] = os.time()
	M.update_buflisted(tabnr)

	-- Restart LSP for buffers in this tab (if enabled)
	if state.stop_lsp_on_tab_leave then
		restart_lsp_for_tab(tabnr)
	end
end

function M.on_tab_leave()
	local tabnr = vim.fn.tabpagenr()
	state.active_timestamps.tabs[tabnr] = os.time()

	-- Stop LSP clients for buffers in this tab (if enabled)
	if state.stop_lsp_on_tab_leave then
		stop_lsp_for_tab(tabnr)
	end
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
