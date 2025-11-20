-- Storage module for handling JSON session files
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
	return M.get_session_dir() .. "/" .. name .. ".json"
end

-- Get path to metadata file
function M.get_metadata_path()
	return M.get_session_dir() .. "/sessions.json"
end

-- Load metadata
function M.load_metadata()
	local path = M.get_metadata_path()
	local file = io.open(path, "r")

	if not file then
		return { sessions = {} }
	end

	local content = file:read("*all")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		return { sessions = {} }
	end

	return data
end

-- Save metadata
function M.save_metadata(metadata)
	local path = M.get_metadata_path()
	local json = vim.json.encode(metadata)

	local file = io.open(path, "w")
	if not file then
		error("Failed to write metadata file: " .. path)
	end

	file:write(json)
	file:close()
end

-- Save session data to JSON file
function M.save(name, data)
	-- Save session file (existing logic)
	local path = M.get_session_path(name)
	local json = vim.json.encode(data)

	local file = io.open(path, "w")
	if not file then
		error("Failed to open file for writing: " .. path)
	end

	file:write(json)
	file:close()

	-- Update metadata
	local metadata = M.load_metadata()
	local found = false

	for _, session in ipairs(metadata.sessions) do
		if session.name == name then
			session.timestamp = data.timestamp
			found = true
			break
		end
	end

	if not found then
		table.insert(metadata.sessions, {
			name = name,
			timestamp = data.timestamp,
		})
	end

	M.save_metadata(metadata)

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

	-- Update metadata
	local metadata = M.load_metadata()
	for i, session in ipairs(metadata.sessions) do
		if session.name == name then
			table.remove(metadata.sessions, i)
			break
		end
	end
	M.save_metadata(metadata)

	return true
end

-- List all available sessions
function M.list()
	local metadata = M.load_metadata()

	if #metadata.sessions > 0 then
		-- Use metadata
		local sessions = {}
		for _, meta in ipairs(metadata.sessions) do
			table.insert(sessions, {
				name = meta.name,
				path = M.get_session_path(meta.name),
				modified = meta.timestamp or 0,
			})
		end

		table.sort(sessions, function(a, b)
			return a.modified > b.modified
		end)

		return sessions
	else
		-- Fallback to scanning directory (backward compatibility)
		local session_dir = M.get_session_dir()
		local files = vim.fn.glob(session_dir .. "/*.json", false, true)

		local sessions = {}
		for _, file in ipairs(files) do
			local name = vim.fn.fnamemodify(file, ":t:r")

			-- Skip metadata file
			if name ~= "sessions" then
				local stat = uv.fs_stat(file)
				table.insert(sessions, {
					name = name,
					path = file,
					modified = stat and stat.mtime.sec or 0,
				})
			end
		end

		table.sort(sessions, function(a, b)
			return a.modified > b.modified
		end)

		return sessions
	end
end

-- Get latest session by timestamp
function M.get_latest_session()
	local metadata = M.load_metadata()

	if #metadata.sessions > 0 then
		-- Use metadata if available
		table.sort(metadata.sessions, function(a, b)
			return (a.timestamp or 0) > (b.timestamp or 0)
		end)
		return metadata.sessions[1].name
	else
		-- Fallback: scan directory for session files (backward compatibility)
		local sessions = M.list()
		if #sessions > 0 then
			-- list() already sorts by modified time, so first is most recent
			return sessions[1].name
		end
		return nil
	end
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
