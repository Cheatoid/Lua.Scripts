-- The "max" standard is key for multi-version support.
std = "max"

-- 1. Define your project's custom globals.
-- Add any global variables or functions your project defines.
globals = {
	"luameta",
	-- Example: A polyfill for a non-standard function
	"math.round",
	-- Example: A polyfill for a function missing in Lua 5.1
	"table.move",
	"table.unpack",
}

-- 2. Define read-only globals.
-- Use this for polyfills that override standard functions
-- or for APIs that should not be modified.
read_globals = {
	-- Example: Your custom string formatting function
	--"string.customFormat",
	-- Example: The polyfilled table.pack
	"table.pack",
}

-- 3. Ignore specific warnings globally.
-- This is your main tool for suppressing false positives for polyfills.
ignore = {
	-- Ignore warnings about using 'unpack' (common in 5.1 code)
	"unpack",
	-- Ignore warnings about setting fields on the global 'string' table
	"string/.*", -- This pattern ignores all warnings related to the 'string' global
	"string",
	"math/.*",
	"math",
	"table/.*",
	"table",
	-- Ignore specific warning codes
	"211", -- unused variable
	"212", -- unused argument
	"213", -- unused loop variable
	"631", -- line is too long
}

-- 4. Exclude files from checking.
-- Use this for third-party code, build scripts, or tests.
exclude_files = {
	".private/*.lua", -- Private scripts
	"vendor/*.lua", -- Third-party libraries
	"build/*.lua", -- Build scripts
	"test/*.lua",  -- Test files
}

-- 5. Set other options for better output.
-- These are optional but recommended.
max_line_length = 999 -- Set a reasonable line length limit
codes = true          -- Show warning codes (e.g., W211, E011)
ranges = true         -- Show column ranges for issues
