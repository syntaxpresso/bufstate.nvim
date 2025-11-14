-- Main bufstate module
local storage = require("bufstate.storage")
local session = require("bufstate.session")
local ui = require("bufstate.ui")

local M = {}

-- State tracking
local current_session = nil

-- Save the current workspace session
function M.save(name)
	if name then
		-- Name provided directly
		local data = session.capture()
		storage.save(name, data)
		current_session = name
		vim.notify("Session saved: " .. name, vim.log.levels.INFO)
	else
		-- Prompt for name using snacks.input
		ui.prompt_session_name(function(session_name)
			local data = session.capture()
			storage.save(session_name, data)
			current_session = session_name
			vim.notify("Session saved: " .. session_name, vim.log.levels.INFO)
		end, { prompt = "Save session as: " })
	end
end

-- Load a workspace session
function M.load(name)
	if name then
		-- Name provided directly
		local data, err = storage.load(name)
		if not data then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end

		session.restore(data)
		current_session = name
		vim.notify("Session loaded: " .. name, vim.log.levels.INFO)
	else
		-- Show picker using snacks.picker
		local sessions = storage.list()
		ui.show_session_picker(sessions, function(selected)
			local data, err = storage.load(selected.name)
			if not data then
				vim.notify(err, vim.log.levels.ERROR)
				return
			end

			session.restore(data)
			current_session = selected.name
			vim.notify("Session loaded: " .. selected.name, vim.log.levels.INFO)
		end, { prompt = "Load Session" })
	end
end

-- Delete a session
function M.delete(name)
	if name then
		-- Name provided directly
		local ok, err = storage.delete(name)
		if not ok then
			vim.notify(err, vim.log.levels.ERROR)
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
				vim.notify(err, vim.log.levels.ERROR)
				return
			end
			-- If we deleted the current session, reset to nil
			if current_session == selected.name then
				current_session = nil
			end
			vim.notify("Session deleted: " .. selected.name, vim.log.levels.INFO)
		end, { prompt = "Delete Session" })
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

	-- Setup autosave if configured
	if opts.autosave then
		local autosave_mod = require("bufstate.autosave")
		autosave_mod.setup(opts.autosave)
	end
end

return M
