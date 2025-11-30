This is a cool concept! Calling it **Demel** (Lua de Mel) is a great name.

To make this robust on Linux without creating a dependency nightmare, I have designed this to run with **Lua 5.1+ (or LuaJIT)**.

### Prerequisites

You will need to install a few standard tools and Lua libraries.

```bash
# Ubuntu/Debian
sudo apt install lua5.1 liblua5.1-0-dev luarocks curl

# Arch
sudo pacman -S lua luarocks curl

# Install the JSON library for Lua
sudo luarocks install lua-cjson
```

### The Setup

You will need two API keys:
1.  **Google Gemini API Key**: (Get from aistudio.google.com)
2.  **ListenBrainz User Token**: (Get from listenbrainz.org/profile)

### The `demel` Script

Save the following code as `demel`.

```lua
#!/usr/bin/env lua
local cjson = require "cjson"
local os = require "os"

-- CONFIGURATION
local GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
local LISTENBRAINZ_TOKEN = os.getenv("LISTENBRAINZ_TOKEN")
local GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key="

-- COLOR HELPERS
local function print_info(msg) print("\27[34m[DEMEL]\27[0m " .. msg) end
local function print_success(msg) print("\27[32m[SUCCESS]\27[0m " .. msg) end
local function print_err(msg) print("\27[31m[ERROR]\27[0m " .. msg) end
local function print_gemini(msg) print("\27[35m[GEMINI]\27[0m " .. msg) end

-- CHECK ENV
if not GEMINI_API_KEY or not LISTENBRAINZ_TOKEN then
    print_err("Missing Environment Variables.")
    print("Please export GEMINI_API_KEY and LISTENBRAINZ_TOKEN")
    os.exit(1)
end

-- HELPER: EXECUTE CURL
local function curl_post(url, headers, body)
    local cmd = "curl -s -X POST '" .. url .. "'"
    for _, h in ipairs(headers) do
        cmd = cmd .. " -H '" .. h .. "'"
    end
    -- Escape single quotes in JSON body for shell safety
    local safe_body = body:gsub("'", "'\\''")
    cmd = cmd .. " -d '" .. safe_body .. "'"

    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function curl_get(url)
    local cmd = "curl -s -L '" .. url .. "' -H 'User-Agent: DemelCLI/1.0 ( lua-cli )'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- 1. TALK TO GEMINI TO PARSE INTENT
local function parse_intent_with_gemini(user_input)
    print_info("Asking Gemini to interpret: '" .. user_input .. "'...")

    local prompt = {
        contents = {{
            parts = {{
                text = [[
                You are a helper for a CLI music scrobbler.
                Analyze the user's request. They might mention an album or a track.

                Return ONLY valid JSON. No markdown formatting.
                Structure:
                {
                    "type": "album" or "track",
                    "artist": "extracted artist name",
                    "title": "extracted album or track title",
                    "search_query": "Artist Name Album/Track Title"
                }

                Input: "]] .. user_input .. [[".
                ]]
            }}
        }}
    }

    local json_body = cjson.encode(prompt)
    local res = curl_post(GEMINI_URL .. GEMINI_API_KEY, {"Content-Type: application/json"}, json_body)

    local data = cjson.decode(res)

    if data.candidates and data.candidates[1].content then
        local raw_text = data.candidates[1].content.parts[1].text
        -- Strip markdown code blocks if Gemini adds them
        raw_text = raw_text:gsub("```json", ""):gsub("```", "")
        return cjson.decode(raw_text)
    else
        print_err("Gemini failed to understand.")
        os.exit(1)
    end
end

-- 2. SEARCH MUSICBRAINZ
local function search_musicbrainz(intent)
    print_info("Searching MusicBrainz for: " .. intent.search_query)

    local q = intent.search_query:gsub(" ", "%%20")
    local entity = (intent.type == "album") and "release" or "recording"
    local url = "https://musicbrainz.org/ws/2/" .. entity .. "?query=" .. q .. "&fmt=json&limit=5"

    local res = curl_get(url)
    local data = cjson.decode(res)

    local results = (intent.type == "album") and data.releases or data.recordings

    if not results or #results == 0 then
        print_err("Not found in MusicBrainz DB.")
        print_gemini("To add this manually, go here:")
        print("https://musicbrainz.org/" .. entity .. "/add")
        os.exit(0)
    end

    return results
end

-- 3. USER SELECTION
local function select_result(results, intent_type)
    print("\nSelect the correct " .. intent_type .. ":")
    for i, item in ipairs(results) do
        local artist = item["artist-credit"][1].name
        local title = item.title
        local date = item.date or "Unknown Date"
        print(string.format(" %d) %s - %s (%s)", i, artist, title, date))
    end
    print(" 0) None of these (Show me how to add it)")

    io.write("\n> ")
    local choice = io.read("*n")

    if choice == 0 then
        print_gemini("Please contribute to the database here:")
        local entity = (intent_type == "album") and "release" or "recording"
        print("https://musicbrainz.org/" .. entity .. "/add")
        os.exit(0)
    end

    return results[choice]
end

-- 4. HANDLE ALBUM TRACKLIST
local function get_album_tracks(release_id)
    local url = "https://musicbrainz.org/ws/2/release/" .. release_id .. "?inc=recordings&fmt=json"
    local res = curl_get(url)
    local data = cjson.decode(res)

    local tracks = {}
    for _, medium in ipairs(data.media) do
        for _, track in ipairs(medium.tracks) do
            table.insert(tracks, {
                title = track.title,
                artist = track["artist-credit"][1].name,
                duration = track.length or 180000 -- default 3 mins if missing
            })
        end
    end
    return tracks
end

-- 5. SUBMIT TO LISTENBRAINZ
local function submit_listen(artist, track_name, release_name, timestamp)
    local payload = {
        listen_type = "import",
        payload = {{
            listened_at = math.floor(timestamp),
            track_metadata = {
                artist_name = artist,
                track_name = track_name,
                release_name = release_name
            }
        }}
    }

    local json_body = cjson.encode(payload)
    local headers = {
        "Authorization: Token " .. LISTENBRAINZ_TOKEN,
        "Content-Type: application/json"
    }

    curl_post("https://api.listenbrainz.org/1/submit-listen", headers, json_body)
    print_success("Scrobbled: " .. artist .. " - " .. track_name)
end

-- === MAIN LOGIC ===

local args = {...}
local user_input = table.concat(args, " ")

if #args == 0 then
    print_info("Usage: demel \"I want to scrobble the white album by Queen\"")
    os.exit(0)
end

-- Step 1: Gemini Processing
local intent = parse_intent_with_gemini(user_input)
print_gemini("Detected: " .. intent.type:upper() .. " | " .. intent.artist .. " - " .. intent.title)

-- Step 2: MusicBrainz Search
local results = search_musicbrainz(intent)
local selected = select_result(results, intent.type)

-- Step 3: Action
if intent.type == "album" then
    print("\n" .. intent.title .. " is an entire album.")
    print("What time did you START listening? (format HH:MM in 24h, or type 'now')")
    io.write("> ")
    io.read() -- clear buffer
    local time_str = io.read()

    local start_time = os.time()

    if time_str ~= "now" then
        local hour, min = time_str:match("(%d+):(%d+)")
        if hour and min then
            local date = os.date("*t")
            date.hour = tonumber(hour)
            date.min = tonumber(min)
            date.sec = 0
            start_time = os.time(date)
        else
            print_err("Invalid time format. Using 'now'.")
        end
    end

    print_info("Fetching tracklist...")
    local tracks = get_album_tracks(selected.id)

    local current_ts = start_time
    for _, track in ipairs(tracks) do
        submit_listen(track.artist, track.title, selected.title, current_ts)
        -- Add duration (ms to seconds) for next track's timestamp
        current_ts = current_ts + (track.duration / 1000)
    end

    print_success("Full album scrobbled!")

else
    -- Single Track
    submit_listen(selected["artist-credit"][1].name, selected.title, selected.releases[1].title, os.time())
end
```

