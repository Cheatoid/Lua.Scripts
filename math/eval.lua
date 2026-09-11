-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lightweight arithmetic expression parser and evaluator

-- Features:
-- * Tokenizes numeric literals, identifiers, operators, parentheses and commas
-- * Supports Shunting-Yard (RPN) and Pratt parsing (AST)
-- * Built-in operators and functions with registration helpers

---@class MathToken
---@field [1] number Token type (T_NUMBER, T_IDENT, T_OP, T_FUNC, T_COMMA, T_MARKER)
---@field [2] number|string Token value

---@class MathOpConfig
---@field [1] number Precedence
---@field [2] number Associativity (0=Left, 1=Right)
---@field [3] number Arity (1=Unary, 2=Binary)
---@field [4] function Implementation

---@class MathFuncConfig
---@field [1] number Arity (-1 for variable)
---@field [2] function Implementation

----------------------------------------------------------------------
-- Localized global functions for better performance
----------------------------------------------------------------------

local error, tonumber, type, tostring          = error, tonumber, type, tostring
local math_floor                               = math.floor
local string_byte, string_sub                  = string.byte, string.sub
local table_insert, table_remove, table_unpack = table.insert, table.remove,
		table.unpack or
		unpack -- Lua 5.1 / 5.2+ compatibility

----------------------------------------------------------------------
-- Localized ASCII byte codes for fast structural comparisons
----------------------------------------------------------------------

local B_LPAR                                   = 40 -- (
local B_RPAR                                   = 41 -- )
local B_COMMA                                  = 44 -- ,
local B_PLUS                                   = 43 -- +
local B_MINUS                                  = 45 -- -
local B_DOT                                    = 46 -- .
local B_SLASH                                  = 47 -- /
local B_STAR                                   = 42 -- *
local B_CARET                                  = 94 -- ^
local B_PERCENT                                = 37 -- %

----------------------------------------------------------------------
-- TOKEN TYPES (Numeric identifiers for performance)
-- 1: Number, 2: Identifier, 3: Operator, 4: Function, 5: Comma, 6: Marker
----------------------------------------------------------------------

local T_NUMBER                                 = 1
local T_IDENT                                  = 2
local T_OP                                     = 3
local T_FUNC                                   = 4
local T_COMMA                                  = 5
local T_MARKER                                 = 6

----------------------------------------------------------------------
-- CONFIGURATION: Numeric indexes & Direct References
-- Operators: { 1: precedence, 2: associativity (0=L, 1=R), 3: arity, 4: func }
-- Functions: { 1: arity (-1 for variable args), 2: func }
----------------------------------------------------------------------

--- Operator configuration table.
---
--- Keys are operator symbols (string). Value format:<br>
--- `{ precedence:number, associativity:0|1, arity:1|2, func:function }`
---
--- Precedence hierarchy (high -> low):
---   5 : ^          (right-assoc)
---   4 : unary + / unary -   (right-assoc)
---   3 : * / // %
---   2 : + -
local OPS                                      = {
	["+"]  = { 2, 0, 2, function(a, b) return a + b end },
	["-"]  = { 2, 0, 2, function(a, b) return a - b end },
	["*"]  = { 3, 0, 2, function(a, b) return a * b end },
	["/"]  = { 3, 0, 2, function(a, b) return a / b end },
	["%"]  = { 3, 0, 2, function(a, b) return a % b end },
	["//"] = { 3, 0, 2, function(a, b) return math_floor(a / b) end },
	["^"]  = { 5, 1, 2, function(a, b) return a ^ b end },
	["u-"] = { 4, 1, 1, function(a) return -a end },
	["u+"] = { 4, 1, 1, function(a) return a end },
}

--- Function configuration table.
---
--- Each entry: `{ arity:number (-1 for variable args), func:function }`
local FUNCS                                    = {
	["abs"]   = { 1, math.abs },
	["acos"]  = { 1, math.acos },
	["asin"]  = { 1, math.asin },
	["atan"]  = { 1, math.atan },
	["ceil"]  = { 1, math.ceil },
	["cos"]   = { 1, math.cos },
	["deg"]   = { 1, math.deg },
	["exp"]   = { 1, math.exp },
	["floor"] = { 1, math_floor },
	["log"]   = { -1, math.log }, -- supports log(x) and log(x, base)
	["max"]   = { -1, math.max },
	["min"]   = { -1, math.min },
	["rad"]   = { 1, math.rad },
	["sin"]   = { 1, math.sin },
	["sqrt"]  = { 1, math.sqrt },
	["tan"]   = { 1, math.tan },
}

