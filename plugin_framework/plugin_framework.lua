-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple plugin framework.

-- Localized global functions for better performance
local assert, type, next, setmetatable, pcall = assert, type, next, setmetatable, pcall
local table_remove = table.remove

-- Import dependencies
local compat = require "compat"

--- PluginManager class for managing plugins, services, and events.
---@class PluginManager
---@field plugins table<string, Plugin> Table of registered plugins.
---@field services table<string, any> Registry of available services.
---@field events table<string, function[]> Table of event handlers.
---@field opts table Configuration options for the plugin manager.
local PluginManager = {}
PluginManager.__index = PluginManager

--- Create a new PluginManager instance.
---@param opts table|nil Optional configuration table.
---@return PluginManager obj New PluginManager instance.
function PluginManager.new(opts) -- TODO/CONS: dual call?
	return setmetatable({
		plugins = {},
		services = {},
		events = {},
		opts = opts or {},
	}, PluginManager)
end

----------------------------------------------------------------------
--- Service locator (simple DI)
----------------------------------------------------------------------

---@param name string Service name.
---@param svc any Service object.
---@return PluginManager obj Self.
function PluginManager:register_service(name, svc)
	assert(type(name) == "string", "service name must be string")
	assert(type(svc) == "table", "service must be table")
	self.services[name] = svc
	return self
end

--- Get a registered service.
---@param name string Service name.
---@return any service Service object.
function PluginManager:get_service(name)
	return self.services[name]
end

--- Check if a service is registered.
---@param name string Service name.
---@return boolean registered Whether the service is registered.
function PluginManager:has_service(name)
	return self.services[name] ~= nil
end

----------------------------------------------------------------------
-- EventBus
----------------------------------------------------------------------

