local BuildOrder = { }
local MetaIndex = { }

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
        surface = ghost_entity.surface,
        surface_name = ghost_entity.surface.name,
        position = ghost_entity.position,
        item_name = build_order_item_name,
        direction = ghost_entity.direction,
        entity = ghost_entity,
        entity_name = ghost_entity.ghost_name
    }

    setmetatable(new, {__index = MetaIndex })

    return new
end

function MetaIndex:can_reach(character)
    fail_if_invalid(character) 

    local surface = self:try_get_surface()
    if surface == nil then
        return false
    end
    
    local hittest_entity = self.entity
    local is_hittest_entity_ephemeral = false
    if not is_valid(hittest_entity) then
        -- Create an ephemeral entity to run a hit-test against.
        -- If the entity in relation to this build order already exists, use that entity instead of a new one.

        -- Ghost entities flashing into and out of existance may mess with construction robots or other mods, not sure.
        -- A fix for this is to create dummy prototypes with matching hitboxes for every entity in the game,
        -- or implement the raw hit test code from factorio but using simple math instead of entities.  
        hittest_entity = surface.create_entity( { name = build_order.entity_name, position = build_order.position, direction = build_order.direction })
        is_hittest_entity_ephemeral = true
    end
    
    -- The function character.can_reach_entity() is off limits because
    -- it will always return true for entities such as ghost.
    
    local selection_box_world_space = math.rectangle.translate(hittest_entity.prototype.selection_box, hittest_entity.position)
    local distance = math.distance_rectangle_to_point(selection_box_world_space, character.position)
    local can_reach = distance < util.get_build_distance(character) - 0.5
    -- Include a 0.5 margin of error because this isn't the exact reach distance formula.
    
    if is_hittest_entity_ephemeral == true then
        -- destroy the ephemeral entity that was created earlier in the function
        hittest_entity.destroy()
    end
    
    return can_reach
end

--[Comment]
-- Returns a valid handle of the surface of this build order, or nil.
function MetaIndex:try_get_surface()
    if is_valid(self.surface) then
        return self.surface
    end

    self.surface = game.surfaces[self.surface_name]
    if is_valid(self.surface) then
        return self.surface
    end
end

return BuildOrder