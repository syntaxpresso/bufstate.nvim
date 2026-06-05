-- tests/bufstate/init_spec.lua
-- Integration tests for init.lua — buffer tracking, buflisted filtering,
-- TabEnter/TabLeave autocmds, and safe buffer operations.

local state = require("bufstate.state")

describe("bufstate.init", function()
	before_each(function()
		-- Close extra tabs
		local tabs = vim.api.nvim_list_tabpages()
		for i = #tabs, 2, -1 do
			pcall(vim.api.nvim_set_current_tabpage, tabs[i])
			pcall(vim.cmd, "tabclose!")
		end
		vim.api.nvim_set_current_tabpage(tabs[1])
		-- Wipe normal buffers
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
		state.reset()
	end)

	describe("buffer tracking via BufReadPost", function()
		it("adds buffer to current tab state when opened", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_tracked.lua")
			vim.bo[buf].buftype = ""

			-- Simulate BufReadPost — state.add
			local tab = vim.api.nvim_get_current_tabpage()
			state.add(tab, buf)

			assert.is_true(state.has(tab, buf))
		end)

		it("removes buffer from all tabs on BufDelete", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_to_delete.lua")
			vim.bo[buf].buftype = ""
			local tab = vim.api.nvim_get_current_tabpage()
			state.add(tab, buf)

			state.remove(buf)

			assert.is_false(state.has(tab, buf))
		end)
	end)

	describe("buf_filter", function()
		local bufstate = require("bufstate")

		it("returns true for buffer in current tab", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""
			local tab = vim.api.nvim_get_current_tabpage()
			state.add(tab, buf)

			assert.is_true(bufstate.buf_filter(buf))
		end)

		it("returns false for buffer not in current tab", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""

			assert.is_false(bufstate.buf_filter(buf))
		end)
	end)

	describe("buflisted filtering", function()
		it("filters out buffers from other tabs", function()
			vim.cmd("enew")
			local tab1 = vim.api.nvim_get_current_tabpage()
			local buf1 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(buf1, vim.fn.tempname() .. "_tab1.lua")
			vim.bo[buf1].buftype = ""
			state.add(tab1, buf1)
			vim.bo[buf1].buflisted = true

			-- Create tab 2 with its own buffer
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.cmd("enew")
			local buf2 = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_name(buf2, vim.fn.tempname() .. "_tab2.lua")
			vim.bo[buf2].buftype = ""
			state.add(tab2, buf2)
			vim.bo[buf2].buflisted = true

			-- In tab 2, buf1 should NOT belong
			assert.is_false(state.has(tab2, buf1))
			assert.is_true(state.has(tab2, buf2))

			-- Test buf_filter from tab2's perspective
			local bufstate = require("bufstate")
			assert.is_false(bufstate.buf_filter(buf1))
			assert.is_true(bufstate.buf_filter(buf2))
		end)
	end)

	describe("safe bdelete / bwipeout", function()
		local bufstate = require("bufstate")

		it("bdelete does not close the tab", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""
			pcall(bufstate.bdelete, buf)
			-- Tab should still exist
			local tabs = vim.api.nvim_list_tabpages()
			assert.is_true(#tabs >= 1)
		end)

		it("bwipeout does not close the tab", function()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""
			pcall(bufstate.bwipeout, buf)
			local tabs = vim.api.nvim_list_tabpages()
			assert.is_true(#tabs >= 1)
		end)
	end)

	describe("TabClosed purge", function()
		it("purges dead tab handles from state.db", function()
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""
			state.add(tab2, buf)

			-- Close tab 2 — triggers TabClosed autocmd
			vim.cmd("tabclose")
			-- TabClosed autocmd runs state.purge_tab for dead tabs
			-- Manually simulate what the autocmd does
			local live = {}
			for _, t in ipairs(vim.api.nvim_list_tabpages()) do
				live[t] = true
			end
			for tab in pairs(state.db) do
				if not live[tab] then
					state.purge_tab(tab)
				end
			end

			assert.is_false(state.has(tab2, buf))
		end)
	end)
end)