--- Register an event handler.
---@param event string Event name.
---@param handler function Event handler.
---@return PluginManager obj Self.
function PluginManager:on(event, handler)
	assert(type(event) == "string", "event name must be string")
	assert(type(handler) == "function", "handler must be function")
	local ev = self.events[event] or {}
	ev[#ev + 1] = handler
	self.events[event] = ev
	return self
end

--- Unregister an event handler.
---@param event string Event name.
---@param handler function Event handler.
---@return PluginManager obj Self.
function PluginManager:off(event, handler)
	local ev = self.events[event]
	if not ev then return self end

	for i = #ev, 1, -1 do -- important: reverse iteration due to table.remove
		if ev[i] == handler then
			table_remove(ev, i)
		end
	end

	if #ev == 0 then
		self.events[event] = nil
	end
	return self
end

--- Emit an event.
---@param event string Event name.
---@param ... any Arguments to pass to event handlers.
function PluginManager:emit(event, ...)
	local ev = self.events[event]
	if not ev then return end

	local i = 1
	while i <= #ev do
		local handler = ev[i]
		if handler then
			local ok, err = pcall(handler, ...)
			if not ok and self.opts.debug then
				print("error in event handler for", event, ":", err)
			end
			i = i + 1
		else
			table_remove(ev, i)
		end
	end
end

----------------------------------------------------------------------
-- Plugin lifecycle
----------------------------------------------------------------------

--- Register a plugin.
---@param plugin table Plugin object.
---@return PluginManager obj Self.
function PluginManager:register(plugin)
	assert(type(plugin) == "table" and plugin.name, "invalid plugin")
	if self.plugins[plugin.name] then
		return error("plugin '" .. plugin.name .. "' already registered")
	end
	self.plugins[plugin.name] = plugin
	plugin.manager = self
	return self
end

function PluginManager:unregister(name)
	local plugin = self.plugins[name]
	if plugin and plugin.stop then
		plugin:stop()
	end
	self.plugins[name] = nil
	return self
end

function PluginManager:get_plugin(name)
	return self.plugins[name]
end

function PluginManager:has_plugin(name)
	return self.plugins[name] ~= nil
end

function PluginManager:list_plugins()
	local names = {}
	for name, _ in next, self.plugins do
		names[#names + 1] = name
	end
	return names
end

function PluginManager:cleanup_dead_plugins()
	local cleaned = 0
	for name, plugin in next, self.plugins do
		if not plugin or not plugin.name then
			self.plugins[name] = nil
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

function PluginManager:init_all()
	local plugins = self.plugins
	for name, p in next, plugins do
		if p and p.init then
			local ok, err = pcall(p.init, p, self)
			if not ok then
				print("error initializing plugin '" .. name .. "':", err)
			end
		end
	end
end

function PluginManager:start_all()
	local plugins = self.plugins
	for name, p in next, plugins do
		if p and p.start then
			local ok, err = pcall(p.start, p)
			if not ok then
				print("error starting plugin '" .. name .. "':", err)
			end
		end
	end
end

function PluginManager:stop_all()
	local plugins = self.plugins
	for name, p in next, plugins do
		if p and p.stop then
			local ok, err = pcall(p.stop, p)
			if not ok then
				print("error stopping plugin '" .. name .. "':", err)
			end
		end
	end
end

----------------------------------------------------------------------
-- Dynamic plugin loading
----------------------------------------------------------------------

function PluginManager:load_plugin_from_string(name, code, opts)
	assert(type(name) == "string", "plugin name must be string")
	assert(type(code) == "string", "plugin code must be string")

	if self.plugins[name] then
		return error("plugin '" .. name .. "' already exists")
	end

	local plugin = {
		name = name,
		manager = self,
		state = opts and opts.state or {},
		config = opts and opts.config or {}
	}

	local env = setmetatable({
		plugin = plugin,
		services = self.services,
		emit = function(...) self:emit(...) end,
		print = print,
		require = require,
	}, { __index = _G })

	local f, err = compat.load(code, name, "t", env)
	assert(f, err)

	local ok, res = pcall(f, plugin)
	assert(ok, res)

	self.plugins[name] = plugin
	return plugin
end

function PluginManager:hot_reload(name, code)
	local p = self.plugins[name]
	if p and p.stop then
		local ok, err = pcall(p.stop, p)
		if not ok and self.opts.debug then
			print("error stopping plugin for reload:", err)
		end
	end

	local new = self:load_plugin_from_string(name, code)
	if new.init then
		local ok, err = pcall(new.init, new, self)
		if not ok then
			print("error initializing reloaded plugin:", err)
		end
	end

	if new.start then
		local ok, err = pcall(new.start, new)
		if not ok then
			print("error starting reloaded plugin:", err)
		end
	end

	return new
end

--- Plugin class for creating plugin instances
---@class Plugin
---@field name string Plugin name
---@field state table Plugin state storage
---@field config table Plugin configuration
---@field enabled boolean Whether the plugin is enabled
---@field deps string[]|nil Plugin dependencies
---@field manager PluginManager|nil Reference to the plugin manager
---@field init function|nil Plugin initialization function
---@field start function|nil Plugin start function
---@field stop function|nil Plugin stop function

--- Create a new Plugin instance.
---@param name string Plugin name.
---@return Plugin obj New plugin instance.
local function Plugin(name)
	---@type Plugin
	local self = {
		name = name,
		state = {},
		config = {},
		enabled = true,
	}

	function self:depends_on(...)
		self.deps = { ... }
		return self
	end

	function self:with_init(f)
		self.init = f
		return self
	end

	function self:with_start(f)
		self.start = f
		return self
	end

	function self:with_stop(f)
		self.stop = f
		return self
	end

	function self:with_config(cfg)
		self.config = cfg
		return self
	end

	function self:enable()
		self.enabled = true
		return self
	end

	function self:disable()
		self.enabled = false
		return self
	end

	return self
end

--- Export module with PluginManager and Plugin.
---@class PluginFramework
---@field PluginManager PluginManager Plugin manager class.
---@field Plugin function Plugin factory function.
return {
	PluginManager = PluginManager,
	Plugin = Plugin,
}
