local Waypoint = require("Waypoint")
local Event = require("Event");

local Sequence = { }
local metatable = { __index = Sequence }

function Sequence.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

    setmetatable(instance, metatable)
    Event.set_metatable(instance.changed)

	for k,v in pairs(instance.waypoints) do
		Waypoint.set_metatable(v)
	end
end

function Sequence.new()
    
    local sequence = {
        waypoints = { },
        changed = Event.new();
    }
    
	Sequence.set_metatable(sequence)

    local origin = { x = 0, y = 0 }
    local new_waypoint = sequence:insert_waypoint(1, "nauvis", origin)
    if new_waypoint == nil then
        
        game.print("Could not create a waypoint at spawn because one already exists there.")
        
    else
            
        new_waypoint:add_craft_order("iron-axe", 1)

    end

    return sequence
end

function Sequence.new_from_template(template)
    local new = util.clone_table(template)

    new.waypoints = { }
    new.changed = Event.new()

    Sequence.set_metatable(new)

    for index, waypoint_template in pairs(template.waypoints) do
        local waypoint = Waypoint.new_from_template(waypoint_template)
        table.insert(new.waypoints, waypoint)
        waypoint.assign_sequence(new, index)
    end

    return new
end

function Sequence:to_template()
    local template = util.clone_table(self)

    template.waypoints = { }
    for index, waypoint in pairs(self.waypoints) do
        local waypoint_template = waypoint:to_template()
        table.insert(template.waypoints, waypoint_template)
    end

    template.changed = nil
    return template
end

function Sequence:set_index(index)
    self.index = index
end

function Sequence:insert_waypoint(insert_index, surface_name, pos)
    return self:_insert_waypoint(insert_index, surface_name, pos)
end

function Sequence:insert_waypoint_from_entity(insert_index, waypoint_entity)
    return self:_insert_waypoint(insert_index, waypoint_entity.surface.name, waypoint_entity.position, waypoint_entity)
end

function Sequence:_insert_waypoint(insert_index, surface_name, pos, waypoint_entity)
    fail_if_missing(insert_index)
    fail_if_missing(surface_name)
    fail_if_missing(pos)

    if insert_index < 1 or insert_index > #self.waypoints + 1 then
        error("insert_index out of range")
    end

    local is_spawning_entity = is_valid(waypoint_entity) == false
    local waypoint = Waypoint.new(surface_name, pos, is_spawning_entity)

    table.insert(self.waypoints, insert_index, waypoint)

    waypoint:assign_sequence(self, insert_index)

    for i = insert_index + 1, #self.waypoints do
        self.waypoints[i]:set_index(i)
    end

    self:_changed("add_waypoint", waypoint)

    return waypoint
end

function Sequence:can_remove_waypoint(index)
    fail_if_missing(index)

    -- ensure that there will never be zero waypoints in the sequence.
    return #self.waypoints > 1
end

function Sequence:remove_waypoint(index)
    fail_if_missing(index)

    if self:can_remove_waypoint(index) == false then
        error()
    end

    if index < 1 or index > #self.waypoints then
        error("index out of range")
    end

    local waypoint = table.remove(self.waypoints, index)

    for i = index, #self.waypoints do
        self.waypoints[i]:set_index(i)
    end
    
    waypoint:destroy()

    self:_changed("remove_waypoint", waypoint)
end

function Sequence:get_change_event(type, waypoint)
    return Sequence.ChangedEvent.new(self, type, waypoint);
end

--[Comment]
-- Registers a callback to be run when the sequence changes and provides an event object.
-- This is called every time a waypoint is added or removed.
-- single parameter `Event` with the following fields:
-- sender :: The sequence that triggered the callback.
-- type :: string: Can be [add_waypoint|remove_waypoint]
-- waypoint :: Waypoint: The waypoint.
function Sequence:_changed(type, waypoint)
    local event = self:get_change_event(type, waypoint)
    self.changed:invoke(event);
end







local Changed = { }
Sequence.ChangedEvent = Changed

-- metatable
local sequence_changed_mt = { __index = Sequence.ChangedEvent }
function Changed.set_metatable(instance) 
    if getmetatable(instance) ~= nil then
        return
    end


    setmetatable(instance, sequence_changed_mt)
    Sequence.set_metatable(instance.sender)
    Waypoint.set_metatable(instance.waypoint)
    

end
--

function Changed.new(sender_sequence, type, waypoint) 
    local new = {
        sender = sender_sequence,
        type = type,
        waypoint = waypoint,
    }

    Changed.set_metatable(new)

    return new;
end

return Sequence