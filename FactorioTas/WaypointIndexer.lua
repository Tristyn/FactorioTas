local WaypointIndexer = { }

function WaypointIndexer.set_metatable(instance)
	setmetatable(instance, {__index = WaypointIndexer})
end

function WaypointIndexer.new()
	local new = {
		_hash_table = { }
	}

	WaypointIndexer.set_metatable(new)

	return new
end

function WaypointIndexer:add(sequence, sequence_index, waypoint_index)
	fail_if_missing(sequence)
	fail_if_missing(sequence_index)
	fail_if_missing(waypoint_index)

	local waypoint = sequence.waypoints[waypoint_index]

	fail_if_missing(waypoint)

	local waypoint_entity = waypoint:get_entity()

	fail_if_invalid(waypoint_entity)

	local table_key = util.entity.get_hash_string(waypoint_entity)
	local table_value = {
		sequence_index = sequence_index,
		sequence = sequence,
		waypoint_index = waypoint_index,
		waypoint = waypoint
	}

	self._hash_table[table_key] = table_value
end

function WaypointIndexer:find_from_entity(waypoint_entity)
	fail_if_invalid(waypoint_entity)

	local table_key = util.entity.get_hash_string(waypoint_entity)

	return self._hash_table[table_key]
end

function WaypointIndexer:update_sequence_index(sequence, new_sequence_index)
	fail_if_missing(sequence)
	fail_if_missing(new_sequence_index)

	for waypoint_index, waypoint in pairs(sequence.waypoints) do

	local entity = waypoint:get_entity()

	fail_if_invalid(entity)

	local entry = self:find_from_entity(entity)

	fail_if_missing(entry)

	entry.sequence_index = new_sequence_index

	end
end

function WaypointIndexer:update_waypoint_index(waypoint, new_waypoint_index)
	fail_if_missing(waypoint)
	fail_if_missing(new_waypoint_index)

	local entity = waypoint:get_entity()

	fail_if_invalid(entity)

	local entry = self:find_from_entity(entity)

	fail_if_missing(entry)

	entry.waypoint_index = new_waypoint_index
end

function WaypointIndexer:update_waypoint_entity(old_waypoint_entity, new_waypoint_entity)
	fail_if_invalid(old_waypoint_entity)
	fail_if_invalid(new_waypoint_entity)

	local new_key = util.entity.get_hash_string(new_waypoint_entity)
	local old_key = util.entity.get_hash_string(old_waypoint_entity)
	local old_value = self._hash_table[old_key]

	fail_if_missing(old_value)

	self._hash_table[new_key] = old_value

	table.remove(_hash_table, old_key)
end

--[Comment]
-- Removes the entry using the waypoint_entity. Returns true if the entry is found, else false.
function WaypointIndexer:remove(waypoint_entity)
	fail_if_invalid(waypoint_entity)

	local table_key = util.entity.get_hash_string(waypoint_entity)

	self._hash_table[table_key] = nil
end



return WaypointIndexer