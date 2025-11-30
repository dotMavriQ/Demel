local M = {}

function M.print_info(msg) print("\27[34m[DEMEL]\27[0m " .. msg) end
function M.print_success(msg) print("\27[32m[SUCCESS]\27[0m " .. msg) end
function M.print_err(msg) print("\27[31m[ERROR]\27[0m " .. msg) end
function M.print_gemini(msg) print("\27[35m[GEMINI]\27[0m " .. msg) end

function M.curl_post(url, headers, body)
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

function M.curl_get(url)
    local cmd = "curl -s -L '" .. url .. "' -H 'User-Agent: DemelCLI/1.0 ( lua-cli )'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

function M.url_encode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])",
            function(c) return string.format("%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "%%20")
    end
    return str
end

return M
