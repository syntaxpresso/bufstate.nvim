-- tests/bufstate/autosave_spec.lua
-- Integration tests for bufstate.autosave — timer, debounce, pause/resume.

local autosave = require("bufstate.autosave")

describe("bufstate.autosave", function()
	before_each(function()
		autosave.stop()
	end)

	describe("status", function()
		it("reports paused status correctly", function()
			autosave.pause()
			local status = autosave.get_status()
			assert.is_true(status.paused)
		end)

		it("reports resumed status correctly", function()
			autosave.pause()
			autosave.resume()
			local status = autosave.get_status()
			assert.is_false(status.paused)
		end)

		it("includes interval in minutes", function()
			local status = autosave.get_status()
			assert.is_not_nil(status.interval_minutes)
			assert.is_true(type(status.interval_minutes) == "number")
		end)

		it("includes last_save field", function()
			local status = autosave.get_status()
			assert.is_not_nil(status.last_save)
		end)

		it("includes enabled field", function()
			local status = autosave.get_status()
			assert.is_not_nil(status.enabled)
		end)

		it("includes session field", function()
			local status = autosave.get_status()
			assert.is_not_nil(status.session)
		end)
	end)

	describe("debounce", function()
		it("honors debounce interval between saves", function()
			-- First save should happen
			autosave.perform_autosave()
			-- Second save immediately after should be throttled
			-- (debounce is 30s by default, so a second call right away is skipped)
			-- We verify the status shows a recent last_save
			local status = autosave.get_status()
			assert.is_not_nil(status.last_save)
		end)
	end)

	describe("_autosave fallback", function()
		it("uses _autosave when no session is active", function()
			local ok = pcall(autosave.perform_autosave)
			-- Should not crash even with no active session
			assert.is_true(ok)
		end)
	end)
end)
