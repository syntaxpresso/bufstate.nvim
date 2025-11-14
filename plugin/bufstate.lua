-- bufstate.nvim - Plugin initialization
if vim.g.loaded_bufstate then
	return
end
vim.g.loaded_bufstate = 1

-- Ensure setup is called at least once with defaults if user doesn't configure
-- This is deferred to allow user configuration to run first
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		-- Only run default setup if user hasn't called setup yet
		if not vim.g.bufstate_setup_called then
			require("bufstate").setup({})
		end
	end,
})

-- Define user commands
vim.api.nvim_create_user_command("SaveSession", function(opts)
	require("bufstate").save(opts.args ~= "" and opts.args or nil)
end, {
	nargs = "?",
	complete = function(arg_lead)
		local storage = require("bufstate.storage")
		local sessions = storage.list()
		local names = {}
		for _, session in ipairs(sessions) do
			if vim.startswith(session.name, arg_lead) then
				table.insert(names, session.name)
			end
		end
		return names
	end,
})

vim.api.nvim_create_user_command("LoadSession", function(opts)
	require("bufstate").load(opts.args ~= "" and opts.args or nil)
end, {
	nargs = "?",
	complete = function(arg_lead)
		local storage = require("bufstate.storage")
		local sessions = storage.list()
		local names = {}
		for _, session in ipairs(sessions) do
			if vim.startswith(session.name, arg_lead) then
				table.insert(names, session.name)
			end
		end
		return names
	end,
})

vim.api.nvim_create_user_command("DeleteSession", function(opts)
	require("bufstate").delete(opts.args ~= "" and opts.args or nil)
end, {
	nargs = "?",
	complete = function(arg_lead)
		local storage = require("bufstate.storage")
		local sessions = storage.list()
		local names = {}
		for _, session in ipairs(sessions) do
			if vim.startswith(session.name, arg_lead) then
				table.insert(names, session.name)
			end
		end
		return names
	end,
})

vim.api.nvim_create_user_command("ListSessions", function()
	require("bufstate").list()
end, {})

vim.api.nvim_create_user_command("NewSession", function(opts)
	require("bufstate").new(opts.args ~= "" and opts.args or nil)
end, { nargs = "?" })

-- Autosave commands
vim.api.nvim_create_user_command("AutosaveStatus", function()
	require("bufstate").autosave_status()
end, {})

vim.api.nvim_create_user_command("AutosavePause", function()
	require("bufstate").autosave_pause()
end, {})

vim.api.nvim_create_user_command("AutosaveResume", function()
	require("bufstate").autosave_resume()
end, {})

vim.api.nvim_create_user_command("AutosaveNow", function()
	require("bufstate").autosave()
end, {})

-- Default keymaps (can be disabled by setting g:bufstate_no_default_maps = 1)
if not vim.g.bufstate_no_default_maps then
	vim.keymap.set("n", "<leader>qs", ":SaveSession<CR>", { desc = "Save current session" })
	vim.keymap.set("n", "<leader>ql", ":LoadSession<CR>", { desc = "Load session" })
	vim.keymap.set("n", "<leader>qd", ":DeleteSession<CR>", { desc = "Delete session" })
	vim.keymap.set("n", "<leader>qn", ":NewSession<CR>", { desc = "New session" })
end
