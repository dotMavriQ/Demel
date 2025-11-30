-- Batch import module for importing multiple scrobbles from file
local cjson = require "cjson"

local M = {}

function M.parse_csv(filename)
    local file = io.open(filename, "r")
    if not file then
        print("[ERROR] Could not open file: " .. filename)
        return nil
    end

    local entries = {}
    local line_num = 0

    for line in file:lines() do
        line_num = line_num + 1

        -- Skip header line
        if line_num == 1 then
            goto continue
        end

        -- Parse CSV line (simple parsing, doesn't handle quotes with commas)
        local fields = {}
        for field in line:gmatch("[^,]+") do
            table.insert(fields, field:match("^%s*(.-)%s*$")) -- trim whitespace
        end

        if #fields >= 2 then
            table.insert(entries, {
                artist = fields[1],
                title = fields[2],
                album = fields[3] or nil,
                timestamp = tonumber(fields[4]) or os.time()
            })
        end

        ::continue::
    end

    file:close()
    return entries
end

function M.parse_json(filename)
    local file = io.open(filename, "r")
    if not file then
        print("[ERROR] Could not open file: " .. filename)
        return nil
    end

    local content = file:read("*a")
    file:close()

    local status, data = pcall(cjson.decode, content)
    if not status then
        print("[ERROR] Invalid JSON format")
        return nil
    end

    -- Expected format: array of {artist, title, album?, timestamp?}
    return data
end

function M.import_file(filename, format)
    -- Auto-detect format if not specified
    if not format then
        if filename:match("%.json$") then
            format = "json"
        elseif filename:match("%.csv$") then
            format = "csv"
        else
            print("[ERROR] Unknown file format. Use .csv or .json")
            return nil
        end
    end

    local entries
    if format == "csv" then
        entries = M.parse_csv(filename)
    elseif format == "json" then
        entries = M.parse_json(filename)
    else
        print("[ERROR] Unsupported format: " .. format)
        return nil
    end

    return entries
end

function M.create_example_csv(filename)
    filename = filename or "import_example.csv"
    local file = io.open(filename, "w")
    if not file then
        print("[ERROR] Could not create file: " .. filename)
        return false
    end

    file:write("artist,title,album,timestamp\n")
    file:write("Pink Floyd,Comfortably Numb,The Wall,\n")
    file:write("Led Zeppelin,Stairway to Heaven,Led Zeppelin IV,\n")
    file:write("Black Sabbath,Iron Man,Paranoid,\n")

    file:close()
    print("[SUCCESS] Created example file: " .. filename)
    print("[INFO] Edit this file and use: demel --import " .. filename)
    return true
end

function M.create_example_json(filename)
    filename = filename or "import_example.json"
    local file = io.open(filename, "w")
    if not file then
        print("[ERROR] Could not create file: " .. filename)
        return false
    end

    local example = {
        {artist = "Pink Floyd", title = "Comfortably Numb", album = "The Wall"},
        {artist = "Led Zeppelin", title = "Stairway to Heaven", album = "Led Zeppelin IV"},
        {artist = "Black Sabbath", title = "Iron Man", album = "Paranoid"}
    }

    file:write(cjson.encode(example))
    file:close()
    print("[SUCCESS] Created example file: " .. filename)
    print("[INFO] Edit this file and use: demel --import " .. filename)
    return true
end

return M
