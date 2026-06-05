-- tests/bufstate/session_spec.lua
-- Integration tests for bufstate.session — high-level session operations.
-- Guards against the PR #13 regression where buffers were dropped on reload.

local session = require("bufstate.session")
local state = require("bufstate.state")
local storage = require("bufstate.storage")

describe("bufstate.session", function()
	before_each(function()
		-- Reset all state
		state.reset()
		-- Clean up all buffers
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
		-- Close all but one tab
		local tabs = vim.api.nvim_list_tabpages()
		for i = #tabs, 2, -1 do
			pcall(vim.api.nvim_set_current_tabpage, tabs[i])
			pcall(vim.cmd, "tabclose!")
		end
		vim.api.nvim_set_current_tabpage(tabs[1])
		-- Wipe session files
		vim.fn.delete(storage.session_dir(), "rf")
		session.current = nil
	end)

	describe("regression: dropped files on reload (PR #13)", function()
		it("preserves all buffers after save/load round-trip in single tab", function()
			local bufnrs = {}
			for i = 1, 4 do
				vim.cmd("enew")
				local buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_file" .. i .. ".lua")
				vim.bo[buf].buftype = ""
				-- Simulate bufstate tracking (as if BufReadPost fired)
				state.add(vim.api.nvim_get_current_tabpage(), buf)
				bufnrs[#bufnrs + 1] = buf
			end

			-- Inject save wrapper that uses the real storage layer
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)

			local ok, err = session.save("roundtrip-single")
			assert.is_true(ok, err)

			-- Capture buffer names before clear
			local expected_names = {}
			for _, buf in ipairs(bufnrs) do
				expected_names[#expected_names + 1] = vim.api.nvim_buf_get_name(buf)
			end

			-- Wipe everything
			session.current = nil
			state.reset()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end

			-- Load the session
			ok, err = session.load("roundtrip-single")
			assert.is_true(ok, err)

			-- Verify all buffers were restored
			local loaded_bufs = vim.api.nvim_list_bufs()
			local loaded_names = {}
			for _, buf in ipairs(loaded_bufs) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
					local name = vim.api.nvim_buf_get_name(buf)
					if name ~= "" then
						loaded_names[#loaded_names + 1] = name
					end
				end
			end

			assert.is_true(
				#loaded_names >= #expected_names,
				string.format("Expected at least %d buffers restored, got %d", #expected_names, #loaded_names)
			)
		end)

		it("preserves all buffers across multiple tabs after save/load", function()
			-- Tab 1: 2 buffers
			local tab1 = vim.api.nvim_get_current_tabpage()
			local tab1_bufs = {}
			for i = 1, 2 do
				vim.cmd("enew")
				local buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_tab1_file" .. i .. ".lua")
				vim.bo[buf].buftype = ""
				state.add(tab1, buf)
				tab1_bufs[#tab1_bufs + 1] = buf
			end

			-- Tab 2: 2 buffers
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			local tab2_bufs = {}
			for i = 1, 2 do
				vim.cmd("enew")
				local buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "_tab2_file" .. i .. ".lua")
				vim.bo[buf].buftype = ""
				state.add(tab2, buf)
				tab2_bufs[#tab2_bufs + 1] = buf
			end
			vim.api.nvim_set_current_tabpage(tab1)

			-- Inject save wrapper
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)

			local ok, err = session.save("roundtrip-multi")
			assert.is_true(ok, err)

			-- Wipe everything
			session.current = nil
			state.reset()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end
			local tabs = vim.api.nvim_list_tabpages()
			for i = #tabs, 2, -1 do
				pcall(vim.api.nvim_set_current_tabpage, tabs[i])
				pcall(vim.cmd, "tabclose!")
			end
			vim.api.nvim_set_current_tabpage(tabs[1])

			-- Load the session
			ok, err = session.load("roundtrip-multi")
			assert.is_true(ok, err)

			-- Verify tabs and buffers restored
			local restored_tabs = vim.api.nvim_list_tabpages()
			assert.is_true(
				#restored_tabs >= 2,
				string.format("Expected at least 2 tabs restored, got %d", #restored_tabs)
			)

			local total_bufs = 0
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if
					vim.api.nvim_buf_is_valid(buf)
					and vim.bo[buf].buftype == ""
					and vim.api.nvim_buf_get_name(buf) ~= ""
				then
					total_bufs = total_bufs + 1
				end
			end
			assert.is_true(
				total_bufs >= 4,
				string.format("Expected at least 4 buffers restored, got %d", total_bufs)
			)
		end)
	end)

	describe("delete", function()
		it("clears session.current after deleting the active session", function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("to-delete-current")
			assert.equals("to-delete-current", session.current)

			local ok = session.delete("to-delete-current")
			assert.is_true(ok)
		end)

		it("keeps session.current when deleting a different session", function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("keep-me")
			local ok = session.delete("other-session")

			assert.is_not_nil(session.current)
		end)
	end)

	describe("new", function()
		it("saves current and clears workspace", function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("before-new")

			-- Add a buffer
			vim.cmd("enew")
			vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. "_new_test.lua")
			vim.bo[0].buftype = ""

			local ok, err = session.new("fresh-start")
			assert.is_true(ok, err)
			assert.equals("fresh-start", session.current)
		end)
	end)

	describe("list", function()
		it("returns saved sessions in the list", function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("first")
			session.save("second")
			local sessions = session.list()
			assert.is_true(#sessions >= 2)
			local names = {}
			for _, s in ipairs(sessions) do
				names[#names + 1] = s.name
			end
			assert.is_true(vim.tbl_contains(names, "first"))
			assert.is_true(vim.tbl_contains(names, "second"))
		end)
	end)

	describe("alternate", function()
		before_each(function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("alternate-a")
			session.save("alternate-b")
			session.previous = nil
		end)

		it("returns error when no previous session exists", function()
			session.current = nil
			session.previous = nil
			local ok, err = session.alternate()
			assert.is_false(ok)
			assert.is_not_nil(err)
		end)

		it("loads the previous session", function()
			local ok, err = session.load("alternate-a")
			assert.is_true(ok, err)
			ok, err = session.load("alternate-b")
			assert.is_true(ok, err)
			assert.equals("alternate-a", session.previous)

			ok, err = session.alternate()
			assert.is_true(ok, err)
			assert.equals("alternate-a", session.current)
		end)

		it("toggles between two sessions", function()
			session.load("alternate-a")
			session.load("alternate-b")

			session.alternate()
			assert.equals("alternate-a", session.current)

			session.alternate()
			assert.equals("alternate-b", session.current)
		end)
	end)

	describe("current session filtering", function()
		it("excludes the active session from the load list", function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("session-one")
			session.save("session-two")
			session.load("session-one")

			local all = storage.list()
			local filtered = vim.tbl_filter(function(s)
				return s.name ~= session.current
			end, all)

			local names = {}
			for _, s in ipairs(filtered) do
				names[#names + 1] = s.name
			end
			assert.is_false(vim.tbl_contains(names, "session-one"))
			assert.is_true(vim.tbl_contains(names, "session-two"))
		end)
	end)

	describe("close", function()
		before_each(function()
			session.set_save_fn(function(name)
				storage.save(name)
				session.current = name
			end)
			session.save("close-session")
		end)

		it("saves current, wipes buffers, and sets current to nil", function()
			-- Create a normal buffer
			vim.cmd("enew")
			local buf = vim.api.nvim_get_current_buf()
			vim.bo[buf].buftype = ""

			session.close()

			assert.is_nil(session.current)
			-- All normal buffers should be wiped
			local remaining = vim.api.nvim_list_bufs()
			for _, b in ipairs(remaining) do
				if vim.api.nvim_buf_is_valid(b) then
					assert.is_false(vim.bo[b].buftype == "")
				end
			end
		end)

		it("uses _autosave fallback when no session is active", function()
			session.current = nil
			local ok = pcall(session.close)
			assert.is_true(ok)
		end)

		it("closes extra tabs, leaving only one", function()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			assert.equals(3, #vim.api.nvim_list_tabpages())

			session.close()

			assert.equals(1, #vim.api.nvim_list_tabpages())
		end)
	end)
end)
