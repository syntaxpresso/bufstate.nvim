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

	-- Parse the vim session file for metadata
	local metadata = storage.parse_session_metadata(ctx.item.session.name)
	if not metadata then
		ctx.preview:notify("Failed to parse session file", "error")
		return
	end

	-- Build preview content
	local lines = {}
	table.insert(lines, "# Session: " .. ctx.item.session.name)
	table.insert(lines, "")
	table.insert(lines, "**Modified:** " .. os.date("%Y-%m-%d %H:%M:%S", ctx.item.session.modified))
	table.insert(lines, "**Tabs:** " .. metadata.tab_count)
	table.insert(lines, "**Buffers:** " .. #metadata.buffers)

	-- Show working directories
	if #metadata.cwd_list > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Working Directories")
		table.insert(lines, "")
		for i, cwd in ipairs(metadata.cwd_list) do
			table.insert(lines, string.format("%d. `%s`", i, cwd))
		end
	end

	-- Show buffer list (limited to first 20 to avoid huge previews)
	if #metadata.buffers > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Buffers")
		table.insert(lines, "")
		local max_show = math.min(20, #metadata.buffers)
		for i = 1, max_show do
			local buf_path = metadata.buffers[i]
			local filename = vim.fn.fnamemodify(buf_path, ":t")
			table.insert(lines, string.format("- %s", filename))
		end
		if #metadata.buffers > 20 then
			table.insert(lines, string.format("- ... and %d more", #metadata.buffers - 20))
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
			picker:close()
			if item then
				vim.schedule(function()
					callback(item.session)
				end)
			end
		end,
	})
end

return M
