-- bufstate.nvim - Plugin initialization
if vim.g.loaded_bufstate then
	return
end
vim.g.loaded_bufstate = 1

-- Ensure setup is called at least once with defaults if user doesn't configure.
-- Deferred to VimEnter so user configuration in init.lua runs first.
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		if not vim.g.bufstate_setup_called then
			require("bufstate").setup({})
		end
	end,
})

-- Default keymaps (disable with vim.g.bufstate_no_default_maps = 1)
	if not vim.g.bufstate_no_default_maps then
		vim.keymap.set("n", "<leader>qs", ":BufstateSave<CR>", { desc = "Save session" })
		vim.keymap.set("n", "<leader>qS", ":BufstateSaveAs<CR>", { desc = "Save session as" })
		vim.keymap.set("n", "<leader>ql", ":BufstateLoad<CR>", { desc = "Load session" })
		vim.keymap.set("n", "<leader>qd", ":BufstateDelete<CR>", { desc = "Delete session" })
		vim.keymap.set("n", "<leader>qn", ":BufstateNew<CR>", { desc = "New session" })
		vim.keymap.set("n", "<leader>qc", ":BufstateClose<CR>", { desc = "Close workspace" })
		vim.keymap.set("n", "<leader>qa", ":BufstateAlternate<CR>", { desc = "Alternate session" })
	end
