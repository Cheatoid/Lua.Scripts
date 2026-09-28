-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Native library loader for LuaJIT

-- Localized global functions for better performance
local error = error
local pcall = pcall
local setmetatable = setmetatable
local tonumber = tonumber
local type = type
local string_format = string.format

-- Import dependencies
local ffi = require "ffi" or error "LuaJIT is required"
local C = ffi.C

local native = {}

-- -@alias cdata userdata

--- Cross-platform native library handle with cached symbols.<br>
--- Owns an OS handle closed explicitly or by garbage collection.
---@class jit.Library
---@field _path string Library path used for loading.
---@field _handle cdata OS library handle with GC finalizer.
---@field _addresses table Cached raw symbol addresses by name.
---@field _functions table Cached functions by name then signature.
---@field _ctypes table Parsed FFI ctypes by signature.
local Library = {}
Library.__index = Library

----------------------------------------------------------------------
-- Platform backend
----------------------------------------------------------------------

local backend = {}

if ffi.os == "Windows" then
	ffi.cdef [[
		typedef void* lj_native_hmodule_t;

		typedef void (__stdcall *lj_native_farproc_t)();

		lj_native_hmodule_t __stdcall LoadLibraryA(
			const char* lpFileName
		);

		lj_native_farproc_t __stdcall GetProcAddress(
			lj_native_hmodule_t hModule,
			const char* lpProcName
		);

		int __stdcall FreeLibrary(
			lj_native_hmodule_t hLibModule
		);

		unsigned long __stdcall GetLastError();
	]]

	function backend.load(path)
		local handle = C.LoadLibraryA(path)

		if handle == nil then
			return nil, string_format(
				"LoadLibraryA(%q) failed (GetLastError=%d)",
				path,
				tonumber(C.GetLastError())
			)
		end

		-- The HMODULE must remain alive until the Library is closed.
		return ffi.gc(handle, function(h)
			C.FreeLibrary(h)
		end)
	end

	function backend.address(handle, name)
		local proc = C.GetProcAddress(handle, name)

		if proc == nil then
			return nil, string_format(
				"GetProcAddress(%q) failed (GetLastError=%d)",
				name,
				tonumber(C.GetLastError())
			)
		end

		-- Normalize the result to a plain data pointer.
		return ffi.cast("void*", proc)
	end

	function backend.close(handle)
		return C.FreeLibrary(handle) ~= 0
	end
else
	--------------------------------------------------------------------------
	-- POSIX
	--
	-- ffi.C normally exposes dlopen/dlsym on POSIX systems where they are
	-- part of the process's default/global namespace.
	-- If not, fall back to loading libdl.
	--------------------------------------------------------------------------

	ffi.cdef [[
		void* dlopen(
			const char* filename,
			int flags
		);

		void* dlsym(
			void* handle,
			const char* symbol
		);

		int dlclose(
			void* handle
		);

		const char* dlerror();
	]]

	local ok = pcall(function()
		return C.dlopen
	end)

	if not ok then
		C = ffi.load("dl")
	end

	-- POSIX RTLD_NOW.
	--
	-- This is the conventional value used by the Unix dynamic-loader APIs supported by LuaJIT targets.
	local RTLD_NOW = 2

	function backend.load(path)
		-- Clear any previous dlerror()
		C.dlerror()

		local handle = C.dlopen(path, RTLD_NOW)

		if handle == nil then
			local error_string = C.dlerror()

			if error_string ~= nil then
				error_string = ffi.string(error_string)
			else
				error_string = "unknown dlopen error"
			end

			return nil, string_format(
				"dlopen(%q) failed: %s",
				path,
				error_string
			)
		end

		return ffi.gc(handle, function(h)
			C.dlclose(h)
		end)
	end

	function backend.address(handle, name)
		-- POSIX requires checking dlerror() separately, because a NULL symbol value is technically possible
		C.dlerror()

		local address = C.dlsym(handle, name)
		local error_string = C.dlerror()

		if error_string ~= nil then
			return nil, string_format(
				"dlsym(%q) failed: %s",
				name,
				ffi.string(error_string)
			)
		end

		return address
	end

	function backend.close(handle)
		return C.dlclose(handle) == 0
	end
end

----------------------------------------------------------------------
-- Library
----------------------------------------------------------------------

--- Assert the library handle is still open.<br>
--- Throws when the library was already closed.
---@param self jit.Library The library instance.
local function check_open(self)
	if self._handle == nil then
		return error("native library is already closed", 3)
	end
end

