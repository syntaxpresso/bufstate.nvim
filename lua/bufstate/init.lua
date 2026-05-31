-- lua/bufstate/init.lua

local M = {}
local state = require("bufstate.state")
local session = require("bufstate.session")
local storage = require("bufstate.storage")
local ui = require("bufstate.ui")

-- Guard: true while we are toggling buflisted ourselves.
-- Prevents our own buflisted changes from triggering state.remove via BufDelete.
local filtering = false

-- Guard: true while a session file is being :source'd.
-- Suppresses BufAdd during the global `badd` preamble emitted by :mksession,
-- which fires before any tab context is restored. State is rebuilt from the
-- authoritative window layout after :source completes via post_load_rebuild().
local loading = false

-- ── helpers ───────────────────────────────────────────────────────────────────

--- Set buflisted for all known buffers based on ownership of `tab`.
--- Buffers owned by `tab` → listed. All others → unlisted.
---@param tab integer
local function filter_for_tab(tab)
	filtering = true
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.bo[buf].buflisted = state.has(tab, buf)
		end
	end
	filtering = false
end

--- Unlist every known buffer (called on TabLeave).
local function unlist_all()
	filtering = true
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.bo[buf].buflisted = false
		end
	end
	filtering = false
end

local function normalized_buf_path(name)
	if not name or name == "" then
		return nil
	end
	local path = vim.fn.fnamemodify(name, ":p")
	if path == "" then
		return nil
	end
	if vim.fs and vim.fs.normalize then
		path = vim.fs.normalize(path)
	end
	if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
		path = path:lower()
	end
	return path
end

