local Event = { }
local metatable = { __index = Event }

function Event.set_metatable(instance)
	setmetatable(instance, metatable)
end

function Event.new()
	local new = {
		callback_objects = { },
		callback_objects_num_entries = { }
	}

	Event.set_metatable(new)

	return new
end

function Event:add(callback_object, callback_function_name)
	-- ensure the callback exists and is callable
	local func = callback_object[callback_function_name]
	if Event._is_callable(func) == false then
		error("Couldn't find function " .. callback_function_name .. " in callback object.")
	end

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

function Event:invoke(...)
	for object, callback_names in pairs(self.callback_objects) do
		for function_name, _ in pairs(callback_names) do
			object[function_name](object, ...)
		end
	end
end

function Event:remove(callback_object, callback_function_name)
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

function Event._is_callable(func)
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