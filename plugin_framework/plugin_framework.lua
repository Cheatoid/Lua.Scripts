-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple plugin framework

-- Localized global functions for better performance
local assert, error, type, next, setmetatable, pcall = assert, error, type, next, setmetatable, pcall
local table_concat, table_remove = table.concat, table.remove

-- Import dependencies
local compat = require "compat"
local compat_load = compat.load

--- PluginManager class for managing plugins, services, and events.
---@class PluginManager
---@field plugins table<string, Plugin> Table of registered plugins.
---@field services table<string, any> Registry of available services.
---@field events table<string, function[]> Table of event handlers.
---@field opts table Configuration options for the plugin manager.
local PluginManager = {}
PluginManager.__index = PluginManager

--- Create a new PluginManager instance.<br>
--- Initializes an empty plugin registry, service registry, and event bus for managing plugins.
---@param opts? table Optional configuration table (e.g. { debug = true } for error messages).
---@return PluginManager manager New PluginManager instance.
---@usage <br>
--- ```
--- local manager = PluginManager.new({ debug = true })
--- ```
function PluginManager.new(opts)
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

--- Register a service in the service registry.<br>
--- Services are available to all plugins via the services table in their environment.<br>
--- Services support dependency injection patterns for plugins.
---@param name string Service name (must be a string).
---@param svc table Service object (must be a table).
---@return PluginManager self Self for method chaining.
---@usage <br>
--- ```
--- manager:register_service("logger", { log = function(msg) print(msg) end })
--- ```
function PluginManager:register_service(name, svc)
	assert(type(name) == "string", "service name must be string")
	assert(type(svc) == "table", "service must be table")
	self.services[name] = svc
	return self
end

--- Get a registered service by name.<br>
--- Returns the service object if it exists, otherwise returns nil.<br>
--- Plugins can access services through the services table in their environment.
---@param name string Service name to retrieve.
---@return table? service Service object, or nil if not found.
---@usage <br>
--- ```
--- local logger = manager:get_service("logger")
--- if logger then logger.log("Hello") end
--- ```
function PluginManager:get_service(name)
	return self.services[name]
end

--- Check if a service is registered.<br>
--- Returns true if the service exists in the registry.
---@param name string Service name to check.
---@return boolean registered True if the service is registered.
---@usage <br>
--- ```
--- if manager:has_service("logger") then
---   print("Logger service is available")
--- end
--- ```
function PluginManager:has_service(name)
	return self.services[name] ~= nil
end

----------------------------------------------------------------------
-- EventBus
----------------------------------------------------------------------

