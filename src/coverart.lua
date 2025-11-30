-- Album art fetcher using MusicBrainz Cover Art Archive
local utils = require "utils"
local cjson = require "cjson"

local M = {}

function M.get_cover_art_url(release_mbid)
    if not release_mbid then return nil end

    local url = "https://coverartarchive.org/release/" .. release_mbid
    local res = utils.curl_get(url, 1) -- Only 1 retry for cover art

    if not res or res == "" then return nil end

    local status, data = pcall(cjson.decode, res)
    if not status then return nil end

    -- Get the front cover
    if data.images then
        for _, image in ipairs(data.images) do
            if image.front then
                return image.thumbnails and image.thumbnails.small or image.image
            end
        end
        -- If no front cover, return first image
        if #data.images > 0 then
            return data.images[1].thumbnails and data.images[1].thumbnails.small or data.images[1].image
        end
    end

    return nil
end

function M.download_cover(release_mbid, output_path)
    local url = M.get_cover_art_url(release_mbid)
    if not url then
        print("[INFO] No cover art found for this release")
        return false
    end

    output_path = output_path or "cover.jpg"

    local cmd = "curl -s -L '" .. url .. "' -o '" .. output_path .. "'"
    local result = os.execute(cmd)

    if result == 0 then
        print("[SUCCESS] Cover art saved to: " .. output_path)
        return true
    else
        print("[ERROR] Failed to download cover art")
        return false
    end
end

function M.display_cover_ascii(release_mbid)
    -- This requires 'jp2a' or similar tool to convert image to ASCII
    -- Check if jp2a is installed
    local check = io.popen("which jp2a 2>/dev/null")
    local jp2a_path = check:read("*a")
    check:close()

    if jp2a_path == "" then
        print("[INFO] Install 'jp2a' to display album art in terminal")
        return false
    end

    local url = M.get_cover_art_url(release_mbid)
    if not url then return false end

    -- Download to temp file and convert to ASCII
    local temp_file = "/tmp/demel_cover.jpg"
    local download_cmd = "curl -s -L '" .. url .. "' -o '" .. temp_file .. "'"
    os.execute(download_cmd)

    local ascii_cmd = "jp2a --width=60 '" .. temp_file .. "'"
    os.execute(ascii_cmd)
    os.execute("rm '" .. temp_file .. "'")

    return true
end

return M
