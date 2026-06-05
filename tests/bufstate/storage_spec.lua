-- tests/bufstate/storage_spec.lua
-- Integration tests for bufstate.storage — file I/O layer.

local storage = require("bufstate.storage")

describe("bufstate.storage", function()
	before_each(function()
		vim.fn.delete(storage.session_dir(), "rf")
	end)

	describe("session_dir", function()
		it("resolves under isolated stdpath('data')", function()
			local dir = storage.session_dir()
			assert.is_true(dir:find(vim.fn.stdpath("data"), 1, true) ~= nil)
		end)

		it("creates the directory on access", function()
			vim.fn.delete(storage.session_dir(), "rf")
			local dir = storage.session_dir()
			assert.equals(1, vim.fn.isdirectory(dir))
		end)
	end)

	describe("session_path / metadata_path", function()
		it("returns .vim path for a session", function()
			local p = storage.session_path("my-session")
			assert.is_true(p:find("%.vim$") ~= nil)
			assert.is_true(p:find("my%-session") ~= nil)
		end)

		it("returns .bufstate.json path for metadata", function()
			local p = storage.metadata_path("my-session")
			assert.is_true(p:find("%.bufstate%.json$") ~= nil)
		end)
	end)

	describe("save / list / load / delete round-trip", function()
		local buf

		before_each(function()
			buf = vim.api.nvim_create_buf(true, true)
			vim.api.nvim_buf_set_name(buf, "/tmp/bufstate-test-file.txt")
			vim.bo[buf].buftype = ""
		end)

		after_each(function()
			if buf and vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end)

		it("saves a session and lists it", function()
			storage.save("test-list")
			local sessions = storage.list()
			local names = {}
			for _, s in ipairs(sessions) do
				names[#names + 1] = s.name
			end
			assert.is_true(vim.tbl_contains(names, "test-list"))
		end)

		it("saves and loads a session successfully", function()
			storage.save("test-load")
			local ok, err = storage.load("test-load")
			assert.is_true(ok, err)
			assert.is_nil(err)
		end)

		it("deletes a session and its files", function()
			storage.save("test-delete")
			local ok, err = storage.delete("test-delete")
			assert.is_true(ok, err)
			assert.is_nil(err)
			local sessions = storage.list()
			local names = {}
			for _, s in ipairs(sessions) do
				names[#names + 1] = s.name
			end
			assert.is_false(vim.tbl_contains(names, "test-delete"))
		end)

		it("returns error for non-existent session load", function()
			local ok, err = storage.load("nonexistent-session")
			assert.is_false(ok)
			assert.is_not_nil(err)
		end)

		it("returns error for non-existent session delete", function()
			local ok, err = storage.delete("nonexistent-session")
			assert.is_false(ok)
			assert.is_not_nil(err)
		end)
	end)

	describe("metadata save / load", function()
		before_each(function()
			local buf = vim.api.nvim_create_buf(true, true)
			vim.bo[buf].buftype = ""
			storage.save("meta-test")
		end)

		it("round-trips tab-to-buffer metadata", function()
			local original = {
				{ "/path/a.lua", "/path/b.lua" },
				{ "/path/c.lua" },
			}
			storage.save_metadata("meta-test", original)
			local loaded = storage.load_metadata("meta-test")
			assert.are.same(original, loaded)
		end)

		it("returns empty table for missing metadata (legacy fallback)", function()
			vim.fn.delete(storage.metadata_path("meta-test"))
			local loaded = storage.load_metadata("meta-test")
			assert.are.same({}, loaded)
		end)

		it("returns empty table for corrupt JSON metadata", function()
			vim.fn.writefile({ "not valid json" }, storage.metadata_path("meta-test"))
			local loaded = storage.load_metadata("meta-test")
			assert.are.same({}, loaded)
		end)
	end)

	describe("last_loaded", function()
		it("saves and retrieves the last loaded session name", function()
			storage.save_last_loaded("last-session-name")
			local name = storage.get_last_loaded()
			assert.equals("last-session-name", name)
		end)

		it("returns nil when no last loaded file exists", function()
			vim.fn.delete(storage.last_loaded_path())
			local name = storage.get_last_loaded()
			assert.is_nil(name)
		end)
	end)

	describe("parse_session_metadata", function()
		it("parses badd and tabnew from a session file", function()
			local buf = vim.api.nvim_create_buf(true, true)
			vim.bo[buf].buftype = ""
			local root = vim.fn.getcwd()
			storage.save("parse-test")
			local meta = storage.parse_session_metadata("parse-test")
			assert.is_not_nil(meta)
			assert.is_not_nil(meta.tab_count)
			assert.is_not_nil(meta.buffers)
		end)
	end)
end)
