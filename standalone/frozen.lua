-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Immutable, callable classes.
--
-- Factory for defining frozen (immutable) classes. Both the class proxy and
-- every instance reject future assignments via `__newindex`, guaranteeing
-- immutability after creation. Instances delegate lookup to the definition
-- table (`__index = def`), while the class proxy delegates reads through
-- `rawget` so metamethods are not triggered. The optional `init` field is
-- treated as the constructor and invoked with the new instance as first
-- argument. During `init`, fields can be assigned normally (`self.x = x`),
-- and once construction completes, all future assignments are rejected.

-- Localized global functions for better performance
local error = error
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local tostring = tostring
local type = type

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

--- Sentinel used for `__metatable` to hide the real metatable.<br>
--- Applied to both the definition table and the public class proxy.
local FROZEN_METATABLE = "<frozen>"

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Rejects writes to frozen instances.
---@param _ table The instance (unused).
---@param k any The attempted key.
---@return nil _ No return, always errors.
local function frozen_instance_newindex(_, k)
	return error("instance is frozen: cannot assign '" .. tostring(k) .. "'", 2)
end

--- Rejects writes to the frozen class proxy.
---@param _ table The class proxy (unused).
---@param k any The attempted key.
---@return nil _ No return, always errors.
local function frozen_class_newindex(_, k)
	return error("class is frozen: cannot assign '" .. tostring(k) .. "'", 2)
end

----------------------------------------------------------------------
-- Class factory
----------------------------------------------------------------------

--- Definition table for `frozen`.
---@class FrozenDef
---@field init? fun(self: table, ...) Constructor invoked with the new instance as first argument.
---@field [string] any Methods and static values shared by instances via `__index`.

--- Callable class proxy returned by `frozen`.<br>
--- Call the proxy to create a new frozen instance.
---@class FrozenClass
---@field [string] any Read-only view of the definition table (via `__index` + `rawget`).

--- Define an immutable, callable class.<br>
--- `def` maps method names to functions; the special `init` field runs as the constructor body when the class is called.<br>
--- Instances delegate lookups to methods and a private backing store, and any future write on either the class or an instance fails loudly.
---@param def? table Definition table mapping method names to functions. The special `init` field is used as the constructor body.
---@return FrozenClass class Empty proxy representing the class. Call `class(...)` to create a frozen instance.
---@usage <br>
--- ```
--- local Point = frozen({
--- 	init = function(self, x, y)
--- 		self.x = x
--- 		self.y = y
--- 	end,
---
--- 	distance = function(self)
--- 		return math.sqrt(self.x * self.x + self.y * self.y)
--- 	end,
--- })
---
--- local p = Point(3, 4)
--- print(p:distance()) -- 5
--- p.x = 10            -- error: instance is frozen: cannot assign 'x'
--- Point.extra = true  -- error: class is frozen: cannot assign 'extra'
--- ```
local frozen = function(def)
	def = def or {}

	-- Create an isolated internal table to prevent external mutation leaks
	local class_meta = {}
	for k, v in next, def do
		class_meta[k] = v
	end

	-- Respect custom user __index if provided, otherwise default to class_meta itself
	local custom_index = class_meta.__index
	if type(custom_index) == "function" then
		class_meta.__index = function(self, k)
			local v = class_meta[k]
			if v ~= nil then return v end
			return custom_index(self, k)
		end
	elseif type(custom_index) == "table" then
		class_meta.__index = function(self, k)
			local v = class_meta[k]
			if v ~= nil then return v end
			return custom_index[k]
		end
	else
		class_meta.__index = class_meta
	end

	-- Lock down the definition table against metatable inspection.
	class_meta.__metatable = FROZEN_METATABLE

	-- The public class object is an *empty* proxy:
	-- reads delegate to `class_meta`, writes always hit `__newindex`,
	-- so even overwriting an existing method is rejected.
	return setmetatable({}, {
		__call = function(_, ...)
			local store = {}
			local initializing = true

			local obj = setmetatable({}, {
				__index = function(_, k)
					local v = class_meta[k]
					if v ~= nil then return v end
					return store[k]
				end,
				__newindex = function(_, k, v)
					if initializing then
						store[k] = v
					else
						return error("instance is frozen: cannot assign '" .. tostring(k) .. "'", 2)
					end
				end,
				__metatable = FROZEN_METATABLE,
			})

			local init = rawget(class_meta, "init")
			if init then
				init(obj, ...)
			end
			-- rawset inside init bypasses __newindex and creates a raw field on the instance.
			-- Lua only invokes __newindex for missing keys, so a later normal assignment
			-- (e.g. c.value = 10) would silently update the raw field without error.
			-- Migrate any raw keys created via rawset into the private store and clear the
			-- raw table so the instance stays empty and future writes always trap via __newindex.
			do
				local to_move = {}
				for k, v in next, obj do
					to_move[k] = v
				end
				for k, v in next, to_move do
					if store[k] == nil then
						store[k] = v
					end
					rawset(obj, k, nil)
				end
			end
			initializing = false

			return obj
		end,

		__index = function(_, k)
			return rawget(class_meta, k)
		end,

		__newindex = frozen_class_newindex,

		__metatable = FROZEN_METATABLE,
	})
end

-- Export
return frozen
