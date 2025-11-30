local cjson = require "cjson"
local utils = require "utils"
local os = require "os"
local gemini = require "gemini" -- Require gemini for refinement
local cache = require "cache"

local M = {}

local function get_release_score(release)
    local score = 0
    if release.status == "Official" then score = score + 100 end

    if release["release-group"] then
        local rg = release["release-group"]
        if rg["primary-type"] == "Album" then score = score + 50 end
        if rg["primary-type"] == "Single" then score = score + 20 end

        if rg["secondary-types"] then
            for _, st in ipairs(rg["secondary-types"]) do
                if st == "Live" then score = score - 50 end
                if st == "Compilation" then score = score - 30 end
                if st == "Remix" then score = score - 40 end
                if st == "Demo" then score = score - 40 end
            end
        end
    end

    -- Prefer older releases (Originals)
    if release.date then
        local year = tonumber(release.date:match("^(%d%d%d%d)"))
        if year then
            score = score + (2025 - year) -- Add 1 point per year of age
        end
    end

    return score
end

local function prioritize_results(results)
    if not results then return nil end

    for _, item in ipairs(results) do
        local best_release = nil
        local best_score = -9999

        if item.releases then
            for _, release in ipairs(item.releases) do
                local score = get_release_score(release)
                if score > best_score then
                    best_score = score
                    best_release = release
                end
            end
        end

        item.best_release = best_release
        item.sort_score = (tonumber(item.score) or 0) + (best_score / 10) -- Weight MB score heavily, but use release quality as tiebreaker/boost
    end

    table.sort(results, function(a, b)
        return (a.sort_score or 0) > (b.sort_score or 0)
    end)

    return results
end

