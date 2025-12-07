-- Main bufstate module
local storage = require("bufstate.storage")
local session = require("bufstate.session")
local ui = require("bufstate.ui")
local tabfilter = require("bufstate.tabfilter")

local M = {}

-- State tracking
local current_session = nil

-- Save the current workspace session (overwrites current session)
function M.save()
	if current_session then
		-- Save to current session
		session.save(current_session)
		vim.notify("Session saved: " .. current_session, vim.log.levels.INFO)
	else
		-- No current session, prompt for name (behaves like save_as)
		M.save_as()
	end
end

-- Save the current workspace session with a new name
function M.save_as(name)
	if name then
		-- Name provided directly
		session.save(name)
		current_session = name
		vim.notify("Session saved as: " .. name, vim.log.levels.INFO)
	else
		-- Prompt for name using snacks.input
		ui.prompt_session_name(function(session_name)
			session.save(session_name)
			current_session = session_name
			vim.notify("Session saved as: " .. session_name, vim.log.levels.INFO)
		end, { prompt = "Save session as: " })
	end
end

-- Load a workspace session
function M.load(name)
	if name then
		-- Direct load with session name
		local ok, result = session.load(name, current_session)
		if not ok then
			vim.notify(result or "Failed to load session", vim.log.levels.ERROR)
			return
		end
		-- Update current_session with the loaded session name
		if result then
			current_session = result
			vim.notify("Session loaded: " .. result, vim.log.levels.INFO)
		end
	else
		-- Show picker first, then call session.load with selected name
		local sessions = storage.list()
		local filtered_sessions = {}
		for _, s in ipairs(sessions) do
			if s.name ~= current_session then
				table.insert(filtered_sessions, s)
			end
		end
		if #filtered_sessions == 0 then
			vim.notify("No sessions available", vim.log.levels.WARN)
			return
		end
		ui.show_session_picker(filtered_sessions, function(selected)
			-- Call session.load with the selected name
			local ok, result = session.load(selected.name, current_session)
			if not ok then
				vim.notify(result or "Failed to load session", vim.log.levels.ERROR)
				return
			end
			if result then
				current_session = result
				vim.notify("Session loaded: " .. result, vim.log.levels.INFO)
			end
		end, { prompt = "Session to load: " })
	end
end

-- Delete a session
function M.delete(name)
	if name then
		-- Name provided directly
		local ok, err = storage.delete(name)
		if not ok then
			vim.notify(err or "Failed to delete session", vim.log.levels.ERROR)
			return
		end
		-- If we deleted the current session, reset to nil
		if current_session == name then
			current_session = nil
		end
		vim.notify("Session deleted: " .. name, vim.log.levels.INFO)
	else
		-- Show picker using snacks.picker
		local sessions = storage.list()
		ui.show_session_picker(sessions, function(selected)
			local ok, err = storage.delete(selected.name)
			if not ok then
				vim.notify(err or "Failed to delete session", vim.log.levels.ERROR)
				return
			end
			-- If we deleted the current session, reset to nil
			if current_session == selected.name then
				current_session = nil
			end
			vim.notify("Session deleted: " .. selected.name, vim.log.levels.INFO)
		end, { prompt = "Session to delete: " })
	end
end

-- List all available sessions
function M.list()
	local sessions = storage.list()

	if #sessions == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	print("Available sessions:")
	for _, s in ipairs(sessions) do
		local modified = os.date("%Y-%m-%d %H:%M", s.modified)
		print(string.format("  %s (modified: %s)", s.name, modified))
	end
end

-- Get current session name
function M.get_current_session()
	return current_session
end

-- Start a new session (save current, then clear workspace)
function M.new(name)
	if name then
		-- Direct creation with name
		local ok, result = session.new(name, current_session)
		if not ok then
			vim.notify(result or "Failed to create new session", vim.log.levels.ERROR)
			return
		end
		-- Update current_session with the new session name
		if result then
			current_session = result
			vim.notify("New session started: " .. result, vim.log.levels.INFO)
		end
	else
		-- Prompt for name using snacks.input
		ui.prompt_session_name(function(session_name)
			-- Call session.new with the entered name
			local ok, result = session.new(session_name, current_session)
			if not ok then
				vim.notify(result or "Failed to create new session", vim.log.levels.ERROR)
				return
			end
			if result then
				current_session = result
				vim.notify("New session started: " .. result, vim.log.levels.INFO)
			end
		end, { prompt = "New session name: " })
	end
end

-- Autosave functions
function M.autosave()
	local autosave_mod = require("bufstate.autosave")
	autosave_mod.perform_autosave()
end

function M.autosave_pause()
	local autosave_mod = require("bufstate.autosave")
	autosave_mod.pause()
end

function M.autosave_resume()
	local autosave_mod = require("bufstate.autosave")
	autosave_mod.resume()
end

function M.autosave_status()
	local autosave_mod = require("bufstate.autosave")
	local status = autosave_mod.get_status()

	print("Autosave Status:")
	print(string.format("  Enabled: %s", status.enabled and "Yes" or "No"))
	print(string.format("  Paused: %s", status.paused and "Yes" or "No"))
	print(string.format("  Current Session: %s", status.session))
	print(string.format("  Last Save: %s", status.last_save))
	print(string.format("  Interval: %.1f minutes", status.interval_minutes))
end

-- Setup function for plugin configuration
function M.setup(opts)
	opts = opts or {}

	-- Mark that setup has been called
	vim.g.bufstate_setup_called = true

	-- Setup tab filtering (enabled by default)
	if opts.filter_by_tab ~= false then
		tabfilter.setup({
			enabled = true,
			stop_lsp_on_tab_leave = opts.stop_lsp_on_tab_leave,
		})
	end

	-- Setup session management with LSP config
	session.setup({
		stop_lsp_on_session_load = opts.stop_lsp_on_session_load,
	})

	-- Always setup autosave with user config (or defaults)
	local autosave_mod = require("bufstate.autosave")
	autosave_mod.setup(opts.autosave or {})

	-- Auto-load latest session on startup
	if opts.autoload_last_session then
		local function do_autoload()
			-- Check if any buffers were opened with nvim (e.g., nvim file.txt)
			local has_args = #vim.fn.argv() > 0

			if not has_args then
				local latest = storage.get_last_loaded()
				if latest then
					local ok, result = session.load(latest, nil)
					if not ok then
						vim.notify("Failed to auto-load latest session: " .. result, vim.log.levels.WARN)
					elseif result then
						-- Direct load succeeded, update current_session immediately
						current_session = result
						vim.notify("Session auto-loaded: " .. result, vim.log.levels.INFO)
					end
				end
			end
		end

		-- If VimEnter has already fired (lazy.nvim loaded us late), run immediately
		-- Otherwise, wait for VimEnter
		if vim.v.vim_did_enter == 1 then
			vim.schedule(do_autoload)
		else
			vim.api.nvim_create_autocmd("VimEnter", {
				once = true,
				callback = function()
					vim.schedule(do_autoload)
				end,
			})
		end
	end
end

return M
