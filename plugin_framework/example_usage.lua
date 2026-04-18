-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--package.path = "?.lua;" .. package.path

-- Example usage of the plugin framework with hello_plugin
local PluginFramework = require "plugin_framework"
local PluginManager = PluginFramework.PluginManager
local Plugin = PluginFramework.Plugin

-- Create a plugin manager instance
local manager = PluginManager.new({
	debug = true -- Enable debug mode for error messages
})

-- Register a service (dependency injection)
manager:register_service("logger", {
	log = function(msg) print("[LOGGER]", msg) end,
	info = function(msg) print("[LOGGER] INFO:", msg) end,
})

-- Load hello_plugin from file
local hello_plugin_code = [[
-- plugin is available in the environment (set by load_plugin_from_string)
function plugin:init(manager)
	print("[hello_plugin] Initializing...")
	self.state.count = 0
	self.state.last_event = nil
	print("[hello_plugin] Initialized with manager")
end

function plugin:start()
	print("[hello_plugin] Starting...")
	self.state.count = self.state.count + 1
	print("[hello_plugin] Started! Count:", self.state.count)
end

function plugin:stop()
	print("[hello_plugin] Stopping...")
	print("[hello_plugin] Stopped! Final count:", self.state.count)
end

function plugin:say_hello(name)
	name = name or "World"
	print("[hello_plugin] Hello, " .. name .. "!")
	self.state.count = self.state.count + 1
	return self.state.count
end

function plugin:check_services()
	if services then
		print("[hello_plugin] Available services:")
		for name, _ in pairs(services) do
			print("  - " .. name)
		end
	else
		print("[hello_plugin] No services available")
	end
end

function plugin:trigger_custom_event()
	if emit then
		emit("hello_plugin:custom", { message = "Custom event triggered!", count = self.state.count })
		print("[hello_plugin] Emitted custom event")
	end
end

return plugin
]]

-- Load the plugin from string
print("\n=== Loading hello_plugin from string ===")
local plugin1 = manager:loadstring("hello_plugin", hello_plugin_code)

-- Create another plugin using the Plugin factory
print("\n=== Creating plugin using Plugin factory ===")
local plugin2 = Plugin("counter_plugin")
	:with_config({ max_count = 10 })
	:with_init(function(self, manager)
		print("[counter_plugin] Initializing...")
		self.state.count = 0
	end)
	:with_start(function(self)
		print("[counter_plugin] Starting...")
		self.state.count = 0
	end)
	:with_stop(function(self)
		print("[counter_plugin] Stopping...")
		print("[counter_plugin] Final count:", self.state.count)
	end)

manager:register(plugin2)

-- Create a third plugin that depends on hello_plugin
print("\n=== Creating plugin with dependencies ===")
local plugin3 = Plugin("dependent_plugin")
	:depends_on("hello_plugin")
	:with_init(function(self, manager)
		print("[dependent_plugin] Initializing...")
		print("[dependent_plugin] Dependency 'hello_plugin' should already be initialized")
		local hello = manager:get_plugin("hello_plugin")
		if hello then
			print("[dependent_plugin] Found hello_plugin, count:", hello.state.count)
		end
	end)
	:with_start(function(self)
		print("[dependent_plugin] Starting...")
		print("[dependent_plugin] Dependency 'hello_plugin' should already be started")
	end)
	:with_stop(function(self)
		print("[dependent_plugin] Stopping...")
	end)

manager:register(plugin3)

-- Load a plugin from a string (using function-style approach)
print("\n=== Loading plugin from function ===")
local plugin4 = manager:loadstring("function_plugin", [[
local plugin = ...
print("[function_plugin] Loaded from string!")
function plugin:greet(name)
	name = name or "World"
	print("[function_plugin] Greetings, " .. name .. "!")
end
return plugin
]])

plugin4:greet("Lua")

-- Test event system
print("\n=== Testing event system ===")
manager:on("hello_plugin:custom", function(data)
	print("[EVENT HANDLER] Received custom event:", data.message, "Count:", data.count)
end)

-- Trigger event again
plugin1:trigger_custom_event()

-- List all plugins
print("\n=== Listing all plugins ===")
local plugins = manager:list_plugins()
for i, name in next, plugins do
	print(i .. ". " .. name)
end

-- Initialize all plugins
print("\n=== Initializing all plugins ===")
manager:init_all()

-- Start all plugins
print("\n=== Starting all plugins ===")
manager:start_all()

-- Test plugin methods (after init so state is ready)
print("\n=== Testing plugin methods ===")
plugin1:say_hello("Lua")
plugin1:check_services()
plugin1:trigger_custom_event()

-- Stop all plugins
print("\n=== Stopping all plugins ===")
manager:stop_all()

print("\n=== Example complete ===")
