local os = require "os"
local utils = require "utils"

local M = {}

-- Helper to load .env file
local function load_env()
    local file = io.open(".env", "r")
    if not file then return end

    for line in file:lines() do
        -- Skip comments and empty lines
        if not line:match("^#") and line:match("=") then
            local key, value = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
            if key and value then
                -- Remove quotes if present
                value = value:gsub("^['\"]", ""):gsub("['\"]$", "")
                -- Set in os environment so os.getenv works, or just return table
                -- But since we use os.getenv below, let's just set M fields if not env
                if not os.getenv(key) then
                    -- We can't easily set os env in Lua 5.1/JIT portably without C,
                    -- so we'll store in a local table or just return it.
                    -- For this module, we'll just prioritize env vars, then file.
                    M[key] = value
                end
            end
        end
    end
    file:close()
end

-- Load .env first
load_env()

-- Prioritize Environment Variables, fallback to .env values loaded into M
M.GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or M.GEMINI_API_KEY
M.LISTENBRAINZ_TOKEN = os.getenv("LISTENBRAINZ_TOKEN") or M.LISTENBRAINZ_TOKEN
M.GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key="

function M.check_env()
    if not M.GEMINI_API_KEY or not M.LISTENBRAINZ_TOKEN then
        utils.print_err("Missing Configuration.")
        print("Please set GEMINI_API_KEY and LISTENBRAINZ_TOKEN in the .env file or as environment variables.")
        os.exit(1)
    end
end

return M
