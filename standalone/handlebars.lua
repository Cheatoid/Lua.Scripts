-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua implementation of the Handlebars (minimal) template engine on steroids

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

local function escape_html(s)
	if type(s) ~= "string" then return s end
	return string_gsub(s, "[&<>\"']", html_escapes)
end

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

-- Resolves a variable path against a context stack
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

-- Resolves arguments passed to helpers, evaluating strings/numbers/paths
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
		if not e1 then error("Unclosed handlebars tag at position " .. s1) end

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

-- Use bracket notation because "if" is a Lua reserved keyword
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

function handlebars.registerHelper(name, fn)
	handlebars.helpers[name] = fn
end

function string.handlebars(str, data)
	return handlebars.compile(str)(data)
end

-- Export
return handlebars
