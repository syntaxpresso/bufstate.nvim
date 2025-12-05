-- Storage module for handling vim session files
local M = {}

-- Compatibility: use vim.uv if available (Neovim 0.10+), otherwise vim.loop
local uv = vim.uv or vim.loop

-- Get the session storage directory
function M.get_session_dir()
	local data_path = vim.fn.stdpath("data")
	local session_dir = data_path .. "/bufstate-sessions"

	-- Create directory if it doesn't exist
	if vim.fn.isdirectory(session_dir) == 0 then
		vim.fn.mkdir(session_dir, "p")
	end

	return session_dir
end

-- Get full path to a session file
function M.get_session_path(name)
	return M.get_session_dir() .. "/" .. name .. ".vim"
end

-- Save session using :mksession!
function M.save(name)
	local path = M.get_session_path(name)

	-- Use :mksession! to generate vim session file
	local ok, err = pcall(function()
		vim.cmd("mksession! " .. vim.fn.fnameescape(path))
	end)
	if not ok then
		error("Failed to save session: " .. (err or "unknown error"))
	end

	return true
end

--
-- Load session using :source
function M.load(name)
	local path = M.get_session_path(name)

	if vim.fn.filereadable(path) == 0 then
		return nil, "Session not found: " .. name
	end

	-- Explicitly clean up before loading session
	-- This ensures no buffers from current Neovim instance leak into the session
	vim.cmd("silent! %bdelete!")
	vim.cmd("silent! tabonly")

	-- Set a flag to indicate we're loading a bufstate session
	vim.g.bufstate_loading_session = true

	-- Source the vim session file
	local ok, err = pcall(function()
		vim.cmd("source " .. vim.fn.fnameescape(path))
	end)

	-- Clear the loading flag
	vim.g.bufstate_loading_session = false

	if not ok then
		return nil, "Failed to load session: " .. (err or "unknown error")
	end

	return true
end

-- Delete a session file
function M.delete(name)
	local path = M.get_session_path(name)

	if vim.fn.filereadable(path) == 0 then
		return false, "Session not found: " .. name
	end

	vim.fn.delete(path)
	return true
end

-- Get all buffer file paths from a session file
-- @param name string: Session name
-- @return table|nil: Array of buffer paths, or nil if session doesn't exist
function M.get_session_buffer_paths(name)
	local path = M.get_session_path(name)
	local file = io.open(path, "r")

	if not file then
		return nil
	end

	local buffers = {}
	for line in file:lines() do
		-- Extract buffers: badd +line path
		local buf_path = line:match("^badd %+%d+ (.+)$")
		if buf_path then
			table.insert(buffers, buf_path)
		end
	end

	file:close()
	return buffers
end

-- Parse vim session file to extract metadata for preview
function M.parse_session_metadata(name)
	local path = M.get_session_path(name)
	local file = io.open(path, "r")

	if not file then
		return nil
	end

	local metadata = {
		buffers = {},
		tabs = {},
		cwd_list = {},
	}

	for line in file:lines() do
		-- Extract buffers: badd +line path
		local buf_path = line:match("^badd %+%d+ (.+)$")
		if buf_path then
			table.insert(metadata.buffers, buf_path)
		end

		-- Extract tab working directories: tcd path
		local tcd_path = line:match("^tcd (.+)$")
		if tcd_path then
			table.insert(metadata.cwd_list, tcd_path)
		end

		-- Count tabs by counting "tabnew" commands
		if line:match("^tabnew") then
			table.insert(metadata.tabs, true)
		end
	end

	file:close()

	-- Calculate tab count: 1 (first tab) + number of tabnew commands
	metadata.tab_count = #metadata.tabs + 1

	return metadata
end

-- List all available sessions
function M.list()
	local session_dir = M.get_session_dir()
	local files = vim.fn.glob(session_dir .. "/*.vim", false, true)

	local sessions = {}
	for _, file in ipairs(files) do
		local name = vim.fn.fnamemodify(file, ":t:r")
		local stat = uv.fs_stat(file)

		table.insert(sessions, {
			name = name,
			path = file,
			modified = stat and stat.mtime.sec or 0,
		})
	end

	-- Sort by modification time (most recent first)
	table.sort(sessions, function(a, b)
		return a.modified > b.modified
	end)

	return sessions
end

-- Get latest session by filesystem mtime
function M.get_latest_session()
	local sessions = M.list()
	if #sessions > 0 then
		-- list() already sorts by modified time, so first is most recent
		return sessions[1].name
	end
	return nil
end

-- Get path to last loaded session tracker file
function M.get_last_loaded_path()
	return M.get_session_dir() .. "/.last_loaded"
end

-- Save the name of the last loaded session
function M.save_last_loaded(name)
	local path = M.get_last_loaded_path()
	local file = io.open(path, "w")
	if not file then
		return false
	end
	file:write(name)
	file:close()
	return true
end

-- Get the name of the last loaded session
function M.get_last_loaded()
	local path = M.get_last_loaded_path()
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local name = file:read("*all")
	file:close()
	return name and name ~= "" and name or nil
end

return M
