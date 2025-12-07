-- Buffer utility functions module
local M = {}

-- Check if there are any modified buffers
-- @return table: List of { bufnr, name } for modified buffers
function M.has_modified()
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
function M.prompt_save_modified(bufnr, bufname)
	local display_name = vim.fn.fnamemodify(bufname, ":~:.")
	local msg = string.format('Save changes to "%s"?', display_name)

	local choice = vim.fn.confirm(msg, "&Save\n&Discard\n&Cancel", 1)

	if choice == 1 then -- Save
		local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
			-- Use noautocmd to prevent autocmds from triggering during save
			-- which could potentially load additional buffers
			vim.cmd("write")
		end)
		if not ok then
			return nil, "Failed to save buffer: " .. bufname
		end
		vim.notify("Saved: " .. display_name, vim.log.levels.INFO)
	elseif choice == 2 then -- Discard
		local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
			vim.cmd("e!")
		end)
		if not ok then
			return nil, "Failed to discard changes for buffer: " .. bufname
		end
		vim.notify("Discarded changes to: " .. display_name, vim.log.levels.INFO)
	elseif choice == 3 or choice == 0 then -- Cancel or ESC
		return nil, "Operation cancelled"
	end

	return true
end

-- Get all currently open file buffers
-- @return table: List of { bufnr, path, modified } for all valid file buffers
function M.get_all_open()
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

-- Delete all unloaded buffers from the buffer list
-- This is useful for cleaning up "ghost" buffers that remain in the buffer list
-- but are no longer loaded in memory (e.g., after stopping LSP clients)
function M.delete_unloaded()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and not vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end
end

function M.delete_all()
	-- Clean up any unloaded buffers that LSP or other plugins might have left behind
	-- This prevents ghost buffers from being included in the saved session
	M.delete_unloaded()

	-- Delete all buffers
	vim.cmd("silent! %bd!")

	-- Delete all tabs
	vim.cmd("silent! tabonly!")
end

return M
