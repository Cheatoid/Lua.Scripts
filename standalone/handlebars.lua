-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- Lua implementation of the Handlebars (minimal) template engine on steroids.<br>
--- Supports expressions `{{expr}}`, raw expressions `{{{expr}}}`,
--- block helpers `{{#name}}...{{/name}}`, else branches `{{else}}`,
--- and custom helper registration.
---@usage <br>
--- ```
--- local handlebars = require "standalone/handlebars"
--- local render = handlebars.compile("Hello {{name}}!")
--- local output = render({ name = "World" })
--- -- output == "Hello World!"
---
--- -- Quick one-liner via string extension:
--- local output = "Hello {{name}}!":handlebars({ name = "World" })
--- ```
---@class handlebars
---@field helpers table<string, handlebars.HelperFn> Built-in helper functions keyed by name
local handlebars = {}
handlebars.__index = handlebars

-- Localized global functions for better performance
local error = error
local next = next
local tonumber = tonumber
local tostring = tostring
local type = type
local string_find = string.find
local string_gsub = string.gsub
local string_gmatch = string.gmatch
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_unpack = table.unpack or unpack

---@alias handlebars.TokenType
---| "TEXT" # Literal text outside expressions
---| "EXPR" # Escaped expression `{{expr}}`
---| "RAW_EXPR" # Raw unescaped expression `{{{expr}}}`
---| "COMMENT" # Comment tag `{{!...}}`
---| "OPEN_BLOCK" # Block open tag `{{#name args}}`
---| "CLOSE_BLOCK" # Block close tag `{{/name}}`
---| "ELSE" # Else branch tag `{{else}}`

---@class handlebars.Token
---@field type handlebars.TokenType
---@field value? string
---@field name? string
---@field args? string

---@alias handlebars.NodeType
---| "TEXT"
---| "EXPR"
---| "RAW_EXPR"
---| "BLOCK"

---@class handlebars.Node
---@field type handlebars.NodeType
---@field value? string
---@field name? string
---@field args? string[]
---@field body? handlebars.Node[]
---@field else_body? handlebars.Node[]

---@class handlebars.Context
---@field _ctx_ any The wrapped context value
---@field ["@index"]? number Current iteration index (0-based, set by `#each`)
---@field ["@key"]? any Current iteration key (set by `#each`)
---@field ["@first"]? boolean True if first iteration (set by `#each`)
---@field ["@last"]? boolean True if last iteration (set by `#each`)

---@alias handlebars.RenderFn fun(nodes: handlebars.Node[], context_stack: handlebars.Context[], helpers: table<string, handlebars.HelperFn>): string

--- Helper function signature used by block helpers.<br>
--- Block helpers receive the parsed block node, context stack, helpers table,
--- a variable resolver, and a render function for recursive rendering.
---@alias handlebars.HelperFn fun(block_node: handlebars.Node, context_stack: handlebars.Context[], helpers: table<string, handlebars.HelperFn>, resolve_fn: fun(path: string, stack: handlebars.Context[]): any, render_fn: handlebars.RenderFn): string

----------------------------------------------------------------------
-- Utility/Helper Functions
----------------------------------------------------------------------

local html_escapes = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&#39;"
}

--- Escapes HTML special characters in a string to prevent XSS.<br>
--- Non-string values are returned unchanged.
---@param s any The value to escape
---@return any any The escaped string, or the original value if not a string
---@usage <br>
--- ```
--- escape_html("<script>") -- "&lt;script&gt;"
--- escape_html(123)        -- 123 (unchanged)
--- ```
local function escape_html(s)
	if type(s) ~= "string" then return s end
	return string_gsub(s, "[&<>\"']", html_escapes)
end

