-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing global library.

-- Localized global functions for better performance
--local next = next

-- Import metamethod factories
--local metamethod_factory = require("../standalone/metamethod_factory")

-- Export metamethod factories to global namespace
--for name, factory in next, metamethod_factory.default do
--	_G[name] = factory
--end

-- Export (for compatibility)
return _G
