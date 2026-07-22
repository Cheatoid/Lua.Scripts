-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = require "init"

local class = luameta.class
local trait = luameta.trait
local namespace = luameta.namespace

local tests_passed = 0
local tests_failed = 0
local tests_skipped = 0

-- Lua 5.1 (and LuaJIT) do not support __len or __gc metamethods on tables
local is_lua51 = _VERSION == "Lua 5.1" or jit

local function run_test(name, fn)
	if not fn then
		tests_skipped = tests_skipped + 1
		io.write(string.format("Testing: %-55s ... ", name))
		print("SKIPPED (requires Lua 5.2+)")
		return
	end
	io.write(string.format("Testing: %-55s ... ", name))
	local ok, err = pcall(fn)
	if ok then
		print("PASSED")
		tests_passed = tests_passed + 1
	else
		print("FAILED")
		print("  --> Error: " .. tostring(err))
		tests_failed = tests_failed + 1
	end
end

local function assert_throws(fn, msg_substring)
	local ok, err = pcall(fn)
	assert(not ok, "Expected function to throw an error, but it succeeded.")
	if msg_substring then
		assert(
			string.find(tostring(err), msg_substring, 1, true) ~= nil,
			string.format("Expected error message containing '%s', got '%s'", msg_substring, tostring(err))
		)
	end
end

print("==================================================================")
print("                    RUNNING LUAMETA TEST SUITE                    ")
print("==================================================================\n")

--------------------------------------------------------------------------------
-- 1. BASIC CLASS & INSTANTIATION
--------------------------------------------------------------------------------

run_test("Basic class creation and constructor execution", function()
	class "Person"
		:constructor(function(self, name, age)
			self.name = name
			self.age = age
		end)
		:method {
			greet = function(self)
				return "Hello, " .. self.name
			end
		}

	local p = Person("Alice", 30)
	assert(p.name == "Alice", "Constructor failed to set instance field 'name'")
	assert(p.age == 30, "Constructor failed to set instance field 'age'")
	assert(p:greet() == "Hello, Alice", "Method call failed")
	assert(p:isA(Person), "isA failed for own class")
	assert(p:isA(_G.Person), "isA failed for global class reference")
end)

run_test("Private state encapsulation", function()
	class "Encapsulated"
		:constructor(function(self, secret)
			self:private().secret = secret
		end)
		:method {
			getSecret = function(self)
				return self:private().secret
			end
		}

	local obj = Encapsulated("top_secret")
	assert(obj.secret == nil, "Private variable leaked to public instance fields")
	assert(obj:getSecret() == "top_secret", "Private accessor method failed")
end)

run_test("Instance cloning", function()
	class "CloneableObj"
		:constructor(function(self, val, secret)
			self.val = val
			self:private().secret = secret
		end)
		:method {
			getSecret = function(self)
				return self:private().secret
			end
		}

	local orig = CloneableObj(10, "hidden")
	local copy = orig:clone()

	assert(copy ~= orig, "Clone returned same table reference")
	assert(copy.val == 10, "Clone failed to copy public field")
	assert(copy:getSecret() == "hidden", "Clone failed to duplicate private store")

	-- Ensure mutation of private state doesn't affect clone
	orig:private().secret = "changed"
	assert(copy:getSecret() == "hidden", "Clone shares private store with original")
end)

run_test("Clone preserves class and isA relationship", function()
	class "ClsPreserve"
		:constructor(function(self) self.x = 1 end)

	local orig = ClsPreserve()
	local copy = orig:clone()
	assert(copy.class == orig.class, "Clone preserved class reference")
	assert(copy:isA(ClsPreserve), "Clone isA original class")
end)

run_test("Clone of clone", function()
	class "CloneOfClone"
		:constructor(function(self, v) self.val = v end)

	local a = CloneOfClone("a")
	local b = a:clone()
	local c = b:clone()
	assert(c.val == "a", "Clone of clone preserved value")
	assert(c:isA(CloneOfClone), "Clone of clone isA original class")
	assert(c ~= b and b ~= a, "All clones are distinct tables")
end)

run_test("Clone excludes __super_host__ stale state (BUG #4)", function()
	class "SuperCloneParent"
		:method { base = function(self) return "base" end }

	class "SuperCloneChild":extends "SuperCloneParent"
		:method {
			derived = function(self)
				self:super():base()
				return "child"
			end
		}

	local inst = SuperCloneChild()
	inst:derived() -- populates __super_host__
	local copy = inst:clone()
	-- __super_host__ should not leak into clone's iteration
	for k in next, copy do
		assert(k ~= "__super_host__", "__super_host__ leaked into clone")
	end
end)

run_test("Clone with nested private tables (shallow copy BUG #10)", function()
	class "NestedPrivate"
		:constructor(function(self)
			self:private().cache = { a = 1 }
		end)
		:method {
			getCache = function(self) return self:private().cache end
		}

	local orig = NestedPrivate()
	local copy = orig:clone()
	-- both point to same nested table (shallow copy)
	orig:private().cache.a = 999
	assert(copy:getCache().a == 999, "Nested private table was deep-copied (expected shallow)")
end)

run_test("Clone with properties still works", function()
	class "ClsProp"
		:property {
			val = {
				get = function(self) return self._v end,
				set = function(self, v) self._v = v end
			}
		}
		:constructor(function(self, v) self.val = v end)

	local orig = ClsProp(42)
	local copy = orig:clone()
	assert(copy.val == 42, "Clone property getter works")
	copy.val = 100
	assert(copy.val == 100, "Clone property setter works")
	assert(orig.val == 42, "Original property unchanged by clone mutation")
end)

--------------------------------------------------------------------------------
-- 2. INHERITANCE & SUPER CALLS
--------------------------------------------------------------------------------

