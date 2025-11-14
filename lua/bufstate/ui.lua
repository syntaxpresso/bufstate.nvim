-- UI module for snacks integration
local M = {}

-- Prompt for session name using snacks.input
function M.prompt_session_name(callback, opts)
	opts = opts or {}

	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim is required for workspace-selector", vim.log.levels.ERROR)
		return
	end

	snacks.input({
		prompt = opts.prompt or "Session name: ",
		default = opts.default or "",
	}, function(value)
		if value and value ~= "" then
			callback(value)
		end
	end)
end

-- Custom preview function to show session details
local function preview_session(ctx)
	local storage = require("bufstate.storage")

	-- Reset preview
	ctx.preview:reset()
	ctx.preview:minimal()

	-- Load the session data
	local session_data = storage.load(ctx.item.session.name)
	if not session_data then
		ctx.preview:notify("Failed to load session data", "error")
		return
	end

	-- Build preview content
	local lines = {}
	table.insert(lines, "# Session: " .. ctx.item.session.name)
	table.insert(lines, "")
	table.insert(lines, "**Modified:** " .. os.date("%Y-%m-%d %H:%M:%S", ctx.item.session.modified))
	table.insert(lines, "**Tabs:** " .. #session_data.tabs)

	-- Count total buffers
	local total_buffers = 0
	for _, tab in ipairs(session_data.tabs) do
		if tab.buffers then
			total_buffers = total_buffers + #tab.buffers
		end
	end
	if total_buffers > 0 then
		table.insert(lines, "**Buffers:** " .. total_buffers)
	end

	table.insert(lines, "")
	table.insert(lines, "## Workspaces")
	table.insert(lines, "")

	for i, tab in ipairs(session_data.tabs) do
		local buf_count = tab.buffers and #tab.buffers or 0
		if buf_count > 0 then
			table.insert(
				lines,
				string.format("%d. `%s` (%d buffer%s)", i, tab.cwd, buf_count, buf_count == 1 and "" or "s")
			)
			-- Show buffer list
			for j, buf in ipairs(tab.buffers) do
				local filename = vim.fn.fnamemodify(buf.path, ":t")
				table.insert(lines, string.format("   - %s", filename))
			end
		else
			table.insert(lines, string.format("%d. `%s`", i, tab.cwd))
		end
	end

	-- Set the preview content
	ctx.preview:set_lines(lines)
	ctx.preview:highlight({ ft = "markdown" })
end

-- Show session picker using snacks.picker
function M.show_session_picker(sessions, callback, opts)
	opts = opts or {}

	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim is required for bufstate", vim.log.levels.ERROR)
		return
	end

	if #sessions == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	-- Format sessions for picker
	local items = {}
	for _, session in ipairs(sessions) do
		local modified = os.date("%Y-%m-%d %H:%M", session.modified)
		table.insert(items, {
			text = session.name, -- Only searchable name, not the date
			session = session,
			modified = modified, -- Store modified date separately
		})
	end

	snacks.picker.pick({
		items = items,
		prompt = opts.prompt or "Select Session",
		format = function(item, _)
			-- Format display without numbers (numbers interfere with filtering)
			return {
				{ string.format("%-30s", item.text) },
				{ " " },
				{ item.modified, "Comment" },
			}
		end,
		preview = preview_session,
		confirm = function(picker, item)
			if item then
				callback(item.session)
			end
			picker:close()
		end,
	})
end

return M
