-- Statistics and analytics module for tracking scrobbling habits
local cjson = require "cjson"
local os = require "os"

local M = {}

local STATS_DIR = os.getenv("HOME") .. "/.local/share/demel"
local STATS_FILE = STATS_DIR .. "/stats.json"

local function ensure_stats_dir()
    os.execute("mkdir -p '" .. STATS_DIR .. "'")
end

local function load_stats()
    ensure_stats_dir()
    local file = io.open(STATS_FILE, "r")
    if not file then
        return {
            total_scrobbles = 0,
            artists = {},
            albums = {},
            tracks = {},
            first_scrobble = nil,
            last_scrobble = nil
        }
    end

    local content = file:read("*a")
    file:close()

    local status, data = pcall(cjson.decode, content)
    if not status then
        return {
            total_scrobbles = 0,
            artists = {},
            albums = {},
            tracks = {},
            first_scrobble = nil,
            last_scrobble = nil
        }
    end

    return data
end

local function save_stats(stats)
    ensure_stats_dir()
    local file = io.open(STATS_FILE, "w")
    if file then
        file:write(cjson.encode(stats))
        file:close()
    end
end

function M.record_scrobble(artist, track, album, timestamp)
    local stats = load_stats()

    stats.total_scrobbles = stats.total_scrobbles + 1

    -- Track artist counts
    if not stats.artists[artist] then
        stats.artists[artist] = 0
    end
    stats.artists[artist] = stats.artists[artist] + 1

    -- Track album counts
    if album then
        if not stats.albums[album] then
            stats.albums[album] = {count = 0, artist = artist}
        end
        stats.albums[album].count = stats.albums[album].count + 1
    end

    -- Track specific track counts
    local track_key = artist .. " - " .. track
    if not stats.tracks[track_key] then
        stats.tracks[track_key] = 0
    end
    stats.tracks[track_key] = stats.tracks[track_key] + 1

    -- Update timestamps
    if not stats.first_scrobble then
        stats.first_scrobble = timestamp
    end
    stats.last_scrobble = timestamp

    save_stats(stats)
end

function M.show_stats()
    local stats = load_stats()

    print("\n" .. string.rep("=", 50))
    print("📊 Demel Statistics")
    print(string.rep("=", 50))

    print(string.format("\nTotal Scrobbles: %d", stats.total_scrobbles))

    if stats.first_scrobble then
        print(string.format("First Scrobble: %s", os.date("%Y-%m-%d %H:%M", stats.first_scrobble)))
        print(string.format("Last Scrobble: %s", os.date("%Y-%m-%d %H:%M", stats.last_scrobble)))
    end

    -- Top artists
    print("\n🎤 Top 5 Artists:")
    local artist_list = {}
    for artist, count in pairs(stats.artists) do
        table.insert(artist_list, {name = artist, count = count})
    end
    table.sort(artist_list, function(a, b) return a.count > b.count end)

    for i = 1, math.min(5, #artist_list) do
        print(string.format("  %d. %s (%d plays)", i, artist_list[i].name, artist_list[i].count))
    end

    -- Top albums
    print("\n💿 Top 5 Albums:")
    local album_list = {}
    for album, data in pairs(stats.albums) do
        table.insert(album_list, {name = album, count = data.count, artist = data.artist})
    end
    table.sort(album_list, function(a, b) return a.count > b.count end)

    for i = 1, math.min(5, #album_list) do
        print(string.format("  %d. %s - %s (%d plays)",
            i, album_list[i].artist, album_list[i].name, album_list[i].count))
    end

    -- Top tracks
    print("\n🎵 Top 5 Tracks:")
    local track_list = {}
    for track, count in pairs(stats.tracks) do
        table.insert(track_list, {name = track, count = count})
    end
    table.sort(track_list, function(a, b) return a.count > b.count end)

    for i = 1, math.min(5, #track_list) do
        print(string.format("  %d. %s (%d plays)", i, track_list[i].name, track_list[i].count))
    end

    print("\n" .. string.rep("=", 50) .. "\n")
end

function M.export_csv(filename)
    local stats = load_stats()
    filename = filename or "demel_export.csv"

    local file = io.open(filename, "w")
    if not file then
        print("[ERROR] Could not write to " .. filename)
        return false
    end

    file:write("Type,Name,Count,Artist\n")

    for artist, count in pairs(stats.artists) do
        file:write(string.format("Artist,%s,%d,\n", artist:gsub(",", ";"), count))
    end

    for album, data in pairs(stats.albums) do
        file:write(string.format("Album,%s,%d,%s\n",
            album:gsub(",", ";"), data.count, data.artist:gsub(",", ";")))
    end

    for track, count in pairs(stats.tracks) do
        file:write(string.format("Track,%s,%d,\n", track:gsub(",", ";"), count))
    end

    file:close()
    print("[SUCCESS] Exported stats to " .. filename)
    return true
end

return M
