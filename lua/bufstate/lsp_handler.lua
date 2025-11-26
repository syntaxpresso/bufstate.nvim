-- LSP handler module for bufstate
-- Suppresses expected LSP exit messages when stopping servers
local M = {}

-- Configuration
local config = {
	suppress_exit_messages = true, -- Suppress "quit with exit code 143" messages (default: true)
}

-- Store original vim.notify
local original_notify = nil

-- Setup function to accept configuration
function M.setup(opts)
	opts = opts or {}
	config.suppress_exit_messages = opts.suppress_exit_messages ~= false -- default true

	if config.suppress_exit_messages then
		M.enable()
	end
end

-- Enable message suppression
function M.enable()
	-- Only hook once
	if original_notify then
		return
	end

	-- Store the original notify function
	original_notify = vim.notify

	-- Override vim.notify to filter out expected LSP exit messages
	vim.notify = function(msg, level, opts)
		-- Suppress "quit with exit code 143" messages (SIGTERM - graceful shutdown)
		-- Exit code 143 = 128 + 15 (SIGTERM) - this is expected when we stop LSP servers
		if type(msg) == "string" and msg:match("exit code 143") then
			return
		end

		-- Call original notify for all other messages
		original_notify(msg, level, opts)
	end
end

-- Disable message suppression (restore original vim.notify)
function M.disable()
	if original_notify then
		vim.notify = original_notify
		original_notify = nil
	end
end

return M
