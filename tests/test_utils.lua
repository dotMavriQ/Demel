#!/usr/bin/env lua

-- Simple test framework
local tests_passed = 0
local tests_failed = 0

local function assert_equals(actual, expected, test_name)
    if actual == expected then
        print("✓ " .. test_name)
        tests_passed = tests_passed + 1
    else
        print("✗ " .. test_name)
        print("  Expected: " .. tostring(expected))
        print("  Got: " .. tostring(actual))
        tests_failed = tests_failed + 1
    end
end

local function assert_true(condition, test_name)
    assert_equals(condition, true, test_name)
end

-- Load utils module
package.path = package.path .. ";../src/?.lua"
local utils = require "utils"

-- Test URL encoding
print("\n=== Testing URL Encoding ===")
assert_equals(utils.url_encode("hello world"), "hello%20world", "URL encode spaces")
assert_equals(utils.url_encode("foo&bar"), "foo%26bar", "URL encode ampersand")
assert_equals(utils.url_encode("test@example.com"), "test%40example.com", "URL encode @ symbol")
assert_equals(utils.url_encode("hello-world_test.file~name"), "hello-world_test.file~name", "URL encode preserves safe chars")

-- Test that we have the print functions
print("\n=== Testing Print Functions ===")
assert_true(type(utils.print_info) == "function", "print_info exists")
assert_true(type(utils.print_success) == "function", "print_success exists")
assert_true(type(utils.print_err) == "function", "print_err exists")
assert_true(type(utils.print_gemini) == "function", "print_gemini exists")

-- Test that curl functions exist
print("\n=== Testing Curl Functions ===")
assert_true(type(utils.curl_get) == "function", "curl_get exists")
assert_true(type(utils.curl_post) == "function", "curl_post exists")

-- Summary
print("\n=== Test Summary ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)

if tests_failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
