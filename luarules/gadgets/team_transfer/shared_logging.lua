-- This is the part where I invent log levels again because springsettings.cfg says it sets flush log level to 15 but it still won't output INFO logs

---@class TeamTransferLogger
local M = {}

-- Configuration - CENTRALIZED CONTROL
local GLOBAL_LOG_MODE = "NONE"  -- Change this single line to control ALL TeamTransfer logging
local TEAM_TRANSFER_LOG_SECTION = "TeamTransfer"

-- Core logging function
local function TeamTransferLog(level, message, ...)
	if GLOBAL_LOG_MODE == "NONE" then
		return
	end

	local shouldLog = false
	if GLOBAL_LOG_MODE == "DEBUG" then
		shouldLog = true
	elseif GLOBAL_LOG_MODE == "INFO" and (level == "INFO" or level == "ERROR") then
		shouldLog = true
	elseif GLOBAL_LOG_MODE == "ERROR" and level == "ERROR" then
		shouldLog = true
	end

	if shouldLog then
		-- Check if Spring is available (handles test environments where Spring isn't mocked yet)
		if Spring and Spring.Log and LOG and LOG.ERROR then
			Spring.Log(TEAM_TRANSFER_LOG_SECTION, LOG.ERROR, "[" .. level .. "] " .. message, ...)
		else
			-- Fallback to print for test environments
			print("[" .. TEAM_TRANSFER_LOG_SECTION .. ":" .. level .. "] " .. message)
		end
	end
end

-- Public logging functions
function M.LogDebug(message, ...) TeamTransferLog("DEBUG", message, ...) end
function M.LogInfo(message, ...) TeamTransferLog("INFO", message, ...) end
function M.LogError(message, ...) TeamTransferLog("ERROR", message, ...) end

-- Legacy functions for compatibility (now no-ops since logging is centralized)
function M.SetLogMode(mode)
	-- No-op: Log mode is now hardcoded in GLOBAL_LOG_MODE above
end

-- Get current log mode
function M.GetLogMode()
	return GLOBAL_LOG_MODE
end

return M
