#!/usr/bin/env lua

-- Demel - A CLI music scrobbler with AI assistance
local VERSION = "0.2.0"

-- Add src to package path
local str = debug.getinfo(1, "S").source:sub(2)
local path = str:match("(.*/)") or "./"
package.path = package.path .. ";" .. path .. "src/?.lua"

local os = require "os"
local utils = require "utils"
local config = require "config"
local gemini = require "gemini"
local musicbrainz = require "musicbrainz"
local listenbrainz = require "listenbrainz"
local cache = require "cache"
local stats = require "stats"
local history = require "history"

-- === CLI ARGUMENTS ===

local function show_help()
    print([[
Demel - CLI Music Scrobbler with AI assistance

Usage: demel [OPTIONS]

Options:
  -h, --help          Show this help message
  -v, --version       Show version information
  --clear-cache       Clear the MusicBrainz search cache
  --debug             Enable debug logging
  --stats             Show scrobbling statistics
  --export [file]     Export stats to CSV
  --history [n]       Show recent search history (default: 10)
  --clear-history     Clear search history

Environment Variables:
  DEMEL_LOG_LEVEL     Set log verbosity (0=SILENT, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG)
  GEMINI_API_KEY      Your Gemini API key
  LISTENBRAINZ_TOKEN  Your ListenBrainz user token

Examples:
  demel                    Start interactive mode
  demel --clear-cache      Clear cached search results
  DEMEL_LOG_LEVEL=4 demel  Run with debug logging
]])
    os.exit(0)
end

local function show_version()
    print("Demel v" .. VERSION)
    print("A CLI music scrobbler with AI-powered intent parsing")
    os.exit(0)
end

-- Parse arguments
for i, arg in ipairs(arg) do
    if arg == "-h" or arg == "--help" then
        show_help()
    elseif arg == "-v" or arg == "--version" then
        show_version()
    elseif arg == "--clear-cache" then
        cache.clear()
        print("Cache cleared!")
        os.exit(0)
    elseif arg == "--debug" then
        os.setenv("DEMEL_LOG_LEVEL", "4")
    elseif arg == "--stats" then
        stats.show_stats()
        os.exit(0)
    elseif arg == "--export" then
        local filename = arg[i + 1]
        stats.export_csv(filename)
        os.exit(0)
    elseif arg == "--history" then
        local count = tonumber(arg[i + 1]) or 10
        history.show_recent(count)
        os.exit(0)
    elseif arg == "--clear-history" then
        history.clear()
        os.exit(0)
    end
end

-- === INITIALIZATION ===

-- Check Env
config.check_env()

print("\n\27[1mWelcome to Demel\27[0m")
print("----------------")

-- Check Connections
if not gemini.check_connection() then os.exit(1) end
if not listenbrainz.check_connection() then os.exit(1) end

print("\n\27[32mSystem Ready.\27[0m Type 'exit' or 'quit' to leave.")

-- === HELPERS ===

local function get_start_time()
    print("Time? (HH:MM [24h], 'now', or Enter for now)")
    io.write("> ")
    local time_str = io.read()

    if time_str == "" or time_str == "now" then
        return os.time()
    end

    local hour, min = time_str:match("(%d+):(%d+)")
    if hour and min then
        local date = os.date("*t")
        date.hour = tonumber(hour)
        date.min = tonumber(min)
        date.sec = 0
        return os.time(date)
    else
        utils.print_err("Invalid format. Using 'now'.")
        return os.time()
    end
end

-- === MAIN LOOP ===

while true do
    io.write("\n\27[1mDemel > \27[0m")
    local user_input = io.read()

    if not user_input or user_input == "exit" or user_input == "quit" then
        print("Bye!")
        break
    end

    if user_input ~= "" then
        -- Step 1: Gemini Processing
        local intent = gemini.parse_intent(user_input)

        if intent.type == "chat" then
            print("\n\27[36m[AI]\27[0m " .. intent.message)
        else
            -- Interactive Fallback for Missing Artist
            if intent.artist == "Unknown Artist" then
                print("\n\27[33m[?]\27[0m I couldn't identify the artist for '" .. intent.title .. "'.")
                io.write("Who is the artist? > ")
                local manual_artist = io.read()
                if manual_artist and manual_artist ~= "" then
                    -- Use Gemini to resolve the artist name from the user's input
                    intent.artist = gemini.resolve_artist(manual_artist, intent.title)
                    -- Rebuild search query since we have new info
                    intent.search_query = intent.artist .. " " .. intent.title
                end
            end

            local detected_msg = "Detected: " .. intent.type:upper() .. " | " .. intent.artist .. " - " .. intent.title
            if intent.album then
                detected_msg = detected_msg .. " (Album: " .. intent.album .. ")"
            end
            utils.print_gemini(detected_msg)

            -- Step 2: MusicBrainz Search
            local results = musicbrainz.search(intent)

            if results then
                local selected = musicbrainz.select_result(results, intent)

                -- Step 3: Action
                if intent.type == "album" then
                    print("\n" .. intent.title .. " is an entire album.")
                    local start_time = get_start_time()

                    utils.print_info("Fetching tracklist...")
                    local tracks = musicbrainz.get_album_tracks(selected.id)

                    local current_ts = start_time
                    for _, track in ipairs(tracks) do
                        listenbrainz.submit_listen(track.artist, track.title, selected.title, current_ts)
                        stats.record_scrobble(track.artist, track.title, selected.title, current_ts)
                        -- Add duration (ms to seconds) for next track's timestamp
                        current_ts = current_ts + (track.duration / 1000)
                    end

                    utils.print_success("Full album scrobbled!")

                    -- Record album in history
                    history.add_entry(user_input, intent.artist, intent.title, selected.title)

                else
                    -- Single Track
                    local start_time = get_start_time()
                    local artist = selected["artist-credit"][1].name
                    local title = selected.title
                    local album = selected.releases[1].title
                    listenbrainz.submit_listen(artist, title, album, start_time)
                    stats.record_scrobble(artist, title, album, start_time)

                    -- Record in history
                    history.add_entry(user_input, artist, title, album)
                end
            end
        end
    end
end
