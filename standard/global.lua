-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing global library (must be loaded manually)

-- Localized global functions for better performance
--local next = next

-- Import metamethod factories
--local metamethod_factory = require "../standalone/metamethod_factory"

-- Export metamethod factories to global namespace
--for name, factory in next, metamethod_factory.default do
--	_G[name] = factory
--end

_G.printf = require("../standalone/printf")

for name, func in next, require("../standalone/istype") do
	_G[name] = func
end

-- Export (for compatibility)
return _G
