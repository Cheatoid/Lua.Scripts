return function()
	local autocompleter = require "autocompleter"

	-- 1. Create an instance
	local ac = autocompleter.new()
	print("autocompleter instance created")

	-- 2. Insert words
	local words_to_insert = {
		"apple", "apricot", "application", "apply", "app", "Appliance",
		"banana", "bandana", "bank",
		"cat", "catalog", "category", "concatenate",
		"lua", "luarocks", "lunar", "LuaScript",
		"WriteLine", "ReadLine", "write_line_to_console",
		"appleTree"
	}

	print("\nInserting words:")
	for _, word in ipairs(words_to_insert) do
		ac:insert(word)
		print("- Inserted: " .. word)
	end
	ac:insert("apple") -- Test inserting duplicate, should be handled

	-- Test inserting non-string/empty (should be handled gracefully)
	ac:insert(123)
	ac:insert(nil)
	ac:insert("")

	-- 3. Get completions
	local function test_completions(input, options, test_name)
		print("\n-- Testing: " .. test_name)
		print("Input: '" .. input .. "', Options: ")
		if options then
			for k, v in pairs(options) do print(string.format(" %s = %s", tostring(k), tostring(v))) end
		else
			print("  (default)")
		end

		local completions = ac:get_completions(input, options)
		if #completions > 0 then
			print("Completions found:")
			for i, comp_word in ipairs(completions) do
				print(string.format("  %d. %s", i, comp_word))
			end
		else
			print("  No completions found.")
		end
	end

	-- Test A: Default (Prefix only)
	test_completions("ap", nil, "Default (Prefix only) for 'ap'")
	test_completions("App", nil, "Default (Prefix only) for 'App' (case-sensitive)") -- Expect Appliance

	-- Test B: Prefix matching explicitly
	test_completions("app", { prefix = true }, "Prefix only for 'app'")

	-- Test C: Shorthand matching
	test_completions("apn", { shorthand = true, prefix = false }, "Shorthand for 'apn' (e.g., application)")
	test_completions("RL", { shorthand = true, prefix = false }, "Shorthand for 'RL' (e.g., ReadLine)")
	test_completions("wltc", { shorthand = true, prefix = false }, "Shorthand for 'wltc' (e.g., write_line_to_console)")

	-- Test D: Substring matching
	test_completions("cat", { substring = true, prefix = false },
		"Substring for 'cat' (e.g., catalog, category, concatenate)")
	test_completions("Line", { substring = true, prefix = false },
		"Substring for 'Line' (e.g., WriteLine, ReadLine, write_line_to_console)")

	-- Test E: Combined matching strategies
	test_completions("app", { prefix = true, shorthand = true, substring = true, max_results = 5 },
		"Combined for 'app', max 5")
	-- Expect: app, apple, application, apply, Appliance (prefix matches first)

	test_completions("lua", { prefix = true, shorthand = true, substring = true, max_results = 5 },
		"Combined for 'lua', max 5")
	-- Expect: lua, luarocks, lunar, LuaScript (prefix matches first)

	-- Test F: Max results
	test_completions("a", { prefix = true, max_results = 3 }, "Prefix for 'a', max 3")

	-- Test G: Empty input
	test_completions("", { prefix = true }, "Empty input (all words via prefix if enabled)")
	test_completions("", { shorthand = true, prefix = false },
		"Empty input (shorthand - should be empty or all based on impl)")
	test_completions("", { substring = true, prefix = false },
		"Empty input (substring - should be empty or all based on impl)")

	-- Test H: No matches
	test_completions("xyz", { prefix = true, shorthand = true, substring = true }, "No matches for 'xyz'")

	-- Test I: Shorthand that could also be a prefix
	test_completions("app", { shorthand = true, prefix = false },
		"Shorthand for 'app' (should find 'apple', 'application', 'apply', 'Appliance')")

	-- Test J: Input that is a full word
	test_completions("apple", { prefix = true, shorthand = true, substring = true, max_results = 5 }, "Full word 'apple'")

	-- Test K: Fuzzy Matching
	test_completions("aple",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 1 },
		"Fuzzy for 'aple' (expect 'apple', distance 1)")
	test_completions("aplle",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 1 },
		"Fuzzy for 'aplle' (expect 'apple', distance 1)")
	test_completions("banna",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 1 },
		"Fuzzy for 'banna' (expect 'banana', 'bandana' distance 1)")
	test_completions("bannna",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 2 },
		"Fuzzy for 'bannna' (expect 'banana', 'bandana' distance 2)")
	test_completions("bannna",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 1 },
		"Fuzzy for 'bannna', max_edit_distance 1 (should not find banana/bandana)")
	test_completions("LiaScript",
		{ fuzzy = true, prefix = false, shorthand = false, substring = false, max_edit_distance = 2 },
		"Fuzzy for 'LiaScript' (expect 'LuaScript', distance 2)")

	-- Test L: Fuzzy Matching combined with other strategies
	test_completions("aple",
		{ prefix = true, shorthand = true, substring = true, fuzzy = true, max_edit_distance = 1, max_results = 5 },
		"Combined with Fuzzy for 'aple', max 5")
	-- Expect 'apple' (from fuzzy), potentially others if 'aple' was a prefix/shorthand/substring of something else.

	-- Test M: Fuzzy matching with an input that is also a prefix
	test_completions("app", { prefix = true, fuzzy = true, max_edit_distance = 1, max_results = 10 },
		"Prefix 'app' with Fuzzy enabled")
	-- Expect: app, apple, application, apply, Appliance (from prefix)
	--         + any fuzzy matches for "app" if they are different and within distance 1 (e.g. if "axp" existed)

	-- Test N: Exact Match Prioritization
	test_completions("apple", { prefix = true, max_results = 5 },
		"Exact Match 'apple' (should be first, then 'appleTree')")

	print("\nExample with new features (including fuzzy matching and exact match priority) finished.")
end