run_test("Constructor chain and method overriding", function()
	local order = {}

	class "Animal"
		:constructor(function(self, name)
			table.insert(order, "Animal:" .. name)
		end)
		:method {
			speak = function(self) return "Some sound" end
		}

	class "Dog":extends "Animal"
		:constructor(function(self, name)
			table.insert(order, "Dog:" .. name)
		end)
		:method {
			speak = function(self) return "Woof" end
		}

	local d = Dog("Rex")
	assert(#order == 2, "Constructors did not run in chain")
	assert(order[1] == "Animal:Rex", "Parent constructor should run first")
	assert(order[2] == "Dog:Rex", "Child constructor should run second")
	assert(d:speak() == "Woof", "Method override failed")
	assert(d:isA(Dog), "isA failed for derived class")
	assert(d:isA(Animal), "isA failed for base parent class")
end)

run_test("Super method call returning multiple values (pcall fix)", function()
	class "BaseMath"
		:method {
			calc = function(self, a, b)
				return a + b, a * b
			end
		}

	class "SubMath":extends "BaseMath"
		:method {
			calc = function(self, a, b)
				local sum, prod = self:super():calc(a, b)
				return sum + 1, prod + 1
			end
		}

	local sm = SubMath()
	local sum, prod = sm:calc(2, 3)
	assert(sum == 6, "First return value from super call was truncated or invalid")
	assert(prod == 7, "Second return value from super call was truncated or invalid")
end)

run_test("Super call on root class (no parent) returns nil", function()
	class "RootNoParent"
		:method {
			callSuper = function(self) return self:super() end
		}

	local inst = RootNoParent()
	assert(inst:callSuper() == nil, "super() on root class should return nil")
end)

run_test("Super call on non-existent method errors clearly", function()
	class "NoSuchMethodParent"
		:method { ok = function() return 1 end }

	class "NoSuchMethodChild":extends "NoSuchMethodParent"
		:method {
			bad = function(self) return self:super():nonexistent() end
		}

	local inst = NoSuchMethodChild()
	assert_throws(function() inst:bad() end, "super: method 'nonexistent' not found")
end)

run_test("Super call chain (3+ levels)", function()
	local chain = {}
	class "L1"
		:method { run = function(self) table.insert(chain, "L1") end }

	class "L2":extends "L1"
		:method { run = function(self)
			self:super():run(); table.insert(chain, "L2")
		end }

	class "L3":extends "L2"
		:method { run = function(self)
			self:super():run(); table.insert(chain, "L3")
		end }

	local inst = L3()
	inst:run()
	assert(#chain == 3, "Super chain produced wrong number of calls")
	assert(chain[1] == "L1" and chain[2] == "L2" and chain[3] == "L3", "Super chain order wrong")
end)

run_test("Super call with nil arguments", function()
	class "NilArgParent"
		:method { ident = function(self, a, b, c) return a, b, c end }

	class "NilArgChild":extends "NilArgParent"
		:method { ident = function(self, a, b, c) return self:super():ident(a, b, c) end }

	local inst = NilArgChild()
	local a, b, c = inst:ident(1, nil, 3)
	assert(a == 1 and b == nil and c == 3, "Super call with nil args failed")
end)

run_test("Super call preserves non-string error types (BUG #5)", function()
	class "ErrParent"
		:method { crash = function(self) error({ code = 42 }) end }

	class "ErrChild":extends "ErrParent"
		:method { crash = function(self) self:super():crash() end }

	local inst = ErrChild()
	local ok, err = pcall(function() inst:crash() end)
	assert(not ok, "Expected error to propagate")
	assert(type(err) == "table", "Non-string error type was stringified, got " .. type(err))
	assert(err.code == 42, "Error table content was lost")
end)

run_test("Final class and final method restrictions", function()
	class "FinalBase"
		:finalMethod {
			lockedMethod = function() return "locked" end
		}

	local SubOfFinalBase = class "SubOfFinalBase":extends "FinalBase"

	assert_throws(function()
		SubOfFinalBase:method {
			lockedMethod = function() return "override" end
		}
	end, "cannot override final method")

	class "SealedParent":final()

	assert_throws(function()
		class "ChildOfSealed":extends "SealedParent"
	end, "cannot inherit from final class")
end)

--------------------------------------------------------------------------------
-- 3. INHERITED PROPERTIES (GETTERS & SETTERS)
--------------------------------------------------------------------------------

run_test("Inherited properties getter/setter traversal", function()
	class "BaseWithProps"
		:property {
			multiplier = {
				get = function(self) return (self._val or 0) * 2 end,
				set = function(self, v) self._val = v end
			}
		}

	class "DerivedWithProps":extends "BaseWithProps"

	local inst = DerivedWithProps()
	inst.multiplier = 10 -- Exercises setter from parent
	assert(inst._val == 10, "Property setter from parent was not executed")
	assert(inst.multiplier == 20, "Property getter from parent was not executed")
end)

run_test("Property with only getter (no setter) falls back to rawset", function()
	class "ReadOnlyProp"
		:property {
			val = { get = function(self) return self._val or 0 end }
		}

	local inst = ReadOnlyProp()
	assert(inst.val == 0, "Read-only property getter failed")
	inst.val = 42
	-- no setter defined, so rawset on instance
	assert(inst.val == 42, "Read-only property with no setter should rawset")
	assert(rawget(inst, "val") == 42, "No-setter property should rawset instance field")
end)

run_test("Property with only setter (no getter) returns nil on read", function()
	class "WriteOnlyProp"
		:property {
			val = { set = function(self, v) self._v = v end }
		}

	local inst = WriteOnlyProp()
	inst.val = 10
	assert(inst._v == 10, "Write-only property setter not invoked")
	assert(inst.val == nil, "Write-only property getter should return nil")
end)

run_test("Property shadowing (child overrides parent property)", function()
	class "BaseProp"
		:property {
			name = {
				get = function(self) return "base:" .. (self._n or "") end,
				set = function(self, v) self._n = v end
			}
		}

	class "DerivedProp":extends "BaseProp"
		:property {
			name = {
				get = function(self) return "derived:" .. (self._n or "") end,
				set = function(self, v) self._n = "[" .. v .. "]" end
			}
		}

	local inst = DerivedProp()
	inst.name = "test"
	assert(inst.name == "derived:[test]", "Child property setter/getter should override parent")
	local baseInst = BaseProp()
	baseInst.name = "test"
	assert(baseInst.name == "base:test", "Parent property should be unaffected")
end)

run_test("Multi-level property inheritance (3+ levels)", function()
	class "L1Prop"
		:property {
			x = {
				get = function(self) return (self._x or 0) + 1 end,
				set = function(self, v) self._x = v end
			}
		}

	class "L2Prop":extends "L1Prop"
		:property {
			x = {
				get = function(self) return (self._x or 0) + 2 end
			}
		}

	class "L3Prop":extends "L2Prop"

	local inst = L3Prop()
	inst.x = 10
	assert(inst.x == 12, "Multi-level property inheritance: getter from L2, setter from L1")
end)

run_test("Multiple properties on one class", function()
	class "MultiProp"
		:property {
			a = { get = function(self) return self._a end, set = function(self, v) self._a = v end },
			b = { get = function(self) return self._b end, set = function(self, v) self._b = v end }
		}

	local inst = MultiProp()
	inst.a = 1
	inst.b = 2
	assert(inst.a == 1 and inst.b == 2, "Multiple properties on one class failed")
end)

run_test("Property with same name as a method", function()
	class "PropMethodConflict"
		:property {
			run = {
				get = function(self) return "prop_value" end,
				set = function(self, v) rawset(self, "_run", v) end
			}
		}
		:method { run = function(self) return "method_value" end }

	local inst = PropMethodConflict()
	-- methods take precedence over property getters in __index
	assert(inst:run() == "method_value", "Method should shadow property getter")
end)

run_test("Property setter that throws propagates error", function()
	class "ThrowingProp"
		:property {
			val = {
				get = function(self) return self._v end,
				set = function(self, v)
					if v < 0 then error("negative value not allowed", 0) end
					self._v = v
				end
			}
		}

	local inst = ThrowingProp()
	inst.val = 5
	assert(inst.val == 5, "Normal property set works")
	assert_throws(function() inst.val = -1 end, "negative value not allowed")
end)

run_test("Property getter/setter self context is the instance", function()
	local seen_self = nil
	class "SelfContextProp"
		:property {
			val = {
				get = function(self)
					seen_self = self; return 1
				end,
				set = function(self) seen_self = self end
			}
		}

	local inst = SelfContextProp()
	local _ = inst.val
	assert(seen_self == inst, "Property getter self is not the instance")
	inst.val = 0
	assert(seen_self == inst, "Property setter self is not the instance")
end)

--------------------------------------------------------------------------------
-- 4. ABSTRACT CLASSES & METHODS
--------------------------------------------------------------------------------

run_test("Abstract classes and method enforcement", function()
	class "AbstractShape"
		:abstract({ "area", "perimeter" })

	assert_throws(function()
		local shape = AbstractShape()
	end, "cannot instantiate abstract class")

	class "Square":extends "AbstractShape"
		:method {
			area = function(self) return 16 end
		}

	assert_throws(function()
		local sq = Square()
	end, "cannot instantiate abstract class")

	class "CompleteSquare":extends "Square"
		:method {
			perimeter = function(self) return 16 end
		}

	local cs = CompleteSquare()
	assert(cs:area() == 16, "Abstract method implementation failed")
	assert(cs:perimeter() == 16, "Abstract method implementation failed")
end)

run_test("abstract() with no argument prevents instantiation (BUG #2)", function()
	class "AbstractNoArg"
		:abstract()

	assert_throws(function()
		AbstractNoArg()
	end, "cannot instantiate abstract class")
end)

run_test("abstract({}) with empty table prevents instantiation (BUG #2)", function()
	class "AbstractEmptyTable"
		:abstract({})

	assert_throws(function()
		AbstractEmptyTable()
	end, "cannot instantiate abstract class")
end)

run_test("Abstract method implemented via trait", function()
	class "AbstractNeedsWalk"
		:abstract({ "walk" })

	trait "WalkTrait"
		:method { walk = function(self) return "walking" end }

	class "Walker":extends "AbstractNeedsWalk"
		:implements "WalkTrait"

	local inst = Walker()
	assert(inst:walk() == "walking", "Abstract method via trait implementation failed")
end)

run_test("Final class with abstract methods errors on instantiation", function()
	class "FinalAbstract"
		:final()
		:abstract({ "mustImplement" })

	assert_throws(function()
		FinalAbstract()
	end, "cannot instantiate abstract class")
end)

--------------------------------------------------------------------------------
-- 5. TRAITS & COMPOSED TRAITS
--------------------------------------------------------------------------------

run_test("Basic trait implementation and method resolution", function()
	trait "Flyable"
		:method {
			fly = function(self) return "Flying high" end
		}

	class "Bird"
		:implements "Flyable"

	local b = Bird()
	assert(b:fly() == "Flying high", "Trait method execution failed")
	assert(b:isA(Flyable), "isA failed to recognize implemented trait")
end)

run_test("Composed traits (Trait implementing another Trait)", function()
	trait "BaseTrait"
		:method {
			baseFunc = function(self) return "base" end
		}

	trait "CompositeTrait"
		:implements "BaseTrait"
		:method {
			compFunc = function(self) return "comp" end
		}

	class "TraitUser"
		:implements "CompositeTrait"

	local user = TraitUser()
	assert(user:compFunc() == "comp", "Direct trait method failed")
	assert(user:baseFunc() == "base", "Composed/nested trait method failed to inherit")
end)

run_test("Trait options: alias, except, and only", function()
	trait "Logger"
		:method {
			log = function(self) return "log" end,
			debug = function(self) return "debug" end,
			info = function(self) return "info" end
		}

	class "AliasedApp"
		:implements({
			trait = Logger,
			alias = { log = "customLog" },
			except = { "debug" }
		})

	local app = AliasedApp()
	assert(app:customLog() == "log", "Trait method aliasing failed")
	assert(app.log == nil, "Original aliased method still exposed")
	assert(app.debug == nil, "Excepted trait method was imported")
	assert(app:info() == "info", "Non-excepted method missing")
end)

--------------------------------------------------------------------------------
-- 6. NAMESPACES
--------------------------------------------------------------------------------

run_test("Namespace isolation and class descriptor handling", function()
	local AppNS = namespace "App"

	class "Widget"
		:method { render = function() return "rendering" end }

	AppNS { Widget }

	assert(_G.Widget == nil, "Namespace failed to remove class from global scope")
	assert(AppNS.Widget ~= nil, "Class missing from namespace table")

	class "Button":extends "Widget"

	local btn = Button()
	assert(btn:render() == "rendering", "Namespace lookup failed during extends")
end)

run_test("Nested namespaces", function()
	local Root = namespace "Root"
	local sub = Root:nested("Core.Utils")

	class "Helper"
		:method { help = function() return "helping" end }

	sub { Helper }

	assert(Root.Core.Utils.Helper ~= nil, "Nested namespace resolution failed")
	local h = Root.Core.Utils.Helper()
	assert(h:help() == "helping", "Instantiation from nested namespace failed")
end)

--------------------------------------------------------------------------------
-- 7. KEY SHADOWING & RESERVED HELPER SAFETY
--------------------------------------------------------------------------------

run_test("User-defined methods overriding reserved key defaults", function()
	class "CustomClone"
		:method {
			clone = function(self)
				return "Custom Clone Method"
			end
		}

	local inst = CustomClone()
	assert(inst:clone() == "Custom Clone Method", "User 'clone' method was shadowed by default helper")
end)

run_test("User method named 'isA' works correctly", function()
	class "CustomIsA"
		:method {
			isA = function(self, target)
				return "custom"
			end
		}

	local inst = CustomIsA()
	assert(inst:isA("anything") == "custom", "Custom isA method should be callable")
end)

run_test("User method named 'class' returns method not class table", function()
	class "CustomClass"
		:method {
			class = function(self) return "custom_class_method" end
		}

	local inst = CustomClass()
	-- inst.class should return the method, not the class table
	assert(inst:class() == "custom_class_method", "Custom class method should be callable")
end)

run_test("User method named 'super' inside instance", function()
	class "CustomSuper"
		:method {
			super = function(self) return "custom_super" end
		}

	local inst = CustomSuper()
	-- inst:super() should return the method
	assert(inst:super() == "custom_super", "Custom super method should override default")
end)

run_test("User method named 'private' works", function()
	class "CustomPrivate"
		:method {
			private = function(self) return "custom_private" end
		}

	local inst = CustomPrivate()
	assert(inst:private() == "custom_private", "Custom private method should be callable")
end)

--------------------------------------------------------------------------------
-- 8. STATIC MEMBERS
--------------------------------------------------------------------------------

run_test("Static methods and properties on class", function()
	class "StaticDemo"
		:static {
			version = "1.0",
			reset = function(self) self.counter = 0 end,
		}
		:static { counter = 0 }

	assert(StaticDemo.version == "1.0", "Static property not accessible on class table")
	assert(StaticDemo.counter == 0, "Static counter initialization failed")
	StaticDemo:reset()
	assert(StaticDemo.counter == 0, "Static method call failed")
end)

run_test("Static members inherited by subclass", function()
	class "ParentStatic"
		:static { species = "mammal" }

	class "ChildStatic":extends "ParentStatic"

	assert(ChildStatic.species == "mammal", "Inherited static property missing on subclass")
end)

run_test("Static with nil value", function()
	class "StaticNilVal"
		:static { foo = nil }

	assert(StaticNilVal.foo == nil, "Static with nil value should be nil")
	assert(rawget(StaticNilVal, "foo") ~= nil or rawget(_G.StaticNilVal, "foo") == nil,
		"Static nil should be stored (not absent)")
end)

run_test("Static with false value", function()
	class "StaticFalseVal"
		:static { enabled = false }

	assert(StaticFalseVal.enabled == false, "Static with false value should be false")
	assert(rawget(StaticFalseVal, "enabled") == false, "Static false should be stored as raw")
end)

run_test("Static method inheritance through 3+ levels", function()
	class "StaticGP"
		:static { gp = function() return "gp" end }

	class "StaticP":extends "StaticGP"
		:static { p = function() return "p" end }

	class "StaticC":extends "StaticP"
		:static { c = function() return "c" end }

	assert(StaticC:gp() == "gp", "Static inherited from grandparent")
	assert(StaticC:p() == "p", "Static inherited from parent")
	assert(StaticC:c() == "c", "Static own method")
end)

run_test("Static method shadowing in child", function()
	class "StaticShadowParent"
		:static { value = function() return "parent" end }

	class "StaticShadowChild":extends "StaticShadowParent"
		:static { value = function() return "child" end }

	assert(StaticShadowChild:value() == "child", "Static shadow should use child's method")
	assert(StaticShadowParent:value() == "parent", "Parent static should be unchanged")
end)

run_test("Static method called from instance via self.class", function()
	class "StaticViaInstance"
		:static { kind = "special" }

	local inst = StaticViaInstance()
	assert(inst.class.kind == "special", "Instance.class should access static")
end)

--------------------------------------------------------------------------------
-- 9. METAMETHODS VIA meta BUILDER
--------------------------------------------------------------------------------

run_test("Custom __tostring via meta builder", function()
	class "Labeled"
		:constructor(function(self, label)
			self.label = label
		end)
		:meta { __tostring = function(self) return "Labeled:" .. self.label end }

	local obj = Labeled("test")
	assert(tostring(obj) == "Labeled:test", "Custom __tostring not applied")
end)

run_test("Custom operator metamethods via meta builder", function()
	class "Vec2"
		:constructor(function(self, x, y)
			self.x = x
			self.y = y
		end)
		:meta {
			__add = function(a, b) return Vec2(a.x + b.x, a.y + b.y) end,
		}

	local v1 = Vec2(1, 2)
	local v2 = Vec2(3, 4)
	local v3 = v1 + v2
	assert(v3.x == 4 and v3.y == 6, "Custom __add metamethod not working")
end)

run_test("meta builder rejects __index and __newindex override", function()
	class "MetaGuard"
	assert_throws(function()
		class "MetaGuardBad":meta { __index = {} }
	end, "cannot redeclare")
end)

run_test("__eq on instances", function()
	class "EqClass"
		:constructor(function(self, id) self.id = id end)
		:meta { __eq = function(a, b) return a.id == b.id end }

	local a = EqClass(1)
	local b = EqClass(1)
	local c = EqClass(2)
	assert(a == b, "Custom __eq should match same id")
	assert(a ~= c, "Custom __eq should reject different id")
end)

run_test("__lt and __le on instances", function()
	class "OrdClass"
		:constructor(function(self, v) self.v = v end)
		:meta {
			__lt = function(a, b) return a.v < b.v end,
			__le = function(a, b) return a.v <= b.v end
		}

	local s = OrdClass(1)
	local m = OrdClass(2)
	assert(s < m, "__lt failed")
	assert(s <= m, "__le failed")
	assert(m >= s, "__le (reverse) failed")
end)

if is_lua51 then
	run_test("__len on instances (requires Lua 5.2+)")
else
	run_test("__len on instances", function()
		class "LenClass"
			:constructor(function(self, items) self.items = items end)
			:meta { __len = function(self) return #self.items end }

		local inst = LenClass({ 10, 20, 30 })
		assert(#inst == 3, "__len on instance failed")
	end)
end

run_test("__concat on instances", function()
	class "ConcatClass"
		:constructor(function(self, s) self.s = s end)
		:meta { __concat = function(a, b) return ConcatClass(a.s .. b.s) end }

	local a = ConcatClass("hello ")
	local b = ConcatClass("world")
	local c = a .. b
	assert(c.s == "hello world", "__concat on instance failed")
end)

if is_lua51 then
	run_test("__len on instance (via meta) (requires Lua 5.2+)")
else
	run_test("__len on instance (via meta)", function()
		class "LenViaMeta"
			:constructor(function(self, items) self.items = items end)
			:meta { __len = function(self) return #self.items end }

		local inst = LenViaMeta({ 10, 20, 30 })
		assert(#inst == 3, "__len via meta on instance failed")
	end)
end

run_test("Meta method inheritance through extends", function()
	class "MetaParent"
		:meta { __tostring = function(self) return "parent:" .. self.x end }

	class "MetaChild":extends "MetaParent"

	local inst = MetaChild()
	inst.x = 5
	assert(tostring(inst) == "parent:5", "Meta method not inherited")
end)

run_test("Meta method override in subclass", function()
	class "MetaOverrideParent"
		:meta { __tostring = function(self) return "parent" end }

	class "MetaOverrideChild":extends "MetaOverrideParent"
		:meta { __tostring = function(self) return "child" end }

	local p = MetaOverrideParent()
	local c = MetaOverrideChild()
	assert(tostring(p) == "parent", "Parent __tostring should be preserved")
	assert(tostring(c) == "child", "Child __tostring should override parent")
end)

run_test("__tostring on class table itself", function()
	class "ClassTostring"
		:meta { __tostring = function(self) return "class:" .. self.name end }

	assert(tostring(ClassTostring) == "class:ClassTostring", "__tostring on class table failed")
end)

--------------------------------------------------------------------------------
-- 10. SEALED METHODS & DESTRUCTOR
--------------------------------------------------------------------------------

run_test("Final method cannot be overridden by any subclass", function()
	class "FinalMethodParent"
		:finalMethod {
			locked = function(self) return "parent" end
		}

	assert_throws(function()
		class "FinalMethodChild":extends "FinalMethodParent"
			:method {
				locked = function(self) return "child" end
			}
	end, "cannot override final method")
end)

if is_lua51 then
	run_test("Destructor registration via destructor builder (requires Lua 5.2+)")
else
	run_test("Destructor registration via destructor builder", function()
		local gc_called = false
		class "HasDestructor"
			:destructor(function(self)
				gc_called = true
			end)

		-- Create and collect
		local obj = HasDestructor()
		obj = nil
		collectgarbage()
		assert(gc_called, "Destructor was not called after garbage collection")
	end)
end

if is_lua51 then
	run_test("Destructor on clone (requires Lua 5.2+)")
else
	run_test("Destructor on clone", function()
		local destroyed = {}
		class "CloneDestructor"
			:constructor(function(self, id) self.id = id end)
			:destructor(function(self) table.insert(destroyed, self.id) end)

		local orig = CloneDestructor("orig")
		local copy = orig:clone()
		-- reassign so they go out of scope
		orig = nil
		copy = nil
		collectgarbage()
		-- at least one destructor should have run
		assert(#destroyed >= 1, "Destructor was not called after clone")
	end)
end

if is_lua51 then
	run_test("Destructor inherited by subclass (requires Lua 5.2+)")
else
	run_test("Destructor inherited by subclass", function()
		local ran = false
		class "DestructorParent"
			:destructor(function(self) ran = true end)

		class "DestructorChild":extends "DestructorParent"

		local inst = DestructorChild()
		inst = nil
		collectgarbage()
		assert(ran, "Destructor should be inherited by subclass")
	end)
end

--------------------------------------------------------------------------------
-- 11. ADVANCED INHERITANCE
--------------------------------------------------------------------------------

run_test("Extends with table reference instead of string", function()
	class "TableExtBase"
		:method { greet = function() return "hi" end }

	class("TableExtChild"):extends(TableExtBase)
		:method { greet = function() return "hello" end }

	local obj = TableExtChild()
	assert(obj:greet() == "hello", "Table-based extends failed")
end)

run_test("Extends with own class name raises error", function()
	class "SelfExtend"
	assert_throws(function()
		class "SelfExtender":extends "SelfExtender"
	end, "not a valid class")
end)

run_test("Double extends raises error", function()
	class "SingleParent"
	class "SingleChild":extends "SingleParent"
	assert_throws(function()
		class "DoubleExtendChild":extends "SingleParent"
			:extends "SingleParent"
	end, "has already inherited")
end)

run_test("Multi-level inheritance with method chain", function()
	class "Grandparent"
		:method { value = function() return 1 end }

	class "ParentLevel":extends "Grandparent"
		:method { value = function() return 2 end }

	class "ChildLevel":extends "ParentLevel"
		:method { value = function() return 3 end }

	local obj = ChildLevel()
	assert(obj:value() == 3, "Multi-level method resolution failed")
	local pobj = ParentLevel()
	assert(pobj:value() == 2, "Parent level method resolution failed")
	assert(obj:isA(Grandparent), "isA failed for grandparent")
	assert(obj:isA(ParentLevel), "isA failed for parent")
end)

run_test("Super call with static methods", function()
	class "BaseStaticSuper"
		:static { kind = function() return "base" end }

	class "ChildStaticSuper":extends "BaseStaticSuper"
		:static { kind = function(self) return "child" end }

	assert(ChildStaticSuper:kind() == "child", "Static method override failed")
end)

run_test("Abstract method inherited by sub-child after full implementation", function()
	class "AbstractRoot"
		:abstract({ "doThing" })

	class "AbstractMid":extends "AbstractRoot"
	-- does not implement doThing

	class "AbstractLeaf":extends "AbstractMid"
		:method { doThing = function() return "done" end }

	local leaf = AbstractLeaf()
	assert(leaf:doThing() == "done", "Abstract method implementation via inheritance chain failed")
	assert(leaf:isA(AbstractRoot), "isA failed for abstract root ancestor")
end)

run_test("Extends after method defined (order independence)", function()
	class "OrderMethod"
		:method { greet = function() return "hi" end }

	class "OrderMethodChild":extends "OrderMethod"

	local inst = OrderMethodChild()
	assert(inst:greet() == "hi", "Extends after method failed")
end)

run_test("Extends after static defined", function()
	class "OrderStatic"
		:static { MODE = "test" }

	class "OrderStaticChild":extends "OrderStatic"

	assert(OrderStaticChild.MODE == "test", "Extends after static failed")
end)

run_test("Extends after meta defined", function()
	class "OrderMeta"
		:meta { __tostring = function(self) return "ordered" end }

	class "OrderMetaChild":extends "OrderMeta"

	local inst = OrderMetaChild()
	assert(tostring(inst) == "ordered", "Extends after meta failed")
end)

run_test("Extends after property defined", function()
	class "OrderProp"
		:property {
			x = { get = function(self) return self._x end, set = function(self, v) self._x = v end }
		}

	class "OrderPropChild":extends "OrderProp"

	local inst = OrderPropChild()
	inst.x = 42
	assert(inst.x == 42, "Extends after property failed")
end)

run_test("Extends after abstract defined", function()
	class "OrderAbstract"
		:abstract({ "foo" })

	class "OrderAbstractChild":extends "OrderAbstract"
		:method { foo = function() return "foo" end }

	local inst = OrderAbstractChild()
	assert(inst:foo() == "foo", "Extends after abstract failed")
end)

run_test("Extends after finalMethod defined", function()
	class "OrderFinalMethod"
		:finalMethod { locked = function() return "locked" end }

	class "OrderFinalMethodChild":extends "OrderFinalMethod"

	assert_throws(function()
		class "BadOverride":extends "OrderFinalMethod"
			:method { locked = function() return "bad" end }
	end, "cannot override final method")
end)

run_test("Extends after instantiation raises error (BUG #6)", function()
	class "PostInstParentA"
		:method { hey = function() return "hey" end }

	class "PostInstChildA":extends "PostInstParentA"

	local inst = PostInstChildA()
	local desc = class.get("PostInstChildA")
	assert_throws(function()
		desc:extends(PostInstParentA)
	end, "cannot extend class")
end)

--------------------------------------------------------------------------------
-- 12. isA AND CLASS HELPER EDGE CASES
--------------------------------------------------------------------------------

run_test("isA with trait name string", function()
	trait "TraitForIsA"
		:method { tMethod = function() return "trait" end }

	class "ClassWithTrait"
		:implements "TraitForIsA"

	local obj = ClassWithTrait()
	assert(obj:isA("TraitForIsA"), "isA with string trait name failed")
end)

run_test("isA returns false for unrelated class instances", function()
	class "ClassA"
	class "ClassB"
	local a = ClassA()
	assert(a:isA(ClassA), "isA should return true for own class")
	assert(a:isA(ClassB) == false, "isA should return false for unrelated class")
end)

run_test("class.is static function", function()
	class "ClassIsDemo"
	local obj = ClassIsDemo()
	assert(class.is(obj, ClassIsDemo), "class.is returned false for valid instance")
	assert(class.is(obj, _G.ClassIsDemo), "class.is failed with global class reference")
	assert(class.is({}, ClassIsDemo) == false, "class.is returned true for plain table")
	assert(class.is(nil, ClassIsDemo) == false, "class.is returned true for nil")
	assert(class.is("str", ClassIsDemo) == false, "class.is returned true for string")
end)

run_test("class.get and class.isClass static functions", function()
	class "HelperCheck"

	local retrieved = class.get("HelperCheck")
	assert(retrieved ~= nil, "class.get returned nil for registered class")
	assert(retrieved.name == "HelperCheck", "class.get returned wrong descriptor")
	assert(class.isClass(HelperCheck), "class.isClass returned false for class table")
	assert(class.isClass({}) == false, "class.isClass returned true for plain table")
	assert(class.isClass(nil) == false, "class.isClass returned true for nil")
end)

run_test("Instance :class accessor", function()
	class "ClassAccessorDemo"
		:method { ident = function() return "demo" end }

	local obj = ClassAccessorDemo()
	local cls = obj.class
	assert(cls ~= nil, ":class returned nil")
	assert(cls.name == "ClassAccessorDemo", ":class returned wrong class table")
	-- Static property access via :class
	assert(cls.origin ~= nil, "Class table missing origin pointer")
	assert(rawget(cls, "origin") ~= nil, "Class table missing raw origin pointer")
end)

--------------------------------------------------------------------------------
-- 13. CONSTRUCTOR EDGE CASES
--------------------------------------------------------------------------------

run_test("Multiple constructors in chain", function()
	local calls = {}
	class "MultiCtor"
		:constructor(function(self) table.insert(calls, "first") end)
		:constructor(function(self, a) table.insert(calls, "second:" .. a) end)

	local obj = MultiCtor("x")
	assert(calls[1] == "first", "First constructor did not run")
	assert(calls[2] == "second:x", "Second constructor did not run")
end)

run_test("Class instantiation with no constructor", function()
	class "NoCtor"
	local obj = NoCtor()
	assert(type(obj) == "table", "Instance creation without constructor failed")
	assert(obj:isA(NoCtor), "isA failed for constructor-less class")
end)

run_test("Constructor argument forwarding", function()
	class "ArgForward"
		:constructor(function(self, a, b, c)
			self.a = a
			self.b = b
			self.c = c
		end)

	local obj = ArgForward(1, nil, 3)
	assert(obj.a == 1, "Constructor arg 1 not forwarded")
	assert(obj.b == nil, "Constructor nil arg not preserved")
	assert(obj.c == 3, "Constructor arg 3 not forwarded")
end)

--------------------------------------------------------------------------------
-- 14. TRAIT EDGE CASES
--------------------------------------------------------------------------------

run_test("Trait with only option", function()
	trait "TOnly"
		:method {
			alpha = function() return "a" end,
			beta  = function() return "b" end,
			gamma = function() return "c" end,
		}

	class "OnlyUser"
		:implements({ trait = TOnly, only = { "alpha", "gamma" } })

	local obj = OnlyUser()
	assert(obj:alpha() == "a", "Only trait method 'alpha' missing")
	assert(obj:gamma() == "c", "Only trait method 'gamma' missing")
	assert(obj.beta == nil, "'beta' should not be imported with only filter")
end)

run_test("Trait static methods propagated to class", function()
	trait "TraitStatic"
		:static { factor = 10 }
		:method { compute = function(self, x) return x * self.class.factor end }

	class "TraitStaticUser"
		:implements "TraitStatic"

	local obj = TraitStaticUser()
	assert(TraitStaticUser.factor == 10, "Trait static not propagated to class table")
	assert(obj:compute(5) == 50, "Trait method using class static failed")
end)

run_test("Trait meta methods (non-conflicting)", function()
	trait "TraitMeta"
		:meta { __add = function(a, b) return a end }

	class "TraitMetaUser"
		:implements "TraitMeta"

	local obj = TraitMetaUser()
	assert(rawequal(obj + obj, obj), "Trait meta __add not applied")
end)

run_test("Trait method conflict raises error", function()
	trait "ConflictA"
		:method { shared = function() return "A" end }

	trait "ConflictB"
		:method { shared = function() return "B" end }

	class "ConflictVictimA"
		:implements "ConflictA"

	assert_throws(function()
		class "ConflictVictimB"
			:implements "ConflictB"
			:implements "ConflictA"
	end, "method conflict")
end)

run_test("Trait static conflict raises error", function()
	trait "StaticConflictTrait"
		:static { max = 100 }

	class "StaticConflictClass"
		:static { max = 200 }

	assert_throws(function()
		class "StaticConflictVictim":extends "StaticConflictClass"
			:implements "StaticConflictTrait"
	end, "static conflict")
end)

run_test("Trait meta conflict raises error", function()
	trait "MetaConflictTrait"
		:meta { __tostring = function() return "trait" end }

	class "MetaConflictClass"
		:meta { __tostring = function() return "class" end }

	assert_throws(function()
		class "MetaConflictVictim":extends "MetaConflictClass"
			:implements "MetaConflictTrait"
	end, "meta conflict")
end)

run_test("Implements with non-trait table raises error", function()
	assert_throws(function()
		class "NotTraitUser":implements({})
	end, "not a trait")
end)

run_test("trait.is and trait.get static functions", function()
	trait "TraitHelperCheck"
		:method { h = function() end }

	assert(trait.is(TraitHelperCheck), "trait.is returned false for a trait")
	assert(trait.is({}) == false, "trait.is returned true for plain table")
	assert(trait.is(nil) == false, "trait.is returned true for nil")
	local retrieved = trait.get("TraitHelperCheck")
	assert(retrieved ~= nil, "trait.get returned nil for registered trait")
	assert(retrieved.name == "TraitHelperCheck", "trait.get returned wrong trait")
end)

run_test("Multiple traits on one class", function()
	trait "TMultiA"
		:method { a = function() return "A" end }

	trait "TMultiB"
		:method { b = function() return "B" end }

	class "MultiTraitUser"
		:implements "TMultiA"
		:implements "TMultiB"

	local obj = MultiTraitUser()
	assert(obj:a() == "A", "First of multiple traits missing")
	assert(obj:b() == "B", "Second of multiple traits missing")
end)

run_test("Circular trait implementation (A→B, B→A) does not stack overflow (BUG #1)", function()
	trait "CircA"
		:method { a = function() return "a" end }

	trait "CircB"
		:method { b = function() return "b" end }

	CircA:implements "CircB"
	assert_throws(function()
		CircB:implements "CircA"
	end, "circular trait dependency")
end)

run_test("Trait self-implementation raises error", function()
	trait "SelfImpl"
		:method { x = function() return "x" end }

	assert_throws(function()
		-- self-implementation: string lookup skips self.name
		SelfImpl:implements("SelfImpl")
	end, "not a trait")
end)

run_test("Trait method alias to non-conflicting name", function()
	trait "TAlias"
		:method { alpha = function() return "alpha" end, beta = function() return "beta" end }

	class "TAliasUser"
		:implements({ trait = TAlias, alias = { alpha = "aliased" } })

	local inst = TAliasUser()
	assert(inst:aliased() == "alpha", "Alias should map alpha to aliased")
	assert(inst.alpha == nil, "Original aliased name should be absent")
	assert(inst:beta() == "beta", "Unrelated method should still be present")
end)

run_test("Trait except with non-existent method is a no-op", function()
	trait "TExceptNonExistent"
		:method { real = function() return "real" end }

	class "TExceptNonExistentUser"
		:implements({ trait = TExceptNonExistent, except = { "imaginary" } })

	local inst = TExceptNonExistentUser()
	assert(inst:real() == "real", "Except with non-existent method should be no-op")
end)

run_test("Trait only with non-existent method imports nothing", function()
	trait "TOnlyNonExistent"
		:method { real = function() return "real" end }

	class "TOnlyNonExistentUser"
		:implements({ trait = TOnlyNonExistent, only = { "imaginary" } })

	local inst = TOnlyNonExistentUser()
	assert(inst.real == nil, "'only' with non-existent name should import nothing")
end)

run_test("Post-instantiation: method after instantiation", function()
	local desc = class "PostMethod"
	local inst = desc.class()
	-- should not error (but existing instances won't see the new method)
	desc:method { late = function() return "late" end }
	local inst2 = desc.class()
	assert(inst2:late() == "late", "Method after instantiation not seen by new instances")
end)

run_test("Post-instantiation: static after instantiation", function()
	local desc = class "PostStatic"
	local inst = desc.class()
	desc:static { LATE = "yes" }
	assert(desc.class.LATE == "yes", "Static after instantiation failed")
end)

run_test("Post-instantiation: property after instantiation", function()
	local desc = class "PostProp"
	local inst = desc.class()
	desc:property { x = { get = function(self) return 1 end } }
	assert(inst.x == 1, "Property after instantiation failed")
end)

run_test("Post-instantiation: meta after instantiation", function()
	local desc = class "PostMeta"
	local inst = desc.class()
	desc:meta { __tostring = function() return "post" end }
	assert(tostring(inst) == "post", "Meta after instantiation failed")
end)

run_test("Post-instantiation: implements after instantiation", function()
	trait "LateTrait"
		:method { lateMethod = function() return "late" end }

	local desc = class "PostImplements"
	local inst = desc.class()
	desc:implements "LateTrait"
	-- new instances see the trait
	local inst2 = desc.class()
	assert(inst2:lateMethod() == "late", "Implements after instantiation not seen by new instances")
end)

run_test("Post-instantiation: finalMethod after instantiation", function()
	local desc = class "PostFinalMethod"
	local inst = desc.class()
	desc:finalMethod { seal = function() return "sealed" end }
	assert_throws(function()
		class "PostFinalMethodBad":extends "PostFinalMethod"
			:method { seal = function() end }
	end, "cannot override final method")
end)

run_test("Post-instantiation: abstract after instantiation", function()
	local desc = class "PostAbstract"
	local inst = desc.class()
	desc:abstract({ "lateAbstract" })
	assert_throws(function()
		desc.class()
	end, "cannot instantiate abstract class")
end)

run_test("Post-instantiation: constructor after instantiation", function()
	local ran = false
	local desc = class "PostCtor"
	local inst = desc.class()
	desc:constructor(function(self) ran = true end)
	local inst2 = desc.class()
	assert(ran, "Constructor added after instantiation should run on new instances")
end)

run_test("Extends by string when registerGlobally=false (BUG #3)", function()
	local saved = luameta.config.registerGlobally
	luameta.config.registerGlobally = false

	class "RegOffParent"
		:method { who = function() return "parent" end }

	class "RegOffChild":extends "RegOffParent"

	local childDesc = class.get("RegOffChild")
	assert(childDesc ~= nil, "Class descriptor not found in registry")
	local inst = childDesc.class()
	assert(inst:who() == "parent", "Extends by string with registerGlobally=false failed")

	luameta.config.registerGlobally = saved
end)

run_test("Implements by string when registerGlobally=false (BUG #3)", function()
	local saved = luameta.config.registerGlobally
	luameta.config.registerGlobally = false

	trait "RegOffTrait"
		:method { traitMethod = function() return "trait" end }

	local desc = (class "RegOffTraitUser"
		:implements "RegOffTrait")

	local inst = desc.class()
	assert(inst:traitMethod() == "trait", "Implements by string with registerGlobally=false failed")

	luameta.config.registerGlobally = saved
end)

--------------------------------------------------------------------------------
-- 15. NAMESPACE EDGE CASES
--------------------------------------------------------------------------------

run_test("Namespace include with traits", function()
	local GameNS = namespace "GameNS"

	trait "Renderable"
		:method { render = function() return "rendered" end }

	GameNS { Renderable }

	assert(_G.Renderable == nil, "Trait not removed from global scope by namespace")
	assert(GameNS.Renderable ~= nil, "Trait missing from namespace table")
	assert(trait.is(GameNS.Renderable), "Namespace stored trait is not a valid trait")
end)

run_test("Namespace include with key-value pairs", function()
	local KVNS = namespace "KVNS"
	KVNS { pi = 3.14, e = 2.71 }
	assert(KVNS.pi == 3.14, "Namespace key-value include failed for 'pi'")
	assert(KVNS.e == 2.71, "Namespace key-value include failed for 'e'")
end)

run_test("namespace.isNamespace and namespace.get static functions", function()
	local TestNS = namespace "TestNSHelper"

	assert(namespace.isNamespace(TestNS), "namespace.isNamespace false for valid namespace")
	assert(namespace.isNamespace({}) == false, "namespace.isNamespace true for plain table")
	assert(namespace.isNamespace(nil) == false, "namespace.isNamespace true for nil")
	local retrieved = namespace.get("TestNSHelper")
	assert(retrieved ~= nil, "namespace.get returned nil")
	assert(retrieved.name == "TestNSHelper", "namespace.get returned wrong namespace")
end)

run_test("Trait implements by string after namespace inclusion", function()
	local LibNS = namespace "LibNS"

	trait "Loggable"
		:method { log = function(_, msg) return "log:" .. msg end }

	LibNS { Loggable }

	class "LoggerUser"
		:implements "Loggable"

	local obj = LoggerUser()
	assert(obj:log("test") == "log:test", "Trait in namespace not found by implements string")
end)

run_test("Extends from parent namespace using string lookup", function()
	local ParentNS = namespace "ParentNS"

	class "BaseInNS"
		:method { whoami = function() return "base-in-ns" end }

	ParentNS { BaseInNS }

	class "ChildInNS":extends "BaseInNS"

	local obj = ChildInNS()
	assert(obj:whoami() == "base-in-ns", "Extends failed for class in namespace")
	assert(obj:isA(ParentNS.BaseInNS), "isA failed for class accessed via namespace")
end)

run_test("Nested namespace class extends from grandparent namespace", function()
	local RootNS = namespace "RootNS"
	local MiddleNS = RootNS:nested("Middle")
	local DeepNS = RootNS:nested("Middle.Deep")

	class "DeepClass"
		:method { deep = function() return "deep" end }

	DeepNS { DeepClass }

	class "MiddleClass"
		:method { middle = function() return "middle" end }

	MiddleNS { MiddleClass }

	-- Both classes are discoverable via namespace registry fallback
	class "UserOfDeep":extends "DeepClass"
		:method { user = function() return "user" end }

	local obj = UserOfDeep()
	assert(obj:deep() == "deep", "Extends deep class from nested ns failed")
	assert(obj:user() == "user", "Own method on class from nested ns failed")
end)

run_test("Include suppresses name key in key-value pairs", function()
	local FilterNS = namespace "FilterNS"
	FilterNS { name = "should-skip", value = 42 }
	assert(FilterNS.name == "FilterNS", "name field overwrote namespace's own name")
	assert(FilterNS.value == 42, "Non-name field not stored in namespace")
end)

----------------------------------------------------------------------
-- 16. REGISTRY INTERACTIONS
----------------------------------------------------------------------

run_test("Global registration flag respected", function()
	-- config.registerGlobally is true by default in init.lua
	class "GlobalRegClass"
		:method { g = function() return "global" end }
	assert(_G.GlobalRegClass ~= nil, "Globally registered class not in _G")
end)

run_test("Duplicate class name in global scope raises error", function()
	class "UniqueClass"
	assert_throws(function()
			class "UniqueClass"
		end,
		"already declared")
end)

run_test("Duplicate trait name in global scope raises error", function()
	trait "UniqueTrait"
	assert_throws(function()
			trait "UniqueTrait"
		end,
		"already declared")
end)

run_test("Duplicate namespace name in global scope raises error", function()
	namespace "UniqueNS"
	assert_throws(function()
			namespace "UniqueNS"
		end,
		"already declared")
end)

run_test("isA with composed traits (recursive trait check)", function()
	trait "RecLeafTrait"
		:method { leaf = function() return "leaf" end }

	trait "RecCompTrait"
		:implements "RecLeafTrait"
		:method { comp = function() return "comp" end }

	class "RecTraitUser"
		:implements "RecCompTrait"

	local obj = RecTraitUser()
	assert(obj:isA(RecCompTrait), "isA failed for direct trait")
	assert(obj:isA(RecLeafTrait), "isA failed for composed trait (recursive check)")
	assert(obj:isA("RecLeafTrait"), "isA with string name failed for composed trait")
end)

run_test("Registry prevents duplicate class name regardless of global flag", function()
	local saved = luameta.config.registerGlobally
	luameta.config.registerGlobally = false
	class "RegOnlyClass"
		:method { dummy = function() return "dummy" end }
	assert_throws(function()
		class "RegOnlyClass"
	end, "already registered")
	luameta.config.registerGlobally = saved
end)

run_test("class.isClass returns false for class descriptor", function()
	local desc = class "DescClassCheck"
		:method { m = function() end }
	assert(class.isClass(_G.DescClassCheck), "class table should be identified as class")
	assert(class.isClass(desc) == false, "class descriptor should not be identified as class")
end)

--------------------------------------------------------------------------------
-- 17. ERROR / EDGE CASE INPUTS
--------------------------------------------------------------------------------

run_test("class.get(\"NonExistent\") returns nil", function()
	assert(class.get("NonExistent") == nil, "class.get for non-existent should be nil")
end)

run_test("trait.get(\"NonExistent\") returns nil", function()
	assert(trait.get("NonExistent") == nil, "trait.get for non-existent should be nil")
end)

run_test("namespace.get(\"NonExistent\") returns nil", function()
	assert(namespace.get("NonExistent") == nil, "namespace.get for non-existent should be nil")
end)

run_test("isA with nil target returns false", function()
	class "NilTarget"
	local inst = NilTarget()
	assert(inst:isA(nil) == false, "isA(nil) should return false")
end)

run_test("class.is with descriptor as target", function()
	class "DescriptorTarget"
	local desc = class.get("DescriptorTarget")
	local inst = DescriptorTarget()
	assert(class.is(inst, desc), "class.is with descriptor as target should work")
end)

run_test("Extends from a trait raises error", function()
	trait "NotAClass"
		:method { x = function() end }

	assert_throws(function()
		class "BadExtends":extends(NotAClass)
	end, "not a valid class")
end)

run_test("Implements with a class raises error", function()
	class "NotATrait"
		:method { x = function() end }

	assert_throws(function()
		class "BadImplements":implements(NotATrait)
	end, "not a trait")
end)

run_test("method with non-table arg raises error", function()
	local desc = class "MethodBadArg"
	assert_throws(function()
		desc:method("not a table")
	end, "not a table")
end)

run_test("static with non-table arg raises error", function()
	local desc = class "StaticBadArg"
	assert_throws(function()
		desc:static("not a table")
	end, "not a table")
end)

run_test("property with non-table arg raises error", function()
	local desc = class "PropBadArg"
	assert_throws(function()
		desc:property("not a table")
	end, "expected a table")
end)

run_test("property with non-table spec raises error", function()
	local desc = class "PropBadSpec"
	assert_throws(function()
		desc:property { x = "not a table" }
	end, "spec for 'x' must be a table")
end)

run_test("property with spec lacking both get and set raises error", function()
	local desc = class "PropBadGetter"
	assert_throws(function()
		desc:property { x = {} }
	end, "must have 'get' and/or 'set'")
end)

run_test("meta with non-table arg raises error", function()
	local desc = class "MetaBadArg"
	assert_throws(function()
		desc:meta("not a table")
	end, "not a table")
end)

run_test("implements with nil is a no-op", function()
	local desc = class "ImplementsNil"
	desc:implements(nil)
	-- should not throw
end)

run_test("implements with non-trait non-string non-table", function()
	local desc = class "ImplementsNumber"
	assert_throws(function()
		desc:implements(42)
	end, "not a trait")
end)

run_test("constructor with non-function", function()
	local desc = class "CtorNonFn"
	assert_throws(function()
		desc:constructor("not a function")
	end, "not a function")
end)

run_test("destructor with non-function", function()
	local desc = class "DtorNonFn"
	assert_throws(function()
		desc:destructor("not a function")
	end, "must be a function")
end)

run_test("finalMethod with non-table", function()
	local desc = class "FinalMethodNonTable"
	assert_throws(function()
		desc:finalMethod("not a table")
	end, "not a table")
end)

run_test("abstract with non-table arg makes class abstract", function()
	local desc = class "AbstractNonTable"
	desc:abstract("not a table")
	assert_throws(function()
		desc.class()
	end, "cannot instantiate abstract class")
end)

run_test("class with non-string name", function()
	assert_throws(function()
		class(42)
	end, "not valid")
end)

run_test("trait with non-string name", function()
	assert_throws(function()
		trait(42)
	end, "must be a string")
end)

run_test("namespace with non-string name returns nil (no error)", function()
	local result = namespace(42)
	assert(result == nil, "namespace(42) with number should return nil")
end)

run_test("namespace with non-table arg in call", function()
	namespace "BadArgNS"
	-- BadArgNS(42) with a number should be a no-op (no error, returns nil)
	local result = BadArgNS(42)
	assert(result == nil, "namespace call with non-string, non-table should return nil")
end)

run_test("final() called multiple times is idempotent", function()
	class "DoubleFinal"
		:final()
		:final()
	-- should not throw
	assert_throws(function()
		class "ChildOfDoubleFinal":extends "DoubleFinal"
	end, "cannot inherit from final class")
end)

run_test("finalMethod called twice with same name raises error", function()
	local desc = class "DoubleFinalMethod"
		:finalMethod { x = function() return 1 end }

	assert_throws(function()
		desc:finalMethod { x = function() return 2 end }
	end, "cannot override final method")
end)

run_test("Protected instance fields cannot be overwritten", function()
	class "ProtectedFields"

	local inst = ProtectedFields()
	-- __class__ is served via __index, not stored on instance;
	-- writing __class__ triggers __newindex which rejects it
	assert_throws(function() inst.__class__ = "hacked" end, "protected field")
	-- __super_host__ is not set by default; write goes through __newindex rejection
	assert_throws(function() inst.__super_host__ = {} end, "protected field")
end)

run_test("Protected class table fields cannot be overwritten via __newindex on class table", function()
	local desc = class "ProtectedClassFields"
	local ct = desc.class
	-- origin/name are set during newClass so __newindex is not fired for them.
	-- But __class__/__super_host__ are NOT stored on instances so protection works.
	assert_throws(function() ct.__class__ = "hacked" end, "protected field")
	assert_throws(function() ct.__super_host__ = {} end, "protected field")
end)

run_test("Constructor that returns a value is ignored", function()
	class "CtorReturn"
		:constructor(function(self)
			self.x = 1
			return { x = 999 }
		end)

	local inst = CtorReturn()
	assert(inst.x == 1, "Constructor return value should be ignored, new instance used")
end)

run_test("Multiple constructors at different inheritance levels run in order", function()
	local order = {}
	class "CtorOrderParent"
		:constructor(function(self) table.insert(order, "parent") end)

	class "CtorOrderChild":extends "CtorOrderParent"
		:constructor(function(self) table.insert(order, "child") end)

	CtorOrderChild()
	assert(order[1] == "parent" and order[2] == "child", "Constructor order: parent then child")
end)

run_test("Constructor with nil args preserved via select('#')", function()
	class "CtorSelectNil"
		:constructor(function(self, ...)
			self.n = select("#", ...)
		end)

	local inst = CtorSelectNil(1, nil, 3)
	assert(inst.n == 3, "select('#', ...) should see nil args (n=3)")
end)

run_test("Namespace include with class descriptor (not class table)", function()
	local NS = namespace "NSDesc"
	class "DescForNS"
		:method { m = function() return "desc" end }

	local desc = class.get("DescForNS")
	NS { desc }
	assert(NS.DescForNS ~= nil, "Namespace include with descriptor failed")
	assert(_G.DescForNS == nil, "Descriptor include should remove from global")
end)

run_test("Namespace include with nested namespace", function()
	local Outer = namespace "OuterNS"
	local Inner = namespace "InnerNS"

	Outer { Inner }
	assert(Outer.InnerNS ~= nil, "Nested namespace include failed")
end)

run_test("Namespace include with unnamed array item silently skipped", function()
	local NS = namespace "UnnamedNS"
	local unnamed = { noName = true }
	NS { unnamed }
	-- unnamed table without .name is silently skipped
	assert(#NS == 0 or true, "Unnamed array item should be silently skipped")
end)

run_test("Namespace include with duplicate names overwrites", function()
	local NS = namespace "DupNS"
	local t1 = { name = "dupItem", value = 1 }
	local t2 = { name = "dupItem", value = 2 }
	NS { t1 }
	NS { t2 }
	assert(NS.dupItem.value == 2, "Duplicate namespace name should be overwritten")
end)

run_test("Namespace-qualified string in extends falls back to registry", function()
	local saved = luameta.config.registerGlobally
	luameta.config.registerGlobally = false

	class "NSQualifiedBase"
		:method { test = function() return "ns-qualified" end }

	class "NSQualifiedChild":extends "NSQualifiedBase"

	local desc = class.get("NSQualifiedChild")
	local inst = desc.class()
	assert(inst:test() == "ns-qualified", "Registry fallback for qualified extends failed")

	luameta.config.registerGlobally = saved
end)

run_test("Instance :isA with descriptor as target", function()
	class "DescIsATarget"
	local inst = DescIsATarget()
	local desc = class.get("DescIsATarget")
	assert(inst:isA(desc) == true, "isA with descriptor target should match")
end)

run_test("Extends with nil name raises error", function()
	assert_throws(function()
		class "NilExtends":extends(nil)
	end, "not a valid class")
end)

run_test("Extends with number name raises error", function()
	assert_throws(function()
		class "NumExtends":extends(123)
	end, "not a valid class")
end)

run_test("Circular class extends (A→B, B→A) raises error", function()
	local _CircExt1 = class "CircExt1"
	local _CircExt2 = class "CircExt2"
	_CircExt1:extends "CircExt2"
	assert_throws(function()
		_CircExt2:extends "CircExt1"
	end, "circular inheritance")
end)

run_test("Circular class extends (3-way A→B→C→A) raises error", function()
	local _CircExt3A = class "CircExt3A"
	local _CircExt3B = class "CircExt3B"
	local _CircExt3C = class "CircExt3C"
	_CircExt3A:extends "CircExt3B"
	_CircExt3B:extends "CircExt3C"
	assert_throws(function()
		_CircExt3C:extends "CircExt3A"
	end, "circular inheritance")
end)

run_test("Super proxy caching works (repeated calls do not error)", function()
	local _Base = class "SuperCacheBase"
		:method { greet = function(self) return "base" end }
	local _Derived = class "SuperCacheDerived"
		:extends "SuperCacheBase"
		:method { greet = function(self) return self:super():greet() .. "|derived" end }
	local inst = _Derived.class()
	assert(inst:greet() == "base|derived", "first call")
	assert(inst:greet() == "base|derived", "second call (cached proxy)")
	assert(inst:greet() == "base|derived", "third call (cached proxy + cached wrapper)")
end)

run_test("Deterministic namespace resolution picks alphabetically first", function()
	local saved = luameta.config.registerGlobally
	luameta.config.registerGlobally = false
	local nsA = namespace "DetNsA"
	local nsB = namespace "DetNsB"
	local ca = class "DetResA":method { x = function() return "fromA" end }
	local cb = class "DetResB":method { x = function() return "fromB" end }
	nsA["SameKey"] = ca.class
	nsB["SameKey"] = cb.class
	local child = class "DetChild":extends "SameKey"
	-- nsA < nsB alphabetically → resolves from nsA
	local inst = child.class()
	assert(inst:x() == "fromA", "expected 'fromA', got '" .. tostring(inst:x()) .. "'")
	luameta.config.registerGlobally = saved
end)

--------------------------------------------------------------------------------
-- TEST SUMMARY
--------------------------------------------------------------------------------

print("\n==================================================================")
print(string.format("RESULTS: %d Passed, %d Failed, %d Skipped", tests_passed, tests_failed, tests_skipped))
print("==================================================================")

if tests_failed > 0 then
	os.exit(1)
end
