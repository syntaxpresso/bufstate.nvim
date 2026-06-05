-- tests/minimal_init.lua
-- Bootstrap environment for bufstate.nvim tests.
-- Provides full XDG isolation and auto-clones plenary.nvim.

local M = {}

function M.root(subdir)
	local source_path = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(source_path, ":p:h") .. "/" .. (subdir or "")
end

function M.package_root()
	return M.root(".tests/site/pack/deps/start/")
end

function M.ensure_plugin(repo)
	local name = repo:match(".*/(.*)")
	local dest = M.package_root() .. name
	if vim.uv.fs_stat(dest) then
		return dest
	end
	vim.fn.mkdir(M.package_root(), "p")
	vim.fn.system({
		"git",
		"clone",
		"--depth=1",
		"https://github.com/" .. repo .. ".git",
		dest,
	})
	return dest
end

function M.isolate_paths()
	local test_root = M.root(".tests")
	vim.env.XDG_CONFIG_HOME = test_root .. "/config"
	vim.env.XDG_DATA_HOME = test_root .. "/data"
	vim.env.XDG_STATE_HOME = test_root .. "/state"
	vim.env.XDG_CACHE_HOME = test_root .. "/cache"
end

function M.setup()
	vim.o.swapfile = false
	vim.o.shadafile = "NONE"

	M.isolate_paths()

	vim.opt.runtimepath:prepend(M.root(".."))
	vim.opt.packpath = { M.root(".tests/site") }

	M.ensure_plugin("nvim-lua/plenary.nvim")

	vim.cmd("runtime plugin/plenary.vim")
	require("plenary.busted")
	vim.cmd("runtime plugin/bufstate.lua")
end

M.setup()
