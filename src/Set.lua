local Set = { }
local metatable = { __index = Set }

-- A simple hashset with pairs, next and # implemented

function Set.set_metatable(instance)
	setmetatable(instance, metatable)
end

function Set.new()
	new = {
		_count = 0,
		_bag = { }
	}

	Set.set_metatable(new)

	return new
end

-- Adds the item to the set and returns false if the item is already present 
function Set:add(item)
	fail_if_missing(item)
	self:_fail_if_userdata(item)

	local present = self._bag[item] ~= nil

	self._bag[item] = item

	if present == true then
		return false
	else
		self._count = self._count + 1
		return true
	end
end

-- Remove the item from the set, and returns true if the item is present.
function Set:remove(item)
	fail_if_missing(item)
	self:_fail_if_userdata(item)

	local present = self._bag[item] ~= nil

	self._bag[item] = nil

	if present == true then
		self._count = self._count - 1
		return true
	else
		return false
	end
end

function Set:exists(item)
	fail_if_missing(item)
	self:_fail_if_userdata(item)

	return self._bag[item] ~= nil
end

function Set:_fail_if_userdata(item)
	if type(item) ~= "userdata" then return end
	
	error("Can't add userdata types to a set, userdata from the Factorio Api can't be used as a table key.")
end

function metatable:__len()
	return self._count
end

function metatable:__pairs(...)
	return pairs(self._bag, ...)
end

function metatable:__next(...)
	return next(self._bag, ...)
end

function metatable:__ipairs()
	error("ipairs unsupported")
end

return Set