function M.search(intent)
    local entity = (intent.type == "album") and "release" or "recording"
    local results = nil

    local function execute_search(query)
        -- Check cache first
        local cache_key = "mb_search:" .. entity .. ":" .. query
        local cached = cache.get(cache_key)
        if cached then
            utils.print_info("Using cached results for: " .. query)
            return cached
        end

        utils.print_info("Searching MusicBrainz for: " .. query)
        local q = utils.url_encode(query)
        local url = "https://musicbrainz.org/ws/2/" .. entity .. "?query=" .. q .. "&fmt=json&limit=20"

        local res = utils.curl_get(url)
        if not res or res == "" then return nil end

        local status, data = pcall(cjson.decode, res)
        if not status then return nil end

        local results = (intent.type == "album") and data.releases or data.recordings

        -- Cache the results
        if results then
            cache.set(cache_key, results)
        end

        return results
    end

    -- 1. Try Strict Search
    if intent.artist and intent.artist ~= "Unknown Artist" then
        local safe_artist = intent.artist:gsub('"', '\\"')
        local target_field = (intent.type == "album") and "release" or "recording"
        local strict_query = nil

        if intent.title and intent.title ~= "Unknown Title" then
             local safe_title = intent.title:gsub('"', '\\"')
             strict_query = string.format('artist:"%s" AND %s:"%s"', safe_artist, target_field, safe_title)
        end

        -- If we have an album, add it to the query
        if intent.album and intent.album ~= cjson.null then
            local safe_album = intent.album:gsub('"', '\\"')
            if strict_query then
                -- Try strict album first
                local album_strict_query = strict_query .. string.format(' AND release:"%s"', safe_album)
                results = execute_search(album_strict_query)

                -- If strict album search yields few results, try loose album search
                if not results or #results < 3 then
                    utils.print_info("Strict album search yielded few results. Trying loose album search...")
                    local album_loose_query = strict_query .. string.format(' AND release:(%s)', safe_album)
                    local loose_results = execute_search(album_loose_query)

                    if loose_results and #loose_results > 0 then
                        -- Merge results (simple override for now, or append if we had a merge function)
                        results = loose_results
                    end
                end
            else
                strict_query = string.format('artist:"%s" AND release:"%s"', safe_artist, safe_album)
                results = execute_search(strict_query)
            end
        elseif strict_query then
            results = execute_search(strict_query)
        end

        -- 2. Fallback: Loose Search (if no results found yet)
        if (not results or #results == 0) and intent.title and intent.title ~= "Unknown Title" then
            utils.print_info("Strict search failed. Trying loose search...")
            local safe_title = intent.title:gsub('"', '\\"')
            local loose_query = string.format('artist:"%s" AND %s:(%s)', safe_artist, target_field, safe_title)
            results = execute_search(loose_query)
        end
    end

    -- 3. Fallback: Raw Query
    if not results or #results == 0 then
        if intent.search_query and intent.search_query ~= "" then
             utils.print_info("Trying raw query search...")
             results = execute_search(intent.search_query)
        end
    end

    if not results or #results == 0 then
        utils.print_err("Not found in MusicBrainz DB.")
        utils.print_gemini("To add this manually, go here:")
        print("https://musicbrainz.org/" .. entity .. "/add")
        return nil
    end

    return prioritize_results(results)
end

function M.select_result(results, intent)
    local intent_type = intent.type
    print("\nSelect the correct " .. intent_type .. ":")

    -- Only show the top 5 results to the user
    local display_limit = math.min(#results, 5)

    for i = 1, display_limit do
        local item = results[i]
        local artist = item["artist-credit"][1].name
        local title = item.title
        local extra_info = ""

        if intent_type == "album" then
            local date = item.date or "Unknown Date"
            extra_info = "(" .. date .. ")"
        else
            -- For tracks, show Album and Year
            local release = item.best_release or (item.releases and item.releases[1])

            if release then
                local album_name = release.title
                local date = release.date or "Unknown Date"
                local year = date:match("^(%d%d%d%d)") or date
                extra_info = string.format("(%s, %s)", album_name, year)
            else
                extra_info = "(Single/Unknown Album)"
            end
        end

        print(string.format(" %d) %s - %s %s", i, artist, title, extra_info))
    end

    if #results > display_limit then
        print(string.format(" ... and %d more hidden results (ask Gemini to find them)", #results - display_limit))
    end

    print(" 0) None of these (Show me how to add it)")

    io.write("\n> ")
    local input = io.read()
    local choice = tonumber(input)

    if not choice then
        utils.print_gemini("Refining selection based on: '" .. input .. "'...")
        local refinement = gemini.refine_selection(results, input, intent)

        -- Handle New Search Request from Gemini
        if refinement and refinement.new_search_intent then
             local new_intent_data = refinement.new_search_intent
             utils.print_gemini(refinement.message)

             local function clean(v) return (v ~= cjson.null and v ~= "null") and v or nil end

             -- Create a new intent for the search
             local new_intent = {
                 type = intent_type,
                 artist = clean(new_intent_data.artist) or intent.artist,
                 title = clean(new_intent_data.title) or intent.title,
                 album = clean(new_intent_data.album), -- New field
                 search_query = "" -- Will be rebuilt
             }

             -- Rebuild search query for display/fallback
             new_intent.search_query = (new_intent.artist or "") .. " " .. (new_intent.title or "") .. " " .. (new_intent.album or "")

             utils.print_gemini("Switching search to: " .. new_intent.search_query)

             -- Perform new search
             local new_results = M.search(new_intent)
             if new_results then
                 return M.select_result(new_results, new_intent)
             else
                 return nil
             end
        end

        if not refinement or refinement.suggested_index == cjson.null or type(refinement.suggested_index) ~= "number" then
            utils.print_err("I couldn't figure out which one you meant. Please try again.")
            return M.select_result(results, intent_type)
        end

        utils.print_gemini(refinement.message)
        choice = refinement.suggested_index
        print("Gemini picked option: " .. choice)
    end

    if choice == 0 then
        utils.print_gemini("Please contribute to the database here:")
        local entity = (intent_type == "album") and "release" or "recording"
        print("https://musicbrainz.org/" .. entity .. "/add")
        os.exit(0)
    end

    if not results[choice] then
        utils.print_err("Invalid selection.")
        return M.select_result(results, intent_type)
    end

    return results[choice]
end

function M.get_album_tracks(release_id)
    local url = "https://musicbrainz.org/ws/2/release/" .. release_id .. "?inc=recordings&fmt=json"
    local res = utils.curl_get(url)
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

return M