--- Parses a space-separated argument string, supporting quoted strings.<br>
--- Handles double-quoted and single-quoted arguments.
---@param args_str? string The raw argument string from a template tag
---@return string[] string Array of parsed argument values
---@usage <br>
--- ```
--- parse_args('foo "bar baz"') -- { "foo", "\"bar baz\"" }
--- parse_args("")              -- {}
--- parse_args(nil)             -- {}
--- ```
local function parse_args(args_str)
	local args = {}
	if not args_str or args_str == "" then return args end
	local n = 0
	local i = 1
	local len = #args_str
	while i <= len do
		local c = string_sub(args_str, i, i)
		if c == " " then
			i = i + 1
		elseif c == '"' then
			local close = string_find(args_str, '"', i + 1, true)
			if close then
				n = n + 1
				args[n] = string_sub(args_str, i, close)
				i = close + 1
			else
				n = n + 1
				args[n] = string_sub(args_str, i)
				break
			end
		elseif c == "'" then
			local close = string_find(args_str, "'", i + 1, true)
			if close then
				n = n + 1
				args[n] = string_sub(args_str, i, close)
				i = close + 1
			else
				n = n + 1
				args[n] = string_sub(args_str, i)
				break
			end
		else
			local j = i + 1
			while j <= len and string_sub(args_str, j, j) ~= " " do
				j = j + 1
			end
			n = n + 1
			args[n] = string_sub(args_str, i, j - 1)
			i = j
		end
	end
	return args
end

--- Resolves a variable path against a context stack.<br>
--- Supports dot-separated paths (e.g. `user.name`), parent traversal (`../`), and current context reference (`.`).
---@param path? string The dot-separated variable path to resolve
---@param context_stack handlebars.Context[] The context stack to resolve against
---@return any value The resolved value, or nil if not found
---@usage <br>
--- ```
--- local stack = { { _ctx_ = { user = { name = "Alice" } } } }
--- resolve("user.name", stack) -- "Alice"
--- resolve(".", stack)         -- the current context table
--- resolve("../key", stack)    -- parent context lookup
--- ```
local function resolve(path, context_stack)
	if not path or path == "" then return end
	local depth = #context_stack
	local clean_path = path

	-- Handle ../ (parent context)
	for _ in string_gmatch(path, "%.%./") do
		depth = depth - 1
		if depth < 1 then depth = 1 end
	end
	clean_path = string_gsub(path, "%.%./", "")

	local current = context_stack[depth]
	if not current then return end

	-- Handle current context (.)
	if clean_path == "." or clean_path == "" then
		return current._ctx_ or current
	end

	-- Walk down the path (e.g. user.name)
	for key in string_gmatch(clean_path, "[^.]+") do
		local val
		if type(current) == "table" then
			-- Support handlebars private @ variables injected by #each
			if current._ctx_ and current[key] == nil then
				val = current._ctx_[key]
			else
				val = current[key]
			end
		else
			return -- Cannot traverse a non-table
		end
		if val == nil then return end
		current = val
	end
	return current
end

--- Resolves a helper argument, evaluating quoted strings, numbers, booleans, and variable paths against the context stack.
---@param arg string The raw argument token to resolve
---@param context_stack handlebars.Context[] The current context stack
---@return any value The resolved value
---@usage <br>
--- ```
--- resolve_arg('"hello"', stack) -- "hello" (string)
--- resolve_arg("42", stack)      -- 42 (number)
--- resolve_arg("true", stack)    -- true (boolean)
--- resolve_arg("name", stack)    -- resolves "name" from context
--- ```
local function resolve_arg(arg, context_stack)
	local first = string_sub(arg, 1, 1)
	local last = string_sub(arg, -1, -1)
	if first == '"' and last == '"' then return string_sub(arg, 2, -2) end
	if first == "'" and last == "'" then return string_sub(arg, 2, -2) end
	local num = tonumber(arg)
	if num then return num end
	if arg == "true" then return true end
	if arg == "false" then return false end
	return resolve(arg, context_stack)
end

----------------------------------------------------------------------
-- Tokenizer (Lexer)
----------------------------------------------------------------------

