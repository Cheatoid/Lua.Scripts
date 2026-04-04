-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local error = error
local setmetatable = setmetatable

--- Generic function to create metamethod objects.
--- @param metamethod_name string The name of the metamethod (e.g., `__mul`, `__pow`).
--- @param syntax_hint string The error message hint for usage (e.g., "use * syntax").
--- @param tostring_char string The character to display in tostring.
--- @return function factory A function that creates metamethod objects.
local function create_metamethod_factory(metamethod_name, syntax_hint, tostring_char)
	return function(func)
		return setmetatable({},
			{
				[metamethod_name] = function(_, ...) return func(...) end,
				__call = function() return error(syntax_hint, 2) end,
				__index = function() return error(syntax_hint, 2) end,
				__newindex = function() return error("cannot change immutable table", 2) end,
				__tostring = function() return tostring_char end,
				__metatable = false,
				__mode = "kv",
			})
	end
end

-- Create specific metamethod factories using the generic function.
local __pow = create_metamethod_factory("__pow", "use ^ syntax", "^")
local __unm = create_metamethod_factory("__unm", "use unary - syntax", "unary -")
local __bnot = create_metamethod_factory("__bnot", "use ~ syntax", "~")
local __concat = create_metamethod_factory("__concat", "use .. syntax", "..")
local __mul = create_metamethod_factory("__mul", "use * syntax", "*")
local __div = create_metamethod_factory("__div", "use / syntax", "/")
local __idiv = create_metamethod_factory("__idiv", "use // syntax", "//")
local __mod = create_metamethod_factory("__mod", "use % syntax", "%")
local __add = create_metamethod_factory("__add", "use + syntax", "+")
local __sub = create_metamethod_factory("__sub", "use - syntax", "-")
local __shl = create_metamethod_factory("__shl", "use << syntax", "<<")
local __shr = create_metamethod_factory("__shr", "use >> syntax", ">>")
local __bxor = create_metamethod_factory("__bxor", "use ~ syntax", "~")
local __len = create_metamethod_factory("__len", "use # syntax", "#")

return {
	create_metamethod_factory = create_metamethod_factory,
	-- Sorted by operator precedence (highest to lowest).
	default = {
		-- @formatter:off
		__pow = __pow,       -- ^
		__unm = __unm,       -- unary -
		__bnot = __bnot,     -- unary ~
		__concat = __concat, -- ..
		__mul = __mul,       -- *
		__div = __div,       -- /
		__idiv = __idiv,     -- //
		__mod = __mod,       -- %
		__add = __add,       -- +
		__sub = __sub,       -- -
		__shl = __shl,       -- <<
		__shr = __shr,       -- >>
		__bxor = __bxor,     -- ~
		__len = __len,       -- #
		-- @formatter:on
	}
}
