-- lua/bufstate/autosave.lua
-- Periodic and exit-triggered session save with debouncing, pause/resume, and status.

local M = {}

local uv = vim.uv or vim.loop

-- ── state ─────────────────────────────────────────────────────────────────────

local timer         = nil
local last_save_time = 0
local paused        = false

local config = {
  enabled  = true,
  on_exit  = true,
  interval = 300000, -- 5 minutes (ms)
  debounce = 30000,  -- 30 seconds (ms)
}

-- ── internal ──────────────────────────────────────────────────────────────────

local function get_current_session()
  local session = require("bufstate.session")
  return session.current
end

-- ── public API ────────────────────────────────────────────────────────────────

--- Perform a silent autosave, respecting debounce and paused state.
function M.perform_autosave()
  if paused then return end

  local now = uv.now()
  if now - last_save_time < config.debounce then return end

  local name = get_current_session() or "_autosave"
  local ok = pcall(function()
    require("bufstate.session").save(name)
  end)
  if ok then
    last_save_time = now
  end
end

--- Start the periodic timer.
function M.start()
  if not config.enabled or config.interval <= 0 then return end
  M.stop()
  timer = uv.new_timer()
  if timer then
    timer:start(config.interval, config.interval, vim.schedule_wrap(M.perform_autosave))
  end
end

--- Stop the periodic timer.
function M.stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

--- Pause autosave without stopping the timer.
function M.pause()
  paused = true
  vim.notify("Autosave paused", vim.log.levels.INFO)
end

--- Resume autosave.
function M.resume()
  paused = false
  vim.notify("Autosave resumed", vim.log.levels.INFO)
end

--- Return a status table.
---@return { enabled: boolean, paused: boolean, session: string, last_save: string, interval_minutes: number }
function M.get_status()
  return {
    enabled          = config.enabled,
    paused           = paused,
    session          = get_current_session() or "_autosave",
    last_save        = last_save_time > 0
                         and os.date("%Y-%m-%d %H:%M:%S", last_save_time / 1000)
                         or "Never",
    interval_minutes = config.interval / 60000,
  }
end

--- Set up autosave. Called by init.lua during M.setup().
---@param user_config table
---@param augroup integer  the BufstateNvim augroup handle
function M.setup(user_config, augroup)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  if not config.enabled then return end

  if config.on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group    = augroup,
      callback = M.perform_autosave,
    })
  end

  if config.interval > 0 then
    M.start()
  end
end

return M
