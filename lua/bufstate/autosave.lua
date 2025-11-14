-- Autosave module for bufstate
local M = {}

-- State
local timer = nil
local last_save_time = 0
local paused = false

-- Default configuration
local config = {
	enabled = true,
	on_exit = true,
	interval = 300000, -- 5 minutes in milliseconds
	debounce = 30000, -- 30 seconds in milliseconds
}

-- Get current session name from main module
local function get_current_session()
	-- Directly call the main module's function
	local bufstate = require("bufstate")
	if bufstate and bufstate.get_current_session then
		return bufstate.get_current_session()
	end
	return nil
end

-- Perform autosave (silent, with debouncing)
function M.perform_autosave()
	if paused then
		return
	end

	-- Check debounce
	local now = vim.loop.now()
	if now - last_save_time < config.debounce then
		return
	end

	-- Get current session name
	local session_name = get_current_session() or "_autosave"

	-- Perform silent save
	local ok = pcall(require, "bufstate")
	if ok then
		-- Save silently (don't show notification)
		local session_mod = require("bufstate.session")
		local storage_mod = require("bufstate.storage")

		local data = session_mod.capture()
		storage_mod.save(session_name, data)

		last_save_time = now
	end
end

-- Start autosave timer
function M.start()
	if not config.enabled or config.interval <= 0 then
		return
	end

	-- Stop existing timer if any
	M.stop()

	-- Create new timer
	timer = vim.loop.new_timer()
	if timer then
		timer:start(
			config.interval, -- Initial delay
			config.interval, -- Repeat interval
			vim.schedule_wrap(function()
				M.perform_autosave()
			end)
		)
	end
end

-- Stop autosave timer
function M.stop()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

-- Pause autosave
function M.pause()
	paused = true
	vim.notify("Autosave paused", vim.log.levels.INFO)
end

-- Resume autosave
function M.resume()
	paused = false
	vim.notify("Autosave resumed", vim.log.levels.INFO)
end

-- Get autosave status
function M.get_status()
	local session_name = get_current_session() or "_autosave"
	local status = {
		enabled = config.enabled,
		paused = paused,
		session = session_name,
		last_save = last_save_time > 0 and os.date("%Y-%m-%d %H:%M:%S", last_save_time / 1000) or "Never",
		interval_minutes = config.interval / 60000,
	}
	return status
end

-- Setup autosave with user configuration
function M.setup(user_config)
	-- Merge user config with defaults
	config = vim.tbl_deep_extend("force", config, user_config or {})

	if not config.enabled then
		return
	end

	-- Setup autocmd for exit save
	if config.on_exit then
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = vim.api.nvim_create_augroup("BufstateAutosave", { clear = true }),
			callback = function()
				M.perform_autosave()
			end,
		})
	end

	-- Start timer if interval is set
	if config.interval > 0 then
		M.start()
	end
end

return M