--- Tokenizes a Handlebars template string into an array of tokens.<br>
--- Recognizes expressions (`{{}}`), raw expressions (`{{{}}}`), block open/close tags, else tags, and comments.
---@param template string The raw template string
---@return handlebars.Token[] tokens Array of parsed tokens
---@error string if an unclosed tag is encountered
---@usage <br>
--- ```
--- local tokens = tokenize("Hello {{name}}!")
--- -- tokens[1] = { type = "TEXT", value = "Hello " }
--- -- tokens[2] = { type = "EXPR", value = "name" }
--- -- tokens[3] = { type = "TEXT", value = "!" }
--- ```
local function tokenize(template)
	local tokens = {}
	local pos = 1
	local template_len = #template
	while pos <= template_len do
		local s1 = string_find(template, "{{", pos, true)
		if not s1 then
			tokens[#tokens + 1] = { type = "TEXT", value = string_sub(template, pos) }
			break
		end

		if s1 > pos then
			tokens[#tokens + 1] = { type = "TEXT", value = string_sub(template, pos, s1 - 1) }
		end

		local is_raw = string_sub(template, s1 + 2, s1 + 2) == "{"
		local end_tag = is_raw and "}}}" or "}}"
		local e_tag_len = is_raw and 3 or 2

		local e1 = string_find(template, end_tag, s1 + 2, true)
		if not e1 then return error("Unclosed handlebars tag at position " .. s1) end

		local content = string_match(string_sub(template, s1 + (is_raw and 3 or 2), e1 - 1), "^%s*(.-)%s*$")

		if is_raw then
			tokens[#tokens + 1] = { type = "RAW_EXPR", value = content }
		else
			if string_sub(content, 1, 1) == "!" then
				tokens[#tokens + 1] = { type = "COMMENT", value = string_sub(content, 2) }
			elseif string_sub(content, 1, 1) == "#" then
				local rest = string_match(string_sub(content, 2), "^%s*(.-)%s*$")
				local name = string_match(rest, "^(%S+)")
				local args = string_match(string_sub(rest, #name + 1), "^%s*(.-)%s*$")
				tokens[#tokens + 1] = { type = "OPEN_BLOCK", name = name, args = args }
			elseif string_sub(content, 1, 1) == "/" then
				tokens[#tokens + 1] = { type = "CLOSE_BLOCK", name = string_match(string_sub(content, 2), "^%s*(.-)%s*$") }
			elseif content == "else" then
				tokens[#tokens + 1] = { type = "ELSE" }
			else
				tokens[#tokens + 1] = { type = "EXPR", value = content }
			end
		end

		pos = e1 + e_tag_len
	end
	return tokens
end

----------------------------------------------------------------------
-- Parser (AST Builder)
----------------------------------------------------------------------

--- Parses an array of tokens into an Abstract Syntax Tree (AST).<br>
--- The AST is an array of nodes representing text, expressions, raw expressions, and blocks (which may contain nested body and else_body arrays).
---@param tokens handlebars.Token[] Array of tokens from the tokenizer
---@return handlebars.Node[] root The root AST node array
---@usage <br>
--- ```
--- local tokens = tokenize("{{#if ok}}Yes{{else}}No{{/if}}")
--- local ast = parse(tokens)
--- -- ast[1] = { type = "BLOCK", name = "if", body = {...}, else_body = {...} }
--- ```
local function parse(tokens)
	local root = {}
	-- Stack tracks current block body and the block node itself
	local stack = {
		{
			container = root,
			--block_node = nil
		}
	}
	local stack_n = 1

	for i = 1, #tokens do
		local token = tokens[i]
		local top = stack[stack_n]

		if token.type == "TEXT" then
			local container = top.container
			container[#container + 1] = { type = "TEXT", value = token.value }
		elseif token.type == "EXPR" then
			local container = top.container
			container[#container + 1] = { type = "EXPR", value = token.value }
		elseif token.type == "RAW_EXPR" then
			local container = top.container
			container[#container + 1] = { type = "RAW_EXPR", value = token.value }
		elseif token.type == "OPEN_BLOCK" then
			local container = top.container
			local node = {
				type = "BLOCK",
				name = token.name,
				args = parse_args(token.args),
				body = {},
				--else_body = nil
			}
			container[#container + 1] = node
			stack_n = stack_n + 1
			stack[stack_n] = { container = node.body, block_node = node }
		elseif token.type == "ELSE" then
			top.block_node.else_body = {}
			top.container = top.block_node.else_body
		elseif token.type == "CLOSE_BLOCK" then
			stack[stack_n] = nil
			stack_n = stack_n - 1
		end
	end
	return root
end

----------------------------------------------------------------------
-- Interpreter (Renderer)
----------------------------------------------------------------------

--- Renders an array of AST nodes to a string, resolving expressions<br>
--- and invoking block helpers as needed. HTML-escapes `EXPR` output, but not `RAW_EXPR` output.
---@param nodes handlebars.Node[] Array of AST nodes to render
---@param context_stack handlebars.Context[] The current context stack
---@param helpers table<string, handlebars.HelperFn> Available helper functions
---@return string output The rendered output string
---@usage <br>
--- ```
--- local ast = parse(tokenize("Hello {{name}}!"))
--- local output = render_nodes(ast, { { _ctx_ = { name = "World" } } }, handlebars.helpers)
--- -- output == "Hello World!"
--- ```
local function render_nodes(nodes, context_stack, helpers)
	local out = {}
	local out_n = 0
	local nodes_len = #nodes
	for i = 1, nodes_len do
		local node = nodes[i]
		if node.type == "TEXT" then
			out_n = out_n + 1
			out[out_n] = node.value
		elseif node.type == "EXPR" then
			local value = node.value
			local helper_fn
			local first_word
			local space_pos = string_find(value, " ", 1, true)

			if space_pos then
				first_word = string_sub(value, 1, space_pos - 1)
				helper_fn = helpers[first_word]
			else
				first_word = value
				helper_fn = helpers[first_word]
			end

			if helper_fn and type(helper_fn) == "function" then
				local resolved_args = {}
				local ra_n = 0
				if space_pos then
					for part in string_gmatch(string_sub(value, space_pos + 1), "%S+") do
						ra_n = ra_n + 1
						resolved_args[ra_n] = resolve_arg(part, context_stack)
					end
				end
				out_n = out_n + 1
				out[out_n] = escape_html(tostring(helper_fn(resolved_args) or ""))
			else
				local val = resolve(value, context_stack)
				out_n = out_n + 1
				out[out_n] = escape_html(tostring(val == nil and "" or val))
			end
		elseif node.type == "RAW_EXPR" then
			local val = resolve(node.value, context_stack)
			out_n = out_n + 1
			out[out_n] = tostring(val == nil and "" or val)
		elseif node.type == "BLOCK" then
			local helper = helpers[node.name]
			if helper then
				out_n = out_n + 1
				out[out_n] = helper(node, context_stack, helpers, resolve, render_nodes)
			else
				-- Fallback: render body if helper missing
				out_n = out_n + 1
				out[out_n] = render_nodes(node.body, context_stack, helpers)
			end
		end
	end
	return table_concat(out)
end

----------------------------------------------------------------------
-- Built-in Helpers
----------------------------------------------------------------------

handlebars.helpers = {}

--- Conditional block helper. Renders body if the condition is truthy, otherwise renders the else_body (if present).
--- Truthy values: non-nil, non-false, non-empty-string, non-zero, non-empty-table.
---@param block_node handlebars.Node The parsed block node with body and args
---@param context_stack handlebars.Context[] Current context stack
---@param helpers table<string, handlebars.HelperFn> Available helpers
---@param resolve_fn function Variable resolver
---@param render_fn function Node renderer
---@return string string The rendered output
---@usage <br>
--- ```
--- local render = handlebars.compile("{{#if admin}}Admin{{else}}User{{/if}}")
--- render({ admin = true })  -- "Admin"
--- render({ admin = false }) -- "User"
--- ```
handlebars.helpers["if"] = function(block_node, context_stack, helpers, resolve_fn, render_fn)
	local condition = resolve_fn(block_node.args[1] or "", context_stack)
	-- handlebars (JS) semantics: nil, false, empty string, 0, and empty tables are falsey
	local is_truthy = condition and condition ~= "" and condition ~= 0
	if type(condition) == "table" and next(condition) == nil then is_truthy = false end

	if is_truthy then
		return render_fn(block_node.body, context_stack, helpers)
	end
	if block_node.else_body then
		return render_fn(block_node.else_body, context_stack, helpers)
	end
	return ""
end

--- Inverse conditional block helper. Renders body if the condition is falsy, otherwise renders the else_body (if present). Opposite of `#if`.
---@param block_node handlebars.Node The parsed block node with body and args
---@param context_stack handlebars.Context[] Current context stack
---@param helpers table<string, handlebars.HelperFn> Available helpers
---@param resolve_fn function Variable resolver
---@param render_fn function Node renderer
---@return string string The rendered output
---@usage <br>
--- ```
--- local render = handlebars.compile("{{#unless banned}}Welcome{{else}}Blocked{{/unless}}")
--- render({ banned = false }) -- "Welcome"
--- render({ banned = true })  -- "Blocked"
--- ```
function handlebars.helpers.unless(block_node, context_stack, helpers, resolve_fn, render_fn)
	local condition = resolve_fn(block_node.args[1] or "", context_stack)
	local is_truthy = condition and condition ~= "" and condition ~= 0
	if type(condition) == "table" and next(condition) == nil then is_truthy = false end

	if not is_truthy then
		return render_fn(block_node.body, context_stack, helpers)
	end
	if block_node.else_body then
		return render_fn(block_node.else_body, context_stack, helpers)
	end
	return ""
end

--- Iteration block helper. Renders the body for each element in a collection.<br>
--- Supports both array-like tables (indexed by integer) and map-like tables.<br>
--- Special context variables available inside the loop:<br>
--- `@index` (0-based), `@key`, `@first`, `@last`.
---@param block_node handlebars.Node The parsed block node with body and args
---@param context_stack handlebars.Context[] Current context stack
---@param helpers table<string, handlebars.HelperFn> Available helpers
---@param resolve_fn function Variable resolver
---@param render_fn function Node renderer
---@return string string The rendered output
---@usage <br>
--- ```
--- local render = handlebars.compile("{{#each items}}{{@index}}:{{.}} {{/each}}")
--- render({ items = {"a", "b", "c"} }) -- "0:a 1:b 2:c "
--- ```
function handlebars.helpers.each(block_node, context_stack, helpers, resolve_fn, render_fn)
	local collection = resolve_fn(block_node.args[1] or "", context_stack)
	if not collection or type(collection) ~= "table" then
		if block_node.else_body then return render_fn(block_node.else_body, context_stack, helpers) end
		return ""
	end

	if next(collection) == nil then
		if block_node.else_body then return render_fn(block_node.else_body, context_stack, helpers) end
		return ""
	end

	local out = {}
	local out_n = 0
	local count
	local is_array = collection[1] ~= nil

	if is_array then
		count = #collection
	else
		count = 0
		for _ in next, collection do count = count + 1 end
	end

	if is_array then
		for i = 1, count do
			local v = collection[i]
			local new_ctx = {
				_ctx_ = v,
				["@index"] = i - 1,
				["@key"] = i,
				["@first"] = i == 1,
				["@last"] = i == count
			}

			local new_stack = { table_unpack(context_stack) }
			new_stack[#new_stack + 1] = new_ctx

			out_n = out_n + 1
			out[out_n] = render_fn(block_node.body, new_stack, helpers)
		end
	else
		local i = 0
		for k, v in next, collection do
			i = i + 1
			local new_ctx = {
				_ctx_ = v,
				["@index"] = i - 1,
				["@key"] = k,
				["@first"] = i == 1,
				["@last"] = i == count
			}

			local new_stack = { table_unpack(context_stack) }
			new_stack[#new_stack + 1] = new_ctx

			out_n = out_n + 1
			out[out_n] = render_fn(block_node.body, new_stack, helpers)
		end
	end

	return table_concat(out)
end

--- Context-switching block helper.<br>
--- Renders the body with a new context set to the resolved value.<br>
--- Allows accessing nested properties directly.
---@param block_node handlebars.Node The parsed block node with body and args
---@param context_stack handlebars.Context[] Current context stack
---@param helpers table<string, handlebars.HelperFn> Available helpers
---@param resolve_fn function Variable resolver
---@param render_fn function Node renderer
---@return string string The rendered output
---@usage <br>
--- ```
--- local render = handlebars.compile("{{#with person}}Name: {{name}}{{/with}}")
--- render({ person = { name = "Alice" } }) -- "Name: Alice"
--- ```
function handlebars.helpers.with(block_node, context_stack, helpers, resolve_fn, render_fn)
	local ctx = resolve_fn(block_node.args[1] or "", context_stack)
	if not ctx then
		if block_node.else_body then return render_fn(block_node.else_body, context_stack, helpers) end
		return ""
	end

	local new_stack = { table_unpack(context_stack) }
	new_stack[#new_stack + 1] = { _ctx_ = ctx }
	return render_fn(block_node.body, new_stack, helpers)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Compiles a Handlebars template string into a render function.<br>
--- The returned function accepts a data table and optional custom helpers, and returns the rendered string.
---@param template string The Handlebars template string to compile
---@return function render A function that renders the template with the given data
---@usage <br>
--- ```
--- local render = handlebars.compile("Hello {{name}}!")
--- local output = render({ name = "World" })
--- -- output == "Hello World!"
---
--- -- With custom helpers:
--- local output = render({ name = "World" }, { upper = function(args) return string.upper(args[1]) end })
--- ```
function handlebars.compile(template)
	local tokens = tokenize(template)
	local ast = parse(tokens)
	local default_helpers = handlebars.helpers

	return function(data, custom_helpers)
		local helpers = {}
		for k, v in next, default_helpers do helpers[k] = v end
		if custom_helpers then
			for k, v in next, custom_helpers do helpers[k] = v end
		end

		local context_stack = { { _ctx_ = data } }
		return render_nodes(ast, context_stack, helpers)
	end
end

--- Registers a custom helper function that can be used in templates.<br>
--- Helpers receive `(args, context)` for expressions or
--- `(block_node, context_stack, helpers, resolve_fn, render_fn)` for blocks.
---@param name string The helper name (used as `{{name}}` or `{{#name}}...{{/name}}`)
---@param fn handlebars.HelperFn The helper function
---@usage <br>
--- ```
--- handlebars.registerHelper("shout", function(args)
---   return string.upper(args[1] or "")
--- end)
--- local render = handlebars.compile("{{shout word}}")
--- render({ word = "hello" }) -- "HELLO"
--- ```
function handlebars.registerHelper(name, fn)
	handlebars.helpers[name] = fn
end

--- String extension method for quick one-liner template rendering.<br>
--- Compiles and renders a Handlebars template in a single call.
---@param str string The Handlebars template string
---@param data? table<string, any> The context data for template rendering
---@return string output The rendered string
---@usage <br>
--- ```
--- local output = "Hello {{name}}!":handlebars({ name = "World" })
--- -- output == "Hello World!"
--- ```
function string.handlebars(str, data)
	return handlebars.compile(str)(data)
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
handlebars.register_helper = handlebars.registerHelper

-- Export
return handlebars
