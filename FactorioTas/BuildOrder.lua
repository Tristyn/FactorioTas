local BuildOrder = { }
local metatable = { __index = BuildOrder }

function BuildOrder.set_metatable(instance)
    setmetatable(instance, metatable)
end

--[Comment]
-- Creates a new build order object that is tied to a ghost entity.
-- ghost_entity must not be nil or invalid. 
function BuildOrder.new_from_ghost_entity(ghost_entity)
    fail_if_invalid(ghost_entity)

    local build_order_item_name = nil
    for name, entity in pairs(ghost_entity.ghost_prototype.items_to_place_this) do
        build_order_item_name = name
    end

    local new =
    {
        surface_name = ghost_entity.surface.name,
        position = ghost_entity.position,
        item_name = build_order_item_name,
        direction = ghost_entity.direction,
        entity_name = ghost_entity.ghost_name
    }

    BuildOrder.set_metatable(new)

    return new
end

function BuildOrder:assign_waypoint(waypoint, index)
    if self.waypoint ~= nil then
        error("A waypoint can only be assigned once.") 
    end
    if waypoint.build_orders[index] ~= self then error() end
    
    self.waypoint = waypoint
    self.index = index
end

function BuildOrder:set_index(index)
    if self.waypoint.build_orders[index] ~= self then error() end

    self.index = index
end

function BuildOrder:can_reach(character)
    fail_if_invalid(character) 

    local surface = self:try_get_surface()
    if surface == nil then
        return false
    end
    
    local hittest_entity = surface.create_entity( { name="entity-ghost", inner_name = self.entity_name, position = self.position, direction = self.direction })
    
    -- The function character.can_reach_entity() is off limits because
    -- it will always return true for entities such as ghost.
    
    local selection_box_world_space = math.rectangle.translate(hittest_entity.prototype.selection_box, hittest_entity.position)
    local distance = math.distance_rectangle_to_point(selection_box_world_space, character.position)
    local can_reach = distance < util.get_build_distance(character) - 0.5
    -- Include a 0.5 margin of error because this isn't the exact reach distance formula.
    
    -- destroy the ephemeral entity that was created earlier in the function
    hittest_entity.destroy()
        
    return can_reach
end

--[Comment]
-- Returns a valid handle of the surface of this build order, or nil.
function BuildOrder:try_get_surface()
    if is_valid(self.surface) then
        return self.surface
    end

    self.surface = game.surfaces[self.surface_name]
    if is_valid(self.surface) then
        return self.surface
    end
end

function BuildOrder:try_build_object(player)
    -- build_order.surface.create_entity( { name = build_order.entity_name, position = build_order.position, direction = build_order.direction })
    -- in the future, calculate the players zoom
    tas.runner.move_player_cursor(player, build_order.position)
    local cursor = "empty";
    if player.cursor_stack.valid_for_read then
        cursor = player.cursor_stack.name
    end

    return player.build_from_cursor(click_position)
end

return BuildOrder