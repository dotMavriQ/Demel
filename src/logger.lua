-- Logging module with verbosity levels
local M = {}

-- Log levels
M.LEVEL = {
    SILENT = 0,
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4
}

-- Default level from environment or INFO
M.current_level = tonumber(os.getenv("DEMEL_LOG_LEVEL")) or M.LEVEL.INFO

local function should_log(level)
    return level <= M.current_level
end

function M.set_level(level)
    M.current_level = level
end

function M.error(msg)
    if should_log(M.LEVEL.ERROR) then
        print("\27[31m[ERROR]\27[0m " .. msg)
    end
end

function M.warn(msg)
    if should_log(M.LEVEL.WARN) then
        print("\27[33m[WARN]\27[0m " .. msg)
    end
end

function M.info(msg)
    if should_log(M.LEVEL.INFO) then
        print("\27[34m[INFO]\27[0m " .. msg)
    end
end

function M.debug(msg)
    if should_log(M.LEVEL.DEBUG) then
        print("\27[90m[DEBUG]\27[0m " .. msg)
    end
end

function M.success(msg)
    if should_log(M.LEVEL.INFO) then
        print("\27[32m[SUCCESS]\27[0m " .. msg)
    end
end

function M.gemini(msg)
    if should_log(M.LEVEL.INFO) then
        print("\27[35m[GEMINI]\27[0m " .. msg)
    end
end

return M