### How to install & run

1.  **Make it executable:**
    ```bash
    chmod +x demel
    ```

2.  **Move it to your path** (Optional):
    ```bash
    sudo mv demel /usr/local/bin/
    ```

3.  **Run it:**

    *Note: Replace the API key below with your actual mockup or real key.*

    ```bash
    export GEMINI_API_KEY="AIzbSyCg72lgjZYpGwqnDRUmXqJY5n_0YG4z5M8"
    export LISTENBRAINZ_TOKEN="your_actual_listenbrainz_token_here"

    # For an album
    ./demel "I want to scrobble that white album from Queen"

    # For a track
    ./demel "I just heard Bohemian Rhapsody"
    ```

### How it works (The Logic)

1.  **Lua & cURL**: Instead of compiling complex HTTP libraries, Demel wraps `curl` commands. This makes it portable across almost any Linux distro.
2.  **Gemini 1.5 (API v1beta)**:
    *   It takes your natural language ("that white album").
    *   It acts as a parser to extract structured data (`{ artist="Queen", title="The White Album", type="album" }`).
    *   It cleans the input for the MusicBrainz search.
3.  **MusicBrainz Grounding**:
    *   It doesn't trust the AI to generate IDs (which leads to hallucinations).
    *   It uses the AI's extracted text to search the official MusicBrainz API.
    *   It asks **you** to verify the release (e.g., distinguishing between the 1968 original and the 2018 remaster).
4.  **Fallback**:
    *   If MusicBrainz returns nothing, Demel provides the direct link to the MusicBrainz "Add Release" page, satisfying the requirement to guide the user on how to add it manually.
5.  **Smart Timestamping**:
    *   If you select an Album, it asks for the *start time*.
    *   It fetches the duration of every track in that album.
    *   It mathematically calculates the exact timestamp for every track (Track 1 @ 14:00, Track 2 @ 14:04, etc.) so your ListenBrainz history looks accurate.
