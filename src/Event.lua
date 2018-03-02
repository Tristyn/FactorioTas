local Map = require("ltrie.hashmap")

-- An event object that supports reentrancy.

local Event = { }
local metatable = { __index = Event }

function Event.set_metatable(instance)
	setmetatable(instance, metatable)
end

function Event.new()
	local new = {
		callback_objects = Map.of()
	}

	Event.set_metatable(new)

	return new
end

function Event:add(callback_object, callback_function_name)
	fail_if_missing(callback_object)
	fail_if_missing(callback_function_name)

	-- ensure the callback exists and is callable
	if Event._is_callable(callback_object, callback_function_name) == false then
		error("Couldn't find function " .. callback_function_name .. " in callback object.")
	end

	local obj_callbacks = self.callback_objects:get(callback_object)
	if obj_callbacks == nil then
		obj_callbacks = Map.from( pairs({ [callback_function_name] = callback_function_name }))
	elseif obj_callbacks:get(callback_function_name) ~= nil then
		error("The callback was added twice.")
	else
		obj_callbacks = obj_callbacks:assoc(callback_function_name, callback_function_name)
	end

	self.callback_objects = self.callback_objects:assoc(callback_object, obj_callbacks)
end

function Event:invoke(...)
	-- grab a local copy of the immutable structure in case it is modified
	-- during the event invocation.
	local callback_objects = self.callback_objects

	for _it, object, callback_names in callback_objects:iter() do
		for __it, function_name, _ in callback_names:iter() do
			object[function_name](object, ...)
		end
	end
end

function Event:remove(callback_object, callback_function_name)
	fail_if_missing(callback_object)
	fail_if_missing(callback_function_name)

	local obj_callbacks = self.callback_objects:get(callback_object)
	
	if obj_callbacks == nil then 
		error()
	end
	
	if obj_callbacks:get(callback_function_name) == nil then
		error()
	end

	obj_callbacks = obj_callbacks:dissoc(callback_function_name)

	if obj_callbacks:len() > 0 then
		self.callback_objects = self.callback_objects:assoc(callback_object, obj_callbacks)
	else
		self.callback_objects = self.callback_objects:dissoc(callback_object)
	end

end

function Event._is_callable(callback_object, callback_function_name)
	local func = callback_object[callback_function_name]

	if type(func) == "function" then
		return true
	end
		
	local mt = debug.getmetatable(func)
	if mt == nil then
		return false
	end

	return type(mt.__call) == "function"
end

return Event