--- Register an event handler for a specific event.<br>
--- Multiple handlers can be registered for the same event; they will be called in order.<br>
--- Handlers receive all arguments passed to the emit call.
---@param event string Event name to listen for (must be a string).
---@param handler function Event handler function (must be a function).
---@return PluginManager self Self for method chaining.
---@usage <br>
--- ```
--- manager:on("player:join", function(player)
---   print("Player joined:", player.name)
--- end)
--- ```
function PluginManager:on(event, handler)
	assert(type(event) == "string", "event name must be string")
	assert(type(handler) == "function", "handler must be function")
	local ev = self.events[event] or {}
	ev[#ev + 1] = handler
	self.events[event] = ev
	return self
end

--- Unregister an event handler for a specific event.<br>
--- Removes the specified handler from the event's handler list.<br>
--- If the event has no handlers left, the event is removed from the registry.
---@param event string Event name to remove handler from.
---@param handler function Event handler function to remove.
---@return PluginManager self Self for method chaining.
---@usage <br>
--- ```
--- local handler = function(msg) print(msg) end
--- manager:on("log", handler)
--- manager:off("log", handler)
--- ```
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

--- Emit an event to all registered handlers.<br>
--- Calls all handlers registered for the event with the provided arguments.<br>
--- Errors in handlers are caught and printed if debug mode is enabled.
---@param event string Event name to emit.
---@param ... any Arguments to pass to event handlers.
---@usage <br>
--- ```
--- manager:emit("player:join", { name = "John", id = 123 })
--- ```
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

--- Register a plugin with the manager.<br>
--- Adds the plugin to the registry and sets up a weak reference to the manager.<br>
--- Validates plugin structure and dependencies. Throws error if plugin is invalid or already registered.
---@param plugin table Plugin object (must have name field).
---@return PluginManager self Self for method chaining.
---@usage <br>
--- ```
--- local plugin = Plugin("myplugin"):with_init(function(self, manager) ... end)
--- manager:register(plugin)
--- ```
function PluginManager:register(plugin)
	assert(type(plugin) == "table" and type(plugin.name) == "string", "invalid plugin")
	assert(plugin.manager == nil, "plugin '" .. plugin.name .. "' is already managed")
	assert(not self.plugins[plugin.name], "plugin '" .. plugin.name .. "' is already registered")

	-- Validate dependencies
	if plugin.deps then
		for _, dep_name in next, plugin.deps do
			if type(dep_name) ~= "string" then
				return error("dependency name must be a string, got " .. type(dep_name), 2)
			end
		end
	end

	self.plugins[plugin.name] = plugin
	plugin.manager = setmetatable({ self }, { __mode = "v" }) -- weakref
	return self
end

--- Unregister a plugin by name.<br>
--- Stops the plugin if it has a stop method, then removes it from the registry.<br>
--- Errors during stop are caught and printed but don't prevent unregistration.
---@param name string Plugin name to unregister.
---@return PluginManager self Self for method chaining.
---@usage <br>
--- ```
--- manager:unregister("myplugin")
--- ```
function PluginManager:unregister(name)
	local plugin = self.plugins[name]
	if plugin and plugin.stop then
		pcall(plugin.stop, plugin)
	end
	self.plugins[name] = nil
	return self
end

--- Get a registered plugin by name.<br>
--- Returns the plugin object if it exists, otherwise returns nil.
---@param name string Plugin name to retrieve.
---@return table? plugin Plugin object, or nil if not found.
---@usage <br>
--- ```
--- local plugin = manager:get_plugin("myplugin")
--- if plugin then print(plugin.name) end
--- ```
function PluginManager:get_plugin(name)
	return self.plugins[name]
end

--- Check if a plugin is registered.<br>
--- Returns true if the plugin exists in the registry.
---@param name string Plugin name to check.
---@return boolean registered True if the plugin is registered.
---@usage <br>
--- ```
--- if manager:has_plugin("myplugin") then
---   print("Plugin is loaded")
--- end
--- ```
function PluginManager:has_plugin(name)
	return self.plugins[name] ~= nil
end

--- List all registered plugin names.<br>
--- Returns an array of all plugin names currently in the registry.
---@return string[] names Array of plugin names.
---@usage <br>
--- ```
--- local plugins = manager:list_plugins()
--- for i, name in next, plugins do
---   print(i .. ". " .. name)
--- end
--- ```
function PluginManager:list_plugins()
	local names = {}
	for name, _ in next, self.plugins do
		names[#names + 1] = name
	end
	return names
end

--- Remove dead/invalid plugins from the registry.<br>
--- Cleans up plugins that are nil, missing required fields, or have been garbage collected (weak manager reference is nil).
---@return integer number Number of plugins that were removed.
---@usage <br>
--- ```
--- local cleaned = manager:cleanup_dead_plugins()
--- print("Cleaned up " .. cleaned .. " dead plugins")
--- ```
function PluginManager:cleanup_dead_plugins()
	local cleaned = 0
	for name, plugin in next, self.plugins do
		if not plugin
			or not plugin.name
			or not plugin.manager
			or not plugin.manager[1] then
			self.plugins[name] = nil
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

--- Helper to call lifecycle method with _PLUGIN global set and restored
local function call_lifecycle(plugin, method, manager, is_init)
	local prev_plugin = _G._PLUGIN
	_G._PLUGIN = plugin
	local ok, err
	if is_init then
		ok, err = pcall(method, plugin, manager)
	else
		ok, err = pcall(method, plugin)
	end
	_G._PLUGIN = prev_plugin
	return ok, err
end

--- Module-level helper: resolve dependencies with topological sort<br>
--- Topological sort: dependencies before dependencies
local function resolve_deps_helper(plugins, processed, visited, path, name, manager, lifecycle_method, lifecycle_name)
	if processed[name] then return true end
	if visited[name] then
		-- Cyclic dependency detected
		local cycle = table_concat(path, " -> ") .. " -> " .. name
		return error("cyclic dependency detected: " .. cycle, 2)
	end

	visited[name] = true
	path[#path + 1] = name

	local p = plugins[name]
	if not p then
		path[#path] = nil
		visited[name] = false
		return true
	end

	-- Resolve dependencies first
	if p.deps then
		for _, dep_name in next, p.deps do
			if not resolve_deps_helper(plugins, processed, visited, path, dep_name, manager, lifecycle_method, lifecycle_name) then
				path[#path] = nil
				visited[name] = false
				return false
			end
			-- Ensure dependency is processed
			if not processed[dep_name] then
				local dep = plugins[dep_name]
				if dep and dep[lifecycle_method] then
					local ok, err = call_lifecycle(dep, dep[lifecycle_method], manager, lifecycle_name == "init")
					if not ok then
						print(
							"error " .. lifecycle_name .. "ing dependency '" .. dep_name .. "' for '" .. name .. "':",
							err
						)
						path[#path] = nil
						visited[name] = false
						return false
					end
					processed[dep_name] = true
				end
				processed[dep_name] = true
			end
		end
	end

	-- Process this plugin
	if p[lifecycle_method] and not processed[name] then
		local ok, err = call_lifecycle(p, p[lifecycle_method], manager, lifecycle_name == "init")
		if not ok then
			print("error " .. lifecycle_name .. "ing plugin '" .. name .. "':", err)
			path[#path] = nil
			visited[name] = false
			return false
		end
		processed[name] = true
	end

	path[#path] = nil
	visited[name] = false
	return true
end

--- Initialize all registered plugins.<br>
--- Calls the init method of each plugin in dependency order (dependencies before dependents).<br>
--- Uses topological sort to respect plugin dependencies. Detects and reports cyclic dependencies.
---@usage <br>
--- ```
--- manager:init_all()
--- ```
function PluginManager:init_all()
	local plugins = self.plugins
	local initialized = {}
	local visited = {}
	local path = {}

	for name in next, plugins do
		if not initialized[name] then
			resolve_deps_helper(plugins, initialized, visited, path, name, self, "init", "init")
		end
	end
end

--- Start all registered plugins.<br>
--- Calls the start method of each plugin in dependency order (dependencies before dependents).<br>
--- Uses topological sort to respect plugin dependencies. Detects and reports cyclic dependencies.
---@usage <br>
--- ```
--- manager:start_all()
--- ```
function PluginManager:start_all()
	local plugins = self.plugins
	local started = {}
	local visited = {}
	local path = {}

	for name in next, plugins do
		if not started[name] then
			resolve_deps_helper(plugins, started, visited, path, name, self, "start", "start")
		end
	end
end

--- Module-level helper: stop plugin with reverse dependency resolution<br>
--- Reverse topological sort: stop dependents before dependencies
local function stop_plugin_helper(plugins, stopped, visited, path, name)
	if stopped[name] then return true end
	if visited[name] then
		-- Cyclic dependency detected
		local cycle = table_concat(path, " -> ") .. " -> " .. name
		return error("cyclic dependency detected: " .. cycle, 2)
	end

	visited[name] = true
	path[#path + 1] = name

	local p = plugins[name]
	if not p then
		path[#path] = nil
		visited[name] = false
		return true
	end

	-- First, stop all plugins that depend on this one
	for other_name, other_p in next, plugins do
		if other_p.deps then
			for _, dep_name in next, other_p.deps do
				if dep_name == name and not stopped[other_name] then
					if not stop_plugin_helper(plugins, stopped, visited, path, other_name) then
						path[#path] = nil
						visited[name] = false
						return false
					end
				end
			end
		end
	end

	-- Then stop this plugin
	if p.stop and not stopped[name] then
		local ok, err = pcall(p.stop, p)
		if not ok then
			print("error stopping plugin '" .. name .. "':", err)
			path[#path] = nil
			visited[name] = false
			return false
		end
		stopped[name] = true
	end

	path[#path] = nil
	visited[name] = false
	return true
end

--- Stop all registered plugins.<br>
--- Calls the stop method of each plugin in reverse dependency order (dependents before dependencies).<br>
--- Ensures plugins that depend on others are stopped before their dependencies. Detects and reports cyclic dependencies.
---@usage <br>
--- ```
--- manager:stop_all()
--- ```
function PluginManager:stop_all()
	local plugins = self.plugins
	local stopped = {}
	local visited = {}
	local path = {}

	for name in next, plugins do
		if not stopped[name] then
			stop_plugin_helper(plugins, stopped, visited, path, name)
		end
	end
end

----------------------------------------------------------------------
-- Dynamic plugin loading
----------------------------------------------------------------------

--- Load a plugin from a Lua code string.<br>
--- Compiles and executes the plugin code in a sandboxed environment with access to plugin, services, emit, print, and require.<br>
--- The plugin receives the plugin instance as the first argument and should return it modified.<br>
--- Throws error if plugin name already exists or if compilation fails.
---@param name string Plugin name (must be unique).
---@param code string Lua code string containing the plugin implementation.
---@param opts? table Optional table with state and config fields.
---@return table plugin Loaded plugin instance.
---@usage <br>
--- ```
--- local plugin = manager:load_plugin_from_string("myplugin", code, { state = {}, config = {} })
--- ```
function PluginManager:load_plugin_from_string(name, code, opts)
	assert(type(name) == "string", "plugin name must be string")
	assert(type(code) == "string", "plugin code must be string")

	if self.plugins[name] then
		return error("plugin '" .. name .. "' already exists", 2)
	end

	local plugin = {
		name = name,
		manager = setmetatable({ self }, { __mode = "v" }), -- weakref
		state = opts and opts.state or {},
		config = opts and opts.config or {},
	}

	local env = setmetatable({
		plugin = plugin,
		services = self.services,
		emit = function(...) self:emit(...) end,
		print = print,
		require = require,
	}, { __index = _G }) -- TODO/CONS: use `__index = _ENV or _G`

	local f, err = compat_load(code, name, "t", env)
	assert(f, err)

	local ok, res = pcall(f, plugin)
	assert(ok, res)

	-- Use the returned plugin table (res) if provided, otherwise use the original
	plugin = res or plugin

	self.plugins[name] = plugin
	return plugin
end

--- Alias for load_plugin_from_string.
---@see PluginManager.load_plugin_from_string
PluginManager.loadstring = PluginManager.load_plugin_from_string

--- Load a plugin from a function.<br>
--- Executes the function with the plugin instance as the first argument.<br>
--- The function can modify the plugin instance and should return it.<br>
--- The plugin receives access to services and emit through the manager.
---@param name string Plugin name (must be unique).
---@param fn function Plugin function (receives plugin instance as first argument).
---@param opts? table Optional table with state and config fields.
---@return table plugin Loaded plugin instance.
---@usage <br>
--- ```
--- local plugin = manager:load_plugin_from_function("myplugin", function(plugin)
---   plugin:say_hello = function(name) print("Hello, " .. name) end
---   return plugin
--- end)
--- ```
function PluginManager:load_plugin_from_function(name, fn, opts)
	assert(type(name) == "string", "plugin name must be string")
	assert(type(fn) == "function", "plugin function must be function")

	if self.plugins[name] then
		return error("plugin '" .. name .. " already exists", 2)
	end

	local plugin = {
		name = name,
		manager = setmetatable({ self }, { __mode = "v" }), -- weakref
		state = opts and opts.state or {},
		config = opts and opts.config or {},
	}

	-- Inject services and emit into plugin's metatable for access
	local plugin_mt = getmetatable(plugin) or {}
	plugin_mt.__index = function(t, k)
		if k == "services" then return self.services end
		if k == "emit" then return function(...) self:emit(...) end end
		return rawget(plugin, k)
	end
	setmetatable(plugin, plugin_mt)

	local ok, res = pcall(fn, plugin)
	if not ok then
		return error("error loading plugin from function '" .. name .. "': " .. res, 2)
	end

	self.plugins[name] = plugin
	return plugin
end

--- Hot reload a plugin from new code (string).<br>
--- Stops the existing plugin, loads the new code, and re-initializes and starts it.<br>
--- Maintains the plugin's state and config from the previous version.
---@param name string Plugin name to reload.
---@param code string New Lua code string.
---@return table plugin Reloaded plugin instance.
---@usage <br>
--- ```
--- local new_plugin = manager:hot_reload("myplugin", new_code)
--- ```
function PluginManager:hot_reload(name, code)
	local p = self.plugins[name]
	if p and p.stop then
		local ok, err = pcall(p.stop, p)
		if not ok and self.opts.debug then
			print("error stopping plugin for reload:", err)
		end
	end

	local instance = self:load_plugin_from_string(name, code)
	if instance.init then
		local ok, err = pcall(instance.init, instance, self)
		if not ok then
			print("error initializing reloaded plugin:", err)
		end
	end

	if instance.start then
		local ok, err = pcall(instance.start, instance)
		if not ok then
			print("error starting reloaded plugin:", err)
		end
	end

	return instance
end

--- Hot reload a plugin from a function.<br>
--- Stops the existing plugin, executes the function with the plugin instance, and re-initializes and starts it.<br>
--- Maintains the plugin's state and config from the previous version.
---@param name string Plugin name to reload.
---@param fn function Plugin function (receives plugin instance as first argument).
---@return table plugin Reloaded plugin instance.
---@usage <br>
--- ```
--- local new_plugin = manager:hot_reload_function("myplugin", function(plugin)
---   plugin:greet = function() print("Hello!") end
---   return plugin
--- end)
--- ```
function PluginManager:hot_reload_function(name, fn)
	assert(type(fn) == "function", "reload function must be a function")

	local p = self.plugins[name]
	if p and p.stop then
		local ok, err = pcall(p.stop, p)
		if not ok and self.opts.debug then
			print("error stopping plugin for reload:", err)
		end
	end

	-- Remove old plugin entry to allow load_plugin_from_function to create new one
	self.plugins[name] = nil

	local instance = self:load_plugin_from_function(name, fn, {
		state = p and p.state or {},
		config = p and p.config or {}
	})

	if instance.init then
		local ok, err = pcall(instance.init, instance, self)
		if not ok then
			print("error initializing reloaded plugin:", err)
		end
	end

	if instance.start then
		local ok, err = pcall(instance.start, instance)
		if not ok then
			print("error starting reloaded plugin:", err)
		end
	end

	return instance
end

--- Reload a plugin from new code (string or function).<br>
--- Dispatches to hot_reload (for string) or hot_reload_function (for function) based on code type.
---@param name string Plugin name to reload.
---@param code string|function New Lua code string or function for the plugin.
---@return table plugin Reloaded plugin instance.
function PluginManager:reload(name, code)
	if type(code) == "function" then
		return self:hot_reload_function(name, code)
	end
	return self:hot_reload(name, code)
end

---@alias PluginInitFn fun(self: Plugin, manager: PluginManager): nil
---@alias PluginStartFn fun(self: Plugin): nil
---@alias PluginStopFn fun(self: Plugin): nil

--- Plugin class for creating plugin instances
---@class Plugin
---@field name string Plugin name
---@field state table Plugin state storage
---@field config table Plugin configuration
---@field enabled boolean Whether the plugin is enabled
---@field deps? string[] Plugin dependencies
---@field manager? PluginManager Reference to the plugin manager
---@field init? PluginInitFn Plugin initialization function
---@field start? PluginStartFn Plugin start function
---@field stop? PluginStopFn Plugin stop function

--- Plugin builder with chainable methods for configuration
---@class PluginBuilder : Plugin
---@field depends_on fun(self: PluginBuilder, ...: string): PluginBuilder Specify plugin dependencies
---@field with_init fun(self: PluginBuilder, f: PluginInitFn): PluginBuilder Set the init function
---@field with_start fun(self: PluginBuilder, f: PluginStartFn): PluginBuilder Set the start function
---@field with_stop fun(self: PluginBuilder, f: PluginStopFn): PluginBuilder Set the stop function
---@field with_config fun(self: PluginBuilder, cfg: table): PluginBuilder Set the configuration
---@field enable fun(self: PluginBuilder): PluginBuilder Enable the plugin
---@field disable fun(self: PluginBuilder): PluginBuilder Disable the plugin
---@field toggle fun(self: PluginBuilder): PluginBuilder Toggle enabled state
---@field reload fun(self: PluginBuilder, code: string|function): PluginBuilder? Reload the plugin from new code

--- Create a new Plugin instance using the factory pattern.<br>
--- Returns a plugin table with chainable methods for configuration and lifecycle hooks.<br>
--- The plugin includes state, config, and enabled fields by default.
---@param name string Plugin name (must be a string).
---@return PluginBuilder plugin New plugin instance with chainable methods.
---@usage <br>
--- ```
--- local plugin = Plugin("myplugin")
---   :with_init(function(self, manager) ... end)
---   :with_start(function(self) ... end)
---   :with_stop(function(self) ... end)
---   :depends_on("other_plugin")
--- ```
local function Plugin(name)
	assert(type(name) == "string", "bad argument #1 to 'Plugin' (string expected, got " .. type(name) .. ")")

	---@class PluginBuilder
	local self = {
		name = name,
		state = {},
		config = {},
		enabled = true,
	}

	--- Specify plugin dependencies.<br>
	--- The plugin will only be initialized/started after its dependencies.<br>
	--- Dependencies are resolved using topological sort.
	---@param ... string Names of plugins this plugin depends on.
	---@return PluginBuilder self Self for method chaining.
	function self:depends_on(...)
		self.deps = { ... }
		return self
	end

	--- Set the plugin initialization function.<br>
	--- Called with (self, manager) when manager:init_all() is invoked.<br>
	--- Should set up the plugin's initial state and resources.
	---@param f PluginInitFn Initialization function (receives self and manager).
	---@return PluginBuilder self Self for method chaining.
	function self:with_init(f)
		self.init = f
		return self
	end

	--- Set the plugin start function.<br>
	--- Called with (self) when manager:start_all() is invoked.<br>
	--- Should start the plugin's active operations.
	---@param f PluginStartFn Start function (receives self).
	---@return PluginBuilder self Self for method chaining.
	function self:with_start(f)
		self.start = f
		return self
	end

	--- Set the plugin stop function.<br>
	--- Called with (self) when manager:stop_all() is invoked.<br>
	--- Should clean up the plugin's resources and stop active operations.
	---@param f PluginStopFn Stop function (receives self).
	---@return PluginBuilder self Self for method chaining.
	function self:with_stop(f)
		self.stop = f
		return self
	end

	--- Set the plugin configuration.<br>
	--- Configuration is accessible via self.config and can be used to customize plugin behavior.
	---@param cfg table Configuration table.
	---@return PluginBuilder self Self for method chaining.
	function self:with_config(cfg)
		self.config = cfg
		return self
	end

	--- Enable the plugin.<br>
	--- Sets the enabled flag to true. Plugins can check this flag to determine if they should run.
	---@return PluginBuilder self Self for method chaining.
	function self:enable()
		self.enabled = true
		return self
	end

	--- Disable the plugin.<br>
	--- Sets the enabled flag to false. Plugins can check this flag to determine if they should run.
	---@return PluginBuilder self Self for method chaining.
	function self:disable()
		self.enabled = false
		return self
	end

	--- Toggle the plugin enabled state.<br>
	--- Flips the enabled flag between true and false.
	---@return PluginBuilder self Self for method chaining.
	function self:toggle()
		self.enabled = not self.enabled
		return self
	end

	--- Reload the plugin from new code.<br>
	--- Stops the plugin, loads new code, and re-initializes and starts it.<br>
	--- Maintains the plugin's state and config from the previous version.<br>
	--- If `code` is a string, it's loaded as Lua code.<br>
	--- If `code` is a function, it's executed directly as the plugin code.
	---@param code string|function New Lua code string or function for the plugin.
	---@return PluginBuilder? plugin Reloaded plugin instance, or nil on error.
	function self:reload(code)
		local mgr = self.manager and self.manager[1] ---@type PluginManager?
		if not mgr then
			print("error: plugin '" .. self.name .. "' has no manager")
			return
		end
		if type(code) == "function" then
			return mgr:hot_reload_function(self.name, code)
		end
		return mgr:hot_reload(self.name, code)
	end

	return self
end

--- Export module with PluginManager and Plugin.
---@class PluginFramework
---@field PluginManager PluginManager Plugin manager class.
---@field Plugin fun(name: string): PluginBuilder Plugin factory function.
return {
	PluginManager = PluginManager,
	Plugin = Plugin,
}
