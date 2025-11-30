local cjson = require "cjson"
local utils = require "utils"
local config = require "config"
local os = require "os"

local M = {}

function M.check_connection()
    utils.print_info("Verifying Gemini API connection...")
    local prompt = {
        contents = {{
            parts = {{ text = "Hello" }}
        }}
    }
    local json_body = cjson.encode(prompt)
    local res = utils.curl_post(config.GEMINI_URL .. config.GEMINI_API_KEY, {"Content-Type: application/json"}, json_body)
    local data = cjson.decode(res)

    if data.candidates then
        utils.print_success("Gemini API Connected.")
        return true
    else
        utils.print_err("Gemini API Connection Failed.")
        print("Response: " .. res) -- Debug output
        return false
    end
end

function M.parse_intent(user_input)
    utils.print_info("Asking Gemini to interpret: '" .. user_input .. "'...")

    local prompt = {
        contents = {{
            parts = {{
                text = [[
                You are Demel, a helpful CLI music scrobbler assistant.
                Analyze the user's input.

                1. If the user is greeting you, asking for help, or chatting generally (e.g. "hello", "how does this work?", "hi"), return:
                {
                    "type": "chat",
                    "message": "A helpful, friendly response explaining that you can scrobble music by saying things like 'I listened to [Song] by [Artist]'."
                }

                2. If the user wants to scrobble music (e.g. "I listened to...", "scrobble...", or just a song name), return:
                {
                    "type": "album" or "track",
                    "artist": "extracted artist name or null",
                    "title": "extracted album or track title",
                    "album": "extracted album name if specified (e.g. 'from the album X') or null",
                    "search_query": "Artist Name Album/Track Title"
                }

                IMPORTANT: If the user provides only a song title (e.g. "Green Onions", "Bohemian Rhapsody"), and the song is well-known, YOU MUST INFER the artist and populate the "artist" field. Do not leave it null if you are reasonably sure.

                IMPORTANT: If the user asks for "the original" or provides lyrics/description, identify the MOST FAMOUS or ORIGINAL artist for that song. For "Killing Me Softly", it is Roberta Flack (or Fugees if specified). For "I Will Always Love You", it is Whitney Houston or Dolly Parton. Do not pick obscure covers.

                IMPORTANT: Correct common typos or misremembered titles. For example, if the user says "100000 by NIN", they likely mean "1,000,000". If they say "Teen Spirit", they mean "Smells Like Teen Spirit". Use the CORRECT official title in the "title" field.

                Return ONLY valid JSON. No markdown formatting.

                Input: "]] .. user_input .. [[".
                ]]
            }}
        }}
    }

    local json_body = cjson.encode(prompt)
    local res = utils.curl_post(config.GEMINI_URL .. config.GEMINI_API_KEY, {"Content-Type: application/json"}, json_body)

    local data = cjson.decode(res)

    if data.candidates and data.candidates[1].content then
        local raw_text = data.candidates[1].content.parts[1].text
        -- Strip markdown code blocks if Gemini adds them
        raw_text = raw_text:gsub("```json", ""):gsub("```", "")
        local parsed = cjson.decode(raw_text)

                -- Sanitize cjson.null and nil
        if parsed.artist == cjson.null or parsed.artist == nil or parsed.artist == "null" then parsed.artist = "Unknown Artist" end
        if parsed.title == cjson.null or parsed.title == nil or parsed.title == "null" then parsed.title = "Unknown Title" end
        if parsed.album == cjson.null or parsed.album == "null" then parsed.album = nil end

        if parsed.message == cjson.null or parsed.message == nil then
            parsed.message = "I'm here to help with your music scrobbling!"
        end

        return parsed
    else
        utils.print_err("Gemini failed to understand.")
        os.exit(1)
    end
end

