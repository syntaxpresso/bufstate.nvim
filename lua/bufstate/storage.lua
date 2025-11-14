-- Storage module for handling JSON session files
local M = {}

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
	return M.get_session_dir() .. "/" .. name .. ".json"
end

-- Save session data to JSON file
function M.save(name, data)
	local path = M.get_session_path(name)
	local json = vim.json.encode(data)

	local file = io.open(path, "w")
	if not file then
		error("Failed to open file for writing: " .. path)
	end

	file:write(json)
	file:close()

	return true
end

-- Load session data from JSON file
function M.load(name)
	local path = M.get_session_path(name)

	local file = io.open(path, "r")
	if not file then
		return nil, "Session not found: " .. name
	end

	local content = file:read("*all")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		return nil, "Failed to parse session file: " .. name
	end

	return data
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

-- List all available sessions
function M.list()
	local session_dir = M.get_session_dir()
	local files = vim.fn.glob(session_dir .. "/*.json", false, true)

	local sessions = {}
	for _, file in ipairs(files) do
		local name = vim.fn.fnamemodify(file, ":t:r")
		local stat = vim.loop.fs_stat(file)

		table.insert(sessions, {
			name = name,
			path = file,
			modified = stat and stat.mtime.sec or 0,
		})
	end

	-- Sort by most recently modified
	table.sort(sessions, function(a, b)
		return a.modified > b.modified
	end)

	return sessions
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

