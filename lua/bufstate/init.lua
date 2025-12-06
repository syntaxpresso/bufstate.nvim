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
	-- Callback to update current_session when load completes
	local function on_loaded(loaded_name)
		current_session = loaded_name
		vim.notify("Session loaded: " .. loaded_name, vim.log.levels.INFO)
	end

	if name then
		-- Direct load with session name
		local ok, err = session.load(name, current_session, on_loaded)
		if not ok then
			vim.notify(err or "Failed to load session", vim.log.levels.ERROR)
			return
		end
	else
		-- Show picker (session.load handles this when name is nil)
		session.load(nil, current_session, on_loaded)
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
	-- Save current session before starting new one (only if a session is active)
	if current_session then
		session.save(current_session)
		vim.notify("Current session saved: " .. current_session, vim.log.levels.INFO)
	end

	-- Clear all tabs and buffers
	vim.cmd("silent! %bdelete")
	vim.cmd("silent! tabonly")

	if name then
		-- Set the new session name directly
		current_session = name
		vim.notify("New session started: " .. name, vim.log.levels.INFO)
	else
		-- Prompt for name using snacks.input
		ui.prompt_session_name(function(session_name)
			current_session = session_name
			vim.notify("New session started: " .. session_name, vim.log.levels.INFO)
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
		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				-- Schedule to ensure Neovim is fully initialized
				vim.schedule(function()
					-- Check if any buffers were opened with nvim (e.g., nvim file.txt)
					local has_args = #vim.fn.argv() > 0

					if not has_args then
						local latest = storage.get_latest_session()
						if latest then
							local ok, err = session.load(latest, nil, function(loaded_name)
								current_session = loaded_name
								vim.notify("Session auto-loaded: " .. loaded_name, vim.log.levels.INFO)
							end)
							if not ok then
								vim.notify("Failed to auto-load latest session: " .. err, vim.log.levels.WARN)
							end
						end
					end
				end)
			end,
		})
	end
end

return M
