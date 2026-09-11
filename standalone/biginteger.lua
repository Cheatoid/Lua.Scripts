-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Arbitrary-precision integer and expression evaluator (Shunting-yard logic)

-- TODO: Implement binary (0b) and hexadecimal (0x) support for eval and string constructor (BigInt_from_any)
-- TODO: Implement radix support for BigInteger_to_number (supported base: 2 for binary, 10 for decimal, 16 for hexadecimal; default 10)
-- TODO: Fix zero sign (field at index 1) and BigInteger_zero (it should use 0, not 1), also account for negative 0 (tonumber("-0.0"))

----------------------------------------------------------------------
-- Localized global functions for better performance
----------------------------------------------------------------------

local error = error
local tostring = tostring
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local math_floor = math.floor
local string_sub = string.sub
local string_byte = string.byte
local table_concat = table.concat

----------------------------------------------------------------------
-- BigInteger object layout (numeric index for faster indexing)
-- { [1] = sign (-1 or 1), [2] = digits array (base 10, MSB first) }
----------------------------------------------------------------------

-- !!! TODO !!!
-- Make sure to use Base 1000000: Instead of storing decimal digits (Base 10) which is slow,
-- or binary (Base 2^32) which requires complex string conversion, we use Base 10^6.
-- This fits within a standard Lua number (which uses double-precision floats, guaranteeing 52 bits
-- of integer precision) while allowing 6 decimal digits per storage unit. This makes arithmetic
-- roughly 2x faster than naive number arrays.
-- Configuration: Base 10^6 allows 6 digits per "limb".
-- Lua numbers (doubles) can safely hold integers up to 2^14.
-- 10^6 fits comfortably, and 10^6 * 10^6 = 10^12 < 2^14.
local BASE, BASE_DIGITS = 1000000, 6

