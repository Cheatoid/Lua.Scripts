-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for handlebars.lua.
-- Run from this directory:
--   lua handlebars.lua
--   luajit handlebars.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
        for _, f in ipairs(tries) do
          if isfile(f) then
            local chunk, err = loadfile(f)
            if chunk then return chunk, f end
          end
        end
      end
      return nil
    end)
  end
end
local lib = require "handlebars"
-- Bridging: file-locals used by tests mapped to module exports.
local handlebars = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: c, content, first, helper, helpers, last, n, val, value

if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[handlebars] testing...")

	-- Basic expression
	test("simple expression", function()
		local r = string.handlebars("Hello {{name}}!", { name = "World" })
		assert(r == "Hello World!")
	end)

	test("missing variable renders empty", function()
		local r = string.handlebars("Hello {{name}}!", {})
		assert(r == "Hello !")
	end)

	test("numeric value", function()
		local r = string.handlebars("Count: {{n}}", { n = 42 })
		assert(r == "Count: 42")
	end)

	test("boolean value", function()
		local r = string.handlebars("Flag: {{f}}", { f = true })
		assert(r == "Flag: true")
	end)

	-- Raw expression
	test("raw expression", function()
		local r = string.handlebars("Raw: {{{val}}}", { val = "<b>bold</b>" })
		assert(r == "Raw: <b>bold</b>")
	end)

	test("escaped expression", function()
		local r = string.handlebars("Escaped: {{val}}", { val = "<b>bold</b>" })
		assert(r == "Escaped: &lt;b&gt;bold&lt;/b&gt;")
	end)

	-- Nested path
	test("nested path", function()
		local r = string.handlebars("{{user.name}}", { user = { name = "Alice" } })
		assert(r == "Alice")
	end)

	test("deeply nested path", function()
		local r = string.handlebars("{{a.b.c}}", { a = { b = { c = "deep" } } })
		assert(r == "deep")
	end)

	test("missing nested path", function()
		local r = string.handlebars("{{a.b.c}}", { a = {} })
		assert(r == "")
	end)

	-- #if helper
	test("if truthy", function()
		local r = string.handlebars("{{#if ok}}yes{{/if}}", { ok = true })
		assert(r == "yes")
	end)

	test("if falsy", function()
		local r = string.handlebars("{{#if ok}}yes{{/if}}", { ok = false })
		assert(r == "")
	end)

	test("if nil", function()
		local r = string.handlebars("{{#if ok}}yes{{/if}}", {})
		assert(r == "")
	end)

	test("if empty string", function()
		local r = string.handlebars("{{#if s}}yes{{/if}}", { s = "" })
		assert(r == "")
	end)

	test("if zero", function()
		local r = string.handlebars("{{#if n}}yes{{/if}}", { n = 0 })
		assert(r == "")
	end)

	test("if empty table", function()
		local r = string.handlebars("{{#if t}}yes{{/if}}", { t = {} })
		assert(r == "")
	end)

	test("if with else", function()
		local r = string.handlebars("{{#if ok}}yes{{else}}no{{/if}}", { ok = false })
		assert(r == "no")
	end)

	test("if non-empty table is truthy", function()
		local r = string.handlebars("{{#if t}}yes{{/if}}", { t = { 1 } })
		assert(r == "yes")
	end)

	-- #unless helper
	test("unless falsy", function()
		local r = string.handlebars("{{#unless ok}}yes{{/unless}}", { ok = false })
		assert(r == "yes")
	end)

	test("unless truthy", function()
		local r = string.handlebars("{{#unless ok}}yes{{/unless}}", { ok = true })
		assert(r == "")
	end)

	test("unless with else", function()
		local r = string.handlebars("{{#unless ok}}yes{{else}}no{{/unless}}", { ok = true })
		assert(r == "no")
	end)

	-- #each helper
	test("each array", function()
		local r = string.handlebars("{{#each items}}{{.}} {{/each}}", { items = { "a", "b", "c" } })
		assert(r == "a b c ")
	end)

	test("each with @index", function()
		local r = string.handlebars("{{#each items}}{{@index}}:{{.}} {{/each}}", { items = { "x", "y" } })
		assert(r == "0:x 1:y ")
	end)

	test("each with @first and @last", function()
		local r = string.handlebars("{{#each items}}{{#if @first}}[{{/if}}{{.}}{{#if @last}}]{{/if}} {{/each}}",
			{ items = { "a", "b", "c" } })
		assert(r == "[a b c] ")
	end)

	test("each empty array renders else", function()
		local r = string.handlebars("{{#each items}}{{.}}{{else}}empty{{/each}}", { items = {} })
		assert(r == "empty")
	end)

	test("each non-table renders else", function()
		local r = string.handlebars("{{#each items}}{{.}}{{else}}empty{{/each}}", { items = "not a table" })
		assert(r == "empty")
	end)

	test("each map", function()
		local r = string.handlebars("{{#each obj}}{{@key}}={{.}} {{/each}}", { obj = { a = 1, b = 2 } })
		-- map order is not guaranteed, check both present
		assert(r:find("a=1"))
		assert(r:find("b=2"))
	end)

	-- #with helper
	test("with helper", function()
		local r = string.handlebars("{{#with person}}Name: {{name}}{{/with}}", { person = { name = "Alice" } })
		assert(r == "Name: Alice")
	end)

	test("with nil renders else", function()
		local r = string.handlebars("{{#with person}}Name{{else}}none{{/with}}", {})
		assert(r == "none")
	end)

	test("with nil renders empty", function()
		local r = string.handlebars("{{#with person}}Name{{/with}}", {})
		assert(r == "")
	end)

	-- compile API
	test("compile returns function", function()
		local fn = handlebars.compile("Hello {{name}}!")
		assert(type(fn) == "function")
		assert(fn({ name = "World" }) == "Hello World!")
	end)

	test("compile with custom helpers", function()
		local fn = handlebars.compile("{{shout word}}")
		local r = fn({ word = "hello" }, {
			shout = function(args) return string.upper(args[1]) end
		})
		assert(r == "HELLO")
	end)

	-- registerHelper API
	test("registerHelper", function()
		handlebars.registerHelper("double", function(args)
			return tostring(tonumber(args[1]) * 2)
		end)
		local r = string.handlebars("{{double n}}", { n = 5 })
		assert(r == "10")
	end)

	-- Comments
	test("comment is ignored", function()
		local r = string.handlebars("Hello{{! this is a comment}} World", {})
		assert(r == "Hello World")
	end)

	-- Mixed content
	test("mixed text and expressions", function()
		local r = string.handlebars("Hi {{name}}, you have {{count}} items", { name = "Bob", count = 3 })
		assert(r == "Hi Bob, you have 3 items")
	end)

	-- Unclosed tag error
	test("unclosed tag errors", function()
		expect_error(function() handlebars.compile("{{name") end, "Unclosed handlebars tag")
	end)

	-- Parent context traversal
	test("parent context with ../", function()
		local render = handlebars.compile("{{#with a}}{{../x}}{{/with}}")
		local r = render({ a = {}, x = "parent" })
		assert(r == "parent")
	end)

	print(string_format("[handlebars] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