function M.refine_selection(options, user_query, original_intent)
    utils.print_info("Asking Gemini to help select...")

    local original_context = ""
    if original_intent then
        original_context = "Original Search Context: " .. (original_intent.search_query or "Unknown")
        if original_intent.artist then original_context = original_context .. "\nOriginal Artist: " .. original_intent.artist end
        if original_intent.title then original_context = original_context .. "\nOriginal Title: " .. original_intent.title end
    end

    local options_text = ""
    for i, item in ipairs(options) do
        local artist = item["artist-credit"] and item["artist-credit"][1].name or "Unknown Artist"
        local title = item.title or "Unknown Title"
        local extra = ""

        -- Use best_release if available (calculated in musicbrainz.lua), otherwise fallback
        local release = item.best_release or (item.releases and item.releases[1])

        if release then
            local date = release.date or "Unknown"
            extra = string.format(" (Album: %s, Date: %s)", release.title, date)
        elseif item.date then
             extra = " (Date: " .. item.date .. ")"
        end

        options_text = options_text .. string.format("%d) %s - %s%s\n", i, artist, title, extra)
    end

    local prompt = {
        contents = {{
            parts = {{
                text = [[
                You are helping a user select the correct music track from a list of search results.

                ]] .. original_context .. [[

                User Refinement: "]] .. user_query .. [["

                Options:
                ]] .. options_text .. [[

                Analyze the options based on the user's refinement and the original context.

                1. If the user is selecting one of the options (e.g. "the second one", "the 2002 version", "the original"), provide the "suggested_index".
                2. If the user indicates the song is WRONG, or the artist is wrong, or wants to search for something else, provide a "new_search_intent".
                   - Infer the Artist, Title, and Album from the conversation.
                   - If the user mentions an album (e.g. "It's on Lust for Life"), put that in "album".
                   - If the user mentions a specific song title, put that in "title".
                   - If the user implies the original song title was correct but the results were wrong, keep the "title".

                Return ONLY valid JSON.
                {
                    "message": "Explanation...",
                    "suggested_index": number or null,
                    "new_search_intent": {
                        "artist": "Artist Name" or null,
                        "title": "Track Title" or null,
                        "album": "Album Name" or null
                    }
                }
                ]]
            }}
        }}
    }

    local json_body = cjson.encode(prompt)
    local res = utils.curl_post(config.GEMINI_URL .. config.GEMINI_API_KEY, {"Content-Type: application/json"}, json_body)
    local data = cjson.decode(res)

    if data.candidates and data.candidates[1].content then
        local raw_text = data.candidates[1].content.parts[1].text
        raw_text = raw_text:gsub("```json", ""):gsub("```", "")
        local parsed = cjson.decode(raw_text)

        -- Sanitize
        if parsed.message == cjson.null then parsed.message = "Refining search..." end
        if parsed.suggested_index == cjson.null then parsed.suggested_index = nil end
        if parsed.new_search_intent == cjson.null then parsed.new_search_intent = nil end

        return parsed
    else
        return { message = "I couldn't figure it out.", suggested_index = nil }
    end
end

function M.resolve_artist(description, song_title)
    utils.print_info("Asking Gemini to identify artist from description...")

    local prompt = {
        contents = {{
            parts = {{
                text = [[
                The user is trying to identify the artist for a song, but provided a description instead of a name.

                Song Title: "]] .. song_title .. [["
                User Description of Artist: "]] .. description .. [["

                Identify the artist name.
                If the user says "google it" or "you should know", use your knowledge to identify the most famous artist for this song.

                Return ONLY valid JSON.
                {
                    "artist": "The Actual Artist Name"
                }
                ]]
            }}
        }}
    }

    local json_body = cjson.encode(prompt)
    local res = utils.curl_post(config.GEMINI_URL .. config.GEMINI_API_KEY, {"Content-Type: application/json"}, json_body)
    local data = cjson.decode(res)

    if data.candidates and data.candidates[1].content then
        local raw_text = data.candidates[1].content.parts[1].text
        raw_text = raw_text:gsub("```json", ""):gsub("```", "")
        local result = cjson.decode(raw_text)
        return result.artist
    else
        return description -- Fallback to original input if AI fails
    end
end

return M
