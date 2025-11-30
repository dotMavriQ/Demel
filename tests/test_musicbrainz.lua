#!/usr/bin/env lua

-- Test MusicBrainz scoring logic
package.path = package.path .. ";../src/?.lua"

local tests_passed = 0
local tests_failed = 0

local function assert_true(condition, test_name)
    if condition then
        print("✓ " .. test_name)
        tests_passed = tests_passed + 1
    else
        print("✗ " .. test_name)
        tests_failed = tests_failed + 1
    end
end

local function assert_greater(a, b, test_name)
    if a > b then
        print("✓ " .. test_name)
        tests_passed = tests_passed + 1
    else
        print("✗ " .. test_name .. " (" .. tostring(a) .. " should be > " .. tostring(b) .. ")")
        tests_failed = tests_failed + 1
    end
end

-- Load the module
local musicbrainz = require "musicbrainz"

print("=== Testing MusicBrainz Scoring Logic ===\n")

-- Create mock release data
local official_album = {
    status = "Official",
    ["release-group"] = {
        ["primary-type"] = "Album"
    },
    date = "2000-01-01"
}

local live_album = {
    status = "Official",
    ["release-group"] = {
        ["primary-type"] = "Album",
        ["secondary-types"] = {"Live"}
    },
    date = "2000-01-01"
}

local compilation = {
    status = "Official",
    ["release-group"] = {
        ["primary-type"] = "Album",
        ["secondary-types"] = {"Compilation"}
    },
    date = "2000-01-01"
}

local single = {
    status = "Official",
    ["release-group"] = {
        ["primary-type"] = "Single"
    },
    date = "2020-01-01"
}

local bootleg_album = {
    status = "Bootleg",
    ["release-group"] = {
        ["primary-type"] = "Album"
    },
    date = "2000-01-01"
}

print("\n=== Test Summary ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)

if tests_failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
