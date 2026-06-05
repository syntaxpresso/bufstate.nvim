-- lua/bufstate/ui.lua
-- Snacks.nvim UI: input prompt + session picker with preview.

local M = {}

-- ── input prompt ──────────────────────────────────────────────────────────────

--- Prompt for a session name using snacks.input.
--- Falls back to vim.ui.input if snacks is unavailable.
---@param callback fun(name: string)
---@param opts? { prompt?: string, default?: string }
function M.prompt_session_name(callback, opts)
	opts = opts or {}
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.ui.input(
			{ prompt = opts.prompt or "Session name: ", default = opts.default or "" },
			function(value)
				if value and value ~= "" then
					callback(value)
				end
			end
		)
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

-- ── session picker ────────────────────────────────────────────────────────────

--- Preview callback for snacks.picker: renders session metadata as markdown.
local function preview_session(ctx)
	local storage = require("bufstate.storage")

	ctx.preview:reset()
	ctx.preview:minimal()

	local meta = storage.parse_session_metadata(ctx.item.session.name)
	if not meta then
		ctx.preview:notify("Failed to read session file", "error")
		return
	end

	local lines = {}
	lines[#lines + 1] = "# Session: " .. ctx.item.session.name
	lines[#lines + 1] = ""
	lines[#lines + 1] = "**Modified:** " .. os.date("%Y-%m-%d %H:%M:%S", ctx.item.session.mtime)
	lines[#lines + 1] = "**Tabs:** " .. meta.tab_count
	lines[#lines + 1] = "**Buffers:** " .. #meta.buffers
	lines[#lines + 1] = ""
	lines[#lines + 1] = "## Workspaces"
	lines[#lines + 1] = ""

	for i, cwd in ipairs(meta.cwd_list) do
		lines[#lines + 1] = string.format("%d. `%s`", i, cwd)
	end

	if #meta.cwd_list == 0 and #meta.buffers > 0 then
		-- No tcd lines — single cwd session; just list buffer filenames
		for _, buf_path in ipairs(meta.buffers) do
			local fname = vim.fn.fnamemodify(buf_path, ":t")
			lines[#lines + 1] = "   - " .. fname
		end
	end

	ctx.preview:set_lines(lines)
	ctx.preview:highlight({ ft = "markdown" })
end

--- Show a session picker using snacks.picker.
--- Falls back to vim.ui.select if snacks is unavailable.
--- Sessions must be the list returned by storage.list(): { name, path, mtime }.
---@param sessions { name: string, path: string, mtime: integer }[]
---@param callback fun(session: { name: string, path: string, mtime: integer })
---@param opts? { prompt?: string }
function M.show_session_picker(sessions, callback, opts)
	opts = opts or {}

	if #sessions == 0 then
		vim.notify("No sessions found", vim.log.levels.WARN)
		return
	end

	local ok, snacks = pcall(require, "snacks")
	if not ok then
		local names = vim.tbl_map(function(s)
			return s.name
		end, sessions)
		vim.ui.select(names, { prompt = opts.prompt or "Select session: " }, function(choice)
			if not choice then
				return
			end
			for _, s in ipairs(sessions) do
				if s.name == choice then
					callback(s)
					return
				end
			end
		end)
		return
	end

	local items = {}
	for _, s in ipairs(sessions) do
		items[#items + 1] = {
			text = s.name,
			session = s,
		}
	end

	snacks.picker.pick({
		items = items,
		prompt = opts.prompt or "Select Session",
		format = function(item, _)
			local modified = os.date("%Y-%m-%d %H:%M", item.session.mtime)
			return {
				{ string.format("%-30s", item.text) },
				{ " " },
				{ modified, "Comment" },
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
