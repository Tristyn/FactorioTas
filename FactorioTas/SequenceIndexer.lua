-- A fast index for objects and maintains the index as objects are modified. 

local Sequence = require("Sequence")
local Waypoint = require("Waypoint")

local SequenceIndexer = { }
local metatable = { __index = SequenceIndexer }

function SequenceIndexer.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, metatable)

	-- The callbacks requires a unique identity to be able to unregister so
	-- create a delegate per instance
	local on_sequence_changed_delegate = util.function_delegate(function(event) instance:_on_sequence_changed(event) end)
	local on_waypoint_changed_delegate = util.function_delegate(function(event) instance:_on_waypoint_changed(event) end)

	for k, sequence in pairs(instance.sequences) do
		Sequence.set_metatable(sequence)
		if instance._on_sequence_changed_delegate ~= nil then
			sequence:unregister_on_changed(instance._on_sequence_changed_delegate)
			sequence:on_changed(on_sequence_changed_delegate)
		end

		if instance._on_waypoint_changed_delegate ~= nil then
			for k, waypoint in pairs(sequence.waypoints) do
				waypoint:unregister_on_changed(instance._on_waypoint_changed_delegate)
				waypoint:on_changed(on_waypoint_changed_delegate)
			end
		end
	end

	instance._on_sequence_changed_delegate = on_sequence_changed_delegate
	instance._on_waypoint_changed_delegate = on_waypoint_changed_delegate
end

function SequenceIndexer.new()
	
	local new = {
		_waypoint_index = { },
		sequences = { },
		_on_changed_callbacks = { }
	}

	SequenceIndexer.set_metatable(new)

	return new

end

function SequenceIndexer:new_sequence()
	local sequence = Sequence.new()

	sequence:on_changed(self._on_sequence_changed_delegate)

	local sequences = self.sequences
	local insert_index = #sequences + 1
	sequences[insert_index] = sequence
	sequence:set_index(insert_index)

	local waypoint_to_sequence = self._waypoint_to_sequence
	for _, waypoint in pairs(sequence.waypoints) do
		self:_add_waypoint(waypoint)
	end

	self:_changed("add_sequence", sequence)

	return sequence
end

function SequenceIndexer:remove_sequence(sequence)
	fail_if_missing(sequence)
	
	local sequences = self.sequences
	
	if sequences[sequence.index] ~= sequence then
		error("Sequence was not in this collection")
	end

	sequence:unregister_on_changed(self._on_sequence_changed_delegate)
	table.remove(sequences, sequence.index)

	--update sequence indexes
	for i = sequence.index, #sequences do
		sequences[i]:set_index(i)
	end

	for _, waypoint in pairs(sequence.waypoints) do
		self:_remove_waypoint(waypoint)
	end

	self:_changed("remove_sequence", sequence)
end

function SequenceIndexer:find_waypoint_from_entity(waypoint_entity)
	fail_if_invalid(waypoint_entity)

	local index = Waypoint.entity_to_string(waypoint_entity)

	return self._waypoint_index[index]
end

--[Comment]
-- Registers a callback to be run when the SequenceIndexer changes and provides an event object.
-- This is called every time a sequence is added or removed.
-- single parameter `event` with the following fields:
-- sender :: The SequenceIndexer that triggered the callback.
-- type :: string: Can be [add_sequence|remove_sequence]
-- sequence :: Sequnce: The sequence.
function SequenceIndexer:on_changed(func)
	if self._on_changed_callbacks[func] ~= nil then
		error()
	end
	self._on_changed_callbacks[func] = func
end

function SequenceIndexer:unregister_on_changed(func)
	if self._on_changed_callbacks[func] == nil then
		error()
	end
	self._on_changed_callbacks[func] = nil
end

function SequenceIndexer:_changed(type, sequence)
	fail_if_missing(type)
	fail_if_missing(sequence)

	local event = {
		sender = self,
		type = type,
		sequence = sequence
	}

	for k,func in pairs(self._on_changed_callbacks) do
		func(event)
	end
end

function SequenceIndexer:_add_waypoint(waypoint)
	self:_add_waypoint_to_index(waypoint)
	waypoint:on_changed(self._on_waypoint_changed_delegate)
end

function SequenceIndexer:_add_waypoint_to_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:to_string()] = waypoint
end

function SequenceIndexer:_remove_waypoint(waypoint)
	self:_remove_waypoint_from_index(waypoint)
	waypoint:unregister_on_changed(self._on_waypoint_changed_delegate)
end

function SequenceIndexer:_remove_waypoint_from_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:to_string()] = nil
end

function SequenceIndexer:_on_sequence_changed(event)
	if event.type == "add_waypoint" then
		self:_add_waypoint(event.waypoint)
	elseif event.type == "remove_waypoint" then
		self:_remove_waypoint(event.waypoint)
	end
end

function SequenceIndexer:_on_waypoint_changed(event)
	if event.type == "moved" then
		-- create a dummy with the new changes only to index it 
		local dummy = Waypoint.new(event.old_surface_name, event.old_position)
		self:_remove_waypoint_from_index(dummy)
		self:_add_waypoint_to_index(event.sender)
	end
end

return SequenceIndexer