local BigInteger_mt = {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Normalize: Remove leading zeros, fix negative zero
local normalize = function(sign, limbs)
	while #limbs > 1 and limbs[#limbs] == 0 do
		limbs[#limbs] = nil
	end
	if #limbs == 1 and limbs[1] == 0 then
		return 1, limbs -- Normalize -0 to +0
	end
	return sign, limbs
end

-- Compare Absolute Values: Returns 1 if a>b, -1 if a<b, 0 if a==b
local compareAbsolute = function(limbs_a, limbs_b)
	local len_a, len_b = #limbs_a, #limbs_b
	if len_a ~= len_b then
		return len_a > len_b and 1 or -1
	end
	for i = len_a, 1, -1 do
		if limbs_a[i] ~= limbs_b[i] then
			return limbs_a[i] > limbs_b[i] and 1 or -1
		end
	end
	return 0
end

-- Add Absolute Values: Returns limbs
local addAbsolute = function(limbs_a, limbs_b)
	local res = {}
	local carry = 0
	local max_len = #limbs_a > #limbs_b and #limbs_a or #limbs_b
	for i = 1, max_len do
		local v1 = limbs_a[i] or 0
		local v2 = limbs_b[i] or 0
		local sum = v1 + v2 + carry
		res[i] = sum % BASE
		carry = math_floor(sum / BASE)
	end
	if carry > 0 then
		res[#res + 1] = carry
	end
	return res
end

-- Subtract Absolute Values (a - b): Returns limbs. Assumes |a| >= |b|
local subAbsolute = function(limbs_a, limbs_b)
	local res = {}
	local borrow = 0
	for i = 1, #limbs_a do
		local v1 = limbs_a[i]
		local v2 = limbs_b[i] or 0
		local diff = v1 - v2 - borrow
		if diff < 0 then
			diff = diff + BASE
			borrow = 1
		else
			borrow = 0
		end
		res[i] = diff
	end
	return res
end

local strip_leading_zeros = function(digits)
	local n = #digits
	local i = 1
	while i < n and digits[i] == 0 do
		i = i + 1
	end
	if i == 1 then
		if n == 0 then
			digits[1] = 0
		end
		return digits
	end
	local r = {}
	local j = 1
	while i <= n do
		r[j] = digits[i]
		j = j + 1
		i = i + 1
	end
	if #r == 0 then
		r[1] = 0
	end
	return r
end

----------------------------------------------------------------------
-- Construction and cloning
----------------------------------------------------------------------

local BigInt_new_raw = function(sign, digits)
	digits = strip_leading_zeros(digits)
	-- zero normalization
	if #digits == 1 and digits[1] == 0 then
		sign = 1
	end
	return setmetatable({ sign, digits }, BigInteger_mt)
end

local BigInt_from_any = function(v)
	local t = type(v)
	if t == "table" and getmetatable(v) == BigInteger_mt then -- Copy constructor
		local d = v[2]
		local nd = {}
		for i = 1, #d do
			nd[i] = d[i]
		end
		return setmetatable({ v[1], nd }, BigInteger_mt)
	end

	if t == "number" then
		v = tostring(v)
	end

	local s = tostring(v)
	local len = #s
	if len == 0 then
		return error("invalid integer string: empty", 2)
	end

	local sign = 1
	local first = string_byte(s, 1, 1)
	local start_idx = 1

	if first == 45 then -- -
		sign = -1
		start_idx = 2
	elseif first == 43 then -- +
		start_idx = 2
	end

	if start_idx > len then
		return error("invalid integer string: " .. s, 2)
	end

	local digits = {}
	local di = 1
	for i = start_idx, len do
		local b = string_byte(s, i, i)
		if b < 48 or b > 57 then
			return error("invalid integer string: " .. s, 2)
		end
		digits[di] = b - 48
		di = di + 1
	end

	return BigInt_new_raw(sign, digits)
end

local BigInt_clone = function(a)
	local d = a[2]
	local nd = {}
	for i = 1, #d do
		nd[i] = d[i]
	end
	return setmetatable({ a[1], nd }, BigInteger_mt)
end

local BigInt_ensure = function(v)
	if type(v) == "table" and getmetatable(v) == BigInteger_mt then
		return v
	end
	return BigInt_from_any(v)
end

----------------------------------------------------------------------
-- Comparison helpers
----------------------------------------------------------------------

local BigInt_abs = function(a)
	if a[1] < 0 then
		return BigInt_new_raw(1, a[2])
	end
	return BigInt_clone(a)
end

-- Compare absolute values. Returns 1 if |a|>|b|, -1 if |a|<|b|, 0 if equal.
local BigInt_cmp_abs = function(a, b)
	local da, db = a[2], b[2]
	local na, nb = #da, #db
	if na < nb then
		return -1
	end
	if na > nb then
		return 1
	end
	for i = 1, na do
		local xa, xb = da[i], db[i]
		if xa < xb then
			return -1
		end
		if xa > xb then
			return 1
		end
	end
	return 0
end

local BigInt_cmp = function(a, b)
	local sa, sb = a[1], b[1]
	if sa ~= sb then
		if sa < sb then
			return -1
		end
		return 1
	end
	local c = BigInt_cmp_abs(a, b)
	if sa > 0 then
		return c
	end
	return -c
end

----------------------------------------------------------------------
-- Arithmetic: absolute add/sub/mul/divmod
----------------------------------------------------------------------

local BigInt_add_abs = function(a, b)
	local da, db = a[2], b[2]
	local na, nb = #da, #db
	local i = 0
	local carry = 0
	local r = {}

	while na - i > 0 or nb - i > 0 or carry ~= 0 do
		local xa = (na - i > 0) and da[na - i] or 0
		local xb = (nb - i > 0) and db[nb - i] or 0
		local s = xa + xb + carry
		carry = math_floor(s * 0.1)
		r[#r + 1] = s % 10
		i = i + 1
	end

	local n = #r
	local j = 1
	while j <= math_floor(n * 0.5) do
		r[j], r[n - j + 1] = r[n - j + 1], r[j]
		j = j + 1
	end

	return BigInt_new_raw(1, r)
end

local BigInt_sub_abs = function(a, b)
	-- assumes |a| >= |b|
	local da, db = a[2], b[2]
	local na, nb = #da, #db
	local r = {}
	local borrow = 0
	local i = 0

	while na - i > 0 do
		local xa = da[na - i] - borrow
		local xb = (nb - i > 0) and db[nb - i] or 0
		if xa < xb then
			xa = xa + 10
			borrow = 1
		else
			borrow = 0
		end
		r[#r + 1] = xa - xb
		i = i + 1
	end

	local n = #r
	local j = 1
	while j <= math_floor(n * 0.5) do
		r[j], r[n - j + 1] = r[n - j + 1], r[j]
		j = j + 1
	end

	return BigInt_new_raw(1, r)
end

local BigInt_mul_abs = function(a, b)
	local da, db = a[2], b[2]
	local na, nb = #da, #db
	local r = {}
	local i

	for i = 1, na + nb do
		r[i] = 0
	end

	for ia = na, 1, -1 do
		local carry = 0
		local xa = da[ia]
		for ib = nb, 1, -1 do
			local idx = ia + ib
			local prod = xa * db[ib] + r[idx] + carry
			carry = math_floor(prod * 0.1)
			r[idx] = prod % 10
		end
		r[ia] = r[ia] + carry
	end

	return BigInt_new_raw(1, r)
end

local BigInt_divmod_abs = function(a, b)
	-- long division: returns q, r with |a| = |b|*q + r
	local db = b[2]
	if #db == 1 and db[1] == 0 then
		return error("division by zero", 2)
	end

	local cmp = BigInt_cmp_abs(a, b)
	if cmp < 0 then
		return BigInt_new_raw(1, { 0 }), BigInt_clone(a)
	end
	if cmp == 0 then
		return BigInt_new_raw(1, { 1 }), BigInt_new_raw(1, { 0 })
	end

	-- TODO: Use Newton-Raphson or Multi-precision division.
	-- Long Division (Knuth Algorithm D simplified for small base)
	local da = a[2]
	local na = #da
	local q_digits = {}
	local r = BigInt_new_raw(1, { 0 }) -- accumulator

	-- TODO: Process limbs from most significant to least?
	for i = 1, na do
		-- Shift accumulator left by one limb and add current limb
		local rd = r[2]
		if not (#rd == 1 and rd[1] == 0) then
			rd[#rd + 1] = da[i]
		else
			rd[1] = da[i]
		end
		r[2] = strip_leading_zeros(rd)

		local x = 0
		local low, high = 0, 9
		while low <= high do
			local mid = math_floor((low + high) * 0.5)
			local mid_big = BigInt_new_raw(1, { mid })
			local t = BigInt_mul_abs(b, mid_big)
			local c = BigInt_cmp_abs(t, r)
			if c <= 0 then
				x = mid
				low = mid + 1
			else
				high = mid - 1
			end
		end

		q_digits[#q_digits + 1] = x
		if x ~= 0 then
			local x_big = BigInt_new_raw(1, { x })
			local t = BigInt_mul_abs(b, x_big)
			r = BigInt_sub_abs(r, t)
		end
	end

	local q = BigInt_new_raw(1, q_digits)
	return q, r
end

----------------------------------------------------------------------
-- Public arithmetic (with signs)
----------------------------------------------------------------------

local BigInt_add = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	local sa, sb = a[1], b[1]

	if sa == sb then
		local r = BigInt_add_abs(a, b)
		r[1] = sa
		return r
	end

	local cmp = BigInt_cmp_abs(a, b)
	if cmp == 0 then
		return BigInt_new_raw(1, { 0 })
	end
	if cmp > 0 then
		local r = BigInt_sub_abs(a, b)
		r[1] = sa
		return r
	end
	local r = BigInt_sub_abs(b, a)
	r[1] = sb
	return r
end

local BigInt_sub = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	return BigInt_add(a, BigInt_new_raw(-b[1], b[2]))
end

local BigInt_mul = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	local r = BigInt_mul_abs(a, b)
	r[1] = a[1] * b[1]
	return r
end

local BigInt_div = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	local qa, qb = BigInt_abs(a), BigInt_abs(b)
	local q, _ = BigInt_divmod_abs(qa, qb)
	q[1] = a[1] * b[1]
	return q
end

local BigInt_mod = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	local qa, qb = BigInt_abs(a), BigInt_abs(b)
	local _, r = BigInt_divmod_abs(qa, qb)
	r[1] = a[1]
	return r
end

local BigInt_pow = function(a, e)
	a, e = BigInt_ensure(a), BigInt_ensure(e)

	if e[1] < 0 then
		return error("negative exponent not supported for integer pow", 2)
	end

	local zero = BigInt_new_raw(1, { 0 })
	local one = BigInt_new_raw(1, { 1 })
	local two = BigInt_new_raw(1, { 2 })

	local base = BigInt_clone(a)
	local exp = BigInt_clone(e)
	local result = BigInt_clone(one)

	-- Exponentiation by squaring
	while BigInt_cmp(exp, zero) > 0 do
		local _, r = BigInt_divmod_abs(exp, two)
		if BigInt_cmp(r, one) == 0 then
			result = BigInt_mul(result, base)
		end
		exp = BigInt_div(exp, two)
		base = BigInt_mul(base, base)
	end

	return result
end

----------------------------------------------------------------------
-- Conversions
----------------------------------------------------------------------

local BigInt_tostring = function(a)
	local sign = a[1]
	local d = a[2]
	local n = #d
	local buf = {}
	local i = 1

	if sign < 0 and not (n == 1 and d[1] == 0) then
		buf[i] = "-"
		i = i + 1
	end

	for j = 1, n do
		buf[i] = tostring(d[j])
		i = i + 1
	end

	return table_concat(buf)
end

local BigInt_tonumber = function(a)
	-- may overflow for very large values, but convenient
	local d = a[2]
	local n = #d
	local v = 0
	for i = 1, n do
		v = (v * 10) + d[i]
	end
	return a[1] * v
end

----------------------------------------------------------------------
-- Metamethods (comparisons, operator overload for arithmetic, tostring)
----------------------------------------------------------------------

BigInteger_mt.__eq = function(a, b)
	a, b = BigInt_ensure(a), BigInt_ensure(b)
	if a[1] ~= b[1] then
		return false
	end
	local da, db = a[2], b[2]
	local na, nb = #da, #db
	if na ~= nb then
		return false
	end
	for i = 1, na do
		if da[i] ~= db[i] then
			return false
		end
	end
	return true
end

BigInteger_mt.__lt = function(a, b)
	return BigInt_cmp(BigInt_ensure(a), BigInt_ensure(b)) < 0
end

BigInteger_mt.__le = function(a, b)
	return a == b or a < b
end

BigInteger_mt.__add = BigInt_add
BigInteger_mt.__sub = BigInt_sub
BigInteger_mt.__mul = BigInt_mul
BigInteger_mt.__div = BigInt_div
BigInteger_mt.__mod = BigInt_mod
BigInteger_mt.__pow = BigInt_pow
BigInteger_mt.__unm = function(a)
	a = BigInt_ensure(a)
	-- should be faster than mul -1
	if #a[2] == 1 and a[2][1] == 0 then
		return a
	end
	return BigInt_new_raw(-a[1], a[2])
end

BigInteger_mt.__concat = function(a, b) return tostring(a) .. tostring(b) end
BigInteger_mt.__tostring = function(a)
	return BigInt_tostring(BigInt_ensure(a))
end

----------------------------------------------------------------------
-- Public API bindings
----------------------------------------------------------------------

---@return table
local BigInteger_zero = function()
	return BigInt_new_raw(1, { 0 })
end

---@return table
local BigInteger_one = function()
	return BigInt_new_raw(1, { 1 })
end

---@param a table
---@return number
local BigInteger_to_number = function(a)
	return BigInt_tonumber(BigInt_ensure(a))
end

---@param a table
---@return string
local BigInteger_to_string = function(a)
	return BigInt_tostring(BigInt_ensure(a))
end

----------------------------------------------------------------------
-- Expression evaluator
----------------------------------------------------------------------

-- Token types
local T_NUM = 1
local T_ADD = 2
local T_SUB = 3
local T_MUL = 4
local T_DIV = 5
local T_MOD = 6
local T_POW = 7
local T_LP = 8
local T_RP = 9
local T_EOF = 10

-- AST node types
local NODE_NUMBER = 1
local NODE_UNARY = 2
local NODE_BINOP = 3

-- Byte -> token lookup
local BYTE_TO_TOKEN = {
	[43] = T_ADD, -- '+'
	[45] = T_SUB, -- '-'
	[42] = T_MUL, -- '*'
	[47] = T_DIV, -- '/'
	[37] = T_MOD, -- '%'
	[94] = T_POW, -- '^'
	[40] = T_LP, -- '('
	[41] = T_RP, -- ')'
}

-- Token -> operator string lookup (for potential external use)
--local TOKEN_TO_OP = {
--  [T_ADD] = "+",
--  [T_SUB] = "-",
--  [T_MUL] = "*",
--  [T_DIV] = "/",
--  [T_MOD] = "%",
--  [T_POW] = "^",
--}

-- Array of tokens
local lex = function(input)
	local tokens = {}
	local i = 1
	local len = #input

	while i <= len do
		local b = string_byte(input, i, i)

		-- whitespace: space, tab, CR, LF
		if b == 32 or b == 9 or b == 10 or b == 13 then
			i = i + 1

			-- digits
		elseif b >= 48 and b <= 57 then
			local start = i
			i = i + 1
			while i <= len do
				local b2 = string_byte(input, i, i)
				if b2 < 48 or b2 > 57 then
					break
				end
				i = i + 1
			end
			local num = string_sub(input, start, i - 1)
			tokens[#tokens + 1] = { T_NUM, num }
		else
			local tok = BYTE_TO_TOKEN[b]
			if tok then
				tokens[#tokens + 1] = { tok }
				i = i + 1
			else
				return error("unexpected character in expression: " .. string_sub(input, i, i), 2)
			end
		end
	end

	tokens[#tokens + 1] = { T_EOF }
	return tokens
end

----------------------------------------------------------------------
-- Recursive-descent parser
-- Produce AST (abstract syntax tree) from lex tokens
-- Grammar (right-associative ^):
-- expr   := term ((+|-) term)*
-- term   := factor ((*|/|%) factor)*
-- factor := unary
-- unary  := (+|-) unary | power
-- power  := primary (^ power)?
-- primary:= NUMBER | '(' expr ')'
----------------------------------------------------------------------

local parse = function(tokens)
	local pos = 1

	local current = function() -- TODO: inline this, and remove this function
		return tokens[pos]
	end

	-- TODO: refactor all of these nested local functions, move them outside of this function (into root scope) to make JIT happier

	local eat = function(tt)
		local tok = tokens[pos]
		if tok[1] == tt then
			pos = pos + 1
		else
			return error("unexpected token", 2)
		end
	end

	local parse_expr, parse_term, parse_factor, parse_power, parse_primary

	function parse_expr()
		local node = parse_term()
		while true do
			local t = current()[1]
			if t == T_ADD or t == T_SUB then
				local op = t -- TODO/FIXME: can this be inlined (and removed)?
				eat(t)
				local right = parse_term()
				node = { NODE_BINOP, op, node, right }
			else
				break
			end
		end
		return node
	end

	function parse_term()
		local node = parse_factor()
		while true do
			local t = current()[1]
			if t == T_MUL or t == T_DIV or t == T_MOD then
				local op = t -- TODO/FIXME: can this be inlined (and removed)?
				eat(t)
				local right = parse_factor()
				node = { NODE_BINOP, op, node, right }
			else
				break
			end
		end
		return node
	end

	function parse_factor()
		-- unary
		local t = current()[1]
		if t == T_ADD then
			eat(T_ADD)
			return { NODE_UNARY, T_ADD, parse_factor() }
		end
		if t == T_SUB then
			eat(T_SUB)
			return { NODE_UNARY, T_SUB, parse_factor() }
		end
		return parse_power()
	end

	function parse_power()
		local node = parse_primary()
		if current()[1] == T_POW then
			eat(T_POW)
			node = { NODE_BINOP, T_POW, node, parse_power() } -- right-associative
		end
		return node
	end

	function parse_primary()
		local tok = current()
		local t = tok[1]
		if t == T_NUM then
			eat(T_NUM)
			return { NODE_NUMBER, tok[2] }
		end
		if t == T_LP then
			eat(T_LP)
			local node = parse_expr()
			eat(T_RP)
			return node
		end
		return error("unexpected token in primary", 2)
	end

	local ast = parse_expr()
	if current()[1] ~= T_EOF then
		return error("unexpected tokens after expression", 2)
	end
	return ast
end

local eval_ast
eval_ast = function(node)
	local kind = node[1]

	-- TODO: Use lookup table: kind_lookup[kind] and kind_lookup[kind](node) or error("unknown AST node kind", 2)
	if kind == NODE_NUMBER then
		return BigInt_from_any(node[2])
	end
	if kind == NODE_UNARY then
		local op = node[2]
		local v = eval_ast(node[3])
		if op == T_SUB then
			return BigInt_new_raw(-v[1], v[2])
		end
		return v
	end
	if kind == NODE_BINOP then
		local op = node[2]
		local l = eval_ast(node[3])
		local r = eval_ast(node[4])

		-- TODO: Use lookup table: binop_lookup[op] and binop_lookup[op](l, r) or error("unknown binary operator", 2)
		if op == T_ADD then
			return BigInt_add(l, r)
		end
		if op == T_SUB then
			return BigInt_sub(l, r)
		end
		if op == T_MUL then
			return BigInt_mul(l, r)
		end
		if op == T_DIV then
			return BigInt_div(l, r)
		end
		if op == T_MOD then
			return BigInt_mod(l, r)
		end
		if op == T_POW then
			return BigInt_pow(l, r)
		end

		return error("unknown binary operator", 2)
	end

	return error("unknown AST node kind", 2)
end

---@param expr string
---@return table|nil
local BigInteger_eval = function(expr)
	return eval_ast(parse(lex(expr)))
end

-- Export
return setmetatable({
	new = BigInt_from_any,
	zero = BigInteger_zero,
	one = BigInteger_one,
	to_number = BigInteger_to_number,
	to_string = BigInteger_to_string,
	eval = BigInteger_eval,
}, {
	__call = function(_, ...) return BigInt_from_any(...) end
})
