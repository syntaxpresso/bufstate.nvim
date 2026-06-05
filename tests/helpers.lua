-- tests/helpers.lua
-- Shared utilities for bufstate.nvim integration tests.

local Helpers = {}

function Helpers.temp_dir()
	return vim.fn.tempname() .. "_dir"
end

function Helpers.create_normal_buffer(name)
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_" .. (name or "buf"))
	vim.bo[buf].buftype = ""
	return buf
end

function Helpers.cleanup_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
end

function Helpers.cleanup_tabs()
	local tabs = vim.api.nvim_list_tabpages()
	for i = #tabs, 2, -1 do
		pcall(vim.api.nvim_set_current_tabpage, tabs[i])
		pcall(vim.cmd, "tabclose!")
	end
	vim.api.nvim_set_current_tabpage(tabs[1])
end

function Helpers.create_tab_with_buffers(names)
	vim.cmd("tabnew")
	for _, name in ipairs(names) do
		vim.cmd("enew")
		vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. "_" .. name)
		vim.bo[0].buftype = ""
	end
	return vim.api.nvim_get_current_tabpage()
end

function Helpers.create_tab_with_single_buffer()
	return Helpers.create_tab_with_buffers({ "single.lua" })
end

return Helpers
