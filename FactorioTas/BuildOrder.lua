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
        name = ghost_entity.ghost_name,
        force_name = ghost_entity.force.name
    }

    BuildOrder.set_metatable(new)

    return new
end

function BuildOrder.new_from_template(template)
    local new = util.assign_table({}, template)
    new.position = util.assign_table({}, template.position)

    BuildOrder.set_metatable(new)

    return new
end

function BuildOrder:to_template()
    local template = util.assign_table({}, self)
    template.position = util.assign_table({}, self.position)
    template.waypoint = nil
    return template
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

function BuildOrder:get_entity()
    return util.find_entity(self.surface_name, self.name, self.position)
end

function BuildOrder:can_reach(character)
    return util.can_reach(character, self.surface_name, self.name, self.position)
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

function BuildOrder:spawn_object()
    local surface = self:try_get_surface()

    fail_if_invalid(surface)

    local ent = surface.create_entity({
        name = self.name,
        position = self.position,
        direction = self.direction,
        force = self.force_name
    })

    fail_if_missing(ent)
end

return BuildOrder