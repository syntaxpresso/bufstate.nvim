-- tests/bufstate/safe_delete_spec.lua
-- Integration tests verifying safe bdelete/bwipeout never close tabs.

local bufstate = require("bufstate")

describe("safe_delete", function()
	before_each(function()
		-- Ensure a clean tab with one scratch buffer
		local tabs = vim.api.nvim_list_tabpages()
		for i = #tabs, 2, -1 do
			pcall(vim.api.nvim_set_current_tabpage, tabs[i])
			pcall(vim.cmd, "tabclose!")
		end
		vim.api.nvim_set_current_tabpage(tabs[1])
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
	end)

	describe("bdelete", function()
		it("keeps the tab alive when deleting the last buffer", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""

			local tab_before = vim.api.nvim_get_current_tabpage()
			pcall(bufstate.bdelete, buf)
			local tab_after = vim.api.nvim_get_current_tabpage()

			-- Tab should still exist and be the same
			assert.is_true(vim.api.nvim_tabpage_is_valid(tab_after))
			assert.equals(tab_before, tab_after)
		end)

		it("does not error when deleting last buffer", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""
			local ok = pcall(bufstate.bdelete, buf)
			assert.is_true(ok)
		end)
	end)

	describe("bwipeout", function()
		it("keeps the tab alive when wiping the last buffer", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""

			local tab_before = vim.api.nvim_get_current_tabpage()
			pcall(bufstate.bwipeout, buf)
			local tab_after = vim.api.nvim_get_current_tabpage()

			assert.is_true(vim.api.nvim_tabpage_is_valid(tab_after))
			assert.equals(tab_before, tab_after)
		end)
	end)
end)
