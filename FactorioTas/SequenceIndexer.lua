-- A fast index for objects and maintains the index as objects are modified. 

local EntityIndexer = require("EntityIndexer")

local SequenceIndexer = { }
local metatable = { __index = SequenceIndexer }

function SequenceIndexer.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, { __index = instance._sequences })
	setmetatable(instance._sequences, metatable)
end

function SequenceIndexer.new()
	
	local new = {
		_waypoint_index = { },
		_sequences = { }
	}

	-- The callbacks requires a unique identity to be able to unregister so
	-- create a function per instance
	new._on_sequence_changed_delegate = function(event) new._on_sequence_changed(new, event) end
	new._on_waypoint_changed_delegate = function(event) new._on_waypoint_changed(new, event) end

	SequenceIndexer.set_metatable(new)

	return new

end

function SequenceIndexer:add_sequence(sequence)
	fail_if_missing(sequence)

	sequence:on_changed(self._on_sequence_changed_delegate)

	local sequences = self._sequences
	local insert_index = #sequences + 1
	sequences[insert_index] = sequence

	local waypoint_to_sequence = self._waypoint_to_sequence
	for _, waypoint in pairs(sequence.waypoints) do
		self:_add_waypoint_to_index(waypoint)
	end
end

function SequenceIndexer:remove_sequence(sequence)
	fail_if_missing(sequence)
	if self._sequences[sequence.index] ~= sequence then
		error("Sequence was not in this collection")
	end

	sequence:unregister_on_changed(self._on_sequence_changed_delegate)
	table.remove(self._sequences, sequence.index)

	--update sequence indexes
	for i = sequence.index, #self._sequences do
		self._sequences[i]:set_index(i)
	end

	for _, waypoint in pairs(sequence.waypoints) do
		self:_remove_waypoint_from_index(waypoint)
	end
end

function SequenceIndexer:find_waypoint_from_entity(waypoint_entity)
	fail_if_invalid(waypoint_entity)

	local index = Waypoint.entity_to_string(waypoint_entity)

	return self._waypoint_index[index]
end

function SequenceIndexer:_add_waypoint_to_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:to_string()] = waypoint
	waypoint:on_changed(self._on_waypoint_changed_delegate)
end

function SequenceIndexer:_remove_waypoint_from_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:to_string()] = nil
	waypoint:unregister_on_changed(self._on_waypoint_changed_delegate)
end

function SequenceIndexer:_on_sequence_changed(event)
	if event.type == "add_waypoint" then
		self:_add_waypoint_to_index(event.waypoint)
	elseif event.type == "remove_waypoint" then
		self:_remove_waypoint_from_index(event.waypoint)
	end
end

function SequenceIndexer:_on_waypoint_changed(event)
	if event.type == "moved" then
		self:_remove_waypoint_from_index(event.sender)
		-- create a dummy with the new changes only to index it 
		local dummy = Waypoint.new(event.surface_name, event.position)
		self:_add_waypoint_to_index(dummy)
	end
end

return SequenceIndexer