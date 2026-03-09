-- lua/bufstate/lsp.lua
-- LSP client management: stop/restart clients per-tab or globally.
-- Adapted to read buffer ownership from bufstate.state rather than the old
-- tabfilter module.

local M = {}

-- ── internal ──────────────────────────────────────────────────────────────────

local function stop_client_ids(client_ids)
	local count = 0
	for client_id in pairs(client_ids) do
		count = count + 1
		vim.schedule(function()
			vim.lsp.stop_client(client_id, true)
		end)
	end
	return count
end

-- ── public API ────────────────────────────────────────────────────────────────

--- Stop LSP clients for all buffers owned by `tab` according to state.db.
---@param tab integer  tab page handle
---@return integer  count of unique clients stopped
function M.stop_clients_for_tab(tab)
	local state = require("bufstate.state")
	local clients_to_stop = {}
	for _, bufnr in ipairs(state.get(tab)) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
				clients_to_stop[client.id] = true
			end
		end
	end
	return stop_client_ids(clients_to_stop)
end

--- Stop all LSP clients attached to any open buffer.
---@return integer  count of unique clients stopped
function M.stop_all_clients()
	local clients_to_stop = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
				clients_to_stop[client.id] = true
			end
		end
	end
	return stop_client_ids(clients_to_stop)
end

--- Trigger FileType autocmd on each buffer to reattach LSP clients.
---@param bufnrs integer[]
function M.restart_clients_for_buffers(bufnrs)
	vim.schedule(function()
		for _, bufnr in ipairs(bufnrs) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				local name = vim.api.nvim_buf_get_name(bufnr)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
				local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
				if name ~= "" and buftype == "" and ft ~= "" then
					if #vim.lsp.get_clients({ bufnr = bufnr }) == 0 then
						vim.api.nvim_exec_autocmds("FileType", {
							buffer = bufnr,
							data = { filetype = ft },
						})
					end
				end
			end
		end
	end)
end

--- Restart LSP for all buffers owned by `tab` according to state.db.
---@param tab integer  tab page handle
function M.restart_clients_for_tab(tab)
	local state = require("bufstate.state")
	M.restart_clients_for_buffers(state.get(tab))
end

return M
