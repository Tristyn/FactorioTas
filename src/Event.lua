-- An event object that supports reentrancy.

local Event = { }
local metatable = { __index = Event }

function Event.set_metatable(instance)
	setmetatable(instance, metatable)
end

function Event.new()
	local new = {
		reentry_count = 0,
		callback_objects = { },
		callback_objects_num_entries = { }
	}

	Event.set_metatable(new)

	return new
end

function Event:add(callback_object, callback_function_name)
	-- ensure the callback exists and is callable
	if Event._is_func_callable(callback_object, callback_function_name) == false then
		error("Couldn't find function " .. callback_function_name .. " in callback object.")
	end

	if self:_is_call_reentrant() then
		self:_add_during_reentrancy(callback_object, _callback_function_name)
	else
		self:_add(callback_object, callback_function_name)
	end
end

function Event:_add(callback_object, callback_function_name)
	local obj_callbacks = self.callback_objects[callback_object]
	local obj_num_entries = self.callback_objects_num_entries[callback_object]
	if obj_callbacks == nil then
		obj_callbacks = { }
		self.callback_objects[callback_object] = obj_callbacks
	end
	if obj_num_entries == nil then
		obj_num_entries = 0
	end
	
	if obj_callbacks[callback_function_name] ~= nil then
		error("The callback was added twice.")
	end

	obj_num_entries = obj_num_entries + 1
	obj_callbacks[callback_function_name] = callback_function_name
	self.callback_objects_num_entries[callback_object] = obj_num_entries
end

function Event:_add_during_reentrancy(callback_object, callback_function_name)
	-- to make the call reentrant we must treat self.callback_objects
	-- as an immutable objects:

	-- update self.callback_objects
	local obj_callbacks = self.callback_objects[callback_object]
	if obj_callbacks == nil then
		obj_callbacks = { [callback_function_name] = callback_function_name }
		self.callback_objects[callback_object] = obj_callbacks -- defer
	elseif obj_callbacks[callback_function_name] ~= nil then
		error("The callback was added twice.")
	else
		obj_callbacks = util.assign_table({}, obj_callbacks)
		obj_callbacks[callback_function_name] = callback_function_name
	end
	self.callback_objects = util.assign_table({}, obj_callbacks)
	self.callback_objects[obj_callbacks] = obj_callbacks

	-- update self.callback_objects_num_entries
	local obj_num_entries = self.callback_objects_num_entries[callback_object]
	if obj_num_entries == nil then
		obj_num_entries = 0
	end
	self.callback_objects_num_entries[callback_object] = obj_num_entries + 1
end

function Event:invoke(...)
	self.reentry_count = self.reentry_count + 1
	
	-- get a local reference in case a reentrant call replaces self.callback_objects
	local callback_objects = self.callback_objects

	local ok, err = xpcall(
		function(...) for object, callback_names in pairs(self.callback_objects) do
			for function_name, _ in pairs(callback_names) do
				object[function_name](object, ...)
			end
		end
	end, ..., debug.stacktrace)


	self.reentry_count = self.reentry_count - 1
	assert(self.reentry_count >= 0)

	if not ok then
		error(err)
	end
end

function Event:remove(callback_object, callback_function_name)
	if self:_is_call_reentrant() then
		self:_remove_during_reentrancy(callback_object, _callback_function_name)
	else
		self:_remove(callback_object, callback_function_name)
	end
end

function Event:_remove(callback_object, callback_function_name)
	local obj_callbacks = self.callback_objects[callback_object]
	if obj_callbacks == nil then error() end
	local callback_exists = obj_callbacks[callback_function_name] ~= nil

	if not callback_exists == true then error()	end
	obj_callbacks[callback_function_name] = nil
	
	self.callback_objects_num_entries[callback_object] = self.callback_objects_num_entries[callback_object] - 1
	local num_entries = self.callback_objects_num_entries[callback_object]
	if num_entries == 0 then
		self.callback_objects[callback_object] = nil
		self.callback_objects_num_entries[callback_object] = nil
	end
end

function Event:_remove_during_reentrancy(callback_object, callback_function_name)

	self.callback_objects_num_entries[callback_object] = self.callback_objects_num_entries[callback_object] - 1
	local num_entries = self.callback_objects_num_entries[callback_object]
	if num_entries == 0 then
		self.callback_objects_num_entries[callback_object] = nil

		local callback_objects = util.assign_table({}, self.callback_objects)
		callback_objects[callback_object] = nil
		self.callback_objects = callback_objects
	else
		local obj_callbacks = self.callback_objects[callback_object]

		if obj_callbacks == nil then error() end
		if obj_callbacks[callback_function_name] == nil then error() end
		
		obj_callbacks = util.assign_table({}, obj_callbacks)
		obj_callbacks[callback_function_name] = nil
		self.callback_objects = callback_objects
	end

end

function Event:_is_call_reentrant()
	return self.reentry_count > 0
end

function Event._is_func_callable(callback_object, callback_function_name)
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