local function collect_session_buffers()
	local result = {}
	for tab_index, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local paths = {}
		local seen = {}
		for _, buf in ipairs(state.get(tab)) do
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
				local path = normalized_buf_path(vim.api.nvim_buf_get_name(buf))
				if path and not seen[path] then
					seen[path] = true
					paths[#paths + 1] = path
				end
			end
		end
		result[tab_index] = paths
	end
	return result
end

local function restore_session_buffers_from_metadata(name, tabs)
	local saved = storage.load_metadata(name)
	if vim.tbl_isempty(saved) then
		return false
	end

	local buffers_by_path = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
			local path = normalized_buf_path(vim.api.nvim_buf_get_name(buf))
			if path then
				buffers_by_path[path] = buf
			end
		end
	end

	local restored = false
	for tab_index, paths in ipairs(saved) do
		local tab = tabs[tab_index]
		if tab and type(paths) == "table" then
			for _, saved_path in ipairs(paths) do
				local normalized_path = normalized_buf_path(saved_path)
				local buf = normalized_path and buffers_by_path[normalized_path]
				if buf then
					state.add(tab, buf)
					restored = true
				end
			end
		end
	end
	return restored
end

local function add_all_normal_buffers_to_tab(tab)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(buf)
			and vim.bo[buf].buftype == ""
			and vim.api.nvim_buf_get_name(buf) ~= ""
		then
			state.add(tab, buf)
		end
	end
end

--- Rebuild state.db from the live tab/window layout after a session load.
--- New bufstate sessions carry an explicit tab->buffer ownership sidecar, which
--- is authoritative. Older sessions without a sidecar fall back to the native
--- window layout:
---   • Window buffers  — nvim_win_get_buf (the buffer visible in the window)
---   • Alternate bufs  — bufnr('#') inside each window (best-effort only)
--- All tabs a buffer appears in are recorded (a buffer in two tabs → owned by both).
---@param name string
---@param restart_lsp boolean
local function post_load_rebuild(name, restart_lsp)
	state.reset()
	local tabs = vim.api.nvim_list_tabpages()
	local restored_from_metadata = restore_session_buffers_from_metadata(name, tabs)
	if not restored_from_metadata then
		for _, tab in ipairs(tabs) do
			local wins = vim.api.nvim_tabpage_list_wins(tab)
			for _, win in ipairs(wins) do
				-- Primary buffer displayed in this window
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
					state.add(tab, buf)
				end
				-- Best-effort legacy fallback: older sessions did not contain
				-- bufstate's explicit ownership metadata, so use Vim's alternate
				-- buffer as a hint for hidden buffers.
				local alt = vim.api.nvim_win_call(win, function()
					return vim.fn.bufnr("#")
				end)
				if alt and alt > 0 and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buftype == "" then
					state.add(tab, alt)
				end
			end
		end
		if #tabs == 1 then
			-- Older bufstate sessions only have :mksession's global badd preamble.
			-- In a single-tab session every normal named buffer belongs to that tab.
			add_all_normal_buffers_to_tab(tabs[1])
		end
	end
	local current_tab = vim.api.nvim_get_current_tabpage()
	filter_for_tab(current_tab)

	if restart_lsp then
		require("bufstate.lsp").restart_clients_for_tab(current_tab)
	end
end

--- Temporarily relist every buffer known to state.db (across all tabs) so that
--- :mksession records them in its `badd` preamble. Without this, buffers on
--- non-current tabs are unlisted (our filter hid them) and are silently dropped
--- from the session file.
--- Always paired with a filter_for_tab() call immediately after :mksession.
local function relist_all_for_save()
	filtering = true
	for _, bufs in pairs(state.db) do
		for buf in pairs(bufs) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.bo[buf].buflisted = true
			end
		end
	end
	filtering = false
end

--- Save wrapper used by all save paths in init.lua.
--- Relists all known buffers before :mksession so nothing is dropped, then
--- restores the buflisted filter for the current tab.
--- Raises on failure (same contract as storage.save).
---@param name string
local function do_save(name)
	local buffers_by_tab = collect_session_buffers()
	relist_all_for_save()
	local ok, err = pcall(function()
		storage.save(name) -- raises on failure
		storage.save_metadata(name, buffers_by_tab) -- raises on failure
	end)
	filter_for_tab(vim.api.nvim_get_current_tabpage())
	if not ok then
		error(err, 0)
	end
	session.current = name
end

-- ── safe buffer delete / wipeout ─────────────────────────────────────────────

--- Core: switch away from `buf`, then run `cmd` to remove it.
--- If buf is not the current buffer, runs `cmd` immediately.
---@param buf integer
---@param cmd string  "bdelete" or "bwipeout"
local function safe_remove(buf, cmd)
	if vim.api.nvim_get_current_buf() == buf then
		vim.cmd("bprevious")
		-- bprevious is a no-op when there is nothing else to switch to
		if vim.api.nvim_get_current_buf() == buf then
			vim.cmd("enew")
		end
	end
	pcall(vim.cmd, cmd .. " " .. buf)
end

-- ── public API ────────────────────────────────────────────────────────────────

--- Returns true if buf belongs to the current tab.
--- Wire this into bufferline's custom_filter option:
---   custom_filter = require("bufstate").buf_filter
---@param buf integer
---@return boolean
function M.buf_filter(buf)
	local tab = vim.api.nvim_get_current_tabpage()
	return state.has(tab, buf)
end

--- Safe bdelete — keeps the tab alive.
--- Wire into bufferline: close_command = function(buf) require("bufstate").bdelete(buf) end
---@param buf? integer  defaults to current buffer
function M.bdelete(buf)
	safe_remove(buf or vim.api.nvim_get_current_buf(), "bdelete")
end

--- Safe bwipeout — keeps the tab alive.
---@param buf? integer  defaults to current buffer
function M.bwipeout(buf)
	safe_remove(buf or vim.api.nvim_get_current_buf(), "bwipeout")
end

-- ── watch window ──────────────────────────────────────────────────────────────

local watch_buf = nil
local watch_win = nil
local watch_timer = nil

--- Build a human-readable snapshot of state.db for display.
---@return string
local function db_snapshot()
	local tabs = vim.api.nvim_list_tabpages()
	local current_tab = vim.api.nvim_get_current_tabpage()

	local lines = { "bufstate.nvim state:" }
	for _, tab in ipairs(tabs) do
		local marker = tab == current_tab and " *" or ""
		local bufs = state.get(tab)
		local names = {}
		for _, buf in ipairs(bufs) do
			local name = vim.api.nvim_buf_get_name(buf)
			name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("[buf " .. buf .. "]")
			names[#names + 1] = name
		end
		lines[#lines + 1] = string.format("  tab %d%s: [%s]", tab, marker, table.concat(names, ", "))
	end

	-- Orphaned (dead) tab entries still in db
	local live = {}
	for _, t in ipairs(tabs) do
		live[t] = true
	end
	for tab in pairs(state.db) do
		if not live[tab] then
			lines[#lines + 1] = string.format("  tab %d (dead): %d buf(s)", tab, vim.tbl_count(state.db[tab]))
		end
	end

	return table.concat(lines, "\n")
end

local function watch_refresh()
	if not watch_buf or not vim.api.nvim_buf_is_valid(watch_buf) then
		return
	end
	local lines = vim.split(db_snapshot(), "\n", { plain = true })
	vim.api.nvim_buf_set_option(watch_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(watch_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(watch_buf, "modifiable", false)
end

local function watch_open()
	if watch_win and vim.api.nvim_win_is_valid(watch_win) then
		vim.api.nvim_set_current_win(watch_win)
		return
	end

	watch_buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
	vim.api.nvim_buf_set_option(watch_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(watch_buf, "filetype", "bufstate-watch")

	local width = 60
	local height = 15
	local nvim_ui = vim.api.nvim_list_uis()[1]
	watch_win = vim.api.nvim_open_win(watch_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = 1,
		col = (nvim_ui and nvim_ui.width or 120) - width - 2,
		style = "minimal",
		border = "rounded",
		title = " bufstate state ",
		title_pos = "center",
		zindex = 50,
	})

	watch_refresh()

	watch_timer = (vim.uv or vim.loop).new_timer()
	watch_timer:start(
		500,
		500,
		vim.schedule_wrap(function()
			if not watch_win or not vim.api.nvim_win_is_valid(watch_win) then
				watch_timer:stop()
				watch_timer = nil
				watch_buf = nil
				watch_win = nil
				return
			end
			watch_refresh()
		end)
	)
end

local function watch_close()
	if watch_timer then
		watch_timer:stop()
		watch_timer = nil
	end
	if watch_win and vim.api.nvim_win_is_valid(watch_win) then
		vim.api.nvim_win_close(watch_win, true)
	end
	watch_win = nil
	watch_buf = nil
end

-- ── setup ─────────────────────────────────────────────────────────────────────

function M.setup(_opts)
	_opts = _opts or {}
	local augroup = vim.api.nvim_create_augroup("BufstateNvim", { clear = true })

	-- LSP config
	local stop_lsp_on_session_load = _opts.stop_lsp_on_session_load ~= false -- default true
	local stop_lsp_on_tab_leave = _opts.stop_lsp_on_tab_leave ~= false -- default true

	-- Wire session.lua's save calls through our relist-aware wrapper so that
	-- :mksession always sees all buffers across all tabs (not just the current
	-- tab's listed ones).
	session.set_save_fn(do_save)

	-- ── autocmds ────────────────────────────────────────────────────────────────

	-- State write: buffer explicitly opened by the user
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = augroup,
		callback = function(ev)
			local tab = vim.api.nvim_get_current_tabpage()
			state.add(tab, ev.buf)
			filter_for_tab(tab)
		end,
	})

	-- State write: buffer added via :badd (BufReadPost never fires for :badd)
	vim.api.nvim_create_autocmd("BufAdd", {
		group = augroup,
		callback = function(ev)
			if filtering then
				return
			end
			-- Suppress during session :source — the global `badd` preamble fires
			-- before tabs are restored, so tab context is wrong. post_load_rebuild()
			-- will assign buffers to the correct tabs after :source completes.
			if loading then
				return
			end
			if vim.bo[ev.buf].buftype ~= "" then
				return
			end
			local tab = vim.api.nvim_get_current_tabpage()
			state.add(tab, ev.buf)
		end,
	})

	-- State write: buffer deleted by the user
	vim.api.nvim_create_autocmd("BufDelete", {
		group = augroup,
		callback = function(ev)
			if filtering then
				return
			end
			state.remove(ev.buf)
		end,
	})

	-- On TabLeave: unlist everything so no bleed between tabs; stop LSP
	vim.api.nvim_create_autocmd("TabLeave", {
		group = augroup,
		callback = function()
			local tab = vim.api.nvim_get_current_tabpage()
			unlist_all()
			if stop_lsp_on_tab_leave then
				require("bufstate.lsp").stop_clients_for_tab(tab)
			end
		end,
	})

	-- On TabEnter: list only the buffers that belong to this tab; restart LSP
	vim.api.nvim_create_autocmd("TabEnter", {
		group = augroup,
		callback = function()
			local tab = vim.api.nvim_get_current_tabpage()
			filter_for_tab(tab)
			require("bufstate.lsp").restart_clients_for_tab(tab)
		end,
	})

	-- Cleanup: purge dead tab handles from db
	vim.api.nvim_create_autocmd("TabClosed", {
		group = augroup,
		callback = function()
			local live = {}
			for _, t in ipairs(vim.api.nvim_list_tabpages()) do
				live[t] = true
			end
			for tab in pairs(state.db) do
				if not live[tab] then
					state.purge_tab(tab)
				end
			end
		end,
	})

	-- ── debug / watch commands ───────────────────────────────────────────────────

	vim.api.nvim_create_user_command("BufstateDebug", function()
		vim.notify(db_snapshot(), vim.log.levels.INFO, { title = "bufstate.nvim" })
	end, { desc = "Print bufstate.nvim state" })

	vim.api.nvim_create_user_command("BufstateWatch", function()
		if watch_win and vim.api.nvim_win_is_valid(watch_win) then
			watch_close()
		else
			watch_open()
		end
	end, { desc = "Toggle bufstate.nvim live state watch window" })

	-- ── safe delete commands ─────────────────────────────────────────────────────

	vim.api.nvim_create_user_command("Bdelete", function()
		M.bdelete()
	end, {
		desc = "Delete buffer without closing the tab",
	})
	vim.api.nvim_create_user_command("Bwipeout", function()
		M.bwipeout()
	end, {
		desc = "Wipeout buffer without closing the tab",
	})

	vim.cmd([[
    cnoreabbrev <expr> bd getcmdtype() == ":" && getcmdline() == "bd" ? "Bdelete"  : "bd"
    cnoreabbrev <expr> bw getcmdtype() == ":" && getcmdline() == "bw" ? "Bwipeout" : "bw"
  ]])

	-- ── session commands ────────────────────────────────────────────────────────

	-- :BufstateSave [name] — save current session (prompts if no name and no current)
	vim.api.nvim_create_user_command("BufstateSave", function(cmd_opts)
		local name = cmd_opts.args ~= "" and cmd_opts.args or session.current
		if name then
			local ok, err = pcall(do_save, name)
			if not ok then
				vim.notify(err, vim.log.levels.ERROR)
			else
				vim.notify("Session saved: " .. name, vim.log.levels.INFO)
			end
		else
			ui.prompt_session_name(function(input)
				local ok, err = pcall(do_save, input)
				if not ok then
					vim.notify(err, vim.log.levels.ERROR)
				else
					vim.notify("Session saved as: " .. input, vim.log.levels.INFO)
				end
			end, { prompt = "Save session as: " })
		end
	end, { nargs = "?", desc = "Save current session" })

	-- :BufstateSaveAs [name] — always prompts / accepts explicit name
	vim.api.nvim_create_user_command("BufstateSaveAs", function(cmd_opts)
		local function run_save(name)
			local ok, err = pcall(do_save, name)
			if not ok then
				vim.notify(err, vim.log.levels.ERROR)
			else
				vim.notify("Session saved as: " .. name, vim.log.levels.INFO)
			end
		end
		if cmd_opts.args ~= "" then
			run_save(cmd_opts.args)
		else
			ui.prompt_session_name(run_save, { prompt = "Save session as: " })
		end
	end, { nargs = "?", desc = "Save session with a new name" })

	-- :BufstateLoad [name] — load a session (snacks picker if no name)
	vim.api.nvim_create_user_command("BufstateLoad", function(cmd_opts)
		local function do_load(name)
			if stop_lsp_on_session_load then
				require("bufstate.lsp").stop_all_clients()
			end
			loading = true
			local ok, err = session.load(name)
			loading = false
			if not ok then
				vim.notify(err or "Failed to load session", vim.log.levels.ERROR)
			else
				post_load_rebuild(name, stop_lsp_on_session_load)
				vim.notify("Session loaded: " .. name, vim.log.levels.INFO)
			end
		end
		if cmd_opts.args ~= "" then
			do_load(cmd_opts.args)
		else
			local sessions = storage.list()
			if #sessions == 0 then
				vim.notify("No sessions found", vim.log.levels.WARN)
				return
			end
			ui.show_session_picker(sessions, function(s)
				do_load(s.name)
			end, {
				prompt = "Load session: ",
			})
		end
	end, { nargs = "?", desc = "Load a session" })

	-- :BufstateDelete [name] — delete a session (snacks picker if no name)
	vim.api.nvim_create_user_command("BufstateDelete", function(cmd_opts)
		local function do_delete(name)
			local ok, err = session.delete(name)
			if not ok then
				vim.notify(err or "Failed to delete session", vim.log.levels.ERROR)
			else
				vim.notify("Session deleted: " .. name, vim.log.levels.INFO)
			end
		end
		if cmd_opts.args ~= "" then
			do_delete(cmd_opts.args)
		else
			local sessions = storage.list()
			if #sessions == 0 then
				vim.notify("No sessions found", vim.log.levels.WARN)
				return
			end
			ui.show_session_picker(sessions, function(s)
				do_delete(s.name)
			end, {
				prompt = "Delete session: ",
			})
		end
	end, { nargs = "?", desc = "Delete a session" })

	-- :BufstateNew [name] — save current then start a fresh workspace
	vim.api.nvim_create_user_command("BufstateNew", function(cmd_opts)
		local function do_new(name)
			local ok, err = session.new(name)
			if not ok then
				vim.notify(err or "Failed to create session", vim.log.levels.ERROR)
			else
				vim.notify("New session: " .. name, vim.log.levels.INFO)
			end
		end
		if cmd_opts.args ~= "" then
			do_new(cmd_opts.args)
		else
			ui.prompt_session_name(do_new, { prompt = "New session name: " })
		end
	end, { nargs = "?", desc = "Start a new session (saves current first)" })

	-- :BufstateList — print all sessions
	vim.api.nvim_create_user_command("BufstateList", function()
		local sessions = storage.list()
		if #sessions == 0 then
			vim.notify("No sessions found", vim.log.levels.WARN)
			return
		end
		local lines = { "bufstate.nvim sessions:" }
		for _, s in ipairs(sessions) do
			local ts = os.date("%Y-%m-%d %H:%M", s.mtime)
			local marker = s.name == session.current and " *" or ""
			lines[#lines + 1] = string.format("  %s%s  (%s)", s.name, marker, ts)
		end
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "bufstate.nvim" })
	end, { desc = "List all saved sessions" })

	-- ── autosave ────────────────────────────────────────────────────────────────

	local autosave = require("bufstate.autosave")
	autosave.setup(_opts.autosave or {}, augroup)

	vim.api.nvim_create_user_command("AutosaveStatus", function()
		local s = autosave.get_status()
		vim.notify(
			string.format(
				"Autosave — enabled: %s | paused: %s | session: %s | last save: %s | interval: %.1f min",
				s.enabled and "yes" or "no",
				s.paused and "yes" or "no",
				s.session,
				s.last_save,
				s.interval_minutes
			),
			vim.log.levels.INFO,
			{ title = "bufstate.nvim" }
		)
	end, { desc = "Show autosave status" })

	vim.api.nvim_create_user_command("AutosavePause", autosave.pause, { desc = "Pause autosave" })
	vim.api.nvim_create_user_command("AutosaveResume", autosave.resume, { desc = "Resume autosave" })
	vim.api.nvim_create_user_command("AutosaveNow", function()
		autosave.perform_autosave()
		vim.notify("Autosave triggered", vim.log.levels.INFO)
	end, { desc = "Trigger autosave immediately" })

	-- ── autoload last session on startup ────────────────────────────────────────

	if _opts.autoload_last_session then
		local function do_autoload()
			if #vim.fn.argv() > 0 then
				return
			end -- nvim opened with file args
			local name = storage.get_last_loaded()
			if name then
				if stop_lsp_on_session_load then
					require("bufstate.lsp").stop_all_clients()
				end
				loading = true
				local ok, err = session.load(name)
				loading = false
				if not ok then
					vim.notify("Failed to auto-load session: " .. (err or ""), vim.log.levels.WARN)
				else
					post_load_rebuild(name, stop_lsp_on_session_load)
					vim.notify("Session auto-loaded: " .. name, vim.log.levels.INFO)
				end
			end
		end

		if vim.v.vim_did_enter == 1 then
			vim.schedule(do_autoload)
		else
			vim.api.nvim_create_autocmd("VimEnter", {
				group = augroup,
				once = true,
				callback = function()
					vim.schedule(do_autoload)
				end,
			})
		end
	end

	vim.g.bufstate_setup_called = 1
end

return M
