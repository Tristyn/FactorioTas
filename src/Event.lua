-- An event object that supports reentrancy.

local inspect = require("inspect")

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
		-- tracks the number of functions registered per object entry
		-- if a function is removed and num_entries for that object decrements to 0,
		-- the callback_objects entry can be removed entirely.
	}

	Event.set_metatable(new)

	return new
end

function Event:add(callback_object, callback_function_name)
	Event._ensure_func_callable(callback_object, callback_function_name)

	if self:_is_call_reentrant() then
		self:_add_during_reentrancy(callback_object, callback_function_name)
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
	--self:_verify()
end

function Event:_add_during_reentrancy(callback_object, callback_function_name)
	-- to make the call safe for reentry we must treat self.callback_objects
	-- as an immutable object

	-- update self.callback_objects
	local obj_callbacks = self.callback_objects[callback_object]
	if obj_callbacks == nil then
		obj_callbacks = { }
		obj_callbacks[callback_function_name] = callback_function_name
	elseif obj_callbacks[callback_function_name] ~= nil then
		error("The callback was added twice.")
	else
		obj_callbacks = util.assign_table({}, obj_callbacks)
		obj_callbacks[callback_function_name] = callback_function_name
	end
	self.callback_objects = util.assign_table({}, self.callback_objects)
	self.callback_objects[callback_object] = obj_callbacks

	-- update self.callback_objects_num_entries
	local obj_num_entries = self.callback_objects_num_entries[callback_object]
	if obj_num_entries == nil then
		obj_num_entries = 0
	end
	self.callback_objects_num_entries[callback_object] = obj_num_entries + 1
	--self:_verify()
end

function Event:invoke(...)
	self.reentry_count = self.reentry_count + 1
	
	-- get a local reference in case a reentrant call replaces self.callback_objects
	local callback_objects = self.callback_objects

	local ok, err = xpcall(
		function(...) 
			for object, callback_names in pairs(callback_objects) do
				for function_name, _ in pairs(callback_names) do
					object[function_name](object, ...)
				end
			end
		end, 
	debug.traceback, ...)


	self.reentry_count = self.reentry_count - 1
	assert(self.reentry_count >= 0)

	if err then
		log_error ({"TAS-err-generic", "Unhandled exception in event handler" .. serpent.block(err)})
	end
	--self:_verify()
end

function Event:remove(callback_object, callback_function_name)
	Event._ensure_func_callable(callback_object, callback_function_name)

	if self:_is_call_reentrant() then
		self:_remove_during_reentrancy(callback_object, callback_function_name)
	else
		self:_remove(callback_object, callback_function_name)
	end
end

function Event:_remove(callback_object, callback_function_name)
	local obj_callbacks = self.callback_objects[callback_object]
	if obj_callbacks == nil then error() end
	local callback_exists = obj_callbacks[callback_function_name] ~= nil

	if callback_exists == false then error() end
	obj_callbacks[callback_function_name] = nil
	
	self.callback_objects_num_entries[callback_object] = self.callback_objects_num_entries[callback_object] - 1
	local num_entries = self.callback_objects_num_entries[callback_object]
	if num_entries == 0 then
		self.callback_objects[callback_object] = nil
		self.callback_objects_num_entries[callback_object] = nil
	end
	--self:_verify()
end

function Event:_remove_during_reentrancy(callback_object, callback_function_name)
	-- to make the call safe for reentry we must treat self.callback_objects
	-- as an immutable object

	local obj_callbacks
	self.callback_objects_num_entries[callback_object] = self.callback_objects_num_entries[callback_object] - 1
	local num_entries = self.callback_objects_num_entries[callback_object]
	if num_entries == 0 then
		self.callback_objects_num_entries[callback_object] = nil

		obj_callbacks = { }
	elseif num_entries == nil then
		error()
	else
		obj_callbacks = self.callback_objects[callback_object]

		if obj_callbacks == nil then error() end
		if obj_callbacks[callback_function_name] == nil then error() end
		
		obj_callbacks = util.assign_table({}, obj_callbacks)
		obj_callbacks[callback_function_name] = nil
	end

	local callback_objects = util.assign_table({}, self.callback_objects)
	callback_objects[callback_object] = obj_callbacks
	self.callback_objects = callback_objects
	--self:_verify()
end

function Event:_is_call_reentrant()
	return self.reentry_count > 0
end

function Event._ensure_func_callable(callback_object, callback_function_name)
	if Event._is_func_callable(callback_object, callback_function_name) == false then
		error("Couldn't find function " .. callback_function_name .. " in callback object.")
	end
end

function Event._is_func_callable(callback_object, callback_function_name)
	fail_if_missing(callback_object)
	fail_if_missing(callback_function_name)

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

-- verify integrity of some of the table data for debugging
-- function Event:_verify()
-- 	local callback_objects = self.callback_objects
-- 	for object, callbacks in pairs(callback_objects) do
-- 		assert(object ~= nil)
-- 		assert(type(callbacks) == "table")
-- 		for key, val in pairs(callbacks) do
-- 			assert(type(key) == "string")
-- 			assert(type(val) == "string")
-- 		end
-- 	end
-- end

return Event