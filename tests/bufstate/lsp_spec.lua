-- tests/bufstate/lsp_spec.lua
-- Smoke tests for bufstate.lsp — client stop/restart logic.

local lsp = require("bufstate.lsp")

describe("bufstate.lsp", function()
	describe("stop_all_clients", function()
		it("returns a number without error", function()
			local result = lsp.stop_all_clients()
			assert.is_true(type(result) == "number")
		end)
	end)

	describe("stop_clients_for_tab", function()
		it("returns a number without error when tab has no buffers", function()
			local result = lsp.stop_clients_for_tab(1)
			assert.is_true(type(result) == "number")
		end)

		it("returns a number when tab has no LSP-attached buffers", function()
			local result = lsp.stop_clients_for_tab(vim.api.nvim_get_current_tabpage())
			assert.is_true(type(result) == "number")
		end)
	end)

	describe("restart_clients_for_tab", function()
		it("does not error with no valid buffers", function()
			local ok = pcall(lsp.restart_clients_for_tab, vim.api.nvim_get_current_tabpage())
			assert.is_true(ok)
		end)
	end)

	describe("restart_clients_for_buffers", function()
		it("does not error with invalid buffer numbers", function()
			local ok = pcall(lsp.restart_clients_for_buffers, { 999999 })
			assert.is_true(ok)
		end)

		it("does not error with empty list", function()
			local ok = pcall(lsp.restart_clients_for_buffers, {})
			assert.is_true(ok)
		end)
	end)
end)
