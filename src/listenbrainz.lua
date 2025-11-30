local cjson = require "cjson"
local utils = require "utils"
local config = require "config"

local M = {}

function M.check_connection()
    utils.print_info("Verifying ListenBrainz Token...")
    local url = "https://api.listenbrainz.org/1/validate-token"
    local headers = { "Authorization: Token " .. config.LISTENBRAINZ_TOKEN }

    local res = utils.curl_get(url .. "?token=" .. config.LISTENBRAINZ_TOKEN)
    local data = cjson.decode(res)

    if data.valid then
        utils.print_success("ListenBrainz Token Valid (User: " .. data.user_name .. ")")
        return true
    else
        utils.print_err("ListenBrainz Token Invalid.")
        return false
    end
end

function M.submit_listen(artist, track_name, release_name, timestamp)
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
        "Authorization: Token " .. config.LISTENBRAINZ_TOKEN,
        "Content-Type: application/json"
    }

    -- Endpoint is submit-listens (plural)
    local response = utils.curl_post("https://api.listenbrainz.org/1/submit-listens", headers, json_body)

    local status, data = pcall(cjson.decode, response)
    if status and data.status == "ok" then
        utils.print_success(string.format("Scrobbled: %s - %s @ %s", artist, track_name, os.date("%H:%M", timestamp)))
    else
        utils.print_err("Failed to scrobble to ListenBrainz.")
        print("Response: " .. (response or "nil"))
        print("Payload: " .. json_body)
    end
end

return M
