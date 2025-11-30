#!/usr/bin/env lua

-- Cache module for reducing API calls to MusicBrainz
local cjson = require "cjson"
local os = require "os"

local M = {}

-- Simple file-based cache
local CACHE_DIR = os.getenv("HOME") .. "/.cache/demel"
local CACHE_TTL = 86400 -- 24 hours in seconds

local function ensure_cache_dir()
    os.execute("mkdir -p '" .. CACHE_DIR .. "'")
end

local function get_cache_path(key)
    -- Create safe filename from key using MD5-like simple hash
    local hash = 0
    for i = 1, #key do
        hash = (hash * 31 + string.byte(key, i)) % 1000000
    end
    return CACHE_DIR .. "/" .. hash .. ".json"
end

function M.get(key)
    ensure_cache_dir()
    local path = get_cache_path(key)
    
    local file = io.open(path, "r")
    if not file then return nil end
    
    local content = file:read("*a")
    file:close()
    
    local status, data = pcall(cjson.decode, content)
    if not status then return nil end
    
    -- Check if cache is expired
    if os.time() - data.timestamp > CACHE_TTL then
        os.remove(path)
        return nil
    end
    
    return data.value
end

function M.set(key, value)
    ensure_cache_dir()
    local path = get_cache_path(key)
    
    local cache_entry = {
        timestamp = os.time(),
        value = value
    }
    
    local file = io.open(path, "w")
    if file then
        file:write(cjson.encode(cache_entry))
        file:close()
    end
end

function M.clear()
    os.execute("rm -rf '" .. CACHE_DIR .. "'")
end

return M
