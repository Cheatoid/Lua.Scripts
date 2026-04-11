-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Hello World Plugin - Demonstrates basic plugin framework usage

---@diagnostic disable: inject-field

--- Access the plugin instance passed as first argument
---@type Plugin
---@diagnostic disable-next-line: undefined-global
local plugin = assert(plugin, "plugin instance is invalid")

--- Services injected by the plugin manager
---@type table<string, any>
---@diagnostic disable-next-line: undefined-global
local services = assert(services, "services are not set")

--- Event emitter injected by the plugin manager
---@type fun(event: string, data: any): nil
---@diagnostic disable-next-line: undefined-global
local emit = assert(emit, "emit is not set")

-- Initialize plugin
function plugin:init(manager)
	print("[hello_plugin] Initializing...")
	self.state.count = 0
	self.state.last_event = nil
	print("[hello_plugin] Initialized with manager:", manager)
end

-- Start plugin
function plugin:start()
	print("[hello_plugin] Starting...")
	self.state.count = self.state.count + 1
	print("[hello_plugin] Started! Count:", self.state.count)
end

-- Stop plugin
function plugin:stop()
	print("[hello_plugin] Stopping...")
	print("[hello_plugin] Stopped! Final count:", self.state.count)
end

-- Custom method
function plugin:say_hello(name)
	name = name or "World"
	print("[hello_plugin] Hello, " .. name .. "!")
	self.state.count = self.state.count + 1
	return self.state.count
end

-- Access services (if available)
function plugin:check_services()
	if services then
		print("[hello_plugin] Available services:")
		for name, _ in next, services do
			print("  - " .. name)
		end
	else
		print("[hello_plugin] No services available")
	end
end

-- Emit an event
function plugin:trigger_custom_event()
	if emit then
		emit("hello_plugin:custom", { message = "Custom event triggered!", count = self.state.count })
		print("[hello_plugin] Emitted custom event")
	end
end

-- Register event handler (called from outside)
function plugin:handle_event(event_name, data)
	print("[hello_plugin] Received event:", event_name, data)
	self.state.last_event = { name = event_name, data = data }
end

return plugin
