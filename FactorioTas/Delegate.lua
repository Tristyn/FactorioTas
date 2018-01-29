-- A primitive in which the delegate will call a method with the `:` syntax (has a self argument).
-- the value of `self` is stored in the delegate, rather than typically a function closure or
-- metatable so that it is still stored after a save/load cycle.
-- Instead of the function being supplied directly, it is retrieved using the provider function
-- and current environment so that if the function body changes between mod versions, the new
-- function can be retrieved from the updated mods environment. 

-- Also useful when registering a callback that requires a unique identity to be able to unregister.

-- The `func_provider` signature is function(env):function
-- The function signature must be function(closure, env, ...):*

-- The `self` parameter can also be used as a makeshift closure. eg:
--[[
	local foo = Foo.new()
	local bar = self:get_bar()
	self.my_callback = Delegate.new({foo = foo, bar = bar}, function(closure, env) 
		closure.foo:do_thing(closure.bar)
	end)
]]

-- Environments are lost during save/load so the function must be pure and only access arguments.
-- To restore the environment it must be included in the closure or provided in the constructor.
--[[
	my_global = { foo = "bar" }
	callback = Delegate.new({foo = foo, bar = bar}, function(closure)
		closure.foo:do_thing(closure.bar)
	end)
]]

local Delegate = { }

function Delegate._invoke(delegate, ...)
	local self = delegate.self
	if self ~= nil then
		return delegate.func(self, delegate.env, unpack({...}))
	end
end

local metatable = { __index = Delegate, __call = Delegate._invoke }

function Delegate.set_env(instance, env)
	-- validate and memoize `func` here to be defensive

	local func = instance.func_provider(env)
	if type(func) ~= "function" then error() end

	setmetatable(instance, metatable)

	instance.env = env
	instance.func = func

end

function Delegate.new(self, env, func_provider)

	local new = { 
		self = self,
		func_provider = func_provider,
	}

	Delegate.set_env(new, env)

	return new
end

return Delegate

-- If the invoke syntax doesnt work then consider unpack as follows:

-- The ... and unpack keywords are dark corners of lua

-- Basically the __call metamethods treats the table as a callable function,
-- first argument of __call is the table being called, followed by the arguments of the call.
-- We want to discard the first argument, and forward the other to a call to `func`.
-- To do that we capture arg one in the variable `self` so it can be ignored,
-- and capture the subsequent arguments in the ... structure.  
-- Clone the call arguments we want into a table: {...} 
-- Then call the function where each table entry is an argument: func(unpack({...}))

-- This is some disgusting syntax yo 

--local metatable = { __call = function(self, ...) func(unpack({...})) end }