--- Constant table: name -> numeric value
local CONSTS                                   = {
	["huge"] = math.huge,
	["pi"]   = math.pi,
	["inf"]  = 1 / 0,
	["tau"]  = 2 * math.pi,
}

----------------------------------------------------------------------
-- STEP 1: TOKENIZER
-- Character-by-character scanner; Lua patterns doesn't support | alternation
----------------------------------------------------------------------

local function is_alpha(c)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
end

local function is_alnum(c)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
end

local function is_digit(c)
	return c >= 48 and c <= 57
end

--- Tokenize an expression string into a flat token list.<br>
--- Each token is a `MathToken` where [1] is token type and [2] is value.
---@param expr string Expression string
---@return MathToken[] tokens Flat token list
local function tokenize(expr)
	local tokens = {}
	local i = 1
	local len = #expr

	while i <= len do
		local c = string_byte(expr, i)

		-- Skip whitespace (space, tab, LF, CR)
		if c == 32 or c == 9 or c == 10 or c == 13 then
			i = i + 1

			-- Number starting with a digit
		elseif is_digit(c) then
			local start = i
			-- Integer part
			while c and is_digit(c) do
				i = i + 1
				c = string_byte(expr, i)
			end
			-- Decimal point and fractional part
			if c == B_DOT then
				i = i + 1
				c = string_byte(expr, i)
				while c and is_digit(c) do
					i = i + 1
					c = string_byte(expr, i)
				end
			end
			-- Exponent part
			if c == 101 or c == 69 then -- e or E
				i = i + 1
				c = string_byte(expr, i)
				if c == 43 or c == 45 then -- + or -
					i = i + 1
					c = string_byte(expr, i)
				end
				while c and is_digit(c) do
					i = i + 1
					c = string_byte(expr, i)
				end
			end
			local num = tonumber(string_sub(expr, start, i - 1))
			if not num then
				return error("Invalid number: " .. string_sub(expr, start, i - 1))
			end
			tokens[#tokens + 1] = { T_NUMBER, num }

			-- Leading-dot number: .5  .5e2  etc.
		elseif c == B_DOT then
			local next_c = string_byte(expr, i + 1)
			if next_c and is_digit(next_c) then
				local start = i
				i = i + 1
				c = next_c
				while c and is_digit(c) do
					i = i + 1
					c = string_byte(expr, i)
				end
				-- Exponent part
				if c == 101 or c == 69 then
					i = i + 1
					c = string_byte(expr, i)
					if c == 43 or c == 45 then
						i = i + 1
						c = string_byte(expr, i)
					end
					while c and is_digit(c) do
						i = i + 1
						c = string_byte(expr, i)
					end
				end
				local num = tonumber(string_sub(expr, start, i - 1))
				if not num then
					return error("Invalid number: " .. string_sub(expr, start, i - 1))
				end
				tokens[#tokens + 1] = { T_NUMBER, num }
			else
				return error("Unexpected character: .")
			end

			-- Identifier (letter or underscore followed by alphanumerics/underscores)
		elseif is_alpha(c) then
			local start = i
			while c and is_alnum(c) do
				i = i + 1
				c = string_byte(expr, i)
			end
			tokens[#tokens + 1] = { T_IDENT, string_sub(expr, start, i - 1) }

			-- Parentheses
		elseif c == B_LPAR then
			tokens[#tokens + 1] = { T_OP, B_LPAR }
			i = i + 1
		elseif c == B_RPAR then
			tokens[#tokens + 1] = { T_OP, B_RPAR }
			i = i + 1

			-- Comma
		elseif c == B_COMMA then
			tokens[#tokens + 1] = { T_COMMA, B_COMMA }
			i = i + 1

			-- Plus (binary or unary)
		elseif c == B_PLUS then
			local prev_type = #tokens > 0 and tokens[#tokens][1] or false
			if not prev_type or prev_type == T_OP or prev_type == T_COMMA then
				tokens[#tokens + 1] = { T_OP, "u+" }
			else
				tokens[#tokens + 1] = { T_OP, "+" }
			end
			i = i + 1

			-- Minus (binary or unary)
		elseif c == B_MINUS then
			local prev_type = #tokens > 0 and tokens[#tokens][1] or false
			if not prev_type or prev_type == T_OP or prev_type == T_COMMA then
				tokens[#tokens + 1] = { T_OP, "u-" }
			else
				tokens[#tokens + 1] = { T_OP, "-" }
			end
			i = i + 1

			-- Slash or double-slash (floor division)
		elseif c == B_SLASH then
			local next_c = string_byte(expr, i + 1)
			if next_c == B_SLASH then
				tokens[#tokens + 1] = { T_OP, "//" }
				i = i + 2
			else
				tokens[#tokens + 1] = { T_OP, "/" }
				i = i + 1
			end

			-- Star
		elseif c == B_STAR then
			tokens[#tokens + 1] = { T_OP, "*" }
			i = i + 1

			-- Caret
		elseif c == B_CARET then
			tokens[#tokens + 1] = { T_OP, "^" }
			i = i + 1

			-- Percent
		elseif c == B_PERCENT then
			tokens[#tokens + 1] = { T_OP, "%" }
			i = i + 1
		else
			return error("Unexpected character: " .. string.char(c))
		end
	end

	return tokens
end

----------------------------------------------------------------------
-- STEP 2: PARSER (strategy selection)
-- Supports both Shunting-Yard and Pratt parsing strategies.
----------------------------------------------------------------------

local parse_shunting_yard, parse_pratt

--- Parse tokens according to the requested strategy.<br>
--- Supported strategies: `"shunting_yard"` (RPN) and `"pratt"` (AST).
---@param tokens MathToken[] Token list from tokenizer
---@param strategy? "shunting_yard"|"pratt" Optional parsing strategy (default: "shunting_yard")
---@return MathToken[]|table parsed RPN or AST tokens
local function parse(tokens, strategy)
	strategy = strategy or "shunting_yard"
	if strategy == "shunting_yard" then
		return parse_shunting_yard(tokens)
	end
	if strategy == "pratt" then
		return parse_pratt(tokens)
	end
	return error("Unknown parsing strategy: " .. strategy, 2)
end

----------------------------------------------------------------------
-- Shunting-Yard algorithm
----------------------------------------------------------------------

--- Parse tokens into Reverse Polish Notation using the Shunting-Yard algorithm.<br>
--- Returns an array of tokens in RPN suitable for `evaluate_rpn`.
---@param tokens MathToken[] Token list from tokenizer
---@return MathToken[] rpn Reverse Polish Notation tokens
function parse_shunting_yard(tokens)
	local output = {}
	local op_stack = {}

	for i = 1, #tokens do
		local token = tokens[i]
		local t_type, t_val = token[1], token[2]
		if t_type == T_NUMBER then  -- number
			output[#output + 1] = token
		elseif t_type == T_IDENT then -- identifier
			if FUNCS[t_val] then
				op_stack[#op_stack + 1] = { T_FUNC, t_val }
			elseif CONSTS[t_val] then
				output[#output + 1] = { T_NUMBER, CONSTS[t_val] }
			else
				return error("Unknown identifier: " .. t_val)
			end
		elseif t_type == T_OP then -- operator (can be byte code or string like "u-")
			if t_val == B_LPAR then
				-- If a function is on top of the stack, emit a marker BEFORE arguments
				if #op_stack > 0 and op_stack[#op_stack][1] == T_FUNC then
					output[#output + 1] = { T_MARKER, B_LPAR }
				end
				op_stack[#op_stack + 1] = token
			elseif t_val == B_RPAR then
				-- Pop until matching '('
				while #op_stack > 0 and not (op_stack[#op_stack][1] == T_OP and op_stack[#op_stack][2] == B_LPAR) do
					output[#output + 1] = table_remove(op_stack)
				end
				if #op_stack == 0 then return error("Mismatched parentheses") end
				table_remove(op_stack) -- discard '('
				-- If a function is on top of the stack, pop it to output
				if #op_stack > 0 and op_stack[#op_stack][1] == T_FUNC then
					local func_token = table_remove(op_stack)
					output[#output + 1] = func_token
				end
			else
				local o1 = OPS[t_val]
				if not o1 then return error("Unknown operator: " .. tostring(t_val)) end
				local p1, a1 = o1[1], o1[2]
				-- If the operator is a prefix operator, we just push it.
				-- We don't pop binary operators because a prefix operator
				-- doesn't take a left operand, so it doesn't compete with
				-- operators waiting for their right operand.
				if o1[3] == 1 then
					op_stack[#op_stack + 1] = token
				else
					-- Pop higher-precedence operators (skip parentheses)
					while #op_stack > 0 do
						local top = op_stack[#op_stack]
						if top[1] == T_OP and top[2] ~= B_LPAR and top[2] ~= B_RPAR then
							local o2 = OPS[top[2]]
							if o2 then
								local p2 = o2[1]
								local cond = (a1 == 0 and p1 <= p2) or (a1 == 1 and p1 < p2)
								if cond then
									output[#output + 1] = table_remove(op_stack)
								else
									break
								end
							else
								break
							end
						else
							break
						end
					end
					op_stack[#op_stack + 1] = token
				end
			end
		elseif t_type == T_COMMA then -- comma
			while #op_stack > 0 and op_stack[#op_stack][2] ~= B_LPAR do
				output[#output + 1] = table_remove(op_stack)
			end
		end
	end

	while #op_stack > 0 do
		local op = table_remove(op_stack)
		if op[2] == B_LPAR or op[2] == B_RPAR then return error("Mismatched parentheses") end
		output[#output + 1] = op
	end

	return output
end

----------------------------------------------------------------------
-- Pratt parser implementation
----------------------------------------------------------------------

--- Parse tokens into an AST using a Pratt (top-down) parser.<br>
--- Returns an AST array where the top-level is a single expression node.
---@param tokens MathToken[] Token list from tokenizer
---@return table ast Abstract Syntax Tree
function parse_pratt(tokens)
	if #tokens == 0 then return error("Empty expression") end
	local index = 1

	--- Peek at the current token without consuming it
	---@return MathToken|nil
	local function peek()
		return tokens[index]
	end

	--- Consume and return the current token
	---@return MathToken
	local function consume()
		local tok = tokens[index]
		index = index + 1
		return tok
	end

	local parse_expression

	local function parse_args(func_name)
		local args = {}
		local next_tok = peek()
		if next_tok and not (next_tok[1] == T_OP and next_tok[2] == B_RPAR) then
			args[#args + 1] = parse_expression(0)
			while peek() and peek()[1] == T_COMMA do
				consume()
				args[#args + 1] = parse_expression(0)
			end
		end
		local closing = consume()
		if not closing or not (closing[1] == T_OP and closing[2] == B_RPAR) then
			return error("Expected ')' after arguments to '" .. func_name .. "'")
		end
		return args
	end

	parse_expression = function(min_prec)
		local token = consume()
		if not token then return error("Unexpected end of expression") end
		local t_type, t_val = token[1], token[2]
		local left

		if t_type == T_NUMBER then
			left = { t_type, t_val }
		elseif t_type == T_IDENT then
			if FUNCS[t_val] then
				local lparen = consume()
				if not lparen or not (lparen[1] == T_OP and lparen[2] == B_LPAR) then
					return error("Expected '(' after function name '" .. t_val .. "'")
				end
				local args = parse_args(t_val)
				local expected_arity = FUNCS[t_val][1]
				if expected_arity ~= -1 and #args ~= expected_arity then
					return error("Function '" .. t_val .. "' expects " .. expected_arity .. " arg(s), got " .. #args)
				end
				left = { T_FUNC, t_val, args }
			elseif CONSTS[t_val] then
				left = { T_NUMBER, CONSTS[t_val] }
			else
				return error("Unknown identifier: '" .. t_val .. "'")
			end
		elseif t_type == T_OP then
			if t_val == B_LPAR then
				left = parse_expression(0)
				local closing = consume()
				if not closing or not (closing[1] == T_OP and closing[2] == B_RPAR) then
					return error("Expected ')' to close grouped expression")
				end
			else
				local op_data = OPS[t_val]
				if not op_data then return error("Unknown operator: '" .. tostring(t_val) .. "'") end
				if op_data[3] ~= 1 then
					return error("Binary operator '" .. tostring(t_val) .. "' cannot appear in prefix position")
				end
				left = { t_type, t_val, parse_expression(op_data[1]) }
			end
		else
			return error("Unexpected token (type=" .. t_type .. ") in prefix position")
		end

		while true do
			local next_tok = peek()
			if not next_tok then break end
			local nxt_type, nxt_val = next_tok[1], next_tok[2]
			if nxt_type ~= T_OP then break end
			local op_data = OPS[nxt_val]
			if not op_data or op_data[3] ~= 2 then break end
			local op_prec = op_data[1]
			local op_assoc = op_data[2]
			if op_prec < min_prec then break end
			consume()
			local next_min = (op_assoc == 1) and op_prec or (op_prec + 1)
			local right = parse_expression(next_min)
			left = { nxt_type, nxt_val, left, right }
		end

		return left
	end

	local node = parse_expression(0)
	if peek() then
		return error("Unexpected token after expression")
	end
	return { node }
end

----------------------------------------------------------------------
-- STEP 3: EVALUATOR (AST or RPN reduction)
----------------------------------------------------------------------

local evaluate_rpn, evaluate_ast

--- Evaluate a parsed expression (RPN or AST) using the chosen strategy.<br>
--- "shunting_yard" expects an RPN array, "pratt" expects an AST.
---@param parsed MathToken[]|table Parsed output from parser
---@param strategy? "shunting_yard"|"pratt" Optional parsing strategy (default: "shunting_yard")
---@return number result Evaluated numeric result
local function evaluate(parsed, strategy)
	strategy = strategy or "shunting_yard"
	if strategy == "shunting_yard" then
		return evaluate_rpn(parsed)
	end
	if strategy == "pratt" then
		return evaluate_ast(parsed)
	end
	return error("Unknown evaluation strategy: " .. strategy, 2)
end

----------------------------------------------------------------------
-- Evaluate RPN (Shunting-Yard output)
----------------------------------------------------------------------

function evaluate_rpn(rpn)
	local stack = {}

	for i = 1, #rpn do
		local token = rpn[i]
		local t_type, t_val = token[1], token[2]

		if t_type == T_NUMBER then
			stack[#stack + 1] = t_val
		elseif t_type == T_MARKER then
			stack[#stack + 1] = B_LPAR
		elseif t_type == T_OP then
			local op_data = OPS[t_val]
			local arity = op_data[3]
			local func = op_data[4]
			if arity == 1 then
				local a = table_remove(stack)
				stack[#stack + 1] = func(a)
			else
				local b = table_remove(stack)
				local a = table_remove(stack)
				stack[#stack + 1] = func(a, b)
			end
		elseif t_type == T_FUNC then
			local func_data = FUNCS[t_val]
			local expected_arity = func_data[1]
			local func = func_data[2]
			local args = {}
			while #stack > 0 and stack[#stack] ~= B_LPAR do
				table_insert(args, 1, table_remove(stack))
			end
			if #stack > 0 and stack[#stack] == B_LPAR then
				table_remove(stack) -- remove marker
			else
				return error("Mismatched parentheses in function call: " .. t_val)
			end
			if expected_arity ~= -1 and #args ~= expected_arity then
				return error("Function " .. t_val .. " expects " .. expected_arity .. " args, got " .. #args)
			end
			stack[#stack + 1] = func(table_unpack(args))
		end
	end

	if #stack ~= 1 then return error("Invalid expression evaluation") end
	return stack[1]
end

----------------------------------------------------------------------
-- Evaluate AST (Pratt parser output)
----------------------------------------------------------------------

local function eval_node(node)
	local t_type, t_val = node[1], node[2]
	if t_type == T_NUMBER then
		return t_val
	end
	if t_type == T_IDENT then
		return CONSTS[t_val] or error("Unknown identifier in AST: " .. t_val)
	end
	if t_type == T_OP then
		local op_data = OPS[t_val]
		local arity = op_data[3]
		local func = op_data[4]
		if arity == 1 then
			local right = eval_node(node[3])
			return func(right)
		end
		local left = eval_node(node[3])
		local right = eval_node(node[4])
		return func(left, right)
	end
	if t_type == T_FUNC then
		local func_data = FUNCS[t_val]
		local func = func_data[2]
		local args = node[3]
		local evaluated_args = {}
		for i = 1, #args do
			evaluated_args[i] = eval_node(args[i])
		end
		return func(table_unpack(evaluated_args))
	end
	return error("Unknown node type: " .. t_type)
end

function evaluate_ast(ast)
	if #ast ~= 1 then return error("Invalid AST structure") end
	return eval_node(ast[1])
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

local self = {}

--- Evaluate an expression string.
---@param expr string Expression to evaluate
---@param strategy? "shunting_yard"|"pratt" Optional parsing strategy (default: "shunting_yard")
---@return number result Evaluated numeric result
local function eval(expr, strategy)
	if type(expr) ~= "string" then return error("Expected string expression to evaluate", 2) end
	return evaluate(parse(tokenize(expr), strategy), strategy)
end

self.eval = eval

--- Register a named function for use in expressions.
---@param name string Function name
---@param arity number Number of arguments (-1 for variable args)
---@param func function Implementation function
local function add_func(name, arity, func)
	FUNCS[name] = { arity, func }
end

self.func = add_func

--- Register an operator.
---@param sym string Operator symbol (e.g. "+", "u-")
---@param prec number Precedence
---@param assoc number|string Associativity (0 = left, 1 = right, "l", "r")
---@param arity number 1 for unary, 2 for binary
---@param func function Implementation function
local function set_op(sym, prec, assoc, arity, func)
	if assoc == "l" then
		assoc = 0
	elseif assoc == "r" then
		assoc = 1
	elseif type(assoc) == "string" then
		return error("Invalid associativity string: " .. assoc, 2)
	end
	OPS[sym] = { prec, assoc, arity, func }
end

self.op = set_op

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return eval(...)
	end
})
