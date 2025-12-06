-- LSP module for bufstate
-- Centralized LSP client management
local M = {}

-- Internal helper: Stop a set of client IDs
-- @param client_ids table: Dictionary of client_id -> client
-- @return number: Count of clients stopped
local function stop_client_ids(client_ids)
	local count = 0
	for client_id, _ in pairs(client_ids) do
		count = count + 1
		vim.schedule(function()
			vim.lsp.stop_client(client_id, true)
		end)
	end
	return count
end

-- Get all LSP clients attached to a buffer
-- @param bufnr number: Buffer number
-- @return table: List of LSP clients
function M.get_clients_for_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return {}
	end
	return vim.lsp.get_clients({ bufnr = bufnr })
end

-- Check if a buffer has any LSP clients attached
-- @param bufnr number: Buffer number
-- @return boolean: true if clients are attached
function M.has_clients(bufnr)
	local clients = M.get_clients_for_buffer(bufnr)
	return #clients > 0
end

-- Stop LSP clients attached to specific buffer numbers
-- @param bufnrs table: List of buffer numbers
-- @return number: Count of unique clients stopped
function M.stop_clients_for_buffers(bufnrs)
	local clients_to_stop = {}

	for _, bufnr in ipairs(bufnrs) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			for _, client in ipairs(clients) do
				clients_to_stop[client.id] = client
			end
		end
	end

	return stop_client_ids(clients_to_stop)
end

-- Stop LSP clients for buffers belonging to a specific tab
-- @param tabnr number: Tab number
-- @param buffer_tabs table: Mapping of bufnr -> {tab1, tab2, ...} from tabfilter state
-- @return number: Count of unique clients stopped
function M.stop_clients_for_tab(tabnr, buffer_tabs)
	local clients_to_stop = {}

	for bufnr, tabs in pairs(buffer_tabs) do
		if vim.tbl_contains(tabs, tabnr) and vim.api.nvim_buf_is_valid(bufnr) then
			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			for _, client in ipairs(clients) do
				clients_to_stop[client.id] = client
			end
		end
	end

	return stop_client_ids(clients_to_stop)
end

-- Stop all LSP clients for all currently open buffers
-- @return number: Count of unique clients stopped
function M.stop_all_clients()
	local clients_to_stop = {}

	-- Get clients from all valid buffers
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			for _, client in ipairs(clients) do
				clients_to_stop[client.id] = client
			end
		end
	end

	return stop_client_ids(clients_to_stop)
end

-- Restart LSP clients for specific buffer numbers
-- Triggers FileType autocmd to reattach LSP
-- @param bufnrs table: List of buffer numbers
function M.restart_clients_for_buffers(bufnrs)
	vim.schedule(function()
		for _, bufnr in ipairs(bufnrs) do
			if vim.api.nvim_buf_is_valid(bufnr) then
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

-- Restart LSP clients for buffers in a specific tab
-- @param tabnr number: Tab number
-- @param buffer_tabs table: Mapping of bufnr -> {tab1, tab2, ...} from tabfilter state
function M.restart_clients_for_tab(tabnr, buffer_tabs)
	local bufnrs = {}

	for bufnr, tabs in pairs(buffer_tabs) do
		if vim.tbl_contains(tabs, tabnr) and vim.api.nvim_buf_is_valid(bufnr) then
			table.insert(bufnrs, bufnr)
		end
	end

	M.restart_clients_for_buffers(bufnrs)
end

return M
