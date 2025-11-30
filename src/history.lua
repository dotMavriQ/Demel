-- Search history module to track and reuse recent searches
local cjson = require "cjson"
local os = require "os"

local M = {}

local HISTORY_DIR = os.getenv("HOME") .. "/.local/share/demel"
local HISTORY_FILE = HISTORY_DIR .. "/history.json"
local MAX_HISTORY = 50

local function ensure_history_dir()
    os.execute("mkdir -p '" .. HISTORY_DIR .. "'")
end

local function load_history()
    ensure_history_dir()
    local file = io.open(HISTORY_FILE, "r")
    if not file then
        return {}
    end

    local content = file:read("*a")
    file:close()

    local status, data = pcall(cjson.decode, content)
    if not status then
        return {}
    end

    return data
end

local function save_history(history)
    ensure_history_dir()
    local file = io.open(HISTORY_FILE, "w")
    if file then
        file:write(cjson.encode(history))
        file:close()
    end
end

function M.add_entry(query, artist, title, album)
    local history = load_history()

    local entry = {
        timestamp = os.time(),
        query = query,
        artist = artist,
        title = title,
        album = album
    }

    -- Add to beginning of history
    table.insert(history, 1, entry)

    -- Keep only MAX_HISTORY entries
    while #history > MAX_HISTORY do
        table.remove(history)
    end

    save_history(history)
end

function M.show_recent(count)
    count = count or 10
    local history = load_history()

    if #history == 0 then
        print("\n[INFO] No search history yet")
        return
    end

    print("\n" .. string.rep("=", 60))
    print("📜 Recent Searches")
    print(string.rep("=", 60))

    for i = 1, math.min(count, #history) do
        local entry = history[i]
        local time_str = os.date("%Y-%m-%d %H:%M", entry.timestamp)
        local result = entry.artist .. " - " .. entry.title
        if entry.album then
            result = result .. " (" .. entry.album .. ")"
        end
        print(string.format("%2d. [%s] %s", i, time_str, result))
        print(string.format("    Query: '%s'", entry.query))
    end

    print(string.rep("=", 60) .. "\n")
end

function M.get_entry(index)
    local history = load_history()
    return history[index]
end

function M.clear()
    os.execute("rm -f '" .. HISTORY_FILE .. "'")
    print("[INFO] Search history cleared")
end

return M