--- Resolve a raw symbol address with caching.<br>
--- Caches the address by name for repeated lookups.<br>
--- Throws when the library is closed or the symbol is missing.
---@param self jit.Library The library instance.
---@param name string Symbol name to resolve.
---@return cdata address Raw symbol address pointer.
---@usage <br>
--- ```
--- local addr = lib:get_address("puts")
--- ```
function Library.get_address(self, name)
	check_open(self)

	if type(name) ~= "string" or name == "" then
		return error("symbol name must be a non-empty string", 2)
	end

	local cached = self._addresses[name]

	if cached ~= nil then
		return cached
	end

	local address, error_message = backend.address(
		self._handle,
		name
	)

	if address == nil then
		return error(
			string_format(
				"%s: %s",
				self._path,
				error_message
			),
			2
		)
	end

	self._addresses[name] = address

	return address
end

--- Cast a symbol address to a callable FFI function.<br>
--- Caches the ctype and function by name and signature.<br>
--- Throws when the library is closed or the symbol is missing.
---@param self jit.Library The library instance.
---@param name string Symbol name to resolve.
---@param signature string Function-pointer declaration for `ffi.typeof`.
---@return function fn Callable FFI function for the symbol.
---@usage <br>
--- ```
--- local puts = lib:get_function("puts", "int (*)(const char *)")
--- puts("hello")
--- ```
function Library.get_function(self, name, signature)
	check_open(self)

	if type(signature) ~= "string" or signature == "" then
		return error("function signature must be a non-empty string", 2)
	end

	local functions = self._functions[name]

	if functions == nil then
		functions = {}
		self._functions[name] = functions
	end

	local cached = functions[signature]

	if cached ~= nil then
		return cached
	end

	-- ffi.typeof() parses the function-pointer declaration.
	--
	-- Examples:
	--
	--   "void (*)(int, int)"
	--   "int (*)(const char *)"
	--   "void (__stdcall *)(int, int)"
	--
	-- The caller is responsible for supplying the correct ABI.
	local ctype = self._ctypes[signature]

	if ctype == nil then
		ctype = ffi.typeof(signature)
		self._ctypes[signature] = ctype
	end

	local address = self:get_address(name)

	local fn = ffi.cast(ctype, address)

	functions[signature] = fn

	return fn
end

--- Close the OS library handle and clear caches.<br>
--- Disables the GC finalizer after a successful close.<br>
--- Safe to call on an already closed library.
---@param self jit.Library The library instance.
---@return boolean ok True when closed, false on failure.
---@usage <br>
--- ```
--- lib:close()
--- ```
function Library.close(self)
	local handle = self._handle

	if handle == nil then
		return true
	end

	-- If closing fails, leave the finalizer attached so the handle can still be cleaned up later.
	local ok = backend.close(handle)

	if not ok then
		return false
	end

	-- We have manually closed it, therefore disable its GC finalizer.
	ffi.gc(handle, nil)

	self._handle = nil
	self._addresses = {}
	self._functions = {}
	self._ctypes = {}

	return true
end

--- Check if the library handle is still open.
---@param self jit.Library The library instance.
---@return boolean open True while the handle is open.
---@usage <br>
--- ```
--- if lib:is_open() then print(lib:path()) end
--- ```
function Library.is_open(self)
	return self._handle ~= nil
end

--- Get the path used to load the library.
---@param self jit.Library The library instance.
---@return string path Library path used for loading.
---@usage <br>
--- ```
--- print(lib:path())
--- ```
function Library.path(self)
	return self._path
end

----------------------------------------------------------------------
-- Module API
----------------------------------------------------------------------

--- Load a native library and return a handle.<br>
--- Attaches a GC finalizer that unloads on collection.<br>
--- Throws when the path is empty or loading fails.
---@param path string Library path to load.
---@return jit.Library lib New library handle instance.
---@usage <br>
--- ```
--- local native = require("native")
--- local lib = native.load("user32.dll")
--- lib:close()
--- ```
function native.load(path)
	if type(path) ~= "string" or path == "" then
		return error("library path must be a non-empty string", 2)
	end

	local handle, error_message = backend.load(path)

	if handle == nil then
		return error(error_message, 2)
	end

	return setmetatable({
		_path = path,
		_handle = handle,

		-- Raw symbol-address cache.
		_addresses = {},

		-- Function cache is nested because the same symbol can legitimately
		-- be cast to different signatures when it came from different
		-- Library objects.
		_functions = {},

		-- Parsed ctype cache.
		_ctypes = {},
	}, Library)
end

native.Library = Library
native.platform = ffi.os

-- Export
return native
