-- lua/bufstate/state.lua
-- Pure data module. No autocmds, no side effects.
--
-- db layout:
--   state.db = {
--     [tab_handle] = { [buf_id] = true, ... },
--     ...
--   }
--
-- A buffer can be owned by multiple tabs simultaneously.

local M = {}

M.db = {}

--- Add buf to tab's set (always, even if owned elsewhere).
---@param tab integer  tab page handle (from vim.api.nvim_get_current_tabpage)
---@param buf integer  buffer id
function M.add(tab, buf)
	if not M.db[tab] then
		M.db[tab] = {}
	end
	M.db[tab][buf] = true
end

--- Remove buf from every tab that owns it.
---@param buf integer
function M.remove(buf)
	for _, bufs in pairs(M.db) do
		bufs[buf] = nil
	end
end

--- Returns true if tab owns buf.
---@param tab integer
---@param buf integer
---@return boolean
function M.has(tab, buf)
	return M.db[tab] ~= nil and M.db[tab][buf] == true
end

--- Returns a list of all buf ids owned by tab (valid or not).
---@param tab integer
---@return integer[]
function M.get(tab)
	local result = {}
	local bufs = M.db[tab]
	if not bufs then
		return result
	end
	for buf in pairs(bufs) do
		result[#result + 1] = buf
	end
	return result
end

--- Remove a dead tab entry from db.
---@param tab integer
function M.purge_tab(tab)
	M.db[tab] = nil
end

--- Wipe db entirely (used before rebuilding from session load).
function M.reset()
	for k in pairs(M.db) do
		M.db[k] = nil
	end
end

return M
