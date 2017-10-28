local Waypoint = require("Waypoint")

local Sequence = { }
local metatable = { __index = Sequence }

function Sequence.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, metatable)

	for k,v in pairs(instance.waypoints) do
		Waypoint.set_metatable(v)
	end
end

function Sequence.new(add_spawn_waypoint, add_initial_crafting_queue)
    
    local sequence = {
        waypoints = { },
        _on_changed_callbacks = { }
	}
	
	Sequence.set_metatable(sequence)

    if add_spawn_waypoint == true then

        local origin = { x = 0, y = 0 }
        local new_waypoint = sequence:insert_waypoint(1, "nauvis", origin)
        if new_waypoint == nil then
            
            game.print("Could not create a waypoint at spawn because one already exists there.")
        
        else
            
            if add_initial_crafting_queue == true then
                new_waypoint:add_craft_order("iron-axe", 1)
            end

        end
    end

    return sequence
end

function Sequence:set_index(index)
    self.index = index
end

function Sequence:insert_waypoint(insert_index, surface_name, position)
    return self:_insert_waypoint(insert_index, surface_name, position)
end

function Sequence:insert_waypoint_from_entity(insert_index, waypoint_entity)
    return self:_insert_waypoint(insert_index, waypoint_entity.surface.name, waypoint_entity.position, waypoint_entity)
end

function Sequence:_insert_waypoint(insert_index, surface_name, position, waypoint_entity)
    fail_if_missing(insert_index)
    fail_if_missing(surface_name)
    fail_if_missing(position)

    if insert_index < 1 or insert_index > #self.waypoints + 1 then
        error("insert_index out of range")
    end

    local is_spawning_entity = is_valid(waypoint_entity) == false
    local waypoint = Waypoint.new(surface_name, position, is_spawning_entity)

    table.insert(self.waypoints, insert_index, waypoint)

    waypoint:assign_sequence(self, insert_index)

    for i = insert_index + 1, #self.waypoints do
        self.waypoints[i]:set_index(i)
    end

    self:_changed("add_waypoint", waypoint, insert_index)

    return waypoint
end

function Sequence:remove_waypoint(index)
    fail_if_missing(index)

    if index < 1 or index > #waypoints then
        error("index out of range")
    end

    local waypoint = table.remove(self.waypoints, index)

    for i = index, #self.waypoints do
        self.waypoints[i]:set_index(i)
    end

    self:_changed("remove_waypoint", waypoint, index)
end

function Sequence:_changed(type, waypoint, index)
    local event = {
        sender = self,
        type = type,
        waypoint = waypoint,
        index = index
    }
    
    for k, handler in pairs(self._on_changed_callbacks) do
        handler(event)
    end
end

--[Comment]
-- Registers a callback to be run when the sequence changes and provides an event object.
-- This is called every time a waypoint is added or removed.
-- single parameter `Event` with the following fields:
-- sender :: The sequence that triggered the callback.
-- type :: string: Can be [add_waypoint|remove_waypoint]
-- waypoint :: Waypoint: The waypoint.
-- index :: uint: The index of the waypoint in the sequence.
function Sequence:on_changed(func)
    fail_if_missing(func)

    if self._on_changed_callbacks[func] ~= nil then
        error()
    end

    self._on_changed_callbacks[func] = func
end

--[Comment]
-- Ends further callbacks. Returns true if the handler was found.
function Sequence:unregister_on_changed(func)
    fail_if_missing(func)

    if self._on_changed_callbacks[func] == nil then
        error()
    end

    self._on_changed_callbacks[func] = nil
end

return Sequence