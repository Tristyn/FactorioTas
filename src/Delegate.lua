-- A primitive in which the delegate will call a method with the `:` syntax (has a self argument).
-- the value of `self` is stored in the delegate, rather than typically a function closure or
-- metatable so that it is still stored after a save/load cycle.
-- Instead of the function being supplied directly, it is retrieved by indexing the callback_object with
-- the callback_function_name so that if the function body changes between mod versions, the new
-- version of the function can be executed.
-- delegate:invoke(...) is functionally the same as delegate(...)

-- Also useful when registering a callback that requires a unique identity to be able to unregister.

local Delegate = { }

function Delegate:invoke(...)
	self.callback_object[self.callback_function_name](self.callback_object, ...)
end

local metatable = { __index = Delegate, __call = Delegate.invoke }

function Delegate.set_metatable(instance)
	setmetatable(instance, metatable)

	-- we could throw when instance._is_callable() returns false but
	-- it is not guarenteed if the callback function already has a metatable 
	-- while this delegates metatable is being set.

end

function Delegate.new(callback_object, callback_function_name)
	fail_if_missing(callback_object)
	fail_if_missing(callback_function_name)

	local new = { 
		callback_object = callback_object,
		callback_function_name = callback_function_name,
	}

	Delegate.set_metatable(new)

	if new:_is_callable() == false then
		new:_throw_uncallable()
	end

	return new
end

function Delegate:_is_callable()
	local func = self.callback_object[self.callback_function_name]

	if type(func) == "function" then
		return true
	end
	
	local mt = getmetatable(func)
	if mt == nil then
		return false
	end

	return type(mt.__call) == "function"
end

function Delegate:_throw_uncallable()
	error("Couldn't find function " .. self.callback_function_name .. " in callback object or it is uncallable.")
end

return Delegate